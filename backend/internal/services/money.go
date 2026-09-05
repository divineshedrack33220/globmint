package services

import (
	"context"
	"errors"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/domain/money"
	"globmint/backend/internal/storage"
)

// MoneyService orchestrates money movement on top of the ledger: deposits,
// withdrawals, transfers, conversions, and saved-payee/payout management.
type MoneyService struct {
	store store
}

func NewMoneyService(store store) *MoneyService {
	return &MoneyService{store: store}
}

// Deposit credits the user's available account in the given currency.
func (s *MoneyService) Deposit(ctx context.Context, userID, currency string, amountMinor int64, key string) (*domain.Transaction, error) {
	if currency == "" {
		currency = "NGN"
	}
	return s.Ledger().Credit(ctx, LedgerMoveRequest{
		UserID:         userID,
		AccountKind:    domain.AccountKindAvailable,
		Currency:       currency,
		Type:           domain.TransactionTypeDeposit,
		AmountMinor:    amountMinor,
		IdempotencyKey: key,
	})
}

// Withdraw debits the user's available account toward an external destination.
func (s *MoneyService) Withdraw(ctx context.Context, req LedgerMoveRequest, key string) (*domain.Transaction, error) {
	if req.Currency == "" {
		req.Currency = "NGN"
	}
	req.IdempotencyKey = key
	return s.Ledger().Debit(ctx, req)
}

