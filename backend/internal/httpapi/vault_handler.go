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
	d.RecordSecurityEvent(r.Context(), &domain.SecurityEvent{
		UserID:   user.ID,
		Type:     domain.SecurityEventPinChange,
		Severity: domain.SeverityInfo,
		Title:    "Transaction PIN changed",
		Detail:   "The 6-digit transaction PIN for this account was updated",
		IP:       clientIP(r), UserAgent: r.UserAgent(),
	})
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
		d.RecordSecurityEvent(r.Context(), &domain.SecurityEvent{
			UserID:   user.ID,
			Type:     domain.SecurityEventWithdrawal,
			Severity: domain.SeverityWarn,
			Title:    "Withdrawal rejected",
			Detail:   "A withdrawal request could not be fulfilled",
			IP:       clientIP(r), UserAgent: r.UserAgent(),
			Metadata: map[string]any{"destination": req.Destination, "outcome": "rejected"},
		})
		writeError(w, r, err, "")
		return
	}
	d.publish(user.ID, "all")
	detail := "Withdrawal requested to your destination address"
	if result.Elevation != nil {
		detail = "Withdrawal requested. Subject to a time-lock before broadcast."
	}
	d.RecordSecurityEvent(r.Context(), &domain.SecurityEvent{
		UserID:   user.ID,
		Type:     domain.SecurityEventWithdrawal,
		Severity: domain.SeverityInfo,
		Title:    "Withdrawal requested",
		Detail:   detail,
		IP:       clientIP(r), UserAgent: r.UserAgent(),
		Metadata: map[string]any{"destination": req.Destination, "scheduled": result.Elevation != nil},
	})
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
	d.RecordSecurityEvent(r.Context(), &domain.SecurityEvent{
		UserID:   user.ID,
		Type:     domain.SecurityEventWithdrawal,
		Severity: domain.SeverityInfo,
		Title:    "Withdrawal cancelled",
		Detail:   "A pending time-locked withdrawal was cancelled before its release time",
		IP:       clientIP(r), UserAgent: r.UserAgent(),
		Metadata: map[string]any{"elevation_id": id, "outcome": "cancelled"},
	})
	writeJSON(w, http.StatusOK, map[string]any{"cancelled": true})
}

// handleRecoveryStatus reports the user's clone recovery state (recovery
// address, armed delay, in-flight recovery window) as read from the chain. The
// clone contract is the source of truth; this is a live read, not a cache.
func (d *Deps) handleRecoveryStatus(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	st, err := d.Vault.RecoveryStatus(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"clone":                 st.Clone,
		"owner":                 st.Owner,
		"recovery_address":      st.RecoveryAddress,
		"recovery_delay_sec":    st.RecoveryDelaySec,
		"recovery_requested_at": st.RecoveryRequestedAt,
		"recovery_at":           st.RecoveryAt,
		"recovery_pending":      st.RecoveryPending,
	})
}

// handleCustodyStatus reports who controls the user's clone owner seat as read
// from the chain: the user's own wallet (claimed) or the platform placeholder
// signer (unclaimed — the account must take custody before signing
// withdrawals). The placeholder is returned so the client never hardcodes it.
func (d *Deps) handleCustodyStatus(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	st, err := d.Vault.CustodyStatus(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"clone":       st.Clone,
		"owner":       st.Owner,
		"placeholder": st.Placeholder,
		"claimed":     st.Claimed,
		"nonce":       st.Nonce,
	})
}

// handlePrepareCustody quotes the exact EIP-712 TransferOwnership request the
// platform signer must sign to hand the user's clone to their wallet — the
// custody claim. Nothing moves and nothing is persisted. The response is
// shaped for eth_signTypedData_v4 (domain + message + primaryType + types),
// reusing the WithdrawRequest-style envelope.
func (d *Deps) handlePrepareCustody(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	newOwner := r.URL.Query().Get("new_owner")
	if newOwner == "" {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	quote, err := d.Vault.PrepareCustodyClaim(r.Context(), user.ID, newOwner)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"domain": map[string]any{
			"name":               quote.Domain.Name,
			"version":            quote.Domain.Version,
			"chain_id":           quote.Domain.ChainID,
			"verifying_contract": quote.Domain.VerifyingContract,
		},
		"message": map[string]any{
			"new_owner": quote.Message.NewOwner.Hex(),
			"nonce":     quote.Message.Nonce,
			"deadline":  quote.Message.Deadline,
		},
		"primary_type": "TransferOwnership",
		"types": map[string]any{
			"EIP712Domain": []map[string]string{
				{"name": "name", "type": "string"},
				{"name": "version", "type": "string"},
				{"name": "chainId", "type": "uint256"},
				{"name": "verifyingContract", "type": "address"},
			},
			"TransferOwnership": []map[string]string{
				{"name": "newOwner", "type": "address"},
				{"name": "nonce", "type": "uint256"},
				{"name": "deadline", "type": "uint256"},
			},
		},
		"clone_owner": quote.Owner,
	})
}

