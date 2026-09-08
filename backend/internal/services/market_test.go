package services

import (
	"context"
	"errors"
	"testing"

	"globmint/backend/internal/domain"
)

// Book rates are written by the live market feed only (no invented seeds).
// This is the last real value persisted in the shared test database; restored
// after the test so the shared book keeps its documented state.
var seededBookRates = map[[2]string]int64{
	{"USDT", "NGN"}: 132192,
	{"USDC", "NGN"}: 132192,
	{"NGN", "USDT"}: 132192,
	{"NGN", "USDC"}: 132192,
}

func TestConvertCrossQuotes_DirectionAware(t *testing.T) {
	const rate = int64(160450) // ₦1604.50 per 1 USDC

	// 6000.00 NGN -> USDC: 600000 kobo * 100 / 160450 ≈ 3.74 USDC (374 minor).
	out, err := convertCrossQuotes(600000, rate, "NGN", "USDC")
	if err != nil {
		t.Fatalf("ngn->usdc: %v", err)
	}
	if out != 374 {
		t.Errorf("ngn->usdc = %d minor, want 374 (3.74 USDC)", out)
	}

	// 500.00 USDC -> NGN: 50000 minor * 160450 / 100 = 80225000 kobo (₦802250).
	out, err = convertCrossQuotes(50000, rate, "USDC", "NGN")
	if err != nil {
		t.Fatalf("usdc->ngn: %v", err)
	}
	if out != 80225000 {
		t.Errorf("usdc->ngn = %d kobo, want 80225000", out)
	}

	if _, err := convertCrossQuotes(600000, 0, "NGN", "USDC"); err == nil {
		t.Error("expected error for zero rate")
	}
	if _, err := convertCrossQuotes(600000, rate, "USDT", "USDC"); err == nil {
		t.Error("expected error for an unsupported pair")
	}
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
