package services

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/infrastructure/blockchain"
)

// newFeeVault builds a real-mode vault with the default fee schedule
// (20 bps, min ₦10, cap ₦100) and the given elevation threshold.
func newFeeVault(t *testing.T, st store, userID string, threshold int64) *VaultService {
	t.Helper()
	return NewVaultService(st, blockchain.NewMockBlockchainService(), NewMoneyService(st), VaultConfig{
		VaultAddress:                     vaultAddr,
		StablecoinSymbol:                 "USDC",
		StablecoinDecimals:               6,
		Mode:                             "real",
		FallbackUserID:                   userID,
		WithdrawEnabled:                  true,
		WithdrawElevationThresholdMinor:  threshold,
		WithdrawElevationDelay:           time.Hour,
		WithdrawFeeBPS:                   20,
		WithdrawFeeMinMinor:              1000,
		WithdrawFeeCapMinor:              10000,
	}, 160450)
}

// platformFeeDelta returns the change in the platform fee account balance
// across fn (the test DB persists across runs, so deltas isolate each test).
func platformFeeDelta(t *testing.T, st store, fn func()) int64 {
	t.Helper()
	before := platformFeeBalance(t, st)
	fn()
	return platformFeeBalance(t, st) - before
}

func platformFeeBalance(t *testing.T, st store) int64 {
	t.Helper()
	ctx := context.Background()
	acct, err := st.AccountRepo().FindByUserAndKind(ctx, domain.PlatformUserID, domain.AccountKindPlatformFees, "NGN")
	if err != nil {
		t.Fatalf("find platform fee account: %v", err)
	}
	bal, err := st.LedgerRepo().SumBalanceByAccount(ctx, acct.ID)
	if err != nil {
		t.Fatalf("sum platform fee balance: %v", err)
	}
	return bal
}

// TestWithdraw_Instant_FeeDeducted: an instant withdrawal debits principal +
// fee, records fee_minor on the transaction, and settles the fee to the
// platform account.
func TestWithdraw_Instant_FeeDeducted(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-fee-instant@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-fee-instant-"+uniqueKey("k"))
	v := newFeeVault(t, st, u.ID, 10_000_000)

	// 5,000,000 kobo * 20bps = 10,000 (hits the cap exactly).
	const amount = 5_000_000
	const fee = 10_000

	var res *WithdrawalResult
	delta := platformFeeDelta(t, st, func() {
		var err error
		res, err = v.WithdrawToAddress(ctx, u.ID, "0xFeeDest0000000000000000000000000000000001", amount, "wd-fee-"+uniqueKey("k"))
		if err != nil {
			t.Fatalf("withdraw: %v", err)
		}
	})
	if res.Transaction == nil {
		t.Fatal("expected an instant transaction")
	}
	if res.Transaction.FeeMinor != fee {
		t.Errorf("transaction fee_minor = %d, want %d", res.Transaction.FeeMinor, fee)
	}
	if res.Transaction.AmountMinor != amount {
		t.Errorf("transaction amount_minor = %d, want principal %d", res.Transaction.AmountMinor, amount)
	}
	if bal := availNGN(t, st, u.ID); bal != 50_000_000-amount-fee {
		t.Errorf("balance = %d, want %d", bal, 50_000_000-amount-fee)
	}
	if delta != fee {
		t.Errorf("platform fee delta = %d, want %d", delta, fee)
	}
}

// TestWithdraw_Elevated_FeeStoredAndDeductedOnSweep: the request stores the
// fee without moving funds; the sweep debits principal + fee and settles the
// fee to the platform account.
func TestWithdraw_Elevated_FeeStoredAndDeductedOnSweep(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-fee-elev@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-fee-elev-"+uniqueKey("k"))
	v := newFeeVault(t, st, u.ID, 10_000_000)

	// 20,000,000 kobo * 20bps = 40,000 -> capped at 10,000.
	res, err := v.WithdrawToAddress(ctx, u.ID, "0xFeeDest0000000000000000000000000000000002", 20_000_000, "wd-fee-elev-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("withdraw: %v", err)
	}
	if res.Elevation == nil {
		t.Fatal("expected a pending elevation")
	}
	if res.Elevation.FeeMinor != 10_000 {
		t.Errorf("stored elevation fee = %d, want 10000", res.Elevation.FeeMinor)
	}
	if bal := availNGN(t, st, u.ID); bal != 50_000_000 {
		t.Errorf("balance moved while pending = %d, want 50000000", bal)
	}

	// A due elevation carrying the stored fee is swept: principal + fee leave
	// the user, the fee lands in the platform account, the txn records it.
	elevKey := "elev-fee-sweep-" + uniqueKey("k")
	if _, err := st.ElevationRepo().Create(ctx, &domain.WithdrawalElevation{
		UserID:         u.ID,
		Destination:    "0xFeeDest0000000000000000000000000000000003",
		AmountNgnMinor: 15_000_000, // fee: 15M*20/10000=30,000 -> cap 10,000
		FeeMinor:       10_000,
		Status:         domain.ElevationPending,
		ReleaseAfter:   time.Now().UTC().Add(-time.Minute),
		IdempotencyKey: elevKey,
	}); err != nil {
		t.Fatalf("create elevation: %v", err)
	}
	delta := platformFeeDelta(t, st, func() {
		if err := v.sweepDueElevations(ctx); err != nil {
			t.Fatalf("sweep: %v", err)
		}
	})
	if bal := availNGN(t, st, u.ID); bal != 50_000_000-15_000_000-10_000 {
		t.Errorf("balance after sweep = %d, want %d", bal, 50_000_000-15_000_000-10_000)
	}
	if delta != 10_000 {
		t.Errorf("platform fee delta after sweep = %d, want 10000", delta)
	}
	txn, err := st.LedgerRepo().FindTransactionByIDempotencyKey(ctx, elevKey)
	if err != nil {
		t.Fatalf("find sweep transaction: %v", err)
	}
	if txn.FeeMinor != 10_000 || txn.AmountMinor != 15_000_000 {
		t.Errorf("sweep txn = amount %d fee %d, want 15000000/10000", txn.AmountMinor, txn.FeeMinor)
	}
}

