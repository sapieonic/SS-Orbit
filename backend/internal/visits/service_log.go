package visits

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/visits/store"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Limits on one LogVisit.
const (
	maxIssuesPerVisit = 20
	maxPhotosPerVisit = 20
	// maxClockSkew tolerates phones whose clock runs a little ahead.
	maxClockSkew = 15 * time.Minute
)

// photoTypes maps allowed photo content types to the storage key extension.
var photoTypes = map[string]string{
	"image/jpeg": "jpg",
	"image/png":  "png",
	"image/webp": "webp",
}

// photoKey is where a visit photo lives in object storage.
func photoKey(visitID, photoID uuid.UUID, contentType string) string {
	return "visits/" + visitID.String() + "/" + photoID.String() + "." + photoTypes[contentType]
}

type logVisitPayload struct {
	VisitID       uuid.UUID     `json:"visit_id"`
	FarmerID      uuid.UUID     `json:"farmer_id"`
	PlotID        uuid.UUID     `json:"plot_id"`
	SeasonID      uuid.UUID     `json:"season_id"`
	VisitedAt     time.Time     `json:"visited_at"`
	Location      *payloadPoint `json:"location"`
	FarmerPresent bool          `json:"farmer_present"`
	StageID       *uuid.UUID    `json:"stage_id"`
	Notes         *string       `json:"notes"`
	Issues        []struct {
		IssueVisitID uuid.UUID `json:"issue_visit_id"`
		IssueID      uuid.UUID `json:"issue_id"`
		Severity     string    `json:"severity"`
		// AdvisoryRuleID is the rule (salt, FA-09) the FA picked from the
		// snapshot. If it doesn't check out the issue is kept unresolved.
		AdvisoryRuleID *uuid.UUID `json:"advisory_rule_id"`
	} `json:"issues"`
	Photos []struct {
		PhotoID     uuid.UUID `json:"photo_id"`
		ContentType string    `json:"content_type"`
	} `json:"photos"`
	NextVisit *struct {
		VisitID     uuid.UUID `json:"visit_id"`
		PlannedFor  string    `json:"planned_for"`
		PlannedSlot string    `json:"planned_slot"`
	} `json:"next_visit"`
}

// payloadPoint is the payload's optional {lat, lng}.
type payloadPoint struct {
	Lat *float64 `json:"lat"`
	Lng *float64 `json:"lng"`
}

func (p *payloadPoint) latLng() *Point {
	if p == nil || p.Lat == nil || p.Lng == nil {
		return nil
	}
	return &Point{Lat: *p.Lat, Lng: *p.Lng}
}

// validate checks the payload shape. It returns a rejection.
func (in *logVisitPayload) validate(now time.Time) (nextDay time.Time, err error) {
	if in.VisitID == uuid.Nil || in.FarmerID == uuid.Nil || in.PlotID == uuid.Nil || in.SeasonID == uuid.Nil {
		return time.Time{}, reject("visit_id, farmer_id, plot_id and season_id are required")
	}
	if in.VisitedAt.IsZero() {
		return time.Time{}, reject("visited_at is required")
	}
	if in.VisitedAt.After(now.Add(maxClockSkew)) {
		return time.Time{}, reject("visited_at is in the future")
	}
	if in.Location != nil {
		l := in.Location.latLng()
		if l == nil {
			return time.Time{}, reject("location needs lat and lng")
		}
		if l.Lat < -90 || l.Lat > 90 || l.Lng < -180 || l.Lng > 180 {
			return time.Time{}, reject("location is out of range")
		}
	}
	if len(in.Issues) > maxIssuesPerVisit || len(in.Photos) > maxPhotosPerVisit {
		return time.Time{}, reject("at most %d issues and %d photos per visit", maxIssuesPerVisit, maxPhotosPerVisit)
	}
	seen := map[uuid.UUID]bool{}
	for _, is := range in.Issues {
		if is.IssueVisitID == uuid.Nil || is.IssueID == uuid.Nil {
			return time.Time{}, reject("each issue needs issue_visit_id and issue_id")
		}
		if seen[is.IssueVisitID] {
			return time.Time{}, reject("duplicate issue_visit_id %s", is.IssueVisitID)
		}
		seen[is.IssueVisitID] = true
		if is.Severity != "low" && is.Severity != "moderate" && is.Severity != "high" {
			return time.Time{}, reject("severity must be low, moderate or high")
		}
	}
	for _, ph := range in.Photos {
		if ph.PhotoID == uuid.Nil {
			return time.Time{}, reject("each photo needs photo_id")
		}
		if seen[ph.PhotoID] {
			return time.Time{}, reject("duplicate photo_id %s", ph.PhotoID)
		}
		seen[ph.PhotoID] = true
		if _, ok := photoTypes[ph.ContentType]; !ok {
			return time.Time{}, reject("photo content_type must be image/jpeg, image/png or image/webp")
		}
	}
	if nv := in.NextVisit; nv != nil {
		if nv.VisitID == uuid.Nil || nv.VisitID == in.VisitID {
			return time.Time{}, reject("next_visit.visit_id must be a new visit ID")
		}
		if nextDay, err = parseDay(nv.PlannedFor); err != nil {
			return time.Time{}, reject("next_visit.planned_for must be a date (YYYY-MM-DD)")
		}
		if !validSlot(nv.PlannedSlot) {
			return time.Time{}, reject("next_visit.planned_slot must be morning, afternoon or any")
		}
	}
	return nextDay, nil
}