// WithdrawExternal debits the user's available account for an out-of-system
// withdrawal and settles the fee to the platform fee account, atomically. The
// user pays amount + fee; the single transaction row records the principal in
// amount_minor and the fee in fee_minor (so daily caps summing amount_minor
// stay fee-exclusive). A rollback on any error means a failed broadcast
// settlement never charges the fee.
func (s *MoneyService) WithdrawExternal(ctx context.Context, req LedgerMoveRequest, key string) (*domain.Transaction, error) {
	if req.Currency == "" {
		req.Currency = "NGN"
	}
	if req.AmountMinor <= 0 || req.FeeMinor < 0 {
		return nil, domain.ErrInvalidAmount
	}
	total := req.AmountMinor + req.FeeMinor
	req.IdempotencyKey = key

	// Fast-path idempotency replay (the unique index is the authoritative guard).
	if key != "" {
		existing, err := s.store.LedgerRepo().FindTransactionByIDempotencyKey(ctx, key)
		if err == nil {
			return existing, nil
		}
		if !errors.Is(err, domain.ErrNotFound) {
			return nil, err
		}
	}

	var result *domain.Transaction
	err := s.store.RunInTx(ctx, func(store storage.Store) error {
		from, err := store.AccountRepo().FindByUserAndKind(ctx, req.UserID, req.AccountKind, req.Currency)
		if err != nil {
			return err
		}
		fromBalance, err := store.LedgerRepo().SumBalanceByAccount(ctx, from.ID)
		if err != nil {
			return err
		}
		// Checked inside the transaction to avoid race conditions.
		if fromBalance < total {
			return domain.ErrInsufficientBalance
		}

		reference := req.Reference
		if reference == "" {
			reference = string(req.Type) + "-" + newRandRef()
		}

		txn := &domain.Transaction{
			UserID:         req.UserID,
			Type:           req.Type,
			Status:         domain.StatusCompleted,
			Currency:       req.Currency,
			AmountMinor:    req.AmountMinor,
			FeeMinor:       req.FeeMinor,
			ExchangeRate:   req.ExchangeRate,
			Reference:      reference,
			ProviderRef:    req.ProviderRef,
			IdempotencyKey: req.IdempotencyKey,
			Metadata:       defaultMetadata(req.Metadata),
		}
		if err := store.LedgerRepo().CreateTransaction(ctx, txn); err != nil {
			return err
		}

		// Debit the user for principal + fee.
		if err := store.LedgerRepo().InsertEntry(ctx, &domain.LedgerEntry{
			TransactionID: txn.ID,
			AccountID:     from.ID,
			UserID:        req.UserID,
			Movement:      domain.MovementDebit,
			Currency:      req.Currency,
			AmountMinor:   total,
		}); err != nil {
			return err
		}
		if err := store.AccountRepo().SetBalance(ctx, from.ID, fromBalance-total); err != nil {
			return err
		}

		// Settle the fee to the platform account (never to any user account).
		if req.FeeMinor > 0 {
			feeAcct, err := store.AccountRepo().EnsureAccount(ctx, domain.PlatformUserID, domain.AccountKindPlatformFees, req.Currency)
			if err != nil {
				return err
			}
			feeBalance, err := store.LedgerRepo().SumBalanceByAccount(ctx, feeAcct.ID)
			if err != nil {
				return err
			}
			if err := store.LedgerRepo().InsertEntry(ctx, &domain.LedgerEntry{
				TransactionID: txn.ID,
				AccountID:     feeAcct.ID,
				UserID:        domain.PlatformUserID,
				Movement:      domain.MovementCredit,
				Currency:      req.Currency,
				AmountMinor:   req.FeeMinor,
			}); err != nil {
				return err
			}
			if err := store.AccountRepo().SetBalance(ctx, feeAcct.ID, feeBalance+req.FeeMinor); err != nil {
				return err
			}
		}

		result = txn
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// Ledger returns the underlying LedgerService (kept private to reduce surface).
func (s *MoneyService) Ledger() *LedgerService {
	return NewLedgerService(s.store)
}

// TransferRequest describes an atomic transfer between two of the user's
// accounts (e.g. available -> savings), or from a user account to an external
// recipient reference (which only debits the source).
type TransferRequest struct {
	UserID        string
	FromKind      domain.AccountKind
	ToKind        domain.AccountKind
	Currency      string
	AmountMinor   int64
	FeeMinor      int64
	ExchangeRate  string
	Reference     string
	ProviderRef   string
	IdempotencyKey string
	Metadata      map[string]any
	Destination   string // display string for external recipient, when ToKind is empty
	Description   string
}

// Transfer moves funds from one account to another within the user, recording
// a single transaction with two ledger entries and updating both balance
// projections atomically.
func (s *MoneyService) Transfer(ctx context.Context, req TransferRequest) (*domain.Transaction, error) {
	if req.AmountMinor <= 0 {
		return nil, domain.ErrInvalidAmount
	}
	total := req.AmountMinor + req.FeeMinor
	if req.Currency == "" {
		req.Currency = "NGN"
	}

	// Fast-path idempotency replay.
	if req.IdempotencyKey != "" {
		existing, err := s.store.LedgerRepo().FindTransactionByIDempotencyKey(ctx, req.IdempotencyKey)
		if err == nil {
			return existing, nil
		}
		if !errors.Is(err, domain.ErrNotFound) {
			return nil, err
		}
	}

	var result *domain.Transaction
	err := s.store.RunInTx(ctx, func(store storage.Store) error {
		from, err := store.AccountRepo().FindByUserAndKind(ctx, req.UserID, req.FromKind, req.Currency)
		if err != nil {
			return err
		}
		fromBalance, err := store.LedgerRepo().SumBalanceByAccount(ctx, from.ID)
		if err != nil {
			return err
		}
		if fromBalance < total {
			return domain.ErrInsufficientBalance
		}

		reference := req.Reference
		if reference == "" {
			reference = string(domain.TransactionTypeTransfer) + "-" + newRandRef()
		}

		txn := &domain.Transaction{
			UserID:         req.UserID,
			Type:           domain.TransactionTypeTransfer,
			Status:         domain.StatusCompleted,
			Currency:       req.Currency,
			AmountMinor:    req.AmountMinor,
			FeeMinor:       req.FeeMinor,
			ExchangeRate:   req.ExchangeRate,
			Reference:      reference,
			ProviderRef:    req.ProviderRef,
			IdempotencyKey: req.IdempotencyKey,
			Metadata:       metadataWith(req.Metadata, req.Description, req.Destination),
		}
		if err := store.LedgerRepo().CreateTransaction(ctx, txn); err != nil {
			return err
		}

		// Debit source by amount.
		if err := store.LedgerRepo().InsertEntry(ctx, &domain.LedgerEntry{
			TransactionID: txn.ID,
			AccountID:     from.ID,
			UserID:        req.UserID,
			Movement:      domain.MovementDebit,
			Currency:      req.Currency,
			AmountMinor:   req.AmountMinor,
		}); err != nil {
			return err
		}
		if err := store.AccountRepo().SetBalance(ctx, from.ID, fromBalance-req.AmountMinor); err != nil {
			return err
		}

		// Fee entry.
		if req.FeeMinor > 0 {
			if err := store.LedgerRepo().InsertEntry(ctx, &domain.LedgerEntry{
				TransactionID: txn.ID,
				AccountID:     from.ID,
				UserID:        req.UserID,
				Movement:      domain.MovementDebit,
				Currency:      req.Currency,
				AmountMinor:   req.FeeMinor,
			}); err != nil {
				return err
			}
			if err := store.AccountRepo().SetBalance(ctx, from.ID, fromBalance-req.AmountMinor-req.FeeMinor); err != nil {
				return err
			}
		}

		// Credit destination account if it is internal to the user.
		if req.ToKind != "" {
			to, err := store.AccountRepo().FindByUserAndKind(ctx, req.UserID, req.ToKind, req.Currency)
			if err != nil {
				return err
			}
			toBalance, err := store.LedgerRepo().SumBalanceByAccount(ctx, to.ID)
			if err != nil {
				return err
			}
			if err := store.LedgerRepo().InsertEntry(ctx, &domain.LedgerEntry{
				TransactionID: txn.ID,
				AccountID:     to.ID,
				UserID:        req.UserID,
				Movement:      domain.MovementCredit,
				Currency:      req.Currency,
				AmountMinor:   req.AmountMinor,
			}); err != nil {
				return err
			}
			if err := store.AccountRepo().SetBalance(ctx, to.ID, toBalance+req.AmountMinor); err != nil {
				return err
			}
		}

		result = txn
		return nil
	})

	if err != nil && req.IdempotencyKey != "" && errors.Is(err, domain.ErrConflict) {
		if existing, findErr := s.store.LedgerRepo().FindTransactionByIDempotencyKey(ctx, req.IdempotencyKey); findErr == nil {
			return existing, nil
		}
	}
	return result, err
}

// Quote represents a computed conversion quote.
type Quote struct {
	InputAmount  int64
	InputCurrency string
	OutputAmount int64
	OutputCurrency string
	Rate         int64
	FeeBPS       int
	FeeAmount    int64
	MinMinor     int64
	MaxMinor     int64
}

// QuoteConversion computes a conversion quote for the primary (NGN) pair.
func (s *MoneyService) QuoteConversion(ctx context.Context, amountMinor int64, fromCurrency, toCurrency string) (*Quote, error) {
	if amountMinor <= 0 {
		return nil, domain.ErrInvalidAmount
	}
	rate, err := s.store.ExchangeRateRepo().FindByPair(ctx, fromCurrency, toCurrency)
	if err != nil {
		return nil, err
	}
	if amountMinor < rate.MinMinor || amountMinor > rate.MaxMinor {
		return nil, domain.ErrRateExceeded
	}

	input := money.FromMinorUnits(amountMinor)
	// fee = amount * feeBPS/10000
	fee, err := input.Percent(int64(rate.FeeBPS))
	if err != nil {
		return nil, domain.ErrBadRequest
	}
	net := input
	net, err = net.Sub(fee)
	if err != nil {
		return nil, domain.ErrBadRequest
	}
	// output = net / rate (rate is minor units of quote per 1 major of base).
	// net is in base minor units; convert to base major=cnt, then to quote minor.
	output, err := convertBaseToQuote(net.Minor(), rate.Rate)
	if err != nil {
		return nil, domain.ErrBadRequest
	}
	return &Quote{
		InputAmount:    amountMinor,
		InputCurrency:  fromCurrency,
		OutputAmount:   output,
		OutputCurrency: toCurrency,
		Rate:           rate.Rate,
		FeeBPS:         rate.FeeBPS,
		FeeAmount:      fee.Minor(),
		MinMinor:       rate.MinMinor,
		MaxMinor:       rate.MaxMinor,
	}, nil
}

// convertBaseToQuote converts base minor units into quote minor units given
// the rate (quote minor units per 1 base major unit). Because minor units are
// 100 per major, base major = baseMinor/100, and output quote minor =
// baseMajor * rate = (baseMinor * rate) / 100.
func convertBaseToQuote(baseMinor, rate int64) (int64, error) {
	big := money.FromMinorUnits(baseMinor)
	mult, err := big.MulRatio(rate, money.MinorUnit)
	if err != nil {
		return 0, err
	}
	return mult.Minor(), nil
}

// Convert executes a conversion that debits the source currency account and
// credits the destination currency account.
func (s *MoneyService) Convert(ctx context.Context, userID string, amountMinor int64, fromCurrency, toCurrency, key string) (*domain.Transaction, error) {
	quote, err := s.QuoteConversion(ctx, amountMinor, fromCurrency, toCurrency)
	if err != nil {
		return nil, err
	}
	// Ensure both accounts exist.
	if _, err := s.store.AccountRepo().EnsureAccount(ctx, userID, domain.AccountKindAvailable, fromCurrency); err != nil {
		return nil, err
	}
	if _, err := s.store.AccountRepo().EnsureAccount(ctx, userID, domain.AccountKindAvailable, toCurrency); err != nil {
		return nil, err
	}

	// Fast-path idempotency replay.
	if key != "" {
		existing, err := s.store.LedgerRepo().FindTransactionByIDempotencyKey(ctx, key)
		if err == nil {
			return existing, nil
		}
		if !errors.Is(err, domain.ErrNotFound) {
			return nil, err
		}
	}

	var result *domain.Transaction
	err = s.store.RunInTx(ctx, func(store storage.Store) error {
		from, err := store.AccountRepo().FindByUserAndKind(ctx, userID, domain.AccountKindAvailable, fromCurrency)
		if err != nil {
			return err
		}
		to, err := store.AccountRepo().FindByUserAndKind(ctx, userID, domain.AccountKindAvailable, toCurrency)
		if err != nil {
			return err
		}
		fromBal, err := store.LedgerRepo().SumBalanceByAccount(ctx, from.ID)
		if err != nil {
			return err
		}
		if fromBal < quote.InputAmount {
			return domain.ErrInsufficientBalance
		}
		toBal, err := store.LedgerRepo().SumBalanceByAccount(ctx, to.ID)
		if err != nil {
			return err
		}

		txn := &domain.Transaction{
			UserID:         userID,
			Type:           domain.TransactionTypeConversion,
			Status:         domain.StatusCompleted,
			Currency:       fromCurrency,
			AmountMinor:    quote.InputAmount,
			FeeMinor:       quote.FeeAmount,
			ExchangeRate:   money.FromMinorUnits(quote.Rate).String(),
			Reference:      string(domain.TransactionTypeConversion) + "-" + newRandRef(),
			IdempotencyKey: key,
			Metadata:       map[string]any{"from_currency": fromCurrency, "to_currency": toCurrency, "output_amount": quote.OutputAmount},
		}
		if err := store.LedgerRepo().CreateTransaction(ctx, txn); err != nil {
			return err
		}

		if err := store.LedgerRepo().InsertEntry(ctx, &domain.LedgerEntry{TransactionID: txn.ID, AccountID: from.ID, UserID: userID, Movement: domain.MovementDebit, Currency: fromCurrency, AmountMinor: quote.InputAmount}); err != nil {
			return err
		}
		if err := store.AccountRepo().SetBalance(ctx, from.ID, fromBal-quote.InputAmount); err != nil {
			return err
		}
		if err := store.LedgerRepo().InsertEntry(ctx, &domain.LedgerEntry{TransactionID: txn.ID, AccountID: to.ID, UserID: userID, Movement: domain.MovementCredit, Currency: toCurrency, AmountMinor: quote.OutputAmount}); err != nil {
			return err
		}
		if err := store.AccountRepo().SetBalance(ctx, to.ID, toBal+quote.OutputAmount); err != nil {
			return err
		}
		result = txn
		return nil
	})

	if err != nil && key != "" && errors.Is(err, domain.ErrConflict) {
		if existing, findErr := s.store.LedgerRepo().FindTransactionByIDempotencyKey(ctx, key); findErr == nil {
			return existing, nil
		}
	}
	return result, err
}

// ---- Saved payees & payouts ----

func (s *MoneyService) CreateBeneficiary(ctx context.Context, userID string, b *domain.Beneficiary) error {
	b.UserID = userID
	return s.store.BeneficiaryRepo().Create(ctx, b)
}

func (s *MoneyService) ListBeneficiaries(ctx context.Context, userID string) ([]domain.Beneficiary, error) {
	return s.store.BeneficiaryRepo().ListByUser(ctx, userID)
}

func (s *MoneyService) UpdateBeneficiary(ctx context.Context, userID string, b *domain.Beneficiary) error {
	if b.ID == "" {
		return domain.ErrNotFound
	}
	b.UserID = userID
	return s.store.BeneficiaryRepo().Update(ctx, b)
}

func (s *MoneyService) DeleteBeneficiary(ctx context.Context, userID, id string) error {
	return s.store.BeneficiaryRepo().Delete(ctx, userID, id)
}

func (s *MoneyService) ToggleBeneficiaryFavorite(ctx context.Context, userID, id string) error {
	return s.store.BeneficiaryRepo().ToggleFavorite(ctx, userID, id)
}

func (s *MoneyService) ResolveAccount(ctx context.Context, userID, address string) (*domain.Beneficiary, error) {
	return s.store.BeneficiaryRepo().FindByAddress(ctx, userID, address)
}

func (s *MoneyService) CreateBankAccount(ctx context.Context, userID string, a *domain.BankAccount) error {
	a.UserID = userID
	if a.IsDefault {
		if err := s.store.BankAccountRepo().SetNotDefault(ctx, userID); err != nil {
			return err
		}
	}
	return s.store.BankAccountRepo().Create(ctx, a)
}

func (s *MoneyService) ListBankAccounts(ctx context.Context, userID string) ([]domain.BankAccount, error) {
	return s.store.BankAccountRepo().ListByUser(ctx, userID)
}

func (s *MoneyService) DeleteBankAccount(ctx context.Context, userID, id string) error {
	return s.store.BankAccountRepo().Delete(ctx, userID, id)
}

func (s *MoneyService) SetDefaultBankAccount(ctx context.Context, userID, id string) error {
	return s.store.BankAccountRepo().SetDefault(ctx, userID, id)
}

func metadataWith(base map[string]any, description, destination string) map[string]any {
	m := map[string]any{}
	for k, v := range base {
		m[k] = v
	}
	if description != "" {
		m["description"] = description
	}
	if destination != "" {
		m["destination"] = destination
	}
	return m
}
