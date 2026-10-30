package messaging

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/riverqueue/river"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Regression: names_product was only a checkbox, so an advisory naming a
// product could skip Agronomy approval and go on the service template.
func TestProductMentionNeedsNamesProduct(t *testing.T) {
	e := newEnv(t)
	_, ops := e.ho(auth.RoleOps)

	in := advisoryInput(ChannelSMS)
	in.BodyEn = ptr("Spray Imidacloprid 0.5 ml per litre.")
	_, err := e.svc.CreateAdvisory(ops, in)
	require.True(t, apperr.Is(err, apperr.KindValidation), "%v", err)
	ae, _ := apperr.As(err)
	assert.Contains(t, ae.Details["fields"].(map[string]string)["names_product"], "imidacloprid")

	in = advisoryInput(ChannelSMS)
	in.TitleTe = "ఇమిడాక్లోప్రిడ్ పిచికారీ"
	_, err = e.svc.CreateAdvisory(ops, in)
	assert.True(t, apperr.Is(err, apperr.KindValidation), "Telugu product name in the title: %v", err)

	in.NamesProduct = true
	created, err := e.svc.CreateAdvisory(ops, in)
	require.NoError(t, err, "ticked: allowed, and goes to Agronomy")
	assert.Equal(t, ClassPromotional, created.Advisory.Class)

	// A clean draft whose text becomes a product name later is caught at submit.
	clean, err := e.svc.CreateAdvisory(ops, advisoryInput(ChannelSMS))
	require.NoError(t, err)
	e.masters.terms = append(e.masters.terms, "bollworm")
	_, err = e.svc.SubmitAdvisory(ops, clean.Advisory.ID, nil)
	assert.True(t, apperr.Is(err, apperr.KindValidation), "%v", err)
	assert.Equal(t, 0, e.count(`SELECT count(*) FROM river_job WHERE kind = 'messaging.advisory_fanout'`))
}

// Regression: with ORed levels and the scope filled into district_ids, a
// scoped user picking one village reached the whole district, and a mandal
// from another district reached outside the scope. With the provider ANDing
// lists (fake below), the scope narrows correctly.
func TestScopedTargetingWithANDProvider(t *testing.T) {
	e := newEnv(t)
	e.farmers.and = e.geo
	// A second village in the same district and mandal, and a village in another district.
	sameDistrict := xmod.Village{ID: ids.New(), MandalID: e.village.MandalID, DistrictID: e.district}
	otherDistrict, otherMandal, otherVillage := ids.New(), ids.New(), ids.New()
	e.exec(`INSERT INTO districts (id, name) VALUES ($1, $2)`, otherDistrict, "Other-"+otherDistrict.String()[24:])
	e.exec(`INSERT INTO mandals (id, district_id, name) VALUES ($1, $2, 'M2')`, otherMandal, otherDistrict)
	e.exec(`INSERT INTO villages (id, mandal_id, name) VALUES ($1, $2, 'V2'), ($3, $4, 'V3')`,
		otherVillage, otherMandal, sameDistrict.ID, e.village.MandalID)
	e.geo.villages[sameDistrict.ID] = sameDistrict
	e.geo.villages[otherVillage] = xmod.Village{ID: otherVillage, MandalID: otherMandal, DistrictID: otherDistrict}
	e.farmer("A", "te", "active", uuid.NullUUID{}, nu(e.village.ID))
	e.farmer("B", "te", "active", uuid.NullUUID{}, nu(sameDistrict.ID))
	e.farmer("C", "te", "active", uuid.NullUUID{}, nu(otherVillage))

	_, scoped := e.ho(auth.RoleOps, e.district)
	n, err := e.svc.PreviewRecipients(scoped, Target{VillageIDs: []uuid.UUID{e.village.ID}})
	require.NoError(t, err)
	assert.Equal(t, 1, n, "one village, not the whole district")
	assert.Equal(t, []uuid.UUID{e.district}, e.farmers.lastT.DistrictIDs, "scope applied")

	n, err = e.svc.PreviewRecipients(scoped, Target{MandalIDs: []uuid.UUID{otherMandal}})
	require.NoError(t, err)
	assert.Equal(t, 0, n, "a mandal outside the scope reaches nobody")

	n, err = e.svc.PreviewRecipients(scoped, Target{})
	require.NoError(t, err)
	assert.Equal(t, 2, n, "empty target = the user's districts")

	_, err = e.svc.PreviewRecipients(scoped, Target{DistrictIDs: []uuid.UUID{e.district, otherDistrict}})
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "district_ids must be a subset of the scope")

	_, admin := e.ho(auth.RoleAdmin)
	n, err = e.svc.PreviewRecipients(admin, Target{})
	require.NoError(t, err)
	assert.Equal(t, 3, n)
}

