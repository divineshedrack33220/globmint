package services

import (
	"context"
	"errors"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

// store is a storage root that can run operations atomically in a transaction
// and expose repositories directly. The Postgres implementation satisfies this;
// tests use Postgres via Docker to exercise real transactional + idempotency
// behavior.
type store interface {
	storage.Store
	RunInTx(ctx context.Context, fn func(store storage.Store) error) error
}

// LedgerMoveRequest describes a single atomic balance movement.
type LedgerMoveRequest struct {
	UserID         string
	AccountKind    domain.AccountKind
	Currency       string
	Type           domain.TransactionType
	AmountMinor    int64
	FeeMinor       int64
	ExchangeRate   string
	Reference      string
	ProviderRef    string
	IdempotencyKey string
	Metadata       map[string]any
}

// LedgerService is the source of truth for balance-affecting operations. All
// writes are immutable ledger entries performed atomically with an updated
// balance projection. Operations honor idempotency keys and never trust the
// client with authoritative math.
type LedgerService struct {
	store store
}

func NewLedgerService(store store) *LedgerService {
	return &LedgerService{store: store}
}

func defaultMetadata(m map[string]any) map[string]any {
	if m == nil {
		return map[string]any{}
	}
	return m
}

// Transactions lists a user's transactions, latest first.
func (s *LedgerService) Transactions(ctx context.Context, userID string) ([]domain.Transaction, error) {
	return s.store.LedgerRepo().ListTransactionsByUser(ctx, userID)
}

// Credit increases an account balance and records an immutable entry.
func (s *LedgerService) Credit(ctx context.Context, req LedgerMoveRequest) (*domain.Transaction, error) {
	if req.AmountMinor <= 0 {
		return nil, domain.ErrInvalidAmount
	}
	return s.move(ctx, req, domain.MovementCredit)
}

// Debit decreases an account balance after verifying sufficiency, recording an
// immutable entry. The net movement is amount + fee.
func (s *LedgerService) Debit(ctx context.Context, req LedgerMoveRequest) (*domain.Transaction, error) {
	total := req.AmountMinor + req.FeeMinor
	if total <= 0 {
		return nil, domain.ErrInvalidAmount
	}
	return s.move(ctx, req, domain.MovementDebit)
}

func (s *LedgerService) move(ctx context.Context, req LedgerMoveRequest, movement domain.LedgerMovement) (*domain.Transaction, error) {
	// Fast-path idempotency replay (the unique index is the authoritative guard).
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
		account, err := store.AccountRepo().FindByUserAndKind(ctx, req.UserID, req.AccountKind, req.Currency)
		if err != nil {
			return err
		}
		current, err := store.LedgerRepo().SumBalanceByAccount(ctx, account.ID)
		if err != nil {
			return err
		}

		totalMovement := req.AmountMinor
		if movement == domain.MovementDebit {
			totalMovement = req.AmountMinor + req.FeeMinor
			// Checked inside the transaction to avoid race conditions.
			if current < totalMovement {
				return domain.ErrInsufficientBalance
			}
		}
		if totalMovement > 0 && current+totalMovement < 0 {
			return domain.ErrInsufficientBalance
		}

		newBalance := current
		if movement == domain.MovementCredit {
			newBalance += totalMovement
		} else {
			newBalance -= totalMovement
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
		entry := &domain.LedgerEntry{
			TransactionID: txn.ID,
			AccountID:     account.ID,
			UserID:        req.UserID,
			Movement:      movement,
			Currency:      req.Currency,
			AmountMinor:   totalMovement,
		}
		if err := store.LedgerRepo().InsertEntry(ctx, entry); err != nil {
			return err
		}
		if err := store.AccountRepo().SetBalance(ctx, account.ID, newBalance); err != nil {
			return err
		}
		result = txn
		return nil
	})

	// Concurrent duplicate: another request already committed the same
	// idempotency key. Return the original transaction rather than an error.
	if err != nil && req.IdempotencyKey != "" && errors.Is(err, domain.ErrConflict) {
		existing, findErr := s.store.LedgerRepo().FindTransactionByIDempotencyKey(ctx, req.IdempotencyKey)
		if findErr == nil {
			return existing, nil
		}
	}
	return result, err
}
