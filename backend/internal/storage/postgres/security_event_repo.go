package postgres

import (
	"context"
	"encoding/json"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type securityEventRepo struct{ q Querier }

// NewSecurityEventRepo returns a SecurityEventRepository bound to the given querier.
func NewSecurityEventRepo(q Querier) storage.SecurityEventRepository { return &securityEventRepo{q: q} }

const securityEventCols = `id::text, user_id::text, type, severity, title, detail, ip, user_agent, device_id, device, metadata, created_at`

func scanSecurityEvent(row pgxRow) (*domain.SecurityEvent, error) {
	e := &domain.SecurityEvent{}
	var meta []byte
	if err := row.Scan(
		&e.ID, &e.UserID, (*string)(&e.Type), (*string)(&e.Severity),
		&e.Title, &e.Detail, &e.IP, &e.UserAgent, &e.DeviceID, &e.Device,
		&meta, &e.CreatedAt,
	); err != nil {
		return nil, err
	}
	if len(meta) > 0 {
		_ = json.Unmarshal(meta, &e.Metadata)
	}
	return e, nil
}

func (r *securityEventRepo) Create(ctx context.Context, e *domain.SecurityEvent) error {
	if e.Severity == "" {
		e.Severity = domain.SeverityInfo
	}
	var meta []byte
	if len(e.Metadata) > 0 {
		var err error
		if meta, err = json.Marshal(e.Metadata); err != nil {
			return err
		}
	}
	err := r.q.QueryRow(ctx, `
		INSERT INTO security_events (user_id, type, severity, title, detail, ip, user_agent, device_id, device, metadata)
		VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id::text, created_at`,
		e.UserID, string(e.Type), string(e.Severity), e.Title, e.Detail, e.IP, e.UserAgent, e.DeviceID, e.Device, meta,
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

func (r *securityEventRepo) ListByUserPaged(ctx context.Context, userID string, limit, offset int) ([]domain.SecurityEvent, int, error) {
	if limit <= 0 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}
	rows, err := r.q.Query(ctx, `
		SELECT `+securityEventCols+`,
		       count(*) OVER() AS total
		FROM security_events
		WHERE user_id = $1::uuid
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3`, userID, limit, offset)
	if err != nil {
		return nil, 0, mapPgErr(err)
	}
	defer rows.Close()
	var out []domain.SecurityEvent
	total := 0
	for rows.Next() {
		e := &domain.SecurityEvent{}
		var meta []byte
		if err := rows.Scan(
			&e.ID, &e.UserID, (*string)(&e.Type), (*string)(&e.Severity),
			&e.Title, &e.Detail, &e.IP, &e.UserAgent, &e.DeviceID, &e.Device,
			&meta, &e.CreatedAt, &total,
		); err != nil {
			return nil, 0, err
		}
		if len(meta) > 0 {
			_ = json.Unmarshal(meta, &e.Metadata)
		}
		out = append(out, *e)
	}
	return out, total, rows.Err()
}