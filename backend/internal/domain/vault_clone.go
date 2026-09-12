package domain

import "time"

// VaultClone is a per-user EIP-1167 vault clone deployed by
// GlobmintVaultFactory. Every account gets its own on-chain deposit address so
// funds sent to it belong to the account by construction — no wallet linking
// is required to receive, and the address reveals no personal data on chain.
type VaultClone struct {
	UserID         string
	CloneAddress   string
	FactoryAddress string
	DeployTxHash   string
	ChainID        int64
	CreatedAt      time.Time
}

// WithdrawSignature carries a user's EIP-712 signature authorizing ONE
// withdrawal from their clone (WithdrawRequest(to, amount, nonce, deadline)).
// Used by immediate withdrawals and stored on elevated withdrawals so the
// sweeper can relay the exact pre-signed intent at release time.
type WithdrawSignature struct {
	// Signature is the 0x-prefixed 65-byte (r||s||v) hexadecimal signature
	// over the typed withdrawal request.
	Signature string
	// Deadline is the unix-second expiry the signature covers. Expired
	// signatures are rejected before broadcast.
	Deadline int64
	// RelayNonce is the clone nonce the signature covers. For immediate
	// withdrawals it must equal the chain nonce at broadcast; for elevated
	// withdrawals it must equal the chain nonce at release (a withdrawal in
	// between invalidates the old intent, which is surfaced as "expired").
	// 0 means "signature was produced against the then-current nonce".
	RelayNonce uint64
	// RelayAmountBase is the stablecoin base-unit amount the signature covers,
	// which may differ from converting the NGN amount at a later rate. When
	// set, the relay broadcasts exactly this amount.
	RelayAmountBase int64
}

// OwnsSignature reports whether the withdrawal carries a user signature (as
// opposed to the transitional platform-signer placeholder path).
func (s *WithdrawSignature) HasSignature() bool {
	return s != nil && s.Signature != ""
}