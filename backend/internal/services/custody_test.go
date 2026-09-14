package services

import (
	"context"
	"errors"
	"strings"
	"testing"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/eip712"
	"globmint/backend/internal/infrastructure/blockchain"
)

// TestCustody_UnclaimedWhileOwnedByPlaceholder covers the pre-claim state: the
// clone is owned by the platform placeholder signer, so the account is NOT
// claimed and must take custody before wallet-signed withdrawals.
func TestCustody_UnclaimedWhileOwnedByPlaceholder(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-unclaimed@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	clone := seedClone(t, v, chain, u.ID, vaultAddr)

	status, err := v.CustodyStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("custody status: %v", err)
	}
	if status.Clone != clone {
		t.Errorf("status clone = %s, want %s", status.Clone, clone)
	}
	if !strings.EqualFold(status.Owner, vaultAddr) {
		t.Errorf("status owner = %s, want %s", status.Owner, vaultAddr)
	}
	if status.Placeholder != vaultAddr {
		t.Errorf("status placeholder = %s, want %s", status.Placeholder, vaultAddr)
	}
	if status.Claimed {
		t.Error("placeholder-owned clone must NOT be claimed")
	}
}

// TestCustody_ClaimedOnceOwnedByTheUsersWallet covers the post-claim state: a
// linked-wallet owner (or a completed transferOwnershipBySig) makes the clone
// owned by the user, so it is claimed and can sign withdrawals.
func TestCustody_ClaimedOnceOwnedByTheUsersWallet(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-claimed@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	owner := "0x1111111111111111111111111111111111111111"
	clone := seedClone(t, v, chain, u.ID, owner)

	status, err := v.CustodyStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("custody status: %v", err)
	}
	if status.Clone != clone {
		t.Errorf("status clone = %s, want %s", status.Clone, clone)
	}
	if !strings.EqualFold(status.Owner, owner) {
		t.Errorf("status owner = %s, want %s", status.Owner, owner)
	}
	if status.Placeholder != vaultAddr {
		t.Errorf("status placeholder = %s, want %s", status.Placeholder, vaultAddr)
	}
	if !status.Claimed {
		t.Error("wallet-owned clone must be claimed")
	}
}

// TestCustody_NoCloneIsNotClaimed covers an account with no deployed clone yet:
// the status is empty and, crucially, NOT claimed (the account must first get
// its deposit address via EnsureClone before signing anything).
func TestCustody_NoCloneIsNotClaimed(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-noclone@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	status, err := v.CustodyStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("custody status: %v", err)
	}
	if status.Clone != "" {
		t.Errorf("status clone = %s, want empty", status.Clone)
	}
	if status.Owner != "" {
		t.Errorf("status owner = %s, want empty", status.Owner)
	}
	if status.Claimed {
		t.Error("account without a clone must not be claimed")
	}
}

// TestCustody_ReportsSharedNonce verifies the nonce the custody claim and the
// withdrawal/recovery signatures all share is surfaced to the client.
func TestCustody_ReportsSharedNonce(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-nonce@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	clone := seedClone(t, v, chain, u.ID, vaultAddr)
	chain.SetCloneNonce(clone, 7)

	status, err := v.CustodyStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("custody status: %v", err)
	}
	if status.Nonce != 7 {
		t.Errorf("status nonce = %d, want 7", status.Nonce)
	}
}

// TestCustody_FallsBackToCacheOnChainError covers the node-outage path: the
// last known good owner is repeated instead of inventing a fresh answer.
func TestCustody_FallsBackToCacheOnChainError(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-cache@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	owner := "0x2222222222222222222222222222222222222222"
	clone := seedClone(t, v, chain, u.ID, owner)

	// Prime the cache with the chain truth.
	first, err := v.CustodyStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("custody status (prime): %v", err)
	}
	if !first.Claimed {
		t.Fatal("wallet-owned clone must be claimed")
	}

	// Node drops: the chain read fails, the cached owner is repeated.
	chain.SetCloneReadError(errors.New("node unreachable"))
	status, err := v.CustodyStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("custody status (fallback): %v", err)
	}
	if status.Clone != clone {
		t.Errorf("status clone = %s, want %s", status.Clone, clone)
	}
	if !strings.EqualFold(status.Owner, owner) {
		t.Errorf("status owner = %s, want cached %s", status.Owner, owner)
	}
	if !status.Claimed {
		t.Error("cached wallet-owner must stay claimed during an outage")
	}
}

// TestCustody_NodeErrorWithNoCacheStaysUnclaimed ensures an outage with no
// cached snapshot never fabricates a claimed owner.
func TestCustody_NodeErrorWithNoCacheStaysUnclaimed(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-nocache@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	seedClone(t, v, chain, u.ID, vaultAddr)
	chain.SetCloneReadError(errors.New("node unreachable"))

	status, err := v.CustodyStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("custody status (no cache): %v", err)
	}
	if status.Owner != "" {
		t.Errorf("status owner = %s, want empty when no cache", status.Owner)
	}
	if status.Claimed {
		t.Error("must never claim without chain or cache truth")
	}
}

