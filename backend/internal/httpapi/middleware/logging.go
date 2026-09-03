package middleware

import (
	"log"
	"net/http"
	"time"
)

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

// Logging emits a structured request line including the request ID, method,
// path, status, and duration. The request ID enables cross-referencing with
// error envelopes returned to clients.
func Logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		log.Printf("id=%s method=%s path=%s status=%d dur=%s",
			RequestIDFrom(r.Context()), r.Method, r.URL.Path, rec.status, time.Since(start))
	})
}
