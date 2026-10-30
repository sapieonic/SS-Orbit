package farmers

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
)

// Pure rules, no database.

func TestDaysAfterSowingUsesIndianDate(t *testing.T) {
	sown := time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	// 30 Oct 19:00 UTC is already 31 Oct in India.
	assert.Equal(t, 30, daysAfterSowing(sown, time.Date(2026, 10, 31, 0, 0, 0, 0, time.UTC).Add(-5*time.Hour)))
	assert.Equal(t, 29, daysAfterSowing(sown, time.Date(2026, 10, 30, 18, 0, 0, 0, time.UTC)))
	assert.Equal(t, 0, daysAfterSowing(sown, time.Date(2026, 10, 1, 1, 0, 0, 0, time.UTC)))
	assert.Equal(t, -1, daysAfterSowing(sown, time.Date(2026, 9, 30, 12, 0, 0, 0, time.UTC)))
}

func TestGeoJSONText(t *testing.T) {
	for _, in := range []string{``, `null`, `  `} {
		s, err := geoJSONText(json.RawMessage(in))
		require.NoError(t, err)
		assert.Empty(t, s)
	}
	s, err := geoJSONText(json.RawMessage(`{"type":"Polygon"}`))
	require.NoError(t, err)
	assert.Equal(t, `{"type":"Polygon"}`, s)
	s, err = geoJSONText(json.RawMessage(`"{\"type\":\"Polygon\"}"`))
	require.NoError(t, err, "a string holding GeoJSON is accepted")
	assert.Equal(t, `{"type":"Polygon"}`, s)
	_, err = geoJSONText(json.RawMessage(`[1,2]`))
	assert.True(t, apperr.Is(err, apperr.KindValidation))
	_, err = geoJSONText(json.RawMessage(`"{not json"`))
	assert.True(t, apperr.Is(err, apperr.KindValidation))
}

func TestValidateEnrol(t *testing.T) {
	proof := "a-proof"
	in := EnrolFarmerPayload{FarmerID: ids.New(), Phone: "098480-12345", Name: "  Raju P ", Language: "te", VillageID: ids.New(),
		Consent: EnrolConsent{Purposes: []string{"programme", "programme", "loyalty"}, OTPProof: &proof, NoticeVersion: "2026-10"}}
	norm, err := validateEnrol(&in)
	require.NoError(t, err)
	assert.Equal(t, "+919848012345", norm)
	assert.Equal(t, "Raju P", in.Name)
	assert.Equal(t, []string{"programme", "loyalty"}, in.Consent.Purposes, "deduplicated")

	bad := EnrolFarmerPayload{Phone: "1", Language: "hi", Consent: EnrolConsent{Purposes: []string{"marketing"}, OTPProof: &proof}}
	_, err = validateEnrol(&bad)
	e, ok := apperr.As(err)
	require.True(t, ok)
	fields := e.Details["fields"].(map[string]string)
	for _, k := range []string{"farmer_id", "phone", "name", "language", "village_id", "consent.purposes", "consent.notice_version"} {
		assert.Contains(t, fields, k)
	}
	res, err := result(uuid.Nil, commands.Result{}, err)
	require.NoError(t, err)
	assert.Equal(t, commands.StatusRejected, res.Status)
	assert.Contains(t, *res.Error, "language: must be te or en")

	// Without a proof nothing about consent is required: the farmer is
	// enrolled consent pending.
	noProof := EnrolFarmerPayload{FarmerID: ids.New(), Phone: "9848012345", Name: "Raju", Language: "te", VillageID: ids.New(),
		Consent: EnrolConsent{OTPProof: ptr("  ")}}
	_, err = validateEnrol(&noProof)
	require.NoError(t, err)
	assert.Nil(t, noProof.Consent.OTPProof, "blank proof is no proof")
	_, err = validateEnrol(&EnrolFarmerPayload{FarmerID: ids.New(), Phone: "9848012345", Name: "Raju", Language: "te",
		VillageID: ids.New(), Consent: EnrolConsent{Purposes: []string{"marketing"}}})
	assert.True(t, apperr.Is(err, apperr.KindValidation), "unknown purposes are always refused")
}

func TestResultPassesInfrastructureErrors(t *testing.T) {
	id := ids.New()
	_, err := result(id, commands.Result{}, assert.AnError)
	assert.ErrorIs(t, err, assert.AnError)
	res, err := result(id, commands.Result{}, apperr.Forbidden("not yours"))
	require.NoError(t, err)
	assert.Equal(t, commands.Rejected(id, "not yours"), res)
}

func TestCurrentConsentsTakesLatest(t *testing.T) {
	t0 := time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	rows := []store.Consent{
		{ID: ids.New(), Purpose: "programme", Granted: false, Method: "app", CreatedAt: t0.Add(time.Hour)},
		{ID: ids.New(), Purpose: "programme", Granted: true, Method: "fa_otp", CreatedAt: t0},
		{ID: ids.New(), Purpose: "loyalty", Granted: true, Method: "app", CreatedAt: t0},
	}
	cs := currentConsents(rows)
	require.Len(t, cs, 4)
	assert.Equal(t, "programme", cs[0].Purpose)
	assert.False(t, *cs[0].Granted, "the withdrawal is newer")
	assert.Nil(t, cs[1].Granted)
	assert.Nil(t, cs[2].Granted)
	assert.True(t, *cs[3].Granted)
}

func TestFarmerConflict(t *testing.T) {
	name := "Ravi"
	f := store.Farmer{Name: &name, Language: "te"}
	te, en, other := "te", "en", "Ravi K"
	_, differs := farmerConflict(f, UpdateFarmerFields{Name: &name, Language: &te})
	assert.False(t, differs)
	c, differs := farmerConflict(f, UpdateFarmerFields{Language: &en})
	assert.True(t, differs)
	assert.Equal(t, commands.Conflict{Field: "language", Yours: "en", Theirs: "te"}, c)
	c, _ = farmerConflict(f, UpdateFarmerFields{Name: &other, Language: &en})
	assert.Equal(t, "name", c.Field, "first differing field")
	v := ids.New()
	c, differs = farmerConflict(f, UpdateFarmerFields{VillageID: &v})
	assert.True(t, differs)
	assert.Equal(t, "village_id", c.Field)
}

func TestEscapeLikeAndDigits(t *testing.T) {
	assert.Equal(t, `50\% off\_x\\`, escapeLike(`50% off_x\`))
	assert.Equal(t, "919848012345", digits("+91 98480-12345"))
}
