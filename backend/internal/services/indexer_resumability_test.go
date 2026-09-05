package services

import (
	"context"
	"errors"
	"math/big"
	"testing"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/infrastructure/blockchain"
)

var errSimulatedRPC = errors.New("simulated rpc failure")

const vaultAddr = "0xVaultDepositAddress00000000000000000000000000"

// newResumableVault builds a vault service wired to a controllable mock chain
// and the real Postgres store, with reorg protection and a fallback user so
// deposits credit without a deposit-address link.
func newResumableVault(t *testing.T, st store, chain *blockchain.MockBlockchainService, userID string) *VaultService {
	t.Helper()
	return NewVaultService(st, chain, NewMoneyService(st), VaultConfig{
		VaultAddress:       vaultAddr,
		StablecoinSymbol:   "USDC",
		StablecoinDecimals: 6,
		MinConfirmations:   3,
		FallbackUserID:     userID,
	}, 160450)
}

// resetCursor zeroes the persisted scan cursor so tests are deterministic even
// if a previous run left state behind (the cursor row is app-global).
func resetCursor(t *testing.T, st store) {
	t.Helper()
	if err := st.IndexerStateRepo().SetLastBlock(context.Background(), 0); err != nil {
		t.Fatalf("reset cursor: %v", err)
	}
}

func vaultTransfer(block uint64, tx string) blockchain.TokenTransfer {
	return blockchain.TokenTransfer{
		From:     "0xSender000000000000000000000000000000000000",
		To:       vaultAddr,
		Value:    big.NewInt(10_000_000), // 10 USDC
		TxHash:   uniqueKey(tx),
		BlockNumber: block,
	}
}

func availNGN(t *testing.T, st store, userID string) int64 {
	t.Helper()
	acc, err := st.AccountRepo().FindByUserAndKind(context.Background(), userID, "available", "NGN")
	if err != nil {
		t.Fatalf("find available NGN account: %v", err)
	}
	bal, err := st.AccountRepo().GetBalance(context.Background(), acc.ID)
	if err != nil {
		t.Fatalf("get balance: %v", err)
	}
	return bal
}

// TestIndexerFirstRunSkipsHistory: on a fresh cursor the indexer only watches
// blocks mined from startup, so pre-existing deposits are never back-credited.
func TestIndexerFirstRunSkipsHistory(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-cold@example.com")
	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	chain.AddTransfer(vaultTransfer(95, "0xpre-existing"))
	v := newResumableVault(t, st, chain, u.ID)

	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan: %v", err)
	}
	if bal := availNGN(t, st, u.ID); bal != 0 {
		t.Errorf("pre-existing deposit credited: balance = %d, want 0", bal)
	}
}

// TestIndexerConfirmationWindow: deposits inside the confirmation window are
// not credited until the chain has advanced far enough.
func TestIndexerConfirmationWindow(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-window@example.com")
	chain := blockchain.NewMockBlockchainService()
	v := newResumableVault(t, st, chain, u.ID)

	chain.SetLatest(100)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}
	// Deps at block 148, 149: not yet 3 confirmations behind 153.
	chain.AddTransfer(vaultTransfer(148, "0xwindow-a"))
	chain.AddTransfer(vaultTransfer(149, "0xwindow-b"))
	chain.SetLatest(150)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan before confirmation: %v", err)
	}
	if bal := availNGN(t, st, u.ID); bal != 0 {
		t.Errorf("deposit credited too early: balance = %d, want 0", bal)
	}

	chain.SetLatest(153) // confirmed head = 150, exposes 148 + 149
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan after confirmation: %v", err)
	}
	if bal := availNGN(t, st, u.ID); bal <= 0 {
		t.Errorf("deposit never credited: balance = %d", bal)
	}
	last, _ := st.IndexerStateRepo().LastBlock(ctx)
	if last != 150 {
		t.Errorf("persisted cursor = %d, want 150", last)
	}
}

