package services

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"math/big"
	"strings"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/eip712"
	"globmint/backend/internal/infrastructure/blockchain"
)

// testChainID is the EIP-712 chain id used across these tests (matches the
// vault config so signed digests line up).
const testChainID = int64(31337)

// newSignatureVault builds a real-mode vault whose withdrawals must come from
// per-user clones (relay path). When requireSig is true the platform can never
// sign on the user's behalf. Threshold 0 = no time-lock (instant withdrawals).
func newSignatureVault(t *testing.T, st store, chain *blockchain.MockBlockchainService, userID string, requireSig bool) *VaultService {
	t.Helper()
	return newSignatureVaultT(t, st, chain, userID, requireSig, 0, 24*time.Hour)
}

// newSignedElevationVault is newSignatureVault with a 10M-threshold time-lock
// and a near-zero delay so sweeps fire almost immediately in tests.
func newSignedElevationVault(t *testing.T, st store, chain *blockchain.MockBlockchainService, userID string, requireSig bool) *VaultService {
	t.Helper()
	return newSignatureVaultT(t, st, chain, userID, requireSig, 10_000_000, time.Millisecond)
}

func newSignatureVaultT(t *testing.T, st store, chain *blockchain.MockBlockchainService, userID string, requireSig bool, threshold int64, delay time.Duration) *VaultService {
	t.Helper()
	return NewVaultService(st, chain, NewMoneyService(st), VaultConfig{
		VaultAddress:                  vaultAddr,
		StablecoinSymbol:              "USDC",
		StablecoinDecimals:            6,
		Mode:                          "real",
		ChainID:                       testChainID,
		FallbackUserID:                userID,
		WithdrawEnabled:               true,
		RequireUserSignature:          requireSig,
		WithdrawElevationThresholdMinor: threshold,
		WithdrawElevationDelay:          delay,
	}, 160450)
}

// seedClone deploys the user's clone and sets its on-chain owner seat.
func seedClone(t *testing.T, v *VaultService, chain *blockchain.MockBlockchainService, userID, owner string) string {
	t.Helper()
	ctx := context.Background()
	clone, err := v.EnsureClone(ctx, userID)
	if err != nil {
		t.Fatalf("ensure clone: %v", err)
	}
	if owner != "" {
		chain.SetCloneOwner(clone.CloneAddress, owner)
	}
	return clone.CloneAddress
}

// signWithdraw signs a WithdrawRequest from `key` and wraps it in the
// client-shaped domain.WithdrawSignature.
func signWithdraw(t *testing.T, chainID int64, clone, to string, amountBase int64, nonce uint64, deadline int64, key *ecdsa.PrivateKey) *domain.WithdrawSignature {
	t.Helper()
	digest := eip712.WithdrawDigest(chainID, common.HexToAddress(clone), eip712.WithdrawRequest{
		To:       common.HexToAddress(to),
		Amount:   big.NewInt(amountBase),
		Nonce:    nonce,
		Deadline: deadline,
	})
	sig, err := eip712.SignDigest(digest, key)
	if err != nil {
		t.Fatalf("sign withdraw: %v", err)
	}
	return &domain.WithdrawSignature{
		Signature:       "0x" + common.Bytes2Hex(sig),
		Deadline:        deadline,
		RelayNonce:      nonce,
		RelayAmountBase: amountBase,
	}
}

