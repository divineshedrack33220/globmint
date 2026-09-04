package httpapi

import (
	"net/http"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/httpapi/middleware"
)

type vaultWithdrawRequest struct {
	Amount      string `json:"amount"`
	Destination string `json:"destination"`
}

type vaultWithdrawResponse struct {
	Transaction transactionResponse `json:"transaction"`
	TxHash      string              `json:"tx_hash"`
}

// handleVaultWithdraw debits NGN and sends USDC on-chain from the user's vault
// to the destination address they supply.
func (d *Deps) handleVaultWithdraw(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil || d.Savings == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	var req vaultWithdrawRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	if req.Destination == "" {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	if _, err := domain.ValidateDepositAddress(req.Destination); err != nil {
		writeError(w, r, domain.ErrInvalidAddress, "")
		return
	}
	amountMinor, err := parseIntAmount(req.Amount)
	if err != nil {
		writeError(w, r, err, "")
		return
	}

	txn, err := d.Vault.WithdrawToAddress(r.Context(), user.ID, req.Destination, amountMinor, middleware.IdempotencyKeyFrom(r.Context()))
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusCreated, vaultWithdrawResponse{
		Transaction: newTransactionResponse(txn),
		TxHash:      txn.ProviderRef,
	})
}
