package farmers

import (
	"fmt"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Regression tests for the second gap-fix round: consent at sign-up, village
// hand-over between FAs sharing a village, the unassigned count and farmer
// photos.

func TestConsentWhilePendingProfile(t *testing.T) {
	f := newFixture(t)
	id := f.selfSignUp("9848044444")
	ctx := farmerCtx(id)

	cs, err := f.svc.SetMyConsent(ctx, ConsentInput{Purpose: PurposeProgramme, Granted: true, NoticeVersion: "2026-10", AudioPlayed: true})
	require.NoError(t, err, "sign-up records consent before the village is picked (FAR-04)")
	require.NotNil(t, cs[0].Granted)
	assert.True(t, *cs[0].Granted)
	cs, err = f.svc.SetMyConsent(ctx, ConsentInput{Purpose: PurposeProgramme, Granted: false, NoticeVersion: "2026-10"})
	require.NoError(t, err, "withdrawing works while pending too")
	assert.False(t, *cs[0].Granted)
	assert.Equal(t, StatusPending, f.farmer(id).Status)
	assert.Equal(t, 1, f.count(`SELECT count(*) FROM audit_log WHERE action = 'farmers.consent_withdrawn' AND farmer_id = $1`, id))

	// Other writes still wait for the profile.
	_, err = f.svc.AddMyPlot(ctx, NewPlotInput{Pin: Point{Lat: 17.4, Lng: 78.3}, AreaAcres: 1})
	e, ok := apperr.As(err)
	require.True(t, ok)
	assert.Equal(t, "profile_incomplete", e.Code)

	// Deactivated farmers cannot change consent.
	_, err = f.svc.Deactivate(testutil.Ctx(testutil.HO(auth.RoleOps)), id, nil)
	require.NoError(t, err)
	_, err = f.svc.SetMyConsent(ctx, ConsentInput{Purpose: PurposeProgramme, Granted: true, NoticeVersion: "2026-10"})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
}

func TestReassignVillageHandOverKeepsOtherFAsFarmers(t *testing.T) {
	f := newFixture(t)
	fa3 := ids.New()
	f.exec(`INSERT INTO field_assistants (id, code, name, phone, password_hash, level) VALUES
		($1, 'FA-KDP-003', 'Gopal R', '+919848000003', 'x', 'village')`, fa3)
	f.ident.fas[fa3] = xmod.FieldAssistant{ID: fa3, Code: "FA-KDP-003", Name: "Gopal R", Status: "active"}
	ops := testutil.Ctx(testutil.HO(auth.RoleOps))

	// Kondapur has farmers of two FAs: fa1 (the lead) and fa2 (a support FA).
	_, a := f.enrol(f.fa1, "9848011111", "Anil R", f.village)
	_, b := f.enrol(f.fa2, "9848022222", "Bhanu S", f.village)

	_, err := f.svc.Reassign(ops, ReassignInput{ToFAID: fa3, VillageIDs: []uuid.UUID{f.village}})
	require.True(t, apperr.Is(err, apperr.KindValidation), "from_fa_id is required by village")
	_, err = f.svc.Reassign(ops, ReassignInput{ToFAID: fa3, FromFAID: &fa3, VillageIDs: []uuid.UUID{f.village}})
	require.True(t, apperr.Is(err, apperr.KindValidation), "from and to must differ")

	// fa1 hands Kondapur over to fa3: only fa1's farmer moves.
	moved, err := f.svc.Reassign(ops, ReassignInput{ToFAID: fa3, FromFAID: &f.fa1, VillageIDs: []uuid.UUID{f.village}})
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{a}, moved)
	assert.Equal(t, fa3, f.farmer(a).AssignedFaID.UUID)
	assert.Equal(t, f.fa2, f.farmer(b).AssignedFaID.UUID, "the other FA's farmer in the same village stays")

	// With farmer_ids, from_fa_id is an optional guard.
	moved, err = f.svc.Reassign(ops, ReassignInput{ToFAID: f.fa1, FromFAID: &fa3, FarmerIDs: []uuid.UUID{a, b}})
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{a}, moved, "b is not with fa3, so it is skipped")
	assert.Equal(t, f.fa2, f.farmer(b).AssignedFaID.UUID)
}

