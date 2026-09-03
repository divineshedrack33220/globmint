package httpapi

import (
	"net/http"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/httpapi/middleware"
)

func (d *Deps) handleMe(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	writeJSON(w, http.StatusOK, newUserResponse(user))
}
