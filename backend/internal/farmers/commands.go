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
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// FA offline sync commands (CONVENTIONS section 6). IDs come from the phone.
// Each handler runs one transaction and is idempotent for the same command:
// a replay is recognised by the row's last_command_id (or, for enrolment, by
// the consent rows whose IDs are derived from the command ID) and answered
// with the same result without writing again.
//
// Business outcomes are Results (applied / merged / conflict / rejected);
// only infrastructure failures are returned as errors, so sync retries them.

// Reasons an EnrolFarmer on an existing phone number is rejected. The result
// carries only the phone's own farmer_id, never the existing farmer's ID.
const (
	ReasonRegisteredWithAnotherFA = "registered_with_another_fa"
	ReasonNotInYourArea           = "not_in_your_area"
)

// EnrolFarmer creates a farmer enrolled by the FA, or merges into the farmer
// who already has this phone number and answers merged with merged_into. A
// merge is allowed only into the FA's own farmer, or an unassigned farmer
// (a self sign-up) whose village is in the FA's territory, who then becomes
// the FA's; a farmer of another FA is rejected (CONVENTIONS section 6).
//
// Consent (FAR-04): fa_otp consent rows are written only with a valid
// otp_proof for this FA and phone, timed when the OTP was verified. Without
// one the farmer is enrolled consent pending; RecordConsent adds it later.
func (s *Service) EnrolFarmer(ctx context.Context, p auth.Principal, cmd commands.Command, in EnrolFarmerPayload) (commands.Result, error) {
	ctx = auth.WithPrincipal(ctx, p)
	if p.Kind != auth.KindFA {
		return commands.Rejected(in.FarmerID, "only an FA can enrol farmers"), nil
	}
	norm, err := validateEnrol(&in)
	if err != nil {
		return result(in.FarmerID, commands.Result{}, err)
	}
	v, err := s.village(ctx, in.VillageID)
	if err != nil {
		return result(in.FarmerID, commands.Result{}, err)
	}
	proof, proofState := s.checkConsentProof(p, norm, in.Consent.OTPProof)
	// A photo key outside this farmer's prefix is dropped rather than losing
	// the whole enrolment (and the plot and season queued behind it).
	var droppedPhotoKey *string
	if checkPhotoKey(in.PhotoKey, in.FarmerID) != nil {
		droppedPhotoKey, in.PhotoKey = in.PhotoKey, nil
	}

	var res commands.Result
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		if e, err := q.GetEnrolment(ctx, cmd.ID); err == nil { // replay
			res = enrolResult(in.FarmerID, e.FarmerID)
			return nil
		} else if !db.IsNoRows(err) {
			return apperr.Internalf("farmers: enrol replay check: %w", err)
		}

		f, err := q.GetFarmerByPhoneForUpdate(ctx, norm)
		created := false
		switch {
		case db.IsNoRows(err):
			if _, err := q.GetFarmer(ctx, in.FarmerID); err == nil {
				return apperr.Validation("farmer_id", "already used for another phone number")
			}
			now := s.deps.Clock.Now()
			f, err = q.InsertFarmer(ctx, store.InsertFarmerParams{
				ID: in.FarmerID, Phone: norm, Name: &in.Name, NameTe: trimmed(in.NameTe), Language: in.Language,
				VillageID: nullID(v.ID), MandalID: nullID(v.MandalID), DistrictID: nullID(v.DistrictID),
				AssignedFaID: nullID(p.ID), Source: SourceFA, EnrolledByFaID: nullID(p.ID), PhotoKey: in.PhotoKey,
				Status: StatusActive, ProfileCompletedAt: &now, LastCommandID: nullID(cmd.ID),
			})
			if db.IsNoRows(err) { // the phone was inserted concurrently: treat it as existing
				f, err = q.GetFarmerByPhoneForUpdate(ctx, norm)
			} else {
				created = err == nil
			}
			if err != nil {
				return apperr.Internalf("farmers: enrol insert: %w", err)
			}
		case err != nil:
			return apperr.Internalf("farmers: enrol by phone: %w", err)
		}

		bump := []uuid.UUID{p.ID}
		if created {
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "farmers.enrolled", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
				After: farmerAuditView(f), Meta: enrolMeta(cmd.ID, proofState, droppedPhotoKey),
			}); err != nil {
				return err
			}
			vid, faID := v.ID, p.ID
			if err := s.deps.Events.Publish(ctx, tx, events.FarmerRegistered{
				FarmerID: f.ID, VillageID: &vid, Source: SourceFA, EnrolledByFAID: &faID,
			}); err != nil {
				return err
			}
		} else {
			reason, err := s.enrolClaimCheck(ctx, p.ID, f, v.ID)
			if err != nil {
				return err
			}
			if reason != "" {
				res = commands.Rejected(in.FarmerID, reason)
				_, err := audit.Record(ctx, tx, audit.Entry{
					Action: "farmers.enrolment_refused", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
					Meta: map[string]any{"command_id": cmd.ID, "phone_farmer_id": in.FarmerID, "reason": reason},
				})
				return err
			}
			merged, err := s.mergeEnrolment(ctx, q, tx, p, cmd, in, f, v.ID, v.MandalID, v.DistrictID,
				enrolMeta(cmd.ID, proofState, droppedPhotoKey))
			if err != nil {
				return err
			}
			bump = append(bump, faOf(f), faOf(merged))
			f = merged
		}
		if proof != nil {
			if err := s.insertFAConsents(ctx, q, p, cmd, f, in.Consent.Purposes, in.Consent.NoticeVersion,
				in.Consent.AudioPlayed, *proof); err != nil {
				return err
			}
		}
		if err := q.InsertEnrolment(ctx, store.InsertEnrolmentParams{
			CommandID: cmd.ID, FarmerID: f.ID, PhoneFarmerID: in.FarmerID, FaID: p.ID, ConsentRecorded: proof != nil,
		}); err != nil {
			return apperr.Internalf("farmers: record enrolment: %w", err)
		}
		res = enrolResult(in.FarmerID, f.ID)
		return territory.Bump(ctx, tx, bump...)
	})
	return result(in.FarmerID, res, err)
}

