package sync

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/sync/store"
)

const (
	listDefaultLimit = 50
	listMaxLimit     = 200
)

// ListCommands lists stored commands newest first, for HO to review
// conflicts and rejections. Admin and ops only. Commands carry no district,
// so HO users with an area scope are refused (as in the audit log).
func (s *Service) ListCommands(ctx context.Context, f Filter, limit *int, cursor *string) (paging.Page[CommandRecord], error) {
	p, err := auth.RequireRole(ctx, auth.RoleAdmin, auth.RoleOps)
	if err != nil {
		return paging.Page[CommandRecord]{}, err
	}
	if p.HasAreaScope() {
		return paging.Page[CommandRecord]{}, apperr.Forbidden("sync commands are only available to HO users without an area scope")
	}
	if f.From != nil && f.To != nil && !f.To.After(*f.From) {
		return paging.Page[CommandRecord]{}, apperr.Validation("to", "must be after from")
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[CommandRecord]{}, err
	}
	n := paging.Limit(limit, listDefaultLimit, listMaxLimit)
	var status *string
	if f.Status != nil {
		st := string(*f.Status)
		status = &st
	}
	rows, err := s.q.ListSyncCommands(ctx, store.ListSyncCommandsParams{
		FaID:     nullUUID(f.FAID),
		Status:   status,
		Type:     f.Type,
		FromTime: utc(f.From),
		ToTime:   utc(f.To),
		CursorAt: cur.AtPtr(),
		CursorID: cur.IDNull(),
		RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[CommandRecord]{}, apperr.Internalf("sync: list commands: %w", err)
	}
	return paging.Map(paging.Build(rows, n, rowCursor), toCommandRecord), nil
}

func rowCursor(r store.ListSyncCommandsRow) paging.Cursor {
	return paging.Cursor{At: r.SyncCommand.ReceivedAt, ID: r.SyncCommand.ID}
}

func toCommandRecord(lr store.ListSyncCommandsRow) CommandRecord {
	r := lr.SyncCommand
	c := CommandRecord{
		FailedAttempts:  lr.FailedAttempts,
		LastError:       lr.LastError,
		ID:              r.ID,
		FAID:            r.FaID,
		Type:            r.Type,
		Status:          commands.Status(r.Status),
		Payload:         r.Payload,
		ClientCreatedAt: utc(r.ClientCreatedAt),
		ReceivedAt:      r.ReceivedAt.UTC(),
	}
	if r.DeviceID.Valid {
		c.DeviceID = &r.DeviceID.UUID
	}
	// The result was written by this module from a commands.Result; if it
	// ever fails to decode, the row's status still shows.
	if err := json.Unmarshal(r.Result, &c.Result); err != nil {
		c.Result = commands.Result{Status: c.Status}
	}
	return c
}

func nullUUID(id *uuid.UUID) uuid.NullUUID {
	if id == nil {
		return uuid.NullUUID{}
	}
	return uuid.NullUUID{UUID: *id, Valid: true}
}

func utc(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	u := t.UTC()
	return &u
}
