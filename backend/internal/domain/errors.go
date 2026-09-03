package domain

import "errors"

// Well-typed domain errors mapped to API error codes at the HTTP layer.
// These are NOT the only errors; internal errors are kept opaque to clients.
var (
	ErrNotFound            = errors.New("not found")
	ErrConflict            = errors.New("conflict")
	ErrUnauthenticated     = errors.New("unauthenticated")
	ErrDuplicateEmail      = errors.New("email already registered")
	ErrInvalidCredentials  = errors.New("invalid credentials")
	ErrInvalidToken        = errors.New("invalid or expired token")
	ErrUserLocked          = errors.New("account locked")
	ErrInsufficientBalance = errors.New("insufficient balance")
	ErrInvalidAmount       = errors.New("invalid amount")
	ErrBadRequest          = errors.New("bad request")
	ErrIdempotentReplay    = errors.New("idempotent request already processed")
	ErrAccountNotFound     = errors.New("account not found")
)

// ErrorCode maps a domain error to a stable API error code string.
func ErrorCode(err error) string {
	switch {
	case errors.Is(err, ErrNotFound), errors.Is(err, ErrAccountNotFound):
		return "NOT_FOUND"
	case errors.Is(err, ErrConflict), errors.Is(err, ErrIdempotentReplay):
		return "CONFLICT"
	case errors.Is(err, ErrUnauthenticated), errors.Is(err, ErrInvalidToken):
		return "UNAUTHENTICATED"
	case errors.Is(err, ErrDuplicateEmail):
		return "EMAIL_ALREADY_REGISTERED"
	case errors.Is(err, ErrInvalidCredentials):
		return "INVALID_CREDENTIALS"
	case errors.Is(err, ErrUserLocked):
		return "ACCOUNT_LOCKED"
	case errors.Is(err, ErrInsufficientBalance):
		return "INSUFFICIENT_BALANCE"
	case errors.Is(err, ErrInvalidAmount), errors.Is(err, ErrBadRequest):
		return "INVALID_REQUEST"
	default:
		return "INTERNAL_ERROR"
	}
}
