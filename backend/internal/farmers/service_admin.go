package farmers

import (
	"context"
	"slices"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// HO portal (/v1/admin/farmers). Every HO role reads; ops and admin write.
// HO users with an area scope see only farmers in their districts; a farmer
// outside the scope (or with no village yet) is reported as not found.

const (
	listDefaultLimit = 50
	listMaxLimit     = 200
)

func requireHORead(ctx context.Context) (auth.Principal, error) {
	return auth.RequireRole(ctx, auth.RoleAdmin, auth.RoleAgronomy, auth.RoleFinance, auth.RoleOps)
}

func requireHOWrite(ctx context.Context) (auth.Principal, error) {
	return auth.RequireRole(ctx, auth.RoleAdmin, auth.RoleOps)
}

func canSee(p auth.Principal, f store.Farmer) bool {
	if !p.HasAreaScope() {
		return true
	}
	return f.DistrictID.Valid && p.CanSeeDistrict(f.DistrictID.UUID)
}

// List returns farmers newest first, with village, FA and consent summary.
func (s *Service) List(ctx context.Context, f ListFilter, limit *int, cursor *string) (paging.Page[ListItem], error) {
	p, err := requireHORead(ctx)
	if err != nil {
		return paging.Page[ListItem]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[ListItem]{}, err
	}
	n := paging.Limit(limit, listDefaultLimit, listMaxLimit)
	arg := store.ListFarmersAdminParams{
		ScopeDistrictIds: nonNil(p.DistrictIDs),
		DistrictID:       nullUUID(f.DistrictID),
		MandalID:         nullUUID(f.MandalID),
		VillageID:        nullUUID(f.VillageID),
		FaID:             nullUUID(f.FAID),
		Unassigned:       f.Unassigned,
		CropID:           nullUUID(f.CropID),
		Status:           f.Status,
		Plan:             f.Plan,
		CursorAt:         cur.AtPtr(),
		CursorID:         cur.IDNull(),
		RowLimit:         int32(n + 1),
	}
	if f.Q != nil {
		if q := strings.TrimSpace(*f.Q); q != "" {
			like := "%" + escapeLike(q) + "%"
			arg.NameLike = &like
			if d := digits(q); len(d) >= 4 {
				if len(d) > 10 { // +91 / 0 prefixes typed with the number
					d = d[len(d)-10:]
				}
				pl := "%" + d + "%"
				arg.PhoneLike = &pl
			}
		}
	}
	rows, err := s.q.ListFarmersAdmin(ctx, arg)
	if err != nil {
		return paging.Page[ListItem]{}, apperr.Internalf("farmers: list: %w", err)
	}
	page := paging.Build(rows, n, func(r store.ListFarmersAdminRow) paging.Cursor {
		return paging.Cursor{At: r.CreatedAt, ID: r.ID}
	})

	var farmerIDs, villageIDs, faIDs []uuid.UUID
	for _, r := range page.Items {
		farmerIDs = append(farmerIDs, r.ID)
		if r.VillageID.Valid {
			villageIDs = append(villageIDs, r.VillageID.UUID)
		}
		if r.AssignedFaID.Valid {
			faIDs = append(faIDs, r.AssignedFaID.UUID)
		}
	}
	consents, err := s.q.CurrentConsents(ctx, nonNil(farmerIDs))
	if err != nil {
		return paging.Page[ListItem]{}, apperr.Internalf("farmers: list consents: %w", err)
	}
	byFarmer := map[uuid.UUID][]store.Consent{}
	for _, c := range consents {
		byFarmer[c.FarmerID] = append(byFarmer[c.FarmerID], c)
	}
	villages := s.villages(ctx, villageIDs)
	fas := s.fieldAssistants(ctx, faIDs)

	return paging.Map(page, func(r store.ListFarmersAdminRow) ListItem {
		it := ListItem{
			Farmer:         toFarmer(listRowFarmer(r)),
			ActiveCropIDs:  r.ActiveCropIds,
			TotalAreaAcres: r.TotalAreaAcres,
			PlotCount:      r.PlotCount,
		}
		if v, ok := villages[r.VillageID.UUID]; ok && r.VillageID.Valid {
			it.Village = &v
		}
		if fa, ok := fas[r.AssignedFaID.UUID]; ok && r.AssignedFaID.Valid {
			it.FA = &fa
		}
		for _, c := range currentConsents(byFarmer[r.ID]) {
			if c.Purpose == PurposeProgramme {
				it.ProgrammeConsent = c.Granted
			}
			if c.Granted != nil && *c.Granted {
				it.ConsentsGranted++
			}
		}
		it.ConsentPending = it.ProgrammeConsent == nil
		return it
	}), nil
}

// Get360 returns everything about one farmer for the HO Farmer 360 page.
func (s *Service) Get360(ctx context.Context, farmerID uuid.UUID) (Farmer360View, error) {
	p, err := requireHORead(ctx)
	if err != nil {
		return Farmer360View{}, err
	}
	f, err := s.q.GetFarmer(ctx, farmerID)
	if err != nil {
		return Farmer360View{}, notFound(err, "farmer")
	}
	if !canSee(p, f) {
		return Farmer360View{}, apperr.NotFound("farmer")
	}
	history, err := s.q.ConsentHistory(ctx, f.ID)
	if err != nil {
		return Farmer360View{}, apperr.Internalf("farmers: consent history: %w", err)
	}
	plots, err := s.q.ListPlots(ctx, store.ListPlotsParams{PlotIds: []uuid.UUID{}, FarmerIds: []uuid.UUID{f.ID}})
	if err != nil {
		return Farmer360View{}, apperr.Internalf("farmers: 360 plots: %w", err)
	}
	seasons, err := s.q.ListSeasons(ctx, store.ListSeasonsParams{SeasonIds: []uuid.UUID{}, FarmerIds: []uuid.UUID{f.ID}})
	if err != nil {
		return Farmer360View{}, apperr.Internalf("farmers: 360 seasons: %w", err)
	}

	v := Farmer360View{
		Farmer:         toFarmer(f),
		PhotoURL:       s.photoURL(ctx, f.PhotoKey),
		Consents:       currentConsents(history),
		ConsentPending: consentPending(history),
		ConsentHistory: make([]ConsentRecord, len(history)),
		Plots:          make([]PlotWithSeasons, 0, len(plots)),
	}
	for i, c := range history {
		v.ConsentHistory[i] = toConsent(c)
	}
	byPlot := map[uuid.UUID][]SeasonRecord{}
	for _, se := range seasons { // newest first
		byPlot[se.PlotID] = append(byPlot[se.PlotID], toSeason(se))
	}
	for _, pr := range plots {
		ps := PlotWithSeasons{Plot: toPlot(pr), Seasons: byPlot[pr.ID]}
		if ps.Seasons == nil {
			ps.Seasons = []SeasonRecord{}
		}
		v.Plots = append(v.Plots, ps)
	}
	if f.VillageID.Valid {
		if vil, ok := s.villages(ctx, []uuid.UUID{f.VillageID.UUID})[f.VillageID.UUID]; ok {
			v.Village = &vil
		}
	}
	fas := s.fieldAssistants(ctx, []uuid.UUID{faOf(f), f.EnrolledByFaID.UUID})
	if fa, ok := fas[faOf(f)]; ok {
		v.AssignedFA = &fa
	}
	if fa, ok := fas[f.EnrolledByFaID.UUID]; ok && f.EnrolledByFaID.Valid {
		v.EnrolledByFA = &fa
	}
	return v, nil
}

// AdminUpdateFarmer edits a farmer. expected_version must match the current
// version. A village change also moves the farmer's mandal and district (the
// assigned FA is changed separately, by reassignment). Changing the plan
// (premium without a payment until Phase 2) is admin only, needs a reason and
// is audited on its own (farmers.plan_changed).
func (s *Service) AdminUpdateFarmer(ctx context.Context, farmerID uuid.UUID, in AdminUpdate) (FarmerRecord, error) {
	p, err := requireHOWrite(ctx)
	if err != nil {
		return FarmerRecord{}, err
	}
	if err := validateProfile(ProfileInput{Name: in.Name, NameTe: in.NameTe, Language: in.Language, VillageID: in.VillageID}); err != nil {
		return FarmerRecord{}, err
	}
	if in.Plan != nil && *in.Plan != "free" && *in.Plan != "premium" {
		return FarmerRecord{}, apperr.Validation("plan", "must be free or premium")
	}
	reason := trimmed(in.Reason)
	if reason != nil && *reason == "" {
		reason = nil
	}
	var newPhone string
	if in.Phone != nil {
		if newPhone, err = phone.Normalize(*in.Phone); err != nil {
			return FarmerRecord{}, apperr.Validation("phone", "not a valid Indian mobile number")
		}
	}
	var vil *store.Farmer // carries the new village/mandal/district IDs
	if in.VillageID != nil {
		v, err := s.village(ctx, *in.VillageID)
		if err != nil {
			return FarmerRecord{}, err
		}
		if p.HasAreaScope() && !p.CanSeeDistrict(v.DistrictID) {
			return FarmerRecord{}, apperr.Forbidden("the new village is outside your districts")
		}
		vil = &store.Farmer{VillageID: nullID(v.ID), MandalID: nullID(v.MandalID), DistrictID: nullID(v.DistrictID)}
	}

	var out store.Farmer
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := q.GetFarmerForUpdate(ctx, farmerID)
		if err != nil {
			return notFound(err, "farmer")
		}
		if !canSee(p, f) {
			return apperr.NotFound("farmer")
		}
		if f.Version != in.ExpectedVersion {
			return apperr.Conflict("version_mismatch", map[string]any{"current_version": f.Version}).
				WithMessage("the farmer was changed by someone else; reload and try again")
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
		planChanged := in.Plan != nil && *in.Plan != f.Plan
		if planChanged {
			if p.Role != auth.RoleAdmin {
				return apperr.Forbidden("only an admin can change a farmer's plan")
			}
			if reason == nil {
				return apperr.Validation("reason", "required when changing the plan")
			}
			arg.Plan = *in.Plan
		}
		if newPhone != "" {
			arg.Phone = newPhone
		}
		if vil != nil {
			arg.VillageID, arg.MandalID, arg.DistrictID = vil.VillageID, vil.MandalID, vil.DistrictID
		}
		out, err = q.SaveFarmer(ctx, arg)
		if db.IsUniqueViolation(err, "") {
			return apperr.Conflict("phone_taken", nil).WithMessage("another farmer has this phone number")
		}
		if err != nil {
			return apperr.Internalf("farmers: admin update: %w", err)
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.updated", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
			Before: farmerAuditView(f), After: farmerAuditView(out), Meta: map[string]any{"reason": reason},
		}); err != nil {
			return err
		}
		if planChanged {
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "farmers.plan_changed", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
				Before: map[string]any{"plan": f.Plan}, After: map[string]any{"plan": out.Plan},
				Meta: map[string]any{"reason": *reason, "payment": "none"},
			}); err != nil {
				return err
			}
		}
		return territory.Bump(ctx, tx, faOf(out))
	})
	if err != nil {
		return FarmerRecord{}, err
	}
	return toFarmer(out), nil
}

