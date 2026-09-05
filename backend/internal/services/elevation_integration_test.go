package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/infrastructure/blockchain"
)

// newElevationVault builds a real-mode vault with the time-lock enabled.
func newElevationVault(t *testing.T, st store, userID string, threshold int64, delay time.Duration) *VaultService {
	t.Helper()
	return NewVaultService(st, blockchain.NewMockBlockchainService(), NewMoneyService(st), VaultConfig{
		VaultAddress:                     vaultAddr,
		StablecoinSymbol:                 "USDC",
		StablecoinDecimals:               6,
		Mode:                             "real",
		FallbackUserID:                   userID,
		WithdrawEnabled:                  true,
		WithdrawElevationThresholdMinor:  threshold,
		WithdrawElevationDelay:           delay,
	}, 160450)
}

func fundNGN(t *testing.T, st store, userID string, minor int64, key string) {
	t.Helper()
	if _, err := NewMoneyService(st).Deposit(context.Background(), userID, "NGN", minor, key); err != nil {
		t.Fatalf("fund NGN: %v", err)
	}
}

// TestWithdrawBelowThresholdBroadcastsImmediately: amounts under the elevation
// threshold take the existing instant path and debit the ledger.
func TestWithdrawBelowThresholdBroadcastsImmediately(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-elev-fast@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-fast-"+uniqueKey("k"))
	v := newElevationVault(t, st, u.ID, 10_000_000, time.Hour)

	res, err := v.WithdrawToAddress(ctx, u.ID, "0xDest000000000000000000000000000000000000", 5_000_000, "wd-fast-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("withdraw: %v", err)
	}
	if res.Transaction == nil || res.Elevation != nil {
		t.Fatalf("expected instant tx, got transaction=%v elevation=%v", res.Transaction != nil, res.Elevation != nil)
	}
	if bal := availNGN(t, st, u.ID); bal != 45_000_000 {
		t.Errorf("balance = %d, want 45000000 after instant withdrawal", bal)
	}
}

// TestElevationRequiresTimeLockThenCancel: high-value requests become pending
// elevations, nothing leaves the vault, and the user can cancel before release.
func TestElevationRequiresTimeLockThenCancel(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-elev-lock@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-lock-"+uniqueKey("k"))
	v := newElevationVault(t, st, u.ID, 10_000_000, time.Hour)

	res, err := v.WithdrawToAddress(ctx, u.ID, "0xDest000000000000000000000000000000000001", 20_000_000, "wd-lock-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("withdraw: %v", err)
	}
	if res.Transaction != nil {
		t.Fatalf("expected no instant tx for elevated amount")
	}
	e := res.Elevation
	if e == nil {
		t.Fatal("expected a pending elevation")
	}
	if e.Status != domain.ElevationPending {
		t.Errorf("status = %s, want pending", e.Status)
	}
	if !e.ReleaseAfter.After(time.Now()) {
		t.Errorf("release_after = %v, want future", e.ReleaseAfter)
	}
	// Nothing was debited: the ledger is untouched until release.
	if bal := availNGN(t, st, u.ID); bal != 50_000_000 {
		t.Errorf("balance changed while pending = %d, want 50000000", bal)
	}

	// User cancels before the time-lock elapses.
	if err := v.CancelElevation(ctx, u.ID, e.ID); err != nil {
		t.Fatalf("cancel: %v", err)
	}
	got, err := v.FindElevation(ctx, u.ID, e.ID)
	if err != nil {
		t.Fatalf("find elevation: %v", err)
	}
	if got.Status != domain.ElevationCancelled {
		t.Errorf("status after cancel = %s, want cancelled", got.Status)
	}

	// A fresh identical request is allowed again (the cancelled row does not
	// block the pending unique index).
	res2, err := v.WithdrawToAddress(ctx, u.ID, "0xDest000000000000000000000000000000000001", 20_000_000, "wd-lock2-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("second withdraw: %v", err)
	}
	if res2.Elevation == nil || res2.Elevation.ID == e.ID {
		t.Fatalf("expected a fresh pending elevation, got %+v", res2.Elevation)
	}
}

// TestElevationSweepBroadcastsExactlyOnce: a due pending elevation is claimed,
// broadcast and debited by the sweep; a second sweep does nothing.
func TestElevationSweepBroadcastsExactlyOnce(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-elev-sweep@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sweep-"+uniqueKey("k"))
	v := newElevationVault(t, st, u.ID, 10_000_000, time.Hour)

	beneficiary := "0xDest000000000000000000000000000000000002"
	e, err := st.ElevationRepo().Create(ctx, &domain.WithdrawalElevation{
		UserID:         u.ID,
		Destination:    beneficiary,
		AmountNgnMinor: 20_000_000,
		Status:         domain.ElevationPending,
		ReleaseAfter:   time.Now().UTC().Add(-time.Minute),
		IdempotencyKey: "elev-sweep-" + uniqueKey("k"),
	})
	if err != nil {
		t.Fatalf("create elevation: %v", err)
	}

	if err := v.sweepDueElevations(ctx); err != nil {
		t.Fatalf("sweep: %v", err)
	}

	got, err := st.ElevationRepo().FindByUserAndID(ctx, u.ID, e.ID)
	if err != nil {
		t.Fatalf("find elevation: %v", err)
	}
	if got.Status != domain.ElevationBroadcast || got.BroadcastTxHash == "" {
		t.Fatalf("elevation = status %s tx %q, want broadcast + tx hash", got.Status, got.BroadcastTxHash)
	}
	if bal := availNGN(t, st, u.ID); bal != 30_000_000 {
		t.Errorf("balance = %d, want 30000000 after sweep", bal)
	}

	// Idempotency: a second sweep (or a second claim) does not rebroadcast.
	before, _ := st.LedgerRepo().SumWithdrawalsSince(ctx, u.ID, time.Now().UTC().Add(-time.Hour))
	if err := v.sweepDueElevations(ctx); err != nil {
		t.Fatalf("second sweep: %v", err)
	}
	after, _ := st.LedgerRepo().SumWithdrawalsSince(ctx, u.ID, time.Now().UTC().Add(-time.Hour))
	if after != before {
		t.Errorf("withdrawn total changed across sweeps: %d -> %d", before, after)
	}
}

// TestWithdrawRejectsInsufficientBeforeBroadcast: the sufficiency check runs
// before any chain broadcast, so an underfunded withdrawal never spends gas.
func TestWithdrawRejectsInsufficientBeforeBroadcast(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-elev-empty@example.com")
	v := newElevationVault(t, st, u.ID, 0, time.Hour)

	_, err := v.WithdrawToAddress(ctx, u.ID, "0xDest000000000000000000000000000000000003", 5_000_000, "wd-empty-"+uniqueKey("k"))
	if err == nil {
		t.Fatal("expected insufficient balance error")
	}
	if !errors.Is(err, domain.ErrInsufficientBalance) {
		t.Errorf("err = %v, want ErrInsufficientBalance", err)
	}
}