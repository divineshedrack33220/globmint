package rates

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestFetch_FailsOverBetweenFeeds(t *testing.T) {
	p := newWithFeeds(nil, 0, []marketFeed{
		func(context.Context, *http.Client) (int64, error) { return 0, errors.New("coingecko down") },
		func(context.Context, *http.Client) (int64, error) { return 160450, nil },
	})
	rate, err := p.fetch(context.Background())
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if rate != 160450 {
		t.Errorf("rate = %d, want 160450", rate)
	}
}

func TestFetch_FirstFeedWins(t *testing.T) {
	p := newWithFeeds(nil, 0, []marketFeed{
		func(context.Context, *http.Client) (int64, error) { return 161000, nil },
		func(context.Context, *http.Client) (int64, error) { return 999999, nil },
	})
	rate, err := p.fetch(context.Background())
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if rate != 161000 {
		t.Errorf("rate = %d, want 161000", rate)
	}
}

func TestFetch_AllFeedsFailed(t *testing.T) {
	p := newWithFeeds(nil, 0, []marketFeed{
		func(context.Context, *http.Client) (int64, error) { return 0, errors.New("a") },
		func(context.Context, *http.Client) (int64, error) { return 0, errors.New("b") },
	})
	if _, err := p.fetch(context.Background()); err == nil {
		t.Fatal("expected an error when every feed fails")
	}
}

// stubTransport serves canned HTTP responses without hitting the network.
type stubTransport struct {
	resp *http.Response
}

func (s *stubTransport) RoundTrip(_ *http.Request) (*http.Response, error) {
	return s.resp, nil
}

func mustClient(t *testing.T, body string) *http.Client {
	t.Helper()
	return &http.Client{
		Transport: &stubTransport{
			resp: &http.Response{
				StatusCode: http.StatusOK,
				Status:     "200 OK",
				Header:     make(http.Header),
				Body:       io.NopCloser(strings.NewReader(body)),
			},
		},
	}
}

func TestFetchCryptoCompare_DecodesKobo(t *testing.T) {
	client := mustClient(t, `{"NGN":1604.50}`)
	rate, err := fetchCryptoCompare(context.Background(), client)
	if err != nil {
		t.Fatalf("fetchCryptoCompare: %v", err)
	}
	if rate != 160450 {
		t.Errorf("rate = %d, want 160450", rate)
	}
}

func TestFetchCryptoCompare_RejectsBadPayload(t *testing.T) {
	client := mustClient(t, `{"NGN":0}`)
	if _, err := fetchCryptoCompare(context.Background(), client); err == nil {
		t.Error("expected an error for a non-positive price")
	}
	client = mustClient(t, `not json`)
	if _, err := fetchCryptoCompare(context.Background(), client); err == nil {
		t.Error("expected an error for invalid json")
	}
}

func TestFetchCoinGecko_DecodesKobo(t *testing.T) {
	client := mustClient(t, `{"usd-coin":{"ngn":1604.5}}`)
	rate, err := fetchCoinGecko(context.Background(), client)
	if err != nil {
		t.Fatalf("fetchCoinGecko: %v", err)
	}
	if rate != 160450 {
		t.Errorf("rate = %d, want 160450", rate)
	}
}