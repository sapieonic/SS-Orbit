package farmers

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// ResolveTerritory is the snapshot scope resolver: the villages the FA covers
// (geo expands mandal and district allocations) and exactly the farmers the FA
// may act on (faMayActOn): those assigned to the FA, deactivated ones left out.
func (s *Service) ResolveTerritory(ctx context.Context, faID uuid.UUID) (territory.Scope, error) {
	villages, err := s.ports.Geo.VillageIDsForFA(ctx, faID)
	if err != nil {
		return territory.Scope{}, apperr.Internalf("farmers: territory villages: %w", err)
	}
	farmerIDs, err := s.q.FarmerIDsAssignedTo(ctx, nullID(faID))
	if err != nil {
		return territory.Scope{}, apperr.Internalf("farmers: territory farmers: %w", err)
	}
	return territory.Scope{FAID: faID, VillageIDs: nonNil(villages), FarmerIDs: farmerIDs}, nil
}

// Snapshot rows. The FA app needs the full phone number (to call), the
// version (for UpdateFarmer/SavePlot) and which consents are granted.

type snapFarmer struct {
	ID                 uuid.UUID  `json:"id"`
	Phone              string     `json:"phone"`
	Name               *string    `json:"name"`
	NameTe             *string    `json:"name_te"`
	Language           string     `json:"language"`
	VillageID          *uuid.UUID `json:"village_id"`
	Source             string     `json:"source"`
	PhotoKey           *string    `json:"photo_key"`
	Plan               string     `json:"plan"`
	Status             string     `json:"status"`
	ConsentsGranted    []string   `json:"consents_granted"`
	ConsentPending     bool       `json:"consent_pending"` // no programme consent yet: send RecordConsent
	ProfileCompletedAt *time.Time `json:"profile_completed_at"`
	Version            int32      `json:"version"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

type snapPlot struct {
	ID           uuid.UUID       `json:"id"`
	FarmerID     uuid.UUID       `json:"farmer_id"`
	Label        string          `json:"label"`
	VillageID    *uuid.UUID      `json:"village_id"`
	Boundary     json.RawMessage `json:"boundary"` // GeoJSON or null
	Pin          *Point          `json:"pin"`
	AreaAcres    float64         `json:"area_acres"`
	AreaSource   string          `json:"area_source"`
	GPSAccuracyM *float64        `json:"gps_accuracy_m"`
	Status       string          `json:"status"`
	Version      int32           `json:"version"`
	UpdatedAt    time.Time       `json:"updated_at"`
}

type snapSeason struct {
	ID             uuid.UUID  `json:"id"`
	FarmerID       uuid.UUID  `json:"farmer_id"`
	PlotID         uuid.UUID  `json:"plot_id"`
	SeasonCode     string     `json:"season_code"`
	CropID         uuid.UUID  `json:"crop_id"`
	SowingDate     *string    `json:"sowing_date"` // YYYY-MM-DD
	PreviousCropID *uuid.UUID `json:"previous_crop_id"`
	Status         string     `json:"status"`
	Version        int32      `json:"version"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

func (s *Service) snapshotFarmers(ctx context.Context, sc territory.Scope) (any, error) {
	ids := nonNil(sc.FarmerIDs)
	rows, err := s.q.ListFarmersByIDs(ctx, ids)
	if err != nil {
		return nil, apperr.Internalf("farmers: snapshot farmers: %w", err)
	}
	consents, err := s.q.CurrentConsents(ctx, ids)
	if err != nil {
		return nil, apperr.Internalf("farmers: snapshot consents: %w", err)
	}
	granted := map[uuid.UUID][]string{}
	asked := map[uuid.UUID]bool{} // has a programme consent row
	for _, c := range consents {
		if c.Granted {
			granted[c.FarmerID] = append(granted[c.FarmerID], c.Purpose)
		}
		if c.Purpose == PurposeProgramme {
			asked[c.FarmerID] = true
		}
	}
	out := make([]snapFarmer, len(rows))
	for i, r := range rows {
		f := toFarmer(r)
		g := granted[r.ID]
		if g == nil {
			g = []string{}
		}
		out[i] = snapFarmer{
			ID: f.ID, Phone: f.Phone, Name: f.Name, NameTe: f.NameTe, Language: f.Language, VillageID: f.VillageID,
			Source: f.Source, PhotoKey: f.PhotoKey, Plan: f.Plan, Status: f.Status, ConsentsGranted: g,
			ConsentPending:     !asked[r.ID],
			ProfileCompletedAt: f.ProfileCompletedAt, Version: f.Version, CreatedAt: f.CreatedAt, UpdatedAt: f.UpdatedAt,
		}
	}
	return out, nil
}

func (s *Service) snapshotPlots(ctx context.Context, sc territory.Scope) (any, error) {
	rows, err := s.q.ListPlots(ctx, store.ListPlotsParams{PlotIds: []uuid.UUID{}, FarmerIds: nonNil(sc.FarmerIDs)})
	if err != nil {
		return nil, apperr.Internalf("farmers: snapshot plots: %w", err)
	}
	out := make([]snapPlot, 0, len(rows))
	for _, r := range rows {
		p := toPlot(r)
		out = append(out, snapPlot{
			ID: p.ID, FarmerID: p.FarmerID, Label: p.Label, VillageID: p.VillageID, Boundary: p.Boundary, Pin: p.Pin,
			AreaAcres: p.AreaAcres, AreaSource: p.AreaSource, GPSAccuracyM: p.GPSAccuracyM, Status: p.Status,
			Version: p.Version, UpdatedAt: p.UpdatedAt,
		})
	}
	return out, nil
}

func (s *Service) snapshotSeasons(ctx context.Context, sc territory.Scope) (any, error) {
	rows, err := s.q.ListSeasons(ctx, store.ListSeasonsParams{SeasonIds: []uuid.UUID{}, FarmerIds: nonNil(sc.FarmerIDs)})
	if err != nil {
		return nil, apperr.Internalf("farmers: snapshot seasons: %w", err)
	}
	out := make([]snapSeason, len(rows))
	for i, r := range rows {
		se := toSeason(r)
		out[i] = snapSeason{
			ID: se.ID, FarmerID: se.FarmerID, PlotID: se.PlotID, SeasonCode: se.SeasonCode, CropID: se.CropID,
			SowingDate: dateString(se.SowingDate), PreviousCropID: se.PreviousCropID, Status: se.Status,
			Version: se.Version, UpdatedAt: se.UpdatedAt,
		}
	}
	return out, nil
}

func dateString(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.Format(time.DateOnly)
	return &s
}
