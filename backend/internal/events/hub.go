// Package events implements an in-process change-notification hub that fans
// ledger/vault events out to authenticated Server-Sent Events (SSE) clients.
package events

import "sync"

// Event is a server-pushed change notification. Kind tells clients which
// cached providers to refresh: "account", "vault", "transactions" or "all".
type Event struct {
	Type   string `json:"type"`
	UserID string `json:"user_id"`
	Kind   string `json:"kind"`
	At     string `json:"at"`
}

// Sub is a single subscriber's delivery channel.
type Sub struct {
	id uint64
	Ch chan Event
}

// Hub fans events out to per-user subscribers. Publishing is a cheap no-op
// when a user has no connected clients, so the hot path stays untouched.
type Hub struct {
	mu   sync.Mutex
	next uint64
	subs map[string]map[uint64]chan Event
}

// subBuffer bounds per-connection buffering; slow clients drop events rather
// than blocking publishers (a fresh SSE reconnect re-syncs state anyway).
const subBuffer = 32

// NewHub returns an empty hub.
func NewHub() *Hub {
	return &Hub{subs: make(map[string]map[uint64]chan Event)}
}

// Subscribe registers a new delivery channel for userID.
func (h *Hub) Subscribe(userID string) *Sub {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.next++
	s := &Sub{id: h.next, Ch: make(chan Event, subBuffer)}
	if h.subs[userID] == nil {
		h.subs[userID] = make(map[uint64]chan Event)
	}
	h.subs[userID][s.id] = s.Ch
	return s
}

// Unsubscribe removes a previously registered subscription. Safe to call twice.
func (h *Hub) Unsubscribe(userID string, s *Sub) {
	if s == nil {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if m := h.subs[userID]; m != nil {
		delete(m, s.id)
		if len(m) == 0 {
			delete(h.subs, userID)
		}
	}
}

// Publish delivers the event to every subscriber of e.UserID, dropping it for
// slow consumers rather than backpressuring the business logic.
func (h *Hub) Publish(e Event) {
	h.mu.Lock()
	m := h.subs[e.UserID]
	if len(m) == 0 {
		h.mu.Unlock()
		return
	}
	chs := make([]chan Event, 0, len(m))
	for _, ch := range m {
		chs = append(chs, ch)
	}
	h.mu.Unlock()
	for _, ch := range chs {
		select {
		case ch <- e:
		default:
		}
	}
}