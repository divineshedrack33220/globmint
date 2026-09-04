package httpapi

import (
	"net/http"
	"strings"
	"time"

	"globmint/backend/internal/httpapi/middleware"
)

// NewHandler builds the full HTTP handler, applying middleware and registering routes.
func NewHandler(deps *Deps, auth middleware.Authenticator) http.Handler {
	mux := http.NewServeMux()

	// Public
	mux.HandleFunc("GET /health", deps.handleHealth)
	mux.HandleFunc("GET /live", deps.handleHealth)     // liveness probe
	mux.HandleFunc("GET /ready", deps.handleReady)     // readiness probe

	// API v1 routes
	api := "/api/v1"

	// Auth
	mux.HandleFunc(api+"/auth/register", deps.handleRegister)
	mux.HandleFunc(api+"/auth/login", deps.handleLogin)

	// Authenticated
	mux.Handle("POST "+api+"/auth/logout", middleware.Auth(auth, http.HandlerFunc(deps.handleLogout)))
	mux.Handle("GET "+api+"/users/me", middleware.Auth(auth, http.HandlerFunc(deps.handleMe)))
	mux.Handle("GET "+api+"/balances", middleware.Auth(auth, http.HandlerFunc(deps.handleListBalances)))
	mux.Handle("GET "+api+"/transactions", middleware.Auth(auth, http.HandlerFunc(deps.handleListTransactions)))

	// Money movement (idempotent + rate limited)
	mux.Handle("POST "+api+"/money/deposit", middleware.RateLimiter(
		middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(deps.handleDeposit))),
		time.Second,
		20,
		func(r *http.Request) string { return strings.TrimSpace(r.RemoteAddr) },
	))
	mux.Handle("POST "+api+"/money/withdraw", middleware.RateLimiter(
		middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(deps.handleWithdraw))),
		time.Second,
		20,
		func(r *http.Request) string { return strings.TrimSpace(r.RemoteAddr) },
	))
	mux.Handle("POST "+api+"/money/transfer", middleware.RateLimiter(
		middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(deps.handleTransfer))),
		time.Second,
		20,
		func(r *http.Request) string { return strings.TrimSpace(r.RemoteAddr) },
	))
	mux.Handle("POST "+api+"/money/convert", middleware.RateLimiter(
		middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(deps.handleConvert))),
		time.Second,
		20,
		func(r *http.Request) string { return strings.TrimSpace(r.RemoteAddr) },
	))

	// Conversions (quotes are read-only, no idempotency needed)
	mux.Handle("POST "+api+"/money/quote", middleware.Auth(auth, http.HandlerFunc(deps.handleQuoteConversion)))

	// Beneficiaries
	mux.Handle("GET "+api+"/beneficiaries", middleware.Auth(auth, http.HandlerFunc(deps.handleListBeneficiaries)))
	mux.Handle("POST "+api+"/beneficiaries", middleware.Auth(auth, http.HandlerFunc(deps.handleCreateBeneficiary)))
	mux.Handle("PATCH "+api+"/beneficiaries/{id}", middleware.Auth(auth, http.HandlerFunc(deps.handleUpdateBeneficiary)))
	mux.Handle("POST "+api+"/beneficiaries/{id}/favorite", middleware.Auth(auth, http.HandlerFunc(deps.handleToggleBeneficiaryFavorite)))
	mux.Handle("DELETE "+api+"/beneficiaries/{id}", middleware.Auth(auth, http.HandlerFunc(deps.handleDeleteBeneficiary)))
	mux.Handle("GET "+api+"/beneficiaries/account/{account_number}", middleware.Auth(auth, http.HandlerFunc(deps.handleResolveAccount)))

	// Bank accounts
	mux.Handle("GET "+api+"/bank-accounts", middleware.Auth(auth, http.HandlerFunc(deps.handleListBankAccounts)))
	mux.Handle("POST "+api+"/bank-accounts", middleware.Auth(auth, http.HandlerFunc(deps.handleCreateBankAccount)))
	mux.Handle("POST "+api+"/bank-accounts/{id}/default", middleware.Auth(auth, http.HandlerFunc(deps.handleSetDefaultBankAccount)))
	mux.Handle("DELETE "+api+"/bank-accounts/{id}", middleware.Auth(auth, http.HandlerFunc(deps.handleDeleteBankAccount)))

	// Savings (non-custodial on-chain vault)
	mux.Handle("GET "+api+"/savings/deposit-info", middleware.Auth(auth, http.HandlerFunc(deps.handleGetDepositInfo)))
	mux.Handle("PUT "+api+"/savings/deposit-address", middleware.Auth(auth, http.HandlerFunc(deps.handleSetDepositAddress)))

	// Devices (active sessions)
	mux.Handle("GET "+api+"/devices", middleware.Auth(auth, http.HandlerFunc(deps.handleListDevices)))
	mux.Handle("POST "+api+"/devices/revoke-others", middleware.Auth(auth, http.HandlerFunc(deps.handleRevokeOtherDevices)))
	mux.Handle("POST "+api+"/devices/{id}/revoke", middleware.Auth(auth, http.HandlerFunc(deps.handleRevokeDevice)))

	// Security activity + notifications
	mux.Handle("GET "+api+"/security-events", middleware.Auth(auth, http.HandlerFunc(deps.handleListSecurityEvents)))
	mux.Handle("GET "+api+"/notifications", middleware.Auth(auth, http.HandlerFunc(deps.handleListNotifications)))
	mux.Handle("POST "+api+"/notifications/read-all", middleware.Auth(auth, http.HandlerFunc(deps.handleMarkAllNotificationsRead)))
	mux.Handle("POST "+api+"/notifications/{id}/read", middleware.Auth(auth, http.HandlerFunc(deps.handleMarkNotificationRead)))

	return middleware.Origin("*")(middleware.Logging(middleware.RequestID(mux)))
}

func (d *Deps) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// handleReady is the readiness probe. Returns 200 if the server is ready to serve traffic.
func (d *Deps) handleReady(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}