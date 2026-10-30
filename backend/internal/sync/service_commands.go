package sync

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/sync/store"
)

// SubmitBatch processes an FA's offline commands in order (CONVENTIONS
// section 6).
//
// Each command ID is an idempotency key. A command already in sync_commands
// for this FA returns its stored result without dispatching again; an ID
// stored for another FA is rejected. New commands are dispatched to the
// owning module's handler (which runs its own transaction) and the result is
// stored afterwards.
//
// An infrastructure error (non-nil error from Dispatch, or from storing the
// result) stops the batch: the results so far are returned with RetryFrom set
// to the failed index, and nothing is stored for the failed command, so the
// phone resends it later. If the handler had already committed, the resend
// replays it, which handlers must treat idempotently. Failures are counted per
// command ID (sync_command_failures); on the MaxCommandAttempts-th failure the
// command is stored as rejected (ReasonServerCouldNotApply) and the batch goes
// on, so one command the server can never apply does not block the FA's queue
// forever. HO sees these in the admin commands list.
//
// The same command can arrive twice concurrently (the phone retried after a
// timeout while the first request was still running). Both requests may
// dispatch it; the handler's own idempotency (entity IDs minted on the phone,
// unique keys) keeps the write single. The sync_commands primary key then
// decides: the first insert wins, the second insert does nothing and that
// request returns the stored row's result, so both responses agree.
func (s *Service) SubmitBatch(ctx context.Context, cmds []commands.Command) (BatchResult, error) {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return BatchResult{}, err
	}
	if len(cmds) == 0 || len(cmds) > MaxBatch {
		return BatchResult{}, apperr.Validation("commands", fmt.Sprintf("must have 1 to %d items", MaxBatch))
	}

	ids := make([]uuid.UUID, len(cmds))
	for i, c := range cmds {
		ids[i] = c.ID
	}
	rows, err := s.q.GetSyncCommandsByIDs(ctx, ids)
	if err != nil {
		return BatchResult{}, apperr.Internalf("sync: look up commands: %w", err)
	}
	known := make(map[uuid.UUID]store.SyncCommand, len(rows))
	for _, r := range rows {
		known[r.ID] = r
	}

	out := BatchResult{Outcomes: make([]Outcome, 0, len(cmds))}
	for i, cmd := range cmds {
		_, wasKnown := known[cmd.ID]
		res, err := s.runOne(ctx, p, cmd, known)
		if err != nil && !wasKnown {
			res, err = s.afterFailure(ctx, p, cmd, known, err)
		}
		if err != nil {
			logx.From(ctx).WarnContext(ctx, "sync: command failed; batch stopped for retry",
				"command_id", cmd.ID, "type", cmd.Type, "index", i, "err", err)
			idx := i
			out.RetryFrom = &idx
			break
		}
		out.Outcomes = append(out.Outcomes, Outcome{CommandID: cmd.ID, Result: res})
	}

	// Read after processing: the commands themselves usually bump the
	// territory, and the phone uses these to decide whether to re-pull.
	if out.Versions, err = s.versions(ctx, p.ID); err != nil {
		return BatchResult{}, err
	}
	if out.RetryFrom == nil {
		s.markSynced(ctx, p.ID, p.DeviceID)
	}
	return out, nil
}

// runOne returns the stored result for a known command, or dispatches and
// stores a new one. known is updated so a repeated ID later in the same batch
// is answered from the store too.
func (s *Service) runOne(ctx context.Context, p auth.Principal, cmd commands.Command, known map[uuid.UUID]store.SyncCommand) (commands.Result, error) {
	if row, ok := known[cmd.ID]; ok {
		return storedResult(ctx, p, row)
	}
	res, err := s.deps.Commands.Dispatch(ctx, p, cmd)
	if err != nil {
		return commands.Result{}, fmt.Errorf("dispatch %s: %w", cmd.Type, err)
	}
	if !validStatus(res.Status) {
		// A handler bug. Not storing it keeps the command on the phone instead
		// of silently dropping the FA's work as "rejected".
		return commands.Result{}, fmt.Errorf("handler for %s returned invalid status %q", cmd.Type, res.Status)
	}
	row, err := s.storeResult(ctx, p, cmd, res)
	if err != nil {
		return commands.Result{}, err
	}
	known[cmd.ID] = row
	return storedResult(ctx, p, row)
}

