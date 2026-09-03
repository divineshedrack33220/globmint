package httpapi

import (
	"net/http"

	"globmint/backend/internal/httpapi/middleware"
)

// NewHandler builds the full HTTP handler, applying middleware and registering routes.
func NewHandler(deps *Deps, auth middleware.Authenticator) http.Handler {
	mux := http.NewServeMux()

	// Public
	mux.HandleFunc("GET /health", deps.handleHealth)
	mux.HandleFunc("POST /auth/register", deps.handleRegister)
	mux.HandleFunc("POST /auth/login", deps.handleLogin)

	// Authenticated
	mux.Handle("POST /auth/logout", middleware.Auth(auth, http.HandlerFunc(deps.handleLogout)))
	mux.Handle("GET /users/me", middleware.Auth(auth, http.HandlerFunc(deps.handleMe)))
	mux.Handle("GET /balances", middleware.Auth(auth, http.HandlerFunc(deps.handleListBalances)))
	mux.Handle("GET /transactions", middleware.Auth(auth, http.HandlerFunc(deps.handleListTransactions)))

	// Money movement (idempotent)
	authIDem := func(f func(http.ResponseWriter, *http.Request)) http.Handler {
		return middleware.Auth(auth, middleware.Idempotency(http.HandlerFunc(f)))
	}
	mux.Handle("POST /money/deposit", authIDem(deps.handleDeposit))
	mux.Handle("POST /money/withdraw", authIDem(deps.handleWithdraw))
	mux.Handle("POST /money/transfer", authIDem(deps.handleTransfer))
	mux.Handle("POST /money/convert", authIDem(deps.handleConvert))

	// Conversions (quotes are read-only, no idempotency needed)
	mux.Handle("POST /money/quote", middleware.Auth(auth, http.HandlerFunc(deps.handleQuoteConversion)))

	// Beneficiaries
	mux.Handle("GET /beneficiaries", middleware.Auth(auth, http.HandlerFunc(deps.handleListBeneficiaries)))
	mux.Handle("POST /beneficiaries", middleware.Auth(auth, http.HandlerFunc(deps.handleCreateBeneficiary)))
	mux.Handle("PATCH /beneficiaries/{id}", middleware.Auth(auth, http.HandlerFunc(deps.handleUpdateBeneficiary)))
	mux.Handle("POST /beneficiaries/{id}/favorite", middleware.Auth(auth, http.HandlerFunc(deps.handleToggleBeneficiaryFavorite)))
	mux.Handle("DELETE /beneficiaries/{id}", middleware.Auth(auth, http.HandlerFunc(deps.handleDeleteBeneficiary)))
	mux.Handle("GET /beneficiaries/account/{account_number}", middleware.Auth(auth, http.HandlerFunc(deps.handleResolveAccount)))

	// Bank accounts
	mux.Handle("GET /bank-accounts", middleware.Auth(auth, http.HandlerFunc(deps.handleListBankAccounts)))
	mux.Handle("POST /bank-accounts", middleware.Auth(auth, http.HandlerFunc(deps.handleCreateBankAccount)))
	mux.Handle("POST /bank-accounts/{id}/default", middleware.Auth(auth, http.HandlerFunc(deps.handleSetDefaultBankAccount)))
	mux.Handle("DELETE /bank-accounts/{id}", middleware.Auth(auth, http.HandlerFunc(deps.handleDeleteBankAccount)))

	return middleware.Origin("*")(middleware.Logging(middleware.RequestID(mux)))
}

func (d *Deps) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}