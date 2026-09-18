package services

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/bcrypt"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/events"
	"globmint/backend/internal/infrastructure/mailer"
	"globmint/backend/internal/observability"
	"globmint/backend/internal/storage"
)

// AuthService handles registration, authentication, and session management.
// Passwords are hashed with bcrypt and never stored in plaintext; session
// tokens are random, issued to the client once, and stored only as SHA-256
// hashes.
type AuthService struct {
	store        store
	sessionTTL   time.Duration
	challengeKey []byte
	otpSender    OTPMailer

	// AlertMailer delivers security-notification email (new sign-in, failed
	// sign-in). Set by the server bootstrap; the no-op console sender when
	// unset (dev/tests).
	AlertMailer mailer.Sender
	// SecurityHub fans security events out to SSE subscribers. Nil in tests.
	SecurityHub *events.Hub

	mu       sync.Mutex
	attempts map[string]*attemptWindow // key: "login:<sha256(email)>" or "pin:<userID>"

	// lastAlertAt dedupes security-alert email to at most one per hour per
	// user per type ("new_signin" | "failed_login").
	alertMu   sync.Mutex
	lastAlert map[string]time.Time
}

type attemptWindow struct {
	count int
	reset time.Time
}

// OTPMailer delivers one-time codes by email. Satisfied by the Resend-backed
// sender (infrastructure/mailer) in production and by the console fallback in
// dev; loadtest supplies a no-op.
type OTPMailer interface {
	SendOTP(ctx context.Context, to, code string) error
}

const (
	loginMaxAttempts = 5
	attemptWindowDur = 15 * time.Minute
	pinMaxAttempts   = 5
	totpChallengeTTL = 5 * time.Minute
	// alertDedupe is the minimum gap between two emails of the same alert type
	// sent to the same account.
	alertDedupe = time.Hour

	// Email OTP policy: 6 digits, 10-minute validity, 60s resend cooldown,
	// 5 verify attempts before the code is voided.
	otpDigits     = 6
	otpTTL        = 10 * time.Minute
	otpCooldown   = 60 * time.Second
	otpMaxAttempt = 5
)

func NewAuthService(store store, sessionTTL time.Duration, sessionSecret string, otpSender OTPMailer) *AuthService {
	if sessionSecret == "" {
		sessionSecret = "dev-only-change-me-session-secret-0000000000"
	}
	return &AuthService{
		store:        store,
		sessionTTL:   sessionTTL,
		challengeKey: []byte(sessionSecret),
		otpSender:    otpSender,
		attempts:     map[string]*attemptWindow{},
		lastAlert:    map[string]time.Time{},
	}
}

// VerifyPassword checks a plaintext password against the stored bcrypt hash.
func (s *AuthService) VerifyPassword(user *domain.User, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)) == nil
}

