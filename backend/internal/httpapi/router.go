package httpapi

import (
	"net"
	"net/http"
	"time"

	"globmint/backend/internal/httpapi/middleware"
)

// clientIPKey keys the rate limiter by client IP (without the ephemeral port)
// so burst accounting actually applies across requests from one browser.
func clientIPKey(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil {
		return host
	}
	return r.RemoteAddr
}

// NewHandler builds the full HTTP handler, applying middleware and registering
// routes. corsOrigins is the explicit browser-origin allowlist (empty = open).
// limits overrides the per-route rate budgets; chaos injects failures (test-only).
func NewHandler(deps *Deps, auth middleware.Authenticator, corsOrigins []string, limits middleware.RateLimits, chaos middleware.ChaosConfig) http.Handler {
	limits = limits.Normalized()
	mux := http.NewServeMux()

	// Public
	mux.HandleFunc("GET /health", deps.handleHealth)
	mux.HandleFunc("GET /live", deps.handleHealth)     // liveness probe
	mux.HandleFunc("GET /ready", deps.handleReady)     // readiness probe
	mux.HandleFunc("GET /metrics", deps.handleMetrics)

	// API v1 routes
	api := "/api/v1"

	// Auth (rate-limited to slow brute force)
	mux.Handle("POST "+api+"/auth/register", middleware.RateLimiter(http.HandlerFunc(deps.handleRegister), time.Second, limits.AuthBurst, clientIPKey))
	mux.Handle("POST "+api+"/auth/login", middleware.RateLimiter(http.HandlerFunc(deps.handleLogin), time.Second, limits.AuthBurst, clientIPKey))
	mux.Handle("POST "+api+"/auth/2fa/verify", middleware.RateLimiter(http.HandlerFunc(deps.handleVerify2FA), time.Second, limits.AuthBurst, clientIPKey))

	// Authenticated
	mux.Handle("POST "+api+"/auth/logout", middleware.Auth(auth, http.HandlerFunc(deps.handleLogout)))
	mux.Handle("POST "+api+"/auth/password", middleware.Auth(auth, http.HandlerFunc(deps.handleChangePassword)))
	mux.Handle("GET "+api+"/auth/totp/setup", middleware.Auth(auth, http.HandlerFunc(deps.handleGenerateTOTP)))
	mux.Handle("POST "+api+"/auth/totp/enable", middleware.Auth(auth, http.HandlerFunc(deps.handleEnableTOTP)))
	mux.Handle("POST "+api+"/auth/totp/disable", middleware.Auth(auth, http.HandlerFunc(deps.handleDisableTOTP)))
	mux.Handle("GET "+api+"/users/me", middleware.Auth(auth, http.HandlerFunc(deps.handleMe)))
	mux.Handle("POST "+api+"/pin/verify", middleware.RateLimiter(
		middleware.Auth(auth, http.HandlerFunc(deps.handleVerifyPin)),
		time.Second,
		limits.AuthBurst,
		clientIPKey,
	))
	mux.Handle("PUT "+api+"/pin", middleware.Auth(auth, http.HandlerFunc(deps.handleSetPin)))
	mux.Handle("GET "+api+"/balances", middleware.Auth(auth, http.HandlerFunc(deps.handleListBalances)))
	mux.Handle("GET "+api+"/transactions", middleware.Auth(auth, http.HandlerFunc(deps.handleListTransactions)))

	// Server-Sent Events: push balance/vault/transaction changes to the UI.
	mux.Handle("GET "+api+"/events", middleware.Auth(auth, http.HandlerFunc(deps.handleEvents)))

	// Money movement (idempotent + rate limited)
	mux.Handle("POST "+api+"/money/deposit", middleware.RateLimiter(
		middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(deps.handleDeposit))),
		time.Second,
		limits.MoneyBurst,
		clientIPKey,
	))
	mux.Handle("POST "+api+"/money/withdraw", middleware.RateLimiter(
		middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(deps.handleWithdraw))),
		time.Second,
		limits.MoneyBurst,
		clientIPKey,
	))
	mux.Handle("POST "+api+"/money/transfer", middleware.RateLimiter(
		middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(deps.handleTransfer))),
		time.Second,
		limits.MoneyBurst,
		clientIPKey,
	))
	mux.Handle("POST "+api+"/money/convert", middleware.RateLimiter(
		middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(deps.handleConvert))),
		time.Second,
		limits.MoneyBurst,
		clientIPKey,
	))

	// Conversions (quotes are read-only, no idempotency needed)
	mux.Handle("POST "+api+"/money/quote", middleware.Auth(auth, http.HandlerFunc(deps.handleQuoteConversion)))
	mux.Handle("GET "+api+"/money/rate", middleware.Auth(auth, http.HandlerFunc(deps.handleRate)))

	// Beneficiaries
	mux.Handle("GET "+api+"/beneficiaries", middleware.Auth(auth, http.HandlerFunc(deps.handleListBeneficiaries)))
	mux.Handle("POST "+api+"/beneficiaries", middleware.Auth(auth, http.HandlerFunc(deps.handleCreateBeneficiary)))
	mux.Handle("PATCH "+api+"/beneficiaries/{id}", middleware.Auth(auth, http.HandlerFunc(deps.handleUpdateBeneficiary)))
	mux.Handle("POST "+api+"/beneficiaries/{id}/favorite", middleware.Auth(auth, http.HandlerFunc(deps.handleToggleBeneficiaryFavorite)))
	mux.Handle("DELETE "+api+"/beneficiaries/{id}", middleware.Auth(auth, http.HandlerFunc(deps.handleDeleteBeneficiary)))
	mux.Handle("GET "+api+"/beneficiaries/address/{address}", middleware.Auth(auth, http.HandlerFunc(deps.handleResolveAccount)))

	// Bank accounts
	mux.Handle("GET "+api+"/bank-accounts", middleware.Auth(auth, http.HandlerFunc(deps.handleListBankAccounts)))
	mux.Handle("POST "+api+"/bank-accounts", middleware.Auth(auth, http.HandlerFunc(deps.handleCreateBankAccount)))
	mux.Handle("POST "+api+"/bank-accounts/{id}/default", middleware.Auth(auth, http.HandlerFunc(deps.handleSetDefaultBankAccount)))
	mux.Handle("DELETE "+api+"/bank-accounts/{id}", middleware.Auth(auth, http.HandlerFunc(deps.handleDeleteBankAccount)))

	// Savings (non-custodial on-chain vault)
	mux.Handle("GET "+api+"/savings/deposit-info", middleware.Auth(auth, http.HandlerFunc(deps.handleGetDepositInfo)))
	mux.Handle("PUT "+api+"/savings/deposit-address", middleware.Auth(auth, http.HandlerFunc(deps.handleSetDepositAddress)))
	mux.Handle("GET "+api+"/savings/vault-status", middleware.Auth(auth, http.HandlerFunc(deps.handleVaultStatus)))
	mux.Handle("POST "+api+"/savings/withdraw", middleware.RateLimiter(
		middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(deps.handleVaultWithdraw))),
		time.Second,
		limits.MoneyBurst,
		clientIPKey,
	))
	mux.Handle("GET "+api+"/savings/withdraw", middleware.Auth(auth, http.HandlerFunc(deps.handleListVaultElevations)))
	mux.Handle("POST "+api+"/savings/withdraw/{id}/cancel", middleware.RateLimiter(
		middleware.Auth(auth, http.HandlerFunc(deps.handleCancelVaultWithdraw)),
		time.Second,
		limits.MoneyBurst,
		clientIPKey,
	))

	// Devices (active sessions)
	mux.Handle("GET "+api+"/devices", middleware.Auth(auth, http.HandlerFunc(deps.handleListDevices)))
	mux.Handle("POST "+api+"/devices/revoke-others", middleware.Auth(auth, http.HandlerFunc(deps.handleRevokeOtherDevices)))
	mux.Handle("POST "+api+"/devices/{id}/revoke", middleware.Auth(auth, http.HandlerFunc(deps.handleRevokeDevice)))

	// Security activity + notifications
	mux.Handle("GET "+api+"/security-events", middleware.Auth(auth, http.HandlerFunc(deps.handleListSecurityEvents)))
	mux.Handle("GET "+api+"/notifications", middleware.Auth(auth, http.HandlerFunc(deps.handleListNotifications)))
	mux.Handle("POST "+api+"/notifications/read-all", middleware.Auth(auth, http.HandlerFunc(deps.handleMarkAllNotificationsRead)))
	mux.Handle("POST "+api+"/notifications/{id}/read", middleware.Auth(auth, http.HandlerFunc(deps.handleMarkNotificationRead)))

	return middleware.Origin(corsOrigins)(middleware.Logging(middleware.RequestID(middleware.Chaos(chaos)(mux))))
}

func (d *Deps) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// handleReady is the readiness probe. Returns 200 if the server is ready to serve traffic.
func (d *Deps) handleReady(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}