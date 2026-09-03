package domain

import "time"

// AccountKind categorizes the purpose of an account.
type AccountKind string

const (
	AccountKindAvailable   AccountKind = "available"
	AccountKindSavings     AccountKind = "savings"
	AccountKindPending     AccountKind = "pending"
	AccountKindWithdrawable AccountKind = "withdrawable"
)

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
