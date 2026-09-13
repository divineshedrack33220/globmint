package services

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/eip712"
	"globmint/backend/internal/infrastructure/blockchain"
)

// signRecovery signs a SetRecovery request from `key` and wraps it in the
// client-shaped domain.WithdrawSignature (reusing the signed-intent envelope).
func signRecovery(t *testing.T, chainID int64, clone, recovery string, nonce uint64, deadline int64, key *ecdsa.PrivateKey) *domain.WithdrawSignature {
	t.Helper()
	digest := eip712.SetRecoveryDigest(chainID, common.HexToAddress(clone), eip712.SetRecoveryRequest{
		RecoveryAddress: common.HexToAddress(recovery),
		Nonce:           nonce,
		Deadline:        deadline,
	})
	sig, err := eip712.SignDigest(digest, key)
	if err != nil {
		t.Fatalf("sign recovery: %v", err)
	}
	return &domain.WithdrawSignature{
		Signature:  "0x" + common.Bytes2Hex(sig),
		Deadline:   deadline,
		RelayNonce: nonce,
	}
}

// TestRecovery_OwnerDesignatesRecoveryAddress: the clone owner signs a
// SetRecovery request, the backend relays the exact setRecoveryAddressBySig,
// the mock records the recovery address, and the nonce advances so the
// designation cannot be replayed as a withdrawal.
func TestRecovery_OwnerDesignatesRecoveryAddress(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "recovery-set@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	ownerKey, err := crypto.GenerateKey()
	if err != nil {
		t.Fatalf("generate owner key: %v", err)
	}
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	recovery := "0x2222222222222222222222222222222222222222"
	deadline := time.Now().UTC().Add(15 * time.Minute).Unix()
	sig := signRecovery(t, testChainID, clone, recovery, 0, deadline, ownerKey)

	txHash, err := v.SetRecoveryAddressBySig(ctx, u.ID, recovery, sig)
	if err != nil {
		t.Fatalf("set recovery: %v", err)
	}
	if txHash == "" {
		t.Fatal("expected a tx hash")
	}

	relays := chain.RecoveryRelays()
	if len(relays) != 1 {
		t.Fatalf("recovery relays = %d, want 1", len(relays))
	}
	r := relays[0]
	if r.Clone != clone {
		t.Errorf("relay clone = %s, want %s", r.Clone, clone)
	}
	if r.RecoveryAddress != recovery {
		t.Errorf("relay recovery = %s, want %s", r.RecoveryAddress, recovery)
	}
	if r.Nonce != 0 || r.Deadline != deadline {
		t.Errorf("relay nonce/deadline = %d/%d, want 0/%d", r.Nonce, r.Deadline, deadline)
	}

	// The on-chain recovery address is set and the nonce advanced (shared
	// nonce with withdrawals: a withdrawal signature at nonce 0 is dead).
	recoverySet, _ := chain.CloneRecoveryAddress(ctx, clone)
	if !strings.EqualFold(recoverySet, recovery) {
		t.Errorf("chain recovery = %s, want %s", recoverySet, recovery)
	}
	if nextNonce, _ := chain.CloneNonce(ctx, clone); nextNonce != 1 {
		t.Errorf("clone nonce after recovery = %d, want 1", nextNonce)
	}
}

// TestRecovery_WrongOwnerRejected: only the clone owner's signature can
// designate a recovery address; a stranger's signature is rejected before any
// broadcast.
func TestRecovery_WrongOwnerRejected(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "recovery-wrong@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	intruder, _ := crypto.GenerateKey()
	recovery := "0x3333333333333333333333333333333333333333"
	sig := signRecovery(t, testChainID, clone, recovery, 0, time.Now().UTC().Add(time.Hour).Unix(), intruder)

	_, err := v.SetRecoveryAddressBySig(ctx, u.ID, recovery, sig)
	if !errors.Is(err, domain.ErrInvalidSignature) {
		t.Fatalf("err = %v, want ErrInvalidSignature", err)
	}
	if n := len(chain.RecoveryRelays()); n != 0 {
		t.Errorf("recovery relays = %d, want 0", n)
	}
	if rec, _ := chain.CloneRecoveryAddress(ctx, clone); rec != "" {
		t.Errorf("recovery set on chain = %s, want none", rec)
	}
}

