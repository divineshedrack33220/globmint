package httpapi

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/httpapi/middleware"
)

// ErrorEnvelope is the canonical structured error body returned to clients.
// Internal details are never leaked; only stable codes and safe messages are
// exposed.
type ErrorEnvelope struct {
	Code          string `json:"code"`
	Message       string `json:"message,omitempty"`
	RequestID     string `json:"request_id"`
	TransactionID string `json:"transaction_id,omitempty"`
}

// writeJSON writes a JSON body with the given status code.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if v != nil {
		if err := json.NewEncoder(w).Encode(v); err != nil {
			log.Printf("httpapi: encode response: %v", err)
		}
	}
}

// safeMessage maps an error to a user-safe message. Errors that must not leak
// details (internal failures) always fall back to a generic message.
func safeMessage(err error) string {
	switch {
	case errors.Is(err, domain.ErrInvalidCredentials):
		return "Invalid email or password."
	case errors.Is(err, domain.ErrInvalidToken):
		return "Your session is invalid or has expired."
	case errors.Is(err, domain.ErrUserLocked):
		return "Your account is locked. Contact support."
	case errors.Is(err, domain.ErrNotFound), errors.Is(err, domain.ErrAccountNotFound):
		return "The requested resource was not found."
	case errors.Is(err, domain.ErrDuplicateEmail):
		return "An account with this email already exists."
	case errors.Is(err, domain.ErrInsufficientBalance):
		return "You do not have enough available funds."
	case errors.Is(err, domain.ErrIdempotentReplay):
		return "This request was already processed."
	case errors.Is(err, domain.ErrConflict):
		return "The request conflicts with existing data."
	case errors.Is(err, domain.ErrInvalidAmount):
		return "The amount provided is invalid."
	case errors.Is(err, domain.ErrBadRequest):
		return "The request could not be processed."
	default:
		return "Something went wrong. Please try again."
	}
}

// writeError converts a domain error into a structured error response and
// assigns the appropriate HTTP status code.
func writeError(w http.ResponseWriter, r *http.Request, err error, txnID string) {
	status := errorStatus(err)
	writeJSON(w, status, ErrorEnvelope{
		Code:          domain.ErrorCode(err),
		Message:       safeMessage(err),
		RequestID:     middleware.RequestIDFrom(r.Context()),
		TransactionID: txnID,
	})
}

func errorStatus(err error) int {	switch {
	case errors.Is(err, domain.ErrInvalidCredentials),
		errors.Is(err, domain.ErrUnauthenticated),
		errors.Is(err, domain.ErrInvalidToken):
		return http.StatusUnauthorized
	case errors.Is(err, domain.ErrUserLocked):
		return http.StatusForbidden
	case errors.Is(err, domain.ErrNotFound), errors.Is(err, domain.ErrAccountNotFound):
		return http.StatusNotFound
	case errors.Is(err, domain.ErrConflict),
		errors.Is(err, domain.ErrDuplicateEmail),
		errors.Is(err, domain.ErrIdempotentReplay):
		return http.StatusConflict
	case errors.Is(err, domain.ErrInvalidAmount),
		errors.Is(err, domain.ErrInsufficientBalance),
		errors.Is(err, domain.ErrBadRequest):
		return http.StatusBadRequest
	default:
		return http.StatusInternalServerError
	}
}

// decodeJSON parses a request body into dst, rejecting extra fields and bodies
// larger than maxBytes. Malformed input yields a structured bad-request error.
func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) error {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1 MiB
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil && !errors.Is(err, io.EOF) {
		return domain.ErrBadRequest
	}
	return nil
}
