package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"globmint/backend/internal/domain"
)

type vaultCloneRepo struct {
	q Querier
}

func NewVaultCloneRepo(q Querier) *vaultCloneRepo {
	return &vaultCloneRepo{q: q}
}

func (r *vaultCloneRepo) Ensure(ctx context.Context, c *domain.VaultClone) error {
	_, err := r.q.Exec(ctx,
		`INSERT INTO user_vault_clones (user_id, clone_address, factory_address, deploy_tx_hash, chain_id)
		 VALUES ($1, $2, $3, $4, $5)
		 ON CONFLICT (user_id) DO NOTHING`,
		c.UserID, c.CloneAddress, c.FactoryAddress, c.DeployTxHash, c.ChainID)
	return mapPgErr(err)
}

func (r *vaultCloneRepo) ByUser(ctx context.Context, userID string) (*domain.VaultClone, error) {
	row := r.q.QueryRow(ctx,
		`SELECT user_id, clone_address, factory_address, deploy_tx_hash, chain_id, created_at
		   FROM user_vault_clones
		  WHERE user_id = $1`, userID)
	var c domain.VaultClone
	if err := row.Scan(&c.UserID, &c.CloneAddress, &c.FactoryAddress, &c.DeployTxHash, &c.ChainID, &c.CreatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, mapPgErr(err)
	}
	return &c, nil
}

func (r *vaultCloneRepo) All(ctx context.Context) ([]domain.VaultClone, error) {
	rows, err := r.q.Query(ctx,
		`SELECT user_id, clone_address, factory_address, deploy_tx_hash, chain_id, created_at
		   FROM user_vault_clones
		  ORDER BY created_at`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.VaultClone
	for rows.Next() {
		var c domain.VaultClone
		if err := rows.Scan(&c.UserID, &c.CloneAddress, &c.FactoryAddress, &c.DeployTxHash, &c.ChainID, &c.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// CacheRecovery stores the backend's cached snapshot of a clone's on-chain
// ownership + recovery state. The chain remains authoritative; this cache lets
// API reads survive a node outage and powers the reconciler's refresh loop.
func (r *vaultCloneRepo) CacheRecovery(ctx context.Context, userID string, rec *domain.CloneRecovery) error {
	if rec == nil {
		return errors.New("nil recovery cache")
	}
	var requestedAt any
	if rec.RecoveryRequestedAt > 0 {
		requestedAt = time.Unix(rec.RecoveryRequestedAt, 0).UTC()
	}
	_, err := r.q.Exec(ctx,
		`UPDATE user_vault_clones
		    SET owner_address = $2,
		        recovery_address = $3,
		        recovery_delay = $4,
		        recovery_requested_at = $5
		  WHERE user_id = $1`,
		userID, rec.Owner, rec.RecoveryAddress, int64(rec.RecoveryDelay), requestedAt)
	return mapPgErr(err)
}

// RecoveryCache returns the last cached ownership + recovery snapshot for a
// user's clone, or nil when nothing has been cached yet.
func (r *vaultCloneRepo) RecoveryCache(ctx context.Context, userID string) (*domain.CloneRecovery, error) {
	row := r.q.QueryRow(ctx,
		`SELECT COALESCE(owner_address, ''), COALESCE(recovery_address, ''),
		        COALESCE(recovery_delay, 0), recovery_requested_at
		   FROM user_vault_clones
		  WHERE user_id = $1`, userID)
	var rec domain.CloneRecovery
	var requestedAt *time.Time
	if err := row.Scan(&rec.Owner, &rec.RecoveryAddress, &rec.RecoveryDelay, &requestedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, mapPgErr(err)
	}
	if requestedAt != nil {
		rec.RecoveryRequestedAt = requestedAt.Unix()
	}
	return &rec, nil
}