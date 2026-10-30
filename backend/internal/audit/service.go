package audit

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/audit/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// Page sizes.
const (
	listDefaultLimit  = 50
	listMaxLimit      = 200
	chainDefaultLimit = 200
	chainMaxLimit     = 500
)

// queries is the subset of the generated store the service uses. Declaring it
// here (instead of using store.Querier) keeps test fakes small.
type queries interface {
	ListAuditEvents(ctx context.Context, arg store.ListAuditEventsParams) ([]store.AuditLog, error)
	ListEntityChain(ctx context.Context, arg store.ListEntityChainParams) ([]store.AuditLog, error)
}

// Service implements audit log reads.
type Service struct {
	q     queries
	ports *Ports
}

// NewService builds the service on q (store.New(pool) in production).
func NewService(q queries, ports *Ports) *Service {
	if ports == nil {
		ports = &Ports{}
	}
	return &Service{q: q, ports: ports}
}

// authorize allows admin, finance and ops (not agronomy). Audit rows carry no
// district, so HO users with an area scope cannot be filtered and are refused.
func authorize(ctx context.Context) error {
	p, err := auth.RequireRole(ctx, auth.RoleAdmin, auth.RoleFinance, auth.RoleOps)
	if err != nil {
		return err
	}
	if p.HasAreaScope() {
		return apperr.Forbidden("the audit log is only available to HO users without an area scope")
	}
	return nil
}

// List searches the log, newest first.
func (s *Service) List(ctx context.Context, f Filter, limit *int, cursor *string) (paging.Page[Event], error) {
	if err := authorize(ctx); err != nil {
		return paging.Page[Event]{}, err
	}
	if f.From != nil && f.To != nil && !f.To.After(*f.From) {
		return paging.Page[Event]{}, apperr.Validation("to", "must be after from")
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[Event]{}, err
	}
	n := paging.Limit(limit, listDefaultLimit, listMaxLimit)
	rows, err := s.q.ListAuditEvents(ctx, store.ListAuditEventsParams{
		EntityType:   f.EntityType,
		EntityID:     nullUUID(f.EntityID),
		ActorID:      nullUUID(f.ActorID),
		FarmerID:     nullUUID(f.FarmerID),
		ActionPrefix: f.ActionPrefix,
		FromTime:     utc(f.From),
		ToTime:       utc(f.To),
		CursorAt:     cur.AtPtr(),
		CursorID:     cur.IDNull(),
		RowLimit:     int32(n + 1), // one extra row tells us there is a next page
	})
	if err != nil {
		return paging.Page[Event]{}, apperr.Internalf("audit: list: %w", err)
	}
	return paging.Map(paging.Build(rows, n, rowCursor), toEvent), nil
}

// Chain returns every event for one record, oldest first.
func (s *Service) Chain(ctx context.Context, entityType string, entityID uuid.UUID, limit *int, cursor *string) (paging.Page[Event], error) {
	if err := authorize(ctx); err != nil {
		return paging.Page[Event]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[Event]{}, err
	}
	n := paging.Limit(limit, chainDefaultLimit, chainMaxLimit)
	rows, err := s.q.ListEntityChain(ctx, store.ListEntityChainParams{
		EntityType: entityType,
		EntityID:   uuid.NullUUID{UUID: entityID, Valid: true},
		CursorAt:   cur.AtPtr(),
		CursorID:   cur.IDNull(),
		RowLimit:   int32(n + 1),
	})
	if err != nil {
		return paging.Page[Event]{}, apperr.Internalf("audit: chain: %w", err)
	}
	return paging.Map(paging.Build(rows, n, rowCursor), toEvent), nil
}

func rowCursor(r store.AuditLog) paging.Cursor { return paging.Cursor{At: r.OccurredAt, ID: r.ID} }

func toEvent(r store.AuditLog) Event {
	e := Event{
		ID:         r.ID,
		OccurredAt: r.OccurredAt.UTC(),
		ActorKind:  r.ActorKind,
		ActorID:    uuidPtr(r.ActorID),
		OnBehalfOf: uuidPtr(r.OnBehalfOf),
		Action:     r.Action,
		EntityType: r.EntityType,
		EntityID:   uuidPtr(r.EntityID),
		FarmerID:   uuidPtr(r.FarmerID),
		PlotID:     uuidPtr(r.PlotID),
		SeasonID:   uuidPtr(r.SeasonID),
		Before:     r.Before,
		After:      r.After,
		Meta:       r.Meta,
		DeviceID:   r.DeviceID,
		RequestID:  r.RequestID,
	}
	if r.Ip != nil {
		s := r.Ip.String()
		e.IP = &s
	}
	return e
}

func nullUUID(id *uuid.UUID) uuid.NullUUID {
	if id == nil {
		return uuid.NullUUID{}
	}
	return uuid.NullUUID{UUID: *id, Valid: true}
}

func uuidPtr(n uuid.NullUUID) *uuid.UUID {
	if !n.Valid {
		return nil
	}
	return &n.UUID
}

func utc(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	u := t.UTC()
	return &u
}
