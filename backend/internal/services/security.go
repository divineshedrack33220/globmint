package services

import (
	"context"
	"strings"
	"time"

	"globmint/backend/internal/domain"
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

// RevokeDevice revokes a single session, verifying ownership.
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
	_ = s.record(ctx, userID, domain.SecurityEventDevice,
		"Device logged out", "A signed-in device was logged out remotely", sess.IP, sess.Device)
	return nil
}

// RevokeOtherDevices revokes every session except the current one.
func (s *SecurityService) RevokeOtherDevices(ctx context.Context, userID, keepID string) error {
	if err := s.store.SessionRepo().RevokeAllExcept(ctx, userID, keepID); err != nil {
		return err
	}
	_ = s.record(ctx, userID, domain.SecurityEventDevice,
		"Other devices logged out", "All other signed-in devices were logged out", "", "")
	return nil
}

// ListSecurityEvents returns the security activity feed.
func (s *SecurityService) ListSecurityEvents(ctx context.Context, userID string) ([]domain.SecurityEvent, error) {
	return s.store.SecurityEventRepo().ListByUser(ctx, userID, 50)
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
func (s *SecurityService) record(ctx context.Context, userID string, etype domain.SecurityEventType, title, detail, ip, device string) error {
	return s.store.SecurityEventRepo().Create(ctx, &domain.SecurityEvent{
		UserID: userID,
		Type:   etype,
		Title:  title,
		Detail: detail,
		IP:     ip,
		Device: device,
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
