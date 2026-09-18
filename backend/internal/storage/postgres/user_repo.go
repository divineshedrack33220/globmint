package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type userRepo struct{ q Querier }

// NewUserRepo returns a UserRepository bound to the given querier.
func NewUserRepo(q Querier) storage.UserRepository { return &userRepo{q: q} }

const userCols = `id::text, email, phone, first_name, last_name, password_hash, COALESCE(pin_hash,'') AS pin_hash, COALESCE(totp_secret,'') AS totp_secret, totp_enabled, status, created_at, updated_at, email_verified_at`

func scanUser(row pgxRow) (*domain.User, error) {
	u := &domain.User{}
	err := row.Scan(
		&u.ID, &u.Email, &u.Phone, &u.FirstName, &u.LastName,
		&u.PasswordHash, &u.PINHash, &u.TOTPSecret, &u.TOTPEnabled,
		&u.Status, &u.CreatedAt, &u.UpdatedAt, &u.EmailVerifiedAt,
	)
	if err != nil {
		return nil, mapPgErr(err)
	}
	return u, nil
}

func (r *userRepo) Create(ctx context.Context, u *domain.User) error {
	err := r.q.QueryRow(ctx, `
		INSERT INTO users (email, phone, first_name, last_name, password_hash, status, email_verified_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING `+userCols,
		u.Email, u.Phone, u.FirstName, u.LastName, u.PasswordHash, u.Status, u.EmailVerifiedAt,
	).Scan(&u.ID, &u.Email, &u.Phone, &u.FirstName, &u.LastName, &u.PasswordHash, &u.PINHash, &u.TOTPSecret, &u.TOTPEnabled, &u.Status, &u.CreatedAt, &u.UpdatedAt, &u.EmailVerifiedAt)
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

func (r *userRepo) UpdatePIN(ctx context.Context, id, pinHash string) error {
	tag, err := r.q.Exec(ctx, `UPDATE users SET pin_hash = $2, updated_at = now() WHERE id = $1::uuid`, id, pinHash)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *userRepo) UpdatePassword(ctx context.Context, id, passwordHash string) error {
	tag, err := r.q.Exec(ctx, `UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1::uuid`, id, passwordHash)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *userRepo) UpdateTOTP(ctx context.Context, id, secret string, enabled bool) error {
	tag, err := r.q.Exec(ctx, `UPDATE users SET totp_secret = $2, totp_enabled = $3, updated_at = now() WHERE id = $1::uuid`, id, secret, enabled)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *userRepo) MarkEmailVerified(ctx context.Context, id string) error {
	tag, err := r.q.Exec(ctx, `
		UPDATE users SET email_verified_at = COALESCE(email_verified_at, now()), updated_at = now()
		WHERE id = $1::uuid`, id)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *userRepo) NotificationPrefs(ctx context.Context, id string) (bool, bool, error) {
	var newSignin, failedLogin bool
	err := r.q.QueryRow(ctx, `
		SELECT COALESCE(notify_new_signin, TRUE), COALESCE(notify_failed_login, TRUE)
		FROM users WHERE id = $1::uuid`, id).Scan(&newSignin, &failedLogin)
	if err != nil {
		return false, false, mapPgErr(err)
	}
	return newSignin, failedLogin, nil
}

func (r *userRepo) UpdateNotificationPrefs(ctx context.Context, id string, newSignin, failedLogin bool) error {
	tag, err := r.q.Exec(ctx, `
		UPDATE users
		SET notify_new_signin = $2, notify_failed_login = $3, updated_at = now()
		WHERE id = $1::uuid`, id, newSignin, failedLogin)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
