package messaging

import (
	"bytes"
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
)

func advisoryInput(channels ...string) AdvisoryInput {
	return AdvisoryInput{
		TitleTe: "తెగులు హెచ్చరిక", BodyTe: "పత్తిలో గులాబీ పురుగు కనిపిస్తోంది. పొలం చూసుకోండి.",
		TitleEn: ptr("Pest alert"), BodyEn: ptr("Pink bollworm seen in cotton. Check your field."),
		Channels: channels,
	}
}

func TestAdvisoryEndToEnd(t *testing.T) {
	e := newEnv(t)
	_, ops := e.ho(auth.RoleOps)
	fa := e.fa("Ravi")
	teFarmer := e.farmer("Lakshmi", "te", "active", nu(fa.ID), nu(e.village.ID))
	enFarmer := e.farmer("Suresh", "en", "active", nu(fa.ID), nu(e.village.ID))
	e.identity.tokens[enFarmer.ID] = []string{"tok-1"}
	e.farmers.targeted = []uuid.UUID{teFarmer.ID, enFarmer.ID, ids.New()} // the unknown one is skipped

	in := advisoryInput(ChannelSMS, ChannelPush, ChannelWhatsApp)
	in.AudioContentType = ptr("audio/mpeg")
	in.Target.VillageIDs = []uuid.UUID{e.village.ID}
	created, err := e.svc.CreateAdvisory(ops, in)
	require.NoError(t, err)
	adv := created.Advisory
	assert.Equal(t, StatusDraft, adv.Status)
	assert.Equal(t, ClassService, adv.Class)
	require.NotNil(t, created.AudioUpload)
	assert.Equal(t, "PUT", created.AudioUpload.Method)
	assert.Nil(t, created.ImageUpload)

	n, err := e.svc.PreviewRecipients(ops, in.Target)
	require.NoError(t, err)
	assert.Equal(t, 3, n)
	assert.Equal(t, []uuid.UUID{e.village.ID}, e.farmers.lastT.VillageIDs)

	// Submitting before the voice note is uploaded is refused.
	_, err = e.svc.SubmitAdvisory(ops, adv.ID, nil)
	assert.True(t, apperr.Is(err, apperr.KindValidation), "%v", err)
	require.NoError(t, e.deps.Storage.Put(context.Background(), *adv.AudioKey, "audio/mpeg", bytes.NewReader([]byte("mp3"))))

	adv, err = e.svc.SubmitAdvisory(ops, adv.ID, nil)
	require.NoError(t, err)
	assert.Equal(t, StatusScheduled, adv.Status, "no product named: no approval needed")
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM river_job WHERE kind = 'messaging.advisory_fanout'`))

	_, err = e.svc.SubmitAdvisory(ops, adv.ID, nil)
	assert.True(t, apperr.Is(err, apperr.KindConflict), "submit twice")
	_, err = e.svc.CancelAdvisory(ops, ids.New())
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	// Fan-out: one notice per eligible farmer, a delivery per channel.
	require.NoError(t, e.svc.RunAdvisoryFanout(context.Background(), adv.ID))
	got, err := e.svc.GetAdvisory(ops, adv.ID)
	require.NoError(t, err)
	assert.Equal(t, StatusSent, got.Status)
	require.NotNil(t, got.RecipientCount)
	assert.Equal(t, 2, *got.RecipientCount)
	assert.NotNil(t, got.AudioURL)
	assert.Equal(t, 2, got.Stats.Notices)
	assert.Equal(t, 6, got.Stats.Deliveries["sms.queued"]+got.Stats.Deliveries["push.queued"]+got.Stats.Deliveries["whatsapp.queued"])
	assert.Equal(t, 6, e.count(`SELECT count(*) FROM river_job WHERE kind = 'messaging.delivery'`))

	// Running again (redelivered job) changes nothing.
	require.NoError(t, e.svc.RunAdvisoryFanout(context.Background(), adv.ID))
	// A run that stopped half way resumes without duplicates.
	e.exec(`UPDATE advisories SET status = 'sending' WHERE id = $1`, adv.ID)
	require.NoError(t, e.svc.RunAdvisoryFanout(context.Background(), adv.ID))
	assert.Equal(t, 2, e.count(`SELECT count(*) FROM notices WHERE advisory_id = $1`, adv.ID))
	assert.Equal(t, 6, e.count(`SELECT count(*) FROM deliveries`))

	// Send everything.
	e.sendAll()
	assert.Equal(t, 2, len(e.sms.sent), "one SMS per farmer: WhatsApp sends nothing until a provider is integrated")
	assert.Equal(t, 2, e.count(`SELECT count(*) FROM deliveries WHERE channel = 'whatsapp' AND status = 'skipped'
		AND error = 'whatsapp_not_configured'`))
	require.Len(t, e.push.sent, 1, "only the farmer with a push token")
	assert.Equal(t, "Pest alert", e.push.sent[0].Title, "push in the farmer's language")
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM deliveries WHERE status = 'skipped' AND error = 'no push token'`))
	for _, m := range e.sms.sent {
		assert.Contains(t, m.Body, "/web/notices/", "voice note: the SMS links to the page")
		assert.NotContains(t, m.Body, linkMarker)
		assert.NotEmpty(t, m.TemplateID)
	}

	page, err := e.svc.ListRecipients(ops, adv.ID, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 2)
	assert.Len(t, page.Items[0].Deliveries, 3)

	list, err := e.svc.ListAdvisories(ops, ptr(StatusSent), nil, nil)
	require.NoError(t, err)
	assert.Len(t, list.Items, 1)
	assert.Equal(t, 3, e.count(`SELECT count(DISTINCT action) FROM audit_log WHERE entity_id = $1 AND action IN
		('messaging.advisory_created', 'messaging.advisory_submitted', 'messaging.advisory_sent')`, adv.ID))
}

