package services

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"globmint/backend/internal/domain"
)

// captureMailer records delivered codes so tests can assert the exact payload
// that would reach a user's inbox.
type captureMailer struct {
	mu   sync.Mutex
	sent map[string]string // email -> code
}

func (c *captureMailer) SendOTP(_ context.Context, to, code string) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.sent[to] = code
	return nil
}

func TestEmailOTPRoundTrip(t *testing.T) {
	st := testStore(t)
	mailer := &captureMailer{sent: map[string]string{}}
	svc := NewAuthService(st, time.Hour, "test-session-secret", mailer)
	ctx := context.Background()

	user := newTestUser(t, st, "otp-user@example.com")
	email := user.Email

	// Issue a code.
	if err := svc.SendOTPCode(ctx, email); err != nil {
		t.Fatalf("SendOTPCode: %v", err)
	}
	code, ok := mailer.sent[email]
	if !ok || len(code) != 6 {
		t.Fatalf("expected a 6-digit code delivered by mailer, got %q (delivered=%v)", code, ok)
	}

	// Immediate resend is rate-limited by the cooldown.
	if err := svc.SendOTPCode(ctx, email); !errors.Is(err, domain.ErrOTPCooldown) {
		t.Fatalf("expected cooldown on immediate resend, got %v", err)
	}

	// Wrong code is rejected and burns an attempt.
	if err := svc.VerifyOTPCode(ctx, email, "000000"); !errors.Is(err, domain.ErrInvalidCode) {
		t.Fatalf("expected ErrInvalidCode for wrong code, got %v", err)
	}

	// There is no staged signup for an existing account.
	user2, token, err := svc.CompleteRegistration(ctx, email, code, "test-dev", "127.0.0.1")
	if !errors.Is(err, ErrNoPendingRegistration) {
		t.Fatalf("expected ErrNoPendingRegistration for existing account, got user=%v token=%q err=%v", user2, token, err)
	}

	// Correct code verifies and stamps email_verified_at.
	if err := svc.VerifyOTPCode(ctx, email, code); err != nil {
		t.Fatalf("VerifyOTPCode: %v", err)
	}
	got, err := st.UserRepo().FindByEmail(ctx, email)
	if err != nil {
		t.Fatalf("FindByEmail: %v", err)
	}
	if got.EmailVerifiedAt == nil {
		t.Fatal("expected EmailVerifiedAt to be set after verification")
	}

	// Code is single-use: a replay finds nothing outstanding.
	if err := svc.VerifyOTPCode(ctx, email, code); !errors.Is(err, domain.ErrOTPNotFound) {
		t.Fatalf("expected single-use code to be cleared, got %v", err)
	}

	// Unknown email can still receive a code…
	anonEmail := uniqueEmail("anon-otp@example.com")
	if err := svc.SendOTPCode(ctx, anonEmail); err != nil {
		t.Fatalf("send to unknown email: %v", err)
	}
	// …but has no staged signup, so verification leaves it un-created and fails.
	anonCode, _ := mailer.sent[anonEmail]
	_, _, cerr := svc.CompleteRegistration(ctx, anonEmail, anonCode, "", "")
	if !errors.Is(cerr, ErrNoPendingRegistration) {
		t.Fatalf("expected ErrNoPendingRegistration for staged-less email, got %v", cerr)
	}
}

// TestOTPStagedRegistration is the core guarantee: signup data is never
// persisted as a user until the emailed code is verified, and verification
// creates a fully-verified account with first session + PIN-less welcome.
func TestOTPStagedRegistration(t *testing.T) {
	st := testStore(t)
	mailer := &captureMailer{sent: map[string]string{}}
	svc := NewAuthService(st, time.Hour, "test-session-secret", mailer)
	ctx := context.Background()

	email := uniqueEmail("staged@example.com")

	// Nothing exists yet that looks like an account.
	if _, err := st.UserRepo().FindByEmail(ctx, email); !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("expected no user before registration, got %v", err)
	}

	resendAfter, err := svc.StageRegistration(ctx, RegisterInput{
		Email: email, Password: "SuperSecret123!", FirstName: "Ada", LastName: "Okafor", Phone: "+2348000000000",
	})
	if err != nil {
		t.Fatalf("StageRegistration: %v", err)
	}
	if !time.Now().Before(resendAfter) {
		t.Fatalf("expected a future resend_after, got %v", resendAfter)
	}
	code, ok := mailer.sent[email]
	if !ok || len(code) != 6 {
		t.Fatalf("expected a 6-digit code delivered by mailer, got %q", code)
	}

	// Staging must still not create a user row.
	if _, err := st.UserRepo().FindByEmail(ctx, email); !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("expected user to remain uncreated until verification, got %v", err)
	}

	// A resend keeps the staged payload but blocks while the cooldown is hot.
	if _, err := svc.StageRegistration(ctx, RegisterInput{
		Email: email, Password: "SuperSecret123!", FirstName: "Ada", LastName: "Okafor",
	}); !errors.Is(err, domain.ErrOTPCooldown) {
		t.Fatalf("expected cooldown on re-stage, got %v", err)
	}

	// Wrong code must not create the account either.
	if _, _, err := svc.CompleteRegistration(ctx, email, "000000", "dev", "127.0.0.1"); !errors.Is(err, domain.ErrInvalidCode) {
		t.Fatalf("expected ErrInvalidCode before creation, got %v", err)
	}
	if _, err := st.UserRepo().FindByEmail(ctx, email); !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("expected user to remain uncreated after failed code, got %v", err)
	}

	// Correct code creates the account atomically.
	user, token, err := svc.CompleteRegistration(ctx, email, code, "test-device", "127.0.0.1")
	if err != nil {
		t.Fatalf("CompleteRegistration: %v", err)
	}
	if token == "" {
		t.Fatal("expected a session token after registration")
	}
	if user.FirstName != "Ada" || user.LastName != "Okafor" || user.Phone != "+2348000000000" {
		t.Fatalf("staged profile not carried over: %+v", user)
	}
	if user.EmailVerifiedAt == nil {
		t.Fatal("expected email_verified_at to be set on registration")
	}
	got, err := st.UserRepo().FindByEmail(ctx, email)
	if err != nil {
		t.Fatalf("expected user to exist after verification: %v", err)
	}
	if got.EmailVerifiedAt == nil {
		t.Fatal("expected persisted user to have email_verified_at set")
	}
	if got.PasswordHash == "" || got.PasswordHash == "SuperSecret123!" {
		t.Fatal("expected a bcrypt-hashed password")
	}

	// The issued token authenticates.
	auth, err := svc.Authenticate(ctx, token)
	if err != nil || auth == nil || auth.ID != user.ID {
		t.Fatalf("expected the issued token to authenticate, err=%v", err)
	}

	// Code is single-use: a replay finds nothing outstanding.
	if _, _, err := svc.CompleteRegistration(ctx, email, code, "", ""); !errors.Is(err, domain.ErrOTPNotFound) {
		t.Fatalf("expected single-use code to be cleared after registration, got %v", err)
	}

	// Re-staging an address that now has an account is rejected.
	if _, err := svc.StageRegistration(ctx, RegisterInput{
		Email: email, Password: "SuperSecret123!", FirstName: "A", LastName: "B",
	}); !errors.Is(err, domain.ErrDuplicateEmail) {
		t.Fatalf("expected ErrDuplicateEmail for registered address, got %v", err)
	}
}