// TestRecovery_ExpiredRejected: an expired SetRecovery signature is rejected
// before any broadcast.
func TestRecovery_ExpiredRejected(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "recovery-expired@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	recovery := "0x4444444444444444444444444444444444444444"
	sig := signRecovery(t, testChainID, clone, recovery, 0, time.Now().UTC().Add(-time.Second).Unix(), ownerKey)

	_, err := v.SetRecoveryAddressBySig(ctx, u.ID, recovery, sig)
	if !errors.Is(err, domain.ErrSignatureExpired) {
		t.Fatalf("err = %v, want ErrSignatureExpired", err)
	}
	if n := len(chain.RecoveryRelays()); n != 0 {
		t.Errorf("recovery relays = %d, want 0", n)
	}
}

// TestRecovery_RequiresCustody: an account with no clone cannot designate a
// recovery address.
func TestRecovery_RequiresCustody(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "recovery-noclone@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	recovery := "0x5555555555555555555555555555555555555555"
	if _, err := v.SetRecoveryAddressBySig(ctx, u.ID, recovery, &domain.WithdrawSignature{
		Signature:  "0x" + common.Bytes2Hex(make([]byte, 65)),
		Deadline:   time.Now().UTC().Add(time.Hour).Unix(),
	}); !errors.Is(err, domain.ErrWithdrawRequiresCustody) {
		t.Fatalf("err = %v, want ErrWithdrawRequiresCustody", err)
	}
}

// TestRecovery_PrepareMatchesSet: a PrepareRecovery quote (domain + message)
// ties directly into SetRecoveryAddressBySig, so a signature over the quoted
// message authorizes exactly the recovery address that gets relayed.
func TestRecovery_PrepareMatchesSet(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "recovery-prepare@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	recovery := "0x6666666666666666666666666666666666666666"
	quote, err := v.PrepareRecovery(ctx, u.ID, recovery)
	if err != nil {
		t.Fatalf("prepare recovery: %v", err)
	}
	if quote.Domain.Name != eip712.DomainName || quote.Domain.VerifyingContract != clone {
		t.Errorf("quote domain mismatch: %+v", quote.Domain)
	}
	if quote.Message.RecoveryAddress.Hex() != recovery {
		t.Errorf("quote recovery = %s, want %s", quote.Message.RecoveryAddress.Hex(), recovery)
	}
	if !strings.EqualFold(quote.Owner, owner.Hex()) {
		t.Errorf("quote owner = %s, want %s", quote.Owner, owner.Hex())
	}

	// Sign the quoted message and relay it: exact same nonce + deadline.
	digest := eip712.SetRecoveryDigest(testChainID, common.HexToAddress(clone), quote.Message)
	sigBytes, err := eip712.SignDigest(digest, ownerKey)
	if err != nil {
		t.Fatalf("sign quoted recovery: %v", err)
	}
	sig := &domain.WithdrawSignature{
		Signature:  "0x" + common.Bytes2Hex(sigBytes),
		Deadline:   quote.Message.Deadline,
		RelayNonce: quote.Message.Nonce,
	}
	if _, err := v.SetRecoveryAddressBySig(ctx, u.ID, recovery, sig); err != nil {
		t.Fatalf("set recovery from quote: %v", err)
	}
	if rec, _ := chain.CloneRecoveryAddress(ctx, clone); rec != recovery {
		t.Errorf("chain recovery = %s, want %s", rec, recovery)
	}
}

