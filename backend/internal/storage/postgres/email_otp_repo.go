package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type emailOTPRepo struct{ q Querier }

// NewEmailOTPRepo returns an EmailOTPRepository bound to the given querier.
func NewEmailOTPRepo(q Querier) storage.EmailOTPRepository { return &emailOTPRepo{q: q} }

func (r *emailOTPRepo) Upsert(ctx context.Context, otp *domain.EmailOTP) error {
	// A resend (payload columns empty) replaces the code but deliberately
	// preserves any staged registration payload already on the row: only the
	// INSERT carries the optional signup columns, the conflict branch never
	// touches them.
	_, err := r.q.Exec(ctx, `
		INSERT INTO email_otps (email, code_hash, expires_at, next_send_at, attempts, first_name, last_name, phone, password_hash)
		VALUES ($1, $2, $3, $4, 0, $5, $6, $7, $8)
		ON CONFLICT (email) DO UPDATE SET
			code_hash   = EXCLUDED.code_hash,
			expires_at  = EXCLUDED.expires_at,
			next_send_at = EXCLUDED.next_send_at,
			attempts    = 0,
			updated_at  = now()`,
		otp.Email, otp.CodeHash, otp.ExpiresAt, otp.NextSendAt,
		nullableStr(otp.FirstName), nullableStr(otp.LastName), nullableStr(otp.Phone), nullableStr(otp.PasswordHash))
	return mapPgErr(err)
}

func (r *emailOTPRepo) FindByEmail(ctx context.Context, email string) (*domain.EmailOTP, error) {
	row := r.q.QueryRow(ctx, `
		SELECT email, code_hash, expires_at, next_send_at, attempts,
		       COALESCE(first_name, ''), COALESCE(last_name, ''), COALESCE(phone, ''), COALESCE(password_hash, ''),
		       created_at, updated_at
		FROM email_otps WHERE email = $1`, email)

	otp := &domain.EmailOTP{}
	if err := row.Scan(
		&otp.Email, &otp.CodeHash, &otp.ExpiresAt, &otp.NextSendAt,
		&otp.Attempts, &otp.FirstName, &otp.LastName, &otp.Phone, &otp.PasswordHash,
		&otp.CreatedAt, &otp.UpdatedAt,
	); err != nil {
		return nil, mapPgErr(err)
	}
	return otp, nil
}

// nullableStr returns NULL for "" so clean rows never store empty signup
// payloads, and an empty string maps to NULL on resends (payload preserved).
func nullableStr(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func (r *emailOTPRepo) IncrementAttempts(ctx context.Context, email string) error {
	_, err := r.q.Exec(ctx, `UPDATE email_otps SET attempts = attempts + 1, updated_at = now() WHERE email = $1`, email)
	return mapPgErr(err)
}

func (r *emailOTPRepo) Clear(ctx context.Context, email string) error {
	_, err := r.q.Exec(ctx, `DELETE FROM email_otps WHERE email = $1`, email)
	return mapPgErr(err)
}