// enrolClaimCheck decides whether an FA enrolment may merge into the existing
// farmer f: yes for the FA's own farmer; for an unassigned farmer only when
// their village (or, if they have none yet, the enrolment's village) is in the
// FA's territory. It returns the rejection reason, "" when allowed.
func (s *Service) enrolClaimCheck(ctx context.Context, faID uuid.UUID, f store.Farmer, enrolVillage uuid.UUID) (string, error) {
	if f.Status == StatusInactive {
		return "", apperr.Validation("phone", "this farmer was deactivated by HO; ask HO to reactivate")
	}
	if f.AssignedFaID.Valid {
		if f.AssignedFaID.UUID == faID {
			return "", nil
		}
		return ReasonRegisteredWithAnotherFA, nil
	}
	village := enrolVillage
	if f.VillageID.Valid {
		village = f.VillageID.UUID
	}
	ok, err := s.villageInTerritory(ctx, faID, village)
	if err != nil {
		return "", err
	}
	if !ok {
		return ReasonNotInYourArea, nil
	}
	return "", nil
}

// villageInTerritory reports whether the FA's allocations cover the village.
func (s *Service) villageInTerritory(ctx context.Context, faID, villageID uuid.UUID) (bool, error) {
	ids, err := s.ports.Geo.VillageIDsForFA(ctx, faID)
	if err != nil {
		return false, apperr.Internalf("farmers: FA villages: %w", err)
	}
	return slices.Contains(ids, villageID), nil
}

