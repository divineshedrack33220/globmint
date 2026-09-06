package storage

import (
	"context"
	"time"

	"globmint/backend/internal/domain"
)

// UserRepository persists user records.
type UserRepository interface {
	Create(ctx context.Context, u *domain.User) error
	FindByID(ctx context.Context, id string) (*domain.User, error)
	FindByEmail(ctx context.Context, email string) (*domain.User, error)
	UpdateStatus(ctx context.Context, id string, status domain.UserStatus) error
	UpdatePIN(ctx context.Context, id, pinHash string) error
	UpdatePassword(ctx context.Context, id, passwordHash string) error
	UpdateTOTP(ctx context.Context, id, secret string, enabled bool) error
}

// SessionRepository persists sessions.
type SessionRepository interface {
	Create(ctx context.Context, s *domain.Session) error
	FindByTokenHash(ctx context.Context, hash string) (*domain.Session, error)
	FindByID(ctx context.Context, id string) (*domain.Session, error)
	ListActiveByUser(ctx context.Context, userID string) ([]domain.Session, error)
	Revoke(ctx context.Context, id string) error
	RevokeAllForUser(ctx context.Context, userID string) error
	RevokeAllExcept(ctx context.Context, userID, keepID string) error
	TouchLastActive(ctx context.Context, id string) error
}

// AccountRepository persists accounts and their balances.
type AccountRepository interface {
	EnsureDefaultAccounts(ctx context.Context, userID string) error
	EnsureAccount(ctx context.Context, userID string, kind domain.AccountKind, currency string) (*domain.Account, error)
	FindByID(ctx context.Context, id string) (*domain.Account, error)
	FindByUserAndKind(ctx context.Context, userID string, kind domain.AccountKind, currency string) (*domain.Account, error)
	ListByUser(ctx context.Context, userID string) ([]domain.Account, error)
	GetBalance(ctx context.Context, accountID string) (int64, error)
	SetBalance(ctx context.Context, accountID string, minor int64) error
}

// LedgerRepository persists transactions and their immutable entries.
type LedgerRepository interface {
	CreateTransaction(ctx context.Context, t *domain.Transaction) error
	FindTransactionByID(ctx context.Context, id string) (*domain.Transaction, error)
	FindTransactionByIDempotencyKey(ctx context.Context, key string) (*domain.Transaction, error)
	ListTransactionsByUser(ctx context.Context, userID string) ([]domain.Transaction, error)
	InsertEntry(ctx context.Context, e *domain.LedgerEntry) error
	ListEntriesByAccount(ctx context.Context, accountID string) ([]domain.LedgerEntry, error)
	SumBalanceByAccount(ctx context.Context, accountID string) (int64, error)
	SumWithdrawalsSince(ctx context.Context, userID string, since time.Time) (int64, error)
}

// BeneficiaryRepository persists saved payees.
type BeneficiaryRepository interface {
	Create(ctx context.Context, b *domain.Beneficiary) error
	ListByUser(ctx context.Context, userID string) ([]domain.Beneficiary, error)
	Update(ctx context.Context, b *domain.Beneficiary) error
	Delete(ctx context.Context, userID, id string) error
	ToggleFavorite(ctx context.Context, userID, id string) error
	FindByAddress(ctx context.Context, userID, address string) (*domain.Beneficiary, error)
}

// BankAccountRepository persists a user's saved external bank accounts.
type BankAccountRepository interface {
	Create(ctx context.Context, a *domain.BankAccount) error
	ListByUser(ctx context.Context, userID string) ([]domain.BankAccount, error)
	Delete(ctx context.Context, userID, id string) error
	SetDefault(ctx context.Context, userID, id string) error
	SetNotDefault(ctx context.Context, userID string) error
}

// ExchangeRateRepository persists currency conversion rates.
type ExchangeRateRepository interface {
	FindByPair(ctx context.Context, base, quote string) (*domain.ExchangeRate, error)
	// UpdateRate sets rate_minor for an active pair (used by the market-rate
	// refresher). Returns ErrNotFound when the pair does not exist.
	UpdateRate(ctx context.Context, base, quote string, rateMinor int64) error
}

// UserSaltsRepository persists per-user random salts for commitment-based
// balance privacy. When GLOBMINT_PRIVACY_MODE is enabled, each user's salt
// is stored here so the backend can derive keccak256(user, salt) commitments.
type UserSaltsRepository interface {
	Upsert(ctx context.Context, userID string, salt []byte) error
	FindByUser(ctx context.Context, userID string) ([]byte, error)
	Delete(ctx context.Context, userID string) error
}

// DepositAddressRepository persists the on-chain deposit address a user links
// to their account for non-custodial vault deposits.
type DepositAddressRepository interface {
	// FindByUser returns nil (not found) when the user has not linked an address.
	FindByUser(ctx context.Context, userID string) (*domain.DepositAddress, error)
	// Set upserts the user's deposit address. Returns ErrConflict if the
	// address is already claimed by another user.
	Set(ctx context.Context, da *domain.DepositAddress) error
	// OwnerOf returns the user ID that claimed the given address, or "" if none.
	OwnerOf(ctx context.Context, address string) (string, error)
}

