package services

import (
	"context"
	"strings"

	"globmint/backend/internal/domain"
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

// Join validates and records an email. Duplicate and already-joined addresses
// are ignored (idempotent).
func (s *WaitlistService) Join(ctx context.Context, email string) error {
	email = strings.ToLower(strings.TrimSpace(email))
	if !emailRe.MatchString(email) {
		return domain.ErrInvalidEmail
	}
	return s.store.WaitlistRepo().Join(ctx, email)
}

// Count returns the number of emails on the waitlist.
func (s *WaitlistService) Count(ctx context.Context) (int, error) {
	return s.store.WaitlistRepo().Count(ctx)
}
