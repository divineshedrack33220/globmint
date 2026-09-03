package httpapi

import (
	"net/http"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/domain/money"
	"globmint/backend/internal/httpapi/middleware"
)

type balanceResponse struct {
	AccountID string `json:"account_id"`
	Kind      string `json:"kind"`
	Currency  string `json:"currency"`
	Amount    string `json:"amount"` // major-unit decimal string
	AmountMinor int64 `json:"amount_minor"`
}

// handleListBalances returns the authenticated user's balances.
func (d *Deps) handleListBalances(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	snapshots, err := d.Balance.List(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	out := make([]balanceResponse, 0, len(snapshots))
	for _, s := range snapshots {
		out = append(out, balanceResponse{
			AccountID:   s.AccountID,
			Kind:        string(s.Kind),
			Currency:    s.Currency,
			Amount:      money.FromMinorUnits(s.Amount).String(),
			AmountMinor: s.Amount,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"balances": out})
}
