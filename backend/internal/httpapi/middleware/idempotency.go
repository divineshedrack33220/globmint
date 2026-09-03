package middleware

import (
	"context"
	"net/http"
	"strings"
)

type idemCtxKey string

const idempotencyKeyCtxKey idemCtxKey = "idempotency_key"

// Idempotency captures the Idempotency-Key header so handlers and services can
// honor exactly-once semantics on retries. The authoritative dedupe is enforced
// at the ledger/data layer; this only carries the key through the request.
func Idempotency(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
		ctx := context.WithValue(r.Context(), idempotencyKeyCtxKey, key)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// IdempotencyKeyFrom returns the captured idempotency key (possibly empty).
func IdempotencyKeyFrom(ctx context.Context) string {
	if v, ok := ctx.Value(idempotencyKeyCtxKey).(string); ok {
		return v
	}
	return ""
}