// mergeEnrolment folds an FA enrolment into the existing farmer with the same
// phone (the caller has checked the FA may claim them): it fills fields the
// farmer has not set (the farmer's own answers win), completes a pending self
// sign-up, assigns the enrolling FA if the farmer has none, and records the
// phone's farmer_id as an alias.
func (s *Service) mergeEnrolment(ctx context.Context, q *store.Queries, tx pgx.Tx, p auth.Principal, cmd commands.Command,
	in EnrolFarmerPayload, f store.Farmer, villageID, mandalID, districtID uuid.UUID, meta map[string]any) (store.Farmer, error) {
	arg := saveParams(f)
	if arg.Name == nil {
		arg.Name = &in.Name
	}
	if arg.NameTe == nil {
		arg.NameTe = trimmed(in.NameTe)
	}
	if !arg.VillageID.Valid {
		arg.VillageID, arg.MandalID, arg.DistrictID = nullID(villageID), nullID(mandalID), nullID(districtID)
	}
	if arg.PhotoKey == nil {
		arg.PhotoKey = in.PhotoKey
	}
	if !arg.AssignedFaID.Valid {
		arg.AssignedFaID = nullID(p.ID)
	}
	if !arg.EnrolledByFaID.Valid {
		arg.EnrolledByFaID = nullID(p.ID)
	}
	if f.Status == StatusPending {
		now := s.deps.Clock.Now()
		arg.Language, arg.Status, arg.ProfileCompletedAt = in.Language, StatusActive, &now
	}
	arg.LastCommandID = nullID(cmd.ID)
	out, err := q.SaveFarmer(ctx, arg)
	if err != nil {
		return store.Farmer{}, apperr.Internalf("farmers: merge enrolment: %w", err)
	}
	meta["phone_farmer_id"] = in.FarmerID
	if in.FarmerID != f.ID {
		if err := q.InsertAlias(ctx, store.InsertAliasParams{AliasID: in.FarmerID, FarmerID: f.ID, CommandID: cmd.ID, FaID: nullID(p.ID)}); err != nil {
			return store.Farmer{}, apperr.Internalf("farmers: alias: %w", err)
		}
	}
	if _, err := audit.Record(ctx, tx, audit.Entry{
		Action: "farmers.enrolment_merged", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
		Before: farmerAuditView(f), After: farmerAuditView(out),
		Meta: meta,
	}); err != nil {
		return store.Farmer{}, err
	}
	return out, nil
}

// Consent proof states, recorded in the enrolment audit entry.
const (
	consentRecorded     = "recorded"
	consentNoProof      = "pending_no_proof"
	consentInvalidProof = "pending_invalid_proof"
)

// checkConsentProof verifies an OTP consent proof (FAR-04): signed by
// identity, not expired, for this FA and this phone. It returns nil and why
// when there is no usable proof.
func (s *Service) checkConsentProof(p auth.Principal, phoneE164 string, token *string) (*auth.ConsentProof, string) {
	if token == nil {
		return nil, consentNoProof
	}
	pr, err := s.deps.Tokens.VerifyConsentProof(*token)
	if err != nil || pr.FAID != p.ID || pr.Phone != phoneE164 {
		return nil, consentInvalidProof
	}
	return &pr, consentRecorded
}

// insertFAConsents appends one granted fa_otp consent per purpose, timed when
// the OTP was verified (capped at now). Row IDs derive from the command, so a
// replay appends nothing.
func (s *Service) insertFAConsents(ctx context.Context, q *store.Queries, p auth.Principal, cmd commands.Command,
	f store.Farmer, purposes []string, notice string, audioPlayed bool, proof auth.ConsentProof) error {
	at := proof.VerifiedAt.UTC()
	if now := s.deps.Clock.Now(); at.After(now) {
		at = now
	}
	for _, purpose := range purposes {
		if err := q.InsertConsent(ctx, store.InsertConsentParams{
			ID: consentID(cmd.ID, purpose), FarmerID: f.ID, Purpose: purpose, Granted: true, Method: MethodFAOTP,
			CapturedByFaID: nullID(p.ID), NoticeVersion: notice, Language: f.Language,
			AudioPlayed: audioPlayed, CreatedAt: at,
		}); err != nil {
			return apperr.Internalf("farmers: FA consent: %w", err)
		}
	}
	return nil
}

