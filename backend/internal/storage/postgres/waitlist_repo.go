package postgres

import (
	"context"

	"globmint/backend/internal/storage"
)

type waitlistRepo struct{ q Querier }

// NewWaitlistRepo returns a WaitlistRepository bound to the given querier.
func NewWaitlistRepo(q Querier) storage.WaitlistRepository { return &waitlistRepo{q: q} }

func (r *waitlistRepo) Join(ctx context.Context, signup storage.WaitlistSignup) error {
	_, err := r.q.Exec(ctx, `
		INSERT INTO waitlist (email, source, ip_hash, user_agent)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (email_lower) DO NOTHING`,
		signup.Email, signup.Source, signup.IPHash, signup.UserAgent)
	return mapPgErr(err)
}

func (r *waitlistRepo) Count(ctx context.Context) (int, error) {
	var n int
	if err := r.q.QueryRow(ctx, `SELECT count(*) FROM waitlist`).Scan(&n); err != nil {
		return 0, mapPgErr(err)
	}
	return n, nil
}
