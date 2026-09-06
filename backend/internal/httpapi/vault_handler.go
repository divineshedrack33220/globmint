package httpapi

import (
	"net/http"
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/httpapi/middleware"
)

type vaultWithdrawRequest struct {
	Amount      string `json:"amount"`
	Destination string `json:"destination"`
	Pin         string `json:"pin"`
}

// elevationResponse is the client-facing shape of a time-locked withdrawal.
type elevationResponse struct {
	ID              string `json:"id"`
	Destination     string `json:"destination"`
	AmountNgnMinor  int64  `json:"amount_ngn_minor"`
	FeeNgnMinor     int64  `json:"fee_ngn_minor"`
	Status          string `json:"status"`
	ReleaseAfter    string `json:"release_after"`
	BroadcastTxHash string `json:"broadcast_tx_hash,omitempty"`
}

func toElevationResponse(e *domain.WithdrawalElevation) elevationResponse {
	r := elevationResponse{
		ID:              e.ID,
		Destination:     e.Destination,
		AmountNgnMinor:  e.AmountNgnMinor,
		FeeNgnMinor:     e.FeeMinor,
		Status:          string(e.Status),
		ReleaseAfter:    e.ReleaseAfter.UTC().Format(time.RFC3339),
		BroadcastTxHash: e.BroadcastTxHash,
	}
	return r
}

type vaultWithdrawResponse struct {
	Transaction *transactionResponse `json:"transaction,omitempty"`
	TxHash      string              `json:"tx_hash,omitempty"`
	Elevation   *elevationResponse  `json:"elevation,omitempty"`
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

	result, err := d.Vault.WithdrawToAddress(r.Context(), user.ID, req.Destination, amountMinor, middleware.IdempotencyKeyFrom(r.Context()))
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	d.publish(user.ID, "all")
	resp := vaultWithdrawResponse{}
	if result.Transaction != nil {
		tr := newTransactionResponse(result.Transaction)
		resp.Transaction = &tr
		resp.TxHash = result.TxHash
	}
	if result.Elevation != nil {
		er := toElevationResponse(result.Elevation)
		resp.Elevation = &er
	}
	writeJSON(w, http.StatusCreated, resp)
}

// handleListVaultElevations lists the user's pending time-locked withdrawals.
func (d *Deps) handleListVaultElevations(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	elevations, err := d.Vault.ListPendingElevations(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	out := make([]elevationResponse, 0, len(elevations))
	for i := range elevations {
		out = append(out, toElevationResponse(&elevations[i]))
	}
	writeJSON(w, http.StatusOK, map[string]any{"elevations": out})
}

// handleCancelVaultWithdraw cancels a pending elevated withdrawal before its
// release time. Already-broadcast or broadcast-in-progress elevations cannot be
// cancelled.
func (d *Deps) handleCancelVaultWithdraw(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	id := r.PathValue("id")
	if err := d.Vault.CancelElevation(r.Context(), user.ID, id); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"cancelled": true})
}
