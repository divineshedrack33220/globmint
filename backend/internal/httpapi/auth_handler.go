package httpapi

import (
	"net/http"

	"globmint/backend/internal/domain"
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
	writeJSON(w, http.StatusCreated, authResponse{Token: token, User: ptr(newUserResponse(user))})
}

func (d *Deps) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	result, err := d.Auth.Login(r.Context(), req.Email, req.Password, r.Header.Get("User-Agent"), r.RemoteAddr)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	if result.Requires2FA {
		writeJSON(w, http.StatusOK, authResponse{
			Requires2FA:    true,
			ChallengeToken: result.ChallengeToken,
		})
		return
	}
	writeJSON(w, http.StatusOK, authResponse{Token: result.Token, User: ptr(newUserResponse(result.User))})
}

// handleVerify2FA completes a login that required a TOTP one-time code.
func (d *Deps) handleVerify2FA(w http.ResponseWriter, r *http.Request) {
	var req twoFactorVerifyRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	result, err := d.Auth.Verify2FA(r.Context(), req.ChallengeToken, req.Code, r.Header.Get("User-Agent"), r.RemoteAddr)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, authResponse{Token: result.Token, User: ptr(newUserResponse(result.User))})
}

func (d *Deps) handleLogout(w http.ResponseWriter, r *http.Request) {
	token := middleware.TokenFrom(r.Context())
	if err := d.Auth.Logout(r.Context(), token); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "logged_out"})
}

// handleChangePassword verifies the current password and stores a new hash,
// revoking every other device session.
func (d *Deps) handleChangePassword(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req changePasswordRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	keep := d.Auth.CurrentSessionID(r.Context(), middleware.TokenFrom(r.Context()))
	if err := d.Auth.ChangePassword(r.Context(), user.ID, req.CurrentPassword, req.NewPassword, keep); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"updated": true})
}

// handleGenerateTOTP provisions a fresh TOTP secret for the user. The secret is
// stored but only activated after enableTOTP proves possession.
func (d *Deps) handleGenerateTOTP(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	secret, uri, err := d.Auth.GenerateTOTP(r.Context(), user.ID, user.Email)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, totpSetupResponse{Secret: secret, URI: uri})
}

// handleEnableTOTP activates 2FA once the user submits a valid code.
func (d *Deps) handleEnableTOTP(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req totpEnableRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	if err := d.Auth.EnableTOTP(r.Context(), user.ID, req.Code); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"enabled": true})
}

// handleDisableTOTP turns off 2FA, requiring the PIN and a valid code.
func (d *Deps) handleDisableTOTP(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	var req totpDisableRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	if err := d.Auth.DisableTOTP(r.Context(), user.ID, req.Pin, req.Code); err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"disabled": true})
}