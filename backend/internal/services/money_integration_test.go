package services

import (
	"context"
	"errors"
	"testing"

	"globmint/backend/internal/domain"
)

// helper to credit a user's available account in an arbitrary currency.
func creditCurrency(t *testing.T, st store, userID, currency string, amount int64, key string) {
	t.Helper()
	if _, err := st.AccountRepo().EnsureAccount(context.Background(), userID, domain.AccountKindAvailable, currency); err != nil {
		t.Fatalf("ensure account: %v", err)
	}
	ledger := NewLedgerService(st)
	if _, err := ledger.Credit(context.Background(), LedgerMoveRequest{
		UserID:         userID,
		AccountKind:    domain.AccountKindAvailable,
		Currency:       currency,
		Type:           domain.TransactionTypeDeposit,
		AmountMinor:    amount,
		IdempotencyKey: key,
	}); err != nil {
		t.Fatalf("credit %s: %v", currency, err)
	}
}

func TestTransferAvailableToSavings(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "transfer1@example.com")
	moneySvc := NewMoneyService(st)
	creditCurrency(t, st, u.ID, "NGN", 100000, uniqueKey("tr-src"))

	txn, err := moneySvc.Transfer(ctx, TransferRequest{
		UserID:        u.ID,
		FromKind:      domain.AccountKindAvailable,
		ToKind:        domain.AccountKindSavings,
		Currency:      "NGN",
		AmountMinor:   40000,
		IdempotencyKey: uniqueKey("tr-key"),
	})
	if err != nil {
		t.Fatalf("transfer: %v", err)
	}
	if txn == nil || txn.ID == "" {
		t.Fatal("expected transaction")
	}

	avail, err := st.AccountRepo().GetBalance(ctx, availableAccount(t, st, u.ID).ID)
	if err != nil {
		t.Fatalf("balance: %v", err)
	}
	if avail != 60000 {
		t.Errorf("available balance = %d, want 60000", avail)
	}
	savings, err := st.AccountRepo().FindByUserAndKind(ctx, u.ID, domain.AccountKindSavings, "NGN")
	if err != nil {
		t.Fatalf("find savings: %v", err)
	}
	sBal, err := st.AccountRepo().GetBalance(ctx, savings.ID)
	if err != nil {
		t.Fatalf("savings balance: %v", err)
	}
	if sBal != 40000 {
		t.Errorf("savings balance = %d, want 40000", sBal)
	}
}

func TestTransferInsufficientBalance(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "transfer2@example.com")
	moneySvc := NewMoneyService(st)
	creditCurrency(t, st, u.ID, "NGN", 1000, uniqueKey("tr2-src"))

	_, err := moneySvc.Transfer(ctx, TransferRequest{
		UserID:        u.ID,
		FromKind:      domain.AccountKindAvailable,
		ToKind:        domain.AccountKindSavings,
		Currency:      "NGN",
		AmountMinor:   5000,
		IdempotencyKey: uniqueKey("tr2-key"),
	})
	if !errors.Is(err, domain.ErrInsufficientBalance) {
		t.Fatalf("expected ErrInsufficientBalance, got %v", err)
	}
}

func TestTransferIdempotent(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "transfer3@example.com")
	moneySvc := NewMoneyService(st)
	creditCurrency(t, st, u.ID, "NGN", 100000, uniqueKey("tr3-src"))

	key := uniqueKey("tr3-idem")
	first, err := moneySvc.Transfer(ctx, TransferRequest{
		UserID:        u.ID,
		FromKind:      domain.AccountKindAvailable,
		ToKind:        domain.AccountKindSavings,
		Currency:      "NGN",
		AmountMinor:   20000,
		IdempotencyKey: key,
	})
	if err != nil {
		t.Fatalf("first transfer: %v", err)
	}
	second, err := moneySvc.Transfer(ctx, TransferRequest{
		UserID:        u.ID,
		FromKind:      domain.AccountKindAvailable,
		ToKind:        domain.AccountKindSavings,
		Currency:      "NGN",
		AmountMinor:   20000,
		IdempotencyKey: key,
	})
	if err != nil {
		t.Fatalf("second transfer: %v", err)
	}
	if first.ID != second.ID {
		t.Errorf("idempotent replay returned different txn %s vs %s", first.ID, second.ID)
	}
}

