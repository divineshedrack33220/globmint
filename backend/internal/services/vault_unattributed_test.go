package services

import (
	"context"
	"math/big"
	"testing"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/infrastructure/blockchain"
)

// unlinkedTransfer builds a token transfer into the vault from a wallet that
// no user has linked (the MetaMask "Send" case).
func unlinkedTransfer(block uint64, tx, sender string) blockchain.TokenTransfer {
	return blockchain.TokenTransfer{
		From:        sender,
		To:          vaultAddr,
		Value:       big.NewInt(10_000_000), // 10 USDC
		TxHash:      uniqueKey(tx),
		BlockNumber: block,
	}
}

// newNoFallbackVault builds a vault service with NO fallback user so an
// unlinked sender must be flagged for operator review instead of credited.
func newNoFallbackVault(t *testing.T, st store, chain *blockchain.MockBlockchainService) *VaultService {
	t.Helper()
	return NewVaultService(st, chain, NewMoneyService(st), VaultConfig{
		VaultAddress:       vaultAddr,
		StablecoinSymbol:   "USDC",
		StablecoinDecimals: 6,
		MinConfirmations:   0,
	}, 160450)
}

// TestIndexerFlagsUnlinkedDirectTransferForOperatorReview: a direct USDC
// transfer into the vault from a wallet that is not linked to any user is not
// silently dropped — it is durably flagged as unattributed so an operator can
// review the queue and attribute the funds.
func TestIndexerFlagsUnlinkedDirectTransferForOperatorReview(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-attr@example.com")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newNoFallbackVault(t, st, chain)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	unlinked := "0xStrayWallet" + uniqueKey("")
	tr := unlinkedTransfer(148, "0xstray-send", unlinked)
	chain.AddTransfer(tr)
	chain.SetLatest(150)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan: %v", err)
	}

	// The sender was not credited (and no user owns it)...
	if bal := availNGN(t, st, u.ID); bal != 0 {
		t.Errorf("unlinked sender credited by accident: balance = %d, want 0", bal)
	}
	// ...but the deposit was flagged durably for operator review.
	flags, err := st.IndexerEventRepo().ListUnattributed(ctx, 20)
	if err != nil {
		t.Fatalf("list unattributed: %v", err)
	}
	found := false
	for _, e := range flags {
		if e.TxHash == tr.TxHash && e.LogIndex == tr.LogIndex {
			found = true
			if e.EventType != domain.IndexerEventUnattributed {
				t.Errorf("event type = %q, want %q", e.EventType, domain.IndexerEventUnattributed)
			}
			if e.From != unlinked || e.To != vaultAddr || e.ValueBase != 10_000_000 {
				t.Errorf("flagged event mismatch: from=%s to=%s value=%d", e.From, e.To, e.ValueBase)
			}
		}
	}
	if !found {
		t.Fatalf("unattributed flag missing for %s (flags=%d)", tr.TxHash, len(flags))
	}
}

// TestOperatorAttributeDepositCreditsIdempotently: attributing a flagged
// deposit links the sender to the given user and credits their ledger exactly
// once; replaying the attribution is a no-op.
func TestOperatorAttributeDepositCreditsIdempotently(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-attr-credit@example.com")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newNoFallbackVault(t, st, chain)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	unlinked := "0xStrayWalletCredit" + uniqueKey("")
	tr := unlinkedTransfer(148, "0xstray-credit", unlinked)
	chain.AddTransfer(tr)
	chain.SetLatest(150)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan: %v", err)
	}

	want := depositNGNMinor(big.NewInt(10_000_000), 160450)
	credited, err := v.AttributeDeposit(ctx, tr.TxHash, tr.LogIndex, u.ID)
	if err != nil {
		t.Fatalf("attribute: %v", err)
	}
	if !credited {
		t.Fatal("expected first attribution to credit the ledger")
	}
	if bal := availNGN(t, st, u.ID); bal != want {
		t.Errorf("balance after attribution = %d, want %d", bal, want)
	}

	// Owner link persists so the indexer would now credit this sender directly.
	owner, err := st.DepositAddressRepo().OwnerOf(ctx, unlinked)
	if err != nil {
		t.Fatalf("owner lookup: %v", err)
	}
	if owner != u.ID {
		t.Errorf("sender owned by %q, want %q", owner, u.ID)
	}

	// Idempotent replay: no error, nothing credited twice.
	credited, err = v.AttributeDeposit(ctx, tr.TxHash, tr.LogIndex, u.ID)
	if err != nil {
		t.Fatalf("replay attribute: %v", err)
	}
	if credited {
		t.Error("replay attributed a second time")
	}
	if bal := availNGN(t, st, u.ID); bal != want {
		t.Errorf("balance after replay = %d, want %d (double credit!)", bal, want)
	}

	evt, err := st.IndexerEventRepo().FindByTxAndLog(ctx, tr.TxHash, tr.LogIndex)
	if err != nil {
		t.Fatalf("find event: %v", err)
	}
	if evt.EventType != domain.IndexerEventDeposited {
		t.Errorf("event type after attribution = %q, want %q", evt.EventType, domain.IndexerEventDeposited)
	}
}

// TestOperatorAttributeDepositRejectsStolenAddress: an operator cannot attribute
// a flagged deposit whose sender address belongs to a different user.
func TestOperatorAttributeDepositRejectsStolenAddress(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	owner := newTestUser(t, st, "vault-attr-owner@example.com")
	thief := newTestUser(t, st, "vault-attr-thief@example.com")
	contested := "0xContestedWallet" + uniqueKey("")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newNoFallbackVault(t, st, chain)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	tr := unlinkedTransfer(148, "0xstray-contested", contested)
	chain.AddTransfer(tr)
	chain.SetLatest(150)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan: %v", err)
	}

	// The address is claimed by its real owner before the operator acts.
	if err := st.DepositAddressRepo().Set(ctx, &domain.DepositAddress{UserID: owner.ID, Address: contested}); err != nil {
		t.Fatalf("link owner: %v", err)
	}

	if _, err := v.AttributeDeposit(ctx, tr.TxHash, tr.LogIndex, thief.ID); err != domain.ErrConflict {
		t.Errorf("attributing to a non-owner address: err = %v, want ErrConflict", err)
	}
	if bal := availNGN(t, st, thief.ID); bal != 0 {
		t.Errorf("thief got credited: balance = %d, want 0", bal)
	}

	// The rightful owner can still claim and be credited.
	want := depositNGNMinor(big.NewInt(10_000_000), 160450)
	if _, err := v.AttributeDeposit(ctx, tr.TxHash, tr.LogIndex, owner.ID); err != nil {
		t.Fatalf("attributing to the real owner: %v", err)
	}
	if bal := availNGN(t, st, owner.ID); bal != want {
		t.Errorf("owner balance = %d, want %d", bal, want)
	}
}