// TestWithdrawSigned_UserSignatureRelaysExactIntent: a withdrawal authorized by
// the user's own wallet signature is relayed as an exact withdrawWithSig on
// their clone, and the ledger is debited.
func TestWithdrawSigned_UserSignatureRelaysExactIntent(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-relay@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	ownerKey, err := crypto.GenerateKey()
	if err != nil {
		t.Fatalf("generate owner key: %v", err)
	}
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	destination := "0x1111111111111111111111111111111111111111"
	// Exactly the amount the service converts at the configured rate.
	usdcBase := withdrawUSDCBase(5_000_000, 160450)
	deadline := time.Now().UTC().Add(15 * time.Minute).Unix()
	sig := signWithdraw(t, testChainID, clone, destination, usdcBase, 0, deadline, ownerKey)

	res, err := v.WithdrawToAddressSigned(ctx, u.ID, destination, 5_000_000, sig, "wd-sig-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("signed withdraw: %v", err)
	}
	if res.Transaction == nil {
		t.Fatal("expected an instant transaction")
	}

	relays := chain.Relays()
	if len(relays) != 1 {
		t.Fatalf("relay count = %d, want 1", len(relays))
	}
	r := relays[0]
	if r.Clone != clone || r.To != destination {
		t.Errorf("relay to %s from %s (want %s)", r.To, r.Clone, clone)
	}
	if r.Amount.Int64() != usdcBase {
		t.Errorf("relay amount = %d, want %d", r.Amount.Int64(), usdcBase)
	}
	if r.Nonce != 0 {
		t.Errorf("relay nonce = %d, want 0", r.Nonce)
	}
	if r.Deadline != deadline {
		t.Errorf("relay deadline = %d, want %d", r.Deadline, deadline)
	}
	if bal := availNGN(t, st, u.ID); bal != 45_000_000 {
		t.Errorf("balance = %d, want 45000000", bal)
	}

	// The nonce advanced on-chain after the relay.
	nextNonce, _ := chain.CloneNonce(ctx, clone)
	if nextNonce != 1 {
		t.Errorf("clone nonce after relay = %d, want 1", nextNonce)
	}
}

// TestWithdrawSigned_WrongOwnerRejected: a signature that does not belong to
// the clone owner is rejected before any gas is spent.
func TestWithdrawSigned_WrongOwnerRejected(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-wrong@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-wrong-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	intruder, _ := crypto.GenerateKey()
	usdcBase := withdrawUSDCBase(5_000_000, 160450)
	sig := signWithdraw(t, testChainID, clone, "0x2222222222222222222222222222222222222222", usdcBase, 0, time.Now().Add(time.Hour).Unix(), intruder)

	_, err := v.WithdrawToAddressSigned(ctx, u.ID, "0x2222222222222222222222222222222222222222", 5_000_000, sig, "wd-sig-wrong-"+uniqueKey("k"))
	if !errors.Is(err, domain.ErrInvalidSignature) {
		t.Fatalf("err = %v, want ErrInvalidSignature", err)
	}
	if bal := availNGN(t, st, u.ID); bal != 50_000_000 {
		t.Errorf("balance changed on rejected withdrawal = %d", bal)
	}
	if n := len(chain.Relays()); n != 0 {
		t.Errorf("relays = %d, want 0", n)
	}
}

// TestWithdrawSigned_ExpiredRejected: a signature whose deadline passed is
// rejected without a broadcast.
func TestWithdrawSigned_ExpiredRejected(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-expired@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-exp-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)
	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	usdcBase := withdrawUSDCBase(5_000_000, 160450)
	sig := signWithdraw(t, testChainID, clone, "0x3333333333333333333333333333333333333333", usdcBase, 0, time.Now().UTC().Add(-time.Second).Unix(), ownerKey)

	_, err := v.WithdrawToAddressSigned(ctx, u.ID, "0x3333333333333333333333333333333333333333", 5_000_000, sig, "wd-sig-exp-"+uniqueKey("k"))
	if !errors.Is(err, domain.ErrSignatureExpired) {
		t.Fatalf("err = %v, want ErrSignatureExpired", err)
	}
	if n := len(chain.Relays()); n != 0 {
		t.Errorf("relays = %d, want 0", n)
	}
}

// TestWithdrawSigned_StaleNonceRejected: a signature bound to a nonce that is
// no longer the clone's current nonce is rejected (covered by digest recovery
// failing against the current nonce).
func TestWithdrawSigned_StaleNonceRejected(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-nonce@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-nonce-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)
	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())

	// Signed against nonce 0, but the chain nonce has advanced to 3.
	chain.SetCloneNonce(clone, 3)
	usdcBase := withdrawUSDCBase(5_000_000, 160450)
	sig := signWithdraw(t, testChainID, clone, "0x4444444444444444444444444444444444444444", usdcBase, 0, time.Now().Add(time.Hour).Unix(), ownerKey)

	_, err := v.WithdrawToAddressSigned(ctx, u.ID, "0x4444444444444444444444444444444444444444", 5_000_000, sig, "wd-sig-nonce-"+uniqueKey("k"))
	if !errors.Is(err, domain.ErrInvalidSignature) {
		t.Fatalf("err = %v, want ErrInvalidSignature", err)
	}
	if n := len(chain.Relays()); n != 0 {
		t.Errorf("relays = %d, want 0", n)
	}
}

