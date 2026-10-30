package audit

import (
	"context"
	"encoding/json"

	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// handler implements StrictServerInterface. It only maps between generated
// DTOs and the service; errors from the service are returned unchanged and
// written by httpx.ResponseErrorHandler in the shared error shape.
type handler struct {
	svc *Service
}

var _ StrictServerInterface = (*handler)(nil)

func (h *handler) ListAuditEvents(ctx context.Context, req ListAuditEventsRequestObject) (ListAuditEventsResponseObject, error) {
	p := req.Params
	page, err := h.svc.List(ctx, Filter{
		EntityType:   p.EntityType,
		EntityID:     p.EntityId,
		ActorID:      p.ActorId,
		FarmerID:     p.FarmerId,
		ActionPrefix: p.Action,
		From:         p.From,
		To:           p.To,
	}, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	return ListAuditEvents200JSONResponse(toPageDTO(page)), nil
}

func (h *handler) GetAuditChain(ctx context.Context, req GetAuditChainRequestObject) (GetAuditChainResponseObject, error) {
	page, err := h.svc.Chain(ctx, req.EntityType, req.EntityId, req.Params.Limit, req.Params.Cursor)
	if err != nil {
		return nil, err
	}
	return GetAuditChain200JSONResponse(toPageDTO(page)), nil
}

func toPageDTO(p paging.Page[Event]) AuditEventPage {
	items := make([]AuditEvent, len(p.Items))
	for i, e := range p.Items {
		items[i] = toDTO(e)
	}
	return AuditEventPage{Items: items, NextCursor: p.NextCursor}
}

func toDTO(e Event) AuditEvent {
	return AuditEvent{
		Id:         e.ID,
		OccurredAt: e.OccurredAt,
		ActorKind:  AuditEventActorKind(e.ActorKind),
		ActorId:    e.ActorID,
		OnBehalfOf: e.OnBehalfOf,
		Action:     e.Action,
		EntityType: e.EntityType,
		EntityId:   e.EntityID,
		FarmerId:   e.FarmerID,
		PlotId:     e.PlotID,
		SeasonId:   e.SeasonID,
		Before:     jsonObject(e.Before),
		After:      jsonObject(e.After),
		Meta:       jsonObject(e.Meta),
		Ip:         e.IP,
		DeviceId:   e.DeviceID,
		RequestId:  e.RequestID,
	}
}

// jsonObject decodes a stored JSON snapshot for the response. Non-object
// values (arrays, scalars) are wrapped as {"value": ...} to fit the schema.
func jsonObject(raw json.RawMessage) *map[string]any {
	if len(raw) == 0 || string(raw) == "null" {
		return nil
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err == nil {
		return &m
	}
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return nil
	}
	return &map[string]any{"value": v}
}
