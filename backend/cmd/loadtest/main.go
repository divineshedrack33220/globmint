package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/signal"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"

	"globmint/backend/internal/httpapi"
	"globmint/backend/internal/httpapi/middleware"
	"globmint/backend/internal/infrastructure/blockchain"
	"globmint/backend/internal/services"
	"globmint/backend/internal/storage/postgres"
)

// loadtest drives the full HTTP stack (auth -> rate limiter -> idempotency ->
// handlers) against a real Postgres, using a mock chain so the hot path is
// exercised hermeticiy. It seeds users, logs them in, and mixes read-heavy
// operations (profile + quotes) with occasional money transfers.
//
// Chaos injection (-chaos-failure-rate / -chaos-latency-max-ms) runs the same
// traffic through the chaos middleware so scripts can assert recovery.

type summary struct {
	reqs        uint64
	status      map[int]uint64
	byPath      map[string]map[int]uint64
	transferOK  uint64
	transfer4xx uint64
	latencies   []int64 // ms
	mu          sync.Mutex
}

func (s *summary) add(code int, ms int64) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.reqs++
	s.status[code]++
	s.latencies = append(s.latencies, ms)
}

// addResult records a finished request with its path so 4xx/5xx can be attributed.
func (s *summary) addResult(path string, code int, ms int64) {
	s.add(code, ms)
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.byPath[path] == nil {
		s.byPath[path] = map[int]uint64{}
	}
	s.byPath[path][code]++
}

func pct(sorted []int64, p float64) int64 {
	if len(sorted) == 0 {
		return 0
	}
	idx := int(float64(len(sorted)-1) * p)
	return sorted[idx]
}

