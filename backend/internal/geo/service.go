package geo

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/sapionic/orbit/backend/internal/geo/store"
	"github.com/sapionic/orbit/backend/internal/platform"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Cache keys and lifetimes. The tree is deleted on every geography write;
// FA village lists are keyed by territory version, so a bump makes them stale
// without an explicit delete.
const (
	treeCacheKey      = "geo:tree"
	treeCacheTTL      = 6 * time.Hour
	faVillagesTTL     = 24 * time.Hour
	faVillagesKeyBase = "geo:fa_villages:"
)

// Roles: every HO role reads the masters; admin and ops change them.
var (
	readRoles  = []auth.Role{auth.RoleAdmin, auth.RoleAgronomy, auth.RoleFinance, auth.RoleOps}
	writeRoles = []auth.Role{auth.RoleAdmin, auth.RoleOps}
)

// Service holds the geo business rules: masters, village search, FA
// allocations and the provider methods other modules call.
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

func requireRead(ctx context.Context) (auth.Principal, error) {
	return auth.RequireRole(ctx, readRoles...)
}

func requireWrite(ctx context.Context) (auth.Principal, error) {
	return auth.RequireRole(ctx, writeRoles...)
}

// checkDistrict refuses HO users whose area scope excludes the district.
func checkDistrict(p auth.Principal, districtID uuid.UUID) error {
	if !p.CanSeeDistrict(districtID) {
		return apperr.Forbidden("this district is outside your area")
	}
	return nil
}

// scopeIDs is the district filter for queries: the HO area scope, or an empty
// (never nil: nil encodes as SQL NULL) slice meaning all districts.
func scopeIDs(p auth.Principal) []uuid.UUID {
	if p.HasAreaScope() {
		return p.DistrictIDs
	}
	return []uuid.UUID{}
}

// uniqueConflicts maps unique constraints to the 409 codes clients see.
var uniqueConflicts = map[string]string{
	"districts_name_key":             "district_exists",
	"districts_lgd_code_key":         "lgd_code_taken",
	"mandals_district_id_name_key":   "mandal_exists",
	"mandals_lgd_code_key":           "lgd_code_taken",
	"villages_mandal_id_name_key":    "village_exists",
	"villages_lgd_code_key":          "lgd_code_taken",
	"fa_allocations_fa_area_current": "allocation_exists",
	"fa_allocations_village_lead":    "area_has_lead",
	"fa_allocations_mandal_lead":     "area_has_lead",
	"fa_allocations_district_lead":   "area_has_lead",
}

// mapWriteError turns known constraint violations into apperr conflicts and
// passes anything else through.
func mapWriteError(err error) error {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) || pgErr.Code != "23505" {
		return err
	}
	if code, ok := uniqueConflicts[pgErr.ConstraintName]; ok {
		return apperr.Conflict(code, nil).Wrap(err)
	}
	return apperr.Conflict("", nil).Wrap(err)
}

// cleanName trims a user-entered name; nil stays nil. An all-blank value is a
// validation error on field.
func cleanName(field string, s *string) (*string, error) {
	if s == nil {
		return nil, nil
	}
	t := strings.Join(strings.Fields(*s), " ")
	if t == "" {
		return nil, apperr.Validation(field, "must not be blank")
	}
	return &t, nil
}

// fieldAssistants asks identity for FAs by ID. ok is false when the port is
// not wired (callers then skip the check or the names).
func (s *Service) fieldAssistants(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]xmod.FieldAssistant, bool, error) {
	if s.ports.Identity == nil || len(ids) == 0 {
		return nil, false, nil
	}
	fas, err := s.ports.Identity.GetFieldAssistants(ctx, ids)
	if err != nil {
		return nil, false, err
	}
	out := make(map[uuid.UUID]xmod.FieldAssistant, len(fas))
	for _, fa := range fas {
		out[fa.ID] = fa
	}
	return out, true, nil
}

