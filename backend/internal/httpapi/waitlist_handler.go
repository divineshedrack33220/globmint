package httpapi

import (
	"net/http"
)

// waitlistJoinRequest is the body for POST /api/v1/waitlist.
type waitlistJoinRequest struct {
	Email string `json:"email"`
}

// handleWaitlistJoin records an email on the early-access waitlist. Public and
// rate-limited; duplicates are silently accepted (idempotent) so retries and
// coincident signups never surface as errors.
func (d *Deps) handleWaitlistJoin(w http.ResponseWriter, r *http.Request) {
	var req waitlistJoinRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	if err := d.Waitlist.Join(r.Context(), req.Email); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]bool{"ok": true})
}