// TestWithdraw_Elevated_Cancel_NoFee: cancelling a pending elevation moves no
// funds and records no withdrawal.
func TestWithdraw_Elevated_Cancel_NoFee(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-fee-cancel@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-fee-cancel-"+uniqueKey("k"))
	v := newFeeVault(t, st, u.ID, 10_000_000)

	res, err := v.WithdrawToAddress(ctx, u.ID, "0xFeeDest0000000000000000000000000000000004", 20_000_000, "wd-fee-cancel-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("withdraw: %v", err)
	}
	delta := platformFeeDelta(t, st, func() {
		if err := v.CancelElevation(ctx, u.ID, res.Elevation.ID); err != nil {
			t.Fatalf("cancel: %v", err)
		}
	})
	if bal := availNGN(t, st, u.ID); bal != 50_000_000 {
		t.Errorf("balance after cancel = %d, want 50000000", bal)
	}
	if delta != 0 {
		t.Errorf("platform fee delta after cancel = %d, want 0", delta)
	}
	used, err := st.LedgerRepo().SumWithdrawalsSince(ctx, u.ID, time.Now().UTC().Add(-time.Hour))
	if err != nil {
		t.Fatalf("sum withdrawals: %v", err)
	}
	if used != 0 {
		t.Errorf("withdrawn total after cancel = %d, want 0", used)
	}
}

// TestWithdraw_RejectsVaultSelfSend: withdrawing to the vault's own address
// (or its contract) would loop funds in a circle while debiting the user, so
// it is rejected before anything moves or is charged.
func TestWithdraw_RejectsVaultSelfSend(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-selfsend@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-selfsend-"+uniqueKey("k"))
	v := newFeeVault(t, st, u.ID, 0)
	v.cfg.VaultContract = "0xC0n7rac7000000000000000000000000000000001"

	for _, dest := range []string{vaultAddr, strings.ToUpper(vaultAddr), v.cfg.VaultContract} {
		_, err := v.WithdrawToAddress(ctx, u.ID, dest, 5_000_000, "wd-self-"+uniqueKey("k"))
		if !errors.Is(err, domain.ErrInvalidAddress) {
			t.Errorf("destination %s: err = %v, want ErrInvalidAddress", dest, err)
		}
	}
	if bal := availNGN(t, st, u.ID); bal != 50_000_000 {
		t.Errorf("balance = %d, want 50000000 (nothing debited)", bal)
	}
	if delta := platformFeeDelta(t, st, func() {}); delta != 0 {
		t.Errorf("platform fee delta = %d, want 0", delta)
	}
}

// TestWithdrawalDailyCap_ExcludesFee: the daily cap sums principals only, so a
// withdrawal whose principal fits (but principal + fee would exceed) succeeds.
func TestWithdrawalDailyCap_ExcludesFee(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-fee-cap@example.com")
	fundNGN(t, st, u.ID, 30_000_000, "fund-fee-cap-"+uniqueKey("k"))
	v := newFeeVault(t, st, u.ID, 0) // threshold 0: everything instant
	v.cfg.WithdrawDailyCapMinor = 10_000_000

	// Principal 9,950,000 (fee 10,000 capped).
	if _, err := v.WithdrawToAddress(ctx, u.ID, "0xFeeDest0000000000000000000000000000000005", 9_950_000, "wd-fee-cap1-"+uniqueKey("k")); err != nil {
		t.Fatalf("first withdraw: %v", err)
	}
	// Principal 40,000 (fee 1,000 min): principals total 9,990,000 <= cap,
	// but with fees 9,960,000 + 41,000 = 10,001,000 > cap. Must succeed.
	if _, err := v.WithdrawToAddress(ctx, u.ID, "0xFeeDest0000000000000000000000000000000006", 40_000, "wd-fee-cap2-"+uniqueKey("k")); err != nil {
		t.Fatalf("second withdraw rejected, fee counted toward cap: %v", err)
	}
	// A further 20,000 would push principals to 10,010,000 > cap: rejected.
	if _, err := v.WithdrawToAddress(ctx, u.ID, "0xFeeDest0000000000000000000000000000000007", 20_000, "wd-fee-cap3-"+uniqueKey("k")); err == nil {
		t.Fatal("expected daily cap rejection on principal overflow")
	}
	if bal := availNGN(t, st, u.ID); bal != 30_000_000-9_950_000-10_000-40_000-1_000 {
		t.Errorf("balance = %d, want %d", bal, 30_000_000-9_950_000-10_000-40_000-1_000)
	}
}
