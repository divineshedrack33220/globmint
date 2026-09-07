// Package rates fetches a live NGN-per-USDC market rate with short TTL caching
// and a strict local-only guarantee: callers fall back to the seeded rate book
// whenever the feed is unreachable.
package rates

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"sync"
	"time"
)

// DefaultTimeout bounds a single upstream fetch.
const DefaultTimeout = 3 * time.Second

// Provider returns the NGN price of 1 USDC as NGN minor units (kobo), i.e.
// 160450 for ₦1604.50/USDC. Results are cached for CacheTTL.
type Provider struct {
	client   *http.Client
	cacheTTL time.Duration

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
	return &Provider{client: client, cacheTTL: cacheTTL}
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

// fetch pulls the live USDC/NGN spot price from CoinGecko's simple/price
// endpoint. This is intentionally the only external dependency of the rate
// layer; swap this method to switch feeds (Binance, oracle, ...).
func (p *Provider) fetch(ctx context.Context) (int64, error) {
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
	resp, err := p.client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("rates: fetch: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("rates: upstream status %d", resp.StatusCode)
	}
	var out simplePrice
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return 0, fmt.Errorf("rates: decode: %w", err)
	}
	price := out.USDCoin.NGN
	if price <= 0 {
		return 0, fmt.Errorf("rates: unusable price %v", price)
	}
	return int64(math.Round(price * 100)), nil
}