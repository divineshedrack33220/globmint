package httpapi

import (
	"net/http"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/httpapi/middleware"
)

func (d *Deps) handleListDevices(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	current := d.Auth.CurrentSessionID(r.Context(), middleware.TokenFrom(r.Context()))
	devices, err := d.Security.ListDevices(r.Context(), user.ID, current)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	out := make([]deviceResponse, 0, len(devices))
	for _, dv := range devices {
		out = append(out, newDeviceResponse(dv))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

func (d *Deps) handleRevokeDevice(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if err := d.Security.RevokeDevice(r.Context(), user.ID, r.PathValue("id")); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "revoked"})
}

func (d *Deps) handleRevokeOtherDevices(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	current := d.Auth.CurrentSessionID(r.Context(), middleware.TokenFrom(r.Context()))
	if err := d.Security.RevokeOtherDevices(r.Context(), user.ID, current); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "revoked"})
}

func (d *Deps) handleListSecurityEvents(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	events, err := d.Security.ListSecurityEvents(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	out := make([]securityEventResponse, 0, len(events))
	for _, e := range events {
		out = append(out, newSecurityEventResponse(e))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

func (d *Deps) handleListNotifications(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	notifications, err := d.Security.ListNotifications(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	unread, err := d.Security.UnreadCount(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	out := make([]notificationResponse, 0, len(notifications))
	for _, n := range notifications {
		out = append(out, newNotificationResponse(n))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out, "unread": unread})
}

func (d *Deps) handleMarkNotificationRead(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if err := d.Security.MarkRead(r.Context(), user.ID, r.PathValue("id")); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "read"})
}

func (d *Deps) handleMarkAllNotificationsRead(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if err := d.Security.MarkAllRead(r.Context(), user.ID); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "read"})
}
