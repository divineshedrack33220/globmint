package domain

import "time"

// TransactionType enumerates the high-level financial operations.
type TransactionType string

const (
	TransactionTypeDeposit     TransactionType = "deposit"
	TransactionTypeWithdrawal  TransactionType = "withdrawal"
	TransactionTypeConversion  TransactionType = "conversion"
	TransactionTypeTransfer    TransactionType = "transfer"
	TransactionTypeFee         TransactionType = "fee"
	TransactionTypeAdjustment  TransactionType = "adjustment"
	TransactionTypeReversal    TransactionType = "reversal"
)

// TransactionStatus follows the explicit state machine from the spec; it is
// never reduced to a boolean "success".
type TransactionStatus string

const (
	StatusCreated                TransactionStatus = "created"
	StatusPendingAuthentication  TransactionStatus = "pending_authentication"
	StatusAuthorized             TransactionStatus = "authorized"
	StatusProcessing             TransactionStatus = "processing"
	StatusSubmitted              TransactionStatus = "submitted"
	StatusConfirmed              TransactionStatus = "confirmed"
	StatusCompleted              TransactionStatus = "completed"
	StatusFailed                 TransactionStatus = "failed"
	StatusCancelled              TransactionStatus = "cancelled"
	StatusReversed               TransactionStatus = "reversed"
	StatusExpired                TransactionStatus = "expired"
)

// LedgerMovement describes the direction of a ledger entry.
type LedgerMovement string

const (
	MovementCredit LedgerMovement = "credit"
	MovementDebit  LedgerMovement = "debit"
)

// Transaction is a financial operation that produces one or more ledger
// entries. It is the auditable envelope around all money movement.
type Transaction struct {
	ID             string
	UserID         string
	Type           TransactionType
	Status         TransactionStatus
	Currency       string
	AmountMinor    int64
	FeeMinor       int64
	ExchangeRate   string // decimal string, may be empty
	Reference      string // internal reference, e.g. DEP-...
	ProviderRef    string // external provider reference, may be empty
	IdempotencyKey string // dedupe key for retries
	Metadata       map[string]any
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// LedgerEntry is an immutable single-sided accounting line produced by a
// Transaction. Every balance-affecting movement is recorded here and cannot
// be deleted; corrections are new entries.
type LedgerEntry struct {
	ID            string
	TransactionID string
	AccountID     string
	UserID        string
	Movement      LedgerMovement
	Currency      string
	AmountMinor   int64
	CreatedAt     time.Time
}
