package services

import (
	"crypto/rand"
	"encoding/hex"
)

// newRandRef returns a short random hex reference used to build internal
// transaction references.
func newRandRef() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