// resolvedIssue is one payload issue with the advice the FA gave, or nil
// advice when the rule they picked did not check out (unresolved).
type resolvedIssue struct {
	id, issueID            uuid.UUID
	severity               string
	issueName, issueNameTe *string
	requestedRuleID        *uuid.UUID
	advice                 *xmod.Advice
	unresolvedReason       string
}

// resolveIssues checks the rule the FA picked for each issue (FA-09): it must
// be an approved or since-superseded rule (the FA's offline masters may be
// older than the last approval) for that same issue. Then the visit records
// exactly that rule, salt, product and dose (WF-02). A rule that doesn't check
// out never rejects the visit: the issue is stored unresolved for HO to follow
// up. Only infrastructure failures are returned as errors (sync retries).
func (s *Service) resolveIssues(ctx context.Context, in logVisitPayload) ([]resolvedIssue, error) {
	if len(in.Issues) > 0 && s.ports.Masters == nil {
		return nil, apperr.Unavailable("advice lookup is not available")
	}
	out := make([]resolvedIssue, 0, len(in.Issues))
	for _, is := range in.Issues {
		r := resolvedIssue{id: is.IssueVisitID, issueID: is.IssueID, severity: is.Severity, requestedRuleID: is.AdvisoryRuleID}
		switch {
		case is.AdvisoryRuleID == nil || *is.AdvisoryRuleID == uuid.Nil:
			r.requestedRuleID = nil
			r.unresolvedReason = "no advisory rule was picked"
		default:
			adv, err := s.ports.Masters.RuleForVisit(ctx, *is.AdvisoryRuleID)
			switch {
			case apperr.Is(err, apperr.KindNotFound):
				r.unresolvedReason = "advisory rule " + is.AdvisoryRuleID.String() + " is not an approved rule"
			case err != nil:
				return nil, err
			case adv.IssueID != is.IssueID:
				r.unresolvedReason = "advisory rule " + is.AdvisoryRuleID.String() + " is for another issue"
			default:
				r.advice = &adv
			}
		}
		if s.ports.Labels != nil {
			name, nameTe, err := s.ports.Labels.IssueLabel(ctx, is.IssueID)
			if err != nil && !apperr.Is(err, apperr.KindNotFound) {
				return nil, err
			}
			r.issueName, r.issueNameTe = strPtr(name), strPtr(nameTe)
		}
		out = append(out, r)
	}
	return out, nil
}

func (s *Service) stageLabel(ctx context.Context, stageID *uuid.UUID) (name, nameTe *string, err error) {
	if stageID == nil || s.ports.Labels == nil {
		return nil, nil, nil
	}
	n, te, err := s.ports.Labels.StageLabel(ctx, *stageID)
	if err != nil && !apperr.Is(err, apperr.KindNotFound) {
		return nil, nil, err
	}
	return strPtr(n), strPtr(te), nil
}