// handleClaimCustody hands the clone owner seat from the platform placeholder
// signer to the user's wallet. The transfer is signed by the platform signer
// (the CURRENT owner, the only signer the contract accepts pre-claim) — the
// user authenticates with their account and names the wallet taking custody.
func (d *Deps) handleClaimCustody(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	var req struct {
		NewOwner string `json:"new_owner"`
	}
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	if req.NewOwner == "" {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	txHash, err := d.Vault.ClaimCustody(r.Context(), user.ID, req.NewOwner)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	d.RecordSecurityEvent(r.Context(), &domain.SecurityEvent{
		UserID:   user.ID,
		Type:     domain.SecurityEventCustody,
		Severity: domain.SeverityInfo,
		Title:    "Custody claimed",
		Detail:   "Ownership of your account was claimed or transferred",
		IP:       clientIP(r), UserAgent: r.UserAgent(),
		Metadata: map[string]any{"new_owner": req.NewOwner},
	})
	writeJSON(w, http.StatusOK, map[string]any{
		"claimed":   true,
		"new_owner": req.NewOwner,
		"tx_hash":   txHash,
	})
}

// handlePrepareRecovery quotes the exact EIP-712 SetRecovery request a client
// must sign before designating a recovery address. Nothing moves and nothing
// is persisted. The response is shaped for eth_signTypedData_v4 (domain +
// message + primaryType + types), reusing the WithdrawRequest-style envelope.
func (d *Deps) handlePrepareRecovery(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	recovery := r.URL.Query().Get("recovery_address")
	if recovery == "" {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	quote, err := d.Vault.PrepareRecovery(r.Context(), user.ID, recovery)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"domain": map[string]any{
			"name":               quote.Domain.Name,
			"version":            quote.Domain.Version,
			"chain_id":           quote.Domain.ChainID,
			"verifying_contract": quote.Domain.VerifyingContract,
		},
		"message": map[string]any{
			"recovery_address": quote.Message.RecoveryAddress.Hex(),
			"nonce":            quote.Message.Nonce,
			"deadline":         quote.Message.Deadline,
		},
		"primary_type": "SetRecovery",
		"types": map[string]any{
			"EIP712Domain": []map[string]string{
				{"name": "name", "type": "string"},
				{"name": "version", "type": "string"},
				{"name": "chainId", "type": "uint256"},
				{"name": "verifyingContract", "type": "address"},
			},
			"SetRecovery": []map[string]string{
				{"name": "recoveryAddress", "type": "address"},
				{"name": "nonce", "type": "uint256"},
				{"name": "deadline", "type": "uint256"},
			},
		},
		"clone_owner": quote.Owner,
	})
}

// setRecoveryRequest is the signed designation of a recovery address: the
// recovery address, the EIP-712 signature over
// SetRecovery(recovery_address, nonce, deadline), and the signed nonce +
// deadline. The backend only relays setRecoveryAddressBySig; it cannot set a
// recovery address without the owner's signature.
type setRecoveryRequest struct {
	RecoveryAddress string `json:"recovery_address"`
	Signature       string `json:"signature"`
	Deadline        int64  `json:"deadline"`
	Nonce           uint64 `json:"nonce"`
}

// handleSetRecoveryAddress designates the user's recovery address on their
// clone. The owner's EIP-712 signature is verified off-chain before the
// backend relays setRecoveryAddressBySig; a stranger can never designate
// themselves as recovery.
func (d *Deps) handleSetRecoveryAddress(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	var req setRecoveryRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	if req.RecoveryAddress == "" || req.Signature == "" {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	txHash, err := d.Vault.SetRecoveryAddressBySig(r.Context(), user.ID, req.RecoveryAddress, &domain.WithdrawSignature{
		Signature:  req.Signature,
		Deadline:   req.Deadline,
		RelayNonce: req.Nonce,
	})
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	d.RecordSecurityEvent(r.Context(), &domain.SecurityEvent{
		UserID:   user.ID,
		Type:     domain.SecurityEventRecovery,
		Severity: domain.SeverityInfo,
		Title:    "Recovery address designated",
		Detail:   "A recovery address was set for this account",
		IP:       clientIP(r), UserAgent: r.UserAgent(),
		Metadata: map[string]any{"recovery_address": req.RecoveryAddress},
	})
	d.publish(user.ID, "all")
	writeJSON(w, http.StatusOK, map[string]any{
		"recovery_address": req.RecoveryAddress,
		"tx_hash":          txHash,
	})
}
