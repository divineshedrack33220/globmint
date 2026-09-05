// Package observability provides a zero-dependency Prometheus-style metrics
// registry for the money service. It is deliberately small: counters only, with
// normalized label values so the label space cannot explode from user data.
package observability

import (
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
)

var uuidLike = regexp.MustCompile(`[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}`)
var numLike = regexp.MustCompile(`/[0-9a-fA-Fx]+`)

// Default is the process-wide registry.
var Default = New()

// durationBucketsMS buckets for request latency in milliseconds (Prometheus
// histogram convention: bucket upper bounds, cumulative below).
var durationBucketsMS = []float64{5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000}

// Registry accumulates counters. All methods are safe for concurrent use.
type Registry struct {
	mu        sync.Mutex
	reqs      map[string]*atomic.Int64 // key: method+" "+normalizedPath+" "+status
	durations map[string]*histogram    // key: normalizedPath
	login     atomic.Int64
	// withdraw counts per destination-hash bucket (cardinality-safe).
	withdraw atomic.Int64
	reconcil atomic.Int64
	// outbound failures keyed by a bounded reason string.
	outbound map[string]*atomic.Int64
	// signerBalance is the signer wallet's stablecoin balance in major units,
	// refreshed periodically by the vault sweeper (guarded by mu).
	signerBalance float64
	// indexerLag is (chain head - processed cursor) in blocks, or -1 when the
	// indexer has not scanned yet.
	indexerLag int64
}

// histogram is a latency histogram with fixed bucket boundaries.
type histogram struct {
	buckets []float64
	counts  []uint64
	count   uint64
	sumMS   float64
}

func (h *histogram) observe(ms float64) {
	h.count++
	h.sumMS += ms
	for i, b := range h.buckets {
		if ms <= b {
			h.counts[i]++
		}
	}
}

// New returns an empty registry.
func New() *Registry {
	return &Registry{
		reqs:      make(map[string]*atomic.Int64),
		durations: make(map[string]*histogram),
		outbound:  make(map[string]*atomic.Int64),
		indexerLag: -1,
	}
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

// ObserveDuration records request latency in milliseconds per normalized path.
func (r *Registry) ObserveDuration(path string, ms int64) {
	key := NormalizePath(path)
	r.mu.Lock()
	h := r.durations[key]
	if h == nil {
		h = &histogram{buckets: durationBucketsMS, counts: make([]uint64, len(durationBucketsMS))}
		r.durations[key] = h
	}
	h.observe(float64(ms))
	r.mu.Unlock()
}

// LoginFailure records a rejected login (bad creds or lockout trip).
func (r *Registry) LoginFailure() { r.login.Add(1) }

// Withdrawal records an executed on-chain vault withdrawal.
func (r *Registry) Withdrawal() { r.withdraw.Add(1) }

// WithdrawalFailure records a failed outbound on-chain withdrawal by bounded
// reason ("broadcast" | "ledger" | "elevation"). Reason strings are restricted
// so the label space cannot explode.
func (r *Registry) WithdrawalFailure(reason string) {
	switch reason {
	case "broadcast", "ledger", "elevation":
	default:
		reason = "other"
	}
	r.mu.Lock()
	c := r.outbound[reason]
	if c == nil {
		c = &atomic.Int64{}
		r.outbound[reason] = c
	}
	r.mu.Unlock()
	c.Add(1)
}

// SetSignerBalance records the signer wallet's stablecoin balance (major units).
func (r *Registry) SetSignerBalance(major float64) {
	r.mu.Lock()
	r.signerBalance = major
	r.mu.Unlock()
}

// SetIndexerLag records how many blocks the indexer is behind the chain head;
// -1 means the indexer has not scanned yet.
func (r *Registry) SetIndexerLag(blocks int64) {
	r.mu.Lock()
	r.indexerLag = blocks
	r.mu.Unlock()
}

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
	fmt.Fprintln(w, "# HELP http_request_duration_ms Request latency by normalized path.")
	fmt.Fprintln(w, "# TYPE http_request_duration_ms histogram")
	for key, h := range r.durations {
		cum := uint64(0)
		for i, b := range h.buckets {
			cum += h.counts[i]
			fmt.Fprintf(w, "http_request_duration_ms_bucket{path=%q,le=%q} %d\n", key, formatFloat(b), cum)
		}
		fmt.Fprintf(w, "http_request_duration_ms_bucket{path=%q,le=\"+Inf\"} %d\n", key, h.count)
		fmt.Fprintf(w, "http_request_duration_ms_sum{path=%q} %v\n", key, h.sumMS)
		fmt.Fprintf(w, "http_request_duration_ms_count{path=%q} %d\n", key, h.count)
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
	fmt.Fprintln(w, "# HELP globmint_outbound_failures_total Failed outbound on-chain operations by reason.")
	fmt.Fprintln(w, "# TYPE globmint_outbound_failures_total counter")
	for reason, c := range r.outbound {
		fmt.Fprintf(w, "globmint_outbound_failures_total{reason=%q} %d\n", reason, c.Load())
	}
	fmt.Fprintln(w, "# HELP globmint_signer_balance Stablecoin balance of the withdrawal signer wallet (major units).")
	fmt.Fprintln(w, "# TYPE globmint_signer_balance gauge")
	fmt.Fprintf(w, "globmint_signer_balance %v\n", r.signerBalance)
	fmt.Fprintln(w, "# HELP globmint_indexer_lag_blocks Blocks the vault indexer is behind the chain head.")
	fmt.Fprintln(w, "# TYPE globmint_indexer_lag_blocks gauge")
	if r.indexerLag < 0 {
		fmt.Fprintln(w, "globmint_indexer_lag_blocks NaN")
	} else {
		fmt.Fprintf(w, "globmint_indexer_lag_blocks %d\n", r.indexerLag)
	}
}

func formatFloat(f float64) string {
	return strconv.FormatFloat(f, 'g', -1, 64)
}