// SecurityEventRepository persists security-activity events.
type SecurityEventRepository interface {
	Create(ctx context.Context, e *domain.SecurityEvent) error
	ListByUser(ctx context.Context, userID string, limit int) ([]domain.SecurityEvent, error)
}

// NotificationRepository persists the in-app notification inbox.
type NotificationRepository interface {
	Create(ctx context.Context, n *domain.Notification) error
	ListByUser(ctx context.Context, userID string, limit int) ([]domain.Notification, error)
	CountUnread(ctx context.Context, userID string) (int, error)
	MarkRead(ctx context.Context, userID, id string) error
	MarkAllRead(ctx context.Context, userID string) error
}

// IndexerStateRepository persists the vault indexer's scan cursor so a crash
// or restart resumes from the last confirmed block instead of re-scanning (or
// worse, skipping) history.
type IndexerStateRepository interface {
	// LastBlock returns the last confirmed block the indexer scanned, or 0
	// when the indexer has never run (the singleton row defaults to 0).
	LastBlock(ctx context.Context) (uint64, error)
	// SetLastBlock upserts the singleton cursor.
	SetLastBlock(ctx context.Context, lastBlock uint64) error
}

// IndexerEventRepository persists a durable log of processed vault transfers.
type IndexerEventRepository interface {
	// Insert records a confirmed transfer event; duplicates (same tx hash +
	// log index) are ignored so retries and rescans never duplicate rows.
	Insert(ctx context.Context, evt *domain.IndexerEvent) error
	// ListByRange returns events in a block range, oldest first.
	ListByRange(ctx context.Context, fromBlock, toBlock uint64) ([]domain.IndexerEvent, error)
}

// ElevationRepository persists time-locked (elevated) high-value withdrawals.
type ElevationRepository interface {
	// Create persists the pending elevation and returns it with its assigned ID.
	Create(ctx context.Context, e *domain.WithdrawalElevation) (*domain.WithdrawalElevation, error)
	FindByUserAndID(ctx context.Context, userID, id string) (*domain.WithdrawalElevation, error)
	// FindPendingByContent returns the user's pending elevation for this exact
	// destination+amount, or nil when none (used for idempotent requests).
	FindPendingByContent(ctx context.Context, userID, destination string, amountNgnMinor int64) (*domain.WithdrawalElevation, error)
	// ListPendingByUser returns the user's pending time-locked withdrawals.
	ListPendingByUser(ctx context.Context, userID string) ([]domain.WithdrawalElevation, error)
	// FindDuePending returns pending elevations whose release_after has passed.
	FindDuePending(ctx context.Context, now time.Time) ([]domain.WithdrawalElevation, error)
	// ClaimForBroadcast atomically moves a pending row to "broadcasting" so
	// exactly one sweeper instance broadcasts it. Returns false when another
	// instance already claimed it (or it is no longer pending).
	ClaimForBroadcast(ctx context.Context, id string) (bool, error)
	// MarkBroadcast records the broadcast tx hash and finalizes the row.
	MarkBroadcast(ctx context.Context, id, txHash string) error
	// ReleaseClaim returns a claimed-but-failed row to "pending" so a later
	// sweep retries it.
	ReleaseClaim(ctx context.Context, id string) error
	// CancelPending cancels a still-pending elevation; returns ErrNotFound when
	// it is gone or no longer cancellable.
	CancelPending(ctx context.Context, userID, id string) error
}

// Store bundles the repositories and exposes transaction-scoped operations so
// multi-row financial writes (ledger + balance) are atomic.
type Store interface {
	UserRepo() UserRepository
	SessionRepo() SessionRepository
	AccountRepo() AccountRepository
	LedgerRepo() LedgerRepository
	BeneficiaryRepo() BeneficiaryRepository
	BankAccountRepo() BankAccountRepository
	DepositAddressRepo() DepositAddressRepository
	SecurityEventRepo() SecurityEventRepository
	NotificationRepo() NotificationRepository
	IndexerStateRepo() IndexerStateRepository
	IndexerEventRepo() IndexerEventRepository
	ElevationRepo() ElevationRepository
	// UserSaltsRepository persists per-user random salts for commitment-based
	// balance privacy. When GLOBMINT_PRIVACY_MODE is enabled, each user's salt
	// is stored here so the backend can derive keccak256(user, salt) commitments.
	UserSaltsRepo() UserSaltsRepository
	// TryAcquireIndexerLeadership attempts a Postgres session-level advisory
	// lock so only one indexer instance scans at a time. On success it returns
	// a release func and ok=true; the caller must hold the lock for the whole
	// scan session and call release when done (or on ctx cancellation).
	TryAcquireIndexerLeadership(ctx context.Context, key int64) (release func(), ok bool, err error)
}
