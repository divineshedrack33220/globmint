package httpapi

import (
	"errors"
	"sync"
)

// --- Amount validation constants ---

var (
	ErrAmountEmpty        = errors.New("amount is required")
	ErrAmountNegative     = errors.New("amount must be positive")
	ErrAmountMax          = errors.New("amount exceeds maximum allowed")
	ErrAmountMin          = errors.New("amount is below minimum allowed")
	ErrCurrencyUnsupported = errors.New("currency is not supported")
)

// Supported currencies and their limits (minor units).
var SupportedCurrencies = map[string]struct {
	min, max int64
}{
	"NGN": {min: 1, max: 999999999999},
	"USDT": {min: 1, max: 999999999999},
}

// mu protects SupportedCurrencies map if concurrent access is ever needed.
var mu sync.RWMutex