// Deactivate takes a farmer out of FA snapshots and advisory targeting.
func (s *Service) Deactivate(ctx context.Context, farmerID uuid.UUID, reason *string) (FarmerRecord, error) {
	return s.setStatus(ctx, farmerID, reason, true)
}

// Reactivate brings a deactivated farmer back: active, or pending_profile if
// the profile was never completed.
func (s *Service) Reactivate(ctx context.Context, farmerID uuid.UUID, reason *string) (FarmerRecord, error) {
	return s.setStatus(ctx, farmerID, reason, false)
}

func (s *Service) setStatus(ctx context.Context, farmerID uuid.UUID, reason *string, deactivate bool) (FarmerRecord, error) {
	p, err := requireHOWrite(ctx)
	if err != nil {
		return FarmerRecord{}, err
	}
	var out store.Farmer
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := q.GetFarmerForUpdate(ctx, farmerID)
		if err != nil {
			return notFound(err, "farmer")
		}
		if !canSee(p, f) {
			return apperr.NotFound("farmer")
		}
		arg := saveParams(f)
		action := "farmers.deactivated"
		switch {
		case deactivate && f.Status == StatusInactive:
			return apperr.Conflict("already_inactive", nil)
		case deactivate:
			arg.Status = StatusInactive
		case f.Status != StatusInactive:
			return apperr.Conflict("not_inactive", map[string]any{"status": f.Status})
		default:
			action = "farmers.reactivated"
			arg.Status = StatusActive
			if f.ProfileCompletedAt == nil {
				arg.Status = StatusPending
			}
		}
		if out, err = q.SaveFarmer(ctx, arg); err != nil {
			return apperr.Internalf("farmers: set status: %w", err)
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: action, EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
			Before: map[string]any{"status": f.Status}, After: map[string]any{"status": out.Status},
			Meta: map[string]any{"reason": reason},
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

// Reassign moves farmers (picked by ID, or one FA's farmers in some villages)
// to another FA. By village, FromFAID is required so a territory hand-over
// never takes another FA's farmers who share a village. An HO user with an area scope moves only farmers in their
// districts, and only to an FA allocated somewhere in those districts. Both FAs' snapshots are bumped and farmers.reassigned is
// published once per previous FA, so visits can move open work and messaging
// can SMS the farmers their new FA's name.
func (s *Service) Reassign(ctx context.Context, in ReassignInput) ([]uuid.UUID, error) {
	p, err := requireHOWrite(ctx)
	if err != nil {
		return nil, err
	}
	if (len(in.FarmerIDs) == 0) == (len(in.VillageIDs) == 0) {
		return nil, apperr.Validation("farmer_ids", "give either farmer_ids or village_ids")
	}
	if len(in.VillageIDs) > 0 && in.FromFAID == nil {
		return nil, apperr.Validation("from_fa_id", "required when reassigning by village")
	}
	if in.FromFAID != nil && *in.FromFAID == in.ToFAID {
		return nil, apperr.Validation("from_fa_id", "must differ from to_fa_id")
	}
	fas, err := s.ports.Identity.GetFieldAssistants(ctx, []uuid.UUID{in.ToFAID})
	if err != nil {
		return nil, apperr.Internalf("farmers: reassign FA lookup: %w", err)
	}
	i := slices.IndexFunc(fas, func(fa xmod.FieldAssistant) bool { return fa.ID == in.ToFAID })
	if i < 0 {
		return nil, apperr.Validation("to_fa_id", "unknown FA")
	}
	if fas[i].Status == "inactive" {
		return nil, apperr.Validation("to_fa_id", "this FA is inactive")
	}
	if p.HasAreaScope() {
		districts, err := s.ports.Geo.DistrictIDsForFAs(ctx, []uuid.UUID{in.ToFAID})
		if err != nil {
			return nil, apperr.Internalf("farmers: reassign FA districts: %w", err)
		}
		if !slices.ContainsFunc(districts[in.ToFAID], p.CanSeeDistrict) {
			return nil, apperr.Forbidden("this FA has no allocation in your districts")
		}
	}

	moved := []uuid.UUID{}
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		rows, err := q.ReassignFarmers(ctx, store.ReassignFarmersParams{
			ToFaID:           nullID(in.ToFAID),
			FromFaID:         nullUUID(in.FromFAID),
			FarmerIds:        nonNil(in.FarmerIDs),
			VillageIds:       nonNil(in.VillageIDs),
			ScopeDistrictIds: nonNil(p.DistrictIDs),
		})
		if err != nil {
			return apperr.Internalf("farmers: reassign: %w", err)
		}
		byFrom := map[uuid.UUID][]uuid.UUID{} // uuid.Nil = had no FA
		var from []uuid.UUID
		for _, r := range rows {
			prev := uuid.Nil
			if r.PreviousFaID.Valid {
				prev = r.PreviousFaID.UUID
			}
			if _, seen := byFrom[prev]; !seen {
				from = append(from, prev)
			}
			byFrom[prev] = append(byFrom[prev], r.ID)
			moved = append(moved, r.ID)
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "farmers.reassigned", EntityType: "farmer", EntityID: r.ID, FarmerID: r.ID,
				Before: map[string]any{"assigned_fa_id": uuidPtr(r.PreviousFaID)},
				After:  map[string]any{"assigned_fa_id": in.ToFAID},
			}); err != nil {
				return err
			}
		}
		for _, prev := range from {
			ev := events.FarmersReassigned{FarmerIDs: byFrom[prev], ToFAID: in.ToFAID}
			if prev != uuid.Nil {
				id := prev
				ev.FromFAID = &id
			}
			if err := s.deps.Events.Publish(ctx, tx, ev); err != nil {
				return err
			}
		}
		if len(rows) == 0 {
			return nil
		}
		return territory.Bump(ctx, tx, append(from, in.ToFAID)...)
	})
	if err != nil {
		return nil, err
	}
	return moved, nil
}

