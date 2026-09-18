package services

import (
	"context"
	"strings"
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/events"
)

// DeviceView is a user-facing snapshot of an active session (device).
type DeviceView struct {
	ID           string
	Name         string
	Detail       string
	IP           string
	IsCurrent    bool
	LastActiveAt time.Time
	CreatedAt    time.Time
}

// SecurityService queries/mutates devices, security activity, and the in-app
// notification inbox. It does not own authentication; the AuthService records
// events into the same stores.
type SecurityService struct {
	store store
	// SecurityHub fans security events out to SSE subscribers. Nil in tests.
	SecurityHub *events.Hub
}

func NewSecurityService(store store) *SecurityService { return &SecurityService{store: store} }

// ListDevices returns the user's active sessions as device views.
func (s *SecurityService) ListDevices(ctx context.Context, userID, currentSessionID string) ([]DeviceView, error) {
	sessions, err := s.store.SessionRepo().ListActiveByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]DeviceView, 0, len(sessions))
	for _, sess := range sessions {
		out = append(out, DeviceView{
			ID:           sess.ID,
			Name:         deviceName(sess.Device),
			Detail:       sess.Device,
			IP:           sess.IP,
			IsCurrent:    currentSessionID != "" && sess.ID == currentSessionID,
			LastActiveAt: sess.LastActiveAt,
			CreatedAt:    sess.CreatedAt,
		})
	}
	return out, nil
}

// RevokeDevice revokes a single session, verifying ownership. The remote
// device's owner and every logged-in session see a critical revocation event.
func (s *SecurityService) RevokeDevice(ctx context.Context, userID, deviceID string) error {
	sess, err := s.store.SessionRepo().FindByID(ctx, deviceID)
	if err != nil {
		return err
	}
	if sess.UserID != userID {
		return domain.ErrNotFound
	}
	if err := s.store.SessionRepo().Revoke(ctx, deviceID); err != nil {
		return err
	}
	// Comment: keep event recording best-effort so a failed audit write does not
	// bubble up as a hard error to the user.
	_ = s.record(ctx, &domain.SecurityEvent{
		UserID:   userID,
		Type:     domain.SecurityEventSessionRevoked,
		Severity: domain.SeverityCritical,
		Title:    "Session revoked",
		Detail:   "A signed-in device was logged out remotely",
		IP:       sess.IP,
		Device:   sess.Device,
	})
	s.publishSecurity(userID)
	return nil
}

// RevokeOtherDevices revokes every session except the current one.
func (s *SecurityService) RevokeOtherDevices(ctx context.Context, userID, keepID string) error {
	if err := s.store.SessionRepo().RevokeAllExcept(ctx, userID, keepID); err != nil {
		return err
	}
	_ = s.record(ctx, &domain.SecurityEvent{
		UserID:   userID,
		Type:     domain.SecurityEventSessionRevoked,
		Severity: domain.SeverityCritical,
		Title:    "Other sessions revoked",
		Detail:   "All other signed-in devices were logged out",
	})
	s.publishSecurity(userID)
	return nil
}

// ListSecurityEvents returns the most recent security activity events.
func (s *SecurityService) ListSecurityEvents(ctx context.Context, userID string) ([]domain.SecurityEvent, error) {
	return s.store.SecurityEventRepo().ListByUser(ctx, userID, 50)
}

// ListSecurityEventsPaged returns one page of the security feed (newest
// first) plus the owning user's total event count.
func (s *SecurityService) ListSecurityEventsPaged(ctx context.Context, userID string, limit, offset int) ([]domain.SecurityEvent, int, error) {
	return s.store.SecurityEventRepo().ListByUserPaged(ctx, userID, limit, offset)
}

// NotificationPrefs returns the user's email-alert preferences.
func (s *SecurityService) NotificationPrefs(ctx context.Context, userID string) (newSignin bool, failedLogin bool, err error) {
	return s.store.UserRepo().NotificationPrefs(ctx, userID)
}

// UpdateNotificationPrefs persists the user's email-alert preferences and
// notifies the security feed so other open devices pick up the change.
func (s *SecurityService) UpdateNotificationPrefs(ctx context.Context, userID string, newSignin, failedLogin bool) error {
	if err := s.store.UserRepo().UpdateNotificationPrefs(ctx, userID, newSignin, failedLogin); err != nil {
		return err
	}
	_ = s.record(ctx, &domain.SecurityEvent{
		UserID:   userID,
		Type:     domain.SecurityEventDevice,
		Severity: domain.SeverityInfo,
		Title:    "Alert preferences updated",
		Detail:   "Email security-alert preferences were changed on this account",
	})
	s.publishSecurity(userID)
	return nil
}

// ListNotifications returns the in-app inbox.
func (s *SecurityService) ListNotifications(ctx context.Context, userID string) ([]domain.Notification, error) {
	return s.store.NotificationRepo().ListByUser(ctx, userID, 50)
}

// UnreadCount returns the number of unread notifications.
func (s *SecurityService) UnreadCount(ctx context.Context, userID string) (int, error) {
	return s.store.NotificationRepo().CountUnread(ctx, userID)
}

func (s *SecurityService) MarkRead(ctx context.Context, userID, id string) error {
	return s.store.NotificationRepo().MarkRead(ctx, userID, id)
}

func (s *SecurityService) MarkAllRead(ctx context.Context, userID string) error {
	return s.store.NotificationRepo().MarkAllRead(ctx, userID)
}

// Notify creates a notification in the inbox.
func (s *SecurityService) Notify(ctx context.Context, userID string, category domain.NotificationCategory, title, body string) error {
	return s.store.NotificationRepo().Create(ctx, &domain.Notification{
		UserID:   userID,
		Category: category,
		Title:    title,
		Body:     body,
	})
}

// record appends a security event (best-effort, see callers).
func (s *SecurityService) record(ctx context.Context, ev *domain.SecurityEvent) error {
	return s.store.SecurityEventRepo().Create(ctx, ev)
}

// Record writes an arbitrary security event (best-effort) and pushes an SSE
// refresh. Handlers use it when they hold request context the services do not
// (e.g. IP/user-agent for PIN, withdrawal, recovery and custody actions).
func (s *SecurityService) Record(ctx context.Context, ev *domain.SecurityEvent) {
	_ = s.record(ctx, ev)
	s.publishSecurity(ev.UserID)
}

// publishSecurity pushes a kind:security SSE notification so open security
// centers invalidate their providers. No-op when the hub is unset (tests).
func (s *SecurityService) publishSecurity(userID string) {
	if s.SecurityHub == nil {
		return
	}
	s.SecurityHub.Publish(events.Event{
		Type: "data.changed", UserID: userID, Kind: "security", At: time.Now().UTC().Format(time.RFC3339),
	})
}

// deviceName derives a short, human-friendly label from a User-Agent string.
func deviceName(ua string) string {
	u := strings.ToLower(ua)
	switch {
	case strings.Contains(u, "iphone"):
		return "iPhone"
	case strings.Contains(u, "ipad"):
		return "iPad"
	case strings.Contains(u, "android") && strings.Contains(u, "samsung"):
		return "Samsung Phone"
	case strings.Contains(u, "android"):
		return "Android Phone"
	case strings.Contains(u, "macintosh") || strings.Contains(u, "mac os"):
		return "MacBook"
	case strings.Contains(u, "windows"):
		return "Windows PC"
	case strings.Contains(u, "linux"):
		return "Linux Device"
	default:
		return "Device"
	}
}