func main() {
	var (
		users       = flag.Int("users", 20, "number of seeded users/workers")
		duration    = flag.Duration("duration", 15*time.Second, "load window")
		transferDiv = flag.Int("transfer-every", 4, "every Nth iteration issues a transfer")
		authBurst   = flag.Int("auth-burst", 500, "per-IP auth rate-limit burst")
		moneyBurst  = flag.Int("money-burst", 2000, "per-IP money rate-limit burst")
		chaosRate   = flag.Float64("chaos-failure-rate", 0, "fraction of requests to fail with 503")
		chaosLat    = flag.Int("chaos-latency-max-ms", 0, "max injected latency (ms)")
		maxP95      = flag.Duration("max-p95", 0, "exit non-zero if p95 exceeds this")
		dsn         = flag.String("dsn", "", "postgres DSN (defaults to env or dev DSN)")
		verbose     = flag.Bool("verbose", false, "log each worker start/finish")
	)
	flag.Parse()

	if *dsn == "" {
		*dsn = os.Getenv("GLOBMINT_TEST_DATABASE_URL")
	}
	if *dsn == "" {
		*dsn = "postgres://globmint:globmint_dev@127.0.0.1:5434/globmint"
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	db, err := postgres.Open(ctx, postgres.Config{DSN: *dsn, MaxConns: 64})
	if err != nil {
		fmt.Fprintf(os.Stderr, "postgres: %v\n", err)
		os.Exit(1)
	}
	defer db.Close()
	if err := db.RunMigrations(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "migrations: %v\n", err)
		os.Exit(1)
	}

	authSvc := services.NewAuthService(db, 12*time.Hour, "loadtest-session-secret")
	balanceSvc := services.NewBalanceService(db)
	moneySvc := services.NewMoneyService(db)
	chain := blockchain.NewMockBlockchainService()

	deps := &httpapi.Deps{
		Auth:       authSvc,
		Balance:    balanceSvc,
		Money:      moneySvc,
		Ledger:     services.NewLedgerService(db),
		Savings:    services.NewSavingsService(db, services.SavingsConfig{}),
		Security:   services.NewSecurityService(db),
		Blockchain: chain,
	}
	handler := httpapi.NewHandler(deps, authSvc, nil,
		middleware.RateLimits{AuthBurst: *authBurst, MoneyBurst: *moneyBurst},
		middleware.ChaosConfig{Enabled: *chaosRate > 0 || *chaosLat > 0, FailureRate: *chaosRate, LatencyMaxMS: *chaosLat},
	)
	srv := httptest.NewServer(handler)
	defer srv.Close()

	// Seed users with NGN funding so transfers always succeed.
	type seeded struct {
		email  string
		userID string
	}
	seededUsers := make([]seeded, *users)
	for i := 0; i < *users; i++ {
		email := fmt.Sprintf("loadtest-%d@example.com", time.Now().UnixNano()+int64(i))
		user, _, err := authSvc.Register(ctx, services.RegisterInput{
			Email: email, Password: "LoadTestPass123!", FirstName: "Load", LastName: "Test", Device: "loadtest",
		})
		if err != nil {
			fmt.Fprintf(os.Stderr, "seed user %d: %v\n", i, err)
			os.Exit(1)
		}
		if _, err := moneySvc.Deposit(ctx, user.ID, "NGN", 500_000_00, fmt.Sprintf("loadtest-seed-%s", user.ID)); err != nil {
			fmt.Fprintf(os.Stderr, "seed funding %d: %v\n", i, err)
			os.Exit(1)
		}
		seededUsers[i] = seeded{email: email, userID: user.ID}
	}

	// Workers authenticate via the real login endpoint (bearer flow end-to-end).
	var wg sync.WaitGroup
	agg := &summary{status: map[int]uint64{}, byPath: map[string]map[int]uint64{}}
	start := time.Now()
	for i := 0; i < *users; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			runWorker(ctx, &wg, srv.URL, seededUsers[i].email, fmt.Sprintf("LoadTestPass123!"), *transferDiv, *verbose, start, *duration, agg)
		}(i)
	}
	wg.Wait()
	elapsed := time.Since(start)

	// Report.
	sort.Slice(agg.latencies, func(a, b int) bool { return agg.latencies[a] < agg.latencies[b] })
	lat := agg.latencies
	p50, p95, p99 := pct(lat, 0.50), pct(lat, 0.95), pct(lat, 0.99)
	var maxMs int64
	if len(lat) > 0 {
		maxMs = lat[len(lat)-1]
	}
	rps := float64(agg.reqs) / elapsed.Seconds()
	fmt.Printf("\nloadtest summary (users=%d duration=%s chaos_rate=%.3f chaos_lat=+%dms)\n", *users, *duration, *chaosRate, *chaosLat)
	fmt.Printf("  requests: %d (%.0f req/s over %s)\n", agg.reqs, rps, elapsed.Round(time.Millisecond))
	fmt.Printf("  status:   %v\n", agg.status)
	if *verbose {
		for p, codes := range agg.byPath {
			fmt.Printf("  %s %v\n", p, codes)
		}
	} else {
		for _, p := range []string{"/api/v1/users/me", "/api/v1/money/quote", "/api/v1/money/transfer"} {
			if codes := agg.byPath[p]; len(codes) > 0 {
				fmt.Printf("  %s %v\n", p, codes)
			}
		}
	}
	fmt.Printf("  transfers: %d ok, %d 4xx\n", agg.transferOK, agg.transfer4xx)
	if len(lat) > 0 {
		fmt.Printf("  latency:  p50=%.0fms p95=%.0fms p99=%.0fms max=%dms\n", float64(p50)/1e3, float64(p95)/1e3, float64(p99)/1e3, maxMs)
	} else {
		fmt.Println("  latency:  no successful calls recorded (server down?)")
	}

	os.Exit(checkGate(*maxP95, p95, *chaosRate, agg))
}

func checkGate(maxP95 time.Duration, p95 int64, chaosRate float64, agg *summary) int {
	if agg.reqs == 0 {
		return 1
	}
	if maxP95 > 0 && p95 > int64(maxP95/time.Millisecond) {
		fmt.Printf("FAIL: p95 %.0fms > gate %s\n", float64(p95)/1e3, maxP95)
		return 1
	}
	if chaosRate > 0 {
		failures := agg.status[503] + agg.status[429] + agg.status[500]
		if failures == 0 {
			fmt.Println("FAIL: chaos enabled but no injected failures observed")
			return 1
		}
	}
	return 0
}

