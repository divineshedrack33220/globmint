package services

import (
	"context"
	"strings"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

// WaitlistService records early-access signups. Email-only and non-account:
// an email may be placed on the waitlist before (or without) full registration.
type WaitlistService struct {
	store store
}

// NewWaitlistService returns a WaitlistService bound to the given store.
func NewWaitlistService(store store) *WaitlistService {
	return &WaitlistService{store: store}
}

// WaitlistSignup is the validated input to Join. IPHash is a one-way hash of
// the client IP (never a raw address); Source defaults to "landing".
type WaitlistSignup struct {
	Email     string
	Source    string
	IPHash    string
	UserAgent string
}

// Join validates and records a signup. Duplicate and already-joined addresses
// are ignored (idempotent), regardless of case.
func (s *WaitlistService) Join(ctx context.Context, signup WaitlistSignup) error {
	signup.Email = strings.ToLower(strings.TrimSpace(signup.Email))
	if !emailRe.MatchString(signup.Email) {
		return domain.ErrInvalidEmail
	}
	if strings.TrimSpace(signup.Source) == "" {
		signup.Source = "landing"
	}
	return s.store.WaitlistRepo().Join(ctx, storage.WaitlistSignup{
		Email:     signup.Email,
		Source:    signup.Source,
		IPHash:    strings.TrimSpace(signup.IPHash),
		UserAgent: signup.UserAgent,
	})
}

// Count returns the number of emails on the waitlist.
func (s *WaitlistService) Count(ctx context.Context) (int, error) {
	return s.store.WaitlistRepo().Count(ctx)
}