// TestIndexerRestartResumesFromCursor: a freshly constructed service resumes
// from the persisted cursor, picks up only new deposits, and never re-credits
// the ones the crashed process already handled.
func TestIndexerRestartResumesFromCursor(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-restart@example.com")
	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v1 := newResumableVault(t, st, chain, u.ID)
	if err := v1.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	chain.AddTransfer(vaultTransfer(148, "0xrestart-a"))
	chain.AddTransfer(vaultTransfer(149, "0xrestart-b"))
	chain.SetLatest(153)
	if err := v1.scan(ctx); err != nil {
		t.Fatalf("v1 scan: %v", err)
	}
	bal1 := availNGN(t, st, u.ID)
	if bal1 <= 0 {
		t.Fatalf("v1 credited nothing: balance = %d", bal1)
	}
	last, _ := st.IndexerStateRepo().LastBlock(ctx)
	if last != 150 {
		t.Fatalf("persisted cursor = %d, want 150", last)
	}

	// "Crash": drop v1. A new process resumes from the persisted cursor.
	chain.AddTransfer(vaultTransfer(152, "0xrestart-c"))
	chain.SetLatest(156) // confirmed head = 153, includes 152
	v2 := newResumableVault(t, st, chain, u.ID)
	if err := v2.resumeCursor(ctx); err != nil {
		t.Fatalf("resume cursor: %v", err)
	}
	if err := v2.scan(ctx); err != nil {
		t.Fatalf("v2 scan: %v", err)
	}
	bal2 := availNGN(t, st, u.ID)
	if bal2 != bal1+depositNGNMinor(big.NewInt(10_000_000), 160450) {
		t.Errorf("v2 balance = %d, want %d (one new deposit credited)", bal2, bal1+depositNGNMinor(big.NewInt(10_000_000), 160450))
	}
	if _, err := st.LedgerRepo().ListTransactionsByUser(ctx, u.ID); err != nil {
		t.Fatalf("list txns: %v", err)
	}
}

// TestIndexerCrashMidBatchNoDoubleCredit: a crash before the cursor is
// persisted re-scans the same blocks on restart; the tx-hash idempotency must
// dedupe and credit exactly once.
func TestIndexerCrashMidBatchNoDoubleCredit(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-crash@example.com")
	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newResumableVault(t, st, chain, u.ID)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	// A transfer is confirmed and handled but, simulating a crash before
	// SetLastBlock, the cursor never advanced. Replaying the same block window
	// (as a restart would) must not create a second credit.
	tr := vaultTransfer(148, "0xcrash-mid-batch")
	chain.AddTransfer(tr)
	chain.SetLatest(153)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan: %v", err)
	}
	bal := availNGN(t, st, u.ID)
	if bal <= 0 {
		t.Fatalf("first pass credited nothing: balance = %d", bal)
	}

	// Force the in-memory cursor back so the next scan re-reads the window,
	// exactly like a restart whose persisted cursor lost the batch.
	v.lastBlock = 100
	if err := v.scan(ctx); err != nil {
		t.Fatalf("rescan same window: %v", err)
	}
	if got := availNGN(t, st, u.ID); got != bal {
		t.Errorf("balance after rescan = %d, want %d (no double credit)", got, bal)
	}
}

// TestIndexerRPCFaultLeavesCursorIntact: transient RPC failures surface but do
// not advance or corrupt the cursor; the next healthy scan resumes normally.
func TestIndexerRPCFaultLeavesCursorIntact(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-rpc@example.com")
	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newResumableVault(t, st, chain, u.ID)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	chain.AddTransfer(vaultTransfer(148, "0xrpc-a"))
	chain.SetLatest(153)

	chain.SetHeadError(errSimulatedRPC)
	if err := v.scan(ctx); err == nil {
		t.Fatal("expected scan error on head RPC failure")
	}
	chain.SetHeadError(nil)

	chain.SetFilterError(errSimulatedRPC)
	if err := v.scan(ctx); err == nil {
		t.Fatal("expected scan error on filter RPC failure")
	}
	chain.SetFilterError(nil)

	if err := v.scan(ctx); err != nil {
		t.Fatalf("recovery scan: %v", err)
	}
	if bal := availNGN(t, st, u.ID); bal <= 0 {
		t.Errorf("deposit not credited after RPC recovery: balance = %d", bal)
	}
	last, _ := st.IndexerStateRepo().LastBlock(ctx)
	if last != 149 {
		t.Errorf("persisted cursor = %d, want 149", last)
	}
}