// SetPIN hashes and stores a user's transaction PIN.
func (s *AuthService) SetPIN(ctx context.Context, userID, pin string) error {
	if len(pin) != 6 {
		return domain.ErrInvalidPin
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(pin), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	return s.store.UserRepo().UpdatePIN(ctx, userID, string(hash))
}

// HasPIN reports whether the user has a transaction PIN set.
func (s *AuthService) HasPIN(ctx context.Context, userID string) (bool, error) {
	user, err := s.store.UserRepo().FindByID(ctx, userID)
	if err != nil {
		return false, err
	}
	return user.PINHash != "", nil
}

// VerifyPIN checks a supplied PIN against the stored hash.
func (s *AuthService) VerifyPIN(ctx context.Context, userID, pin string) error {
	if len(pin) != 6 {
		return domain.ErrInvalidPin
	}
	user, err := s.store.UserRepo().FindByID(ctx, userID)
	if err != nil {
		return err
	}
	if user.PINHash == "" || bcrypt.CompareHashAndPassword([]byte(user.PINHash), []byte(pin)) != nil {
		return domain.ErrInvalidPin
	}
	return nil
}

var emailRe = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

// RegisterInput carries registration data.
type RegisterInput struct {
	Email     string
	Phone     string
	FirstName string
	LastName  string
	Password  string
	Device    string
	IP        string
}

// pendingRegistration is the staged signup payload held on an email_otps row
// until the user proves email ownership with the delivered code. No account
// record is ever written for a signup that never verifies.
type pendingRegistration struct {
	FirstName    string
	LastName     string
	Phone        string
	PasswordHash string
}

// StageRegistration records a signup payload and delivers a verification code
// WITHOUT creating an account. The account (and its first session) is only
// materialized when CompleteRegistration later confirms email ownership, so a
// user row cannot exist before its email is verified. Returns resendAfter, the
// earliest time a fresh code may be requested under the per-email cooldown.
func (s *AuthService) StageRegistration(ctx context.Context, req RegisterInput) (resendAfter time.Time, err error) {
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if !emailRe.MatchString(email) {
		return time.Time{}, domain.ErrBadRequest
	}
	if len(req.Password) < 8 {
		return time.Time{}, domain.ErrBadRequest
	}
	if _, err := s.store.UserRepo().FindByEmail(ctx, email); err == nil {
		return time.Time{}, domain.ErrDuplicateEmail
	} else if !errors.Is(err, domain.ErrNotFound) {
		return time.Time{}, err
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return time.Time{}, err
	}
	_, resendAfter, err = s.issueAndSendOTP(ctx, email, &pendingRegistration{
		FirstName:    req.FirstName,
		LastName:     req.LastName,
		Phone:        req.Phone,
		PasswordHash: string(hash),
	})
	if err != nil {
		return time.Time{}, err
	}
	return resendAfter, nil
}

// ErrNoPendingRegistration is returned by CompleteRegistration when the email
// holds a valid code but no staged signup (e.g. a code issued only to verify an
// existing account). The HTTP layer then falls back to plain email verification.
var ErrNoPendingRegistration = errors.New("no pending registration for this email")

// CompleteRegistration turns a verified OTP for a staged signup into a real
// account: it validates the code, creates the user from the staged profile with
// email_verified_at already stamped, provisions default accounts, issues a
// session, and clears the code. A user row is never written unless the code
// verifies.
func (s *AuthService) CompleteRegistration(ctx context.Context, email, code, device, ip string) (user *domain.User, token string, err error) {
	email = strings.ToLower(strings.TrimSpace(email))
	if !emailRe.MatchString(email) {
		return nil, "", domain.ErrInvalidCode
	}
	otp, err := s.fetchAndValidateOTP(ctx, email, code)
	if err != nil {
		return nil, "", err
	}
	if otp.PasswordHash == "" {
		return nil, "", ErrNoPendingRegistration
	}

	now := time.Now()
	user = &domain.User{
		Email:           email,
		Phone:           otp.Phone,
		FirstName:       otp.FirstName,
		LastName:        otp.LastName,
		PasswordHash:    otp.PasswordHash,
		Status:          domain.UserStatusActive,
		EmailVerifiedAt: &now,
	}
	if err := s.store.RunInTx(ctx, func(store storage.Store) error {
		if err := store.UserRepo().Create(ctx, user); err != nil {
			return err
		}
		if err := store.AccountRepo().EnsureDefaultAccounts(ctx, user.ID); err != nil {
			return err
		}
		_ = store.EmailOTPRepo().Clear(ctx, email)
		return nil
	}); err != nil {
		return nil, "", err
	}

	token, err = s.issueSession(ctx, user.ID, device, ip)
	if err != nil {
		return nil, "", err
	}
	s.recordSecurity(ctx, user.ID, domain.SecurityEventRegister, "Account created", "Welcome to Globmint", ip, device)
	_ = s.store.NotificationRepo().Create(ctx, &domain.Notification{
		UserID:   user.ID,
		Category: domain.NotificationCategoryGeneral,
		Title:    "Welcome to Globmint",
		Body:     "Your digital savings vault is ready.",
	})
	return user, token, nil
}

// LoginResult carries the outcome of a credential login. When 2FA is enabled
// for the account, Requires2FA is true and ChallengeToken must be exchanged
// via Verify2FA before a session is issued.
type LoginResult struct {
	User           *domain.User
	Token          string
	Requires2FA    bool
	ChallengeToken string
}

// Login authenticates credentials and returns a session (or a 2FA challenge).
func (s *AuthService) Login(ctx context.Context, email, password, device, ip string) (*LoginResult, error) {
	failKey := "login:" + emailHashKey(email)
	user, err := s.store.UserRepo().FindByEmail(ctx, strings.ToLower(strings.TrimSpace(email)))
	if errors.Is(err, domain.ErrNotFound) {
		observability.Default.LoginFailure()
		s.noteFailure(failKey)
		if s.isThrottled(failKey, loginMaxAttempts) {
			return nil, domain.ErrTooManyAttempts
		}
		return nil, domain.ErrInvalidCredentials
	}
	if err != nil {
		return nil, err
	}
	if user.Status == domain.UserStatusLocked || user.Status == domain.UserStatusSuspended {
		return nil, domain.ErrUserLocked
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)) != nil {
		observability.Default.LoginFailure()
		s.noteFailure(failKey)
		s.recordLoginFailure(ctx, user, device, ip, "bad_password")
		if s.isThrottled(failKey, loginMaxAttempts) {
			s.recordThrottle(ctx, user, device, ip)
			s.sendFailedLoginAlert(ctx, user, ip)
			return nil, domain.ErrTooManyAttempts
		}
		return nil, domain.ErrInvalidCredentials
	}
	s.clearFailure(failKey)

	if user.TOTPEnabled {
		s.recordEvent(ctx, &domain.SecurityEvent{
			UserID: user.ID, Type: domain.SecurityEventTwoFactor, Severity: domain.SeverityInfo,
			Title: "Two-factor challenge issued", Detail: "Signing in requires your authenticator code",
			IP: ip, UserAgent: device, Device: device, Metadata: map[string]any{"outcome": "issued"},
		})
		return &LoginResult{
			User:           user,
			Requires2FA:    true,
			ChallengeToken: s.newChallenge(user.ID),
		}, nil
	}

	token, err := s.issueSession(ctx, user.ID, device, ip)
	if err != nil {
		return nil, err
	}
	s.recordLoginSuccess(ctx, user, device, ip, "password")
	return &LoginResult{User: user, Token: token}, nil
}

