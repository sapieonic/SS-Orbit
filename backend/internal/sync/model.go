package sync

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/commands"
)

// MaxBatch is the most commands one POST /v1/fa/sync/commands may carry (the
// spec enforces it too).
const MaxBatch = 200

// MaxCommandAttempts is how many infrastructure failures a command may hit
// before it is stored as rejected with ReasonServerCouldNotApply.
const MaxCommandAttempts = 5

// ReasonServerCouldNotApply is the rejection reason of a dead-lettered
// command: the server failed to apply it MaxCommandAttempts times.
const ReasonServerCouldNotApply = "server_could_not_apply"

// Outcome is the result of one command in a batch.
type Outcome struct {
	CommandID uuid.UUID
	Result    commands.Result
}

// BatchResult is what SubmitBatch returns.
type BatchResult struct {
	Outcomes []Outcome // one per processed command, in request order
	// RetryFrom is the index of the first command not processed because of an
	// infrastructure failure; nil when the whole batch was processed.
	RetryFrom *int
	Versions  Versions
}

// Versions identify the snapshot an FA should hold. When either changes, the
// app pulls a new snapshot.
type Versions struct {
	Territory int64
	Masters   int64
}

// ETag is the snapshot's entity tag, e.g. "t12-m3" (quotes included).
func (v Versions) ETag() string { return fmt.Sprintf(`"t%d-m%d"`, v.Territory, v.Masters) }

// BuiltSnapshot is a built (or cached) snapshot, or a not-modified answer.
type BuiltSnapshot struct {
	Versions    Versions
	NotModified bool   // If-None-Match matched; Gzip is nil
	Gzip        []byte // gzip-compressed JSON envelope
}

// envelope is the snapshot JSON document (spec schema Snapshot).
type envelope struct {
	TerritoryVersion int64          `json:"territory_version"`
	MastersVersion   int64          `json:"masters_version"`
	GeneratedAt      time.Time      `json:"generated_at"`
	Sections         map[string]any `json:"sections"`
}

// CommandRecord is one sync_commands row for HO review.
type CommandRecord struct {
	ID              uuid.UUID
	FAID            uuid.UUID
	DeviceID        *uuid.UUID
	Type            string
	Status          commands.Status
	Payload         json.RawMessage
	Result          commands.Result
	ClientCreatedAt *time.Time
	ReceivedAt      time.Time
	// FailedAttempts and LastError are set when the server failed to apply the
	// command at least once (a dead-lettered command has MaxCommandAttempts).
	FailedAttempts *int32
	LastError      *string
}

// Filter narrows ListCommands. Nil fields are not filtered on.
type Filter struct {
	FAID   *uuid.UUID
	Status *commands.Status
	Type   *string
	From   *time.Time // inclusive
	To     *time.Time // exclusive
}
