package farmers

import (
	"context"
	"testing"
	"time"

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

// Regression tests for the review round: targeting narrows on every filter,
// one FA-authorisation rule, consent proof, merge aliases for other modules.

func TestTargetingNarrowsOnEveryArea(t *testing.T) {
	f := newFixture(t)
	_, kondapur := f.enrol(f.fa1, "9848011111", "Kondapur Farmer", f.village)
	_, gachibowli := f.enrol(f.fa1, "9848022222", "Gachibowli Farmer", f.village2)
	_, medchal := f.enrol(f.fa2, "9848033333", "Medchal Farmer", f.village3)

	target := func(tg xmod.FarmerTarget) []uuid.UUID {
		got, err := f.svc.FarmerIDsForTargeting(context.Background(), tg)
		require.NoError(t, err)
		return got
	}
	assert.ElementsMatch(t, []uuid.UUID{kondapur, gachibowli, medchal}, target(xmod.FarmerTarget{}))
	assert.Equal(t, []uuid.UUID{kondapur},
		target(xmod.FarmerTarget{VillageIDs: []uuid.UUID{f.village}, DistrictIDs: []uuid.UUID{f.district}}),
		"village + its district is that village only, not the whole district")
	assert.Empty(t, target(xmod.FarmerTarget{MandalIDs: []uuid.UUID{f.mandal2}, DistrictIDs: []uuid.UUID{f.district}}),
		"a mandal of another district and a district have no farmer in common")
	assert.Empty(t, target(xmod.FarmerTarget{VillageIDs: []uuid.UUID{f.village3}, MandalIDs: []uuid.UUID{f.mandal}}))
	assert.ElementsMatch(t, []uuid.UUID{kondapur, gachibowli},
		target(xmod.FarmerTarget{MandalIDs: []uuid.UUID{f.mandal}, DistrictIDs: []uuid.UUID{f.district, f.district2}}))
	assert.Empty(t, target(xmod.FarmerTarget{VillageIDs: []uuid.UUID{f.village}, CropIDs: []uuid.UUID{f.cotton}}),
		"crop narrows too: nobody has a cotton season")
}

func TestOneFAAuthorisationRule(t *testing.T) {
	f := newFixture(t)
	fa1, fa2 := faPrincipal(f.fa1), faPrincipal(f.fa2)
	_, mine := f.enrol(f.fa1, "9848011111", "Ravi K", f.village)

	t.Run("enrolling another FA's farmer is rejected without leaking the ID", func(t *testing.T) {
		// fa2 also covers Kondapur, but the farmer is fa1's.
		f.geo.faVillages[f.fa2] = append(f.geo.faVillages[f.fa2], f.village)
		defer func() { f.geo.faVillages[f.fa2] = []uuid.UUID{f.village3} }()
		consents := f.count(`SELECT count(*) FROM consents WHERE farmer_id = $1`, mine)

		in := f.enrolPayload(f.fa2, "9848011111", "Ravi Again", f.village)
		res, err := f.svc.EnrolFarmer(testutil.Ctx(fa2), fa2, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.Rejected(in.FarmerID, ReasonRegisteredWithAnotherFA), res)
		assert.Nil(t, res.MergedInto, "the existing farmer's ID is not revealed")
		assert.Equal(t, consents, f.count(`SELECT count(*) FROM consents WHERE farmer_id = $1`, mine), "no consent added")
		assert.Zero(t, f.count(`SELECT count(*) FROM farmer_aliases WHERE alias_id = $1`, in.FarmerID))
		assert.Equal(t, f.fa1, f.farmer(mine).AssignedFaID.UUID)
		assert.Equal(t, 1, f.count(`SELECT count(*) FROM audit_log WHERE action = 'farmers.enrolment_refused' AND farmer_id = $1`, mine))

		// Covering the village is not enough to act on the farmer either.
		plot := SavePlotPayload{PlotID: ids.New(), FarmerID: mine, Label: "Plot 1", Pin: &Point{Lat: 17.46, Lng: 78.36}, AreaAcres: 1, AreaSource: AreaTyped}
		res, err = f.svc.SavePlot(testutil.Ctx(fa2), fa2, cmd("SavePlot"), plot)
		require.NoError(t, err)
		assert.Equal(t, commands.StatusRejected, res.Status)
		_, err = f.svc.ResolveFarmerForFA(context.Background(), f.fa2, mine)
		assert.True(t, apperr.Is(err, apperr.KindForbidden))
	})

	t.Run("an unassigned farmer outside the FA's area cannot be claimed", func(t *testing.T) {
		self := f.selfSignUp("9848022222")
		f.exec(`UPDATE farmers SET village_id = $2, mandal_id = $3, district_id = $4 WHERE id = $1`, self, f.village3, f.mandal2, f.district2)
		in := f.enrolPayload(f.fa1, "9848022222", "Outside", f.village)
		res, err := f.svc.EnrolFarmer(testutil.Ctx(fa1), fa1, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.Rejected(in.FarmerID, ReasonNotInYourArea), res)
		assert.False(t, f.farmer(self).AssignedFaID.Valid)

		// The FA covering that village can claim them.
		in = f.enrolPayload(f.fa2, "9848022222", "Inside", f.village3)
		res, err = f.svc.EnrolFarmer(testutil.Ctx(fa2), fa2, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.Merged(in.FarmerID, self), res)
		assert.Equal(t, f.fa2, f.farmer(self).AssignedFaID.UUID)
	})

	t.Run("snapshot holds exactly the farmers the FA may act on", func(t *testing.T) {
		scope, err := f.svc.ResolveTerritory(context.Background(), f.fa1)
		require.NoError(t, err)
		assert.Equal(t, []uuid.UUID{mine}, scope.FarmerIDs)
		for _, id := range scope.FarmerIDs {
			_, err := f.svc.ResolveFarmerForFA(context.Background(), f.fa1, id)
			assert.NoError(t, err)
		}
	})
}

func TestResolveFarmerForFA(t *testing.T) {
	f := newFixture(t)
	selfID := f.selfSignUp("9988776655")
	in := f.enrolPayload(f.fa1, "9988776655", "Lakshmi D", f.village2)
	fa := faPrincipal(f.fa1)
	res, err := f.svc.EnrolFarmer(testutil.Ctx(fa), fa, cmd("EnrolFarmer"), in)
	require.NoError(t, err)
	require.Equal(t, commands.StatusMerged, res.Status)

	got, err := f.svc.ResolveFarmerForFA(context.Background(), f.fa1, in.FarmerID)
	require.NoError(t, err)
	assert.Equal(t, selfID, got, "the phone's farmer_id resolves to the canonical farmer")
	got, err = f.svc.ResolveFarmerForFA(context.Background(), f.fa1, selfID)
	require.NoError(t, err)
	assert.Equal(t, selfID, got)
	_, err = f.svc.ResolveFarmerForFA(context.Background(), f.fa2, in.FarmerID)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	_, err = f.svc.ResolveFarmerForFA(context.Background(), f.fa1, ids.New())
	assert.True(t, apperr.Is(err, apperr.KindNotFound))
	f.exec(`UPDATE farmers SET status = 'inactive' WHERE id = $1`, selfID)
	_, err = f.svc.ResolveFarmerForFA(context.Background(), f.fa1, in.FarmerID)
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "deactivated")
}

