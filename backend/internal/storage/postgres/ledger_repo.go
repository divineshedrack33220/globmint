package postgres

import (
	"context"
	"encoding/json"
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type ledgerRepo struct{ q Querier }

// NewLedgerRepo returns a LedgerRepository bound to the given querier.
func NewLedgerRepo(q Querier) storage.LedgerRepository { return &ledgerRepo{q: q} }

const txnCols = `id::text, user_id::text, type, status, currency, amount_minor, fee_minor,
	exchange_rate, reference, provider_ref, idempotency_key, metadata, created_at, updated_at`

func scanTransaction(row pgxRow) (*domain.Transaction, error) {
	t := &domain.Transaction{}
	var meta []byte
	if err := row.Scan(
		&t.ID, &t.UserID, &t.Type, &t.Status, &t.Currency, &t.AmountMinor,
		&t.FeeMinor, &t.ExchangeRate, &t.Reference, &t.ProviderRef,
		&t.IdempotencyKey, &meta, &t.CreatedAt, &t.UpdatedAt,
	); err != nil {
		return nil, err
	}
	if len(meta) > 0 {
		_ = json.Unmarshal(meta, &t.Metadata)
	}
	return t, nil
}

func (r *ledgerRepo) CreateTransaction(ctx context.Context, t *domain.Transaction) error {
	meta, _ := json.Marshal(t.Metadata)
	err := r.q.QueryRow(ctx, `
		INSERT INTO transactions
			(user_id, type, status, currency, amount_minor, fee_minor, exchange_rate,
			 reference, provider_ref, idempotency_key, metadata)
		VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb)
		RETURNING `+txnCols,
		t.UserID, t.Type, t.Status, t.Currency, t.AmountMinor, t.FeeMinor, t.ExchangeRate,
		t.Reference, t.ProviderRef, t.IdempotencyKey, meta,
	).Scan(
		&t.ID, &t.UserID, &t.Type, &t.Status, &t.Currency, &t.AmountMinor,
		&t.FeeMinor, &t.ExchangeRate, &t.Reference, &t.ProviderRef,
		&t.IdempotencyKey, &meta, &t.CreatedAt, &t.UpdatedAt,
	)
	return mapPgErr(err)
}

func (r *ledgerRepo) FindTransactionByID(ctx context.Context, id string) (*domain.Transaction, error) {
	row := r.q.QueryRow(ctx, `SELECT `+txnCols+` FROM transactions WHERE id = $1::uuid`, id)
	return scanTransaction(row)
}

func (r *ledgerRepo) FindTransactionByIDempotencyKey(ctx context.Context, key string) (*domain.Transaction, error) {
	row := r.q.QueryRow(ctx, `SELECT `+txnCols+` FROM transactions WHERE idempotency_key = $1`, key)
	t, err := scanTransaction(row)
	if err != nil {
		return nil, mapPgErr(err)
	}
	return t, nil
}

func (r *ledgerRepo) ListTransactionsByUser(ctx context.Context, userID string) ([]domain.Transaction, error) {
	rows, err := r.q.Query(ctx, `SELECT `+txnCols+` FROM transactions WHERE user_id = $1::uuid ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, mapPgErr(err)
	}
	defer rows.Close()
	var out []domain.Transaction
	for rows.Next() {
		t, err := scanTransaction(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *t)
	}
	return out, rows.Err()
}

func (r *ledgerRepo) InsertEntry(ctx context.Context, e *domain.LedgerEntry) error {
	err := r.q.QueryRow(ctx, `
		INSERT INTO ledger_entries
			(transaction_id, account_id, user_id, movement, currency, amount_minor)
		VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6)
		RETURNING id::text, created_at`,
		e.TransactionID, e.AccountID, e.UserID, e.Movement, e.Currency, e.AmountMinor,
	).Scan(&e.ID, &e.CreatedAt)
	return mapPgErr(err)
}

// SumBalanceByAccount returns the authoritative balance (credits - debits)
// derived directly from the immutable ledger.
func (r *ledgerRepo) SumBalanceByAccount(ctx context.Context, accountID string) (int64, error) {
	var sum int64
	err := r.q.QueryRow(ctx, `
		SELECT COALESCE(SUM(CASE WHEN movement = 'credit' THEN amount_minor ELSE -amount_minor END), 0)
		FROM ledger_entries WHERE account_id = $1::uuid`, accountID).Scan(&sum)
	return sum, mapPgErr(err)
}

// SumWithdrawalsSince returns the total amount_minor of the user's withdrawal
// transactions created at or after `since` (used for daily spending caps).
func (r *ledgerRepo) SumWithdrawalsSince(ctx context.Context, userID string, since time.Time) (int64, error) {
	var sum int64
	err := r.q.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount_minor), 0)
		FROM transactions
		WHERE user_id = $1::uuid
		  AND type = 'withdrawal'
		  AND status <> 'failed'
		  AND status <> 'cancelled'
		  AND created_at >= $2`, userID, since).Scan(&sum)
	return sum, mapPgErr(err)
}

func (r *ledgerRepo) ListEntriesByAccount(ctx context.Context, accountID string) ([]domain.LedgerEntry, error) {
	rows, err := r.q.Query(ctx, `
		SELECT id::text, transaction_id::text, account_id::text, user_id::text, movement, currency, amount_minor, created_at
		FROM ledger_entries WHERE account_id = $1::uuid ORDER BY created_at`, accountID)
	if err != nil {
		return nil, mapPgErr(err)
	}
	defer rows.Close()
	var out []domain.LedgerEntry
	for rows.Next() {
		e := domain.LedgerEntry{}
		if err := rows.Scan(&e.ID, &e.TransactionID, &e.AccountID, &e.UserID, &e.Movement, &e.Currency, &e.AmountMinor, &e.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
