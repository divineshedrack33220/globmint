package middleware

import (
	"net/http"
	"strings"
)

// Origin returns an HTTP handler that applies CORS headers, reflecting only
// origins present in the allowlist. An empty or "*"-containing allowlist opens
// the API to any origin (development default).
func Origin(origins []string) func(http.Handler) http.Handler {
	allowed := map[string]bool{}
	wildcard := len(origins) == 0
	for _, o := range origins {
		o = strings.TrimSpace(o)
		if strings.EqualFold(o, "*") {
			wildcard = true
		} else if o != "" {
			allowed[o] = true
		}
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			originHeader := r.Header.Get("Origin")
			origin := "*"
			if originHeader != "" && !wildcard && allowed[originHeader] {
				origin = originHeader
			} else if originHeader != "" && wildcard {
				// Reflect the request origin when open; keeps dev CORS simple.
				origin = originHeader
			}
			if r.Method == http.MethodOptions {
				w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
				w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Idempotency-Key, x-access-token")
				w.Header().Set("Access-Control-Max-Age", "86400")
				if origin != "" && (wildcard || allowed[originHeader]) {
					w.Header().Set("Access-Control-Allow-Origin", origin)
				}
				w.Header().Add("Vary", "Origin")
				w.WriteHeader(http.StatusNoContent)
				return
			}
			if originHeader != "" && (wildcard || allowed[originHeader]) {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Add("Vary", "Origin")
			}
			next.ServeHTTP(w, r)
		})
	}
}