func TestConsentProof(t *testing.T) {
	f := newFixture(t)
	fa := faPrincipal(f.fa1)
	ctx := testutil.Ctx(fa)
	ho := testutil.Ctx(testutil.HO(auth.RoleOps))
	consents := func(id uuid.UUID) int {
		return f.count(`SELECT count(*) FROM consents WHERE farmer_id = $1`, id)
	}

	t.Run("no proof: enrolled, consent pending", func(t *testing.T) {
		in := f.enrolPayload(f.fa1, "9848011111", "No Proof", f.village)
		in.Consent.OTPProof = nil
		c := cmd("EnrolFarmer")
		res, err := f.svc.EnrolFarmer(ctx, fa, c, in)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(in.FarmerID), res)
		assert.Equal(t, StatusActive, f.farmer(in.FarmerID).Status)
		assert.Zero(t, consents(in.FarmerID))

		// Replay: recognised without consent rows, nothing written twice.
		res, err = f.svc.EnrolFarmer(ctx, fa, c, in)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(in.FarmerID), res)
		assert.Equal(t, 1, f.count(`SELECT count(*) FROM audit_log WHERE action = 'farmers.enrolled' AND farmer_id = $1`, in.FarmerID))

		v, err := f.svc.Get360(ho, in.FarmerID)
		require.NoError(t, err)
		assert.True(t, v.ConsentPending)
		page, err := f.svc.List(ho, ListFilter{}, nil, nil)
		require.NoError(t, err)
		require.Len(t, page.Items, 1)
		assert.True(t, page.Items[0].ConsentPending)
		assert.Nil(t, page.Items[0].ProgrammeConsent)
		st, err := f.svc.Stats(ho, nil)
		require.NoError(t, err)
		assert.Equal(t, 1, st.ConsentPending)
		sums, err := f.svc.GetFarmerSummaries(context.Background(), []uuid.UUID{in.FarmerID})
		require.NoError(t, err)
		assert.False(t, sums[0].ProgrammeConsent)

		// RecordConsent adds it later, timed at OTP verification.
		rc := RecordConsentPayload{FarmerID: in.FarmerID, Purposes: []string{"programme"}, OTPProof: *f.proof(f.fa1, "9848011111"),
			AudioPlayed: true, NoticeVersion: "2026-10"}
		c = cmd("RecordConsent")
		res, err = f.svc.RecordConsent(ctx, fa, c, rc)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(in.FarmerID), res)
		res, err = f.svc.RecordConsent(ctx, fa, c, rc)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(in.FarmerID), res, "replay")
		assert.Equal(t, 1, f.count(`SELECT count(*) FROM consents WHERE farmer_id = $1 AND method = 'fa_otp' AND created_at = $2`,
			in.FarmerID, f.verifiedAt()))
		v, err = f.svc.Get360(ho, in.FarmerID)
		require.NoError(t, err)
		assert.False(t, v.ConsentPending)
		sums, err = f.svc.GetFarmerSummaries(context.Background(), []uuid.UUID{in.FarmerID})
		require.NoError(t, err)
		assert.True(t, sums[0].ProgrammeConsent)
	})

	t.Run("a proof for another phone or another FA records nothing", func(t *testing.T) {
		in := f.enrolPayload(f.fa1, "9848022222", "Wrong Phone", f.village)
		in.Consent.OTPProof = f.proof(f.fa1, "9848099999")
		res, err := f.svc.EnrolFarmer(ctx, fa, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(in.FarmerID), res, "still enrolled")
		assert.Zero(t, consents(in.FarmerID))

		in = f.enrolPayload(f.fa1, "9848033333", "Wrong FA", f.village)
		in.Consent.OTPProof = f.proof(f.fa2, "9848033333")
		res, err = f.svc.EnrolFarmer(ctx, fa, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(in.FarmerID), res)
		assert.Zero(t, consents(in.FarmerID))

		in = f.enrolPayload(f.fa1, "9848044444", "Expired", f.village)
		f.clock.Advance(8 * 24 * time.Hour)
		res, err = f.svc.EnrolFarmer(ctx, fa, cmd("EnrolFarmer"), in)
		require.NoError(t, err)
		assert.Equal(t, commands.Applied(in.FarmerID), res)
		assert.Zero(t, consents(in.FarmerID), "proofs last 7 days")
		assert.Equal(t, 1, f.count(`SELECT count(*) FROM audit_log WHERE action = 'farmers.enrolled' AND farmer_id = $1
			AND meta->>'consent' = 'pending_invalid_proof'`, in.FarmerID))
	})

	t.Run("RecordConsent checks the proof", func(t *testing.T) {
		_, farmerID := f.enrol(f.fa1, "9848055555", "Has Consent", f.village)
		bad := []RecordConsentPayload{
			{FarmerID: farmerID, Purposes: []string{"loyalty"}, OTPProof: *f.proof(f.fa1, "9848066666"), NoticeVersion: "v"}, // other phone
			{FarmerID: farmerID, Purposes: []string{"loyalty"}, OTPProof: *f.proof(f.fa2, "9848055555"), NoticeVersion: "v"}, // other FA
			{FarmerID: farmerID, Purposes: []string{"loyalty"}, OTPProof: "not-a-token", NoticeVersion: "v"},
			{FarmerID: farmerID, Purposes: []string{"marketing"}, OTPProof: *f.proof(f.fa1, "9848055555"), NoticeVersion: "v"},
		}
		before := consents(farmerID)
		for i, in := range bad {
			res, err := f.svc.RecordConsent(ctx, fa, cmd("RecordConsent"), in)
			require.NoError(t, err, i)
			assert.Equal(t, commands.StatusRejected, res.Status, "case %d", i)
		}
		assert.Equal(t, before, consents(farmerID))
	})
}

