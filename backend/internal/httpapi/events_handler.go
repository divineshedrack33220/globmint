package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/events"
	"globmint/backend/internal/httpapi/middleware"
)

// handleEvents streams server-pushed change notifications to the browser via
// Server-Sent Events. Each authenticated connection receives only its own
// user's events, is kept alive with heartbeat comments, and relies on the
// standard SSE client protocol for automatic reconnection.
func (d *Deps) handleEvents(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Events == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}

	// SSE holds the connection open longer than the server's 10s write
	// timeout; clear the per-connection write deadline.
	_ = http.NewResponseController(w).SetWriteDeadline(time.Time{})
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("X-Accel-Buffering", "no")

	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}

	sub := d.Events.Subscribe(user.ID)
	defer d.Events.Unsubscribe(user.ID, sub)

	// Announce the (re)connection so clients refresh state that may have
	// gone stale while they were offline.
	d.writeSSE(w, flusher, events.Event{
		Type: "connected", UserID: user.ID, Kind: "all", At: time.Now().UTC().Format(time.RFC3339),
	})

	heartbeat := time.NewTicker(25 * time.Second)
	defer heartbeat.Stop()

	for {
		select {
		case <-r.Context().Done():
			return
		case <-heartbeat.C:
			fmt.Fprint(w, ": keepalive\n\n")
			flusher.Flush()
		case e := <-sub.Ch:
			d.writeSSE(w, flusher, e)
		}
	}
}

// publish notifies the user's SSE subscribers that their financial data
// changed. Conveniently a no-op when the hub is not configured (tests/dev).
func (d *Deps) publish(userID, kind string) {
	if d.Events == nil {
		return
	}
	d.Events.Publish(events.Event{
		Type: "data.changed", UserID: userID, Kind: kind,
		At: time.Now().UTC().Format(time.RFC3339),
	})
}

func (d *Deps) writeSSE(w http.ResponseWriter, flusher http.Flusher, e events.Event) {
	b, err := json.Marshal(e)
	if err != nil {
		return
	}
	fmt.Fprintf(w, "event: %s\ndata: %s\n\n", e.Type, b)
	flusher.Flush()
}