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

func (r *indexerEventRepo) ListUnattributed(ctx context.Context, limit int) ([]domain.IndexerEvent, error) {
	if limit <= 0 {
		limit = 200
	}
	rows, err := r.q.Query(ctx,
		`SELECT tx_hash, log_index, block_number, event_type, from_addr, to_addr, value_base
		   FROM indexer_events
		  WHERE event_type = 'unattributed'
		  ORDER BY block_number DESC, log_index DESC, ingested_at DESC
		  LIMIT $1`,
		limit,
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

func (r *indexerEventRepo) FindByTxAndLog(ctx context.Context, txHash string, logIndex uint64) (*domain.IndexerEvent, error) {
	row := r.q.QueryRow(ctx,
		`SELECT tx_hash, log_index, block_number, event_type, from_addr, to_addr, value_base
		   FROM indexer_events
		  WHERE tx_hash=$1 AND log_index=$2`,
		txHash, logIndex)
	var e domain.IndexerEvent
	if err := row.Scan(&e.TxHash, &e.LogIndex, &e.BlockNumber, &e.EventType, &e.From, &e.To, &e.ValueBase); err != nil {
		return nil, mapPgErr(err)
	}
	return &e, nil
}

func (r *indexerEventRepo) MarkAttributed(ctx context.Context, txHash string, logIndex uint64) error {
	tag, err := r.q.Exec(ctx,
		`UPDATE indexer_events
		    SET event_type = 'deposited'
		  WHERE tx_hash=$1 AND log_index=$2 AND event_type = 'unattributed'`,
		txHash, logIndex)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
