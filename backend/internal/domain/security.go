package domain

import "time"

// SecurityEventType describes the kind of security-relevant activity.
type SecurityEventType string

const (
	SecurityEventLogin     SecurityEventType = "login"
	SecurityEventRegister  SecurityEventType = "register"
	SecurityEventLogout    SecurityEventType = "logout"
	SecurityEventDevice    SecurityEventType = "device"
	SecurityEventPinChange SecurityEventType = "pin_change"
	SecurityEventPassword  SecurityEventType = "password"
)

// SecurityEvent records a security-relevant activity for the activity feed.
type SecurityEvent struct {
	ID        string
	UserID    string
	Type      SecurityEventType
	Title     string
	Detail    string
	IP        string
	Device    string
	CreatedAt time.Time
}

// NotificationCategory groups notifications in the in-app inbox.
type NotificationCategory string

const (
	NotificationCategoryGeneral    NotificationCategory = "general"
	NotificationCategoryDeposit    NotificationCategory = "deposit"
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
