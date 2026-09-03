package httpapi

import (
	"net/http"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/domain/money"
	"globmint/backend/internal/httpapi/middleware"
)

type transactionResponse struct {
	ID             string `json:"id"`
	Type           string `json:"type"`
	Status         string `json:"status"`
	Currency       string `json:"currency"`
	Amount         string `json:"amount"`
	Fee            string `json:"fee"`
	ExchangeRate   string `json:"exchange_rate,omitempty"`
	Reference      string `json:"reference"`
	ProviderRef    string `json:"provider_ref,omitempty"`
	IdempotencyKey string `json:"idempotency_key,omitempty"`
	CreatedAt      string `json:"created_at"`
}

// handleListTransactions returns the authenticated user's transaction history
// (latest first), exposing the full explicit state of each transaction.
func (d *Deps) handleListTransactions(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	txns, err := d.Ledger.Transactions(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	out := make([]transactionResponse, 0, len(txns))
	for _, t := range txns {
		out = append(out, transactionResponse{
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
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"transactions": out})
}
