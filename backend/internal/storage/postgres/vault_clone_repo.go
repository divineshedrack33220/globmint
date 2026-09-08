package postgres

import (
	"context"
	"errors"
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