// Regression: a delivery pushed into quiet hours by retry backoff was sent
// at night. It is snoozed to 07:00 IST instead.
func TestDeliverySnoozedInQuietHours(t *testing.T) {
	e := newEnv(t)
	f := e.farmer("Lakshmi", "te", "active", uuid.NullUUID{}, uuid.NullUUID{})
	require.NoError(t, e.svc.onWelcome(context.Background(), welcomeEvent(f.ID)))
	var id uuid.UUID
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT id FROM deliveries`).Scan(&id))

	e.clock.Set(time.Date(2026, 10, 30, 23, 15, 0, 0, ist))
	err := e.svc.SendDelivery(context.Background(), id, 2, deliveryMaxAttempts)
	var snooze *river.JobSnoozeError
	require.True(t, errors.As(err, &snooze), "%v", err)
	assert.Equal(t, 7*time.Hour+45*time.Minute, snooze.Duration)
	assert.Empty(t, e.sms.sent)
	d, err := e.svc.q.GetDelivery(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, deliveryQueued, d.Status)

	e.clock.Set(time.Date(2026, 10, 31, 7, 0, 0, 0, ist))
	require.NoError(t, e.svc.SendDelivery(context.Background(), id, 2, deliveryMaxAttempts))
	assert.Len(t, e.sms.sent, 1)
}

// Regression: a delivery held overnight still went out after the farmer was
// deactivated or withdrew programme consent.
func TestDeliveryRechecksFarmerAtSendTime(t *testing.T) {
	e := newEnv(t)
	_, ops := e.ho(auth.RoleOps)
	_, agro := e.ho(auth.RoleAgronomy)
	withdrew := e.farmer("A", "te", "active", uuid.NullUUID{}, nu(e.village.ID))
	stays := e.farmer("B", "te", "active", uuid.NullUUID{}, nu(e.village.ID))
	e.farmers.targeted = []uuid.UUID{withdrew.ID, stays.ID}

	in := advisoryInput(ChannelSMS)
	in.NamesProduct = true
	created, err := e.svc.CreateAdvisory(ops, in)
	require.NoError(t, err)
	_, err = e.svc.SubmitAdvisory(ops, created.Advisory.ID, nil)
	require.NoError(t, err)
	_, err = e.svc.ApproveAdvisory(agro, created.Advisory.ID)
	require.NoError(t, err)
	require.NoError(t, e.svc.RunAdvisoryFanout(context.Background(), created.Advisory.ID))
	assert.Equal(t, 2, e.count(`SELECT count(*) FROM deliveries`))

	// Consent withdrawn before the send.
	s := e.farmers.farmers[withdrew.ID]
	s.ProgrammeConsent = false
	e.farmers.farmers[withdrew.ID] = s
	e.sendAll()
	require.Len(t, e.sms.sent, 1)
	assert.Equal(t, stays.Phone, e.sms.sent[0].To)
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM deliveries WHERE farmer_id = $1 AND status = 'skipped'
		AND error = 'no_programme_consent'`, withdrew.ID))

	// A service message to a farmer deactivated before the send.
	gone := e.farmer("C", "te", "active", uuid.NullUUID{}, uuid.NullUUID{})
	require.NoError(t, e.svc.onWelcome(context.Background(), welcomeEvent(gone.ID)))
	s = e.farmers.farmers[gone.ID]
	s.Status = "inactive"
	e.farmers.farmers[gone.ID] = s
	e.sendAll()
	assert.Len(t, e.sms.sent, 1)
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM deliveries WHERE farmer_id = $1 AND status = 'skipped'
		AND error = 'farmer_inactive'`, gone.ID))
}

// FA-10: a new FA alert is pushed to the FA's devices (as a River job), at
// any hour.
func TestFAAlertIsPushed(t *testing.T) {
	e := newEnv(t)
	_, ops := e.ho(auth.RoleOps)
	fa := e.fa("Ravi")
	e.identity.tokens[fa.ID] = []string{"fa-tok-1", "fa-tok-2"}
	e.clock.Set(time.Date(2026, 10, 30, 23, 0, 0, 0, ist)) // quiet hours do not apply to staff

	a, err := e.svc.CreateHONote(ops, HONote{FAID: fa.ID, Title: "Visit Lakshmi today", Body: ptr("She called HO")})
	require.NoError(t, err)
	var args []byte
	require.NoError(t, e.pool.QueryRow(context.Background(),
		`SELECT args FROM river_job WHERE kind = 'messaging.fa_alert_push'`).Scan(&args))
	var job faAlertPushArgs
	require.NoError(t, json.Unmarshal(args, &job))
	assert.Equal(t, a.ID, job.AlertID)

	e.push.fail = true
	assert.Error(t, e.svc.PushFAAlert(context.Background(), a.ID), "no device reached: River retries")
	e.push.fail = false
	require.NoError(t, e.svc.PushFAAlert(context.Background(), a.ID))
	require.Len(t, e.push.sent, 2)
	assert.Equal(t, "Visit Lakshmi today", e.push.sent[0].Title)
	assert.Equal(t, "fa_alert", e.push.sent[0].Data["type"])
	assert.Equal(t, a.ID.String(), e.push.sent[0].Data["alert_id"])

	// No token: nothing to do, not an error. Unknown alert: same.
	delete(e.identity.tokens, fa.ID)
	require.NoError(t, e.svc.PushFAAlert(context.Background(), a.ID))
	require.NoError(t, e.svc.PushFAAlert(context.Background(), ids.New()))
	assert.Len(t, e.push.sent, 2)
}

func TestFAOfflineAlerts(t *testing.T) {
	e := newEnv(t)
	fa := e.fa("Ravi")
	never := e.fa("Sita")
	last := e.clock.Now().Add(-72 * time.Hour)
	ravi := e.identity.fas[fa.ID]
	ravi.LastSyncAt = &last
	e.identity.notSince = []xmod.FieldAssistant{ravi, e.identity.fas[never.ID]}
	e.geo.faDistricts = map[uuid.UUID][]uuid.UUID{fa.ID: {e.district}}

	n, err := e.svc.RaiseFAOfflineAlerts(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 2, n)
	assert.WithinDuration(t, e.clock.Now().Add(-48*time.Hour), e.identity.since, time.Second)

	// The hourly run is idempotent within the IST day ...
	e.clock.Set(e.clock.Now().Add(5 * time.Hour))
	n, err = e.svc.RaiseFAOfflineAlerts(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 0, n)
	// ... and raises again the next day.
	e.clock.Set(e.clock.Now().Add(24 * time.Hour))
	n, err = e.svc.RaiseFAOfflineAlerts(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 2, n)

	// A scoped HO user sees the alerts of FAs in their district.
	_, scoped := e.ho(auth.RoleOps, e.district)
	page, err := e.svc.ListHOAlerts(scoped, ptr(hoAlertFAOffline), nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 2)
	assert.Equal(t, fa.ID, *page.Items[0].FAID)
	var payload map[string]any
	require.NoError(t, json.Unmarshal(page.Items[0].Payload, &payload))
	assert.Equal(t, "Ravi", payload["fa_name"])
	assert.NotNil(t, payload["last_sync_at"])
	assert.Equal(t, 4, e.count(`SELECT count(*) FROM ho_alerts WHERE kind = 'fa_offline'`))
}
