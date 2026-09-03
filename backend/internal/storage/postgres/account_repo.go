package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type accountRepo struct{ q Querier }

// NewAccountRepo returns an AccountRepository bound to the given querier.
func NewAccountRepo(q Querier) storage.AccountRepository { return &accountRepo{q: q} }

const accountCols = `id::text, user_id::text, kind, currency, created_at`

func scanAccount(row pgxRow) (*domain.Account, error) {
	a := &domain.Account{}
	if err := row.Scan(&a.ID, &a.UserID, &a.Kind, &a.Currency, &a.CreatedAt); err != nil {
		return nil, err
	}
	return a, nil
}

// EnsureDefaultAccounts creates the standard available and savings accounts.
func (r *accountRepo) EnsureDefaultAccounts(ctx context.Context, userID string) error {
	for _, kind := range []domain.AccountKind{domain.AccountKindAvailable, domain.AccountKindSavings} {
		_, err := r.q.Exec(ctx, `
			INSERT INTO accounts (user_id, kind, currency)
			VALUES ($1::uuid, $2, 'NGN')
			ON CONFLICT (user_id, kind, currency) DO NOTHING`, userID, kind)
		if err != nil {
			return mapPgErr(err)
		}
	}
	return nil
}

func (r *accountRepo) FindByID(ctx context.Context, id string) (*domain.Account, error) {
	row := r.q.QueryRow(ctx, `SELECT `+accountCols+` FROM accounts WHERE id = $1::uuid`, id)
	return scanAccount(row)
}

func (r *accountRepo) FindByUserAndKind(ctx context.Context, userID string, kind domain.AccountKind, currency string) (*domain.Account, error) {
	row := r.q.QueryRow(ctx, `
		SELECT `+accountCols+` FROM accounts WHERE user_id = $1::uuid AND kind = $2 AND currency = $3`,
		userID, kind, currency)
	return scanAccount(row)
}

func (r *accountRepo) ListByUser(ctx context.Context, userID string) ([]domain.Account, error) {
	rows, err := r.q.Query(ctx, `SELECT `+accountCols+` FROM accounts WHERE user_id = $1::uuid ORDER BY created_at`, userID)
	if err != nil {
		return nil, mapPgErr(err)
	}
	defer rows.Close()
	var out []domain.Account
	for rows.Next() {
		a, err := scanAccount(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *a)
	}
	return out, rows.Err()
}

func (r *accountRepo) GetBalance(ctx context.Context, accountID string) (int64, error) {
	var minor int64
	err := r.q.QueryRow(ctx, `
		SELECT COALESCE(balance_minor, 0) FROM balances WHERE account_id = $1::uuid`, accountID).Scan(&minor)
	if err != nil {
		// No balance row yet simply means zero.
		if mapErr := mapPgErr(err); mapErr == domain.ErrNotFound {
			return 0, nil
		}
		return 0, mapPgErr(err)
	}
	return minor, nil
}

func (r *accountRepo) SetBalance(ctx context.Context, accountID string, minor int64) error {
	_, err := r.q.Exec(ctx, `
		INSERT INTO balances (account_id, balance_minor, updated_at)
		VALUES ($1::uuid, $2, now())
		ON CONFLICT (account_id) DO UPDATE SET balance_minor = EXCLUDED.balance_minor, updated_at = now()`,
		accountID, minor)
	return mapPgErr(err)
}
