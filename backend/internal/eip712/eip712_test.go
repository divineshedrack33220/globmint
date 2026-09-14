package eip712

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

func TestSignRecoverRoundTrip(t *testing.T) {
	key, err := crypto.GenerateKey()
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	chainID := int64(31337)
	clone := common.HexToAddress("0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F")
	req := WithdrawRequest{
		To:       common.HexToAddress("0x1111111111111111111111111111111111111111"),
		Amount:   big.NewInt(100_000_000),
		Nonce:    3,
		Deadline: 1_700_000_000,
	}
	digest := WithdrawDigest(chainID, clone, req)

	sig, err := SignDigest(digest, key)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if len(sig) != 65 {
		t.Fatalf("signature length = %d, want 65", len(sig))
	}
	if sig[64] != 27 && sig[64] != 28 {
		t.Fatalf("signature v = %d, want 27 or 28", sig[64])
	}

	got, err := RecoverSigner(digest, sig)
	if err != nil {
		t.Fatalf("recover: %v", err)
	}
	want := crypto.PubkeyToAddress(key.PublicKey)
	if got != want {
		t.Fatalf("recovered %s, want %s", got.Hex(), want.Hex())
	}

	// The digest must change with every field: recovery must fail if any part
	// of the request (or the domain) is altered.
	mutations := []WithdrawRequest{
		{To: common.HexToAddress("0x2222222222222222222222222222222222222222"), Amount: req.Amount, Nonce: req.Nonce, Deadline: req.Deadline},
		{To: req.To, Amount: new(big.Int).Add(req.Amount, big.NewInt(1)), Nonce: req.Nonce, Deadline: req.Deadline},
		{To: req.To, Amount: req.Amount, Nonce: req.Nonce + 1, Deadline: req.Deadline},
		{To: req.To, Amount: req.Amount, Nonce: req.Nonce, Deadline: req.Deadline + 1},
	}
	for i, m := range mutations {
		other := WithdrawDigest(chainID, clone, m)
		if other == digest {
			t.Fatalf("mutation %d produced the same digest", i)
		}
		addr, err := RecoverSigner(other, sig)
		if err == nil && addr == want {
			t.Fatalf("mutation %d still recovered original signer", i)
		}
	}
}

func TestDomainSeparatorBindsChainAndContract(t *testing.T) {
	clone := common.HexToAddress("0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F")
	sepA := DomainSeparator(31337, clone)
	sepB := DomainSeparator(31338, clone)
	sepC := DomainSeparator(31337, common.HexToAddress("0x0000000000000000000000000000000000000001"))
	if sepA == sepB {
		t.Fatal("domain separator must depend on the chain id")
	}
	if sepA == sepC {
		t.Fatal("domain separator must depend on the verifying contract")
	}
}

func TestParseSignatureNormalizesV(t *testing.T) {
	key, err := crypto.GenerateKey()
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	digest := WithdrawDigest(31337,
		common.HexToAddress("0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F"),
		WithdrawRequest{
			To:       common.HexToAddress("0x1111111111111111111111111111111111111111"),
			Amount:   big.NewInt(5_000_000),
			Nonce:    0,
			Deadline: 1_800_000_000,
		})

	// crypto.Sign returns v in {0,1}; ParseSignature must normalize to 27/28.
	sig, err := crypto.Sign(digest.Bytes(), key)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if sig[64] != 0 && sig[64] != 1 {
		t.Fatalf("expected raw v in {0,1}, got %d", sig[64])
	}
	v, r, s, err := ParseSignature("0x" + common.Bytes2Hex(sig))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if v != sig[64]+27 {
		t.Fatalf("v = %d, want %d", v, sig[64]+27)
	}
	if r != common.BytesToHash(sig[:32]) || s != common.BytesToHash(sig[32:64]) {
		t.Fatal("r/s round-trip mismatch")
	}

	// Signing via the package (already normalized) must also parse back.
	norm, err := SignDigest(digest, key)
	if err != nil {
		t.Fatalf("sign normalized: %v", err)
	}
	v2, _, _, err := ParseSignature(common.Bytes2Hex(norm))
	if err != nil {
		t.Fatalf("parse normalized: %v", err)
	}
	if v2 != norm[64] {
		t.Fatalf("v = %d, want %d", v2, norm[64])
	}
}

func TestParseSignatureRejectsBadInput(t *testing.T) {
	if _, _, _, err := ParseSignature("0xabcd"); err == nil {
		t.Fatal("expected error for odd-length hex")
	}
	if _, _, _, err := ParseSignature("0x" + common.Bytes2Hex(make([]byte, 64))); err == nil {
		t.Fatal("expected error for 64-byte signature")
	}
}

