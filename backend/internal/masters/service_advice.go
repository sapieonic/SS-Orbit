package masters

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/masters/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Caches. Every masters cache key carries the masters version, so a publish
// makes old entries unreachable at once; the masters.published subscriber then
// deletes the previous version's keys and the TTL catches anything missed.
const (
	cacheTTL          = 24 * time.Hour
	cacheSnapshot     = "snapshot"
	cacheProductTerms = "product_terms"
	cacheFarmerCrops  = "farmer_crops"
)

var cacheNames = []string{cacheSnapshot, cacheProductTerms, cacheFarmerCrops}

func cacheKey(version int64, name string) string {
	return fmt.Sprintf("masters:v%d:%s", version, name)
}

// liveRuleLimit bounds the "every live rule" query (a few rules per issue).
const liveRuleLimit = 100_000

// RuleForVisit is the provider method for visits (CONVENTIONS section 5): the
// rule version an FA picked offline for an issue on a visit. It must have been
// approved at some point (approved = live now, or superseded since: the FA's
// snapshot may be older than the last approval); drafts and rejected versions
// are apperr.NotFound. The caller checks that IssueID is the issue it logged.
func (s *Service) RuleForVisit(ctx context.Context, ruleID uuid.UUID) (xmod.Advice, error) {
	r, err := loadRule(ctx, s.q, ruleID)
	if err != nil {
		return xmod.Advice{}, err
	}
	if r.Status != ruleApproved && r.Status != ruleSuperseded {
		return xmod.Advice{}, apperr.NotFound("rule")
	}
	return toAdvice(r), nil
}

// ProductTerms is the provider method for messaging (CONVENTIONS section 5):
// the lower-cased names of active Shanmukha products and active salts, English
// and Telugu, for the advisory product-mention check. Cached per masters
// version.
func (s *Service) ProductTerms(ctx context.Context) ([]string, error) {
	v, err := s.CurrentVersion(ctx)
	if err != nil {
		return nil, err
	}
	var out []string
	if s.deps.Cache.GetJSON(ctx, cacheKey(v, cacheProductTerms), &out) {
		return out, nil
	}
	err = s.readSnapshot(ctx, func(q *store.Queries) error {
		var err error
		if v, err = currentVersion(ctx, q); err != nil {
			return err
		}
		skus, err := q.ListActiveSkus(ctx)
		if err != nil {
			return apperr.Internalf("masters: product terms skus: %w", err)
		}
		salts, err := q.ListActiveSalts(ctx)
		if err != nil {
			return apperr.Internalf("masters: product terms salts: %w", err)
		}
		out = productTerms(skus, salts)
		return nil
	})
	if err != nil {
		return nil, err
	}
	s.deps.Cache.SetJSON(ctx, cacheKey(v, cacheProductTerms), out, cacheTTL)
	return out, nil
}

// productTerms lower-cases, trims and de-duplicates product and salt names.
func productTerms(skus []store.Sku, salts []store.Salt) []string {
	seen := map[string]bool{}
	out := []string{}
	add := func(s *string) {
		if s == nil {
			return
		}
		t := strings.ToLower(strings.TrimSpace(*s))
		if t != "" && !seen[t] {
			seen[t] = true
			out = append(out, t)
		}
	}
	for _, k := range skus {
		add(&k.ProductName)
		add(k.ProductNameTe)
	}
	for _, sa := range salts {
		add(&sa.Name)
		add(sa.NameTe)
	}
	sort.Strings(out)
	return out
}

func toAdvice(r Rule) xmod.Advice {
	doseTe := r.DoseTe
	return xmod.Advice{
		RuleID: r.ID, RuleVersion: r.Version, RuleStatus: r.Status, IssueID: r.IssueID,
		SaltID: r.SaltID, SaltName: r.SaltName, SaltNameTe: r.SaltNameTe,
		SKUID: r.SKUID, ProductName: r.ProductName, ProductNameTe: r.ProductNameTe, Dose: r.Dose, DoseTe: &doseTe,
	}
}

