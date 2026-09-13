package domain

import "time"

// EmailOTP is a short-lived, single-use email verification code. Only the
// SHA-256 hash of the code is ever stored; the plaintext code exists solely in
// the email the user receives.
//
// When registration is OTP-gated, the untouched signup payload (name, phone,
// bcrypt password hash) is staged on the same row so no user record exists
// unless the code is verified. A resend replaces the code but preserves the
// payload; a successful verification clears the whole row.
type EmailOTP struct {
	Email      string
	CodeHash   string
	ExpiresAt  time.Time
	NextSendAt *time.Time
	Attempts   int
	// Pending-registration payload (staged, not yet an account).
	FirstName    string
	LastName     string
	Phone        string
	PasswordHash string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}
