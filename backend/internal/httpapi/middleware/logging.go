package middleware

import (
	"log/slog"
	"net/http"
	"strings"
	"time"

	"globmint/backend/internal/observability"
)

// requestAttrs returns attributes for the request log entry.
func requestAttrs(r *http.Request) []slog.Attr {
	return []slog.Attr{
		slog.String("method", r.Method),
		slog.String("path", r.URL.Path),
		slog.String("request_id", RequestIDFrom(r.Context())),
		slog.String("remote_addr", strings.TrimSpace(r.RemoteAddr)),
	}
}

// Logging emits structured request logs using slog and feeds the Prometheus
// registry (http_requests_total + latency histogram, normalized paths).
// The request ID enables cross-referencing with error envelopes returned to clients.
func Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		dur := time.Since(start)
		observability.Default.Request(r.Method, r.URL.Path, rec.status)
		observability.Default.ObserveDuration(r.URL.Path, dur.Milliseconds())
		slog.Info("request completed",
			slog.String("method", r.Method),
			"path", r.URL.Path,
			"request_id", RequestIDFrom(r.Context()),
			"remote_addr", strings.TrimSpace(r.RemoteAddr),
			slog.Int("status", rec.status),
			slog.Duration("duration", dur))
	})
}

// statusRecorder captures the HTTP status code written by the handler.
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

// Flush forwards flushes so Server-Sent Events work through the middleware
// stack (the subtle panache the standard library requires for streaming).
func (r *statusRecorder) Flush() {
	if f, ok := r.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

// Unwrap lets http.ResponseController find the underlying writer so SSE
// handlers can clear the server write deadline per connection.
func (r *statusRecorder) Unwrap() http.ResponseWriter { return r.ResponseWriter }