func liveRules(ctx context.Context, q *store.Queries) ([]Rule, error) {
	status := ruleApproved
	rows, err := q.ListRuleViews(ctx, store.ListRuleViewsParams{Status: &status, RowLimit: liveRuleLimit})
	if err != nil {
		return nil, apperr.Internalf("masters: live rules: %w", err)
	}
	out := make([]Rule, len(rows))
	for i, r := range rows {
		out[i] = toRule(r)
	}
	return out, nil
}

// ---- FA snapshot section "masters" ----

// Snapshot is the masters section of the FA territory snapshot. It is the same
// for every FA, so it is cached once per masters version. Compact on purpose:
// only what the app needs offline. SeasonCodes depend on the date, not on the
// masters version, so they are filled after the cache read. JSON keys are
// stable: nullable fields are always present (never omitempty).
type Snapshot struct {
	Version     int64         `json:"version"`
	Crops       []SnapCrop    `json:"crops"`
	Issues      []SnapIssue   `json:"issues"`
	Salts       []SnapSalt    `json:"salts"`
	SKUs        []SnapSKU     `json:"skus"`
	Rules       []SnapRule    `json:"rules"`
	SeasonCodes SeasonCodeSet `json:"season_codes"`
}

// SnapCrop is an active crop with its active stages.
type SnapCrop struct {
	ID           uuid.UUID   `json:"id"`
	Code         string      `json:"code"`
	Name         string      `json:"name"`
	NameTe       string      `json:"name_te"`
	DurationDays *int32      `json:"duration_days"`
	Stages       []SnapStage `json:"stages"`
}

// SnapStage is one stage of a crop calendar.
type SnapStage struct {
	ID       uuid.UUID `json:"id"`
	Code     string    `json:"code"`
	Name     string    `json:"name"`
	NameTe   string    `json:"name_te"`
	Seq      int32     `json:"seq"`
	StartDay int32     `json:"start_day"`
	EndDay   int32     `json:"end_day"`
}

// SnapIssue is an active issue of an active crop.
type SnapIssue struct {
	ID     uuid.UUID `json:"id"`
	CropID uuid.UUID `json:"crop_id"`
	Type   string    `json:"type"`
	Name   string    `json:"name"`
	NameTe string    `json:"name_te"`
}

// SnapSalt is an active salt.
type SnapSalt struct {
	ID     uuid.UUID `json:"id"`
	Name   string    `json:"name"`
	NameTe *string   `json:"name_te"`
}

// SnapSKU is an active Shanmukha SKU.
type SnapSKU struct {
	ID               uuid.UUID `json:"id"`
	Code             string    `json:"code"`
	ProductName      string    `json:"product_name"`
	ProductNameTe    *string   `json:"product_name_te"`
	SaltID           uuid.UUID `json:"salt_id"`
	PackSize         string    `json:"pack_size"`
	MRPPaise         int64     `json:"mrp_paise"`
	CashbackEligible bool      `json:"cashback_eligible"`
}

// SnapRule is a live rule for an issue; an issue can have several, one per
// salt (FA-09: the FA picks the salt, the app shows the Shanmukha product if
// SKUID is set). The app sends RuleID with the visit so it records the exact
// version used (WF-02).
type SnapRule struct {
	ID      uuid.UUID  `json:"id"`
	RuleKey uuid.UUID  `json:"rule_key"`
	Version int32      `json:"version"`
	IssueID uuid.UUID  `json:"issue_id"`
	SaltID  uuid.UUID  `json:"salt_id"`
	SKUID   *uuid.UUID `json:"sku_id"`
	Dose    string     `json:"dose_per_acre"`
	DoseTe  string     `json:"dose_per_acre_te"`
}

// SnapshotSection is the territory provider for section "masters". The scope
// is ignored: masters are the same for every FA.
func (s *Service) SnapshotSection(ctx context.Context, _ territory.Scope) (any, error) {
	return s.Snapshot(ctx)
}