func TestStatsCountsUnassigned(t *testing.T) {
	f := newFixture(t)
	f.enrol(f.fa1, "9848011111", "Anil R", f.village)
	f.selfSignUp("9848022222") // pending: not counted as unassigned
	id := f.selfSignUp("9848033333")
	_, err := f.svc.CompleteProfile(farmerCtx(id), ProfileInput{Name: ptr("Ravi"), Language: ptr("te"), VillageID: &f.village3})
	require.NoError(t, err)
	require.False(t, f.farmer(id).AssignedFaID.Valid, "Kandlakoya has no lead FA")

	st, err := f.svc.Stats(testutil.Ctx(testutil.HO(auth.RoleOps)), nil)
	require.NoError(t, err)
	assert.Equal(t, 1, st.Unassigned)
	st, err = f.svc.Stats(testutil.Ctx(testutil.HO(auth.RoleOps)), &f.district)
	require.NoError(t, err)
	assert.Equal(t, 0, st.Unassigned, "district filter")
}

func TestFarmerPhotos(t *testing.T) {
	f := newFixture(t)
	fa := faPrincipal(f.fa1)
	faCtx := testutil.Ctx(fa)

	t.Run("FA upload URL for a farmer minted offline", func(t *testing.T) {
		newID := ids.New()
		up, err := f.svc.PresignFarmerPhotoForFA(faCtx, newID, "image/webp", 300_000)
		require.NoError(t, err)
		assert.True(t, strings.HasPrefix(up.StorageKey, "farmers/"+newID.String()+"/photo-"), up.StorageKey)
		assert.True(t, strings.HasSuffix(up.StorageKey, ".webp"))
		assert.Equal(t, "PUT", up.Method)
		assert.NotEmpty(t, up.URL)

		_, err = f.svc.PresignFarmerPhotoForFA(faCtx, newID, "image/gif", 300_000)
		assert.True(t, apperr.Is(err, apperr.KindValidation))
		_, err = f.svc.PresignFarmerPhotoForFA(faCtx, newID, "image/jpeg", MaxFarmerPhotoBytes+1)
		assert.True(t, apperr.Is(err, apperr.KindValidation))
	})

	t.Run("enrol keeps a key under the farmer and drops any other", func(t *testing.T) {
		in := f.enrolPayload(f.fa1, "9848011111", "Anil R", f.village)
		up, err := f.svc.PresignFarmerPhotoForFA(faCtx, in.FarmerID, "image/jpeg", 1000)
		require.NoError(t, err)
		in.PhotoKey = &up.StorageKey
		res, err := f.svc.EnrolFarmer(faCtx, fa, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		require.Equal(t, commands.StatusApplied, res.Status)
		require.NotNil(t, f.farmer(in.FarmerID).PhotoKey)
		assert.Equal(t, up.StorageKey, *f.farmer(in.FarmerID).PhotoKey)

		other := f.enrolPayload(f.fa1, "9848022222", "Bhanu S", f.village)
		in2Key := fmt.Sprintf("farmers/%s/photo-%s.jpg", in.FarmerID, ids.New()) // another farmer's prefix
		other.PhotoKey = &in2Key
		res, err = f.svc.EnrolFarmer(faCtx, fa, cmd("EnrolFarmer"), other)
		require.NoError(t, err)
		require.Equal(t, commands.StatusApplied, res.Status, "the enrolment is kept")
		assert.Nil(t, f.farmer(other.FarmerID).PhotoKey)
		assert.Equal(t, 1, f.count(`SELECT count(*) FROM audit_log WHERE action = 'farmers.enrolled' AND farmer_id = $1
			AND meta->>'photo_key_dropped' = $2`, other.FarmerID, in2Key))

		// Another FA may not get an upload URL for this farmer.
		_, err = f.svc.PresignFarmerPhotoForFA(testutil.Ctx(faPrincipal(f.fa2)), in.FarmerID, "image/jpeg", 1000)
		assert.True(t, apperr.Is(err, apperr.KindForbidden))

		// UpdateFarmer: a foreign key is rejected, an own key applied.
		farmer := f.farmer(other.FarmerID)
		bad := "visits/" + ids.New().String() + "/x.jpg"
		res, err = f.svc.UpdateFarmer(faCtx, fa, cmd("UpdateFarmer"), UpdateFarmerPayload{
			FarmerID: farmer.ID, ExpectedVersion: farmer.Version, Fields: UpdateFarmerFields{PhotoKey: &bad},
		})
		require.NoError(t, err)
		assert.Equal(t, commands.StatusRejected, res.Status)
		up, err = f.svc.PresignFarmerPhotoForFA(faCtx, farmer.ID, "image/png", 1000)
		require.NoError(t, err)
		res, err = f.svc.UpdateFarmer(faCtx, fa, cmd("UpdateFarmer"), UpdateFarmerPayload{
			FarmerID: farmer.ID, ExpectedVersion: farmer.Version, Fields: UpdateFarmerFields{PhotoKey: &up.StorageKey},
		})
		require.NoError(t, err)
		require.Equal(t, commands.StatusApplied, res.Status, "%v", res.Error)
		assert.Equal(t, up.StorageKey, *f.farmer(farmer.ID).PhotoKey)

		v, err := f.svc.Get360(testutil.Ctx(testutil.HO(auth.RoleOps)), farmer.ID)
		require.NoError(t, err)
		require.NotNil(t, v.PhotoURL, "Farmer 360 shows the photo")
	})

	t.Run("farmer sets their own photo", func(t *testing.T) {
		id := f.selfSignUp("9848055555")
		ctx := farmerCtx(id)
		_, err := f.svc.PresignMyPhoto(ctx, "image/jpeg", 1000)
		e, ok := apperr.As(err)
		require.True(t, ok)
		assert.Equal(t, "profile_incomplete", e.Code)
		_, err = f.svc.CompleteProfile(ctx, ProfileInput{Name: ptr("Ravi"), Language: ptr("te"), VillageID: &f.village})
		require.NoError(t, err)

		up, err := f.svc.PresignMyPhoto(ctx, "image/jpeg", 1000)
		require.NoError(t, err)
		assert.True(t, strings.HasPrefix(up.StorageKey, "farmers/"+id.String()+"/photo-"))
		foreign := fmt.Sprintf("farmers/%s/photo-%s.jpg", ids.New(), ids.New())
		_, err = f.svc.UpdateMyProfile(ctx, ProfileInput{PhotoKey: &foreign})
		assert.True(t, apperr.Is(err, apperr.KindValidation))
		got, err := f.svc.UpdateMyProfile(ctx, ProfileInput{PhotoKey: &up.StorageKey})
		require.NoError(t, err)
		assert.Equal(t, up.StorageKey, *got.PhotoKey)
		home, err := f.svc.Home(ctx)
		require.NoError(t, err)
		require.NotNil(t, home.PhotoURL)

		// Per-farmer rate limit.
		var last error
		for range farmerPhotoLimit {
			_, last = f.svc.PresignMyPhoto(ctx, "image/jpeg", 1000)
		}
		assert.True(t, apperr.Is(last, apperr.KindRateLimited), "%v", last)
	})
}

func TestCheckPhotoKey(t *testing.T) {
	id, alias := ids.New(), ids.New()
	good := fmt.Sprintf("farmers/%s/photo-%s.png", id, ids.New())
	assert.NoError(t, checkPhotoKey(nil, id))
	assert.NoError(t, checkPhotoKey(&good, id))
	assert.NoError(t, checkPhotoKey(&good, alias, id), "either ID")
	assert.Error(t, checkPhotoKey(&good, alias))
	for _, bad := range []string{
		"farmers/" + id.String() + "/photo-x.png",
		"farmers/" + id.String() + "/../other/photo-" + id.String() + ".png",
		"farmers/" + id.String() + "/photo-" + id.String() + ".gif",
		"/farmers/" + id.String() + "/photo-" + id.String() + ".png",
	} {
		assert.Error(t, checkPhotoKey(&bad, id), bad)
	}
}
