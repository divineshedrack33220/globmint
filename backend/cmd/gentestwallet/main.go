package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"
)

func main() {
	verifyMode := flag.Bool("verify", false, "verify the .env private key matches the wallet key file")
	walletFile := flag.String("wallet", "", "path to the wallet key file (default: backend/.wallets/sepolia-testnet.key)")
	envFile := flag.String("env", "", "path to the .env file (default: project root .env)")
	flag.Parse()

	if *verifyMode {
		verify(walletFile, envFile)
		return
	}
	generate(walletFile)
}

func generate(walletFile *string) {
	key, err := crypto.GenerateKey()
	if err != nil {
		fmt.Fprintln(os.Stderr, "generate key:", err)
		os.Exit(1)
	}
	address := crypto.PubkeyToAddress(key.PublicKey)
	privHex := hexutil.Encode(crypto.FromECDSA(key))

	out := *walletFile
	if out == "" {
		cwd, _ := os.Getwd()
		out = filepath.Join(cwd, "..", ".wallets", "sepolia-testnet.key")
	}
	if err := writeKeyFile(out, privHex); err != nil {
		fmt.Fprintln(os.Stderr, "write key file:", err)
		os.Exit(1)
	}

	fmt.Println("Fresh Sepolia testnet wallet generated.")
	fmt.Println("Public address:", address.Hex())
	fmt.Println()
	fmt.Println("Private key saved to (gitignored):", out)
	fmt.Println()
	fmt.Println("Fund this address with 1) Sepolia ETH (for gas)  2) Sepolia USDC")
	fmt.Println("via the faucets, then set GLOBMINT_STABLECOIN_PRIVATE_KEY")
	fmt.Println("in your local .env to the key in that file.")
	fmt.Println()
	fmt.Println("SECURITY: Do NOT paste the private key into chat, email, or git.")
}

func verify(walletFile, envFile *string) {
	keyFile := *walletFile
	if keyFile == "" {
		cwd, _ := os.Getwd()
		keyFile = filepath.Join(cwd, "..", ".wallets", "sepolia-testnet.key")
	}
	envPath := *envFile
	if envPath == "" {
		cwd, _ := os.Getwd()
		envPath = filepath.Join(cwd, "..", ".env")
	}

	keyHex, err := os.ReadFile(keyFile)
	if err != nil {
		fmt.Println("read wallet file:", err)
		os.Exit(1)
	}
	key, err := crypto.HexToECDSA(strings.TrimPrefix(strings.TrimSpace(string(keyHex)), "0x"))
	if err != nil {
		fmt.Println("parse wallet key:", err)
		os.Exit(1)
	}
	walletAddr := crypto.PubkeyToAddress(key.PublicKey)

	envKey := readEnvVar(envPath, "GLOBMINT_STABLECOIN_PRIVATE_KEY")
	if envKey == "" {
		fmt.Println(".env private key not set")
		os.Exit(1)
	}
	envKeyDerived, err := crypto.HexToECDSA(strings.TrimPrefix(strings.TrimSpace(envKey), "0x"))
	if err != nil {
		fmt.Println("parse .env key:", err)
		os.Exit(1)
	}
	envAddr := crypto.PubkeyToAddress(envKeyDerived.PublicKey)

	fmt.Println("wallet file address:", walletAddr.Hex())
	fmt.Println(".env key address:   ", envAddr.Hex())
	fmt.Println("match (key not printed):", walletAddr == envAddr)
}

func readEnvVar(path, key string) string {
	dat, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	for _, l := range strings.Split(string(dat), "\n") {
		if strings.HasPrefix(l, key+"=") {
			return strings.TrimPrefix(l, key+"=")
		}
	}
	return ""
}

func writeKeyFile(path, content string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content+"\n"), 0o600)
}