// Snapshot builds (or reads from cache) the masters snapshot.
func (s *Service) Snapshot(ctx context.Context) (Snapshot, error) {
	v, err := s.CurrentVersion(ctx)
	if err != nil {
		return Snapshot{}, err
	}
	var out Snapshot
	if !s.deps.Cache.GetJSON(ctx, cacheKey(v, cacheSnapshot), &out) {
		if err := s.readSnapshot(ctx, func(q *store.Queries) error {
			var err error
			out, err = buildSnapshot(ctx, q)
			return err
		}); err != nil {
			return Snapshot{}, err
		}
		s.deps.Cache.SetJSON(ctx, cacheKey(out.Version, cacheSnapshot), out, cacheTTL)
	}
	out.SeasonCodes = SeasonCodesAt(s.deps.Clock.Now())
	return out, nil
}

func buildSnapshot(ctx context.Context, q *store.Queries) (Snapshot, error) {
	v, err := currentVersion(ctx, q)
	if err != nil {
		return Snapshot{}, err
	}
	out := Snapshot{Version: v, Crops: []SnapCrop{}, Issues: []SnapIssue{}, Salts: []SnapSalt{}, SKUs: []SnapSKU{}, Rules: []SnapRule{}}

	crops, err := activeCrops(ctx, q)
	if err != nil {
		return Snapshot{}, err
	}
	for _, c := range crops {
		sc := SnapCrop{ID: c.ID, Code: c.Code, Name: c.Name, NameTe: c.NameTe, DurationDays: c.DurationDays, Stages: []SnapStage{}}
		for _, st := range c.Stages {
			sc.Stages = append(sc.Stages, SnapStage{ID: st.ID, Code: st.Code, Name: st.Name, NameTe: st.NameTe,
				Seq: st.Seq, StartDay: st.StartDay, EndDay: st.EndDay})
		}
		out.Crops = append(out.Crops, sc)
	}

	issues, err := q.ListActiveIssues(ctx)
	if err != nil {
		return Snapshot{}, apperr.Internalf("masters: snapshot issues: %w", err)
	}
	visible := make(map[uuid.UUID]bool, len(issues))
	for _, i := range issues {
		visible[i.ID] = true
		out.Issues = append(out.Issues, SnapIssue{ID: i.ID, CropID: i.CropID, Type: i.Type, Name: i.Name, NameTe: i.NameTe})
	}

	salts, err := q.ListActiveSalts(ctx)
	if err != nil {
		return Snapshot{}, apperr.Internalf("masters: snapshot salts: %w", err)
	}
	for _, sa := range salts {
		out.Salts = append(out.Salts, SnapSalt{ID: sa.ID, Name: sa.Name, NameTe: sa.NameTe})
	}

	skus, err := q.ListActiveSkus(ctx)
	if err != nil {
		return Snapshot{}, apperr.Internalf("masters: snapshot skus: %w", err)
	}
	for _, k := range skus {
		out.SKUs = append(out.SKUs, SnapSKU{ID: k.ID, Code: k.Code, ProductName: k.ProductName, ProductNameTe: k.ProductNameTe,
			SaltID: k.SaltID, PackSize: k.PackSize, MRPPaise: k.MrpPaise, CashbackEligible: k.CashbackEligible})
	}

	rules, err := liveRules(ctx, q)
	if err != nil {
		return Snapshot{}, err
	}
	for _, r := range rules {
		if !visible[r.IssueID] {
			continue // issue or its crop is inactive: the FA can't pick it
		}
		out.Rules = append(out.Rules, SnapRule{ID: r.ID, RuleKey: r.RuleKey, Version: r.Version, IssueID: r.IssueID,
			SaltID: r.SaltID, SKUID: r.SKUID, Dose: r.Dose, DoseTe: r.DoseTe})
	}
	return out, nil
}

// onPublished is the masters.published subscriber: drop the previous
// version's cache entries. Idempotent (deleting twice is harmless).
func (s *Service) onPublished(ctx context.Context, e events.MastersPublished) error {
	if e.Kind != versionKind || e.Version < 2 {
		return nil
	}
	keys := make([]string, 0, len(cacheNames))
	for _, name := range cacheNames {
		keys = append(keys, cacheKey(e.Version-1, name))
	}
	s.deps.Cache.Delete(ctx, keys...)
	logx.From(ctx).Info("masters caches cleared", "version", e.Version)
	return nil
}
