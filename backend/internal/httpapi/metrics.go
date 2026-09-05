package httpapi

import (
	"net/http"

	"globmint/backend/internal/observability"
)

// handleMetrics exposes the process metrics in Prometheus text format. The
// endpoint is unauthenticated by design for scrape agents; in production put it
// behind a firewall/reverse-proxy allow-list.
func (d *Deps) handleMetrics(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	observability.Default.WritePrometheus(w)
}