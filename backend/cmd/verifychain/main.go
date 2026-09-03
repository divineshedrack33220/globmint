package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"globmint/backend/internal/infrastructure/blockchain"
)

func main() {
	rpcURL := os.Getenv("GLOBMINT_BLOCKCHAIN_RPC_URL")
	if rpcURL == "" {
		fmt.Println("set GLOBMINT_BLOCKCHAIN_RPC_URL (Alchemy Sepolia endpoint)")
		os.Exit(1)
	}

	address := os.Getenv("ADDRESS")
	if address == "" {
		// Default to a well-known Sepolia address (Circle USDC contract).
		address = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	svc, closeFn, err := blockchain.NewFromConfig(ctx, "real", blockchain.EthereumConfig{
		RPCURL:              rpcURL,
		ChainID:             11155111,
		StablecoinSymbol:    "USDC",
		StablecoinDecimals:  6,
		StablecoinContract:  "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
	})
	if err != nil {
		fmt.Println("connect:", err)
		os.Exit(1)
	}
	defer closeFn()

	fmt.Println("=== Globmint Sepolia verification ===")
	fmt.Println()
	fmt.Println("address:", address)

	balance, err := svc.GetBalance(ctx, address)
	if err != nil {
		fmt.Println("GetBalance error:", err)
	} else {
		fmt.Println("GetBalance (ETH):", balance)
	}

	tokenBalance, err := svc.GetTokenBalance(ctx, address)
	if err != nil {
		fmt.Println("GetTokenBalance error:", err)
	} else {
		fmt.Println("GetTokenBalance (USDC):", tokenBalance)
	}

	// Get a recent block's first transaction to test GetTransaction.
	tx, err := svc.GetTransaction(ctx, "0x0000000000000000000000000000000000000000000000000000000000000000")
	if err != nil {
		fmt.Println("GetTransaction (null hash) error (expected):", err)
	} else {
		fmt.Println("GetTransaction:", tx)
	}

	fmt.Println("\nDone. Mock stays default; use GLOBMINT_BLOCKCHAIN_MODE=real for live traffic.")
}
