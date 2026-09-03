package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type userRepo struct{ q Querier }

// NewUserRepo returns a UserRepository bound to the given querier.
func NewUserRepo(q Querier) storage.UserRepository { return &userRepo{q: q} }

const userCols = `id::text, email, phone, first_name, last_name, password_hash, status, created_at, updated_at`

func scanUser(row pgxRow) (*domain.User, error) {
	u := &domain.User{}
	err := row.Scan(
		&u.ID, &u.Email, &u.Phone, &u.FirstName, &u.LastName,
		&u.PasswordHash, &u.Status, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return u, nil
}

func (r *userRepo) Create(ctx context.Context, u *domain.User) error {
	err := r.q.QueryRow(ctx, `
		INSERT INTO users (email, phone, first_name, last_name, password_hash, status)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING `+userCols,
		u.Email, u.Phone, u.FirstName, u.LastName, u.PasswordHash, u.Status,
	).Scan(&u.ID, &u.Email, &u.Phone, &u.FirstName, &u.LastName, &u.PasswordHash, &u.Status, &u.CreatedAt, &u.UpdatedAt)
	return mapPgErr(err)
}

func (r *userRepo) FindByID(ctx context.Context, id string) (*domain.User, error) {
	row := r.q.QueryRow(ctx, `SELECT `+userCols+` FROM users WHERE id = $1::uuid`, id)
	return scanUser(row)
}

func (r *userRepo) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
	row := r.q.QueryRow(ctx, `SELECT `+userCols+` FROM users WHERE email = $1`, email)
	return scanUser(row)
}

func (r *userRepo) UpdateStatus(ctx context.Context, id string, status domain.UserStatus) error {
	tag, err := r.q.Exec(ctx, `UPDATE users SET status = $2, updated_at = now() WHERE id = $1::uuid`, id, status)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
