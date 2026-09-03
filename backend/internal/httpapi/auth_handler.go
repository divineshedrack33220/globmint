package httpapi

import (
	"net/http"

	"globmint/backend/internal/httpapi/middleware"
	"globmint/backend/internal/services"
)

func (d *Deps) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	user, token, err := d.Auth.Register(r.Context(), services.RegisterInput{
		Email:     req.Email,
		Phone:     req.Phone,
		FirstName: req.FirstName,
		LastName:  req.LastName,
		Password:  req.Password,
		Device:    r.Header.Get("User-Agent"),
		IP:        r.RemoteAddr,
	})
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusCreated, authResponse{Token: token, User: newUserResponse(user)})
}

func (d *Deps) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	user, token, err := d.Auth.Login(r.Context(), req.Email, req.Password, r.Header.Get("User-Agent"), r.RemoteAddr)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, authResponse{Token: token, User: newUserResponse(user)})
}

func (d *Deps) handleLogout(w http.ResponseWriter, r *http.Request) {
	token := middleware.TokenFrom(r.Context())
	if err := d.Auth.Logout(r.Context(), token); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "logged_out"})
}