// runWorker logs in once, then issues reads + occasional transfers until the
// load window elapses.
func runWorker(ctx context.Context, wg *sync.WaitGroup, baseURL, email, password string, transferDiv int, verbose bool, start time.Time, duration time.Duration, agg *summary) {
	token := login(ctx, baseURL, email, password)
	if token == "" {
		fmt.Fprintln(os.Stderr, "worker login failed")
		return
	}
	client := &http.Client{Timeout: 30 * time.Second}
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	iter := 0
	for {
		if time.Since(start) >= duration {
			return
		}
		select {
		case <-ctx.Done():
			return
		default:
		}
		iter++

		// Read path.
		do(req{method: http.MethodGet, url: baseURL + "/api/v1/users/me", token: token, client: client, agg: agg})

		// Seeded FX book is NGN on one side (migration 0004); quote a seeded pair.
		quote, _ := json.Marshal(map[string]any{"amount": 150_000, "from_currency": "USDT", "to_currency": "NGN"})
		do(req{method: http.MethodPost, url: baseURL + "/api/v1/money/quote", token: token, client: client, agg: agg, body: quote})

		// Every Nth iteration, move money (unique idempotency keys).
		if iter%transferDiv == 0 {
			tr, _ := json.Marshal(map[string]any{"amount": fmt.Sprintf("%d.00", 100+rng.Intn(5000)), "currency": "NGN", "to_kind": "savings"})
			res := do(req{
				method:  http.MethodPost,
				url:     baseURL + "/api/v1/money/transfer",
				token:   token,
				client:  client,
				agg:     agg,
				body:    tr,
				idemKey: fmt.Sprintf("loadtest-%s-%d", tags(email), iter),
			})
			agg.mu.Lock()
			if res >= 200 && res < 300 {
				agg.transferOK++
			} else if res >= 400 && res < 500 {
				agg.transfer4xx++
			}
			agg.mu.Unlock()
		}
	}
}

func tags(email string) string {
	i := strings.IndexByte(email, '@')
	if i < 0 {
		return "u"
	}
	return email[:i]
}

type req struct {
	method, url, token string
	body               []byte
	idemKey            string
	client             *http.Client
	agg                *summary
}

func do(r req) int {
	start := time.Now()
	var reader io.Reader
	if r.body != nil {
		reader = bytes.NewReader(r.body)
	}
	parsed, err := url.Parse(r.url)
	path := ""
	if err == nil {
		path = parsed.Path
	}
	httpReq, err := http.NewRequest(r.method, r.url, reader)
	if err != nil {
		return 0
	}
	httpReq.Header.Set("Authorization", "Bearer "+r.token)
	if r.idemKey != "" {
		httpReq.Header.Set("Idempotency-Key", r.idemKey)
	}
	res, err := r.client.Do(httpReq)
	ms := time.Since(start).Milliseconds()
	if err != nil {
		r.agg.addResult(path, 0, ms)
		return 0
	}
	defer res.Body.Close()
	io.Copy(io.Discard, res.Body)
	r.agg.addResult(path, res.StatusCode, ms)
	return res.StatusCode
}

func login(ctx context.Context, baseURL, email, password string) string {
	body, _ := json.Marshal(map[string]string{"email": email, "password": password})
	res, err := http.Post(baseURL+"/api/v1/auth/login", "application/json", bytes.NewReader(body))
	if err != nil {
		return ""
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return ""
	}
	var auth struct {
		Token       string `json:"token"`
		Requires2FA bool   `json:"requires_2fa"`
	}
	if err := json.NewDecoder(res.Body).Decode(&auth); err != nil || auth.Token == "" {
		return ""
	}
	if auth.Requires2FA {
		return ""
	}
	return auth.Token
}
