package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type securityEventRepo struct{ q Querier }

// NewSecurityEventRepo returns a SecurityEventRepository bound to the given querier.
func NewSecurityEventRepo(q Querier) storage.SecurityEventRepository { return &securityEventRepo{q: q} }

const securityEventCols = `id::text, user_id::text, type, title, detail, ip, device, created_at`

func scanSecurityEvent(row pgxRow) (*domain.SecurityEvent, error) {
	e := &domain.SecurityEvent{}
	if err := row.Scan(&e.ID, &e.UserID, (*string)(&e.Type), &e.Title, &e.Detail, &e.IP, &e.Device, &e.CreatedAt); err != nil {
		return nil, err
	}
	return e, nil
}

func (r *securityEventRepo) Create(ctx context.Context, e *domain.SecurityEvent) error {
	err := r.q.QueryRow(ctx, `
		INSERT INTO security_events (user_id, type, title, detail, ip, device)
		VALUES ($1::uuid, $2, $3, $4, $5, $6)
		RETURNING id::text, created_at`,
		e.UserID, string(e.Type), e.Title, e.Detail, e.IP, e.Device,
	).Scan(&e.ID, &e.CreatedAt)
	return mapPgErr(err)
}

func (r *securityEventRepo) ListByUser(ctx context.Context, userID string, limit int) ([]domain.SecurityEvent, error) {
	rows, err := r.q.Query(ctx, `
		SELECT `+securityEventCols+` FROM security_events
		WHERE user_id = $1::uuid ORDER BY created_at DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, mapPgErr(err)
	}
	defer rows.Close()
	var out []domain.SecurityEvent
	for rows.Next() {
		e, err := scanSecurityEvent(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *e)
	}
	return out, rows.Err()
}
