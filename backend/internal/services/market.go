package services

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

// marketCrossPairs are the rate-book rows quoted between NGN and a
// stablecoin. Every row — both directions — stores the same unit semantics
// (NGN minor units per 1 stablecoin major), so a single live market rate
// refreshes all of them and the book never drifts.
var marketCrossPairs = [][2]string{
	{"USDT", "NGN"},
	{"USDC", "NGN"},
	{"NGN", "USDC"},
	{"NGN", "USDT"},
}

// SyncMarketRate records a live NGN-per-stable rate (kobo) into the rate book
// so quotes, vault conversions, and clients all price from one real market
// value. Rows are upserted (created when missing) so a fresh database is
// populated from real feed data without invented seed prices. Returns an error
// only if no pair could be written.
func SyncMarketRate(ctx context.Context, repo storage.ExchangeRateRepository, rateMinor int64) error {
	if rateMinor <= 0 {
		return domain.ErrInvalidAmount
	}
	var updated int
	var firstErr error
	for _, pair := range marketCrossPairs {
		if err := repo.UpsertRate(ctx, pair[0], pair[1], rateMinor); err != nil {
			if firstErr == nil {
				firstErr = err
			}
			continue
		}
		updated++
	}
	if updated == 0 {
		return firstErr
	}
	return nil
}
