package storage

import (
	"context"

	"globmint/backend/internal/domain"
)

// UserRepository persists user records.
type UserRepository interface {
	Create(ctx context.Context, u *domain.User) error
	FindByID(ctx context.Context, id string) (*domain.User, error)
	FindByEmail(ctx context.Context, email string) (*domain.User, error)
	UpdateStatus(ctx context.Context, id string, status domain.UserStatus) error
}

// SessionRepository persists sessions.
type SessionRepository interface {
	Create(ctx context.Context, s *domain.Session) error
	FindByTokenHash(ctx context.Context, hash string) (*domain.Session, error)
	Revoke(ctx context.Context, id string) error
	RevokeAllForUser(ctx context.Context, userID string) error
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
}

// BeneficiaryRepository persists saved payees.
type BeneficiaryRepository interface {
	Create(ctx context.Context, b *domain.Beneficiary) error
	ListByUser(ctx context.Context, userID string) ([]domain.Beneficiary, error)
	Update(ctx context.Context, b *domain.Beneficiary) error
	Delete(ctx context.Context, userID, id string) error
	ToggleFavorite(ctx context.Context, userID, id string) error
	FindByAccountNumber(ctx context.Context, userID, accountNumber string) (*domain.Beneficiary, error)
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
}
