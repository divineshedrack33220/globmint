package middleware

import (
	"net/http"
)

// SecurityHeaders hardens browser-facing responses with standard security
// headers. The CSP is deliberately permissive about styles/scripts sources so
// the Flutter Web build keeps working in dev; tighten it before production
// release builds.
func SecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		w.Header().Set("Content-Security-Policy",
			"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; "+
				"style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' *; "+
				"frame-ancestors 'none'; base-uri 'self'")
		next.ServeHTTP(w, r)
	})
}

// MaxBody caps request body sizes so a malformed client cannot exhaust memory.
func MaxBody(maxBytes int64) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Body != nil {
				r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
			}
			next.ServeHTTP(w, r)
		})
	}
}