// logVisit handles LogVisit: the visit becomes done with its issues, the
// advice the FA gave (or the issue kept unresolved) and photos awaiting upload, the optional next visit is planned, any open
// call-back of the farmer is closed and visit.logged is published.
//
// Idempotent: a visit that is already done is left as it is (visits are
// append-only; a second log of the same visit ID is a replay).
func (s *Service) logVisit(ctx context.Context, p auth.Principal, cmd commands.Command, in logVisitPayload) (commands.Result, error) {
	id := in.VisitID
	if err := requireFA(p); err != nil {
		return commandResult(id, err)
	}
	now := s.deps.Clock.Now()
	nextDay, err := in.validate(now)
	if err != nil {
		return commandResult(id, err)
	}
	// Replay of an applied log: answer before calling other modules. (The
	// farmer is not compared: the payload may carry a merged farmer's alias.)
	if v, err := s.read().GetVisit(ctx, id); err == nil && v.Status == StatusDone && v.FaID == p.ID &&
		v.PlotID == in.PlotID && v.SeasonID == in.SeasonID {
		return commands.Applied(id), nil
	}
	if in.FarmerID, err = s.resolveFarmer(ctx, p.ID, in.FarmerID); err != nil {
		return commandResult(id, err)
	}
	district, err := s.farmerDistrict(ctx, in.FarmerID)
	if err != nil {
		return commandResult(id, err)
	}
	issues, err := s.resolveIssues(ctx, in)
	if err != nil {
		return commandResult(id, err)
	}
	stageName, stageNameTe, err := s.stageLabel(ctx, in.StageID)
	if err != nil {
		return commandResult(id, err)
	}

	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		q := store.New(tx)
		prevStatus := ""
		cur, err := q.LockVisit(ctx, id)
		switch {
		case db.IsNoRows(err):
		case err != nil:
			return err
		default:
			if cur.FaID != p.ID && cur.Status == StatusDone {
				return reject("visit was logged by another field assistant")
			}
			if !sameTarget(cur, in.FarmerID, in.PlotID, in.SeasonID) {
				return reject("visit_id is already used for a different farmer, plot or season")
			}
			if cur.Status == StatusDone {
				return nil
			}
			prevStatus = cur.Status
		}

		if err := q.UpsertLoggedVisit(ctx, store.UpsertLoggedVisitParams{
			ID: id, FarmerID: in.FarmerID, PlotID: in.PlotID, SeasonID: in.SeasonID, FaID: p.ID,
			VisitedAt: utcPtr(&in.VisitedAt), LocationGeojson: pointGeoJSON(in.Location.latLng()),
			FarmerPresent: &in.FarmerPresent, StageID: nullUUID(in.StageID),
			StageName: stageName, StageNameTe: stageNameTe, Notes: in.Notes,
			ClientCreatedAt: utcPtr(cmd.ClientCreatedAt), DistrictID: district,
		}); err != nil {
			return err
		}
		for _, is := range issues {
			if err := q.InsertVisitIssue(ctx, issueParams(id, in, is)); err != nil {
				return err
			}
		}
		for _, ph := range in.Photos {
			if err := q.InsertVisitPhoto(ctx, store.InsertVisitPhotoParams{
				ID: ph.PhotoID, VisitID: id, StorageKey: photoKey(id, ph.PhotoID, ph.ContentType), ContentType: ph.ContentType,
			}); err != nil {
				return err
			}
		}
		if err := s.planNextVisit(ctx, tx, q, p, in, nextDay, district); err != nil {
			return err
		}
		closed, err := q.CloseOpenCallbacksForFarmer(ctx, store.CloseOpenCallbacksForFarmerParams{
			FarmerID: in.FarmerID, ClosedAt: &now, ClosedBy: uuid.NullUUID{UUID: p.ID, Valid: true},
			Note: strPtr("closed by visit " + id.String()),
		})
		if err != nil {
			return err
		}

		bump := []uuid.UUID{p.ID}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "visits.logged", EntityType: "visit", EntityID: id,
			FarmerID: in.FarmerID, PlotID: in.PlotID, SeasonID: in.SeasonID,
			Before: statusSnapshot(prevStatus), After: logSnapshot(in, issues),
		}); err != nil {
			return err
		}
		for _, c := range closed {
			bump = append(bump, c.FaID)
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "visits.callback_closed", EntityType: "callback_request", EntityID: c.ID, FarmerID: c.FarmerID,
				Before: map[string]any{"status": CallbackOpen}, After: map[string]any{"status": CallbackClosed},
				Meta: map[string]any{"visit_id": id},
			}); err != nil {
				return err
			}
		}
		if err := s.deps.Events.Publish(ctx, tx, events.VisitLogged{
			VisitID: id, FarmerID: in.FarmerID, PlotID: in.PlotID, SeasonID: in.SeasonID, FAID: p.ID,
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, bump...)
	})
	return commandResult(id, err)
}

