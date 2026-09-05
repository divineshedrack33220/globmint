package domain

import "time"

// UserStatus describes the lifecycle of a user account.
type UserStatus string

const (
	UserStatusPending  UserStatus = "pending"
	UserStatusActive   UserStatus = "active"
	UserStatusSuspended UserStatus = "suspended"
	UserStatusLocked   UserStatus = "locked"
)

// User is the core identity record.
type User struct {
	ID           string
	Email        string
	Phone        string
	FirstName    string
	LastName     string
	PasswordHash string
	PINHash      string
	TOTPSecret   string
	TOTPEnabled  bool
	Status       UserStatus
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// Session represents an authenticated session (device login). The actual
// bearer token is never stored in plaintext; only its hash is persisted.
type Session struct {
	ID           string
	UserID       string
	TokenHash    string
	Device       string
	IP           string
	ExpiresAt    time.Time
	RevokedAt    *time.Time
	CreatedAt    time.Time
	LastActiveAt time.Time
}
