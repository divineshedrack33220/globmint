package httpapi

import (
	"net/http"

	"globmint/backend/internal/httpapi/middleware"
)

// NewHandler builds the full HTTP handler, applying middleware and registering
// all routes. Public routes require no authentication; the rest require a valid
// bearer token via the Auth middleware.
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

	return middleware.Logging(middleware.RequestID(mux))
}

func (d *Deps) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
