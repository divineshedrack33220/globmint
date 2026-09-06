package httpapi

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/domain/money"
	"globmint/backend/internal/httpapi/middleware"
	"globmint/backend/internal/services"
)

// parseIntAmount parses a major-unit decimal string into minor units (the
// canonical integer form used throughout the ledger). It rejects negative and
// malformed values with ErrInvalidAmount.
func parseIntAmount(s string) (int64, error) {
	m, err := money.FromMajorUnits(s)
	if err != nil {
		return 0, domain.ErrInvalidAmount
	}
	return m.Minor(), nil
}

func normalizeCurrency(c string) string {
	return strings.ToUpper(c)
}

// handleDeposit credits the user's available account.
func (d *Deps) handleDeposit(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req depositRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	amountMinor, err := parseIntAmount(req.Amount)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	txn, err := d.Money.Deposit(r.Context(), user.ID, normalizeCurrency(req.Currency), amountMinor, middleware.IdempotencyKeyFrom(r.Context()))
	if err != nil {
		writeError(w, r, err, txnID(txn))
		return
	}
	d.publish(user.ID, "all")
	writeJSON(w, http.StatusCreated, map[string]any{"transaction": newTransactionResponse(txn)})
}

// handleWithdraw debits the user's available account toward an external bank.
func (d *Deps) handleWithdraw(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req withdrawRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	amountMinor, err := parseIntAmount(req.Amount)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	txn, err := d.Money.Withdraw(r.Context(), services.LedgerMoveRequest{
		UserID:      user.ID,
		AccountKind: domain.AccountKindAvailable,
		Currency:    normalizeCurrency(req.Currency),
		Type:        domain.TransactionTypeWithdrawal,
		AmountMinor: amountMinor,
		Metadata: map[string]any{
			"bank_id": req.BankID,
		},
	}, middleware.IdempotencyKeyFrom(r.Context()))
	if err != nil {
		writeError(w, r, err, txnID(txn))
		return
	}
	d.publish(user.ID, "all")
	writeJSON(w, http.StatusCreated, map[string]any{"transaction": newTransactionResponse(txn)})
}

// handleTransfer moves funds between the user's accounts or to an external
// recipient (a debit-only transfer).
func (d *Deps) handleTransfer(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req transferRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	amountMinor, err := parseIntAmount(req.Amount)
	if err != nil {
		writeError(w, r, err, "")
		return
	}

	fromKind := domain.AccountKindAvailable
	toKind := domain.AccountKind("")
	if strings.EqualFold(req.ToKind, "savings") {
		toKind = domain.AccountKindSavings
	}

	var destination string
	if req.AccountNumber != "" {
		parts := []string{req.BankName, req.AccountName, req.AccountNumber}
		destination = strings.TrimSpace(strings.Join(parts, " "))
	}

	txn, err := d.Money.Transfer(r.Context(), services.TransferRequest{
		UserID:         user.ID,
		FromKind:       fromKind,
		ToKind:         toKind,
		Currency:       normalizeCurrency(req.Currency),
		AmountMinor:    amountMinor,
		IdempotencyKey: middleware.IdempotencyKeyFrom(r.Context()),
		Destination:    destination,
		Description:    req.Narration,
	})
	if err != nil {
		writeError(w, r, err, txnID(txn))
		return
	}
	d.publish(user.ID, "all")
	writeJSON(w, http.StatusOK, map[string]any{"transaction": newTransactionResponse(txn)})
}

// handleRate returns the current book rate for a pair (live when the market
// feed is reachable, seeded otherwise). Read-only.
func (d *Deps) handleRate(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	base := normalizeCurrency(r.URL.Query().Get("from"))
	quote := normalizeCurrency(r.URL.Query().Get("to"))
	if base == "" || quote == "" {
		writeError(w, r, domain.ErrInvalidAmount, "")
		return
	}
	rate, err := d.Money.GetRate(r.Context(), base, quote)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"base":       rate.Base,
		"quote":      rate.Quote,
		"rate_minor": rate.Rate,
		"updated_at": rate.UpdatedAt.UTC().Format(time.RFC3339),
	})
}

// handleQuoteConversion returns a live quote without moving funds.
func (d *Deps) handleQuoteConversion(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req convertQuoteRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	var amountStr string
	switch v := req.Amount.(type) {
	case string:
		amountStr = v
	case float64:
		amountStr = strconv.FormatFloat(v, 'f', -1, 64)
	case int:
		amountStr = strconv.Itoa(v)
	case json.Number:
		amountStr = v.String()
	default:
		writeError(w, r, domain.ErrInvalidAmount, "")
		return
	}
	amountMinor, err := parseIntAmount(amountStr)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	quote, err := d.Money.QuoteConversion(r.Context(), amountMinor, normalizeCurrency(req.FromCurrency), normalizeCurrency(req.ToCurrency))
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"quote": newQuoteResponse(quote)})
}

// handleConvert executes a cross-currency conversion.
func (d *Deps) handleConvert(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req convertRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	amountMinor, err := parseIntAmount(req.Amount)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	txn, err := d.Money.Convert(r.Context(), user.ID, amountMinor, normalizeCurrency(req.FromCurrency), normalizeCurrency(req.ToCurrency), middleware.IdempotencyKeyFrom(r.Context()))
	if err != nil {
		writeError(w, r, err, txnID(txn))
		return
	}
	d.publish(user.ID, "all")
	writeJSON(w, http.StatusOK, map[string]any{"transaction": newTransactionResponse(txn)})
}