// SavePlot creates or updates a plot. With a boundary the area is computed
// server-side; an update must carry the version the FA saw, else the result is
// a conflict showing the FA's figure against the server's.
func (s *Service) SavePlot(ctx context.Context, p auth.Principal, cmd commands.Command, in SavePlotPayload) (commands.Result, error) {
	ctx = auth.WithPrincipal(ctx, p)
	if p.Kind != auth.KindFA {
		return commands.Rejected(in.PlotID, "only an FA can save plots"), nil
	}
	if in.PlotID == uuid.Nil || in.FarmerID == uuid.Nil {
		return commands.Rejected(in.PlotID, "plot_id and farmer_id are required"), nil
	}
	label := strings.TrimSpace(in.Label)
	if label == "" || len(label) > 60 {
		return commands.Rejected(in.PlotID, "label: must be 1-60 characters"), nil
	}
	g, err := s.measurePlot(ctx, in.BoundaryGeoJSON, in.Pin, in.AreaAcres, in.AreaSource, in.GPSAccuracyM)
	if err != nil {
		return result(in.PlotID, commands.Result{}, err)
	}
	var res commands.Result
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := s.lockFarmerForFA(ctx, q, p, in.FarmerID)
		if err != nil {
			return err
		}
		lat, lng := g.pinLatLng()
		_, err = q.LockPlot(ctx, in.PlotID)
		if db.IsNoRows(err) {
			if err := q.InsertPlot(ctx, store.InsertPlotParams{
				ID: in.PlotID, FarmerID: f.ID, Label: label, VillageID: f.VillageID, BoundaryGeojson: g.boundary,
				PinLat: lat, PinLng: lng, AreaAcres: g.areaAcres, AreaSource: g.areaSource, GpsAccuracyM: g.gpsAccuracy,
				CreatedByFaID: nullID(p.ID), LastCommandID: nullID(cmd.ID),
			}); err != nil {
				return apperr.Internalf("farmers: insert plot: %w", err)
			}
			saved, err := loadPlot(ctx, q, in.PlotID)
			if err != nil {
				return err
			}
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "farmers.plot_saved", EntityType: "plot", EntityID: in.PlotID, FarmerID: f.ID, PlotID: in.PlotID,
				After: plotAuditView(saved), Meta: map[string]any{"command_id": cmd.ID},
			}); err != nil {
				return err
			}
			res = commands.Applied(in.PlotID)
			return territory.Bump(ctx, tx, p.ID, faOf(f))
		}
		if err != nil {
			return apperr.Internalf("farmers: lock plot: %w", err)
		}
		existing, err := loadPlot(ctx, q, in.PlotID)
		if err != nil {
			return err
		}
		if existing.FarmerID != f.ID {
			return apperr.Validation("plot_id", "belongs to another farmer")
		}
		if existing.LastCommandID.Valid && existing.LastCommandID.UUID == cmd.ID {
			res = commands.Applied(in.PlotID)
			return nil
		}
		// A plot created offline is version 1, so a create replayed under a new
		// command ID (or an edit without a version) is checked against 1.
		expected := int32(1)
		if in.ExpectedVersion != nil {
			expected = *in.ExpectedVersion
		}
		if expected != existing.Version {
			res = commands.Conflicted(in.PlotID, plotConflict(existing, label, g, expected))
			return nil
		}
		if err := q.UpdatePlot(ctx, store.UpdatePlotParams{
			ID: in.PlotID, Label: label, BoundaryGeojson: g.boundary, PinLat: lat, PinLng: lng,
			AreaAcres: g.areaAcres, AreaSource: g.areaSource, GpsAccuracyM: g.gpsAccuracy, LastCommandID: nullID(cmd.ID),
		}); err != nil {
			return apperr.Internalf("farmers: update plot: %w", err)
		}
		saved, err := loadPlot(ctx, q, in.PlotID)
		if err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.plot_saved", EntityType: "plot", EntityID: in.PlotID, FarmerID: f.ID, PlotID: in.PlotID,
			Before: plotAuditView(existing), After: plotAuditView(saved), Meta: map[string]any{"command_id": cmd.ID},
		}); err != nil {
			return err
		}
		res = commands.Applied(in.PlotID)
		return territory.Bump(ctx, tx, p.ID, faOf(f))
	})
	return result(in.PlotID, res, err)
}

