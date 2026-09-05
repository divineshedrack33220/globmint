package httpapi

import (
	"net/http"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/httpapi/middleware"
)

type vaultWithdrawRequest struct {
	Amount      string `json:"amount"`
	Destination string `json:"destination"`
	Pin         string `json:"pin"`
}

type vaultWithdrawResponse struct {
	Transaction transactionResponse `json:"transaction"`
	TxHash      string              `json:"tx_hash"`
}

type verifyPinRequest struct {
	Pin string `json:"pin"`
}

type setPinRequest struct {
	Pin        string `json:"pin"`
	CurrentPin string `json:"current_pin,omitempty"`
}

// handleSetPin stores a new transaction PIN. If the user already has a PIN set,
// the current PIN must be supplied and verified first.
func (d *Deps) handleSetPin(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req setPinRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	if len(req.Pin) != 6 {
		writeError(w, r, domain.ErrInvalidPin, "")
		return
	}
	// If a PIN already exists, changing it requires the current one.
	existing, _ := d.Auth.HasPIN(r.Context(), user.ID)
	if existing {
		if err := d.Auth.VerifyPINThrottled(r.Context(), user.ID, req.CurrentPin); err != nil {
			writeError(w, r, err, "")
			return
		}
	}
	if err := d.Auth.SetPIN(r.Context(), user.ID, req.Pin); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"updated": true})
}

// handleVerifyPin checks the user's transaction PIN. Successful verification
// returns 200; a mismatch returns INVALID_PIN so clients can gate high-value
// actions before submitting them.
func (d *Deps) handleVerifyPin(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req verifyPinRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	if err := d.Auth.VerifyPINThrottled(r.Context(), user.ID, req.Pin); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"verified": true})
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
	if err := d.Auth.VerifyPIN(r.Context(), user.ID, req.Pin); err != nil {
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