// TestIndexerParallelCrediting: confirmed deposits for distinct users are
// credited concurrently without lost updates, and every transfer is recorded
// in the durable indexer_events log.
func TestIndexerParallelCrediting(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	ua := newTestUser(t, st, "vault-par-a@example.com")
	ub := newTestUser(t, st, "vault-par-b@example.com")

	addrA := "0xParSenderA" + uniqueKey("")
	addrB := "0xParSenderB" + uniqueKey("")
	for userID, addr := range map[string]string{ua.ID: addrA, ub.ID: addrB} {
		if err := st.DepositAddressRepo().Set(ctx, &domain.DepositAddress{UserID: userID, Address: addr}); err != nil {
			t.Fatalf("link %s: %v", userID, err)
		}
	}

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := NewVaultService(st, chain, NewMoneyService(st), VaultConfig{
		VaultAddress:       vaultAddr,
		StablecoinSymbol:   "USDC",
		StablecoinDecimals: 6,
		MinConfirmations:   0,
	}, 160450)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	ta := blockchain.TokenTransfer{
		From: addrA, To: vaultAddr, Value: big.NewInt(10_000_000),
		TxHash: uniqueKey("0xpar-a"), BlockNumber: 148,
	}
	tb := blockchain.TokenTransfer{
		From: addrB, To: vaultAddr, Value: big.NewInt(20_000_000),
		TxHash: uniqueKey("0xpar-b"), BlockNumber: 149,
	}
	transfers := []blockchain.TokenTransfer{ta, tb}
	chain.AddTransfer(ta)
	chain.AddTransfer(tb)
	chain.SetLatest(150)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("parallel scan: %v", err)
	}

	if bal := availNGN(t, st, ua.ID); bal != depositNGNMinor(big.NewInt(10_000_000), 160450) {
		t.Errorf("user A balance = %d", bal)
	}
	if bal := availNGN(t, st, ub.ID); bal != depositNGNMinor(big.NewInt(20_000_000), 160450) {
		t.Errorf("user B balance = %d", bal)
	}

	events, err := st.IndexerEventRepo().ListByRange(ctx, 148, 149)
	if err != nil {
		t.Fatalf("list events: %v", err)
	}
	// Stale rows from earlier runs may share the block range; assert exactly
	// one log row per processed tx hash (the restart-duplication guarantee).
	seen := map[string]int{}
	for i := range events {
		seen[events[i].TxHash]++
	}
	if seen[transfers[0].TxHash] != 1 || seen[transfers[1].TxHash] != 1 {
		t.Errorf("event log counts = %v, want exactly 1 row per transfer hash", seen)
	}
}

// TestIndexerLeadershipIsExclusive: the Postgres advisory lock is exclusive —
// only one process holds it at a time, and it hands over on release.
func TestIndexerLeadershipIsExclusive(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	const key = int64(0xCAFE)

	rel, ok, err := st.TryAcquireIndexerLeadership(ctx, key)
	if err != nil {
		t.Fatalf("acquire: %v", err)
	}
	if !ok {
		t.Fatal("first acquisition should win the lease")
	}
	if _, ok2, err := st.TryAcquireIndexerLeadership(ctx, key); err != nil {
		t.Fatalf("second acquire: %v", err)
	} else if ok2 {
		t.Fatal("second acquisition must fail while the first holds the lease")
	}

	rel() // leader gives up (or crashes -> session dies)
	if release, ok3, err := st.TryAcquireIndexerLeadership(ctx, key); err != nil {
		t.Fatalf("re-acquire: %v", err)
	} else if !ok3 {
		t.Fatal("lease must transfer after release")
	} else {
		release()
	}
}