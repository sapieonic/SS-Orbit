package farmers

import (
	"context"
	"fmt"
	"slices"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Farmer app (/v1/farmer): the signed-in farmer acts on their own record only.

// Home returns the farmer's profile, plots with the active season and stage,
// the FA card and the next planned visit. FA, visit and stage lookups are
// best effort: if another module fails, home still loads without that card.
func (s *Service) Home(ctx context.Context) (Home, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return Home{}, err
	}
	row, err := s.q.GetFarmer(ctx, p.ID)
	if err != nil {
		return Home{}, notFound(err, "farmer")
	}
	h := Home{Farmer: toFarmer(row), PhotoURL: s.photoURL(ctx, row.PhotoKey), Plots: []HomePlotView{}}
	log := logx.From(ctx)

	plots, err := s.q.ListPlots(ctx, store.ListPlotsParams{PlotIds: []uuid.UUID{}, FarmerIds: []uuid.UUID{row.ID}})
	if err != nil {
		return Home{}, apperr.Internalf("farmers: home plots: %w", err)
	}
	seasons, err := s.q.ListSeasons(ctx, store.ListSeasonsParams{SeasonIds: []uuid.UUID{}, FarmerIds: []uuid.UUID{row.ID}})
	if err != nil {
		return Home{}, apperr.Internalf("farmers: home seasons: %w", err)
	}
	active := map[uuid.UUID]SeasonRecord{}
	for _, se := range seasons {
		if se.Status == SeasonActive {
			active[se.PlotID] = toSeason(se)
		}
	}
	now := s.deps.Clock.Now()
	stages := newStageCache(s.ports.Masters)
	for _, pr := range plots {
		if pr.Status != "active" {
			continue
		}
		hp := HomePlotView{Plot: toPlot(pr)}
		if se, ok := active[pr.ID]; ok {
			hp.ActiveSeason = &se
			if se.SowingDate != nil {
				d := daysAfterSowing(*se.SowingDate, now)
				hp.DaysAfterSowing = &d
				st, err := stages.get(ctx, se.CropID, d)
				if err != nil {
					log.Warn("farmers: stage lookup failed", "err", err)
				}
				hp.Stage = st
			}
		}
		h.Plots = append(h.Plots, hp)
	}

	if row.VillageID.Valid {
		if v, ok := s.villages(ctx, []uuid.UUID{row.VillageID.UUID})[row.VillageID.UUID]; ok {
			h.Village = &v
		}
	}
	if row.AssignedFaID.Valid {
		if fa, ok := s.fieldAssistants(ctx, []uuid.UUID{row.AssignedFaID.UUID})[row.AssignedFaID.UUID]; ok {
			h.FA = &fa
		}
	}
	if s.ports.Visits != nil {
		nv, err := s.ports.Visits.NextPlannedVisit(ctx, row.ID)
		if err != nil {
			log.Warn("farmers: next visit lookup failed", "err", err)
		}
		h.NextVisit = nv
	}
	return h, nil
}

