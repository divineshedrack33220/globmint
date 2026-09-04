package config

import (
	"os"
	"strconv"
	"time"
)

// Config holds all runtime configuration, sourced from the environment.
// Secrets are read from env vars and never logged.
type Config struct {
	HTTPAddr      string
	DatabaseURL   string
	SessionSecret string // base64-encoded secret for signing/encrypting session tokens
	SessionTTL    time.Duration
	TokenIssuer   string
	LogLevel      string
	RequestIDSalt string

	// Blockchain holds settings for the on-chain settlement layer.
	Blockchain BlockchainConfig
}

// BlockchainConfig holds blockchain and stablecoin settings.
type BlockchainConfig struct {
	Network         string // "mock", "sepolia", "mainnet"
	RPCURL          string // e.g. Alchemy/Infura endpoint
	ChainID         int64
	Stablecoin      string // e.g. "USDC"
	StablecoinName  string
	StablecoinDecimals int
	StablecoinEnabled bool
	StablecoinContract string
	// VaultContract is the deployed GlobmintVault address. The vault is the
	// non-custodial on-chain contract that tracks each user's balance. It is
	// referenced by the savings/deposit-info endpoint so clients can build the
	// approve + deposit calls. Empty when the vault is not yet deployed.
	VaultContract string
	// VaultAddress is the custodial deposit address (the backend signer) that
	// users send USD deposits to. Empty in mock mode.
	VaultAddress string
	Mode          string // "mock" or "real"
	// PrivateKeyHex is the signer private key for on-chain transfers. It is
	// read from the environment and must never be logged or committed.
	PrivateKeyHex string
}

// Load reads configuration from the environment, applying defaults.
func Load() Config {
	return Config{
		HTTPAddr:      envOr("GLOBMINT_HTTP_ADDR", ":8081"),
		DatabaseURL:   os.Getenv("GLOBMINT_DATABASE_URL"),
		SessionSecret: envOr("GLOBMINT_SESSION_SECRET", "dev-only-change-me-session-secret-0000000000"),
		SessionTTL:    durationEnv("GLOBMINT_SESSION_TTL", 15*24*time.Hour),
		TokenIssuer:   envOr("GLOBMINT_TOKEN_ISSUER", "globmint"),
		LogLevel:      envOr("GLOBMINT_LOG_LEVEL", "info"),
		RequestIDSalt: envOr("GLOBMINT_REQUEST_ID_SALT", "dev-request-salt"),
		Blockchain: BlockchainConfig{
			Network:          envOr("GLOBMINT_BLOCKCHAIN_NETWORK", "mock"),
			RPCURL:           os.Getenv("GLOBMINT_BLOCKCHAIN_RPC_URL"),
			ChainID:          int64Env("GLOBMINT_BLOCKCHAIN_CHAIN_ID", 11155111), // Sepolia default
			Stablecoin:       envOr("GLOBMINT_STABLECOIN_SYMBOL", "USDC"),
			StablecoinName:   envOr("GLOBMINT_STABLECOIN_NAME", "USD Coin"),
			StablecoinDecimals: intEnv("GLOBMINT_STABLECOIN_DECIMALS", 6),
			StablecoinEnabled: boolEnv("GLOBMINT_STABLECOIN_ENABLED", true),
			StablecoinContract: envOr("GLOBMINT_STABLECOIN_CONTRACT_ADDRESS", "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"),
			VaultContract:      envOr("GLOBMINT_VAULT_CONTRACT_ADDRESS", ""),
			VaultAddress:       envOr("GLOBMINT_VAULT_ADDRESS", ""),
			Mode:               envOr("GLOBMINT_BLOCKCHAIN_MODE", "mock"),
			PrivateKeyHex:   os.Getenv("GLOBMINT_STABLECOIN_PRIVATE_KEY"),
		},
	}
}

func int64Env(key string, def int64) int64 {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil {
			return n
		}
	}
	return def
}

func intEnv(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func boolEnv(key string, def bool) bool {
	if v := os.Getenv(key); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return def
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func durationEnv(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}

// HasDatabase reports whether a Postgres connection string was provided.
func (c Config) HasDatabase() bool { return c.DatabaseURL != "" }