// Verify2FA completes a login that required a TOTP code, issuing a session.
func (s *AuthService) Verify2FA(ctx context.Context, challengeToken, code, device, ip string) (*LoginResult, error) {
	userID, err := s.verifyChallenge(challengeToken)
	if err != nil {
		s.recordEvent(ctx, &domain.SecurityEvent{
			UserID: userID, Type: domain.SecurityEventTwoFactor, Severity: domain.SeverityWarn,
			Title: "Two-factor challenge rejected", Detail: "An invalid or expired 2FA challenge was presented",
			IP: ip, UserAgent: device, Device: device, Metadata: map[string]any{"outcome": "challenge_rejected"},
		})
		return nil, err
	}
	user, err := s.store.UserRepo().FindByID(ctx, userID)
	if err != nil {
		return nil, domain.ErrTwoFactorInvalid
	}
	if !user.TOTPEnabled || user.TOTPSecret == "" {
		return nil, domain.ErrTwoFactorInvalid
	}
	if !verifyTOTP(user.TOTPSecret, code) {
		s.recordEvent(ctx, &domain.SecurityEvent{
			UserID: userID, Type: domain.SecurityEventTwoFactor, Severity: domain.SeverityWarn,
			Title: "Two-factor code rejected", Detail: "An incorrect authenticator code was submitted",
			IP: ip, UserAgent: device, Device: device, Metadata: map[string]any{"outcome": "failed"},
		})
		return nil, domain.ErrInvalidCode
	}
	s.clearFailure("login:" + emailHashKey(user.Email))
	token, err := s.issueSession(ctx, user.ID, device, ip)
	if err != nil {
		return nil, err
	}
	s.recordLoginSuccess(ctx, user, device, ip, "two_factor")
	return &LoginResult{User: user, Token: token}, nil
}

