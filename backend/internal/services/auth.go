package services

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"regexp"
	"strings"
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
	store    store
	sessionTTL time.Duration
}

func NewAuthService(store store, sessionTTL time.Duration) *AuthService {
	return &AuthService{store: store, sessionTTL: sessionTTL}
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

// Login authenticates credentials and returns a raw session token.
func (s *AuthService) Login(ctx context.Context, email, password, device, ip string) (*domain.User, string, error) {
	user, err := s.store.UserRepo().FindByEmail(ctx, strings.ToLower(strings.TrimSpace(email)))
	if errors.Is(err, domain.ErrNotFound) {
		// Constant-ish behavior: do not reveal which part was wrong.
		return nil, "", domain.ErrInvalidCredentials
	}
	if err != nil {
		return nil, "", err
	}
	if user.Status == domain.UserStatusLocked || user.Status == domain.UserStatusSuspended {
		return nil, "", domain.ErrUserLocked
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)) != nil {
		return nil, "", domain.ErrInvalidCredentials
	}
	token, err := s.issueSession(ctx, user.ID, device, ip)
	if err != nil {
		return nil, "", err
	}
	s.recordSecurity(ctx, user.ID, domain.SecurityEventLogin, "New login", "Signed in from a new device", ip, device)
	return user, token, nil
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
