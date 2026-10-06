package services

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// TestWaitlistJoin_AttributionAndDedupe verifies the hardened waitlist path:
// signups carry source/ip_hash/user_agent attribution, never a raw IP, and
// duplicates are idempotent regardless of case (via the email_lower unique
// index installed by migration 0023).
func TestWaitlistJoin_AttributionAndDedupe(t *testing.T) {
	t.Parallel()
	s := testStore(t)
	ctx := context.Background()
	svc := NewWaitlistService(s)

	email := uniqueEmail("waitlist@example.com")
	signup := WaitlistSignup{
		Email:     email,
		Source:    "landing",
		IPHash:    "deadbeef0123456789abcdef",
		UserAgent: "Mozilla/5.0 (test)",
	}

	if err := svc.Join(ctx, signup); err != nil {
		t.Fatalf("first join: %v", err)
	}

	// Mixed-case duplicate must be ignored (email_lower unique index).
	mixed := WaitlistSignup{
		Email:  "WAITLIST." + email[len("waitlist."):],
		IPHash: "abcd",
	}
	if err := svc.Join(ctx, mixed); err != nil {
		t.Fatalf("duplicate join: %v", err)
	}

	dsn := os.Getenv("GLOBMINT_TEST_DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://globmint:globmint_dev@localhost:5434/globmint"
	}
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("open probe pool: %v", err)
	}
	defer pool.Close()

	// Dedupe must collapse to exactly one row for this email, regardless of
	// case, even across concurrent join attempts.
	var gotN int
	if err := pool.QueryRow(ctx,
		`SELECT count(*) FROM waitlist WHERE email_lower = lower($1)`, email,
	).Scan(&gotN); err != nil {
		t.Fatalf("count by email_lower: %v", err)
	}
	if gotN != 1 {
		t.Fatalf("expected 1 waitlist row for %s, got %d", email, gotN)
	}

	var gotEmail, gotSource, gotIPHash, gotUserAgent string
	var gotConfirmed bool
	err = pool.QueryRow(ctx,
		`SELECT email, source, ip_hash, user_agent, confirmed FROM waitlist WHERE email_lower = lower($1)`,
		email,
	).Scan(&gotEmail, &gotSource, &gotIPHash, &gotUserAgent, &gotConfirmed)
	if err != nil {
		t.Fatalf("read back waitlist row: %v", err)
	}
	if gotEmail != email {
		t.Fatalf("email mismatch: %s != %s", gotEmail, email)
	}
	if gotSource != "landing" {
		t.Fatalf("source mismatch: %q != \"landing\"", gotSource)
	}
	if gotIPHash != "deadbeef0123456789abcdef" {
		t.Fatalf("ip_hash mismatch: %q", gotIPHash)
	}
	if gotUserAgent != "Mozilla/5.0 (test)" {
		t.Fatalf("user_agent mismatch: %q", gotUserAgent)
	}
	if gotConfirmed {
		t.Fatalf("confirmed should default to false")
	}
}

// TestWaitlistJoin_DefaultSource verifies the source column defaults to
// "landing" when the caller does not specify one.
func TestWaitlistJoin_DefaultSource(t *testing.T) {
	t.Parallel()
	s := testStore(t)
	ctx := context.Background()
	svc := NewWaitlistService(s)

	email := uniqueEmail("defaultsource@example.com")
	if err := svc.Join(ctx, WaitlistSignup{Email: email, IPHash: "x"}); err != nil {
		t.Fatalf("join: %v", err)
	}

	dsn := os.Getenv("GLOBMINT_TEST_DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://globmint:globmint_dev@localhost:5434/globmint"
	}
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("open probe pool: %v", err)
	}
	defer pool.Close()

	var gotSource string
	if err := pool.QueryRow(ctx,
		`SELECT source FROM waitlist WHERE email = $1`, email,
	).Scan(&gotSource); err != nil {
		t.Fatalf("read back source: %v", err)
	}
	if gotSource != "landing" {
		t.Fatalf("expected default source \"landing\", got %q", gotSource)
	}
}

// TestWaitlistJoin_InvalidEmail verifies validation is still enforced.
func TestWaitlistJoin_InvalidEmail(t *testing.T) {
	t.Parallel()
	s := testStore(t)
	ctx := context.Background()
	svc := NewWaitlistService(s)

	if err := svc.Join(ctx, WaitlistSignup{Email: "not-an-email"}); err == nil {
		t.Fatal("expected error for invalid email, got nil")
	}
}