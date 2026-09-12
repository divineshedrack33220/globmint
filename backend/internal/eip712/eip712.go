// Package eip712 builds and verifies the EIP-712 typed-data digests the
// GlobmintVault clone contracts sign. Both the blockchain relay service (which
// signs on behalf of the platform signer in the transitional placeholder-owner
// path) and the vault service (which verifies user signatures on withdrawal)
// share this one implementation so the two sides can never disagree on the
// encoding of a withdrawal request.
//
// Encoding must byte-for-byte match GlobmintVaultClone.sol:
//
//	domainSeparator = keccak256(abi.encode(
//	    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
//	    keccak256(bytes("GlobmintVault")),
//	    keccak256(bytes("1")),
//	    chainId,
//	    verifyingContract))          // verifyingContract = the per-user clone
//
//	structHash      = keccak256(abi.encode(
//	    keccak256("WithdrawRequest(address to,uint256 amount,uint256 nonce,uint256 deadline)"),
//	    to, amount, nonce, deadline))
//
//	digest          = keccak256("\x19\x01" || domainSeparator || structHash)
package eip712

import (
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

const (
	// DomainName / DomainVersion must match the values hardcoded in
	// GlobmintVaultClone.sol's domainSeparator().
	DomainName    = "GlobmintVault"
	DomainVersion = "1"

	withdrawTypeString = "WithdrawRequest(address to,uint256 amount,uint256 nonce,uint256 deadline)"
	domainTypeString   = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
)

var (
	withdrawTypeHash = crypto.Keccak256Hash([]byte(withdrawTypeString))
	domainTypeHash   = crypto.Keccak256Hash([]byte(domainTypeString))
	nameHash         = crypto.Keccak256Hash([]byte(DomainName))
	versionHash      = crypto.Keccak256Hash([]byte(DomainVersion))
)

// WithdrawRequest is the typed struct a withdrawal signature authorizes.
// It mirrors WithdrawRequest(address to,uint256 amount,uint256 nonce,uint256
// deadline) in the contract. Amount is the stablecoin base-unit amount (e.g.
// micro-USDC) that will actually leave the clone.
type WithdrawRequest struct {
	To       common.Address
	Amount   *big.Int
	Nonce    uint64
	Deadline int64 // unix seconds; the signature expires after this
}

// DomainSeparator returns the EIP-712 domain separator bound to this chain id
// and verifying contract (the per-user clone) — exactly the contract's
// domainSeparator() view.
func DomainSeparator(chainID int64, verifyingContract common.Address) common.Hash {
	return crypto.Keccak256Hash(
		domainTypeHash.Bytes(),
		abiWord(nameHash.Bytes()),
		abiWord(versionHash.Bytes()),
		abiUint256(big.NewInt(chainID)),
		abiAddress(verifyingContract),
	)
}

// WithdrawDigest returns the fully prefixed EIP-712 digest of a withdrawal
// request bound to verifyingContract. Sign (user wallet or platform signer)
// and RecoverSigner must both use this exact digest.
func WithdrawDigest(chainID int64, verifyingContract common.Address, req WithdrawRequest) common.Hash {
	structHash := crypto.Keccak256Hash(
		withdrawTypeHash.Bytes(),
		abiAddress(req.To),
		abiUint256(req.Amount),
		abiUint256(new(big.Int).SetUint64(req.Nonce)),
		abiUint256(big.NewInt(req.Deadline)),
	)
	return crypto.Keccak256Hash(
		[]byte{0x19, 0x01},
		DomainSeparator(chainID, verifyingContract).Bytes(),
		structHash.Bytes(),
	)
}

// SignDigest signs a digest with `key`, returning the 65-byte
// r||s||v signature with v normalized to 27/28 (the form EIP-191 wallets and
// the clone contract both expect).
func SignDigest(digest common.Hash, key *ecdsa.PrivateKey) ([]byte, error) {
	sig, err := crypto.Sign(digest.Bytes(), key)
	if err != nil {
		return nil, fmt.Errorf("eip712 sign: %w", err)
	}
	if sig[64] == 0 || sig[64] == 1 {
		sig[64] += 27
	}
	return sig, nil
}

// RecoverSigner recovers the address that produced a 65-byte signature over a
// digest. Accepts either v=27/28 or the 0/1 form (go-ethereum's recovery
// expects the secp256k1 0/1 id, so 27/28 is normalized down).
func RecoverSigner(digest common.Hash, sig []byte) (common.Address, error) {
	if len(sig) != 65 {
		return common.Address{}, fmt.Errorf("eip712: expected 65-byte signature, got %d", len(sig))
	}
	normalized := make([]byte, 65)
	copy(normalized, sig)
	if normalized[64] == 27 || normalized[64] == 28 {
		normalized[64] -= 27
	}
	recovered, err := crypto.SigToPub(digest.Bytes(), normalized)
	if err != nil {
		return common.Address{}, fmt.Errorf("eip712 recover: %w", err)
	}
	return crypto.PubkeyToAddress(*recovered), nil
}

// ParseSignature decodes a 0x-prefixed (or bare) 65-byte hex signature string
// into its (v, r, s) components, normalizing v from 0/1 to 27/28 so the relay
// payload matches what the contract's ecrecover expects.
func ParseSignature(hexSig string) (v uint8, r, s [32]byte, err error) {
	raw, err := DecodeSignature(hexSig)
	if err != nil {
		return 0, [32]byte{}, [32]byte{}, err
	}
	if len(raw) != 65 {
		return 0, [32]byte{}, [32]byte{}, fmt.Errorf("eip712: signature must be 65 bytes, got %d", len(raw))
	}
	copy(r[:], raw[0:32])
	copy(s[:], raw[32:64])
	v = raw[64]
	if v == 0 || v == 1 {
		v += 27
	}
	if v != 27 && v != 28 {
		return 0, [32]byte{}, [32]byte{}, fmt.Errorf("eip712: invalid v recovery id %d", v)
	}
	return v, r, s, nil
}

// DecodeSignature decodes a 0x-prefixed (or bare) hex signature string into
// its raw 65 bytes (r||s||v). Invalid or non-65-byte values are rejected.
func DecodeSignature(hexSig string) ([]byte, error) {
	raw, err := decodeHex(hexSig)
	if err != nil {
		return nil, err
	}
	if len(raw) != 65 {
		return nil, fmt.Errorf("eip712: expected 65-byte signature, got %d", len(raw))
	}
	return raw, nil
}

// decodeHex strips an optional 0x prefix and decodes an even-length hex string.
func decodeHex(s string) ([]byte, error) {
	clean := strings.TrimPrefix(strings.TrimSpace(s), "0x")
	if len(clean)%2 != 0 {
		return nil, fmt.Errorf("eip712: odd-length hex string")
	}
	return common.FromHex(clean), nil
}

// pack helpers mirror Solidity's abi.encode for static types (each 32 bytes).

// abiWord right-aligns a 32-byte word copy (for precomputed hashes).
func abiWord(b []byte) []byte {
	out := make([]byte, 32)
	copy(out, b)
	return out
}

// abiUint256 left-pads a big.Int into a 32-byte big-endian word.
func abiUint256(n *big.Int) []byte {
	out := make([]byte, 32)
	n.FillBytes(out)
	return out
}

// abiAddress right-aligns a 20-byte address into a 32-byte word.
func abiAddress(a common.Address) []byte {
	out := make([]byte, 32)
	copy(out[12:], a.Bytes())
	return out
}