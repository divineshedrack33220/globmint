package middleware

import (
	"log/slog"
	"net/http"
	"strings"
	"time"
	"sync"
)

// rateLimiter limits the rate of requests per client key.
// It uses a simple token bucket approach stored in memory.
// For production, replace with a distributed store (Redis, etc.).
type rateLimiter struct {
	interval time.Duration
	burst    int
	tokens   map[string]*tokenBucket
	mu       sync.Mutex
}

type tokenBucket struct {
	tokens     int
	lastUpdate time.Time
}

// NewRateLimiter creates a limiter that allows burst tokens every interval.
// For example, NewRateLimiter( time.Second, 10 ) allows 10 requests per second per key.
func NewRateLimiter(interval time.Duration, burst int) *rateLimiter {
	rl := &rateLimiter{
		interval: interval,
		burst:    burst,
		tokens:   make(map[string]*tokenBucket),
	}
	// Initialize buckets
	for key := range rl.tokens {
		rl.tokens[key] = &tokenBucket{tokens: burst, lastUpdate: time.Now()}
	}
	return rl
}

// allow checks if a request from the given key is permitted.
func (rl *rateLimiter) allow(key string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	bucket, exists := rl.tokens[key]
	if !exists {
		bucket = &tokenBucket{tokens: rl.burst, lastUpdate: time.Now()}
		rl.tokens[key] = bucket
	}

	now := time.Now()
	elapsed := now.Sub(bucket.lastUpdate)

	// Refill tokens based on elapsed time
	refill := int(elapsed / rl.interval)
	if refill > 0 {
		bucket.tokens = min(bucket.tokens+refill, rl.burst)
		bucket.lastUpdate = bucket.lastUpdate.Add(time.Duration(refill) * rl.interval)
	}

	if bucket.tokens > 0 {
		bucket.tokens--
		bucket.lastUpdate = now
		return true
	}
	return false
}

// min returns the smaller of a and b.
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// RateLimiter returns an HTTP middleware that limits the rate of requests
// per IP address (or a custom key provided via context).
// The context key must be set by the caller if a different identifier is desired.
func RateLimiter(next http.Handler, interval time.Duration, burst int, keyFunc func(r *http.Request) string) http.Handler {
	rl := NewRateLimiter(interval, burst)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Determine the client key.
		// Default: use remote IP. Override via keyFunc if needed.
		clientKey := keyFunc(r)
		if clientKey == "" {
			clientKey = strings.TrimSpace(r.RemoteAddr)
			if idx := strings.LastIndex(clientKey, ":"); idx >= 0 {
				clientKey = clientKey[:idx]
			}
		}

		if !rl.allow(clientKey) {
			slog.Warn("rate limit exceeded", "key", clientKey, "interval", interval, "burst", burst)
			http.Error(w, "Too many requests. Please retry later.", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}