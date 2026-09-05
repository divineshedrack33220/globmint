package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

// IndexerEventRepository persists the durable vault-transfer event log.
type indexerEventRepo struct {
	q Querier
}

// NewIndexerEventRepo builds the repository.
func NewIndexerEventRepo(q Querier) storage.IndexerEventRepository {
	return &indexerEventRepo{q: q}
}

func (r *indexerEventRepo) Insert(ctx context.Context, evt *domain.IndexerEvent) error {
	_, err := r.q.Exec(ctx,
		`INSERT INTO indexer_events
			(tx_hash, log_index, block_number, event_type, from_addr, to_addr, value_base)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT (tx_hash, log_index) DO NOTHING`,
		evt.TxHash, evt.LogIndex, evt.BlockNumber, evt.EventType, evt.From, evt.To, evt.ValueBase,
	)
	return err
}

func (r *indexerEventRepo) ListByRange(ctx context.Context, fromBlock, toBlock uint64) ([]domain.IndexerEvent, error) {
	rows, err := r.q.Query(ctx,
		`SELECT tx_hash, log_index, block_number, event_type, from_addr, to_addr, value_base
		   FROM indexer_events
		  WHERE block_number BETWEEN $1 AND $2
		  ORDER BY block_number, log_index`,
		fromBlock, toBlock,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.IndexerEvent
	for rows.Next() {
		var e domain.IndexerEvent
		if err := rows.Scan(&e.TxHash, &e.LogIndex, &e.BlockNumber, &e.EventType, &e.From, &e.To, &e.ValueBase); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}