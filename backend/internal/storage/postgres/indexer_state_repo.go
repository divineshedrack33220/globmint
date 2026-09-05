package postgres

import (
	"context"

	"globmint/backend/internal/storage"
)

const indexerStateSingleton = true

// IndexerStateRepository persists the vault indexer cursor in the singleton
// `indexer_state` row (migration 0006). Reads/writes are single-row upserts so
// they cannot drift with multiple indexer processes.
type indexerStateRepo struct {
	q Querier
}

// NewIndexerStateRepo builds the repository.
func NewIndexerStateRepo(q Querier) storage.IndexerStateRepository {
	return &indexerStateRepo{q: q}
}

func (r *indexerStateRepo) LastBlock(ctx context.Context) (uint64, error) {
	var last uint64
	err := r.q.QueryRow(ctx,
		`SELECT last_block FROM indexer_state WHERE singleton = $1`, indexerStateSingleton,
	).Scan(&last)
	if err != nil {
		return 0, err
	}
	return last, nil
}

func (r *indexerStateRepo) SetLastBlock(ctx context.Context, lastBlock uint64) error {
	_, err := r.q.Exec(ctx,
		`INSERT INTO indexer_state (singleton, last_block, updated_at)
		 VALUES ($1, $2, now())
		 ON CONFLICT (singleton) DO UPDATE SET last_block = EXCLUDED.last_block, updated_at = now()`,
		indexerStateSingleton, lastBlock,
	)
	return err
}