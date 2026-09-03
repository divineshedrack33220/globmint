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

	privateKey := os.Getenv("GLOBMINT_STABLECOIN_PRIVATE_KEY")

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
		PrivateKeyHex:       privateKey,
	})
	if err != nil {
		fmt.Println("connect:", err)
		os.Exit(1)
	}
	defer closeFn()

	// Transfer mode: TRANSFER_TO and TRANSFER_AMOUNT env vars trigger a live USDC send.
	if to := os.Getenv("TRANSFER_TO"); to != "" {
		if privateKey == "" {
			fmt.Println("set GLOBMINT_STABLECOIN_PRIVATE_KEY to sign a transfer")
			os.Exit(1)
		}
		amount := os.Getenv("TRANSFER_AMOUNT")
		if amount == "" {
			amount = "0.01"
		}
		sendCtx, sendCancel := context.WithTimeout(ctx, 60*time.Second)
		defer sendCancel()
		hash, err := svc.TransferToken(sendCtx, to, amount)
		if err != nil {
			fmt.Println("TransferToken error:", err)
			os.Exit(1)
		}
		fmt.Println("USDC transfer sent. tx hash:", hash)
		fmt.Println("Waiting for confirmation...")
		res, err := svc.WaitForConfirmation(sendCtx, hash, 1)
		if err != nil {
			fmt.Println("WaitForConfirmation error:", err)
			os.Exit(1)
		}
		fmt.Println("Confirmation:", res)
		return
	}

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

	fmt.Println("\nTo test a real USDC transfer:")
	fmt.Println("  export GLOBMINT_STABLECOIN_PRIVATE_KEY=<your testnet key>")
	fmt.Println("  export TRANSFER_TO=<recipient address> TRANSFER_AMOUNT=<amount>")
	fmt.Println("  go run ./cmd/verifychain")
}
