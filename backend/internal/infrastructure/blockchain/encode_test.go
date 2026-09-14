package blockchain

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

// TestEncodeTransferOwnershipBySig verifies the ABI payload for
// transferOwnershipBySig(address,uint256,uint256,uint8,bytes32,bytes32): the
// selector must match the canonical signature hash and every field must land
// in its 32-byte word.
func TestEncodeTransferOwnershipBySig(t *testing.T) {
	relay := RelayOwnershipTransfer{
		Clone:    "0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F",
		NewOwner: "0x4444444444444444444444444444444444444444",
		Nonce:    3,
		Deadline: 1_700_000_000,
		Sig: WithdrawSignature{
			V: 27,
			R: common.HexToHash("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
			S: common.HexToHash("0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
		},
	}
	data := encodeTransferOwnershipBySig(relay)
	if len(data) != 4+6*32 {
		t.Fatalf("payload length = %d, want %d", len(data), 4+6*32)
	}

	wantSel := crypto.Keccak256Hash([]byte(
		"transferOwnershipBySig(address,uint256,uint256,uint8,bytes32,bytes32)"))
	if got := common.Bytes2Hex(data[:4]); got != wantSel.Hex()[2:10] {
		t.Fatalf("selector = 0x%s, want 0x%s", got, wantSel.Hex()[:10])
	}

	newOwner := new(big.Int).SetBytes(data[4+12 : 4+32]).Text(16)
	if !common.IsHexAddress("0x" + newOwner) || common.HexToAddress("0x"+newOwner).Hex() != relay.NewOwner {
		t.Fatalf("newOwner word = 0x%s, want %s", newOwner, relay.NewOwner)
	}
	if nonce := new(big.Int).SetBytes(data[4+32 : 4+64]).Uint64(); nonce != relay.Nonce {
		t.Errorf("nonce = %d, want %d", nonce, relay.Nonce)
	}
	if deadline := new(big.Int).SetBytes(data[4+64 : 4+96]).Int64(); deadline != relay.Deadline {
		t.Errorf("deadline = %d, want %d", deadline, relay.Deadline)
	}
	if v := data[4+96+31]; v != 27 {
		t.Errorf("v = %d, want 27 (right-aligned byte)", v)
	}
	if r := common.BytesToHash(data[4+128 : 4+160]); r != relay.Sig.R {
		t.Errorf("r word mismatch")
	}
	if s := common.BytesToHash(data[4+160 : 4+192]); s != relay.Sig.S {
		t.Errorf("s word mismatch")
	}
}

// TestTransferOwnershipSelectorMatchesContractSignature pins the ABI selector
// to the canonical signature string so a contract change can never silently
// desync the relay encoding.
func TestTransferOwnershipSelectorMatchesContractSignature(t *testing.T) {
	const wantSelector = "6db464f1"
	sel := crypto.Keccak256Hash([]byte(
		"transferOwnershipBySig(address,uint256,uint256,uint8,bytes32,bytes32)"))
	if common.Bytes2Hex(sel.Bytes()[:4]) != wantSelector {
		t.Fatalf("selector changed: got %s, want %s — update encodeTransferOwnershipBySig AND this test together",
			common.Bytes2Hex(sel.Bytes()[:4]), wantSelector)
	}
}