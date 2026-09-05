// Package money provides a fixed-point decimal type for financial
// calculations. Financial balances must NEVER be represented as floating-point
// numbers; this type stores minor units (kobo, for NGN) as an int64.
package money

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"math/big"
	"strconv"
	"strings"
)

// MinorUnit is the number of minor units per major unit. For NGN this is 100
// kobo per naira. This is intentionally abstract so other currencies can be
// supported later without changing the core arithmetic.
const MinorUnit int64 = 100

// Money represents an amount as a whole number of minor units (kobo).
// The zero value is a valid amount of zero.
type Money struct {
	minor int64
}

var (
	ErrMismatch     = errors.New("money: cannot operate on different currencies")
	ErrNegative     = errors.New("money: negative amounts are not permitted")
	ErrOverflow     = errors.New("money: integer overflow")
	ErrDivideByZero = errors.New("money: division by zero")
)

// FromMajorUnits constructs Money from a decimal string like "1250000.50".
// It accepts an optional currency-agnostic decimal string and stores minor units.
func FromMajorUnits(s string) (Money, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return Money{}, errors.New("money: empty amount")
	}
	neg := false
	if s[0] == '-' {
		neg = true
		s = s[1:]
	}
	parts := strings.Split(s, ".")
	whole := parts[0]
	frac := ""
	if len(parts) == 2 {
		frac = parts[1]
	}
	if whole == "" {
		whole = "0"
	}
	// Validate frac length
	if len(frac) > 18 {
		return Money{}, errors.New("money: too many fractional digits")
	}
	// Pad fraction to MinorUnit digits
	for len(frac) < 2 {
		frac += "0"
	}
	// Combine whole + fractional into a single integer string
	combined := whole + frac
	// Trim to keep within int64
	m, err := strconv.ParseInt(combined, 10, 64)
	if err != nil {
		if errors.Is(err, strconv.ErrRange) {
			return Money{}, ErrOverflow
		}
		return Money{}, fmt.Errorf("money: invalid amount %q", s)
	}
	if neg {
		return Money{}, ErrNegative
	}
	return Money{minor: m}, nil
}

// FromMinorUnits constructs Money directly from an int64 minor-units value.
func FromMinorUnits(minor int64) Money {
	return Money{minor: minor}
}

// Minor returns the underlying minor-units value.
func (m Money) Minor() int64 { return m.minor }

// Major returns the major-units portion (for formatting).
func (m Money) Major() int64 { return m.minor / MinorUnit }

func (m Money) IsNegative() bool { return m.minor < 0 }

// Add returns m + other. It errors on overflow.
func (m Money) Add(other Money) (Money, error) {
	sum := m.minor + other.minor
	if (sum > m.minor) != (other.minor > 0) {
		return Money{}, ErrOverflow
	}
	return Money{minor: sum}, nil
}

// Sub returns m - other. Results may be negative (used for fee/refund math in
// controlled internal contexts); callers validate sufficiency separately.
func (m Money) Sub(other Money) (Money, error) {
	diff := m.minor - other.minor
	if (diff < m.minor) != (other.minor > 0) {
		return Money{}, ErrOverflow
	}
	return Money{minor: diff}, nil
}

// MulRatio multiplies m by a ratio represented by (num, den) using integer
// math with rounding to nearest, ties away from zero. No floating point is
// involved and overflow is handled via big.Int intermediates.
func (m Money) MulRatio(num, den int64) (Money, error) {
	if den == 0 {
		return Money{}, ErrDivideByZero
	}
	if num == 0 || m.minor == 0 {
		return Money{minor: 0}, nil
	}
	// n = minor * num
	n := big.NewInt(m.minor)
	n.Mul(n, big.NewInt(num))
	// q = |n| / |den| with remainder r
	d := big.NewInt(den)
	q := new(big.Int)
	r := new(big.Int)
	q.QuoRem(n, d, r)
	// Round to nearest: if 2*|r| >= |den|, round away from zero.
	twoR := new(big.Int).Set(r)
	twoR.Abs(twoR)
	twoR.Lsh(twoR, 1)
	dAbs := new(big.Int).Abs(d)
	if twoR.Cmp(dAbs) >= 0 {
		if n.Sign() >= 0 {
			q.Add(q, big.NewInt(1))
		} else {
			q.Sub(q, big.NewInt(1))
		}
	}
	if !q.IsInt64() {
		return Money{}, ErrOverflow
	}
	return Money{minor: q.Int64()}, nil
}

// Percent returns m * p% (p as a decimal like 1.5 -> 150/10000 of 1% scaled).
// Whitelist p must be in [0, 10000] representing basis points (0..100%).
func (m Money) Percent(basisPoints int64) (Money, error) {
	if basisPoints < 0 || basisPoints > 10000 {
		return Money{}, fmt.Errorf("money: basis points out of range: %d", basisPoints)
	}
	return m.MulRatio(basisPoints, 10000)
}

// Compare returns -1, 0, or +1.
func (m Money) Compare(other Money) int {
	switch {
	case m.minor < other.minor:
		return -1
	case m.minor > other.minor:
		return 1
	default:
		return 0
	}
}

func (m Money) IsZero() bool { return m.minor == 0 }

// String returns a canonical decimal string, e.g. "1250000.50". Negative
// values are prefixed with a minus sign.
func (m Money) String() string {
	neg := m.minor < 0
	abs := m.minor
	if neg {
		abs = -abs
	}
	whole := abs / MinorUnit
	frac := abs % MinorUnit
	if neg {
		return fmt.Sprintf("-%d.%02d", whole, frac)
	}
	return fmt.Sprintf("%d.%02d", whole, frac)
}

// MustFromMajorUnits panics on invalid input; for tests/constants only.
func MustFromMajorUnits(s string) Money {
	m, err := FromMajorUnits(s)
	if err != nil {
		panic(err)
	}
	return m
}

// UnmarshalJSON implements json.Unmarshaler for wire-safe amounts.
func (m *Money) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err == nil {
		parsed, perr := FromMajorUnits(s)
		if perr != nil {
			return perr
		}
		*m = parsed
		return nil
	}
	// Fall back to numeric
	var f float64
	if err := json.Unmarshal(b, &f); err != nil {
		return err
	}
	if f > math.MaxInt64/float64(MinorUnit) || f < 0 {
		return ErrOverflow
	}
	*m = FromMinorUnits(int64(math.Round(f * float64(MinorUnit))))
	return nil
}

// MarshalJSON implements json.Marshaler, emitting a numeric string.
func (m Money) MarshalJSON() ([]byte, error) {
	return json.Marshal(m.String())
}
