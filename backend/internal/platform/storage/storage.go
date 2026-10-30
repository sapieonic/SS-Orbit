// Package storage abstracts object storage for photos, audio and documents.
// Clients upload and download directly with presigned URLs; the API only
// hands out URLs and checks existence. Keys are module-prefixed paths, e.g.
// "visits/<visit_id>/<photo_id>.jpg".
//
// Dev uses Local (files under STORAGE_DIR, URLs served by the API at
// /dev/files/{key}, HMAC-signed). Production will add an S3-compatible
// implementation of the same interface.
package storage

import (
	"context"
	"errors"
	"io"
	"strings"
	"time"
)

// ErrNotFound is returned by Open for missing keys.
var ErrNotFound = errors.New("storage: object not found")

// Presigned is an upload instruction for a client.
type Presigned struct {
	URL       string            `json:"url"`
	Method    string            `json:"method"`  // "PUT"
	Headers   map[string]string `json:"headers"` // headers the client must send (Content-Type)
	ExpiresAt time.Time         `json:"expires_at"`
}

// Storage is the object store interface. All methods are safe for concurrent use.
type Storage interface {
	// PresignPut returns a URL the client PUTs the object to.
	PresignPut(ctx context.Context, key, contentType string, ttl time.Duration) (Presigned, error)
	// PresignGet returns a URL the client GETs the object from.
	PresignGet(ctx context.Context, key string, ttl time.Duration) (string, error)
	// Exists reports whether an object exists (e.g. to confirm an upload).
	Exists(ctx context.Context, key string) (bool, error)
	// Put writes an object from the server side.
	Put(ctx context.Context, key, contentType string, r io.Reader) error
	// Open reads an object from the server side. Returns ErrNotFound if missing.
	Open(ctx context.Context, key string) (io.ReadCloser, error)
}

// ValidKey reports whether key is a safe relative object key.
func ValidKey(key string) bool {
	if key == "" || len(key) > 512 || strings.HasPrefix(key, "/") || strings.Contains(key, "\\") {
		return false
	}
	for _, part := range strings.Split(key, "/") {
		if part == "" || part == "." || part == ".." {
			return false
		}
	}
	return true
}
