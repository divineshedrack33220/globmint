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
	// EIP-712 withdrawal signature over
	// WithdrawRequest(to, amount, amount_minor_base, nonce, deadline):
	// 0x-prefixed 65-byte hex signed by the clone owner's wallet. Required
	// under GLOBMINT_REQUIRE_USER_SIGNATURE; optional in transitional mode.
	Signature string `json:"signature,omitempty"`
	// Deadline is the unix-second expiry the signature covers.
	Deadline int64 `json:"deadline,omitempty"`
	// Nonce is the clone nonce the signature covers (must match the chain
	// nonce at verification time).
	Nonce uint64 `json:"nonce,omitempty"`
	// AmountMinorBase is the stablecoin base-unit amount the signature covers
	// (the exact USDC that will leave the clone). Optional: when 0 the backend
	// converts amount at the live rate and requires a matching signature.
	AmountMinorBase int64 `json:"amount_minor_base,omitempty"`
}

func (r *vaultWithdrawRequest) signature() *domain.WithdrawSignature {
	if r.Signature == "" {
		return nil
	}
	return &domain.WithdrawSignature{
		Signature:       r.Signature,
		Deadline:        r.Deadline,
		RelayNonce:      r.Nonce,
		RelayAmountBase: r.AmountMinorBase,
	}
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
	ExpiredReason   string `json:"expired_reason,omitempty"`
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
		ExpiredReason:   e.ExpiredReason,
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

// handlePrepareVaultWithdraw quotes the exact EIP-712 withdrawal request a
// self-custody client must sign before calling POST /savings/withdraw. The
// response carries the domain a wallet needs for eth_signTypedData_v4, the
// message (to/amount/nonce/deadline) to sign, and the NGN/fee the user is
// authorizing. No funds move and nothing is persisted.
func (d *Deps) handlePrepareVaultWithdraw(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil || d.Savings == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	destination := r.URL.Query().Get("destination")
	if destination == "" {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	if _, err := domain.ValidateDepositAddress(destination); err != nil {
		writeError(w, r, domain.ErrInvalidAddress, "")
		return
	}
	amountMinor, err := parseIntAmount(r.URL.Query().Get("amount"))
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	quote, err := d.Vault.PrepareSignedWithdrawal(r.Context(), user.ID, destination, amountMinor)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"domain": map[string]any{
			"name":              quote.Domain.Name,
			"version":           quote.Domain.Version,
			"chain_id":          quote.Domain.ChainID,
			"verifying_contract": quote.Domain.VerifyingContract,
		},
		"message": map[string]any{
			"to":       quote.Message.To.Hex(),
			"amount":   quote.Message.Amount.String(),
			"nonce":    quote.Message.Nonce,
			"deadline": quote.Message.Deadline,
		},
		"primary_type":      "WithdrawRequest",
		"types": map[string]any{
			"EIP712Domain": []map[string]string{
				{"name": "name", "type": "string"},
				{"name": "version", "type": "string"},
				{"name": "chainId", "type": "uint256"},
				{"name": "verifyingContract", "type": "address"},
			},
			"WithdrawRequest": []map[string]string{
				{"name": "to", "type": "address"},
				{"name": "amount", "type": "uint256"},
				{"name": "nonce", "type": "uint256"},
				{"name": "deadline", "type": "uint256"},
			},
		},
		"amount_ngn_minor":   quote.AmountNgnMinor,
		"fee_ngn_minor":      quote.FeeNgnMinor,
		"amount_minor_base":  quote.Message.Amount.String(),
		"clone_owner":        quote.Owner,
	})
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

	result, err := d.Vault.WithdrawToAddressSigned(r.Context(), user.ID, req.Destination, amountMinor, req.signature(), middleware.IdempotencyKeyFrom(r.Context()))
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
