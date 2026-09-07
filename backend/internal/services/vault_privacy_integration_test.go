package services

import (
	"context"
	"math/big"
	"testing"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/infrastructure/blockchain"
)

// privacyVaultContract is the on-chain vault contract address the mock chain
// reports privacy deposit events from.
const privacyVaultContract = "0xGlobmintVaultV2ContractAddress000000000000000000"

// newPrivacyVault builds a VaultService in privacy mode wired to the mock
// chain and the real Postgres store. We always set a fallback user so tests
// PROVE privacy deposits never fall back to it (unlinked commitments are
// dropped, never mis-credited).
func newPrivacyVault(t *testing.T, st store, chain *blockchain.MockBlockchainService, fallbackUserID string) *VaultService {
	t.Helper()
	return NewVaultService(st, chain, NewMoneyService(st), VaultConfig{
		VaultAddress:       vaultAddr,
		VaultContract:      privacyVaultContract,
		StablecoinSymbol:   "USDC",
		StablecoinDecimals: 6,
		MinConfirmations:   3,
		FallbackUserID:     fallbackUserID,
		PrivacyMode:        true,
	}, 160450)
}

// linkPrivacyUser links a deposit address and stores a 16-byte salt for a user
// (exactly what SetDepositAddress does in privacy mode) and returns the salt.
func linkPrivacyUser(t *testing.T, st store, userID, addr string) []byte {
	t.Helper()
	ctx := context.Background()
	if err := st.DepositAddressRepo().Set(ctx, &domain.DepositAddress{UserID: userID, Address: addr}); err != nil {
		t.Fatalf("link deposit address: %v", err)
	}
	salt := []byte("0123456789abcdef") // 16 bytes
	if err := st.UserSaltsRepo().Upsert(ctx, userID, salt); err != nil {
		t.Fatalf("upsert salt: %v", err)
	}
	return salt
}

func vaultDeposit(block uint64, tx string, commitment string, user string) blockchain.VaultDeposit {
	return blockchain.VaultDeposit{
		Commitment:  commitment,
		User:        user,
		Amount:      big.NewInt(10_000_000), // 10 USDC
		TxHash:      uniqueKey(tx),
		BlockNumber: block,
	}
}

// TestIndexerPrivacyDepositCreditsMatchedCommitment: a DepositedPrivate event
// whose commitment matches keccak256(address, salt) for a linked user is
// credited to that user and only that user.
func TestIndexerPrivacyDepositCreditsMatchedCommitment(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-priv-match@example.com")
	fallback := newTestUser(t, st, "vault-priv-fallback@example.com")

	addr := privAddrFor(u.ID) // fixed per-test address
	salt := linkPrivacyUser(t, st, u.ID, addr)

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newPrivacyVault(t, st, chain, fallback.ID)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	chain.AddVaultDeposit(vaultDeposit(148, "0xpriv-match", vaultCommitment(addr, salt), ""))
	chain.SetLatest(153)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan: %v", err)
	}

	want := depositNGNMinor(big.NewInt(10_000_000), 160450)
	if bal := availNGN(t, st, u.ID); bal != want {
		t.Errorf("user balance = %d, want %d", bal, want)
	}
	if bal := availNGN(t, st, fallback.ID); bal != 0 {
		t.Errorf("fallback user credited = %d, want 0", bal)
	}
}

// TestIndexerPrivacyDepositUnlinkedIgnored: a privacy deposit with an unknown
// commitment is ignored — it is never credited to the fallback user (which
// would mis-credit a wallet whose salt we cannot verify).
func TestIndexerPrivacyDepositUnlinkedIgnored(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-priv-unknown@example.com")
	fallback := newTestUser(t, st, "vault-priv-unknown-fb@example.com")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newPrivacyVault(t, st, chain, fallback.ID)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	// Commitment of an address/salt combination that has no user_salts row.
	ghost := "0x" + "F0E1D2C3B4A5968778695A4B3C2D1E0F1A2B3C4"
	chain.AddVaultDeposit(vaultDeposit(148, "0xpriv-unknown", vaultCommitment(ghost, []byte("0123456789abcdef")), ""))
	chain.SetLatest(153)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan: %v", err)
	}

	if bal := availNGN(t, st, fallback.ID); bal != 0 {
		t.Errorf("unlinked commitment credited fallback = %d, want 0", bal)
	}
	if bal := availNGN(t, st, u.ID); bal != 0 {
		t.Errorf("unrelated user credited = %d, want 0", bal)
	}

	// The cursor still advanced: the window is consumed, nothing is stuck.
	last, _ := st.IndexerStateRepo().LastBlock(ctx)
	if last != 149 {
		t.Errorf("persisted cursor = %d, want 149", last)
	}
}