func TestLookupPhoneAndMyFAs(t *testing.T) {
	f := newFixture(t)
	fa1 := testutil.Ctx(faPrincipal(f.fa1))
	_, mine := f.enrol(f.fa1, "9848011111", "Mine", f.village)
	_, theirs := f.enrol(f.fa2, "9848022222", "Theirs", f.village3)
	pending := f.selfSignUp("9848033333")
	outside := f.selfSignUp("9848044444")
	f.exec(`UPDATE farmers SET village_id = $2 WHERE id = $1`, outside, f.village3)

	for phoneNumber, want := range map[string]LookupResult{
		"9848011111": {Status: LookupMine, FarmerID: &mine},
		"9848022222": {Status: LookupOtherFA},
		"9848033333": {Status: LookupUnassignedInMyArea, FarmerID: &pending},
		"9848044444": {Status: LookupOutsideMyArea},
		"9848099999": {Status: LookupNew},
	} {
		got, err := f.svc.LookupPhone(fa1, phoneNumber)
		require.NoError(t, err)
		assert.Equal(t, want, got, phoneNumber)
	}
	assert.Equal(t, 5, f.count(`SELECT count(*) FROM audit_log WHERE action = 'farmers.phone_looked_up'`))
	_, err := f.svc.LookupPhone(fa1, "123")
	assert.True(t, apperr.Is(err, apperr.KindValidation))
	_, err = f.svc.LookupPhone(farmerCtx(mine), "9848011111")
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	for i := 0; i < lookupLimit; i++ {
		if _, err = f.svc.LookupPhone(fa1, "9848099999"); err != nil {
			break
		}
	}
	assert.True(t, apperr.Is(err, apperr.KindRateLimited), "rate limited per FA: %v", err)

	// Look for FAs: the farmer's village is covered by fa1 (village lead) and
	// a mandal-level FA; inactive FAs are left out.
	mandalFA, gone := ids.New(), ids.New()
	f.geo.coverage[f.village] = []xmod.Coverage{
		{FAID: f.fa1, Level: "village", IsLead: true}, {FAID: gone, Level: "village"}, {FAID: mandalFA, Level: "mandal", IsLead: true},
	}
	f.ident.fas[mandalFA] = xmod.FieldAssistant{ID: mandalFA, Name: "Mandal FA", Phone: "+919848000003", Level: "mandal", Status: "active"}
	f.ident.fas[gone] = xmod.FieldAssistant{ID: gone, Name: "Gone", Phone: "+919848000004", Status: "inactive"}
	all, err := f.svc.MyFAs(farmerCtx(mine), nil)
	require.NoError(t, err)
	require.Len(t, all, 2)
	assert.Equal(t, f.fa1, all[0].FA.ID)
	assert.True(t, all[0].IsMyFA)
	assert.Equal(t, "+919848000001", all[0].FA.Phone, "phone for the call button")
	assert.Equal(t, "mandal", all[1].CoverageLevel)
	mandal := "mandal"
	only, err := f.svc.MyFAs(farmerCtx(mine), &mandal)
	require.NoError(t, err)
	require.Len(t, only, 1)
	assert.Equal(t, mandalFA, only[0].FA.ID)
	none, err := f.svc.MyFAs(farmerCtx(pending), nil)
	require.NoError(t, err)
	assert.Empty(t, none, "no village yet")
	_ = theirs
}