func TestProductAdvisoryNeedsAgronomyApproval(t *testing.T) {
	e := newEnv(t)
	author, agro := e.ho(auth.RoleAgronomy)
	_, agro2 := e.ho(auth.RoleAgronomy)
	_, admin := e.ho(auth.RoleAdmin)
	_, finance := e.ho(auth.RoleFinance)

	in := advisoryInput(ChannelSMS)
	in.NamesProduct = true
	_, err := e.svc.CreateAdvisory(finance, in)
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "finance cannot send advisories")

	created, err := e.svc.CreateAdvisory(agro, in)
	require.NoError(t, err)
	assert.Equal(t, ClassPromotional, created.Advisory.Class)

	sendAt := e.clock.Now().Add(2 * time.Hour)
	adv, err := e.svc.SubmitAdvisory(admin, created.Advisory.ID, &sendAt)
	require.NoError(t, err)
	assert.Equal(t, StatusPendingApproval, adv.Status)
	assert.Equal(t, 0, e.count(`SELECT count(*) FROM river_job`), "nothing queued before approval")

	_, err = e.svc.ApproveAdvisory(agro, adv.ID)
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "author cannot approve")
	_, err = e.svc.ApproveAdvisory(admin, adv.ID)
	assert.True(t, apperr.Is(err, apperr.KindForbidden), "admin cannot approve agronomy content")

	adv, err = e.svc.RejectAdvisory(agro2, adv.ID, "Name the dose")
	require.NoError(t, err)
	assert.Equal(t, StatusDraft, adv.Status)
	assert.Equal(t, "Name the dose", *adv.ReviewNote)

	_, err = e.svc.SubmitAdvisory(admin, adv.ID, &sendAt)
	require.NoError(t, err)
	adv, err = e.svc.ApproveAdvisory(agro2, adv.ID)
	require.NoError(t, err)
	assert.Equal(t, StatusScheduled, adv.Status)
	require.NotNil(t, adv.ApprovedBy)
	assert.NotEqual(t, author.ID, *adv.ApprovedBy)
	assert.True(t, sendAt.Equal(*adv.ScheduledFor), "keeps the requested send time")
	var scheduledAt time.Time
	require.NoError(t, e.pool.QueryRow(context.Background(),
		`SELECT scheduled_at FROM river_job WHERE kind = 'messaging.advisory_fanout'`).Scan(&scheduledAt))
	assert.WithinDuration(t, sendAt, scheduledAt, time.Second)

	// Cancel before it goes out; the queued job then does nothing.
	adv, err = e.svc.CancelAdvisory(admin, adv.ID)
	require.NoError(t, err)
	assert.Equal(t, StatusCancelled, adv.Status)
	e.clock.Set(sendAt)
	require.NoError(t, e.svc.RunAdvisoryFanout(context.Background(), adv.ID))
	assert.Equal(t, 0, e.count(`SELECT count(*) FROM notices`))
	_, err = e.svc.CancelAdvisory(admin, adv.ID)
	assert.True(t, apperr.Is(err, apperr.KindConflict))
}