// GenerateTOTP provisions a new TOTP secret and returns it with a provisioning
// URI for the authenticator app. The secret is stored but not yet enabled.
func (s *AuthService) GenerateTOTP(ctx context.Context, userID, email string) (secret, uri string, err error) {
	user, err := s.store.UserRepo().FindByID(ctx, userID)
	if err != nil {
		return "", "", err
	}
	if user.TOTPEnabled {
		return "", "", domain.ErrConflict
	}
	secret, err = generateTOTPSecret()
	if err != nil {
		return "", "", err
	}
	if err := s.store.UserRepo().UpdateTOTP(ctx, userID, secret, false); err != nil {
		return "", "", err
	}
	return secret, totpURI(secret, email, "Globmint"), nil
}

// EnableTOTP activates 2FA after the user proves they hold the key.
func (s *AuthService) EnableTOTP(ctx context.Context, userID, code string) error {
	user, err := s.store.UserRepo().FindByID(ctx, userID)
	if err != nil {
		return err
	}
	if user.TOTPSecret == "" {
		return domain.ErrBadRequest
	}
	if !verifyTOTP(user.TOTPSecret, code) {
		return domain.ErrInvalidCode
	}
	if err := s.store.UserRepo().UpdateTOTP(ctx, userID, user.TOTPSecret, true); err != nil {
		return err
	}
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID: userID, Type: domain.SecurityEventTwoFactor, Severity: domain.SeverityInfo,
		Title: "Two-factor enabled", Detail: "Authenticator app linked to this account",
		Metadata: map[string]any{"outcome": "enabled"},
	})
	return nil
}

// DisableTOTP turns off 2FA, requiring the PIN and a valid code.
func (s *AuthService) DisableTOTP(ctx context.Context, userID, pin, code string) error {
	if err := s.VerifyPIN(ctx, userID, pin); err != nil {
		return err
	}
	user, err := s.store.UserRepo().FindByID(ctx, userID)
	if err != nil {
		return err
	}
	if user.TOTPSecret == "" || !verifyTOTP(user.TOTPSecret, code) {
		return domain.ErrInvalidCode
	}
	if err := s.store.UserRepo().UpdateTOTP(ctx, userID, user.TOTPSecret, false); err != nil {
		return err
	}
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID: userID, Type: domain.SecurityEventTwoFactor, Severity: domain.SeverityInfo,
		Title: "Two-factor disabled", Detail: "Authenticator app unlinked from this account",
		Metadata: map[string]any{"outcome": "disabled"},
	})
	return nil
}

// ChangePassword verifies the current password, stores a new hash, and revokes
// every session except the one that requested the change.
func (s *AuthService) ChangePassword(ctx context.Context, userID, current, next, keepSessionID string) error {
	if len(next) < 8 {
		return domain.ErrBadRequest
	}
	user, err := s.store.UserRepo().FindByID(ctx, userID)
	if err != nil {
		return err
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(current)) != nil {
		return domain.ErrInvalidCredentials
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(next), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	if err := s.store.UserRepo().UpdatePassword(ctx, userID, string(hash)); err != nil {
		return err
	}
	if err := s.store.SessionRepo().RevokeAllExcept(ctx, userID, keepSessionID); err != nil {
		return err
	}
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID: userID, Type: domain.SecurityEventPassword, Severity: domain.SeverityInfo,
		Title: "Password changed", Detail: "Your password was updated",
	})
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID: userID, Type: domain.SecurityEventSessionRevoked, Severity: domain.SeverityCritical,
		Title: "Other sessions revoked", Detail: "A password change signed every other device out",
	})
	return nil
}

