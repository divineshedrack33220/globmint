package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type notificationRepo struct{ q Querier }

// NewNotificationRepo returns a NotificationRepository bound to the given querier.
func NewNotificationRepo(q Querier) storage.NotificationRepository { return &notificationRepo{q: q} }

const notificationCols = `id::text, user_id::text, category, title, body, is_read, created_at`

func scanNotification(row pgxRow) (*domain.Notification, error) {
	n := &domain.Notification{}
	if err := row.Scan(&n.ID, &n.UserID, (*string)(&n.Category), &n.Title, &n.Body, &n.IsRead, &n.CreatedAt); err != nil {
		return nil, err
	}
	return n, nil
}

func (r *notificationRepo) Create(ctx context.Context, n *domain.Notification) error {
	err := r.q.QueryRow(ctx, `
		INSERT INTO notifications (user_id, category, title, body)
		VALUES ($1::uuid, $2, $3, $4)
		RETURNING id::text, created_at`,
		n.UserID, string(n.Category), n.Title, n.Body,
	).Scan(&n.ID, &n.CreatedAt)
	return mapPgErr(err)
}

func (r *notificationRepo) ListByUser(ctx context.Context, userID string, limit int) ([]domain.Notification, error) {
	rows, err := r.q.Query(ctx, `
		SELECT `+notificationCols+` FROM notifications
		WHERE user_id = $1::uuid ORDER BY created_at DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, mapPgErr(err)
	}
	defer rows.Close()
	var out []domain.Notification
	for rows.Next() {
		n, err := scanNotification(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *n)
	}
	return out, rows.Err()
}

func (r *notificationRepo) CountUnread(ctx context.Context, userID string) (int, error) {
	var count int
	err := r.q.QueryRow(ctx, `SELECT count(*) FROM notifications WHERE user_id = $1::uuid AND is_read = FALSE`, userID).Scan(&count)
	return count, mapPgErr(err)
}

func (r *notificationRepo) MarkRead(ctx context.Context, userID, id string) error {
	tag, err := r.q.Exec(ctx, `
		UPDATE notifications SET is_read = TRUE WHERE id = $1::uuid AND user_id = $2::uuid AND is_read = FALSE`, id, userID)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *notificationRepo) MarkAllRead(ctx context.Context, userID string) error {
	_, err := r.q.Exec(ctx, `UPDATE notifications SET is_read = TRUE WHERE user_id = $1::uuid AND is_read = FALSE`, userID)
	return mapPgErr(err)
}