// afterFailure counts an infrastructure failure of a new command. Before the
// limit it returns cause (the batch stops and the phone retries). On the
// limit it stores the command as rejected and returns that result. If the
// failure cannot even be counted (database down), cause is returned.
func (s *Service) afterFailure(ctx context.Context, p auth.Principal, cmd commands.Command, known map[uuid.UUID]store.SyncCommand, cause error) (commands.Result, error) {
	attempts, err := s.q.RecordSyncCommandFailure(ctx, store.RecordSyncCommandFailureParams{
		ID:        cmd.ID,
		FaID:      p.ID,
		Type:      cmd.Type,
		LastError: truncate(cause.Error(), maxErrorLen),
		At:        s.deps.Clock.Now(),
	})
	if err != nil {
		logx.From(ctx).WarnContext(ctx, "sync: could not count command failure", "command_id", cmd.ID, "err", err)
		return commands.Result{}, cause
	}
	if attempts < MaxCommandAttempts {
		return commands.Result{}, cause
	}
	logx.From(ctx).ErrorContext(ctx, "sync: command dead-lettered after repeated failures",
		"command_id", cmd.ID, "type", cmd.Type, "attempts", attempts, "err", cause)
	row, err := s.storeResult(ctx, p, cmd, commands.Rejected(uuid.Nil, ReasonServerCouldNotApply))
	if err != nil {
		return commands.Result{}, err
	}
	known[cmd.ID] = row
	return storedResult(ctx, p, row)
}

// maxErrorLen bounds the stored last_error.
const maxErrorLen = 1000

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// storeResult inserts the command and its result. If a concurrent request
// stored the same command ID first, that row is returned instead.
func (s *Service) storeResult(ctx context.Context, p auth.Principal, cmd commands.Command, res commands.Result) (store.SyncCommand, error) {
	resJSON, err := json.Marshal(res)
	if err != nil {
		return store.SyncCommand{}, fmt.Errorf("encode result: %w", err)
	}
	payload := storablePayload(cmd.Payload)
	row, err := s.q.InsertSyncCommand(ctx, store.InsertSyncCommandParams{
		ID:              cmd.ID,
		FaID:            p.ID,
		DeviceID:        uuid.NullUUID{UUID: p.DeviceID, Valid: p.DeviceID != uuid.Nil},
		Type:            cmd.Type,
		Payload:         payload,
		Status:          string(res.Status),
		Result:          resJSON,
		ClientCreatedAt: utc(cmd.ClientCreatedAt),
		ReceivedAt:      s.deps.Clock.Now(),
	})
	if err == nil {
		return row, nil
	}
	if !db.IsNoRows(err) {
		return store.SyncCommand{}, fmt.Errorf("store command: %w", err)
	}
	row, err = s.q.GetSyncCommand(ctx, cmd.ID)
	if err != nil {
		return store.SyncCommand{}, fmt.Errorf("read concurrently stored command: %w", err)
	}
	return row, nil
}

// storedResult is the answer for a command already in sync_commands. A
// command ID belongs to the FA that first sent it; another FA reusing it is
// rejected (and nothing is stored, the ID is taken).
func storedResult(ctx context.Context, p auth.Principal, row store.SyncCommand) (commands.Result, error) {
	if row.FaID != p.ID {
		logx.From(ctx).WarnContext(ctx, "sync: command id belongs to another FA", "command_id", row.ID, "owner_fa_id", row.FaID)
		return commands.Rejected(uuid.Nil, "this command ID was already used by another field assistant"), nil
	}
	var res commands.Result
	if err := json.Unmarshal(row.Result, &res); err != nil {
		return commands.Result{}, fmt.Errorf("decode stored result %s: %w", row.ID, err)
	}
	return res, nil
}

func validStatus(st commands.Status) bool {
	switch st {
	case commands.StatusApplied, commands.StatusMerged, commands.StatusConflict, commands.StatusRejected:
		return true
	}
	return false
}

// storablePayload returns the payload as it can be kept in jsonb. Postgres
// rejects the \u0000 escape (SQLSTATE 22P05), and a command whose payload
// can't be stored could never be answered, so the copy we keep swaps it for
// U+FFFD. The handler already rejected such a command.
func storablePayload(raw json.RawMessage) json.RawMessage {
	if len(raw) == 0 || string(raw) == "null" {
		return json.RawMessage(`{}`)
	}
	if bytes.Contains(raw, []byte(`\u0000`)) {
		return bytes.ReplaceAll(raw, []byte(`\u0000`), []byte(`\ufffd`))
	}
	return raw
}
