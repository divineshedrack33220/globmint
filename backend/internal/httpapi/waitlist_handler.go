package httpapi

import (
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strings"

	"globmint/backend/internal/services"
)

// waitlistJoinRequest is the body for POST /api/v1/waitlist. ip_hash is a
// one-way hash of the client IP (never a raw address), pre-computed by the
// landing page. The handler hashes again if it is absent so a raw IP is never
// persisted.
type waitlistJoinRequest struct {
	Email     string `json:"email"`
	Source    string `json:"source"`
	IPHash    string `json:"ip_hash"`
	UserAgent string `json:"user_agent"`
}

// hashSourceIP derives a stable, non-reversible identifier for a client IP.
// Only the digest is ever stored or forwarded.
func hashSourceIP(ip string) string {
	sum := sha256.Sum256([]byte(strings.TrimSpace(ip)))
	return hex.EncodeToString(sum[:])
}

// handleWaitlistJoin records an email on the early-access waitlist. Public and
// rate-limited; duplicates are silently accepted (idempotent) so retries and
// coincident signups never surface as errors. Never stores a raw IP.
func (d *Deps) handleWaitlistJoin(w http.ResponseWriter, r *http.Request) {
	var req waitlistJoinRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	ipHash := strings.TrimSpace(req.IPHash)
	if ipHash == "" {
		ipHash = hashSourceIP(clientIP(r))
	}
	err := d.Waitlist.Join(r.Context(), services.WaitlistSignup{
		Email:     req.Email,
		Source:    req.Source,
		IPHash:    ipHash,
		UserAgent: req.UserAgent,
	})
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]bool{"ok": true})
}
