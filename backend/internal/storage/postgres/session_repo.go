package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type sessionRepo struct{ q Querier }

// NewSessionRepo returns a SessionRepository bound to the given querier.
func NewSessionRepo(q Querier) storage.SessionRepository { return &sessionRepo{q: q} }

func (r *sessionRepo) Create(ctx context.Context, s *domain.Session) error {
	err := r.q.QueryRow(ctx, `
		INSERT INTO sessions (user_id, token_hash, device, ip, expires_at)
		VALUES ($1::uuid, $2, $3, $4, $5)
		RETURNING id::text, created_at`,
		s.UserID, s.TokenHash, s.Device, s.IP, s.ExpiresAt,
	).Scan(&s.ID, &s.CreatedAt)
	return mapPgErr(err)
}

func scanSession(row pgxRow) (*domain.Session, error) {
	s := &domain.Session{}
	if err := row.Scan(
		&s.ID, &s.UserID, &s.TokenHash, &s.Device, &s.IP,
		&s.ExpiresAt, &s.RevokedAt, &s.CreatedAt,
	); err != nil {
		return nil, err
	}
	return s, nil
}

func (r *sessionRepo) FindByTokenHash(ctx context.Context, hash string) (*domain.Session, error) {
	row := r.q.QueryRow(ctx, `
		SELECT id::text, user_id::text, token_hash, device, ip, expires_at, revoked_at, created_at
		FROM sessions WHERE token_hash = $1`, hash)
	return scanSession(row)
}

func (r *sessionRepo) Revoke(ctx context.Context, id string) error {
	tag, err := r.q.Exec(ctx, `UPDATE sessions SET revoked_at = now() WHERE id = $1::uuid AND revoked_at IS NULL`, id)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *sessionRepo) RevokeAllForUser(ctx context.Context, userID string) error {
	_, err := r.q.Exec(ctx, `UPDATE sessions SET revoked_at = now() WHERE user_id = $1::uuid AND revoked_at IS NULL`, userID)
	return mapPgErr(err)
}