// TestWithdrawRequireSignature_NoSignatureRefused: with signature-gating
// enforced, a request without a user signature is refused even when the
// platform owns the clone.
func TestWithdrawRequireSignature_NoSignatureRefused(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-strict@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-strict-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)
	seedClone(t, v, chain, u.ID, vaultAddr) // platform still owns the clone

	_, err := v.WithdrawToAddress(ctx, u.ID, "0x5555555555555555555555555555555555555555", 5_000_000, "wd-strict-"+uniqueKey("k"))
	if !errors.Is(err, domain.ErrWithdrawSignatureRequired) {
		t.Fatalf("err = %v, want ErrWithdrawSignatureRequired", err)
	}
	if n := len(chain.Relays()); n != 0 {
		t.Errorf("relays = %d, want 0", n)
	}
}

// TestWithdrawTransitional_PlatformSignsForPlaceholderOwner: while signature
// enforcement is off and the clone is still owned by the platform signer, the
// relay is signed by the platform (transitional) and still goes through
// withdrawWithSig — never the shared-signer transfer.
func TestWithdrawTransitional_PlatformSignsForPlaceholderOwner(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-transition@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-trans-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, false)
	seedClone(t, v, chain, u.ID, vaultAddr)

	res, err := v.WithdrawToAddress(ctx, u.ID, "0x6666666666666666666666666666666666666666", 5_000_000, "wd-trans-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("transitional withdraw: %v", err)
	}
	if res.Transaction == nil {
		t.Fatal("expected an instant transaction")
	}
	relays := chain.Relays()
	if len(relays) != 1 {
		t.Fatalf("relay count = %d, want 1", len(relays))
	}
	if bal := availNGN(t, st, u.ID); bal != 45_000_000 {
		t.Errorf("balance = %d, want 45000000", bal)
	}
}

// TestWithdrawTransitional_UserWalletOwnerNeedsSignature: even in transitional
// mode, a clone owned by a real user wallet cannot be withdrawn without that
// wallet's signature.
func TestWithdrawTransitional_UserWalletOwnerNeedsSignature(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-trans-user@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-tu-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, false)
	want := common.HexToAddress("0x0000000000000000000000000000000000000aBc")
	seedClone(t, v, chain, u.ID, want.Hex())

	_, err := v.WithdrawToAddress(ctx, u.ID, "0x7777777777777777777777777777777777777777", 5_000_000, "wd-tu-"+uniqueKey("k"))
	if !errors.Is(err, domain.ErrWithdrawSignatureRequired) {
		t.Fatalf("err = %v, want ErrWithdrawSignatureRequired", err)
	}
	if n := len(chain.Relays()); n != 0 {
		t.Errorf("relays = %d, want 0", n)
	}
}

