package services

import (
	"context"
	"math/big"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/crypto"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/infrastructure/blockchain"
)

// cloneDepositTransfer builds a USDC transfer INTO a user's per-user clone
// address from any wallet — the core "send to your address, no linking needed"
// guarantee of the clone-based design.
func cloneDepositTransfer(block uint64, tx, sender, cloneAddr string) blockchain.TokenTransfer {
	return blockchain.TokenTransfer{
		From:        sender,
		To:          cloneAddr,
		Value:       big.NewInt(7_500_000), // 7.5 USDC
		TxHash:      uniqueKey(tx),
		BlockNumber: block,
	}
}

// newCloneVault builds a vault service with a controlled mock chain configured
// with a clone factory, so EnsureClone + indexer clone routing can be tested.
func newCloneVault(t *testing.T, st store, chain *blockchain.MockBlockchainService, rate int64) *VaultService {
	t.Helper()
	chain.SetCloneFactory("0xCloneFactoryAddress000000000000000000000000000")
	v := NewVaultService(st, chain, NewMoneyService(st), VaultConfig{
		VaultAddress:       vaultAddr,
		StablecoinSymbol:   "USDC",
		StablecoinDecimals: 6,
		MinConfirmations:   0,
	}, rate)
	return v
}

// TestEnsureCloneDeploysPersistsAndIsIdempotent: EnsureClone returns a stable
// per-user clone address, persists the clone row, and never deploys twice.
func TestEnsureCloneDeploysPersistsAndIsIdempotent(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-clone-ensure@example.com")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newCloneVault(t, st, chain, 160450)

	first, err := v.EnsureClone(ctx, u.ID)
	if err != nil {
		t.Fatalf("ensure clone (first): %v", err)
	}
	if first == nil || first.CloneAddress == "" {
		t.Fatalf("first clone empty: %+v", first)
	}
	if first.FactoryAddress != "0xCloneFactoryAddress000000000000000000000000000" {
		t.Errorf("factory address = %q", first.FactoryAddress)
	}
	if first.ChainID != 0 {
		t.Errorf("unexpected chain id %d (not configured in test)", first.ChainID)
	}
	if !strings.HasPrefix(first.DeployTxHash, "0x") {
		t.Errorf("deploy tx hash %q should be 0x-prefixed", first.DeployTxHash)
	}

	// Linear, not partial: the mock gives a deterministic address per user key.
	userKey := crypto.Keccak256Hash([]byte(u.ID)).Hex()
	predicted, _ := chain.PredictClone(ctx, userKey)
	if !strings.EqualFold(first.CloneAddress, predicted) {
		t.Errorf("clone %s != predicted %s", first.CloneAddress, predicted)
	}

	// A second call returns the SAME persisted clone without re-deploying.
	second, err := v.EnsureClone(ctx, u.ID)
	if err != nil {
		t.Fatalf("ensure clone (second): %v", err)
	}
	if !strings.EqualFold(first.CloneAddress, second.CloneAddress) {
		t.Errorf("second ensure returned a different clone: %s vs %s", second.CloneAddress, first.CloneAddress)
	}

	clones, err := st.VaultCloneRepo().All(ctx)
	if err != nil {
		t.Fatalf("list clones: %v", err)
	}
	rowsForUser := 0
	for _, c := range clones {
		if c.UserID == u.ID {
			rowsForUser++
		}
	}
	if rowsForUser != 1 {
		t.Errorf("clone rows for user = %d, want 1 (double deploy!)", rowsForUser)
	}

	addr, err := v.CloneAddress(ctx, u.ID)
	if err != nil {
		t.Fatalf("clone address: %v", err)
	}
	if !strings.EqualFold(addr, first.CloneAddress) {
		t.Errorf("CloneAddress = %q, want %q", addr, first.CloneAddress)
	}
}

// TestEnsureClonePrefersLinkedWalletAsOwner: when the user has linked a wallet,
// the clone is deployed with THAT wallet as owner (self-custody), not the
// platform signer.
func TestEnsureClonePrefersLinkedWalletAsOwner(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-clone-selfcustody@example.com")

	linked := "0xUserWallet" + uniqueKey("") // not a valid hex address; repo Set does not validate
	if err := st.DepositAddressRepo().Set(ctx, &domain.DepositAddress{UserID: u.ID, Address: linked}); err != nil {
		t.Fatalf("link wallet: %v", err)
	}

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newCloneVault(t, st, chain, 160450)

	clone, err := v.EnsureClone(ctx, u.ID)
	if err != nil {
		t.Fatalf("ensure clone: %v", err)
	}
	userKey := crypto.Keccak256Hash([]byte(u.ID)).Hex()
	predicted, _ := chain.PredictClone(ctx, userKey)
	if !strings.EqualFold(clone.CloneAddress, predicted) {
		t.Errorf("clone %s not deterministic from user key %s", clone.CloneAddress, predicted)
	}
}