// planNextVisit inserts LogVisit's optional next visit. An existing visit with
// that ID is fine if it is the same farmer's (a replay); otherwise reject.
func (s *Service) planNextVisit(ctx context.Context, tx pgx.Tx, q *store.Queries, p auth.Principal, in logVisitPayload, day time.Time, district uuid.NullUUID) error {
	nv := in.NextVisit
	if nv == nil {
		return nil
	}
	n, err := q.InsertPlannedVisitIfAbsent(ctx, store.InsertPlannedVisitIfAbsentParams{
		ID: nv.VisitID, FarmerID: in.FarmerID, PlotID: in.PlotID, SeasonID: in.SeasonID, FaID: p.ID,
		PlannedFor: &day, PlannedSlot: &nv.PlannedSlot, DistrictID: district,
	})
	if err != nil {
		return err
	}
	if n == 0 {
		cur, err := q.LockVisit(ctx, nv.VisitID)
		if err != nil {
			return err
		}
		if cur.FarmerID != in.FarmerID {
			return reject("next_visit.visit_id is already used for a different farmer")
		}
		return nil
	}
	_, err = audit.Record(ctx, tx, audit.Entry{
		Action: "visits.planned", EntityType: "visit", EntityID: nv.VisitID,
		FarmerID: in.FarmerID, PlotID: in.PlotID, SeasonID: in.SeasonID,
		After: planSnapshot(StatusPlanned, &day, &nv.PlannedSlot, nil), Meta: map[string]any{"from_visit_id": in.VisitID},
	})
	return err
}

func issueParams(visitID uuid.UUID, in logVisitPayload, is resolvedIssue) store.InsertVisitIssueParams {
	prm := store.InsertVisitIssueParams{
		ID: is.id, VisitID: visitID, FarmerID: in.FarmerID, PlotID: in.PlotID, SeasonID: in.SeasonID,
		IssueID: is.issueID, Severity: is.severity, IssueName: is.issueName, IssueNameTe: is.issueNameTe,
		RequestedRuleID: nullUUID(is.requestedRuleID), AdviceStatus: AdviceGivenStatus,
	}
	a := is.advice
	if a == nil {
		prm.AdviceStatus, prm.UnresolvedReason = AdviceUnresolved, &is.unresolvedReason
		return prm
	}
	prm.AdvisoryRuleID = uuid.NullUUID{UUID: a.RuleID, Valid: true}
	prm.RuleVersion = &a.RuleVersion
	prm.SaltID = uuid.NullUUID{UUID: a.SaltID, Valid: true}
	prm.SaltName, prm.SaltNameTe = strPtr(a.SaltName), a.SaltNameTe
	prm.DosePerAcre, prm.DosePerAcreTe = strPtr(a.Dose), a.DoseTe
	// Only a Shanmukha SKU carries a product name; otherwise salt only.
	if a.SKUID != nil {
		prm.SkuID = uuid.NullUUID{UUID: *a.SKUID, Valid: true}
		prm.ProductName, prm.ProductNameTe = a.ProductName, a.ProductNameTe
	}
	return prm
}

func statusSnapshot(status string) any {
	if status == "" {
		return nil
	}
	return map[string]any{"status": status}
}

func logSnapshot(in logVisitPayload, issues []resolvedIssue) map[string]any {
	adv := make([]map[string]any, len(issues))
	for i, is := range issues {
		m := map[string]any{"issue_id": is.issueID, "severity": is.severity, "requested_rule_id": is.requestedRuleID}
		if a := is.advice; a != nil {
			m["advice_status"], m["rule_id"], m["rule_version"] = AdviceGivenStatus, a.RuleID, a.RuleVersion
			m["rule_status"], m["salt_id"], m["sku_id"], m["dose"] = a.RuleStatus, a.SaltID, a.SKUID, a.Dose
		} else {
			m["advice_status"], m["unresolved_reason"] = AdviceUnresolved, is.unresolvedReason
		}
		adv[i] = m
	}
	return map[string]any{
		"status": StatusDone, "visited_at": in.VisitedAt.UTC(), "farmer_present": in.FarmerPresent,
		"stage_id": in.StageID, "issues": adv, "photos": len(in.Photos),
	}
}