// TestRecovery_StatusReflectsChain: RecoveryStatus returns the on-chain
// recovery state (address, delay, pending window) for the user's clone, and
// writes it through into the DB cache.
func TestRecovery_StatusReflectsChain(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "recovery-status@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	recovery := "0x7777777777777777777777777777777777777777"
	chain.SetCloneRecovery(clone, recovery, 3600, 0)

	st1, err := v.RecoveryStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("recovery status: %v", err)
	}
	if !strings.EqualFold(st1.Clone, clone) || !strings.EqualFold(st1.Owner, owner.Hex()) {
		t.Errorf("status clone/owner = %s/%s", st1.Clone, st1.Owner)
	}
	if st1.RecoveryAddress != recovery {
		t.Errorf("status recovery = %s, want %s", st1.RecoveryAddress, recovery)
	}
	if st1.RecoveryDelaySec != 3600 {
		t.Errorf("status delay = %d, want 3600", st1.RecoveryDelaySec)
	}
	if st1.RecoveryPending {
		t.Errorf("status pending = true, want false (no requested-at yet)")
	}
	if st1.RecoveryAt != 0 {
		t.Errorf("status recovery_at = %d, want 0", st1.RecoveryAt)
	}

	// A successful read wrote the state through into the DB cache.
	cached, err := st.VaultCloneRepo().RecoveryCache(ctx, u.ID)
	if err != nil {
		t.Fatalf("recovery cache read: %v", err)
	}
	if cached == nil {
		t.Fatal("expected a cached snapshot after a successful status read")
	}
	if !strings.EqualFold(cached.Owner, owner.Hex()) || cached.RecoveryAddress != recovery || cached.RecoveryDelay != 3600 {
		t.Errorf("cached snapshot = %+v", cached)
	}

	// An in-flight recovery shows the executable window.
	const requestedAt = 1_750_000_000
	chain.SetCloneRecovery(clone, recovery, 3600, requestedAt)
	st2, err := v.RecoveryStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("recovery status (pending): %v", err)
	}
	if !st2.RecoveryPending {
		t.Fatal("status pending = false, want true")
	}
	if st2.RecoveryRequestedAt != requestedAt || st2.RecoveryAt != requestedAt+3600 {
		t.Errorf("status window = %d..%d, want %d..%d", st2.RecoveryRequestedAt, st2.RecoveryAt, requestedAt, requestedAt+3600)
	}

	// An account with no clone reports an empty status (no error).
	u2 := newTestUser(t, st, "recovery-noclone-status@example.com")
	st0, err := v.RecoveryStatus(ctx, u2.ID)
	if err != nil {
		t.Fatalf("recovery status (no clone): %v", err)
	}
	if st0.Clone != "" || st0.RecoveryAddress != "" || st0.RecoveryPending {
		t.Errorf("empty status = %+v", st0)
	}
}

// TestRecovery_ChainDownFallsBackToCache: when the node is unreachable the
// status surface keeps working off the last cached snapshot (never fabricated).
func TestRecovery_ChainDownFallsBackToCache(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "recovery-cache@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	recovery := "0x8888888888888888888888888888888888888888"
	chain.SetCloneRecovery(clone, recovery, 7200, 0)
	if _, err := v.RecoveryStatus(ctx, u.ID); err != nil {
		t.Fatalf("prime cache: %v", err)
	}

	// Node goes down: reads fail, but the cached snapshot is still served.
	chain.SetCloneReadError(errors.New("chain unreachable"))
	st1, err := v.RecoveryStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("status during outage: %v", err)
	}
	if st1.Clone != clone {
		t.Errorf("status clone = %s, want %s", st1.Clone, clone)
	}
	if !strings.EqualFold(st1.Owner, owner.Hex()) {
		t.Errorf("status owner = %s, want %s (cached)", st1.Owner, owner.Hex())
	}
	if st1.RecoveryAddress != recovery || st1.RecoveryDelaySec != 7200 {
		t.Errorf("status recovery during outage = %s/%d, want %s/7200", st1.RecoveryAddress, st1.RecoveryDelaySec, recovery)
	}
}

// TestRecovery_ReconcilerRefreshesCache: the reconciler keeps the DB cache
// close to chain truth across all clones, including a freshly designated
// recovery the status surface will then serve during an outage.
func TestRecovery_ReconcilerRefreshesCache(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "recovery-reconciler@example.com")

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	// Chain holds a recovery the DB cache has not seen yet.
	recovery := "0x9999999999999999999999999999999999999999"
	chain.SetCloneRecovery(clone, recovery, 86400, 0)

	// Reconciler walks all deployed clones and syncs the cache.
	if err := v.reconcileRecoveryCache(ctx); err != nil {
		t.Fatalf("reconcile: %v", err)
	}
	cached, err := st.VaultCloneRepo().RecoveryCache(ctx, u.ID)
	if err != nil || cached == nil {
		t.Fatalf("recovery cache read: %v", err)
	}
	if cached.RecoveryAddress != recovery || cached.RecoveryDelay != 86400 {
		t.Errorf("reconciled cache = %+v", cached)
	}

	// After the node goes down the status surface serves the reconciled state.
	chain.SetCloneReadError(errors.New("chain unreachable"))
	st1, err := v.RecoveryStatus(ctx, u.ID)
	if err != nil {
		t.Fatalf("status during outage: %v", err)
	}
	if !strings.EqualFold(st1.RecoveryAddress, recovery) || st1.RecoveryDelaySec != 86400 {
		t.Errorf("status during outage = %s/%d, want %s/86400", st1.RecoveryAddress, st1.RecoveryDelaySec, recovery)
	}
}