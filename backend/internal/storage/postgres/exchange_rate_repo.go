package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type exchangeRateRepo struct{ q Querier }

func NewExchangeRateRepo(q Querier) storage.ExchangeRateRepository { return &exchangeRateRepo{q: q} }

const exchangeRateCols = `id::text, base, quote, rate_minor, fee_bps, min_minor, max_minor, status, created_at, updated_at`

func scanExchangeRate(row pgxRow) (*domain.ExchangeRate, error) {
	r := &domain.ExchangeRate{}
	if err := row.Scan(&r.ID, &r.Base, &r.Quote, &r.Rate, &r.FeeBPS, &r.MinMinor, &r.MaxMinor, &r.Status, &r.CreatedAt, &r.UpdatedAt); err != nil {
		return nil, err
	}
	return r, nil
}

func (r *exchangeRateRepo) FindByPair(ctx context.Context, base, quote string) (*domain.ExchangeRate, error) {
	row := r.q.QueryRow(ctx, `
		SELECT `+exchangeRateCols+` FROM exchange_rates
		WHERE base=$1 AND quote=$2 AND status='active'`, base, quote)
	rate, err := scanExchangeRate(row)
	if err != nil {
		return nil, mapPgErr(err)
	}
	return rate, nil
}

func (r *exchangeRateRepo) UpdateRate(ctx context.Context, base, quote string, rateMinor int64) error {
	tag, err := r.q.Exec(ctx, `
		UPDATE exchange_rates
		   SET rate_minor=$3, updated_at=now()
		 WHERE base=$1 AND quote=$2 AND status='active'`, base, quote, rateMinor)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