func TestFanoutQuietHoursAndPromotionalConsent(t *testing.T) {
	e := newEnv(t)
	_, ops := e.ho(auth.RoleOps)
	active := e.farmer("A", "te", "active", uuid.NullUUID{}, nu(e.village.ID))
	pending := e.farmer("P", "te", "pending_profile", uuid.NullUUID{}, uuid.NullUUID{})
	e.farmers.targeted = []uuid.UUID{active.ID, pending.ID}

	in := advisoryInput(ChannelSMS)
	in.NamesProduct = true
	in.Class = ptr(ClassPromotional)
	created, err := e.svc.CreateAdvisory(ops, in)
	require.NoError(t, err)
	_, agro := e.ho(auth.RoleAgronomy)
	_, err = e.svc.SubmitAdvisory(ops, created.Advisory.ID, nil)
	require.NoError(t, err)

	late := time.Date(2026, 10, 30, 22, 30, 0, 0, ist)
	e.clock.Set(late)
	_, err = e.svc.ApproveAdvisory(agro, created.Advisory.ID)
	require.NoError(t, err)
	require.NoError(t, e.svc.RunAdvisoryFanout(context.Background(), created.Advisory.ID))

	// Promotional: only the consented, active farmer.
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM notices WHERE farmer_id = $1`, active.ID))
	assert.Equal(t, 0, e.count(`SELECT count(*) FROM notices WHERE farmer_id = $1`, pending.ID))

	// The notice is in the inbox now; the SMS waits for 07:00 IST.
	var scheduledFor, jobAt time.Time
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT scheduled_for FROM deliveries`).Scan(&scheduledFor))
	require.NoError(t, e.pool.QueryRow(context.Background(),
		`SELECT scheduled_at FROM river_job WHERE kind = 'messaging.delivery'`).Scan(&jobAt))
	want := time.Date(2026, 10, 31, 7, 0, 0, 0, ist)
	assert.True(t, want.Equal(scheduledFor), "got %s", scheduledFor.In(ist))
	assert.WithinDuration(t, want, jobAt, time.Second)
}

func TestAdvisoryAreaScope(t *testing.T) {
	e := newEnv(t)
	other := ids.New()
	e.exec(`INSERT INTO districts (id, name) VALUES ($1, $2)`, other, "Other-"+other.String()[24:])
	_, scoped := e.ho(auth.RoleOps, e.district)
	_, admin := e.ho(auth.RoleAdmin)

	created, err := e.svc.CreateAdvisory(scoped, advisoryInput(ChannelSMS))
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{e.district}, created.Advisory.Target.DistrictIDs)

	in := advisoryInput(ChannelSMS)
	in.Target.DistrictIDs = []uuid.UUID{other}
	_, err = e.svc.CreateAdvisory(scoped, in)
	assert.True(t, apperr.Is(err, apperr.KindForbidden))

	everywhere, err := e.svc.CreateAdvisory(admin, advisoryInput(ChannelSMS))
	require.NoError(t, err)

	list, err := e.svc.ListAdvisories(scoped, nil, nil, nil)
	require.NoError(t, err)
	require.Len(t, list.Items, 1, "scoped user sees only advisories inside their districts")
	assert.Equal(t, created.Advisory.ID, list.Items[0].ID)
	_, err = e.svc.GetAdvisory(scoped, everywhere.Advisory.ID)
	assert.True(t, apperr.Is(err, apperr.KindNotFound))
	_, err = e.svc.CancelAdvisory(scoped, everywhere.Advisory.ID)
	assert.True(t, apperr.Is(err, apperr.KindNotFound))

	all, err := e.svc.ListAdvisories(admin, nil, nil, nil)
	require.NoError(t, err)
	assert.Len(t, all.Items, 2)
}

func TestDeliveryRetriesThenFails(t *testing.T) {
	e := newEnv(t)
	f := e.farmer("Lakshmi", "te", "active", uuid.NullUUID{}, uuid.NullUUID{})
	require.NoError(t, e.svc.onWelcome(context.Background(), welcomeEvent(f.ID)))
	var id uuid.UUID
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT id FROM deliveries`).Scan(&id))

	e.sms.fail = true
	err := e.svc.SendDelivery(context.Background(), id, 1, 3)
	require.Error(t, err, "error makes River retry with backoff")
	d, _ := e.svc.q.GetDelivery(context.Background(), id)
	assert.Equal(t, deliveryQueued, d.Status)
	assert.EqualValues(t, 1, d.Attempts)
	require.NotNil(t, d.Error)

	require.NoError(t, e.svc.SendDelivery(context.Background(), id, 3, 3), "last attempt: recorded, not retried")
	d, _ = e.svc.q.GetDelivery(context.Background(), id)
	assert.Equal(t, deliveryFailed, d.Status)

	e.sms.fail = false
	require.NoError(t, e.svc.SendDelivery(context.Background(), id, 4, 3))
	assert.Empty(t, e.sms.sent, "a failed delivery is not sent again")
	assert.True(t, strings.HasPrefix(*d.Error, "provider down"))
}