// requireFAs checks through identity that every FA exists and, when
// mustBeActive, is not inactive. Without the port the foreign key is the
// only check.
func (s *Service) requireFAs(ctx context.Context, mustBeActive []uuid.UUID, mustExist ...uuid.UUID) error {
	all := append(append([]uuid.UUID{}, mustBeActive...), mustExist...)
	fas, ok, err := s.fieldAssistants(ctx, all)
	if err != nil {
		return apperr.Internalf("geo: get field assistants: %w", err)
	}
	if !ok {
		return nil
	}
	for _, id := range all {
		if _, found := fas[id]; !found {
			return apperr.NotFound("field assistant").WithDetail("fa_id", id)
		}
	}
	for _, id := range mustBeActive {
		if fas[id].Status == "inactive" {
			return apperr.Conflict("fa_inactive", map[string]any{"fa_id": id}).
				WithMessage("this field assistant's login is inactive")
		}
	}
	return nil
}

// attachFAs fills FAAllocation.FA from identity. Names are decoration: if
// identity fails the allocations are returned without them.
func (s *Service) attachFAs(ctx context.Context, items []FAAllocation) {
	seen := map[uuid.UUID]bool{}
	var ids []uuid.UUID
	for _, a := range items {
		if !seen[a.FAID] {
			seen[a.FAID] = true
			ids = append(ids, a.FAID)
		}
	}
	fas, ok, err := s.fieldAssistants(ctx, ids)
	if err != nil {
		logx.From(ctx).WarnContext(ctx, "geo: field assistant names unavailable", "err", err)
		return
	}
	if !ok {
		return
	}
	for i := range items {
		if fa, found := fas[items[i].FAID]; found {
			items[i].FA = &fa
		}
	}
}

func uuidPtr(n uuid.NullUUID) *uuid.UUID {
	if !n.Valid {
		return nil
	}
	return &n.UUID
}

func nullUUID(id *uuid.UUID) uuid.NullUUID {
	if id == nil {
		return uuid.NullUUID{}
	}
	return uuid.NullUUID{UUID: *id, Valid: true}
}

func toDistrict(r store.District) DistrictInfo {
	return DistrictInfo{ID: r.ID, Name: r.Name, NameTe: r.NameTe, LGDCode: r.LgdCode, State: r.State, CreatedAt: r.CreatedAt.UTC()}
}

func toVillage(r store.VillageDetail) VillageInfo {
	v := VillageInfo{
		ID: r.ID, Name: r.Name, NameTe: r.NameTe, LGDCode: r.LgdCode,
		MandalID: r.MandalID, MandalName: r.MandalName, MandalNameTe: r.MandalNameTe,
		DistrictID: r.DistrictID, DistrictName: r.DistrictName, DistrictNameTe: r.DistrictNameTe,
		CreatedAt: r.CreatedAt.UTC(),
	}
	if r.HasCentroid {
		lat, lng := r.Lat, r.Lng
		v.Lat, v.Lng = &lat, &lng
	}
	return v
}

func toXmodVillage(v VillageInfo) xmod.Village {
	return xmod.Village{
		ID: v.ID, Name: v.Name, NameTe: v.NameTe,
		MandalID: v.MandalID, MandalName: v.MandalName, MandalNameTe: v.MandalNameTe,
		DistrictID: v.DistrictID, DistrictName: v.DistrictName, DistrictNameTe: v.DistrictNameTe,
	}
}

func toAllocation(r store.AllocationDetail) FAAllocation {
	a := FAAllocation{
		ID: r.ID, FAID: r.FaID, Level: r.Level,
		VillageID: uuidPtr(r.VillageID), MandalID: uuidPtr(r.MandalID),
		MandalName: r.MandalName, MandalNameTe: r.MandalNameTe,
		DistrictID: r.DistrictID, DistrictName: r.DistrictName, DistrictNameTe: r.DistrictNameTe,
		IsLead: r.IsLead, ValidFrom: r.ValidFrom.UTC(), CreatedBy: uuidPtr(r.CreatedBy), CreatedAt: r.CreatedAt.UTC(),
	}
	if r.ValidTo != nil {
		t := r.ValidTo.UTC()
		a.ValidTo = &t
	}
	switch r.Level {
	case LevelVillage:
		a.AreaID, a.AreaName, a.AreaNameTe = r.VillageID.UUID, deref(r.VillageName), r.VillageNameTe
	case LevelMandal:
		a.AreaID, a.AreaName, a.AreaNameTe = r.MandalID.UUID, deref(r.MandalName), r.MandalNameTe
	default:
		a.AreaID, a.AreaName, a.AreaNameTe = r.DistrictID, r.DistrictName, r.DistrictNameTe
	}
	return a
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
