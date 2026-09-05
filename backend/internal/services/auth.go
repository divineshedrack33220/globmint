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
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/bcrypt"

	"globmint/backend/internal/domain"
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

	mu       sync.Mutex
	attempts map[string]*attemptWindow // key: "login:<sha256(email)>" or "pin:<userID>"
}

type attemptWindow struct {
	count int
	reset time.Time
}

const (
	loginMaxAttempts = 5
	attemptWindowDur = 15 * time.Minute
	pinMaxAttempts   = 5
	totpChallengeTTL = 5 * time.Minute
)

func NewAuthService(store store, sessionTTL time.Duration, sessionSecret string) *AuthService {
	if sessionSecret == "" {
		sessionSecret = "dev-only-change-me-session-secret-0000000000"
	}
	return &AuthService{
		store:        store,
		sessionTTL:   sessionTTL,
		challengeKey: []byte(sessionSecret),
		attempts:     map[string]*attemptWindow{},
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

// Register creates a user, provisions default accounts, and issues a session.
func (s *AuthService) Register(ctx context.Context, req RegisterInput) (user *domain.User, token string, err error) {
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if !emailRe.MatchString(email) {
		return nil, "", domain.ErrBadRequest
	}
	if len(req.Password) < 8 {
		return nil, "", domain.ErrBadRequest
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, "", err
	}

	err = s.store.RunInTx(ctx, func(store storage.Store) error {
		u := &domain.User{
			Email:        email,
			Phone:        req.Phone,
			FirstName:    req.FirstName,
			LastName:     req.LastName,
			PasswordHash: string(hash),
			Status:       domain.UserStatusActive,
		}
		if err := store.UserRepo().Create(ctx, u); err != nil {
			return err
		}
		if err := store.AccountRepo().EnsureDefaultAccounts(ctx, u.ID); err != nil {
			return err
		}
		user = u
		return nil
	})
	if err != nil {
		return nil, "", err
	}

	token, err = s.issueSession(ctx, user.ID, req.Device, req.IP)
	if err != nil {
		return nil, "", err
	}
	s.recordSecurity(ctx, user.ID, domain.SecurityEventRegister, "Account created", "Welcome to Globmint", req.IP, req.Device)
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
		s.noteFailure(failKey)
		if s.isThrottled(failKey, loginMaxAttempts) {
			return nil, domain.ErrTooManyAttempts
		}
		return nil, domain.ErrInvalidCredentials
	}
	s.clearFailure(failKey)

	if user.TOTPEnabled {
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
	s.recordSecurity(ctx, user.ID, domain.SecurityEventLogin, "New login", "Signed in from a new device", ip, device)
	return &LoginResult{User: user, Token: token}, nil
}

// Verify2FA completes a login that required a TOTP code, issuing a session.
func (s *AuthService) Verify2FA(ctx context.Context, challengeToken, code, device, ip string) (*LoginResult, error) {
	userID, err := s.verifyChallenge(challengeToken)
	if err != nil {
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
		return nil, domain.ErrInvalidCode
	}
	s.clearFailure("login:" + emailHashKey(user.Email))
	token, err := s.issueSession(ctx, user.ID, device, ip)
	if err != nil {
		return nil, err
	}
	s.recordSecurity(ctx, user.ID, domain.SecurityEventLogin, "Two-factor login", "Signed in with a one-time code", ip, device)
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
	s.recordSecurity(ctx, userID, domain.SecurityEventRegister, "Two-factor enabled", "Authenticator app linked to this account", "", "")
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
	s.recordSecurity(ctx, userID, domain.SecurityEventRegister, "Two-factor disabled", "Authenticator app unlinked", "", "")
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
	s.recordSecurity(ctx, userID, domain.SecurityEventRegister, "Password changed", "Your password was updated", "", "")
	return nil
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
	s.recordSecurity(ctx, sess.UserID, domain.SecurityEventLogout, "Signed out", "You signed out of this device", sess.IP, sess.Device)
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
	_ = s.store.SecurityEventRepo().Create(ctx, &domain.SecurityEvent{
		UserID: userID,
		Type:   etype,
		Title:  title,
		Detail: detail,
		IP:     ip,
		Device: device,
	})
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
