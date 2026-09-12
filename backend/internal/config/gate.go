package config

import (
	"errors"
	"fmt"
	"strings"
)

// defaultDevSecret values that must never appear in production environments.
const (
	defaultSessionSecret = "dev-only-change-me-session-secret-0000000000"
	defaultRequestSalt   = "dev-request-salt"
)

// ValidateProduction refuses to start when the blockchain network targets
// mainnet but the environment still carries development defaults or dangerous
// settings. Returns a descriptive error so the operator can fix the config.
func ValidateProduction(cfg Config) error {
	isMainnet := cfg.Blockchain.Network == "mainnet" || cfg.Blockchain.ChainID == 1
	if !isMainnet {
		return nil
	}

	var problems []string
	if cfg.Blockchain.Network != "mainnet" {
		problems = append(problems, "GLOBMINT_BLOCKCHAIN_NETWORK must be \"mainnet\"")
	}
	if cfg.Blockchain.Mode != "real" {
		problems = append(problems, "GLOBMINT_BLOCKCHAIN_MODE must be \"real\"")
	}
	if cfg.Blockchain.RPCURL == "" {
		problems = append(problems, "GLOBMINT_BLOCKCHAIN_RPC_URL must be set to a mainnet RPC provider")
	}
	if cfg.Blockchain.PrivateKeyHex == "" {
		problems = append(problems, "GLOBMINT_STABLECOIN_PRIVATE_KEY must be set (vault signer)")
	}
	if cfg.Blockchain.VaultContract == "" {
		problems = append(problems, "GLOBMINT_VAULT_CONTRACT_ADDRESS must be set to the deployed mainnet vault")
	}
	if cfg.Blockchain.VaultAddress == "" {
		problems = append(problems, "GLOBMINT_VAULT_ADDRESS must be set")
	}
	if cfg.VaultFallbackUserID != "" {
		problems = append(problems, "GLOBMINT_VAULT_FALLBACK_USER_ID must be empty on mainnet (it silently credits unlinked deposits)")
	}
	if cfg.SessionSecret == defaultSessionSecret || cfg.SessionSecret == "" {
		problems = append(problems, "GLOBMINT_SESSION_SECRET must be replaced with a long random value")
	}
	if cfg.RequestIDSalt == defaultRequestSalt {
		problems = append(problems, "GLOBMINT_REQUEST_ID_SALT must be replaced with a random value")
	}
	if len(cfg.CORSOrigins) == 0 || hasWildcard(cfg.CORSOrigins) {
		problems = append(problems, "GLOBMINT_CORS_ORIGINS must list explicit app origins on mainnet")
	}
	if cfg.VaultMinConfirmations < 12 {
		problems = append(problems, "GLOBMINT_VAULT_MIN_CONFIRMATIONS must be >= 12 on mainnet")
	}
	if !cfg.RequireUserSignature {
		problems = append(problems, "GLOBMINT_REQUIRE_USER_SIGNATURE must be true on mainnet (no operator-signed withdrawals)")
	}
	if cfg.Blockchain.CloneFactoryContract == "" {
		problems = append(problems, "GLOBMINT_CLONE_FACTORY_ADDRESS must be set on mainnet (withdrawals relay from per-user clones via withdrawWithSig)")
	}
	if len(problems) > 0 {
		return fmt.Errorf("production config check failed:\n  - %s", strings.Join(problems, "\n  - "))
	}
	return nil
}

func hasWildcard(origins []string) bool {
	for _, o := range origins {
		if strings.TrimSpace(o) == "*" {
			return true
		}
	}
	return false
}

// ErrNotConfigured is returned when required configuration is absent.
var ErrNotConfigured = errors.New("required configuration is missing")