// SendOTPCode issues a short-lived email verification code to the supplied
// address and delivers it via the configured mailer. Enforces a per-email
// resend cooldown and caps outstanding attempts so the endpoint cannot be
// abused to spam a mailbox. The code is stored only as a hash. A resend never
// wipes a staged (but unverified) registration payload on the same row.
func (s *AuthService) SendOTPCode(ctx context.Context, email string) error {
	email = strings.ToLower(strings.TrimSpace(email))
	if !emailRe.MatchString(email) {
		return domain.ErrBadRequest
	}
	if _, _, err := s.issueAndSendOTP(ctx, email, nil); err != nil {
		return err
	}
	if user, uerr := s.store.UserRepo().FindByEmail(ctx, email); uerr == nil {
		s.recordEvent(ctx, &domain.SecurityEvent{
			UserID: user.ID, Type: domain.SecurityEventRecovery, Severity: domain.SeverityInfo,
			Title: "Verification code sent", Detail: "A one-time code was emailed to the account address",
		})
	}
	return nil
}

// issueAndSendOTP enforces the per-email resend cooldown and attempt cap,
// stores a fresh code hash (optionally alongside a staged registration
// payload), and delivers the code. It returns the code and the earliest time a
// new code may be requested.
func (s *AuthService) issueAndSendOTP(ctx context.Context, email string, reg *pendingRegistration) (string, time.Time, error) {
	existing, err := s.store.EmailOTPRepo().FindByEmail(ctx, email)
	if err != nil && !errors.Is(err, domain.ErrNotFound) {
		return "", time.Time{}, err
	}
	if existing != nil {
		if existing.NextSendAt != nil && time.Now().Before(*existing.NextSendAt) {
			return "", time.Time{}, domain.ErrOTPCooldown
		}
		if existing.Attempts >= otpMaxAttempt {
			return "", time.Time{}, domain.ErrTooManyAttempts
		}
	}

	code, err := generateOTP(otpDigits)
	if err != nil {
		return "", time.Time{}, err
	}

	next := time.Now().Add(otpCooldown)
	otp := &domain.EmailOTP{
		Email:      email,
		CodeHash:   hashOTP(code),
		ExpiresAt:  time.Now().Add(otpTTL),
		NextSendAt: &next,
	}
	if reg != nil {
		otp.FirstName, otp.LastName, otp.Phone, otp.PasswordHash =
			reg.FirstName, reg.LastName, reg.Phone, reg.PasswordHash
	}
	if err := s.store.EmailOTPRepo().Upsert(ctx, otp); err != nil {
		return "", time.Time{}, err
	}

	if s.otpSender != nil {
		if err := s.otpSender.SendOTP(ctx, email, code); err != nil {
			return "", time.Time{}, err
		}
	} else {
		log.Printf("auth: otp for %s -> %s (no mailer configured)", code, email)
	}
	return code, next, nil
}

// fetchAndValidateOTP loads the outstanding code for an email and checks the
// supplied value against it, enforcing expiry, the brute-force attempt cap, and
// single-use semantics. On success the code row is left in place for the caller
// to complete against; failed/expired/exhausted states may clear it.
func (s *AuthService) fetchAndValidateOTP(ctx context.Context, email, code string) (*domain.EmailOTP, error) {
	if len(code) != otpDigits {
		return nil, domain.ErrInvalidCode
	}
	otp, err := s.store.EmailOTPRepo().FindByEmail(ctx, email)
	if errors.Is(err, domain.ErrNotFound) {
		return nil, domain.ErrOTPNotFound
	}
	if err != nil {
		return nil, err
	}
	if time.Now().After(otp.ExpiresAt) {
		_ = s.store.EmailOTPRepo().Clear(ctx, email)
		return nil, domain.ErrOTPExpired
	}
	if otp.Attempts >= otpMaxAttempt {
		_ = s.store.EmailOTPRepo().Clear(ctx, email)
		return nil, domain.ErrTooManyAttempts
	}
	if !secureEqual(otp.CodeHash, hashOTP(code)) {
		_ = s.store.EmailOTPRepo().IncrementAttempts(ctx, email)
		return nil, domain.ErrInvalidCode
	}
	return otp, nil
}

