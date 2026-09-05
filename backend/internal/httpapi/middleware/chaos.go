package middleware

import (
	"io"
	"log/slog"
	"math/rand"
	"net/http"
	"time"
)

// ChaosConfig enables adversarial fault injection for load/chaos testing.
// It is disabled unless Enabled and at least one of the two knobs is set; the
// production server leaves it off entirely.
type ChaosConfig struct {
	Enabled      bool
	FailureRate  float64 // probability [0..1] a request is failed with 503
	LatencyMaxMS int     // upper bound for injected per-request latency
}

func (c ChaosConfig) active() bool {
	return c.Enabled && (c.FailureRate > 0 || c.LatencyMaxMS > 0)
}

// Chaos wraps a handler with optional request failure and latency injection.
func Chaos(c ChaosConfig) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		if !c.active() {
			return next
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if c.LatencyMaxMS > 0 {
				if ms := rand.Intn(c.LatencyMaxMS + 1); ms > 0 {
					time.Sleep(time.Duration(ms) * time.Millisecond)
				}
			}
			if c.FailureRate > 0 && rand.Float64() < c.FailureRate {
				slog.Warn("chaos: injected failure",
					"method", r.Method, "path", r.URL.Path,
					"request_id", RequestIDFrom(r.Context()))
				w.Header().Set("Content-Type", "text/plain; charset=utf-8")
				w.WriteHeader(http.StatusServiceUnavailable)
				_, _ = io.WriteString(w, "injected failure\n")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}