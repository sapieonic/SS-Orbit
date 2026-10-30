package farmers

import (
	"context"
	"slices"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// FindOrCreateByPhone returns the farmer with this phone number, creating a
// pending_profile farmer when there is none. It runs in the caller's
// transaction (identity's OTP sign-up), so the farmer and the session commit
// together. Self sign-up and FA enrolment merge on the phone number.
func (s *Service) FindOrCreateByPhone(ctx context.Context, tx pgx.Tx, phoneNumber string, source string) (uuid.UUID, bool, error) {
	norm, err := phone.Normalize(phoneNumber)
	if err != nil {
		return uuid.Nil, false, apperr.Validation("phone", "not a valid Indian mobile number")
	}
	if source != SourceSelf && source != SourceFA && source != SourceHO {
		return uuid.Nil, false, apperr.Validation("source", "must be self, fa or ho")
	}
	q := store.New(tx)
	existing, err := q.GetFarmerByPhoneForUpdate(ctx, norm)
	if err == nil {
		return existing.ID, false, nil
	}
	if !db.IsNoRows(err) {
		return uuid.Nil, false, apperr.Internalf("farmers: find by phone: %w", err)
	}
	f, err := q.InsertFarmer(ctx, store.InsertFarmerParams{
		ID: ids.New(), Phone: norm, Language: "te", Source: source, Status: StatusPending,
	})
	if db.IsNoRows(err) { // another transaction inserted this phone first
		existing, err := q.GetFarmerByPhoneForUpdate(ctx, norm)
		if err != nil {
			return uuid.Nil, false, apperr.Internalf("farmers: re-read by phone: %w", err)
		}
		return existing.ID, false, nil
	}
	if err != nil {
		return uuid.Nil, false, apperr.Internalf("farmers: create by phone: %w", err)
	}
	if _, err := audit.Record(ctx, tx, audit.Entry{
		Action: "farmers.registered", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
		After: map[string]any{"phone": phone.Mask(norm), "source": source, "status": f.Status},
	}); err != nil {
		return uuid.Nil, false, err
	}
	if err := s.deps.Events.Publish(ctx, tx, events.FarmerRegistered{FarmerID: f.ID, Source: source}); err != nil {
		return uuid.Nil, false, err
	}
	logx.From(ctx).Info("farmers: registered by phone", "farmer_id", f.ID, "phone", phone.Mask(norm), "source", source)
	return f.ID, true, nil
}

// GetFarmerSummaries returns the farmers with these IDs (unknown IDs are
// skipped). ProgrammeConsent is true when the latest programme consent is a
// grant.
func (s *Service) GetFarmerSummaries(ctx context.Context, farmerIDs []uuid.UUID) ([]xmod.FarmerSummary, error) {
	farmerIDs = uniq(farmerIDs)
	if len(farmerIDs) == 0 {
		return []xmod.FarmerSummary{}, nil
	}
	rows, err := s.q.ListFarmersByIDs(ctx, farmerIDs)
	if err != nil {
		return nil, apperr.Internalf("farmers: summaries: %w", err)
	}
	consents, err := s.q.CurrentConsents(ctx, farmerIDs)
	if err != nil {
		return nil, apperr.Internalf("farmers: summary consents: %w", err)
	}
	programme := map[uuid.UUID]bool{}
	for _, c := range consents {
		if c.Purpose == PurposeProgramme {
			programme[c.FarmerID] = c.Granted
		}
	}
	out := make([]xmod.FarmerSummary, len(rows))
	for i, r := range rows {
		out[i] = xmod.FarmerSummary{
			ID: r.ID, Phone: r.Phone, Name: r.Name, NameTe: r.NameTe, Language: r.Language,
			VillageID: r.VillageID, AssignedFAID: r.AssignedFaID, Plan: r.Plan, Status: r.Status,
			ProgrammeConsent: programme[r.ID],
		}
	}
	return out, nil
}

// ResolveFarmerForFA is the provider method for visits (CONVENTIONS section
// 5 and 6): it follows a merge alias (a farmer_id the FA phone minted for an
// enrolment that merged into an existing farmer) to the canonical farmer ID
// and checks the FA may act on that farmer. apperr.NotFound when unknown,
// apperr.Forbidden when the farmer is not the FA's (or was deactivated).
func (s *Service) ResolveFarmerForFA(ctx context.Context, faID, farmerID uuid.UUID) (uuid.UUID, error) {
	id, err := resolveAlias(ctx, s.q, farmerID)
	if err != nil {
		return uuid.Nil, err
	}
	f, err := s.q.GetFarmer(ctx, id)
	if err != nil {
		return uuid.Nil, notFound(err, "farmer")
	}
	if err := faMayActOn(faID, f); err != nil {
		return uuid.Nil, err
	}
	return f.ID, nil
}

// FarmerIDsForTargeting selects advisory recipients: active farmers whose
// current programme consent is granted. Every non-empty filter narrows the
// audience: plan, villages, mandals, districts (a farmer must match each
// listed level), crop of an active season and the current stage of an active
// season (computed from the sowing date through masters). Empty means "any".
func (s *Service) FarmerIDsForTargeting(ctx context.Context, t xmod.FarmerTarget) ([]uuid.UUID, error) {
	if t.Plan != nil && *t.Plan != "free" && *t.Plan != "premium" {
		return nil, apperr.Validation("plan", "must be free or premium")
	}
	cropIDs := nonNil(t.CropIDs)
	farmerIDs, err := s.q.TargetFarmerIDs(ctx, store.TargetFarmerIDsParams{
		Plan:        t.Plan,
		VillageIds:  nonNil(t.VillageIDs),
		MandalIds:   nonNil(t.MandalIDs),
		DistrictIds: nonNil(t.DistrictIDs),
		CropIds:     cropIDs,
	})
	if err != nil {
		return nil, apperr.Internalf("farmers: targeting: %w", err)
	}
	if len(t.StageCodes) == 0 || len(farmerIDs) == 0 {
		return farmerIDs, nil
	}

	// Stage filter: keep farmers with an active season (of a targeted crop)
	// whose stage today is one of the codes.
	seasons, err := s.q.ActiveSeasonsForFarmers(ctx, store.ActiveSeasonsForFarmersParams{FarmerIds: farmerIDs, CropIds: cropIDs})
	if err != nil {
		return nil, apperr.Internalf("farmers: targeting seasons: %w", err)
	}
	now := s.deps.Clock.Now()
	stages := newStageCache(s.ports.Masters)
	keep := map[uuid.UUID]bool{}
	for _, se := range seasons {
		if keep[se.FarmerID] || se.SowingDate == nil {
			continue
		}
		st, err := stages.get(ctx, se.CropID, daysAfterSowing(*se.SowingDate, now))
		if err != nil {
			return nil, apperr.Internalf("farmers: targeting stage: %w", err)
		}
		if st != nil && slices.Contains(t.StageCodes, st.Code) {
			keep[se.FarmerID] = true
		}
	}
	out := make([]uuid.UUID, 0, len(keep))
	for _, id := range farmerIDs {
		if keep[id] {
			out = append(out, id)
		}
	}
	return out, nil
}

// nonNil turns a nil slice into an empty one (pgx sends nil as NULL, and
// cardinality(NULL) is NULL, not 0).
func nonNil(ids []uuid.UUID) []uuid.UUID {
	if ids == nil {
		return []uuid.UUID{}
	}
	return ids
}