// TestPrepareSignedWithdrawal_QuoteMatchesBroadcast: the quote's message is
// exactly what the signer authorizes and exactly what the backend relays, so a
// signature recovered from the quote succeeds.
func TestPrepareSignedWithdrawal_QuoteMatchesBroadcast(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-quote@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-quote-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)
	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())
	chain.SetCloneNonce(clone, 7)

	destination := "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	quote, err := v.PrepareSignedWithdrawal(ctx, u.ID, destination, 5_000_000)
	if err != nil {
		t.Fatalf("prepare quote: %v", err)
	}
	if quote.Domain.VerifyingContract != clone {
		t.Errorf("domain verifyingContract = %s, want clone %s", quote.Domain.VerifyingContract, clone)
	}
	if quote.Domain.ChainID != testChainID {
		t.Errorf("domain chain id = %d, want %d", quote.Domain.ChainID, testChainID)
	}
	if quote.Domain.Name != "GlobmintVault" || quote.Domain.Version != "1" {
		t.Errorf("domain identity = %s/%s", quote.Domain.Name, quote.Domain.Version)
	}
	if !strings.EqualFold(quote.Message.To.Hex(), destination) {
		t.Errorf("message to = %s, want %s", quote.Message.To.Hex(), destination)
	}
	if quote.Message.Nonce != 7 {
		t.Errorf("message nonce = %d, want 7 (current chain nonce)", quote.Message.Nonce)
	}
	if quote.Message.Amount.Int64() != withdrawUSDCBase(5_000_000, 160450) {
		t.Errorf("message amount = %s, want %d", quote.Message.Amount, withdrawUSDCBase(5_000_000, 160450))
	}
	if quote.AmountNgnMinor != 5_000_000 || quote.FeeNgnMinor < 0 {
		t.Errorf("quote context = ngn %d fee %d", quote.AmountNgnMinor, quote.FeeNgnMinor)
	}
	if !strings.EqualFold(quote.Owner, owner.Hex()) {
		t.Errorf("quote owner = %s, want %s", quote.Owner, owner.Hex())
	}

	// The client signs the quoted message verbatim; the backend must relay the
	// exact signed relay through the quote's fields.
	sig := signWithdraw(t, quote.Domain.ChainID, clone, quote.Message.To.Hex(),
		quote.Message.Amount.Int64(), quote.Message.Nonce, quote.Message.Deadline, ownerKey)
	sig.Deadline = quote.Message.Deadline
	sig.RelayNonce = quote.Message.Nonce
	sig.RelayAmountBase = quote.Message.Amount.Int64()

	res, err := v.WithdrawToAddressSigned(ctx, u.ID, destination, 5_000_000, sig, "wd-quote-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("signed withdraw from quote: %v", err)
	}
	if res.Transaction == nil {
		t.Fatal("expected an instant transaction")
	}
	relays := chain.Relays()
	if len(relays) != 1 {
		t.Fatalf("relay count = %d, want 1", len(relays))
	}
	if relays[0].Amount.Int64() != quote.Message.Amount.Int64() || relays[0].Nonce != 7 {
		t.Errorf("relay mismatch: amount=%d nonce=%d", relays[0].Amount.Int64(), relays[0].Nonce)
	}
	deadlineCheck := relays[0].Deadline
	if deadlineCheck < time.Now().Unix() {
		t.Errorf("relay deadline %d is already past", deadlineCheck)
	}
}

// TestPrepareSignedWithdrawal_NoCustodyRefused: without a clone there is
// nothing to relay against, so the quote refuses rather than producing a
// signature the backend would never accept.
func TestPrepareSignedWithdrawal_NoCustodyRefused(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-quote-noc@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-qnoc-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignatureVault(t, st, chain, u.ID, true)

	_, err := v.PrepareSignedWithdrawal(ctx, u.ID, "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", 5_000_000)
	if !errors.Is(err, domain.ErrWithdrawRequiresCustody) {
		t.Fatalf("err = %v, want ErrWithdrawRequiresCustody", err)
	}
}

