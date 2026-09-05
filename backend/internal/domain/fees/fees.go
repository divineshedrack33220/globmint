// Package fees holds the platform's fee schedule. Withdrawal fees are
// intentionally tiny (fractions of a percent with a low cap); deposits,
// internal transfers, and elevation cancellations are always free.
package fees

// ComputeWithdrawalFee returns the NGN-minor (kobo) fee for a withdrawal of
// amountMinor kobo:
//
//	fee = max(min(amountMinor * bps / 10000, capMinor), minMinor)
//
// All arithmetic is integer-based (no floating point). A non-positive bps
// disables fees entirely (returns 0); a non-positive amount also yields 0.
func ComputeWithdrawalFee(amountMinor, bps, minMinor, capMinor int64) int64 {
	if amountMinor <= 0 || bps <= 0 {
		return 0
	}
	// Division-first ordering avoids int64 overflow for very large amounts:
	// amount*bps/10000 == amount/10000*bps + (amount%10000)*bps/10000.
	raw := amountMinor/10000*bps + (amountMinor%10000)*bps/10000
	if raw > capMinor {
		raw = capMinor
	}
	if raw < minMinor {
		raw = minMinor
	}
	if raw < 0 {
		raw = 0
	}
	return raw
}
