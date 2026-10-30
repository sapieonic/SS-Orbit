package messaging

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Tunables.
const (
	fanoutBatchSize     = 500              // farmers per notice/delivery transaction
	deliveryMaxAttempts = 5                // then the delivery is marked failed
	uploadURLTTL        = 30 * time.Minute // presigned PUT for advisory media
	mediaURLTTL         = time.Hour        // presigned GET for audio/images
	snapshotAlertDays   = 30               // FA snapshot carries alerts this recent
	snapshotAlertLimit  = 200
)

// Service holds the messaging business rules.
type Service struct {
	deps  platform.Deps
	q     *store.Queries
	ports *Ports
}

// NewService builds the service.
func NewService(deps platform.Deps, q *store.Queries, ports *Ports) *Service {
	if ports == nil {
		ports = &Ports{}
	}
	return &Service{deps: deps, q: q, ports: ports}
}

func (s *Service) now() time.Time { return s.deps.Clock.Now() }

// inTx runs fn in a transaction with queries bound to it.
func (s *Service) inTx(ctx context.Context, fn func(tx pgx.Tx, q *store.Queries) error) error {
	return db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error { return fn(tx, s.q.WithTx(tx)) })
}

// farmerSummaries returns the farmers by ID (missing farmers are absent).
func (s *Service) farmerSummaries(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]xmod.FarmerSummary, error) {
	out := make(map[uuid.UUID]xmod.FarmerSummary, len(ids))
	if len(ids) == 0 {
		return out, nil
	}
	list, err := s.ports.Farmers.GetFarmerSummaries(ctx, ids)
	if err != nil {
		return nil, fmt.Errorf("messaging: farmer summaries: %w", err)
	}
	for _, f := range list {
		out[f.ID] = f
	}
	return out, nil
}

// farmerSummary returns one farmer, or apperr.NotFound.
func (s *Service) farmerSummary(ctx context.Context, id uuid.UUID) (xmod.FarmerSummary, error) {
	m, err := s.farmerSummaries(ctx, []uuid.UUID{id})
	if err != nil {
		return xmod.FarmerSummary{}, err
	}
	f, ok := m[id]
	if !ok {
		return xmod.FarmerSummary{}, apperr.NotFound("farmer")
	}
	return f, nil
}

// village returns the village with mandal and district, or nil if unknown.
func (s *Service) village(ctx context.Context, id uuid.NullUUID) (*xmod.Village, error) {
	if !id.Valid {
		return nil, nil
	}
	vs, err := s.ports.Geo.GetVillages(ctx, []uuid.UUID{id.UUID})
	if err != nil {
		return nil, fmt.Errorf("messaging: villages: %w", err)
	}
	for i := range vs {
		if vs[i].ID == id.UUID {
			return &vs[i], nil
		}
	}
	return nil, nil
}

// fieldAssistant returns one FA, or apperr.NotFound.
func (s *Service) fieldAssistant(ctx context.Context, id uuid.UUID) (xmod.FieldAssistant, error) {
	fas, err := s.ports.Identity.GetFieldAssistants(ctx, []uuid.UUID{id})
	if err != nil {
		return xmod.FieldAssistant{}, fmt.Errorf("messaging: field assistants: %w", err)
	}
	for _, fa := range fas {
		if fa.ID == id {
			return fa, nil
		}
	}
	return xmod.FieldAssistant{}, apperr.NotFound("field_assistant")
}

func (s *Service) presignGet(ctx context.Context, key *string) *string {
	if key == nil || *key == "" {
		return nil
	}
	u, err := s.deps.Storage.PresignGet(ctx, *key, mediaURLTTL)
	if err != nil {
		return nil // a missing preview URL must not fail the read
	}
	return &u
}

// Conversions.

func nullUUID(id *uuid.UUID) uuid.NullUUID {
	if id == nil || *id == uuid.Nil {
		return uuid.NullUUID{}
	}
	return uuid.NullUUID{UUID: *id, Valid: true}
}

func someUUID(id uuid.UUID) uuid.NullUUID { return uuid.NullUUID{UUID: id, Valid: id != uuid.Nil} }

