package farmers

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
)

// FA "phone already registered?" check before an enrolment, and the farmer
// app's "Look for FAs" list.

// Lookup rate limit per FA: enough for an enrolment camp, too few to walk
// through phone numbers.
const (
	lookupLimit  = 60
	lookupWindow = time.Hour
)

// LookupPhone tells the FA whether a phone number is already registered and
// whether they may enrol (merge into) that farmer, following the same rule as
// EnrolFarmer. The farmer's ID is returned only when the FA may act on or
// claim them. Rate limited per FA and audited (it reveals whether a number is
// registered).
func (s *Service) LookupPhone(ctx context.Context, phoneNumber string) (LookupResult, error) {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return LookupResult{}, err
	}
	norm, err := phone.Normalize(phoneNumber)
	if err != nil {
		return LookupResult{}, apperr.Validation("phone", "not a valid Indian mobile number")
	}
	ok, err := s.deps.Limiter.Allow(ctx, "farmers:phone_lookup:"+p.ID.String(), lookupLimit, lookupWindow)
	if err != nil {
		return LookupResult{}, apperr.Unavailable("rate limiter unavailable")
	}
	if !ok {
		return LookupResult{}, apperr.RateLimited(lookupWindow / lookupLimit)
	}

	out := LookupResult{Status: LookupNew}
	f, err := s.q.GetFarmerByPhone(ctx, norm)
	switch {
	case db.IsNoRows(err):
	case err != nil:
		return LookupResult{}, apperr.Internalf("farmers: lookup phone: %w", err)
	case f.Status == StatusInactive:
		out.Status = LookupDeactivated
	case f.AssignedFaID.Valid && f.AssignedFaID.UUID == p.ID:
		out.Status, out.FarmerID = LookupMine, &f.ID
	case f.AssignedFaID.Valid:
		out.Status = LookupOtherFA
	default:
		inArea := true // no village yet: the enrolment's village decides (checked then)
		if f.VillageID.Valid {
			if inArea, err = s.villageInTerritory(ctx, p.ID, f.VillageID.UUID); err != nil {
				return LookupResult{}, err
			}
		}
		out.Status = LookupOutsideMyArea
		if inArea {
			out.Status, out.FarmerID = LookupUnassignedInMyArea, &f.ID
		}
	}

	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		_, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.phone_looked_up", EntityType: "farmer", EntityID: idOrNil(out.FarmerID),
			Meta: map[string]any{"phone": phone.Mask(norm), "status": out.Status},
		})
		return err
	})
	if err != nil {
		return LookupResult{}, apperr.Internalf("farmers: audit lookup: %w", err)
	}
	return out, nil
}

// MyFAs lists the FAs covering the signed-in farmer's village (FAR-08), most
// specific allocation level first, leads first; level narrows it to village,
// mandal or district allocations. Inactive FAs are left out. Each FA carries
// the phone for the call button (FAR-09).
func (s *Service) MyFAs(ctx context.Context, level *string) ([]CoveringFA, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return nil, err
	}
	if level != nil && *level != "village" && *level != "mandal" && *level != "district" {
		return nil, apperr.Validation("level", "must be village, mandal or district")
	}
	f, err := s.q.GetFarmer(ctx, p.ID)
	if err != nil {
		return nil, notFound(err, "farmer")
	}
	out := []CoveringFA{}
	if !f.VillageID.Valid {
		return out, nil
	}
	cov, err := s.ports.Geo.FAsCoveringVillage(ctx, f.VillageID.UUID)
	if err != nil {
		return nil, apperr.Internalf("farmers: FAs covering village: %w", err)
	}
	ids := make([]uuid.UUID, 0, len(cov))
	for _, c := range cov {
		if level == nil || c.Level == *level {
			ids = append(ids, c.FAID)
		}
	}
	if len(ids) == 0 {
		return out, nil
	}
	fas, err := s.ports.Identity.GetFieldAssistants(ctx, ids)
	if err != nil {
		return nil, apperr.Internalf("farmers: FA details: %w", err)
	}
	byID := make(map[uuid.UUID]int, len(fas))
	for i, fa := range fas {
		byID[fa.ID] = i
	}
	for _, c := range cov {
		i, ok := byID[c.FAID]
		if !ok || (level != nil && c.Level != *level) || fas[i].Status == "inactive" {
			continue
		}
		out = append(out, CoveringFA{
			FA: fas[i], CoverageLevel: c.Level, IsLead: c.IsLead,
			IsMyFA: f.AssignedFaID.Valid && f.AssignedFaID.UUID == c.FAID,
		})
	}
	return out, nil
}

func idOrNil(id *uuid.UUID) uuid.UUID {
	if id == nil {
		return uuid.Nil
	}
	return *id
}