// CompleteProfile finishes a self sign-up: name, language and village. The
// farmer becomes active and is assigned the lead FA covering the village (if
// there is none, the farmer stays unassigned and HO sees it in the list).
func (s *Service) CompleteProfile(ctx context.Context, in ProfileInput) (FarmerRecord, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return FarmerRecord{}, err
	}
	if in.Name == nil || in.Language == nil || in.VillageID == nil {
		return FarmerRecord{}, apperr.ValidationFields(map[string]string{"name": "required", "language": "required", "village_id": "required"})
	}
	if err := validateProfile(in); err != nil {
		return FarmerRecord{}, err
	}
	v, err := s.village(ctx, *in.VillageID)
	if err != nil {
		return FarmerRecord{}, err
	}
	lead, err := s.leadFAForVillage(ctx, v.ID)
	if err != nil {
		return FarmerRecord{}, err
	}

	var out store.Farmer
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := q.GetFarmerForUpdate(ctx, p.ID)
		if err != nil {
			return notFound(err, "farmer")
		}
		if f.Status != StatusPending {
			return apperr.Conflict("profile_already_complete", map[string]any{"status": f.Status})
		}
		now := s.deps.Clock.Now()
		arg := saveParams(f)
		arg.Name, arg.NameTe, arg.Language = trimmed(in.Name), trimmed(in.NameTe), *in.Language
		arg.VillageID, arg.MandalID, arg.DistrictID = nullID(v.ID), nullID(v.MandalID), nullID(v.DistrictID)
		if !arg.AssignedFaID.Valid {
			arg.AssignedFaID = nullID(lead)
		}
		arg.Status, arg.ProfileCompletedAt = StatusActive, &now
		out, err = q.SaveFarmer(ctx, arg)
		if err != nil {
			return apperr.Internalf("farmers: complete profile: %w", err)
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.profile_completed", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
			Before: farmerAuditView(f), After: farmerAuditView(out),
		}); err != nil {
			return err
		}
		if err := s.deps.Events.Publish(ctx, tx, events.FarmerProfileCompleted{FarmerID: f.ID, VillageID: v.ID}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, faOf(out))
	})
	if err != nil {
		return FarmerRecord{}, err
	}
	return toFarmer(out), nil
}

// UpdateMyProfile changes the farmer's name, language and photo. The photo
// key must be one issued by PresignMyPhoto (under the farmer's own prefix).
func (s *Service) UpdateMyProfile(ctx context.Context, in ProfileInput) (FarmerRecord, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return FarmerRecord{}, err
	}
	in.VillageID = nil // the village changes through the FA or HO
	if err := validateProfile(in); err != nil {
		return FarmerRecord{}, err
	}
	if err := checkPhotoKey(in.PhotoKey, p.ID); err != nil {
		return FarmerRecord{}, err
	}
	var out store.Farmer
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := s.lockOwnFarmer(ctx, q, p.ID)
		if err != nil {
			return err
		}
		arg := saveParams(f)
		if in.Name != nil {
			arg.Name = trimmed(in.Name)
		}
		if in.NameTe != nil {
			arg.NameTe = trimmed(in.NameTe)
		}
		if in.Language != nil {
			arg.Language = *in.Language
		}
		if in.PhotoKey != nil {
			arg.PhotoKey = in.PhotoKey
		}
		out, err = q.SaveFarmer(ctx, arg)
		if err != nil {
			return apperr.Internalf("farmers: update profile: %w", err)
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.profile_updated", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
			Before: farmerAuditView(f), After: farmerAuditView(out),
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, faOf(out))
	})
	if err != nil {
		return FarmerRecord{}, err
	}
	return toFarmer(out), nil
}

// MyConsents returns the current consent for every purpose.
func (s *Service) MyConsents(ctx context.Context) ([]ConsentState, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return nil, err
	}
	rows, err := s.q.CurrentConsents(ctx, []uuid.UUID{p.ID})
	if err != nil {
		return nil, apperr.Internalf("farmers: consents: %w", err)
	}
	return currentConsents(rows), nil
}

