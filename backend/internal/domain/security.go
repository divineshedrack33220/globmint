package domain

import "time"

// SecurityEventType describes the kind of security-relevant activity.
type SecurityEventType string

const (
	SecurityEventLogin          SecurityEventType = "login"
	SecurityEventLoginFailed    SecurityEventType = "failed_login"
	SecurityEventThrottle       SecurityEventType = "throttle"
	SecurityEventTwoFactor      SecurityEventType = "two_factor"
	SecurityEventNewDevice      SecurityEventType = "new_device"
	SecurityEventSessionRevoked SecurityEventType = "session_revoked"
	SecurityEventRegister       SecurityEventType = "register"
	SecurityEventLogout         SecurityEventType = "logout"
	SecurityEventDevice         SecurityEventType = "device"
	SecurityEventPinChange      SecurityEventType = "pin_change"
	SecurityEventPassword       SecurityEventType = "password"
	SecurityEventWithdrawal    SecurityEventType = "withdrawal"
	SecurityEventDeposit       SecurityEventType = "deposit"
	SecurityEventRecovery      SecurityEventType = "recovery"
	SecurityEventCustody       SecurityEventType = "custody"
)

// EventSeverity grades a security event. Severity drives the audit feed's
// visual weight: info is routine, warn is suspect-but-not-proven, critical is
// something needing immediate attention.
type EventSeverity string

const (
	SeverityInfo     EventSeverity = "info"
	SeverityWarn     EventSeverity = "warn"
	SeverityCritical EventSeverity = "critical"
)

// SecurityEvent records a security-relevant activity for the activity feed.
type SecurityEvent struct {
	ID        string
	UserID    string
	Type      SecurityEventType
	Severity  EventSeverity
	Title     string
	Detail    string
	IP        string
	UserAgent string
	DeviceID  string
	Device    string
	Metadata  map[string]any
	CreatedAt time.Time
}

// NotificationCategory groups notifications in the in-app inbox.
type NotificationCategory string

const (
	NotificationCategoryGeneral    NotificationCategory = "general"
	NotificationCategoryDeposit    NotificationCategory = "deposit"
	NotificationCategoryWithdrawal NotificationCategory = "withdrawal"
	NotificationCategoryTransfer   NotificationCategory = "transfer"
	NotificationCategoryConversion NotificationCategory = "conversion"
	NotificationCategorySecurity   NotificationCategory = "security"
)

// Notification is an in-app inbox message for a user.
type Notification struct {
	ID        string
	UserID    string
	Category  NotificationCategory
	Title     string
	Body      string
	IsRead    bool
	CreatedAt time.Time
}