// Rollover closes every active season with this season code (within the HO
// user's districts) at season end. outcome is harvested or abandoned.
func (s *Service) Rollover(ctx context.Context, seasonCode, outcome string) (int, error) {
	p, err := requireHOWrite(ctx)
	if err != nil {
		return 0, err
	}
	if !seasonCodeRe.MatchString(seasonCode) {
		return 0, apperr.Validation("season_code", "must look like rabi-2026-27 or kharif-2027")
	}
	if outcome != SeasonHarvested && outcome != SeasonAbandoned {
		return 0, apperr.Validation("outcome", "must be harvested or abandoned")
	}
	var closed int
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		rows, err := q.CloseSeasonsByCode(ctx, store.CloseSeasonsByCodeParams{
			Status: outcome, SeasonCode: seasonCode, ScopeDistrictIds: nonNil(p.DistrictIDs),
		})
		if err != nil {
			return apperr.Internalf("farmers: rollover: %w", err)
		}
		var faIDs []uuid.UUID
		for _, r := range rows {
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "farmers.season_closed", EntityType: "season", EntityID: r.ID,
				FarmerID: r.FarmerID, PlotID: r.PlotID, SeasonID: r.ID,
				Before: map[string]any{"status": SeasonActive}, After: map[string]any{"status": outcome},
				Meta: map[string]any{"rollover": seasonCode},
			}); err != nil {
				return err
			}
			if r.AssignedFaID.Valid {
				faIDs = append(faIDs, r.AssignedFaID.UUID)
			}
		}
		closed = len(rows)
		return territory.Bump(ctx, tx, faIDs...)
	})
	return closed, err
}

