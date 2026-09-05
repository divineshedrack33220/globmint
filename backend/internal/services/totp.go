package services

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"encoding/base32"
	"encoding/binary"
	"fmt"
	"strings"
	"time"
)

// TOTP parameters (RFC 6238).
const (
	totpStepSeconds = 30
	totpDigits      = 6
	totpHashTokens  = 4 // 31-bit dynamic window
)

// generateTOTPSecret returns a random base32 secret (no padding), suitable for
// provisioning authenticator apps.
func generateTOTPSecret() (string, error) {
	raw := make([]byte, 20)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	return strings.TrimRight(base32.StdEncoding.EncodeToString(raw), "="), nil
}

// totpURI builds the otpauth provisioning URI for the user's authenticator app.
func totpURI(secret, email, issuer string) string {
	return fmt.Sprintf("otpauth://totp/%s:%s?secret=%s&issuer=%s&algorithm=SHA1&digits=%d&period=%d",
		urlPathEscape(issuer), urlPathEscape(email), secret, urlPathEscape(issuer), totpDigits, totpStepSeconds)
}

func urlPathEscape(s string) string {
	r := strings.NewReplacer(":", "%3A", "/", "%2F", "?", "%3F", "#", "%23", "&", "%26", "=", "%3D")
	return r.Replace(s)
}

// computeTOTP returns the current RFC 6238 code for a base32 secret.
func computeTOTP(secret string, at time.Time) (string, error) {
	key, err := base32.StdEncoding.DecodeString(strings.ToUpper(strings.TrimRight(secret, "=")))
	if err != nil {
		return "", err
	}
	counter := uint64(at.Unix() / totpStepSeconds)
	buf := make([]byte, 8)
	binary.BigEndian.PutUint64(buf, counter)

	h := hmac.New(sha1.New, key)
	_, _ = h.Write(buf)
	sum := h.Sum(nil)

	offset := sum[len(sum)-1] & 0x0f
	code := (uint32(sum[offset])&0x7f)<<24 |
		uint32(sum[offset+1])<<16 |
		uint32(sum[offset+2])<<8 |
		uint32(sum[offset+3])
	mod := uint32(1)
	for i := 0; i < totpDigits; i++ {
		mod *= 10
	}
	return fmt.Sprintf("%0*d", totpDigits, code%mod), nil
}

// verifyTOTP checks a code against the current and adjacent time steps
// (accepts a drift of one step in either direction).
func verifyTOTP(secret, code string) bool {
	if len(code) != totpDigits {
		return false
	}
	now := time.Now()
	for _, dt := range []time.Duration{0, -totpStepSeconds, totpStepSeconds} {
		want, err := computeTOTP(secret, now.Add(dt))
		if err != nil {
			return false
		}
		if hmac.Equal([]byte(want), []byte(code)) {
			return true
		}
	}
	return false
}