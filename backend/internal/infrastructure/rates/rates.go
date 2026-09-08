// Package rates fetches a live NGN-per-USDC market rate with short TTL caching
// and a strict local-only guarantee: callers fall back to the seeded rate book
// whenever every market feed is unreachable. Several public feeds are tried in
// order so a single outage never freezes the rate.
package rates

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strings"
	"sync"
	"time"
)

// DefaultTimeout bounds a single upstream fetch.
const DefaultTimeout = 3 * time.Second

// marketFeed pulls the NGN minor price (kobo) of 1 USDC from a single public
// feed. Providers are tried in order until one succeeds.
type marketFeed func(ctx context.Context, client *http.Client) (int64, error)

// Provider returns the NGN price of 1 USDC as NGN minor units (kobo), i.e.
// 132192 for ₦1321.92/USDC, fetched from the configured live feeds. Results
// are cached for CacheTTL.
type Provider struct {
	client   *http.Client
	cacheTTL time.Duration
	feeds    []marketFeed

	mu   sync.Mutex
	rate int64
	at   time.Time
}

// New builds a provider. cacheTTL <= 0 applies a 15s default.
func New(client *http.Client, cacheTTL time.Duration) *Provider {
	if client == nil {
		client = &http.Client{Timeout: DefaultTimeout}
	}
	if cacheTTL <= 0 {
		cacheTTL = 15 * time.Second
	}
	return &Provider{
		client:   client,
		cacheTTL: cacheTTL,
		feeds:    []marketFeed{fetchCoinGecko, fetchCryptoCompare},
	}
}

// newWithFeeds is used by tests to inject deterministic feeds.
func newWithFeeds(client *http.Client, cacheTTL time.Duration, feeds []marketFeed) *Provider {
	p := New(client, cacheTTL)
	if len(feeds) > 0 {
		p.feeds = feeds
	}
	return p
}

// NGNPerUSDCKobo returns the cached or freshly fetched NGN minor rate per USDC.
func (p *Provider) NGNPerUSDCKobo(ctx context.Context) (int64, error) {
	p.mu.Lock()
	if p.at.IsZero() || time.Since(p.at) >= p.cacheTTL {
		if rate, err := p.fetch(ctx); err == nil {
			p.rate = rate
			p.at = time.Now()
		} else {
			// A stale cache is better than none.
			p.mu.Unlock()
			if p.rate > 0 {
				return p.rate, nil
			}
			return 0, err
		}
	}
	r := p.rate
	p.mu.Unlock()
	if r <= 0 {
		return 0, fmt.Errorf("rates: no cached rate available")
	}
	return r, nil
}

// fetch pulls the live USDC/NGN spot price from the configured market feeds in
// order, returning the first success. When every feed fails the aggregated
// errors are returned; upstream keeps pricing from the last good value.
func (p *Provider) fetch(ctx context.Context) (int64, error) {
	var errs []string
	for _, feed := range p.feeds {
		rate, err := feed(ctx, p.client)
		if err != nil {
			errs = append(errs, err.Error())
			continue
		}
		if rate <= 0 {
			errs = append(errs, "feed returned a non-positive rate")
			continue
		}
		return rate, nil
	}
	return 0, fmt.Errorf("rates: all feeds failed: %s", strings.Join(errs, "; "))
}

// fetchCoinGecko pulls the USDC/NGN spot price from CoinGecko's simple/price
// endpoint.
func fetchCoinGecko(ctx context.Context, client *http.Client) (int64, error) {
	type simplePrice struct {
		USDCoin struct {
			NGN float64 `json:"ngn"`
		} `json:"usd-coin"`
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		"https://api.coingecko.com/api/v3/simple/price?ids=usd-coin&vs_currencies=ngn", nil)
	if err != nil {
		return 0, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("rates: coingecko fetch: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("rates: coingecko status %d", resp.StatusCode)
	}
	var out simplePrice
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return 0, fmt.Errorf("rates: coingecko decode: %w", err)
	}
	price := out.USDCoin.NGN
	if price <= 0 {
		return 0, fmt.Errorf("rates: coingecko unusable price %v", price)
	}
	return int64(math.Round(price * 100)), nil
}

// fetchCryptoCompare pulls the USDC/NGN spot price from CryptoCompare's public
// "price" endpoint, which returns a bare currency map, e.g. {"NGN": 1604.50}.
func fetchCryptoCompare(ctx context.Context, client *http.Client) (int64, error) {
	type price struct {
		NGN float64 `json:"NGN"`
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		"https://min-api.cryptocompare.com/data/price?fsym=USDC&tsyms=NGN", nil)
	if err != nil {
		return 0, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("rates: cryptocompare fetch: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("rates: cryptocompare status %d", resp.StatusCode)
	}
	var out price
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return 0, fmt.Errorf("rates: cryptocompare decode: %w", err)
	}
	if out.NGN <= 0 {
		return 0, fmt.Errorf("rates: cryptocompare unusable price %v", out.NGN)
	}
	return int64(math.Round(out.NGN * 100)), nil
}