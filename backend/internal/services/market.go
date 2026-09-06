package services

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

// marketNGNPairs are the rate-book rows quoted as "NGN per stablecoin". A
// single live market rate refreshes all of them; inverse rows (NGN->*) use
// different unit semantics and are left untouched.
var marketNGNPairs = [][2]string{{"USDT", "NGN"}, {"USDC", "NGN"}}

// SyncMarketRate records a live NGN-per-stable rate (kobo) into the rate book
// so quotes, vault conversions, and clients all price from one market value.
// The seeded rows remain the fallback whenever the feed is unreachable.
// Returns an error only if no pair could be updated.
func SyncMarketRate(ctx context.Context, repo storage.ExchangeRateRepository, rateMinor int64) error {
	if rateMinor <= 0 {
		return domain.ErrInvalidAmount
	}
	var updated int
	var firstErr error
	for _, pair := range marketNGNPairs {
		if err := repo.UpdateRate(ctx, pair[0], pair[1], rateMinor); err != nil {
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
