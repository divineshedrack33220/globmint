package middleware

import (
	"log/slog"
	"net/http"
	"strings"
	"time"
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

// Logging emits structured request logs using slog.
// The request ID enables cross-referencing with error envelopes returned to clients.
func Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		slog.Info("request completed",
			slog.String("method", r.Method),
			"path", r.URL.Path,
			"request_id", RequestIDFrom(r.Context()),
			"remote_addr", strings.TrimSpace(r.RemoteAddr),
			slog.Int("status", rec.status),
			slog.Duration("duration", time.Since(start)))
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