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
	ErrInvalidPin          = errors.New("invalid PIN")
	ErrInvalidCode         = errors.New("invalid verification code")
	ErrLimitExceeded       = errors.New("limit exceeded")
	ErrFeatureDisabled     = errors.New("feature disabled")
	ErrTooManyAttempts     = errors.New("too many attempts, try again later")
	ErrTwoFactorRequired   = errors.New("two-factor authentication required")
	ErrTwoFactorInvalid    = errors.New("two-factor challenge expired or invalid")
	// Email OTP sending/verification errors.
	ErrOTPCooldown  = errors.New("wait before requesting another code")
	ErrOTPExpired   = errors.New("verification code expired")
	ErrOTPNotFound  = errors.New("no verification code issued for this email")
	// Withdrawal signature-gating (EIP-712) errors.
	ErrWithdrawSignatureRequired = errors.New("a wallet signature is required for this withdrawal")
	ErrInvalidSignature          = errors.New("invalid withdrawal signature")
	ErrSignatureExpired          = errors.New("withdrawal signature expired")
	ErrWithdrawRequiresCustody   = errors.New("take custody of your vault before withdrawing")
	// Privacy salt derivation errors.
	ErrInvalidOperation = errors.New("operation not allowed in this mode")
	ErrInvalidSalt      = errors.New("invalid privacy salt")
	ErrNoLinkedWallet   = errors.New("link a wallet before recording a derived salt")
	ErrSaltImmutable    = errors.New("privacy salt is immutable once a commitment is funded")
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
	case errors.Is(err, ErrInvalidAmount), errors.Is(err, ErrBadRequest), errors.Is(err, ErrUnsupportedCurrency), errors.Is(err, ErrRateExceeded), errors.Is(err, ErrInvalidAddress), errors.Is(err, ErrInvalidSalt):
		return "INVALID_REQUEST"
	case errors.Is(err, ErrInvalidPin):
		return "INVALID_PIN"
	case errors.Is(err, ErrInvalidCode), errors.Is(err, ErrOTPExpired), errors.Is(err, ErrOTPNotFound):
		return "INVALID_CODE"
	case errors.Is(err, ErrInvalidSignature):
		return "INVALID_SIGNATURE"
	case errors.Is(err, ErrNoLinkedWallet):
		return "WALLET_LINK_REQUIRED"
	case errors.Is(err, ErrSaltImmutable):
		return "SALT_IMMUTABLE"
	case errors.Is(err, ErrInvalidOperation):
		return "INVALID_OPERATION"
	case errors.Is(err, ErrSignatureExpired):
		return "SIGNATURE_EXPIRED"
	case errors.Is(err, ErrWithdrawSignatureRequired), errors.Is(err, ErrWithdrawRequiresCustody):
		return "SIGNATURE_REQUIRED"
	case errors.Is(err, ErrLimitExceeded):
		return "LIMIT_EXCEEDED"
	case errors.Is(err, ErrFeatureDisabled):
		return "FEATURE_DISABLED"
	case errors.Is(err, ErrTooManyAttempts), errors.Is(err, ErrOTPCooldown):
		return "TOO_MANY_REQUESTS"
	case errors.Is(err, ErrTwoFactorRequired):
		return "TWO_FACTOR_REQUIRED"
	case errors.Is(err, ErrTwoFactorInvalid):
		return "TWO_FACTOR_INVALID"
	default:
		return "INTERNAL_ERROR"
	}
}
