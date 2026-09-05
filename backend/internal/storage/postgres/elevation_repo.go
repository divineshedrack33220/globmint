package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

// ElevationRepository persists time-locked high-value withdrawals.
type elevationRepo struct {
	q Querier
}

// NewElevationRepo builds the repository.
func NewElevationRepo(q Querier) storage.ElevationRepository {
	return &elevationRepo{q: q}
}

const elevationColumns = `id, user_id, destination, amount_ngn_minor, fee_minor, status,
	requested_at, release_after,
	COALESCE(broadcast_tx_hash, ''), broadcast_at, COALESCE(idempotency_key, '')`

func scanElevation(row pgx.Row) (*domain.WithdrawalElevation, error) {
	var e domain.WithdrawalElevation
	var status string
	err := row.Scan(&e.ID, &e.UserID, &e.Destination, &e.AmountNgnMinor, &e.FeeMinor, &status,
		&e.RequestedAt, &e.ReleaseAfter, &e.BroadcastTxHash, &e.BroadcastAt, &e.IdempotencyKey)
	if err != nil {
		return nil, err
	}
	e.Status = domain.WithdrawalElevationStatus(status)
	return &e, nil
}

func (r *elevationRepo) Create(ctx context.Context, e *domain.WithdrawalElevation) (*domain.WithdrawalElevation, error) {
	var id string
	// gen_random_uuid() is built-in on PG 13+; if the UUID is pre-set use it.
	err := r.q.QueryRow(ctx,
		`INSERT INTO withdrawal_elevations
			(id, user_id, destination, amount_ngn_minor, fee_minor, status, release_after, idempotency_key)
		 VALUES ((COALESCE(NULLIF($1, ''), gen_random_uuid()::text))::uuid, $2, $3, $4, $5, $6, $7, $8)
		 RETURNING id`,
		e.ID, e.UserID, e.Destination, e.AmountNgnMinor, e.FeeMinor, string(e.Status), e.ReleaseAfter, e.IdempotencyKey,
	).Scan(&id)
	if err != nil {
		return nil, err
	}
	e.ID = id
	return e, nil
}

func (r *elevationRepo) FindByUserAndID(ctx context.Context, userID, id string) (*domain.WithdrawalElevation, error) {
	return scanElevation(r.q.QueryRow(ctx,
		`SELECT `+elevationColumns+` FROM withdrawal_elevations WHERE id = $1 AND user_id = $2`,
		id, userID))
}

func (r *elevationRepo) FindDuePending(ctx context.Context, now time.Time) ([]domain.WithdrawalElevation, error) {
	rows, err := r.q.Query(ctx,
		`SELECT `+elevationColumns+` FROM withdrawal_elevations
		  WHERE status = 'pending' AND release_after <= $1
		  ORDER BY release_after LIMIT 100`, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.WithdrawalElevation
	for rows.Next() {
		e, err := scanElevation(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *e)
	}
	return out, rows.Err()
}

func (r *elevationRepo) FindPendingByContent(ctx context.Context, userID, destination string, amountNgnMinor int64) (*domain.WithdrawalElevation, error) {
	return scanElevation(r.q.QueryRow(ctx,
		`SELECT `+elevationColumns+` FROM withdrawal_elevations
		  WHERE user_id = $1 AND destination = $2 AND amount_ngn_minor = $3 AND status = 'pending'`,
		userID, destination, amountNgnMinor))
}

func (r *elevationRepo) ListPendingByUser(ctx context.Context, userID string) ([]domain.WithdrawalElevation, error) {
	rows, err := r.q.Query(ctx,
		`SELECT `+elevationColumns+` FROM withdrawal_elevations
		  WHERE user_id = $1 AND status = 'pending'
		  ORDER BY requested_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.WithdrawalElevation
	for rows.Next() {
		e, err := scanElevation(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *e)
	}
	return out, rows.Err()
}

func (r *elevationRepo) ClaimForBroadcast(ctx context.Context, id string) (bool, error) {
	var claimed bool
	err := r.q.QueryRow(ctx,
		`UPDATE withdrawal_elevations
		    SET status = 'broadcasting', updated_at = now()
		  WHERE id = $1 AND status = 'pending'
		  RETURNING TRUE`, id).Scan(&claimed)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return claimed, nil
}

func (r *elevationRepo) MarkBroadcast(ctx context.Context, id, txHash string) error {
	_, err := r.q.Exec(ctx,
		`UPDATE withdrawal_elevations
		    SET status = 'broadcast', broadcast_tx_hash = $2, broadcast_at = now(), updated_at = now()
		  WHERE id = $1`, id, txHash)
	return err
}

func (r *elevationRepo) ReleaseClaim(ctx context.Context, id string) error {
	_, err := r.q.Exec(ctx,
		`UPDATE withdrawal_elevations
		    SET status = 'pending', updated_at = now()
		  WHERE id = $1 AND status = 'broadcasting'`, id)
	return err
}

func (r *elevationRepo) CancelPending(ctx context.Context, userID, id string) error {
	tag, err := r.q.Exec(ctx,
		`UPDATE withdrawal_elevations
		    SET status = 'cancelled', updated_at = now()
		  WHERE id = $1 AND user_id = $2 AND status = 'pending'`, id, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}