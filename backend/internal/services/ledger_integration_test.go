package services

import (
	"context"
	"errors"
	"os"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage/postgres"
)

func testStore(t *testing.T) store {
	t.Helper()
	dsn := os.Getenv("GLOBMINT_TEST_DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://globmint:globmint_dev@localhost:5434/globmint"
	}
	ctx := context.Background()
	s, err := postgres.Open(ctx, postgres.Config{DSN: dsn, MaxConns: 20})
	if err != nil {
		t.Fatalf("open postgres: %v", err)
	}
	t.Cleanup(s.Close)
	if err := s.RunMigrations(ctx); err != nil {
		t.Fatalf("run migrations: %v", err)
	}
	return s
}

func uniqueEmail(base string) string {
	if i := strings.IndexByte(base, '@'); i >= 0 {
		return base[:i] + "." + strconv.FormatInt(time.Now().UnixNano(), 10) + base[i:]
	}
	return base
}

func uniqueKey(base string) string {
	return base + "-" + strconv.FormatInt(time.Now().UnixNano(), 10)
}

func newTestUser(t *testing.T, st store, email string) *domain.User {
	t.Helper()
	u := &domain.User{
		Email:        uniqueEmail(email),
		PasswordHash: "x",
		Status:       domain.UserStatusActive,
	}
	ctx := context.Background()
	if err := st.UserRepo().Create(ctx, u); err != nil {
		t.Fatalf("create user: %v", err)
	}
	if err := st.AccountRepo().EnsureDefaultAccounts(ctx, u.ID); err != nil {
		t.Fatalf("ensure default accounts: %v", err)
	}
	return u
}

func availableAccount(t *testing.T, st store, userID string) *domain.Account {
	t.Helper()
	acc, err := st.AccountRepo().FindByUserAndKind(context.Background(), userID, domain.AccountKindAvailable, "NGN")
	if err != nil {
		t.Fatalf("find available account: %v", err)
	}
	return acc
}

func creditReq(userID, key string, amount int64) LedgerMoveRequest {
	return LedgerMoveRequest{
		UserID:         userID,
		AccountKind:    domain.AccountKindAvailable,
		Currency:       "NGN",
		Type:           domain.TransactionTypeDeposit,
		AmountMinor:    amount,
		IdempotencyKey: key,
	}
}

func TestCreditUpdatesBalance(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "credit1@example.com")
	ledger := NewLedgerService(st)

	txn, err := ledger.Credit(ctx, creditReq(u.ID, uniqueKey("credit-key-1"), 50000))
	if err != nil {
		t.Fatalf("credit: %v", err)
	}
	if txn == nil || txn.ID == "" {
		t.Fatal("expected transaction with ID")
	}
	acc := availableAccount(t, st, u.ID)
	bal, err := st.AccountRepo().GetBalance(ctx, acc.ID)
	if err != nil {
		t.Fatalf("get balance: %v", err)
	}
	if bal != 50000 {
		t.Errorf("balance = %d, want 50000", bal)
	}
	sum, _ := st.LedgerRepo().SumBalanceByAccount(ctx, acc.ID)
	if sum != 50000 {
		t.Errorf("ledger sum = %d, want 50000", sum)
	}
}

func TestDebitInsufficientBalance(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "debit1@example.com")
	ledger := NewLedgerService(st)

	_, err := ledger.Debit(ctx, LedgerMoveRequest{
		UserID:      u.ID,
		AccountKind: domain.AccountKindAvailable,
		Currency:    "NGN",
		Type:        domain.TransactionTypeWithdrawal,
		AmountMinor: 100,
	})
	if err == nil {
		t.Fatal("expected error for debit with empty balance")
	}
	if !errors.Is(err, domain.ErrInsufficientBalance) {
		t.Fatalf("expected ErrInsufficientBalance, got %v", err)
	}
}

func TestDebitWithFeeAndSufficiency(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "debit2@example.com")
	ledger := NewLedgerService(st)
	acc := availableAccount(t, st, u.ID)

	if _, err := ledger.Credit(ctx, creditReq(u.ID, uniqueKey("d2-credit"), 1000)); err != nil {
		t.Fatalf("credit: %v", err)
	}
	// Debit 500 + 300 fee = 800; available 1000 -> ok.
	if _, err := ledger.Debit(ctx, LedgerMoveRequest{
		UserID: u.ID, AccountKind: domain.AccountKindAvailable, Currency: "NGN",
		Type: domain.TransactionTypeWithdrawal, AmountMinor: 500, FeeMinor: 300,
	}); err != nil {
		t.Fatalf("debit within balance: %v", err)
	}
	bal, _ := st.AccountRepo().GetBalance(ctx, acc.ID)
	if bal != 200 {
		t.Errorf("balance = %d, want 200", bal)
	}
	// Now only 200 available; debit 250 -> insufficient.
	if _, err := ledger.Debit(ctx, LedgerMoveRequest{
		UserID: u.ID, AccountKind: domain.AccountKindAvailable, Currency: "NGN",
		Type: domain.TransactionTypeWithdrawal, AmountMinor: 250,
	}); err == nil {
		t.Fatal("expected insufficient balance on second debit")
	}
}

func TestIdempotentCreditReplaysOneTransaction(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "idem-seq@example.com")
	ledger := NewLedgerService(st)
	acc := availableAccount(t, st, u.ID)

	key := uniqueKey("idem-seq-key")
	first, err := ledger.Credit(ctx, creditReq(u.ID, key, 50000))
	if err != nil {
		t.Fatalf("first credit: %v", err)
	}
	// Second call with the same key must return the SAME transaction.
	second, err := ledger.Credit(ctx, creditReq(u.ID, key, 50000))
	if err != nil {
		t.Fatalf("second credit: %v", err)
	}
	if first.ID != second.ID {
		t.Fatalf("idempotency violated: txn %s != %s", first.ID, second.ID)
	}
	bal, _ := st.AccountRepo().GetBalance(ctx, acc.ID)
	if bal != 50000 {
		t.Errorf("balance = %d, want 50000 (credited once)", bal)
	}
}

func TestConcurrentIdempotentCreditExactlyOnce(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "idem-conc@example.com")
	ledger := NewLedgerService(st)
	acc := availableAccount(t, st, u.ID)

	key := uniqueKey("idem-conc-key")
	const n = 12
	var wg sync.WaitGroup
	ids := make([]string, n)
	errs := make([]error, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			txn, err := ledger.Credit(ctx, creditReq(u.ID, key, 50000))
			if err == nil && txn != nil {
				ids[i] = txn.ID
			}
			if err != nil {
				errs[i] = err
			}
		}(i)
	}
	wg.Wait()

	for i, e := range errs {
		if e != nil {
			t.Fatalf("goroutine %d error: %v", i, e)
		}
		if ids[i] == "" {
			t.Fatalf("goroutine %d got no transaction", i)
		}
		if i > 0 && ids[i] != ids[0] {
			t.Fatalf("concurrent idempotency violated: %s != %s", ids[i], ids[0])
		}
	}

	bal, _ := st.AccountRepo().GetBalance(ctx, acc.ID)
	if bal != 50000 {
		t.Errorf("balance = %d, want 50000 (exactly once)", bal)
	}
	txns, _ := st.LedgerRepo().ListTransactionsByUser(ctx, u.ID)
	if len(txns) != 1 {
		t.Errorf("transaction count = %d, want 1", len(txns))
	}
}