func TestSetRecoveryRoundTrip(t *testing.T) {
	key, err := crypto.GenerateKey()
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	chainID := int64(31337)
	clone := common.HexToAddress("0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F")
	recovery := common.HexToAddress("0x2222222222222222222222222222222222222222")
	req := SetRecoveryRequest{
		RecoveryAddress: recovery,
		Nonce:           0,
		Deadline:        1_700_000_000,
	}
	digest := SetRecoveryDigest(chainID, clone, req)

	sig, err := SignDigest(digest, key)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	got, err := RecoverSigner(digest, sig)
	if err != nil {
		t.Fatalf("recover: %v", err)
	}
	want := crypto.PubkeyToAddress(key.PublicKey)
	if got != want {
		t.Fatalf("recovered %s, want %s", got.Hex(), want.Hex())
	}

	// Every field must participate: mutating recovery/nonce/deadline, the
	// chain id, or the verifying contract must invalidate the signature.
	mutations := []SetRecoveryRequest{
		{RecoveryAddress: common.HexToAddress("0x3333333333333333333333333333333333333333"), Nonce: req.Nonce, Deadline: req.Deadline},
		{RecoveryAddress: req.RecoveryAddress, Nonce: req.Nonce + 1, Deadline: req.Deadline},
		{RecoveryAddress: req.RecoveryAddress, Nonce: req.Nonce, Deadline: req.Deadline + 1},
	}
	for i, m := range mutations {
		other := SetRecoveryDigest(chainID, clone, m)
		if other == digest {
			t.Fatalf("mutation %d produced the same digest", i)
		}
		if addr, err := RecoverSigner(other, sig); err == nil && addr == want {
			t.Fatalf("mutation %d still recovered original signer", i)
		}
	}
	if other := SetRecoveryDigest(chainID+1, clone, req); inRecoverSet(other, sig, want) {
		t.Fatal("a different chain id still recovered the signer")
	}
	if other := SetRecoveryDigest(chainID, common.HexToAddress("0x3333333333333333333333333333333333333333"), req); inRecoverSet(other, sig, want) {
		t.Fatal("a different verifying contract still recovered the signer")
	}
	// A withdrawal exported the same fields must NOT be the same digest as a
	// recovery request (cross-type replay guard).
	mixed := SetRecoveryDigest(chainID, clone, req)
	withdraw := WithdrawDigest(chainID, clone, WithdrawRequest{To: recovery, Amount: big.NewInt(0), Nonce: req.Nonce, Deadline: req.Deadline})
	if mixed == withdraw {
		t.Fatal("recovery and withdrawal digests must differ")
	}
}

// inRecoverSet returns whether the given signature over `other` recovers to
// `want` (i.e. the signature is still valid for a mutated request).
func inRecoverSet(other common.Hash, sig []byte, want common.Address) bool {
	addr, err := RecoverSigner(other, sig)
	return err == nil && addr == want
}

func TestTransferOwnershipRoundTrip(t *testing.T) {
	key, err := crypto.GenerateKey()
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	chainID := int64(31337)
	clone := common.HexToAddress("0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F")
	newOwner := common.HexToAddress("0x4444444444444444444444444444444444444444")
	req := TransferOwnershipRequest{
		NewOwner: newOwner,
		Nonce:    0,
		Deadline: 1_700_000_000,
	}
	digest := TransferOwnershipDigest(chainID, clone, req)

	sig, err := SignDigest(digest, key)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	got, err := RecoverSigner(digest, sig)
	if err != nil {
		t.Fatalf("recover: %v", err)
	}
	want := crypto.PubkeyToAddress(key.PublicKey)
	if got != want {
		t.Fatalf("recovered %s, want %s", got.Hex(), want.Hex())
	}

	// Every field must participate: mutating newOwner/nonce/deadline, the
	// chain id, or the verifying contract must invalidate the signature.
	mutations := []TransferOwnershipRequest{
		{NewOwner: common.HexToAddress("0x5555555555555555555555555555555555555555"), Nonce: req.Nonce, Deadline: req.Deadline},
		{NewOwner: req.NewOwner, Nonce: req.Nonce + 1, Deadline: req.Deadline},
		{NewOwner: req.NewOwner, Nonce: req.Nonce, Deadline: req.Deadline + 1},
	}
	for i, m := range mutations {
		other := TransferOwnershipDigest(chainID, clone, m)
		if other == digest {
			t.Fatalf("mutation %d produced the same digest", i)
		}
		if addr, err := RecoverSigner(other, sig); err == nil && addr == want {
			t.Fatalf("mutation %d still recovered original signer", i)
		}
	}
	if other := TransferOwnershipDigest(chainID+1, clone, req); inRecoverSet(other, sig, want) {
		t.Fatal("a different chain id still recovered the signer")
	}
	if other := TransferOwnershipDigest(chainID, common.HexToAddress("0x5555555555555555555555555555555555555555"), req); inRecoverSet(other, sig, want) {
		t.Fatal("a different verifying contract still recovered the signer")
	}
	// Cross-intent replay guard: the shared nonce must never let a transfer
	// signature be replayed as a recovery (or withdrawal) of the same address
	// and nonce — the typehash prefixes each intent.
	recovery := SetRecoveryDigest(chainID, clone, SetRecoveryRequest{RecoveryAddress: newOwner, Nonce: req.Nonce, Deadline: req.Deadline})
	if recovery == digest {
		t.Fatal("transfer and recovery digests must differ")
	}
	withdraw := WithdrawDigest(chainID, clone, WithdrawRequest{To: newOwner, Amount: big.NewInt(0), Nonce: req.Nonce, Deadline: req.Deadline})
	if withdraw == digest {
		t.Fatal("transfer and withdrawal digests must differ")
	}
}