package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type bankAccountRepo struct{ q Querier }

func NewBankAccountRepo(q Querier) storage.BankAccountRepository { return &bankAccountRepo{q: q} }

const bankAccountCols = `id::text, user_id::text, bank_name, bank_code, account_number, account_name, is_default, created_at`

func scanBankAccount(row pgxRow) (*domain.BankAccount, error) {
	a := &domain.BankAccount{}
	if err := row.Scan(&a.ID, &a.UserID, &a.BankName, &a.BankCode, &a.AccountNumber, &a.AccountName, &a.IsDefault, &a.CreatedAt); err != nil {
		return nil, err
	}
	return a, nil
}

func (r *bankAccountRepo) Create(ctx context.Context, a *domain.BankAccount) error {
	err := r.q.QueryRow(ctx, `
		INSERT INTO bank_accounts (user_id, bank_name, bank_code, account_number, account_name, is_default)
		VALUES ($1::uuid, $2, $3, $4, $5, $6)
		RETURNING `+bankAccountCols,
		a.UserID, a.BankName, a.BankCode, a.AccountNumber, a.AccountName, a.IsDefault,
	).Scan(&a.ID, &a.UserID, &a.BankName, &a.BankCode, &a.AccountNumber, &a.AccountName, &a.IsDefault, &a.CreatedAt)
	return mapPgErr(err)
}

func (r *bankAccountRepo) ListByUser(ctx context.Context, userID string) ([]domain.BankAccount, error) {
	rows, err := r.q.Query(ctx, `SELECT `+bankAccountCols+` FROM bank_accounts WHERE user_id = $1::uuid ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, mapPgErr(err)
	}
	defer rows.Close()
	var out []domain.BankAccount
	for rows.Next() {
		a, err := scanBankAccount(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *a)
	}
	return out, rows.Err()
}

func (r *bankAccountRepo) Delete(ctx context.Context, userID, id string) error {
	tag, err := r.q.Exec(ctx, `DELETE FROM bank_accounts WHERE id=$1::uuid AND user_id=$2::uuid`, id, userID)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *bankAccountRepo) SetDefault(ctx context.Context, userID, id string) error {
	tag, err := r.q.Exec(ctx, `
		UPDATE bank_accounts SET is_default = (id = $1::uuid)
		WHERE user_id = $2::uuid`, id, userID)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *bankAccountRepo) SetNotDefault(ctx context.Context, userID string) error {
	_, err := r.q.Exec(ctx, `UPDATE bank_accounts SET is_default = FALSE WHERE user_id = $1::uuid`, userID)
	return mapPgErr(err)
}