// StartSeason starts a crop season on a plot. A plot has one active season;
// starting another while one is active is a conflict the FA resolves.
func (s *Service) StartSeason(ctx context.Context, p auth.Principal, cmd commands.Command, in StartSeasonPayload) (commands.Result, error) {
	ctx = auth.WithPrincipal(ctx, p)
	if p.Kind != auth.KindFA {
		return commands.Rejected(in.SeasonID, "only an FA can start seasons"), nil
	}
	if in.SeasonID == uuid.Nil || in.FarmerID == uuid.Nil || in.PlotID == uuid.Nil || in.CropID == uuid.Nil {
		return commands.Rejected(in.SeasonID, "season_id, farmer_id, plot_id and crop_id are required"), nil
	}
	var sowing *time.Time
	if in.SowingDate != nil && *in.SowingDate != "" {
		d, err := time.Parse(time.DateOnly, *in.SowingDate)
		if err != nil {
			return commands.Rejected(in.SeasonID, "sowing_date: must be YYYY-MM-DD"), nil
		}
		sowing = &d
	}
	var res commands.Result
	err := s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := s.lockFarmerForFA(ctx, q, p, in.FarmerID)
		if err != nil {
			return err
		}
		if se, err := q.GetSeasonForUpdate(ctx, in.SeasonID); err == nil {
			// Already there: a replay, or the same season sent again.
			if (se.LastCommandID.Valid && se.LastCommandID.UUID == cmd.ID) || (se.PlotID == in.PlotID && se.FarmerID == f.ID) {
				res = commands.Applied(in.SeasonID)
				return nil
			}
			return apperr.Validation("season_id", "already used for another plot")
		} else if !db.IsNoRows(err) {
			return apperr.Internalf("farmers: load season: %w", err)
		}
		plot, err := q.LockPlot(ctx, in.PlotID)
		if err != nil || plot.FarmerID != f.ID {
			return apperr.NotFound("plot")
		}
		if active, err := q.ActiveSeasonForPlot(ctx, in.PlotID); err == nil {
			res = commands.Conflicted(in.SeasonID, commands.Conflict{
				Field:  "active_season",
				Yours:  map[string]any{"season_code": in.SeasonCode, "crop_id": in.CropID},
				Theirs: map[string]any{"season_id": active.ID, "season_code": active.SeasonCode, "crop_id": active.CropID},
			})
			return nil
		}
		se, err := startSeason(ctx, q, store.InsertSeasonParams{
			ID: in.SeasonID, FarmerID: f.ID, PlotID: in.PlotID, SeasonCode: in.SeasonCode, CropID: in.CropID,
			SowingDate: sowing, PreviousCropID: nullUUID(in.PreviousCropID), LastCommandID: nullID(cmd.ID),
		})
		if err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.season_started", EntityType: "season", EntityID: se.ID,
			FarmerID: f.ID, PlotID: se.PlotID, SeasonID: se.ID, After: seasonAuditView(se),
			Meta: map[string]any{"command_id": cmd.ID},
		}); err != nil {
			return err
		}
		res = commands.Applied(in.SeasonID)
		return territory.Bump(ctx, tx, p.ID, faOf(f))
	})
	return result(in.SeasonID, res, err)
}