// TestCustodyClaim_PrepareAndRelay covers the happy path: the platform signer
// (the CURRENT owner of the unclaimed clone) quotes and then signs the
// transferOwnershipBySig handing the owner seat to the user's wallet.
func TestCustodyClaim_PrepareAndRelay(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-claim@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	clone := seedClone(t, v, chain, u.ID, vaultAddr)
	newOwner := "0x4444444444444444444444444444444444444444"

	quote, err := v.PrepareCustodyClaim(ctx, u.ID, newOwner)
	if err != nil {
		t.Fatalf("prepare custody: %v", err)
	}
	if quote.Domain.Name != eip712.DomainName || quote.Domain.VerifyingContract != clone {
		t.Errorf("quote domain mismatch: %+v", quote.Domain)
	}
	if quote.Message.NewOwner.Hex() != newOwner {
		t.Errorf("quote new owner = %s, want %s", quote.Message.NewOwner.Hex(), newOwner)
	}
	if !strings.EqualFold(quote.Owner, vaultAddr) {
		t.Errorf("quote owner = %s, want placeholder %s", quote.Owner, vaultAddr)
	}
	if quote.Message.Deadline <= 0 {
		t.Error("quote deadline must be a fresh unix timestamp")
	}

	txHash, err := v.ClaimCustody(ctx, u.ID, newOwner)
	if err != nil {
		t.Fatalf("claim custody: %v", err)
	}
	if txHash == "" {
		t.Fatal("expected a tx hash")
	}

	transfers := chain.OwnershipTransfers()
	if len(transfers) != 1 {
		t.Fatalf("ownership transfers = %d, want 1", len(transfers))
	}
	tr := transfers[0]
	if tr.Clone != clone {
		t.Errorf("relay clone = %s, want %s", tr.Clone, clone)
	}
	if tr.NewOwner != newOwner {
		t.Errorf("relay new owner = %s, want %s", tr.NewOwner, newOwner)
	}
	if tr.Nonce != 0 {
		t.Errorf("relay nonce = %d, want 0 (the shared current nonce)", tr.Nonce)
	}
	if tr.Deadline <= 0 {
		t.Errorf("relay deadline = %d, want fresh", tr.Deadline)
	}

	// The claim used the CURRENT nonce — quote and claim agree.
	if quote.Message.Nonce != tr.Nonce {
		t.Errorf("quote nonce = %d, relay nonce = %d: prepare and claim must cover the same nonce",
			quote.Message.Nonce, tr.Nonce)
	}

	// State after the relay: the wallet owns the clone and it is claimed.
	ownerNow, _ := chain.CloneOwner(ctx, clone)
	if !strings.EqualFold(ownerNow, newOwner) {
		t.Errorf("chain owner after claim = %s, want %s", ownerNow, newOwner)
	}
	if nextNonce, _ := chain.CloneNonce(ctx, clone); nextNonce != 1 {
		t.Errorf("clone nonce after claim = %d, want 1", nextNonce)
	}
	status, err := v.CustodyStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("custody status after claim: %v", err)
	}
	if !status.Claimed {
		t.Error("clone must be claimed after the transfer")
	}
	if !strings.EqualFold(status.Owner, newOwner) {
		t.Errorf("status owner after claim = %s, want %s", status.Owner, newOwner)
	}
}

// TestCustodyClaim_SealedOnceClaimed covers idempotence: once the wallet owns
// the clone, both prepare and claim refuse with ErrCustodyAlreadyClaimed.
func TestCustodyClaim_SealedOnceClaimed(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-claimed-sealed@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	seedClone(t, v, chain, u.ID, "0x4444444444444444444444444444444444444444")

	if _, err := v.PrepareCustodyClaim(ctx, u.ID, "0x5555555555555555555555555555555555555555"); !errors.Is(err, domain.ErrCustodyAlreadyClaimed) {
		t.Fatalf("prepare on claimed clone error = %v, want ErrCustodyAlreadyClaimed", err)
	}
	if _, err := v.ClaimCustody(ctx, u.ID, "0x5555555555555555555555555555555555555555"); !errors.Is(err, domain.ErrCustodyAlreadyClaimed) {
		t.Fatalf("claim on claimed clone error = %v, want ErrCustodyAlreadyClaimed", err)
	}
	if n := len(chain.OwnershipTransfers()); n != 0 {
		t.Errorf("ownership transfers = %d, want 0 (nothing may relay)", n)
	}
}

// TestCustodyClaim_NoCloneRequiresCustody covers the missing-clone guard: an
// account with no deposited clone cannot claim custody (it has nothing to
// claim) — surfaced as the withdrawal custody error.
func TestCustodyClaim_NoCloneRequiresCustody(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-noclone-gated@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	if _, err := v.ClaimCustody(ctx, u.ID, "0x4444444444444444444444444444444444444444"); !errors.Is(err, domain.ErrWithdrawRequiresCustody) {
		t.Fatalf("claim without a clone error = %v, want ErrWithdrawRequiresCustody", err)
	}
}

// TestCustodyClaim_ValidatesNewOwner covers input guards: invalid addresses,
// zero addresses, and the current owner being asked to re-claim are refused.
func TestCustodyClaim_ValidatesNewOwner(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "custody-validation@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	clone := seedClone(t, v, chain, u.ID, vaultAddr)

	if _, err := v.ClaimCustody(ctx, u.ID, "not-an-address"); !errors.Is(err, domain.ErrInvalidAddress) {
		t.Fatalf("invalid address error = %v, want ErrInvalidAddress", err)
	}
	if _, err := v.ClaimCustody(ctx, u.ID, "0x0000000000000000000000000000000000000000"); !errors.Is(err, domain.ErrInvalidAddress) {
		t.Fatalf("zero address error = %v, want ErrInvalidAddress", err)
	}
	// The placeholder cannot claim from itself.
	if _, err := v.ClaimCustody(ctx, u.ID, strings.ToLower(vaultAddr)); !errors.Is(err, domain.ErrInvalidAddress) {
		t.Fatalf("same-owner error = %v, want ErrInvalidAddress", err)
	}
	_ = clone
	if n := len(chain.OwnershipTransfers()); n != 0 {
		t.Errorf("ownership transfers = %d, want 0", n)
	}
}