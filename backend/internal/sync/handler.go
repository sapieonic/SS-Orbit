package sync

import (
	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/commands"
)

// handler implements StrictServerInterface: DTO <-> domain mapping only.
// FA endpoints are in handler_fa.go, HO review in handler_admin.go.
type handler struct {
	svc *Service
}

var _ StrictServerInterface = (*handler)(nil)

func toResultDTO(commandID uuid.UUID, r commands.Result) CommandResult {
	out := CommandResult{
		Id:         commandID,
		Status:     CommandStatus(r.Status),
		EntityId:   nonNil(r.EntityID),
		MergedInto: r.MergedInto,
		Error:      r.Error,
	}
	if r.Conflict != nil {
		out.Conflict = &Conflict{Field: r.Conflict.Field, Yours: r.Conflict.Yours, Theirs: r.Conflict.Theirs}
	}
	return out
}

func nonNil(id uuid.UUID) *uuid.UUID {
	if id == uuid.Nil {
		return nil
	}
	return &id
}
