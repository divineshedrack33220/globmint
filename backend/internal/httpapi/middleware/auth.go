package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"globmint/backend/internal/domain"
)

type authCtxKey string

const (
	authUserKey  authCtxKey = "auth_user"
	authTokenKey authCtxKey = "auth_token"
)

// Authenticator validates bearer tokens.
type Authenticator interface {
	Authenticate(ctx context.Context, token string) (*domain.User, error)
}

// Auth requires a valid bearer token and injects the authenticated user into
// the request context.
func Auth(auth Authenticator, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			writeAuthError(w, r)
			return
		}
		token := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
		if token == "" {
			writeAuthError(w, r)
			return
		}
		user, err := auth.Authenticate(r.Context(), token)
		if err != nil {
			writeAuthError(w, r)
			return
		}
		ctx := context.WithValue(r.Context(), authUserKey, user)
		ctx = context.WithValue(ctx, authTokenKey, token)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// UserFrom returns the authenticated user from context.
func UserFrom(ctx context.Context) *domain.User {
	if u, ok := ctx.Value(authUserKey).(*domain.User); ok {
		return u
	}
	return nil
}

// TokenFrom returns the raw bearer token from context.
func TokenFrom(ctx context.Context) string {
	if t, ok := ctx.Value(authTokenKey).(string); ok {
		return t
	}
	return ""
}

type authErrorEnvelope struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	RequestID string `json:"request_id"`
}

func writeAuthError(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_ = json.NewEncoder(w).Encode(authErrorEnvelope{
		Code:      "UNAUTHENTICATED",
		Message:   "Authentication required.",
		RequestID: RequestIDFrom(r.Context()),
	})
}