// SetMyConsent appends a grant or withdrawal (consents are never edited) and
// returns the current consents. Unlike other farmer writes it is allowed while
// the farmer is still pending_profile: sign-up asks for consent (FAR-04)
// before the village is picked. Deactivated farmers cannot change it.
func (s *Service) SetMyConsent(ctx context.Context, in ConsentInput) ([]ConsentState, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return nil, err
	}
	if !slices.Contains(Purposes, in.Purpose) {
		return nil, apperr.Validation("purpose", "unknown purpose")
	}
	if strings.TrimSpace(in.NoticeVersion) == "" {
		return nil, apperr.Validation("notice_version", "required")
	}
	var out []ConsentState
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := q.GetFarmerForUpdate(ctx, p.ID)
		if err != nil {
			return notFound(err, "farmer")
		}
		if f.Status == StatusInactive {
			return apperr.Forbidden("this farmer account is deactivated")
		}
		id := ids.New()
		if err := q.InsertConsent(ctx, store.InsertConsentParams{
			ID: id, FarmerID: f.ID, Purpose: in.Purpose, Granted: in.Granted, Method: MethodApp,
			NoticeVersion: in.NoticeVersion, Language: f.Language, AudioPlayed: in.AudioPlayed, CreatedAt: s.deps.Clock.Now(),
		}); err != nil {
			return apperr.Internalf("farmers: insert consent: %w", err)
		}
		action := "farmers.consent_granted"
		if !in.Granted {
			action = "farmers.consent_withdrawn"
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: action, EntityType: "consent", EntityID: id, FarmerID: f.ID,
			After: map[string]any{"purpose": in.Purpose, "granted": in.Granted, "method": MethodApp, "notice_version": in.NoticeVersion},
		}); err != nil {
			return err
		}
		rows, err := q.CurrentConsents(ctx, []uuid.UUID{f.ID})
		if err != nil {
			return apperr.Internalf("farmers: consents: %w", err)
		}
		out = currentConsents(rows)
		return territory.Bump(ctx, tx, faOf(f))
	})
	return out, err
}

// AddMyPlot adds a plot from the farmer app: a pin and a typed area.
func (s *Service) AddMyPlot(ctx context.Context, in NewPlotInput) (PlotRecord, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return PlotRecord{}, err
	}
	pin := in.Pin
	g, err := s.measurePlot(ctx, nil, &pin, in.AreaAcres, AreaTyped, nil)
	if err != nil {
		return PlotRecord{}, err
	}
	if in.Label != nil && strings.TrimSpace(*in.Label) == "" {
		return PlotRecord{}, apperr.Validation("label", "must not be blank")
	}
	var out store.ListPlotsRow
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := s.lockOwnFarmer(ctx, q, p.ID)
		if err != nil {
			return err
		}
		label := ""
		if in.Label != nil {
			label = strings.TrimSpace(*in.Label)
		} else {
			n, err := q.CountFarmerPlots(ctx, f.ID)
			if err != nil {
				return apperr.Internalf("farmers: count plots: %w", err)
			}
			label = fmt.Sprintf("Plot %d", n+1)
		}
		id := ids.New()
		lat, lng := g.pinLatLng()
		if err := q.InsertPlot(ctx, store.InsertPlotParams{
			ID: id, FarmerID: f.ID, Label: label, VillageID: f.VillageID, PinLat: lat, PinLng: lng,
			AreaAcres: g.areaAcres, AreaSource: g.areaSource,
		}); err != nil {
			return apperr.Internalf("farmers: insert plot: %w", err)
		}
		if out, err = loadPlot(ctx, q, id); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.plot_saved", EntityType: "plot", EntityID: id, FarmerID: f.ID, PlotID: id,
			After: plotAuditView(out),
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, faOf(f))
	})
	if err != nil {
		return PlotRecord{}, err
	}
	return toPlot(out), nil
}

// StartMySeason starts a season on one of the farmer's plots.
func (s *Service) StartMySeason(ctx context.Context, plotID uuid.UUID, in NewSeasonInput) (SeasonRecord, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return SeasonRecord{}, err
	}
	var out store.CropSeason
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := s.lockOwnFarmer(ctx, q, p.ID)
		if err != nil {
			return err
		}
		plot, err := q.LockPlot(ctx, plotID)
		if err != nil || plot.FarmerID != f.ID {
			return apperr.NotFound("plot")
		}
		out, err = startSeason(ctx, q, store.InsertSeasonParams{
			ID: ids.New(), FarmerID: f.ID, PlotID: plotID, SeasonCode: in.SeasonCode, CropID: in.CropID,
			SowingDate: in.SowingDate, PreviousCropID: nullUUID(in.PreviousCropID),
		})
		if err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.season_started", EntityType: "season", EntityID: out.ID,
			FarmerID: f.ID, PlotID: plotID, SeasonID: out.ID, After: seasonAuditView(out),
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, faOf(f))
	})
	if err != nil {
		return SeasonRecord{}, err
	}
	return toSeason(out), nil
}