func TestAdminPlanStatsAndReassignScope(t *testing.T) {
	f := newFixture(t)
	_, a := f.enrol(f.fa1, "9848011111", "Anil R", f.village)
	_, c := f.enrol(f.fa2, "9848022222", "Chandra M", f.village3)
	f.selfSignUp("9848033333")
	admin := testutil.Ctx(testutil.HO(auth.RoleAdmin))
	ops := testutil.Ctx(testutil.HO(auth.RoleOps))
	premium := "premium"

	_, err := f.svc.AdminUpdateFarmer(ops, a, AdminUpdate{ExpectedVersion: f.farmer(a).Version, Plan: &premium, Reason: ptr("pilot")})
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "only admin changes the plan")
	_, err = f.svc.AdminUpdateFarmer(admin, a, AdminUpdate{ExpectedVersion: f.farmer(a).Version, Plan: &premium})
	assert.True(t, apperr.Is(err, apperr.KindValidation), "a reason is required")
	got, err := f.svc.AdminUpdateFarmer(admin, a, AdminUpdate{ExpectedVersion: f.farmer(a).Version, Plan: &premium, Reason: ptr("pilot farmer")})
	require.NoError(t, err)
	assert.Equal(t, "premium", got.Plan)
	assert.Equal(t, 1, f.count(`SELECT count(*) FROM audit_log WHERE action = 'farmers.plan_changed' AND farmer_id = $1
		AND meta->>'reason' = 'pilot farmer' AND before->>'plan' = 'free' AND after->>'plan' = 'premium'`, a))
	name := "Anil Reddy"
	_, err = f.svc.AdminUpdateFarmer(ops, a, AdminUpdate{ExpectedVersion: got.Version, Name: &name, Plan: &premium})
	assert.NoError(t, err, "sending the unchanged plan is not a plan change")

	st, err := f.svc.Stats(ops, nil)
	require.NoError(t, err)
	assert.Equal(t, OverviewStats{Total: 3, Active: 2, PendingProfile: 1, Premium: 1, ConsentPending: 1, NewLast7Days: 3}, st)
	st, err = f.svc.Stats(testutil.Ctx(testutil.HO(auth.RoleFinance, f.district2)), nil)
	require.NoError(t, err)
	assert.Equal(t, OverviewStats{Total: 1, Active: 1, NewLast7Days: 1}, st, "district scope")
	_, err = f.svc.Stats(testutil.Ctx(testutil.HO(auth.RoleFinance, f.district2)), &f.district)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))

	// A Medchal-scoped user may not hand Medchal farmers to an FA with no
	// allocation in Medchal.
	medchalOps := testutil.Ctx(testutil.HO(auth.RoleOps, f.district2))
	_, err = f.svc.Reassign(medchalOps, ReassignInput{ToFAID: f.fa1, FarmerIDs: []uuid.UUID{c}})
	assert.True(t, apperr.Is(err, apperr.KindForbidden))
	assert.Equal(t, f.fa2, f.farmer(c).AssignedFaID.UUID)
	f.geo.faVillages[f.fa1] = append(f.geo.faVillages[f.fa1], f.village3)
	moved, err := f.svc.Reassign(medchalOps, ReassignInput{ToFAID: f.fa1, FarmerIDs: []uuid.UUID{c}})
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{c}, moved)
}
