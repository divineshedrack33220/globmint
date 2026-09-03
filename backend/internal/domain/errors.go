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
	ErrUnsupportedCurrency = errors.New("unsupported currency")
	ErrRateNotFound        = errors.New("exchange rate not found")
	ErrRateExpired         = errors.New("exchange rate expired")
	ErrRateExceeded        = errors.New("amount exceeds rate limits")
	ErrInvalidAddress      = errors.New("invalid deposit address")
)

// ErrorCode maps a domain error to a stable API error code string.
func ErrorCode(err error) string {
	switch {
	case errors.Is(err, ErrNotFound), errors.Is(err, ErrAccountNotFound), errors.Is(err, ErrRateNotFound):
		return "NOT_FOUND"
	case errors.Is(err, ErrConflict), errors.Is(err, ErrIdempotentReplay), errors.Is(err, ErrRateExpired):
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
	case errors.Is(err, ErrInvalidAmount), errors.Is(err, ErrBadRequest), errors.Is(err, ErrUnsupportedCurrency), errors.Is(err, ErrRateExceeded), errors.Is(err, ErrInvalidAddress):
		return "INVALID_REQUEST"
	default:
		return "INTERNAL_ERROR"
	}
}
