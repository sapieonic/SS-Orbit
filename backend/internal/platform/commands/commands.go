// Package commands is the registry for FA offline sync commands (CONVENTIONS
// section 6). The sync module stores each command once and calls
// Registry.Dispatch; the owning module registers a Handler per command type in
// its RegisterCommands method.
//
// Handlers run their own transaction (db.WithTx) and must be idempotent for
// the same command / entity IDs: a retried command must produce the same
// Result without duplicating writes.
package commands

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
)

// Status is the outcome of a command.
type Status string

const (
	StatusApplied  Status = "applied"  // change written
	StatusMerged   Status = "merged"   // entity already existed; merged into MergedInto
	StatusConflict Status = "conflict" // server copy changed; see Conflict
	StatusRejected Status = "rejected" // invalid; see Error. The phone shows it and drops the command.
)

// Conflict describes a field-level conflict for the FA app to show.
type Conflict struct {
	Field  string `json:"field"`
	Yours  any    `json:"yours"`
	Theirs any    `json:"theirs"`
}

// Result is stored in sync_commands.result and returned to the phone.
type Result struct {
	Status     Status     `json:"status"`
	EntityID   uuid.UUID  `json:"entity_id"`
	MergedInto *uuid.UUID `json:"merged_into,omitempty"`
	Conflict   *Conflict  `json:"conflict,omitempty"`
	Error      *string    `json:"error,omitempty"`
}

// Applied builds an applied result.
func Applied(entityID uuid.UUID) Result { return Result{Status: StatusApplied, EntityID: entityID} }

// Merged builds a merged result.
func Merged(entityID, into uuid.UUID) Result {
	return Result{Status: StatusMerged, EntityID: entityID, MergedInto: &into}
}

// Conflicted builds a conflict result.
func Conflicted(entityID uuid.UUID, c Conflict) Result {
	return Result{Status: StatusConflict, EntityID: entityID, Conflict: &c}
}

// Rejected builds a rejected result with a human-readable reason.
func Rejected(entityID uuid.UUID, reason string) Result {
	return Result{Status: StatusRejected, EntityID: entityID, Error: &reason}
}

// Command is one command from the phone.
type Command struct {
	ID              uuid.UUID       `json:"id"`
	Type            string          `json:"type"`
	Payload         json.RawMessage `json:"payload"`
	ClientCreatedAt *time.Time      `json:"client_created_at,omitempty"`
}

// Handler applies one command for principal p (an FA).
//
// Return a Result for every business outcome (including rejected/conflict).
// Returning an apperr Validation/NotFound/Forbidden/Conflict error is also
// fine: Dispatch converts it to a rejected Result. Any other error means
// "infrastructure failure, retry later" and is passed through.
type Handler func(ctx context.Context, p auth.Principal, cmd Command) (Result, error)

// Typed adapts a handler that takes a decoded payload of type T. A payload
// that does not decode, or that carries a NUL character in any string
// (Postgres text cannot store it), becomes a rejected Result.
func Typed[T any](fn func(ctx context.Context, p auth.Principal, cmd Command, payload T) (Result, error)) Handler {
	return func(ctx context.Context, p auth.Principal, cmd Command) (Result, error) {
		var v T
		if err := json.Unmarshal(cmd.Payload, &v); err != nil {
			return Rejected(uuid.Nil, "invalid payload: "+err.Error()), nil
		}
		if hasNUL(cmd.Payload) {
			return Rejected(uuid.Nil, "invalid payload: text must not contain NUL characters"), nil
		}
		return fn(ctx, p, cmd, v)
	}
}

// hasNUL reports whether any JSON string (key or value) in raw contains U+0000.
// A raw NUL byte is invalid JSON, so only the escaped form can reach here;
// decoding generically catches every spelling of the escape.
func hasNUL(raw json.RawMessage) bool {
	if !bytes.Contains(raw, []byte(`\u0000`)) {
		return false // fast path: no escape that could decode to NUL
	}
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return false
	}
	return containsNUL(v)
}

func containsNUL(v any) bool {
	switch x := v.(type) {
	case string:
		return strings.ContainsRune(x, 0)
	case []any:
		for _, e := range x {
			if containsNUL(e) {
				return true
			}
		}
	case map[string]any:
		for k, e := range x {
			if strings.ContainsRune(k, 0) || containsNUL(e) {
				return true
			}
		}
	}
	return false
}

// Registry maps command type to handler. Safe for concurrent use; registration
// happens at startup.
type Registry struct {
	mu       sync.RWMutex
	handlers map[string]Handler
}

// NewRegistry returns an empty registry.
func NewRegistry() *Registry { return &Registry{handlers: map[string]Handler{}} }

// Register adds a handler. It panics on an empty type or a duplicate, which
// is a wiring bug caught at startup.
func (r *Registry) Register(typ string, h Handler) {
	if typ == "" || h == nil {
		panic("commands: empty type or nil handler")
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, dup := r.handlers[typ]; dup {
		panic(fmt.Sprintf("commands: duplicate handler for %q", typ))
	}
	r.handlers[typ] = h
}

// Types returns registered command types, sorted.
func (r *Registry) Types() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]string, 0, len(r.handlers))
	for t := range r.handlers {
		out = append(out, t)
	}
	sort.Strings(out)
	return out
}

// Dispatch runs the handler for cmd.Type. Unknown types, business errors and
// Postgres data/constraint errors (SQLSTATE classes 22 and 23: the payload,
// not the server, is at fault) become rejected Results, so one bad command can
// never block an FA's queue. Only infrastructure errors are returned.
func (r *Registry) Dispatch(ctx context.Context, p auth.Principal, cmd Command) (Result, error) {
	r.mu.RLock()
	h, ok := r.handlers[cmd.Type]
	r.mu.RUnlock()
	if !ok {
		return Rejected(uuid.Nil, fmt.Sprintf("unknown command type %q", cmd.Type)), nil
	}
	res, err := h(ctx, p, cmd)
	if err == nil {
		return res, nil
	}
	if e, ok := apperr.As(err); ok {
		switch e.Kind {
		case apperr.KindValidation, apperr.KindNotFound, apperr.KindForbidden, apperr.KindConflict:
			out := Rejected(res.EntityID, e.Message)
			return out, nil
		}
	}
	if reason, ok := dataErrorReason(err); ok {
		return Rejected(res.EntityID, reason), nil
	}
	return Result{}, err
}

// dataErrorReason maps a Postgres data exception (class 22) or integrity
// constraint violation (class 23) to a short reason safe to show on the phone.
// The SQL text and constraint names are never included.
func dataErrorReason(err error) (string, bool) {
	code := db.PgErrorCode(err)
	if len(code) != 5 {
		return "", false
	}
	switch {
	case code == "22021":
		return "invalid_text: contains characters that cannot be stored", true
	case strings.HasPrefix(code, "22"):
		return "invalid_data: a value is out of range or badly formatted", true
	case code == db.CodeUniqueViolation:
		return "constraint_violation: duplicate value", true
	case code == db.CodeForeignKeyViolation:
		return "constraint_violation: refers to a record that does not exist", true
	case strings.HasPrefix(code, "23"):
		return "constraint_violation: a value is missing or not allowed", true
	}
	return "", false
}