// TestIndexerLegacyEventStillResolvesRawAddress: the vault indexer still
// supports the legacy Deposited event (raw address in the topics) even in a
// privacy-capable service — the address is resolved through the deposit-address
// link exactly as the transfer path did.
func TestIndexerLegacyEventStillResolvesRawAddress(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-priv-legacy@example.com")
	fallback := newTestUser(t, st, "vault-priv-legacy-fb@example.com")

	addr := privAddrFor(u.ID)
	salt := linkPrivacyUser(t, st, u.ID, addr)

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newPrivacyVault(t, st, chain, fallback.ID)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	legacy := vaultDeposit(148, "0xlegacy-raw", vaultCommitment(addr, salt), addr)
	chain.AddVaultDeposit(legacy)
	chain.SetLatest(153)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan: %v", err)
	}

	want := depositNGNMinor(big.NewInt(10_000_000), 160450)
	if bal := availNGN(t, st, u.ID); bal != want {
		t.Errorf("user balance = %d, want %d", bal, want)
	}
	if bal := availNGN(t, st, fallback.ID); bal != 0 {
		t.Errorf("fallback credited = %d, want 0", bal)
	}
}

// TestIndexerPrivacyResumeAndIdempotency: privacy deposits are credited from
// the persisted cursor, and a crash-replay of the same window never double
// credits (the commitment+log-index idempotency key dedupes).
func TestIndexerPrivacyResumeAndIdempotency(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	resetCursor(t, st)
	u := newTestUser(t, st, "vault-priv-replay@example.com")
	fallback := newTestUser(t, st, "vault-priv-replay-fb@example.com")

	addr := privAddrFor(u.ID)
	salt := linkPrivacyUser(t, st, u.ID, addr)
	dep := vaultDeposit(148, "0xpriv-replay", vaultCommitment(addr, salt), "")

	chain := blockchain.NewMockBlockchainService()
	chain.SetLatest(100)
	v := newPrivacyVault(t, st, chain, fallback.ID)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("baseline scan: %v", err)
	}

	chain.AddVaultDeposit(dep)
	chain.SetLatest(153)
	if err := v.scan(ctx); err != nil {
		t.Fatalf("scan: %v", err)
	}
	bal := availNGN(t, st, u.ID)
	want := depositNGNMinor(big.NewInt(10_000_000), 160450)
	if bal != want {
		t.Fatalf("balance = %d, want %d", bal, want)
	}
	last, _ := st.IndexerStateRepo().LastBlock(ctx)
	if last != 149 {
		t.Fatalf("persisted cursor = %d, want 149", last)
	}

	// Simulate a crash before the cursor persisted: force the in-memory cursor
	// back and replay the same window — must not double credit.
	v.lastBlock = 100
	if err := v.scan(ctx); err != nil {
		t.Fatalf("rescan same window: %v", err)
	}
	if got := availNGN(t, st, u.ID); got != bal {
		t.Errorf("balance after replay = %d, want %d (no double credit)", got, bal)
	}

	// A genuinely new privacy deposit after resume credits once more.
	chain.AddVaultDeposit(vaultDeposit(152, "0xpriv-new", vaultCommitment(addr, salt), ""))
	chain.SetLatest(156) // confirmed head = 153
	v2 := newPrivacyVault(t, st, chain, fallback.ID)
	if err := v2.resumeCursor(ctx); err != nil {
		t.Fatalf("resume cursor: %v", err)
	}
	if err := v2.scan(ctx); err != nil {
		t.Fatalf("v2 scan: %v", err)
	}
	if got := availNGN(t, st, u.ID); got != bal+want {
		t.Errorf("balance after resume = %d, want %d", got, bal+want)
	}
}