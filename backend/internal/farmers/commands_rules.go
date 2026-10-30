package farmers

import (
	"slices"
	"strings"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
)

// Pure rules behind the sync command handlers: validation, conflict
// description and turning business errors into rejected results.

// validateEnrol checks an enrolment and returns the normalised phone.
func validateEnrol(in *EnrolFarmerPayload) (string, error) {
	fields := map[string]string{}
	norm, err := phone.Normalize(in.Phone)
	if err != nil {
		fields["phone"] = "not a valid Indian mobile number"
	}
	in.Name = strings.TrimSpace(in.Name)
	if in.FarmerID == uuid.Nil {
		fields["farmer_id"] = "required"
	}
	if in.Name == "" || len(in.Name) > 100 {
		fields["name"] = "must be 1-100 characters"
	}
	if in.Language != "te" && in.Language != "en" {
		fields["language"] = "must be te or en"
	}
	if in.VillageID == uuid.Nil {
		fields["village_id"] = "required"
	}
	c := &in.Consent
	purposes, msg := cleanPurposes(c.Purposes)
	c.Purposes = purposes
	if msg != "" {
		fields["consent.purposes"] = msg
	}
	if c.OTPProof != nil && strings.TrimSpace(*c.OTPProof) == "" {
		c.OTPProof = nil
	}
	// Consent is only recorded with a proof; without one the farmer is
	// enrolled consent pending, so purposes and notice don't matter.
	if c.OTPProof != nil {
		if !slices.Contains(c.Purposes, PurposeProgramme) {
			fields["consent.purposes"] = "programme consent is required"
		}
		if strings.TrimSpace(c.NoticeVersion) == "" {
			fields["consent.notice_version"] = "required"
		}
	}
	if len(fields) > 0 {
		return "", apperr.ValidationFields(fields)
	}
	return norm, nil
}

// cleanPurposes de-duplicates consent purposes; msg names an unknown one.
func cleanPurposes(in []string) (purposes []string, msg string) {
	purposes = []string{}
	for _, pu := range in {
		if !slices.Contains(Purposes, pu) {
			msg = "unknown purpose " + pu
		} else if !slices.Contains(purposes, pu) {
			purposes = append(purposes, pu)
		}
	}
	return purposes, msg
}

// plotConflict names the first field where the FA's plot differs from the
// server's, for the FA app's "Keep mine / Keep HO's" card.
func plotConflict(cur store.ListPlotsRow, label string, g plotGeometry, expected int32) commands.Conflict {
	switch {
	case g.areaAcres != cur.AreaAcres:
		return commands.Conflict{Field: "area_acres", Yours: g.areaAcres, Theirs: cur.AreaAcres}
	case label != cur.Label:
		return commands.Conflict{Field: "label", Yours: label, Theirs: cur.Label}
	case (g.boundary != nil) != (cur.BoundaryGeojson != ""):
		return commands.Conflict{Field: "boundary", Yours: g.boundary != nil, Theirs: cur.BoundaryGeojson != ""}
	default:
		return commands.Conflict{Field: "version", Yours: expected, Theirs: cur.Version}
	}
}

// farmerConflict returns the first changed field whose server value differs
// from the FA's, and false if the server already has every value.
func farmerConflict(f store.Farmer, fl UpdateFarmerFields) (commands.Conflict, bool) {
	str := func(p *string) string {
		if p == nil {
			return ""
		}
		return *p
	}
	if fl.Name != nil && strings.TrimSpace(*fl.Name) != str(f.Name) {
		return commands.Conflict{Field: "name", Yours: strings.TrimSpace(*fl.Name), Theirs: f.Name}, true
	}
	if fl.NameTe != nil && strings.TrimSpace(*fl.NameTe) != str(f.NameTe) {
		return commands.Conflict{Field: "name_te", Yours: strings.TrimSpace(*fl.NameTe), Theirs: f.NameTe}, true
	}
	if fl.Language != nil && *fl.Language != f.Language {
		return commands.Conflict{Field: "language", Yours: *fl.Language, Theirs: f.Language}, true
	}
	if fl.VillageID != nil && (!f.VillageID.Valid || f.VillageID.UUID != *fl.VillageID) {
		return commands.Conflict{Field: "village_id", Yours: *fl.VillageID, Theirs: uuidPtr(f.VillageID)}, true
	}
	if fl.PhotoKey != nil && *fl.PhotoKey != str(f.PhotoKey) {
		return commands.Conflict{Field: "photo_key", Yours: *fl.PhotoKey, Theirs: f.PhotoKey}, true
	}
	return commands.Conflict{}, false
}

// consentID derives a stable consent row ID from the command, so a replayed
// EnrolFarmer or RecordConsent cannot append the same consent twice.
func consentID(commandID uuid.UUID, purpose string) uuid.UUID {
	return uuid.NewSHA1(commandID, []byte("consent:"+purpose))
}

// enrolMeta is the audit meta of an enrolment; a dropped photo key is kept
// there so a broken FA app build shows up in the audit log.
func enrolMeta(commandID uuid.UUID, consentState string, droppedPhotoKey *string) map[string]any {
	m := map[string]any{"command_id": commandID, "consent": consentState}
	if droppedPhotoKey != nil {
		m["photo_key_dropped"] = *droppedPhotoKey
	}
	return m
}

func enrolResult(phoneFarmerID, farmerID uuid.UUID) commands.Result {
	if phoneFarmerID == farmerID {
		return commands.Applied(farmerID)
	}
	return commands.Merged(phoneFarmerID, farmerID)
}

// result turns business errors (validation, not found, forbidden, conflict)
// into a rejected Result for entityID; other errors go back to sync to retry.
func result(entityID uuid.UUID, res commands.Result, err error) (commands.Result, error) {
	if err == nil {
		return res, nil
	}
	if e, ok := apperr.As(err); ok {
		switch e.Kind {
		case apperr.KindValidation, apperr.KindNotFound, apperr.KindForbidden, apperr.KindConflict:
			msg := e.Message
			if f, ok := e.Details["fields"].(map[string]string); ok && e.Message == "request has invalid fields" {
				parts := make([]string, 0, len(f))
				for k, v := range f {
					parts = append(parts, k+": "+v)
				}
				slices.Sort(parts)
				msg = strings.Join(parts, "; ")
			}
			return commands.Rejected(entityID, msg), nil
		}
	}
	return commands.Result{}, err
}