// CloseMySeason closes one of the farmer's active seasons as harvested or abandoned.
func (s *Service) CloseMySeason(ctx context.Context, seasonID uuid.UUID, outcome string) (SeasonRecord, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return SeasonRecord{}, err
	}
	if outcome != SeasonHarvested && outcome != SeasonAbandoned {
		return SeasonRecord{}, apperr.Validation("outcome", "must be harvested or abandoned")
	}
	var out store.CropSeason
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := s.lockOwnFarmer(ctx, q, p.ID)
		if err != nil {
			return err
		}
		se, err := q.GetSeasonForUpdate(ctx, seasonID)
		if err != nil || se.FarmerID != f.ID {
			return apperr.NotFound("season")
		}
		if se.Status != SeasonActive {
			return apperr.Conflict("season_not_active", map[string]any{"status": se.Status})
		}
		if out, err = q.CloseSeason(ctx, store.CloseSeasonParams{ID: se.ID, Status: outcome}); err != nil {
			return apperr.Internalf("farmers: close season: %w", err)
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.season_closed", EntityType: "season", EntityID: se.ID,
			FarmerID: f.ID, PlotID: se.PlotID, SeasonID: se.ID,
			Before: map[string]any{"status": se.Status}, After: map[string]any{"status": out.Status},
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, faOf(f))
	})
	if err != nil {
		return SeasonRecord{}, err
	}
	return toSeason(out), nil
}

// lockOwnFarmer locks the signed-in farmer's row for a write. Deactivated
// farmers cannot change anything; pending sign-ups must complete their
// profile first.
func (s *Service) lockOwnFarmer(ctx context.Context, q *store.Queries, id uuid.UUID) (store.Farmer, error) {
	f, err := q.GetFarmerForUpdate(ctx, id)
	if err != nil {
		return store.Farmer{}, notFound(err, "farmer")
	}
	if err := ownWriteAllowed(f.Status); err != nil {
		return store.Farmer{}, err
	}
	return f, nil
}

// ownWriteAllowed is the farmer app's write rule: deactivated farmers cannot
// change anything; pending sign-ups must complete their profile first.
func ownWriteAllowed(status string) error {
	switch status {
	case StatusInactive:
		return apperr.Forbidden("this farmer account is deactivated")
	case StatusPending:
		return apperr.Conflict("profile_incomplete", nil).WithMessage("complete your profile first")
	}
	return nil
}

// validateProfile checks the optional profile fields that are present.
func validateProfile(in ProfileInput) error {
	fields := map[string]string{}
	if in.Name != nil && (strings.TrimSpace(*in.Name) == "" || len(*in.Name) > 100) {
		fields["name"] = "must be 1-100 characters"
	}
	if in.NameTe != nil && (strings.TrimSpace(*in.NameTe) == "" || len(*in.NameTe) > 300) {
		fields["name_te"] = "must not be blank"
	}
	if in.Language != nil && *in.Language != "te" && *in.Language != "en" {
		fields["language"] = "must be te or en"
	}
	if in.VillageID != nil && *in.VillageID == uuid.Nil {
		fields["village_id"] = "required"
	}
	if len(fields) > 0 {
		return apperr.ValidationFields(fields)
	}
	return nil
}

func trimmed(s *string) *string {
	if s == nil {
		return nil
	}
	t := strings.TrimSpace(*s)
	return &t
}

// faOf is the farmer's assigned FA, or uuid.Nil (territory.Bump ignores Nil).
func faOf(f store.Farmer) uuid.UUID {
	if !f.AssignedFaID.Valid {
		return uuid.Nil
	}
	return f.AssignedFaID.UUID
}
