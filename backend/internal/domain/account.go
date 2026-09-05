package domain

import "time"

// AccountKind categorizes the purpose of an account.
type AccountKind string

const (
	AccountKindAvailable   AccountKind = "available"
	AccountKindSavings     AccountKind = "savings"
	AccountKindPending     AccountKind = "pending"
	AccountKindWithdrawable AccountKind = "withdrawable"
	// AccountKindPlatformFees collects withdrawal fees. It is only ever owned
	// by the platform pseudo-user (PlatformUserID), never by a real user, so
	// fee revenue can never inflate anyone's balance.
	AccountKindPlatformFees AccountKind = "platform_fees"
)

// PlatformUserID owns the platform fee account. The row is seeded by
// migration 0012; it has an unusable password hash and must never be able to
// authenticate.
const PlatformUserID = "00000000-0000-0000-0000-000000000001"

// Account is a sub-ledger belonging to a user. Balances are NOT stored here;
// they are derived from the immutable ledger (see Balance).
type Account struct {
	ID        string
	UserID    string
	Kind      AccountKind
	Currency  string
	CreatedAt time.Time
}

// BalanceSnapshot is a point-in-time derived balance for an account.
type BalanceSnapshot struct {
	AccountID string
	Kind      AccountKind
	Currency  string
	Amount    int64 // minor units (kobo)
}