// VerifyOTPCode validates a submitted code against the issued hash, marking the
// email verified on success. Used for accounts that already exist (no staged
// signup); registration flows go through CompleteRegistration instead.
func (s *AuthService) VerifyOTPCode(ctx context.Context, email, code string) error {
	email = strings.ToLower(strings.TrimSpace(email))
	if !emailRe.MatchString(email) {
		return domain.ErrInvalidCode
	}
	if _, err := s.fetchAndValidateOTP(ctx, email, code); err != nil {
		return err
	}
	user, err := s.store.UserRepo().FindByEmail(ctx, email)
	if err != nil {
		_ = s.store.EmailOTPRepo().Clear(ctx, email)
		return domain.ErrOTPNotFound
	}
	_ = s.store.EmailOTPRepo().Clear(ctx, email)
	if err := s.store.UserRepo().MarkEmailVerified(ctx, user.ID); err != nil && !errors.Is(err, domain.ErrNotFound) {
		return err
	}
	s.recordSecurity(ctx, user.ID, domain.SecurityEventRegister, "Email verified", "Ownership of the account email was confirmed with a one-time code", "", "")
	return nil
}

// generateOTP returns a cryptographically random numeric code of length n.
func generateOTP(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	for i := range buf {
		buf[i] = '0' + buf[i]%10
	}
	return string(buf), nil
}

// hashOTP returns the hex SHA-256 of a code. Only the hash is persisted.
func hashOTP(code string) string {
	sum := sha256.Sum256([]byte(code))
	return hex.EncodeToString(sum[:])
}

// secureEqual compares two code hashes in constant time.
func secureEqual(a, b string) bool {
	return hmac.Equal([]byte(a), []byte(b))
}

// VerifyPINThrottled verifies the PIN with brute-force throttling. Used for the
// dedicated /pin/verify gate (and PIN changes); withdrawals still call
// VerifyPIN directly so a mistyped PIN never blocks a payout.
func (s *AuthService) VerifyPINThrottled(ctx context.Context, userID, pin string) error {
	failKey := "pin:" + userID
	if s.isThrottled(failKey, pinMaxAttempts) {
		return domain.ErrTooManyAttempts
	}
	if err := s.VerifyPIN(ctx, userID, pin); err != nil {
		s.noteFailure(failKey)
		return err
	}
	s.clearFailure(failKey)
	return nil
}

// newChallenge issues a short-lived, HMAC-signed 2FA challenge for a user.
func (s *AuthService) newChallenge(userID string) string {
	payload := fmt.Sprintf("%s|%d", userID, time.Now().Add(totpChallengeTTL).Unix())
	mac := hmac.New(sha256.New, s.challengeKey)
	_, _ = mac.Write([]byte(payload))
	return base64.RawURLEncoding.EncodeToString([]byte(payload + "|" + hex.EncodeToString(mac.Sum(nil))))
}

// verifyChallenge validates a 2FA challenge token and returns the user ID.
func (s *AuthService) verifyChallenge(token string) (string, error) {
	if token == "" {
		return "", domain.ErrTwoFactorInvalid
	}
	raw, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return "", domain.ErrTwoFactorInvalid
	}
	parts := strings.Split(string(raw), "|")
	if len(parts) != 3 {
		return "", domain.ErrTwoFactorInvalid
	}
	payload := parts[0] + "|" + parts[1]
	mac := hmac.New(sha256.New, s.challengeKey)
	_, _ = mac.Write([]byte(payload))
	want := hex.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(want), []byte(parts[2])) {
		return "", domain.ErrTwoFactorInvalid
	}
	exp, err := strconv.ParseInt(parts[1], 10, 64)
	if err != nil || time.Now().Unix() > exp {
		return "", domain.ErrTwoFactorInvalid
	}
	return parts[0], nil
}

func emailHashKey(email string) string {
	sum := sha256.Sum256([]byte(strings.ToLower(strings.TrimSpace(email))))
	return hex.EncodeToString(sum[:])
}

func (s *AuthService) noteFailure(key string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	w := s.attempts[key]
	if w == nil || now.After(w.reset) {
		s.attempts[key] = &attemptWindow{count: 1, reset: now.Add(attemptWindowDur)}
		return
	}
	w.count++
}

