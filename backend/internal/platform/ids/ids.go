// Package ids mints identifiers. All server-created IDs are UUIDv7 (time
// ordered, so they index well and sort by creation). IDs minted offline on the
// FA phone are also UUIDv7 and are accepted as-is.
package ids

import "github.com/google/uuid"

// New returns a new UUIDv7. It panics only if the system random source fails.
func New() uuid.UUID {
	return uuid.Must(uuid.NewV7())
}

// Parse parses a UUID string in canonical form.
func Parse(s string) (uuid.UUID, error) {
	return uuid.Parse(s)
}
