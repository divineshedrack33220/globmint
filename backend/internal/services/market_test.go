package services

import (
	"context"
	"errors"
	"testing"

	"globmint/backend/internal/domain"
)

// Seeded book values (see 0004_seed_rates.sql); restored after the test so
// the shared test database keeps its documented state.
var seededBookRates = map[[2]string]int64{
	{"USDT", "NGN"}: 160450,
	{"USDC", "NGN"}: 160000,
}

func TestSyncMarketRate_UpdatesBookPairs(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	repo := st.ExchangeRateRepo()

	if err := SyncMarketRate(ctx, repo, 170000); err != nil {
		t.Fatalf("sync: %v", err)
	}
	for pair := range seededBookRates {
		er, err := repo.FindByPair(ctx, pair[0], pair[1])
		if err != nil {
			t.Fatalf("find %v: %v", pair, err)
		}
		if er.Rate != 170000 {
			t.Errorf("%v rate = %d, want 170000", pair, er.Rate)
		}
	}

	if err := SyncMarketRate(ctx, repo, 0); err == nil {
		t.Error("expected an error for a non-positive rate")
	}
	if err := repo.UpdateRate(ctx, "XXX", "NGN", 1); !errors.Is(err, domain.ErrNotFound) {
		t.Errorf("missing pair err = %v, want ErrNotFound", err)
	}

	for pair, want := range seededBookRates {
		if err := repo.UpdateRate(ctx, pair[0], pair[1], want); err != nil {
			t.Fatalf("restore %v: %v", pair, err)
		}
	}
}
