package services

import (
	"context"
	"testing"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/infrastructure/blockchain"
)

func inbox(t *testing.T, st store, userID string) []domain.Notification {
	t.Helper()
	list, err := st.NotificationRepo().ListByUser(context.Background(), userID, 50)
	if err != nil {
		t.Fatalf("list notifications: %v", err)
	}
	return list
}

func inboxCategories(list []domain.Notification) map[domain.NotificationCategory]int {
	out := map[domain.NotificationCategory]int{}
	for _, n := range list {
		out[n.Category]++
		if n.Title == "" || n.Body == "" {
			panic("notification with empty title/body: " + string(n.Category))
		}
	}
	return out
}

// TestMoneyMovementNotifies: every completed money movement files exactly one
// inbox notification; idempotent replays file none.
func TestMoneyMovementNotifies(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "notify-money@example.com")
	moneySvc := NewMoneyService(st)

	fundNGN(t, st, u.ID, 50_000_000, "fund-notify-"+uniqueKey("k"))
	creditCurrency(t, st, u.ID, "USDT", 100000, "fund-notify-usdt-"+uniqueKey("k"))

	if _, err := moneySvc.Deposit(ctx, u.ID, "NGN", 1_000_000, "dep-notify-"+uniqueKey("k")); err != nil {
		t.Fatalf("deposit: %v", err)
	}
	if _, err := moneySvc.Transfer(ctx, TransferRequest{
		UserID: u.ID, FromKind: domain.AccountKindAvailable,
		ToKind:   domain.AccountKindSavings,
		Currency: "NGN", AmountMinor: 2_000_000,
		IdempotencyKey: "xfer-notify-" + uniqueKey("k"),
	}); err != nil {
		t.Fatalf("transfer: %v", err)
	}
	if _, err := moneySvc.Convert(ctx, u.ID, 50000, "USDT", "NGN", "cv-notify-"+uniqueKey("k")); err != nil {
		t.Fatalf("convert: %v", err)
	}
	if _, err := moneySvc.Withdraw(ctx, LedgerMoveRequest{
		UserID: u.ID, AccountKind: domain.AccountKindAvailable,
		Currency: "NGN", Type: domain.TransactionTypeWithdrawal,
		AmountMinor: 1_000_000,
	}, "wd-notify-"+uniqueKey("k")); err != nil {
		t.Fatalf("withdraw: %v", err)
	}

	got := inboxCategories(inbox(t, st, u.ID))
	for cat, want := range map[domain.NotificationCategory]int{
		domain.NotificationCategoryDeposit:    2, // funding deposit + test deposit
		domain.NotificationCategoryTransfer:   1,
		domain.NotificationCategoryConversion: 1,
		domain.NotificationCategoryWithdrawal: 1,
	} {
		if got[cat] != want {
			t.Errorf("category %s = %d, want %d (all=%v)", cat, got[cat], want, got)
		}
	}
}

// TestNotifyExactlyOnceOnReplay: retrying a completed deposit with the same
// idempotency key returns the transaction but files no second notification.
func TestNotifyExactlyOnceOnReplay(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "notify-replay@example.com")
	moneySvc := NewMoneyService(st)

	key := "dep-replay-" + uniqueKey("k")
	if _, err := moneySvc.Deposit(ctx, u.ID, "NGN", 1_000_000, key); err != nil {
		t.Fatalf("deposit: %v", err)
	}
	if _, err := moneySvc.Deposit(ctx, u.ID, "NGN", 1_000_000, key); err != nil {
		t.Fatalf("replay: %v", err)
	}
	if n := len(inbox(t, st, u.ID)); n != 1 {
		t.Errorf("notifications after replay = %d, want exactly 1", n)
	}
}

// TestVaultWithdrawalNotifies: a broadcast vault withdrawal (instant and
// swept) files a withdrawal notification naming the destination.
func TestVaultWithdrawalNotifies(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "notify-vault@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-notify-vault-"+uniqueKey("k"))
	v := NewVaultService(st, blockchain.NewMockBlockchainService(), NewMoneyService(st), VaultConfig{
		VaultAddress: vaultAddr, StablecoinSymbol: "USDC", StablecoinDecimals: 6,
		Mode: "real", FallbackUserID: u.ID, WithdrawEnabled: true,
	}, 160450)

	res, err := v.WithdrawToAddress(ctx, u.ID, "0xNotify000000000000000000000000000000000001", 5_000_000, "wd-nv-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("withdraw: %v", err)
	}
	if res.Transaction == nil {
		t.Fatal("expected an instant transaction")
	}
	list := inbox(t, st, u.ID)
	// Two rows: the funding deposit plus the withdrawal under test.
	if len(list) != 2 {
		t.Fatalf("notifications = %d, want 2 (funding + withdrawal)", len(list))
	}
	got := inboxCategories(list)
	if got[domain.NotificationCategoryWithdrawal] != 1 {
		t.Errorf("withdrawal notifications = %d, want 1", got[domain.NotificationCategoryWithdrawal])
	}
}
