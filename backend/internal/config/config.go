package config

import (
	"os"
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
	}
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
