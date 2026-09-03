package httpapi

import (
	"time"

	"globmint/backend/internal/domain"
)

func newUserResponse(u *domain.User) userResponse {
	return userResponse{
		ID:        u.ID,
		Email:     u.Email,
		Phone:     u.Phone,
		FirstName: u.FirstName,
		LastName:  u.LastName,
		Status:    string(u.Status),
		CreatedAt: u.CreatedAt,
	}
}

type userResponse struct {
	ID        string `json:"id"`
	Email     string `json:"email"`
	Phone     string `json:"phone"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Status    string `json:"status"`
	CreatedAt time.Time `json:"created_at"`
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

type authResponse struct {
	Token string       `json:"token"`
	User  userResponse `json:"user"`
}
