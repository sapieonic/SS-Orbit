// Package paging implements the list convention from CONVENTIONS section 4:
// `?limit=&cursor=` in, `{"items": [...], "next_cursor": "..."}` out, keyset
// on (created_at, id) — or another (timestamp, id) pair such as audit_log's
// (occurred_at, id).
//
// The cursor is opaque to clients (base64url of "<unix-nanos>:<uuid>").
//
// Typical service code:
//
//	limit := paging.Limit(req.Limit, 50, 200)
//	cur, err := paging.Decode(req.Cursor)            // zero Cursor when empty
//	rows, err := q.ListX(ctx, store.ListXParams{CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), Lim: int32(limit + 1)})
//	page := paging.Build(rows, limit, func(r store.X) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} })
package paging

import (
	"encoding/base64"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
)

// Cursor is a keyset position: the last row's (timestamp, id).
type Cursor struct {
	At time.Time
	ID uuid.UUID
}

// IsZero reports whether c is the "first page" cursor.
func (c Cursor) IsZero() bool { return c.ID == uuid.Nil && c.At.IsZero() }

// AtPtr returns the timestamp as a nullable sqlc parameter (nil for first page).
func (c Cursor) AtPtr() *time.Time {
	if c.IsZero() {
		return nil
	}
	t := c.At
	return &t
}

// IDNull returns the id as a nullable sqlc parameter.
func (c Cursor) IDNull() uuid.NullUUID { return uuid.NullUUID{UUID: c.ID, Valid: !c.IsZero()} }

// Encode returns the opaque cursor string ("" for the zero cursor).
func (c Cursor) Encode() string {
	if c.IsZero() {
		return ""
	}
	raw := strconv.FormatInt(c.At.UnixNano(), 10) + ":" + c.ID.String()
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// Decode parses a cursor; nil or "" gives the zero cursor. A malformed cursor
// is apperr BadRequest "invalid_cursor".
func Decode(s *string) (Cursor, error) {
	if s == nil || *s == "" {
		return Cursor{}, nil
	}
	bad := apperr.BadRequest("invalid_cursor", "cursor is not valid")
	raw, err := base64.RawURLEncoding.DecodeString(*s)
	if err != nil {
		return Cursor{}, bad
	}
	ts, id, ok := strings.Cut(string(raw), ":")
	if !ok {
		return Cursor{}, bad
	}
	n, err := strconv.ParseInt(ts, 10, 64)
	if err != nil {
		return Cursor{}, bad
	}
	u, err := uuid.Parse(id)
	if err != nil {
		return Cursor{}, bad
	}
	return Cursor{At: time.Unix(0, n).UTC(), ID: u}, nil
}

// Limit clamps a requested page size: nil or <= 0 gives def, above max gives max.
func Limit(requested *int, def, max int) int {
	if requested == nil || *requested <= 0 {
		return def
	}
	if *requested > max {
		return max
	}
	return *requested
}

// Page is a page of items plus the cursor for the next page (nil at the end).
type Page[T any] struct {
	Items      []T
	NextCursor *string
}

// Build turns rows fetched with LIMIT limit+1 into a Page: if there are more
// than limit rows, the extra one is dropped and NextCursor points after the
// last returned row.
func Build[T any](rows []T, limit int, key func(T) Cursor) Page[T] {
	if len(rows) <= limit {
		if rows == nil {
			rows = []T{}
		}
		return Page[T]{Items: rows}
	}
	rows = rows[:limit]
	next := key(rows[len(rows)-1]).Encode()
	return Page[T]{Items: rows, NextCursor: &next}
}

// Map converts a page's items, keeping the cursor.
func Map[T, U any](p Page[T], fn func(T) U) Page[U] {
	out := make([]U, len(p.Items))
	for i, it := range p.Items {
		out[i] = fn(it)
	}
	return Page[U]{Items: out, NextCursor: p.NextCursor}
}