func TestConvertUSDTTonNGN(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "convert1@example.com")
	moneySvc := NewMoneyService(st)
	// Seed rate must exist (via migrations 0004).
	creditCurrency(t, st, u.ID, "USDT", 100000, uniqueKey("cv-credit")) // 1000.00 USDT

	txn, err := moneySvc.Convert(ctx, u.ID, 50000, "USDT", "NGN", uniqueKey("cv-key")) // convert 500.00 USDT
	if err != nil {
		t.Fatalf("convert: %v", err)
	}
	if txn == nil || txn.Type != domain.TransactionTypeConversion {
		t.Fatalf("expected conversion txn, got %+v", txn)
	}

	usdtAcc, err := st.AccountRepo().FindByUserAndKind(ctx, u.ID, domain.AccountKindAvailable, "USDT")
	if err != nil {
		t.Fatalf("find usdt: %v", err)
	}
	usdtBal, _ := st.AccountRepo().GetBalance(ctx, usdtAcc.ID)
	if usdtBal != 50000 {
		t.Errorf("USDT balance = %d, want 50000", usdtBal)
	}

	ngnAcc, err := st.AccountRepo().FindByUserAndKind(ctx, u.ID, domain.AccountKindAvailable, "NGN")
	if err != nil {
		t.Fatalf("find ngn: %v", err)
	}
	ngnBal, _ := st.AccountRepo().GetBalance(ctx, ngnAcc.ID)
	// 500.00 USDT * 1604.50 minus 0.5% fee = 500*160450/100=802250 kobo = 8022.50 NGN; fee 0.5% ~40 kobo
	if ngnBal <= 0 {
		t.Errorf("NGN balance = %d, want > 0", ngnBal)
	}
}

func TestBeneficiaryAndBankAccountCRUD(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "crud1@example.com")
	moneySvc := NewMoneyService(st)

	b := &domain.Beneficiary{Name: "Ada", Bank: "GTBank", AccountNumber: "0123456789", IsFavorite: true}
	if err := moneySvc.CreateBeneficiary(ctx, u.ID, b); err != nil {
		t.Fatalf("create beneficiary: %v", err)
	}
	if b.ID == "" {
		t.Fatal("expected beneficiary ID")
	}
	list, err := moneySvc.ListBeneficiaries(ctx, u.ID)
	if err != nil || len(list) != 1 {
		t.Fatalf("list beneficiaries: %v len=%d", err, len(list))
	}
	resolved, err := moneySvc.ResolveAccount(ctx, u.ID, "0123456789")
	if err != nil || resolved.ID != b.ID {
		t.Fatalf("resolve account: %v", err)
	}
	if err := moneySvc.ToggleBeneficiaryFavorite(ctx, u.ID, b.ID); err != nil {
		t.Fatalf("toggle favorite: %v", err)
	}
	if err := moneySvc.DeleteBeneficiary(ctx, u.ID, b.ID); err != nil {
		t.Fatalf("delete beneficiary: %v", err)
	}

	a := &domain.BankAccount{BankName: "Access", BankCode: "044", AccountNumber: "1234567890", AccountName: "Ada", IsDefault: true}
	if err := moneySvc.CreateBankAccount(ctx, u.ID, a); err != nil {
		t.Fatalf("create bank account: %v", err)
	}
	accts, err := moneySvc.ListBankAccounts(ctx, u.ID)
	if err != nil || len(accts) != 1 {
		t.Fatalf("list bank accounts: %v len=%d", err, len(accts))
	}
	if err := moneySvc.SetDefaultBankAccount(ctx, u.ID, a.ID); err != nil {
		t.Fatalf("set default: %v", err)
	}
	if err := moneySvc.DeleteBankAccount(ctx, u.ID, a.ID); err != nil {
		t.Fatalf("delete bank account: %v", err)
	}
}