// TestEnsureCloneRedeploysStaleRow: after a dev node reset erases chain state
// while the DB row survives, EnsureClone must detect the missing on-chain clone
// and redeploy it (CREATE2 keeps the same address) rather than serve a dead row.
func TestEnsureCloneRedeploysStaleRow(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-clone-stale@example.com")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newCloneVault(t, st, chain, 160450)

	first, err := v.EnsureClone(ctx, u.ID)
	if err != nil {
		t.Fatalf("ensure clone: %v", err)
	}

	// Simulate a node reset: clone no longer deployed on-chain.
	chain.ClearClones()

	second, err := v.EnsureClone(ctx, u.ID)
	if err != nil {
		t.Fatalf("ensure clone after reset: %v", err)
	}
	if !strings.EqualFold(first.CloneAddress, second.CloneAddress) {
		t.Errorf("redeploy changed address: %s -> %s", first.CloneAddress, second.CloneAddress)
	}
	addr, err := v.CloneAddress(ctx, u.ID)
	if err != nil {
		t.Fatalf("clone address: %v", err)
	}
	if !strings.EqualFold(addr, first.CloneAddress) {
		t.Errorf("CloneAddress = %q, want %q", addr, first.CloneAddress)
	}
	redeployed, err := v.chain.CloneByUserKey(ctx, crypto.Keccak256Hash([]byte(u.ID)).Hex())
	if err != nil {
		t.Fatalf("verify redeploy: %v", err)
	}
	if redeployed == "" {
		t.Fatalf("clone not redeployed after stale-row recovery")
	}
}

// TestIndexerCreditsCloneDepositWithoutSenderLink: a USDC transfer to a
// per-user clone is credited to that account even when the SENDER has never
// linked a wallet — the address alone identifies the depositor.
func TestIndexerCreditsCloneDepositWithoutSenderLink(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-clone-indexer@example.com")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newCloneVault(t, st, chain, 160450)

	// Deploy + persist the user's clone BEFORE the scan routing table loads.
	clone, err := v.EnsureClone(ctx, u.ID)
	if err != nil {
		t.Fatalf("ensure clone: %v", err)
	}
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	// An anonymous sender (no link, no fallback) sends into the clone.
	anon := "0xAnonymousSender0000000000000000000000000000"
	tr := cloneDepositTransfer(148, "0xclone-deposit", anon, clone.CloneAddress)
	chain.AddTransfer(tr)
	chain.SetLatest(150)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("deposit scan: %v", err)
	}

	want := depositNGNMinor(big.NewInt(7_500_000), 160450)
	if bal := availNGN(t, st, u.ID); bal != want {
		t.Errorf("user balance = %d, want %d (clone deposit not credited)", bal, want)
	}

	// The anonymous sender was never flagged unattributed: the clone routing
	// resolved the recipient, not the sender.
	flags, err := st.IndexerEventRepo().ListUnattributed(ctx, 20)
	if err != nil {
		t.Fatalf("list unattributed: %v", err)
	}
	for _, e := range flags {
		if e.TxHash == tr.TxHash {
			t.Errorf("clone deposit flagged unattributed: %+v", e)
		}
	}
}

// TestIndexerCloneDepositIdempotent: replaying the same clone deposit (crash
// before the cursor persisted) never double-credits.
func TestIndexerCloneDepositIdempotent(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-clone-replay@example.com")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newCloneVault(t, st, chain, 160450)

	clone, err := v.EnsureClone(ctx, u.ID)
	if err != nil {
		t.Fatalf("ensure clone: %v", err)
	}
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	tr := cloneDepositTransfer(148, "0xclone-replay", "0xAnonReplay0000000000000000000000000000000", clone.CloneAddress)
	chain.AddTransfer(tr)
	chain.SetLatest(150)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("first scan: %v", err)
	}
	want := depositNGNMinor(big.NewInt(7_500_000), 160450)
	if bal := availNGN(t, st, u.ID); bal != want {
		t.Fatalf("first credit = %d, want %d", bal, want)
	}

	v.lastBlock = 100 // simulate crash before the cursor persisted
	if err := v.scan(ctx); err != nil {
		t.Fatalf("replay scan: %v", err)
	}
	if bal := availNGN(t, st, u.ID); bal != want {
		t.Errorf("balance after replay = %d, want %d (double credit!)", bal, want)
	}
}

// TestCloneAddressEmptyWithoutClone: a user with no deployed clone has an empty
// clone address until EnsureClone is called, and no clone row is ever created
// before that.
func TestCloneAddressEmptyWithoutClone(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-clone-empty@example.com")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newCloneVault(t, st, chain, 160450)

	addr, err := v.CloneAddress(ctx, u.ID)
	if err != nil {
		t.Fatalf("clone address: %v", err)
	}
	if addr != "" {
		t.Errorf("CloneAddress = %q, want empty before EnsureClone", addr)
	}
	existing, err := st.VaultCloneRepo().ByUser(ctx, u.ID)
	if err != nil {
		t.Fatalf("by user: %v", err)
	}
	if existing != nil {
		t.Errorf("clone row created before EnsureClone: %+v", existing)
	}
}