func (s *AuthService) isThrottled(key string, max int) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	w := s.attempts[key]
	if w == nil {
		return false
	}
	if time.Now().After(w.reset) {
		delete(s.attempts, key)
		return false
	}
	return w.count > max
}

func (s *AuthService) clearFailure(key string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.attempts, key)
}

// Authenticate validates a bearer token and returns the owning user.
func (s *AuthService) Authenticate(ctx context.Context, token string) (*domain.User, error) {
	hash := tokenHash(token)
	sess, err := s.store.SessionRepo().FindByTokenHash(ctx, hash)
	if errors.Is(err, domain.ErrNotFound) {
		return nil, domain.ErrInvalidToken
	}
	if err != nil {
		return nil, err
	}
	if sess.RevokedAt != nil || time.Now().After(sess.ExpiresAt) {
		return nil, domain.ErrInvalidToken
	}
	user, err := s.store.UserRepo().FindByID(ctx, sess.UserID)
	if err != nil {
		return nil, err
	}
	if user.Status == domain.UserStatusSuspended || user.Status == domain.UserStatusLocked {
		return nil, domain.ErrUserLocked
	}
	_ = s.store.SessionRepo().TouchLastActive(ctx, sess.ID)
	return user, nil
}

// Logout revokes the session identified by the raw token.
func (s *AuthService) Logout(ctx context.Context, token string) error {
	sess, err := s.store.SessionRepo().FindByTokenHash(ctx, tokenHash(token))
	if errors.Is(err, domain.ErrNotFound) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := s.store.SessionRepo().Revoke(ctx, sess.ID); err != nil {
		return err
	}
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID: sess.UserID, Type: domain.SecurityEventLogout, Severity: domain.SeverityInfo,
		Title: "Signed out", Detail: "You signed out of this device",
		IP: sess.IP, UserAgent: sess.Device, Device: sess.Device,
	})
	return nil
}

// CurrentSessionID resolves the session ID for a raw token, or "" when the
// token does not map to a valid session. Used to identify the "current" device.
func (s *AuthService) CurrentSessionID(ctx context.Context, token string) string {
	if token == "" {
		return ""
	}
	sess, err := s.store.SessionRepo().FindByTokenHash(ctx, tokenHash(token))
	if err != nil {
		return ""
	}
	return sess.ID
}

// recordSecurity appends a security event. Failures are intentionally ignored
// so that an audit-log write never fails the primary auth operation.
func (s *AuthService) recordSecurity(ctx context.Context, userID string, etype domain.SecurityEventType, title, detail, ip, device string) {
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID:   userID,
		Type:     etype,
		Severity: domain.SeverityInfo,
		Title:    title,
		Detail:   detail,
		IP:       ip,
		Device:   device,
	})
}

// recordEvent appends a security event (best-effort; an audit write must never
// fail the primary auth operation) and pushes an SSE refresh so open security
// centers update.
func (s *AuthService) recordEvent(ctx context.Context, ev *domain.SecurityEvent) {
	if ev.Severity == "" {
		ev.Severity = domain.SeverityInfo
	}
	_ = s.store.SecurityEventRepo().Create(ctx, ev)
	s.publishSecurity(ev.UserID)
}

func (s *AuthService) publishSecurity(userID string) {
	if s.SecurityHub == nil {
		return
	}
	s.SecurityHub.Publish(events.Event{
		Type: "data.changed", UserID: userID, Kind: "security", At: time.Now().UTC().Format(time.RFC3339),
	})
}

// recordLoginSuccess logs a successful sign-in and, when the device was not
// seen in the trailing 30 days, a new-device event plus an alert email.
func (s *AuthService) recordLoginSuccess(ctx context.Context, user *domain.User, device, ip, via string) {
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID: user.ID, Type: domain.SecurityEventLogin, Severity: domain.SeverityInfo,
		Title: "Signed in", Detail: "Signed in to your account",
		IP: ip, UserAgent: device, Device: device, Metadata: map[string]any{"via": via},
	})
	recent, err := s.store.SessionRepo().CountRecentByDevice(ctx, user.ID, device, time.Now().Add(-30*24*time.Hour))
	if err != nil || recent > 1 {
		return
	}
	// recent==1 is only the session created by this login — a first-seen device.
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID: user.ID, Type: domain.SecurityEventNewDevice, Severity: domain.SeverityInfo,
		Title: "New device sign-in", Detail: "Signed in from a device not seen in the last 30 days",
		IP: ip, UserAgent: device, Device: device,
	})
	s.sendNewSignInAlert(ctx, user, device, ip)
}