// handleListBeneficiaries returns the user's saved payees.
func (d *Deps) handleListBeneficiaries(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	list, err := d.Money.ListBeneficiaries(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	out := make([]beneficiaryResponse, 0, len(list))
	for i := range list {
		out = append(out, newBeneficiaryResponse(&list[i]))
	}
	writeJSON(w, http.StatusOK, map[string]any{"beneficiaries": out})
}

// handleCreateBeneficiary adds a saved payee.
func (d *Deps) handleCreateBeneficiary(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req beneficiaryRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	if strings.TrimSpace(req.Name) == "" || strings.TrimSpace(req.Address) == "" {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	b := &domain.Beneficiary{
		Name:       req.Name,
		Address:    req.Address,
		IsFavorite: req.IsFavorite,
	}
	if err := d.Money.CreateBeneficiary(r.Context(), user.ID, b); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"beneficiary": newBeneficiaryResponse(b)})
}

// handleUpdateBeneficiary edits a saved payee.
func (d *Deps) handleUpdateBeneficiary(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	id := r.PathValue("id")
	var req beneficiaryUpdateRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	b := &domain.Beneficiary{
		ID:         id,
		Name:       req.Name,
		Address:    req.Address,
		IsFavorite: req.IsFavorite,
	}
	if err := d.Money.UpdateBeneficiary(r.Context(), user.ID, b); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"beneficiary": newBeneficiaryResponse(b)})
}

// handleToggleBeneficiaryFavorite flips a payee's favorite flag.
func (d *Deps) handleToggleBeneficiaryFavorite(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if err := d.Money.ToggleBeneficiaryFavorite(r.Context(), user.ID, r.PathValue("id")); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

// handleDeleteBeneficiary removes a saved payee.
func (d *Deps) handleDeleteBeneficiary(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if err := d.Money.DeleteBeneficiary(r.Context(), user.ID, r.PathValue("id")); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

// handleResolveAccount looks up a beneficiary by account number.
func (d *Deps) handleResolveAccount(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	b, err := d.Money.ResolveAccount(r.Context(), user.ID, r.PathValue("address"))
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"beneficiary": newBeneficiaryResponse(b)})
}

// handleListBankAccounts returns the user's saved bank accounts.
func (d *Deps) handleListBankAccounts(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	list, err := d.Money.ListBankAccounts(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	out := make([]bankAccountResponse, 0, len(list))
	for i := range list {
		out = append(out, newBankAccountResponse(&list[i]))
	}
	writeJSON(w, http.StatusOK, map[string]any{"bank_accounts": out})
}

// handleCreateBankAccount saves a new payout bank account.
func (d *Deps) handleCreateBankAccount(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req bankAccountRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	a := &domain.BankAccount{
		BankName:      req.BankName,
		BankCode:      req.BankCode,
		AccountNumber: req.AccountNumber,
		AccountName:   req.AccountName,
		IsDefault:     req.IsDefault,
	}
	if err := d.Money.CreateBankAccount(r.Context(), user.ID, a); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"bank_account": newBankAccountResponse(a)})
}

// handleSetDefaultBankAccount marks a bank account as default.
func (d *Deps) handleSetDefaultBankAccount(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if err := d.Money.SetDefaultBankAccount(r.Context(), user.ID, r.PathValue("id")); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

// handleDeleteBankAccount removes a saved bank account.
func (d *Deps) handleDeleteBankAccount(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if err := d.Money.DeleteBankAccount(r.Context(), user.ID, r.PathValue("id")); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

// newQuoteResponse builds the wire representation of a conversion quote.
func newQuoteResponse(q *services.Quote) quoteResponse {
	return quoteResponse{
		InputAmountMajor:  money.FromMinorUnits(q.InputAmount).String(),
		InputCurrency:     q.InputCurrency,
		OutputAmountMajor: money.FromMinorUnits(q.OutputAmount).String(),
		OutputCurrency:    q.OutputCurrency,
		RateMajor:         money.FromMinorUnits(q.Rate).String(),
		FeeBPS:            q.FeeBPS,
		FeeAmountMajor:    money.FromMinorUnits(q.FeeAmount).String(),
		ExpiresAt:         quoteExpiresAt(),
	}
}

// newTransactionResponse maps a domain transaction to its wire form.
func newTransactionResponse(t *domain.Transaction) transactionResponse {
	return transactionResponse{
		ID:             t.ID,
		Type:           string(t.Type),
		Status:         string(t.Status),
		Currency:       t.Currency,
		Amount:         money.FromMinorUnits(t.AmountMinor).String(),
		Fee:            money.FromMinorUnits(t.FeeMinor).String(),
		ExchangeRate:   t.ExchangeRate,
		Reference:      t.Reference,
		ProviderRef:    t.ProviderRef,
		IdempotencyKey: t.IdempotencyKey,
		CreatedAt:      t.CreatedAt.Format("2006-01-02T15:04:05Z"),
	}
}

func txnID(t *domain.Transaction) string {
	if t == nil {
		return ""
	}
	return t.ID
}