// TestElevationSigned_RelaysExactIntentAtRelease: a signed elevated withdrawal
// is persisted and, once due, the sweeper relays the EXACT signed intent.
func TestElevationSigned_RelaysExactIntentAtRelease(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-elev@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-elev-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignedElevationVault(t, st, chain, u.ID, true)
	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())
	chain.SetCloneNonce(clone, 1)

	destination := "0x8888888888888888888888888888888888888888"
	amountNgn := int64(20_000_000)
	usdcBase := withdrawUSDCBase(amountNgn, 160450)
	deadline := time.Now().UTC().Add(2 * time.Hour).Unix() // covers the time-lock
	sig := signWithdraw(t, testChainID, clone, destination, usdcBase, 1, deadline, ownerKey)

	res, err := v.WithdrawToAddressSigned(ctx, u.ID, destination, int64(amountNgn), sig, "wd-sig-elev-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("signed elevated withdraw: %v", err)
	}
	if res.Elevation == nil {
		t.Fatal("expected a pending elevation")
	}
	got, err := v.FindElevation(ctx, u.ID, res.Elevation.ID)
	if err != nil {
		t.Fatalf("find elevation: %v", err)
	}
	if !got.HasSignedIntent() {
		t.Fatal("elevation should persist the signed intent")
	}
	if got.SignedNonce != 1 || got.SignedAmountBase != usdcBase || got.Deadline != deadline {
		t.Errorf("signed intent mismatch: nonce=%d base=%d deadline=%d",
			got.SignedNonce, got.SignedAmountBase, got.Deadline)
	}

	// The near-zero delay elapses quickly: sweep and expect the exact relay.
	time.Sleep(10 * time.Millisecond)
	if err := v.sweepDueElevations(ctx); err != nil {
		t.Fatalf("sweep: %v", err)
	}

	relays := chain.Relays()
	if len(relays) != 1 {
		t.Fatalf("relay count = %d, want 1", len(relays))
	}
	r := relays[0]
	if r.To != destination || r.Amount.Int64() != usdcBase || r.Nonce != 1 || r.Deadline != deadline {
		t.Errorf("relayed relay mismatch: to=%s amount=%d nonce=%d deadline=%d",
			r.To, r.Amount.Int64(), r.Nonce, r.Deadline)
	}

	final, _ := st.ElevationRepo().FindByUserAndID(ctx, u.ID, got.ID)
	if final.Status != domain.ElevationBroadcast {
		t.Errorf("status = %s, want broadcast", final.Status)
	}
	if bal := availNGN(t, st, u.ID); bal != 30_000_000 {
		t.Errorf("balance = %d, want 30000000 after sweep", bal)
	}
}

// TestElevationSigned_NonceAdvancedExpires: an intent signed against a nonce
// that is consumed before release cannot be relayed; the elevation is marked
// expired (terminal) and is never retried.
func TestElevationSigned_NonceAdvancedExpires(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "vault-sig-elev-stale@example.com")
	fundNGN(t, st, u.ID, 50_000_000, "fund-sig-estale-"+uniqueKey("k"))

	chain := blockchain.NewMockBlockchainService()
	v := newSignedElevationVault(t, st, chain, u.ID, true)
	ownerKey, _ := crypto.GenerateKey()
	owner := crypto.PubkeyToAddress(ownerKey.PublicKey)
	clone := seedClone(t, v, chain, u.ID, owner.Hex())
	chain.SetCloneNonce(clone, 2)

	destination := "0x9999999999999999999999999999999999999999"
	usdcBase := withdrawUSDCBase(int64(20_000_000), 160450)
	sig := signWithdraw(t, testChainID, clone, destination, usdcBase, 2, time.Now().Add(2*time.Hour).Unix(), ownerKey)

	res, err := v.WithdrawToAddressSigned(ctx, u.ID, destination, 20_000_000, sig, "wd-sig-estale-"+uniqueKey("k"))
	if err != nil {
		t.Fatalf("signed elevated withdraw: %v", err)
	}

	// Another withdrawal consumes the signed nonce before release.
	chain.SetCloneNonce(clone, 3)

	time.Sleep(10 * time.Millisecond)
	if err := v.sweepDueElevations(ctx); err != nil {
		t.Fatalf("sweep: %v", err)
	}

	got, _ := st.ElevationRepo().FindByUserAndID(ctx, u.ID, res.Elevation.ID)
	if got.Status != domain.ElevationExpired {
		t.Errorf("status = %s, want expired", got.Status)
	}
	if got.ExpiredReason == "" {
		t.Error("expected an expired reason")
	}
	if n := len(chain.Relays()); n != 0 {
		t.Errorf("relays = %d, want 0 (nothing broadcast)", n)
	}
	// Nothing was debited.
	if bal := availNGN(t, st, u.ID); bal != 50_000_000 {
		t.Errorf("balance = %d, want 50000000", bal)
	}
}