// UpdateFarmer edits a farmer's name, language, village or photo. If the farmer
// changed since the FA's copy (version mismatch), the result is a conflict on
// the first field whose server value differs from the FA's; if none differ,
// the edit is already in place and is reported applied.
func (s *Service) UpdateFarmer(ctx context.Context, p auth.Principal, cmd commands.Command, in UpdateFarmerPayload) (commands.Result, error) {
	ctx = auth.WithPrincipal(ctx, p)
	if p.Kind != auth.KindFA {
		return commands.Rejected(in.FarmerID, "only an FA can update farmers"), nil
	}
	fl := in.Fields
	if fl.Name == nil && fl.NameTe == nil && fl.Language == nil && fl.VillageID == nil && fl.PhotoKey == nil {
		return commands.Rejected(in.FarmerID, "fields: nothing to change"), nil
	}
	if err := validateProfile(ProfileInput{Name: fl.Name, NameTe: fl.NameTe, Language: fl.Language, VillageID: fl.VillageID}); err != nil {
		return result(in.FarmerID, commands.Result{}, err)
	}
	var vil *store.Farmer
	if fl.VillageID != nil {
		v, err := s.village(ctx, *fl.VillageID)
		if err != nil {
			return result(in.FarmerID, commands.Result{}, err)
		}
		vil = &store.Farmer{VillageID: nullID(v.ID), MandalID: nullID(v.MandalID), DistrictID: nullID(v.DistrictID)}
	}
	var res commands.Result
	err := s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := s.lockFarmerForFA(ctx, q, p, in.FarmerID)
		if err != nil {
			return err
		}
		if f.LastCommandID.Valid && f.LastCommandID.UUID == cmd.ID {
			res = commands.Applied(f.ID)
			return nil
		}
		// The FA app may have uploaded under the ID it minted (an alias) or
		// the canonical one.
		if err := checkPhotoKey(fl.PhotoKey, in.FarmerID, f.ID); err != nil {
			return err
		}
		if f.Version != in.ExpectedVersion {
			if c, differs := farmerConflict(f, fl); differs {
				res = commands.Conflicted(f.ID, c)
			} else {
				res = commands.Applied(f.ID)
			}
			return nil
		}
		arg := saveParams(f)
		if fl.Name != nil {
			arg.Name = trimmed(fl.Name)
		}
		if fl.NameTe != nil {
			arg.NameTe = trimmed(fl.NameTe)
		}
		if fl.Language != nil {
			arg.Language = *fl.Language
		}
		if vil != nil {
			arg.VillageID, arg.MandalID, arg.DistrictID = vil.VillageID, vil.MandalID, vil.DistrictID
		}
		if fl.PhotoKey != nil {
			arg.PhotoKey = fl.PhotoKey
		}
		arg.LastCommandID = nullID(cmd.ID)
		out, err := q.SaveFarmer(ctx, arg)
		if err != nil {
			return apperr.Internalf("farmers: FA update: %w", err)
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.updated", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
			Before: farmerAuditView(f), After: farmerAuditView(out), Meta: map[string]any{"command_id": cmd.ID},
		}); err != nil {
			return err
		}
		res = commands.Applied(f.ID)
		return territory.Bump(ctx, tx, p.ID, faOf(out))
	})
	return result(in.FarmerID, res, err)
}

// lockFarmerForFA resolves an alias (an enrolment merged into another farmer),
// locks the farmer and checks the FA may act on them (faMayActOn).
func (s *Service) lockFarmerForFA(ctx context.Context, q *store.Queries, p auth.Principal, id uuid.UUID) (store.Farmer, error) {
	id, err := resolveAlias(ctx, q, id)
	if err != nil {
		return store.Farmer{}, err
	}
	f, err := q.GetFarmerForUpdate(ctx, id)
	if err != nil {
		return store.Farmer{}, notFound(err, "farmer")
	}
	if err := faMayActOn(p.ID, f); err != nil {
		return store.Farmer{}, err
	}
	return f, nil
}
