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