// Stats returns the HO overview numbers (ADM-01) within the caller's
// districts, optionally for one district.
func (s *Service) Stats(ctx context.Context, districtID *uuid.UUID) (OverviewStats, error) {
	p, err := requireHORead(ctx)
	if err != nil {
		return OverviewStats{}, err
	}
	if districtID != nil && p.HasAreaScope() && !p.CanSeeDistrict(*districtID) {
		return OverviewStats{}, apperr.Forbidden("this district is outside your area")
	}
	r, err := s.q.FarmerStats(ctx, store.FarmerStatsParams{
		Since:            s.deps.Clock.Now().Add(-newFarmerWindow),
		ScopeDistrictIds: nonNil(p.DistrictIDs),
		DistrictID:       nullUUID(districtID),
	})
	if err != nil {
		return OverviewStats{}, apperr.Internalf("farmers: stats: %w", err)
	}
	return OverviewStats{
		Total: int(r.Total), Active: int(r.Active), PendingProfile: int(r.PendingProfile), Inactive: int(r.Inactive),
		Premium: int(r.Premium), ConsentPending: int(r.ConsentPending), NewLast7Days: int(r.NewSince),
		Unassigned: int(r.Unassigned),
	}, nil
}

// newFarmerWindow is the "new farmers" period on the overview.
const newFarmerWindow = 7 * 24 * time.Hour