func uuidPtr(n uuid.NullUUID) *uuid.UUID {
	if !n.Valid {
		return nil
	}
	id := n.UUID
	return &id
}

func intPtr(n *int32) *int {
	if n == nil {
		return nil
	}
	v := int(*n)
	return &v
}

func utcPtr(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	u := t.UTC()
	return &u
}

func toAdvisory(r store.Advisory) AdvisoryRecord {
	var t Target
	_ = json.Unmarshal(r.Target, &t) // written by this module; shape is known
	t.normalize()
	return AdvisoryRecord{
		ID: r.ID, Sender: r.Sender, TitleTe: r.TitleTe, BodyTe: r.BodyTe, TitleEn: r.TitleEn, BodyEn: r.BodyEn,
		AudioKey: r.AudioKey, ImageKey: r.ImageKey, NamesProduct: r.NamesProduct, Class: r.Class,
		Target: t, Channels: r.Channels, Status: r.Status, ScheduledFor: utcPtr(r.ScheduledFor),
		SentAt: utcPtr(r.SentAt), RecipientCount: intPtr(r.RecipientCount), CreatedBy: r.CreatedBy, UpdatedBy: uuidPtr(r.UpdatedBy),
		ApprovedBy: uuidPtr(r.ApprovedBy), ApprovedAt: utcPtr(r.ApprovedAt), ReviewNote: r.ReviewNote,
		CreatedAt: r.CreatedAt.UTC(), UpdatedAt: r.UpdatedAt.UTC(),
	}
}

func toNotice(r store.Notice) InboxNotice {
	return InboxNotice{
		ID: r.ID, FarmerID: r.FarmerID, Kind: r.Kind, Sender: r.Sender, TitleTe: r.TitleTe, BodyTe: r.BodyTe,
		TitleEn: r.TitleEn, BodyEn: r.BodyEn, RefType: r.RefType, RefID: uuidPtr(r.RefID), Pinned: r.Pinned,
		ReadAt: utcPtr(r.ReadAt), ListenedAt: utcPtr(r.ListenedAt), CreatedAt: r.CreatedAt.UTC(),
	}
}

func toFAAlert(r store.FaAlert) FieldAlert {
	return FieldAlert{
		ID: r.ID, FAID: r.FaID, Kind: r.Kind, FarmerID: uuidPtr(r.FarmerID), RefID: uuidPtr(r.RefID),
		Title: r.Title, Body: r.Body, TitleTe: r.TitleTe, BodyTe: r.BodyTe, Status: r.Status, CreatedAt: r.CreatedAt.UTC(),
		AcknowledgedAt: utcPtr(r.AcknowledgedAt),
	}
}

func toHOAlert(r store.HoAlert) OverviewAlert {
	return OverviewAlert{
		ID: r.ID, Kind: r.Kind, FarmerID: uuidPtr(r.FarmerID), FAID: uuidPtr(r.FaID),
		DistrictID: uuidPtr(r.DistrictID), Payload: r.Payload, CreatedAt: r.CreatedAt.UTC(),
	}
}

// normalize replaces nil lists with empty ones so the stored JSON has arrays.
func (t *Target) normalize() {
	if t.CropIDs == nil {
		t.CropIDs = []uuid.UUID{}
	}
	if t.DistrictIDs == nil {
		t.DistrictIDs = []uuid.UUID{}
	}
	if t.MandalIDs == nil {
		t.MandalIDs = []uuid.UUID{}
	}
	if t.VillageIDs == nil {
		t.VillageIDs = []uuid.UUID{}
	}
	if t.StageCodes == nil {
		t.StageCodes = []string{}
	}
}

func (t Target) toXmod() xmod.FarmerTarget {
	return xmod.FarmerTarget{
		CropIDs: t.CropIDs, DistrictIDs: t.DistrictIDs, MandalIDs: t.MandalIDs,
		VillageIDs: t.VillageIDs, StageCodes: t.StageCodes, Plan: t.Plan,
	}
}

func dedupe[T comparable](in []T) []T {
	out := make([]T, 0, len(in))
	for _, v := range in {
		if !slices.Contains(out, v) {
			out = append(out, v)
		}
	}
	return out
}
