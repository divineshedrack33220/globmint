package main

import (
	"context"
	"fmt"
	"math/big"
	"os"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
)

func main() {
	if len(os.Args) != 6 {
		fmt.Fprintln(os.Stderr, "usage: usdcsend <rpcUrl> <privKeyHex> <usdcContract> <to> <amountMajor>")
		os.Exit(1)
	}
	rpcURL := os.Args[1]
	privHex := os.Args[2]
	usdc := common.HexToAddress(os.Args[3])
	to := common.HexToAddress(os.Args[4])
	amountMajor := os.Args[5]

	key, err := crypto.HexToECDSA(strings.TrimPrefix(strings.TrimSpace(privHex), "0x"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "parse key:", err)
		os.Exit(1)
	}
	from := crypto.PubkeyToAddress(key.PublicKey)

	ctx := context.Background()
	rc, err := rpc.DialContext(ctx, rpcURL)
	if err != nil {
		fmt.Fprintln(os.Stderr, "dial:", err)
		os.Exit(1)
	}
	client := ethclient.NewClient(rc)

	// Parse amountMajor as a decimal string into 6-decimals base units (avoid float).
	ai := strings.SplitN(amountMajor, ".", 2)
	base := new(big.Int)
	base.SetString(ai[0], 10)
	base.Mul(base, big.NewInt(1_000_000))
	if len(ai) == 2 {
		frac := ai[1]
		if len(frac) > 6 {
			frac = frac[:6]
		}
		for len(frac) < 6 {
			frac += "0"
		}
		f := new(big.Int)
		f.SetString(frac, 10)
		base.Add(base, f)
	}

	// transfer(address,uint256) selector
	transferSig := crypto.Keccak256([]byte("transfer(address,uint256)"))[:4]
	data := append([]byte{}, transferSig...)
	data = append(data, common.LeftPadBytes(to.Bytes(), 32)...)
	data = append(data, common.LeftPadBytes(base.Bytes(), 32)...)

	nonce, err := client.PendingNonceAt(ctx, from)
	if err != nil {
		fmt.Fprintln(os.Stderr, "nonce:", err)
		os.Exit(1)
	}
	gasPrice, err := client.SuggestGasPrice(ctx)
	if err != nil {
		fmt.Fprintln(os.Stderr, "gas price:", err)
		os.Exit(1)
	}
	gasLimit, err := client.EstimateGas(ctx, ethereum.CallMsg{From: from, To: &usdc, Data: data})
	if err != nil {
		fmt.Fprintln(os.Stderr, "estimate gas:", err)
		os.Exit(1)
	}
	tx := types.NewTransaction(nonce, usdc, big.NewInt(0), gasLimit, gasPrice, data)
	signed, err := types.SignTx(tx, types.LatestSignerForChainID(big.NewInt(11155111)), key)
	if err != nil {
		fmt.Fprintln(os.Stderr, "sign:", err)
		os.Exit(1)
	}
	if err := client.SendTransaction(ctx, signed); err != nil {
		fmt.Fprintln(os.Stderr, "send:", err)
		os.Exit(1)
	}
	fmt.Println("tx_hash:", signed.Hash().Hex())
	fmt.Println("from:", from.Hex())
	fmt.Println("to(vault):", to.Hex())
	fmt.Println("amountBase:", base.String())

	// Wait for confirmation
	for i := 0; i < 40; i++ {
		time.Sleep(2 * time.Second)
		_, err := client.TransactionReceipt(ctx, signed.Hash())
		if err == nil {
			fmt.Println("confirmed: yes")
			return
		}
	}
	fmt.Println("confirmed: timeout (check explorer)")
}
