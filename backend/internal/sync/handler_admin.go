package sync

import (
	"context"
	"encoding/json"

	"github.com/sapionic/orbit/backend/internal/platform/commands"
)

func (h *handler) ListSyncCommands(ctx context.Context, req ListSyncCommandsRequestObject) (ListSyncCommandsResponseObject, error) {
	p := req.Params
	f := Filter{FAID: p.FaId, Type: p.Type, From: p.From, To: p.To}
	if p.Status != nil {
		st := commands.Status(*p.Status)
		f.Status = &st
	}
	page, err := h.svc.ListCommands(ctx, f, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	items := make([]StoredCommand, len(page.Items))
	for i, c := range page.Items {
		items[i] = toStoredDTO(c)
	}
	return ListSyncCommands200JSONResponse{Items: items, NextCursor: page.NextCursor}, nil
}

func toStoredDTO(c CommandRecord) StoredCommand {
	return StoredCommand{
		Id:              c.ID,
		FaId:            c.FAID,
		DeviceId:        c.DeviceID,
		Type:            c.Type,
		Status:          CommandStatus(c.Status),
		Payload:         jsonObject(c.Payload),
		Result:          toResultDTO(c.ID, c.Result),
		ClientCreatedAt: c.ClientCreatedAt,
		ReceivedAt:      c.ReceivedAt,
		FailedAttempts:  c.FailedAttempts,
		LastError:       c.LastError,
	}
}

// jsonObject decodes a stored payload for the response. Payloads are JSON
// objects (the spec requires it); anything else is wrapped as {"value": ...}.
func jsonObject(raw json.RawMessage) map[string]any {
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err == nil && m != nil {
		return m
	}
	var v any
	_ = json.Unmarshal(raw, &v)
	return map[string]any{"value": v}
}
