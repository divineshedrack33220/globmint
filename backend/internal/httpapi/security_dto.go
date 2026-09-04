package httpapi

import (
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/services"
)

type deviceResponse struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Detail       string `json:"detail"`
	IP           string `json:"ip"`
	IsCurrent    bool   `json:"is_current"`
	LastActiveAt string `json:"last_active_at"`
	CreatedAt    string `json:"created_at"`
}

func newDeviceResponse(d services.DeviceView) deviceResponse {
	return deviceResponse{
		ID:           d.ID,
		Name:         d.Name,
		Detail:       d.Detail,
		IP:           d.IP,
		IsCurrent:    d.IsCurrent,
		LastActiveAt: formatTime(d.LastActiveAt),
		CreatedAt:    formatTime(d.CreatedAt),
	}
}

type securityEventResponse struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	Title     string `json:"title"`
	Detail    string `json:"detail"`
	IP        string `json:"ip"`
	Device    string `json:"device"`
	CreatedAt string `json:"created_at"`
}

func newSecurityEventResponse(e domain.SecurityEvent) securityEventResponse {
	return securityEventResponse{
		ID:        e.ID,
		Type:      string(e.Type),
		Title:     e.Title,
		Detail:    e.Detail,
		IP:        e.IP,
		Device:    e.Device,
		CreatedAt: formatTime(e.CreatedAt),
	}
}

type notificationResponse struct {
	ID        string `json:"id"`
	Category  string `json:"category"`
	Title     string `json:"title"`
	Body      string `json:"body"`
	IsRead    bool   `json:"is_read"`
	CreatedAt string `json:"created_at"`
}

func newNotificationResponse(n domain.Notification) notificationResponse {
	return notificationResponse{
		ID:        n.ID,
		Category:  string(n.Category),
		Title:     n.Title,
		Body:      n.Body,
		IsRead:    n.IsRead,
		CreatedAt: formatTime(n.CreatedAt),
	}
}

func formatTime(t time.Time) string {
	return t.UTC().Format("2006-01-02T15:04:05Z")
}
