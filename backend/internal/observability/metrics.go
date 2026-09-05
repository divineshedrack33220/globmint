// Package observability provides a zero-dependency Prometheus-style metrics
// registry for the money service. It is deliberately small: counters only, with
// normalized label values so the label space cannot explode from user data.
package observability

import (
	"fmt"
	"io"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
)

var uuidLike = regexp.MustCompile(`[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}`)
var numLike = regexp.MustCompile(`/[0-9a-fA-Fx]+`)

// Default is the process-wide registry.
var Default = New()

// Registry accumulates counters. All methods are safe for concurrent use.
type Registry struct {
	mu    sync.Mutex
	reqs  map[string]*atomic.Int64 // key: method+" "+normalizedPath+" "+status
	login atomic.Int64
	// withdraw counts per destination-hash bucket (cardinality-safe).
	withdraw atomic.Int64
	reconcil atomic.Int64
}

// New returns an empty registry.
func New() *Registry {
	return &Registry{reqs: make(map[string]*atomic.Int64)}
}

// NormalizePath collapses uuid and hex segments so label cardinality stays
// bounded regardless of how many resources users create.
func NormalizePath(path string) string {
	p := uuidLike.ReplaceAllString(path, "{id}")
	p = numLike.ReplaceAllString(p, "/{id}")
	return p
}

// Request records one completed HTTP request.
func (r *Registry) Request(method, path string, status int) {
	key := method + " " + NormalizePath(path) + " " + fmt.Sprintf("%d", status)
	r.mu.Lock()
	c := r.reqs[key]
	if c == nil {
		c = &atomic.Int64{}
		r.reqs[key] = c
	}
	r.mu.Unlock()
	c.Add(1)
}

// LoginFailure records a rejected login (bad creds or lockout trip).
func (r *Registry) LoginFailure() { r.login.Add(1) }

// Withdrawal records an executed on-chain vault withdrawal.
func (r *Registry) Withdrawal() { r.withdraw.Add(1) }

// ReconcileFailure records an indexer reconciliation mismatch.
func (r *Registry) ReconcileFailure() { r.reconcil.Add(1) }

// WritePrometheus renders the registry in Prometheus text exposition format.
func (r *Registry) WritePrometheus(w io.Writer) {
	fmt.Fprintln(w, "# HELP http_requests_total Total HTTP requests by method, path and status.")
	fmt.Fprintln(w, "# TYPE http_requests_total counter")
	r.mu.Lock()
	defer r.mu.Unlock()
	for key, c := range r.reqs {
		parts := strings.SplitN(key, " ", 3)
		fmt.Fprintf(w, "http_requests_total{method=%q,path=%q,status=%q} %d\n", parts[0], parts[1], parts[2], c.Load())
	}
	fmt.Fprintln(w, "# HELP globmint_login_failures_total Rejected login attempts.")
	fmt.Fprintln(w, "# TYPE globmint_login_failures_total counter")
	fmt.Fprintf(w, "globmint_login_failures_total %d\n", r.login.Load())
	fmt.Fprintln(w, "# HELP globmint_withdrawals_total Executed vault withdrawals.")
	fmt.Fprintln(w, "# TYPE globmint_withdrawals_total counter")
	fmt.Fprintf(w, "globmint_withdrawals_total %d\n", r.withdraw.Load())
	fmt.Fprintln(w, "# HELP globmint_reconcile_failures_total Vault reconciliation mismatches.")
	fmt.Fprintln(w, "# TYPE globmint_reconcile_failures_total counter")
	fmt.Fprintf(w, "globmint_reconcile_failures_total %d\n", r.reconcil.Load())
}