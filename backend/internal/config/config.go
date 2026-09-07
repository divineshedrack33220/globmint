package config

import (
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all runtime configuration, sourced from the environment.
// Secrets are read from env vars and never logged.
type Config struct {
	HTTPAddr      string
	DatabaseURL   string
	SessionSecret string
	VaultFallbackUserID string // demo/dev: credit vault deposits to this user when sender is unlinked
	VaultStartBlock     int64 // first block the vault indexer scans from
	SessionTTL    time.Duration
	TokenIssuer   string
	LogLevel      string
	RequestIDSalt string

	// CORSOrigins is the explicit list of allowed browser origins (e.g.
	// "https://app.example.com,https://admin.example.com"). Empty = allow all.
	CORSOrigins []string

	// VaultWithdraw* guard real-money withdrawals.
	VaultWithdrawEnabled   bool
	VaultWithdrawMinMinor  int64 // 0 = no minimum
	VaultWithdrawMaxMinor  int64 // 0 = no maximum
	VaultWithdrawDailyCapMinor int64 // 0 = no daily cap

	// VaultWithdrawElevationThresholdMinor time-locks withdrawals above this
	// amount (kobo); 0 disables the time-lock entirely.
	VaultWithdrawElevationThresholdMinor int64
	// VaultWithdrawElevationDelay is how long an elevated withdrawal waits
	// before the signer broadcasts it (default 24h).
	VaultWithdrawElevationDelay time.Duration

	// WithdrawFee* prices the nearly-free withdrawal fee (kobo). The fee is
	// fee = max(min(amount*bps/10000, cap), min); bps = 0 disables it.
	WithdrawFeeBPS      int
	WithdrawFeeMinMinor int64
	WithdrawFeeCapMinor int64

	// VaultMinConfirmations: number of block confirmations a deposit must
	// reach before the indexer credits the ledger (protects against reorgs).
	VaultMinConfirmations uint64

	// PrivacyMode toggles commitment-based (salt-hashed) vault balances. When
	// true, the backend stores a random salt per user, derives deposit
	// commitments as keccak256(address, salt), and never exposes raw-address
	// balances. Env: GLOBMINT_PRIVACY_MODE.
	PrivacyMode bool

	// RateLimitAuthBurst / RateLimitMoneyBurst override the per-IP token-bucket
	// budgets (auth: 5/s, money: 20/s). Raise them for load testing only.
	RateLimitAuthBurst  int
	RateLimitMoneyBurst int

	// ChaosFailureRate / ChaosLatencyMaxMS enable adversarial fault injection
	// for chaos testing. Both default to disabled in production.
	ChaosFailureRate  float64
	ChaosLatencyMaxMS int

	// Blockchain holds settings for the on-chain settlement layer.
	Blockchain BlockchainConfig
}

// BlockchainConfig holds blockchain and stablecoin settings.
type BlockchainConfig struct {
	Network         string // "mock", "sepolia", "mainnet", or an L2: base, arbitrum, optimism (+ their -sepolia forms)
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
		VaultFallbackUserID: os.Getenv("GLOBMINT_VAULT_FALLBACK_USER_ID"),
		VaultStartBlock:     int64Env("GLOBMINT_VAULT_START_BLOCK", 0),
		CORSOrigins:         csvEnv("GLOBMINT_CORS_ORIGINS"),
		VaultWithdrawEnabled:      boolEnv("GLOBMINT_VAULT_WITHDRAW_ENABLED", true),
		VaultWithdrawMinMinor:     int64Env("GLOBMINT_VAULT_WITHDRAW_MIN_MINOR", 0),
		VaultWithdrawMaxMinor:     int64Env("GLOBMINT_VAULT_WITHDRAW_MAX_MINOR", 0),
		VaultWithdrawDailyCapMinor: int64Env("GLOBMINT_VAULT_WITHDRAW_DAILY_CAP_MINOR", 0),
		VaultWithdrawElevationThresholdMinor: int64Env("GLOBMINT_VAULT_WITHDRAW_ELEVATION_THRESHOLD_MINOR", 0),
		VaultWithdrawElevationDelay:           durationEnv("GLOBMINT_VAULT_WITHDRAW_ELEVATION_DELAY", 24*time.Hour),
		WithdrawFeeBPS:      intEnv("GLOBMINT_WITHDRAW_FEE_BPS", 20),
		WithdrawFeeMinMinor: int64Env("GLOBMINT_WITHDRAW_FEE_MIN_MINOR", 1000),
		WithdrawFeeCapMinor: int64Env("GLOBMINT_WITHDRAW_FEE_CAP_MINOR", 10000),
		VaultMinConfirmations:      uint64Env("GLOBMINT_VAULT_MIN_CONFIRMATIONS", 0),
		PrivacyMode:                boolEnv("GLOBMINT_PRIVACY_MODE", false),
		RateLimitAuthBurst:         intEnv("GLOBMINT_RATE_LIMIT_AUTH_BURST", 5),
		RateLimitMoneyBurst:        intEnv("GLOBMINT_RATE_LIMIT_MONEY_BURST", 20),
		ChaosFailureRate:           float64Env("GLOBMINT_CHAOS_FAILURE_RATE", 0),
		ChaosLatencyMaxMS:          intEnv("GLOBMINT_CHAOS_LATENCY_MAX_MS", 0),
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

func uint64Env(key string, def uint64) uint64 {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.ParseUint(v, 10, 64); err == nil {
			return n
		}
	}
	return def
}

func float64Env(key string, def float64) float64 {
	if v := os.Getenv(key); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return def
}

func csvEnv(key string) []string {
	var out []string
	for _, part := range strings.Split(os.Getenv(key), ",") {
		if p := strings.TrimSpace(part); p != "" {
			out = append(out, p)
		}
	}
	return out
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