// recordLoginFailure logs an incorrect-credential attempt.
func (s *AuthService) recordLoginFailure(ctx context.Context, user *domain.User, device, ip, reason string) {
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID: user.ID, Type: domain.SecurityEventLoginFailed, Severity: domain.SeverityWarn,
		Title: "Failed sign-in attempt", Detail: "An incorrect password was submitted for this account",
		IP: ip, UserAgent: device, Device: device, Metadata: map[string]any{"reason": reason},
	})
}

// recordThrottle logs the temporary sign-in lockout reached after repeated
// failures.
func (s *AuthService) recordThrottle(ctx context.Context, user *domain.User, device, ip string) {
	s.recordEvent(ctx, &domain.SecurityEvent{
		UserID: user.ID, Type: domain.SecurityEventThrottle, Severity: domain.SeverityWarn,
		Title: "Sign-in locked out", Detail: "Repeated failed attempts temporarily locked sign-in for this account",
		IP: ip, UserAgent: device, Device: device, Metadata: map[string]any{"locked_for_seconds": int(attemptWindowDur.Seconds())},
	})
}

// sendNewSignInAlert emails the user about the first-seen device, respecting
// their stored notification preference and deduping to once per hour. Failures
// are swallowed so an alert never breaks the login.
func (s *AuthService) sendNewSignInAlert(ctx context.Context, user *domain.User, device, ip string) {
	if s.AlertMailer == nil || !s.notificationsOn(ctx, user, "new_signin") || !s.dedupeAlert(user.ID, "new_signin") {
		return
	}
	_ = s.AlertMailer.SendNewSignIn(ctx, user.Email, deviceName(device), ip, time.Now().UTC().Format(time.RFC3339))
}

// sendFailedLoginAlert emails the user after repeated failed attempts.
func (s *AuthService) sendFailedLoginAlert(ctx context.Context, user *domain.User, ip string) {
	if s.AlertMailer == nil || !s.notificationsOn(ctx, user, "failed_login") || !s.dedupeAlert(user.ID, "failed_login") {
		return
	}
	_ = s.AlertMailer.SendFailedSignIn(ctx, user.Email, ip, time.Now().UTC().Format(time.RFC3339))
}

// notificationsOn reads the account's email-alert preference for the given
// bucket. Opted-out users get fewer emails but never lose feed events; a read
// failure defaults to ON.
func (s *AuthService) notificationsOn(ctx context.Context, user *domain.User, bucket string) bool {
	newSigninOn, failedLoginOn, err := s.store.UserRepo().NotificationPrefs(ctx, user.ID)
	if err != nil {
		return true
	}
	if bucket == "failed_login" {
		return failedLoginOn
	}
	return newSigninOn
}

// dedupeAlert returns true when no alert of this type has gone out to the user
// in the last hour.
func (s *AuthService) dedupeAlert(userID, typ string) bool {
	key := userID + ":" + typ
	s.alertMu.Lock()
	defer s.alertMu.Unlock()
	if last, ok := s.lastAlert[key]; ok && time.Since(last) < alertDedupe {
		return false
	}
	s.lastAlert[key] = time.Now()
	return true
}

func (s *AuthService) issueSession(ctx context.Context, userID, device, ip string) (string, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	sess := &domain.Session{
		UserID:    userID,
		TokenHash: tokenHash(token),
		Device:    device,
		IP:        ip,
		ExpiresAt: time.Now().Add(s.sessionTTL),
	}
	if err := s.store.SessionRepo().Create(ctx, sess); err != nil {
		return "", err
	}
	return token, nil
}

// tokenHash returns the hex SHA-256 of a raw token.
func tokenHash(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
