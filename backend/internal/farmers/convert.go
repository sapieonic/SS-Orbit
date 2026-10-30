package farmers

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
)

func toFarmer(r store.Farmer) FarmerRecord {
	return FarmerRecord{
		ID:                 r.ID,
		Phone:              r.Phone,
		Name:               r.Name,
		NameTe:             r.NameTe,
		Language:           r.Language,
		VillageID:          uuidPtr(r.VillageID),
		MandalID:           uuidPtr(r.MandalID),
		DistrictID:         uuidPtr(r.DistrictID),
		AssignedFAID:       uuidPtr(r.AssignedFaID),
		Source:             r.Source,
		EnrolledByFAID:     uuidPtr(r.EnrolledByFaID),
		PhotoKey:           r.PhotoKey,
		Plan:               r.Plan,
		Status:             r.Status,
		ProfileCompletedAt: utc(r.ProfileCompletedAt),
		Version:            r.Version,
		CreatedAt:          r.CreatedAt.UTC(),
		UpdatedAt:          r.UpdatedAt.UTC(),
	}
}

// saveParams copies a loaded farmer row into SaveFarmer parameters, so a
// service changes only the fields it means to.
func saveParams(r store.Farmer) store.SaveFarmerParams {
	return store.SaveFarmerParams{
		ID:                 r.ID,
		Phone:              r.Phone,
		Name:               r.Name,
		NameTe:             r.NameTe,
		Language:           r.Language,
		VillageID:          r.VillageID,
		MandalID:           r.MandalID,
		DistrictID:         r.DistrictID,
		AssignedFaID:       r.AssignedFaID,
		EnrolledByFaID:     r.EnrolledByFaID,
		PhotoKey:           r.PhotoKey,
		Plan:               r.Plan,
		Status:             r.Status,
		ProfileCompletedAt: r.ProfileCompletedAt,
		LastCommandID:      r.LastCommandID,
	}
}

func toPlot(r store.ListPlotsRow) PlotRecord {
	p := PlotRecord{
		ID:         r.ID,
		FarmerID:   r.FarmerID,
		Label:      r.Label,
		VillageID:  uuidPtr(r.VillageID),
		AreaAcres:  r.AreaAcres,
		AreaSource: r.AreaSource,
		Status:     r.Status,
		Version:    r.Version,
		CreatedAt:  r.CreatedAt.UTC(),
		UpdatedAt:  r.UpdatedAt.UTC(),
	}
	if r.BoundaryGeojson != "" {
		p.Boundary = json.RawMessage(r.BoundaryGeojson)
	}
	if r.HasPin {
		p.Pin = &Point{Lat: r.PinLat, Lng: r.PinLng}
	}
	if r.GpsAccuracyM >= 0 {
		v := r.GpsAccuracyM
		p.GPSAccuracyM = &v
	}
	return p
}

func toSeason(r store.CropSeason) SeasonRecord {
	return SeasonRecord{
		ID:             r.ID,
		FarmerID:       r.FarmerID,
		PlotID:         r.PlotID,
		SeasonCode:     r.SeasonCode,
		CropID:         r.CropID,
		SowingDate:     utc(r.SowingDate),
		PreviousCropID: uuidPtr(r.PreviousCropID),
		Status:         r.Status,
		Version:        r.Version,
		CreatedAt:      r.CreatedAt.UTC(),
		UpdatedAt:      r.UpdatedAt.UTC(),
	}
}

func toConsent(r store.Consent) ConsentRecord {
	return ConsentRecord{
		ID:             r.ID,
		Purpose:        r.Purpose,
		Granted:        r.Granted,
		Method:         r.Method,
		CapturedByFAID: uuidPtr(r.CapturedByFaID),
		NoticeVersion:  r.NoticeVersion,
		Language:       r.Language,
		AudioPlayed:    r.AudioPlayed,
		CreatedAt:      r.CreatedAt.UTC(),
	}
}

// currentConsents takes the latest row per purpose (by created_at, then
// UUIDv7 id) and returns one entry per known purpose, in display order;
// purposes never asked have Granted nil.
func currentConsents(rows []store.Consent) []ConsentState {
	latest := map[string]store.Consent{}
	for _, r := range rows {
		cur, ok := latest[r.Purpose]
		if !ok || r.CreatedAt.After(cur.CreatedAt) || (r.CreatedAt.Equal(cur.CreatedAt) && r.ID.String() > cur.ID.String()) {
			latest[r.Purpose] = r
		}
	}
	out := make([]ConsentState, 0, len(Purposes))
	for _, p := range Purposes {
		c := ConsentState{Purpose: p}
		if r, ok := latest[p]; ok {
			granted, method, notice, at := r.Granted, r.Method, r.NoticeVersion, r.CreatedAt.UTC()
			c.Granted, c.Method, c.NoticeVersion, c.UpdatedAt = &granted, &method, &notice, &at
		}
		out = append(out, c)
	}
	return out
}

func uuidPtr(n uuid.NullUUID) *uuid.UUID {
	if !n.Valid {
		return nil
	}
	id := n.UUID
	return &id
}

func nullUUID(id *uuid.UUID) uuid.NullUUID {
	if id == nil || *id == uuid.Nil {
		return uuid.NullUUID{}
	}
	return uuid.NullUUID{UUID: *id, Valid: true}
}

func nullID(id uuid.UUID) uuid.NullUUID {
	return uuid.NullUUID{UUID: id, Valid: id != uuid.Nil}
}

func utc(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	u := t.UTC()
	return &u
}
