package httpapi

import (
	"time"

	"globmint/backend/internal/domain"
)

func ptr[T any](v T) *T { return &v }

func newUserResponse(u *domain.User) userResponse {
	return userResponse{
		ID:        u.ID,
		Email:     u.Email,
		Phone:     u.Phone,
		FirstName: u.FirstName,
		LastName:  u.LastName,
		Status:    string(u.Status),
		TwoFactorEnabled: u.TOTPEnabled,
		CreatedAt: u.CreatedAt,
	}
}

type userResponse struct {
	ID               string    `json:"id"`
	Email            string    `json:"email"`
	Phone            string    `json:"phone"`
	FirstName        string    `json:"first_name"`
	LastName         string    `json:"last_name"`
	Status           string    `json:"status"`
	TwoFactorEnabled bool      `json:"two_factor_enabled"`
	CreatedAt        time.Time `json:"created_at"`
}

type registerRequest struct {
	Email     string `json:"email"`
	Phone     string `json:"phone"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Password  string `json:"password"`
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// authResponse is returned on successful login/register/2FA completion.
// When a login requires a one-time code, Requires2FA is true and ChallengeToken
// must be exchanged via POST /auth/2fa/verify.
type authResponse struct {
	Token          string        `json:"token,omitempty"`
	User           *userResponse `json:"user,omitempty"`
	Requires2FA    bool          `json:"requires_2fa"`
	ChallengeToken string        `json:"challenge_token,omitempty"`
}

type changePasswordRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

type twoFactorVerifyRequest struct {
	ChallengeToken string `json:"challenge_token"`
	Code           string `json:"code"`
}

type totpEnableRequest struct {
	Code string `json:"code"`
}

type totpDisableRequest struct {
	Code string `json:"code"`
	Pin  string `json:"pin"`
}

type totpSetupResponse struct {
	Secret string `json:"secret"`
	URI    string `json:"uri"`
}