// consentPending reports a farmer with no programme consent row at all: an FA
// enrolment without a valid OTP proof, or a self sign-up that has not answered.
func consentPending(history []store.Consent) bool {
	return !slices.ContainsFunc(history, func(c store.Consent) bool { return c.Purpose == PurposeProgramme })
}

// listRowFarmer copies the farmer columns of a list row.
func listRowFarmer(r store.ListFarmersAdminRow) store.Farmer {
	return store.Farmer{
		ID: r.ID, Phone: r.Phone, Name: r.Name, NameTe: r.NameTe, Language: r.Language,
		VillageID: r.VillageID, AssignedFaID: r.AssignedFaID, Source: r.Source, EnrolledByFaID: r.EnrolledByFaID,
		PhotoKey: r.PhotoKey, Plan: r.Plan, Status: r.Status, ProfileCompletedAt: r.ProfileCompletedAt,
		Version: r.Version, CreatedAt: r.CreatedAt, UpdatedAt: r.UpdatedAt, MandalID: r.MandalID,
		DistrictID: r.DistrictID, LastCommandID: r.LastCommandID,
	}
}

// escapeLike escapes LIKE wildcards so a search for "50%" means the text.
func escapeLike(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

func digits(s string) string {
	var b strings.Builder
	for _, r := range s {
		if r >= '0' && r <= '9' {
			b.WriteRune(r)
		}
	}
	return b.String()
}
