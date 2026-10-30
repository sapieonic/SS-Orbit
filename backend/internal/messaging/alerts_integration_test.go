package messaging

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	platformsms "github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/platform/testutil"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

func welcomeEvent(farmerID uuid.UUID) events.FarmerRegistered {
	return events.FarmerRegistered{FarmerID: farmerID, Source: "self"}
}

func (e *env) version(faID uuid.UUID) int64 {
	v, err := territory.Version(context.Background(), e.pool, faID)
	require.NoError(e.t, err)
	return v
}

func TestFarmerRegisteredSubscribers(t *testing.T) {
	e := newEnv(t)
	ctx := context.Background()
	fa := e.fa("Ravi")
	f := e.farmer("Lakshmi", "te", "active", nu(fa.ID), nu(e.village.ID))
	ev := events.FarmerRegistered{FarmerID: f.ID, VillageID: &e.village.ID, Source: "self"}

	for range 2 { // at-least-once delivery: the second run is a no-op
		require.NoError(t, e.svc.onFarmerRegistered(ctx, ev))
		require.NoError(t, e.svc.onWelcome(ctx, ev))
	}
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM fa_alerts WHERE fa_id = $1 AND kind = 'new_farmer'`, fa.ID))
	assert.EqualValues(t, 1, e.version(fa.ID), "FA snapshot invalidated once")
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM ho_alerts WHERE kind = 'new_farmer' AND district_id = $1 AND fa_id = $2`, e.district, fa.ID))
	assert.Equal(t, 0, e.count(`SELECT count(*) FROM ho_alerts WHERE kind = 'farmer_without_fa'`))

	// Welcome: one notice and one Telugu SMS.
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM notices WHERE farmer_id = $1 AND ref_type = 'welcome'`, f.ID))
	e.sendAll()
	require.Len(t, e.sms.sent, 1)
	assert.Contains(t, e.sms.sent[0].Body, "నమస్కారం Lakshmi")
	assert.Equal(t, platformsms.DLTWelcomeTe, e.sms.sent[0].TemplateID)
	assert.Equal(t, f.Phone, e.sms.sent[0].To)

	// The HO overview names the farmer, the area and the FA notified.
	_, admin := e.ho(auth.RoleAdmin)
	page, err := e.svc.ListHOAlerts(admin, nil, nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	var payload map[string]any
	require.NoError(t, json.Unmarshal(page.Items[0].Payload, &payload))
	assert.Equal(t, "Lakshmi", payload["farmer_name"])
	assert.Equal(t, "Kondapur", payload["village_name"])
	assert.Equal(t, "Ravi", payload["fa_name"])

	// An FA-enrolled farmer: no FA alert (the FA enrolled them), HO still told.
	f2 := e.farmer("Suresh", "te", "active", nu(fa.ID), nu(e.village.ID))
	require.NoError(t, e.svc.onFarmerRegistered(ctx, events.FarmerRegistered{FarmerID: f2.ID, Source: "fa", EnrolledByFAID: &fa.ID}))
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM fa_alerts`))
	assert.Equal(t, 2, e.count(`SELECT count(*) FROM ho_alerts WHERE kind = 'new_farmer'`))

	// Area scope: a user for another district sees nothing.
	_, scoped := e.ho(auth.RoleOps, ids.New())
	page, err = e.svc.ListHOAlerts(scoped, nil, nil, nil)
	require.NoError(t, err)
	assert.Empty(t, page.Items)
}

func TestSelfSignUpThenProfileCompleted(t *testing.T) {
	e := newEnv(t)
	ctx := context.Background()
	f := e.farmer("Anil", "te", "pending_profile", uuid.NullUUID{}, uuid.NullUUID{})

	// Signed up without a village: HO hears of it, nobody else can yet.
	require.NoError(t, e.svc.onFarmerRegistered(ctx, events.FarmerRegistered{FarmerID: f.ID, Source: "self"}))
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM ho_alerts WHERE kind = 'new_farmer' AND district_id IS NULL`))
	assert.Equal(t, 0, e.count(`SELECT count(*) FROM ho_alerts WHERE kind = 'farmer_without_fa'`))

	// Picked a village that no FA covers.
	f.VillageID = nu(e.village.ID)
	e.farmers.farmers[f.ID] = f
	require.NoError(t, e.svc.onProfileCompleted(ctx, events.FarmerProfileCompleted{FarmerID: f.ID, VillageID: e.village.ID}))
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM ho_alerts WHERE kind = 'new_farmer' AND district_id = $1`, e.district),
		"the earlier alert gets its district")
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM ho_alerts WHERE kind = 'farmer_without_fa' AND farmer_id = $1`, f.ID))
	assert.Equal(t, 0, e.count(`SELECT count(*) FROM fa_alerts`))

	// Another farmer whose village has an FA: the FA is alerted on profile completion.
	fa := e.fa("Ravi")
	g := e.farmer("Gita", "te", "active", nu(fa.ID), nu(e.village.ID))
	require.NoError(t, e.svc.onProfileCompleted(ctx, events.FarmerProfileCompleted{FarmerID: g.ID, VillageID: e.village.ID}))
	require.NoError(t, e.svc.onFarmerRegistered(ctx, events.FarmerRegistered{FarmerID: g.ID, Source: "self"}))
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM fa_alerts WHERE fa_id = $1 AND farmer_id = $2`, fa.ID, g.ID), "deduplicated")
}

func TestOtherSubscribers(t *testing.T) {
	e := newEnv(t)
	ctx := context.Background()
	oldFA, newFA := e.fa("Ravi"), e.fa("Kiran")
	te := e.farmer("Lakshmi", "te", "active", nu(newFA.ID), nu(e.village.ID))
	en := e.farmer("Suresh", "en", "active", nu(newFA.ID), nu(e.village.ID))

	// Callback request -> FA alert, once.
	cb := events.CallbackRequested{CallbackID: ids.New(), FarmerID: te.ID, FAID: newFA.ID}
	require.NoError(t, e.svc.onCallbackRequested(ctx, cb))
	require.NoError(t, e.svc.onCallbackRequested(ctx, cb))
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM fa_alerts WHERE kind = 'callback' AND ref_id = $1`, cb.CallbackID))

	// Reassignment -> each farmer is told the new FA's name, once per event.
	re := events.FarmersReassigned{FarmerIDs: []uuid.UUID{te.ID, en.ID}, FromFAID: &oldFA.ID, ToFAID: newFA.ID}
	require.NoError(t, e.svc.onFarmersReassigned(ctx, re))
	require.NoError(t, e.svc.onFarmersReassigned(ctx, re))
	assert.Equal(t, 2, e.count(`SELECT count(*) FROM notices WHERE ref_type = 'fa_assignment'`))

	// Visit logged -> advice notice and SMS summary.
	visitID := ids.New()
	e.visits.advice[visitID] = xmod.VisitAdvice{VisitID: visitID, FarmerID: en.ID, FAID: newFA.ID, VisitedAt: e.clock.Now(),
		Items: []xmod.AdviceItem{{IssueName: "Aphids", IssueNameTe: "పేను బంక", Severity: "low", SaltName: "Imidacloprid"}}}
	vl := events.VisitLogged{VisitID: visitID, FarmerID: en.ID, FAID: newFA.ID}
	require.NoError(t, e.svc.onVisitLogged(ctx, vl))
	require.NoError(t, e.svc.onVisitLogged(ctx, vl))
	assert.Equal(t, 1, e.count(`SELECT count(*) FROM notices WHERE kind = 'visit_advice' AND sender = 'fa' AND ref_id = $1`, visitID))
	require.NoError(t, e.svc.onVisitLogged(ctx, events.VisitLogged{VisitID: ids.New(), FarmerID: en.ID}), "unknown visit is skipped")

	e.sendAll()
	require.Len(t, e.sms.sent, 3)
	bodies := map[string]string{}
	for _, m := range e.sms.sent {
		bodies[m.To] += m.Body + "\n"
	}
	assert.Contains(t, bodies[te.Phone], "కొత్త ఫీల్డ్ అసిస్టెంట్ Kiran")
	assert.Contains(t, bodies[en.Phone], "Your new field assistant is Kiran")
	assert.Contains(t, bodies[en.Phone], "found 1 problem(s)")
	assert.Contains(t, bodies[en.Phone], "/web/notices/")
}

func TestAckAlertAndSnapshot(t *testing.T) {
	e := newEnv(t)
	fa := e.fa("Ravi")
	f := e.farmer("Lakshmi", "te", "active", nu(fa.ID), nu(e.village.ID))
	reg := commands.NewRegistry()
	e.mod.RegisterCommands(reg)
	treg := territory.NewRegistry()
	e.mod.RegisterSnapshot(treg)
	treg.SetResolver(func(context.Context, uuid.UUID) (territory.Scope, error) { return territory.Scope{}, nil })

	require.NoError(t, e.svc.onFarmerRegistered(context.Background(), events.FarmerRegistered{FarmerID: f.ID, Source: "self"}))
	_, admin := e.ho(auth.RoleAdmin)
	note, err := e.svc.CreateHONote(admin, HONote{FAID: fa.ID, Title: "  Visit Kondapur on Monday ", FarmerID: &f.ID})
	require.NoError(t, err)
	assert.Equal(t, "Visit Kondapur on Monday", note.Title)
	assert.Equal(t, "ho_note", note.Kind)
	_, err = e.svc.CreateHONote(admin, HONote{FAID: ids.New(), Title: "x"})
	assert.True(t, apperr.Is(err, apperr.KindNotFound))
	assert.EqualValues(t, 2, e.version(fa.ID))

	snap, err := treg.Build(context.Background(), fa.ID)
	require.NoError(t, err)
	alerts := snap[territory.SectionAlerts].([]FieldAlert)
	require.Len(t, alerts, 2)
	raw, _ := json.Marshal(alerts[0])
	assert.Contains(t, string(raw), `"kind":"ho_note"`)

	faP := testutil.FA()
	faP.ID = fa.ID
	ctx := testutil.Ctx(faP)
	cmd := func(id uuid.UUID) commands.Command {
		payload, _ := json.Marshal(map[string]any{"alert_id": id})
		return commands.Command{ID: ids.New(), Type: "AckAlert", Payload: payload}
	}
	res, err := reg.Dispatch(ctx, faP, cmd(note.ID))
	require.NoError(t, err)
	assert.Equal(t, commands.StatusApplied, res.Status)
	res, err = reg.Dispatch(ctx, faP, cmd(note.ID))
	require.NoError(t, err)
	assert.Equal(t, commands.StatusApplied, res.Status, "idempotent")
	assert.EqualValues(t, 3, e.version(fa.ID), "bumped once for the ack")

	other := testutil.FA()
	res, err = reg.Dispatch(testutil.Ctx(other), other, cmd(note.ID))
	require.NoError(t, err)
	assert.Equal(t, commands.StatusRejected, res.Status, "another FA's alert")

	page, err := e.svc.ListFAAlerts(ctx, ptr("acknowledged"), nil, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	require.NotNil(t, page.Items[0].FarmerName)
	assert.Equal(t, "Lakshmi", *page.Items[0].FarmerName)
	assert.Equal(t, f.Phone, *page.Items[0].FarmerPhone)
	assert.NotNil(t, page.Items[0].AcknowledgedAt)

	// Old alerts drop out of the snapshot.
	e.clock.Advance((snapshotAlertDays + 1) * 24 * time.Hour)
	snap, err = treg.Build(context.Background(), fa.ID)
	require.NoError(t, err)
	assert.Empty(t, snap[territory.SectionAlerts])
}

func TestFarmerInbox(t *testing.T) {
	e := newEnv(t)
	f := e.farmer("Lakshmi", "te", "active", uuid.NullUUID{}, uuid.NullUUID{})
	other := e.farmer("Suresh", "te", "active", uuid.NullUUID{}, uuid.NullUUID{})
	require.NoError(t, e.svc.onWelcome(context.Background(), welcomeEvent(f.ID)))
	require.NoError(t, e.svc.onWelcome(context.Background(), welcomeEvent(other.ID)))
	visitID := ids.New()
	e.visits.advice[visitID] = xmod.VisitAdvice{VisitID: visitID, VisitedAt: e.clock.Now()}
	require.NoError(t, e.svc.onVisitLogged(context.Background(), events.VisitLogged{VisitID: visitID, FarmerID: f.ID}))

	p := testutil.Farmer()
	p.ID = f.ID
	ctx := testutil.Ctx(p)
	n, err := e.svc.UnreadCount(ctx)
	require.NoError(t, err)
	assert.Equal(t, 2, n)

	one := 1
	page, err := e.svc.ListNotices(ctx, &one, nil)
	require.NoError(t, err)
	require.Len(t, page.Items, 1)
	require.NotNil(t, page.NextCursor)
	page2, err := e.svc.ListNotices(ctx, &one, page.NextCursor)
	require.NoError(t, err)
	require.Len(t, page2.Items, 1)
	assert.NotEqual(t, page.Items[0].ID, page2.Items[0].ID)

	id := page.Items[0].ID
	require.NoError(t, e.svc.MarkRead(ctx, id))
	require.NoError(t, e.svc.MarkRead(ctx, id), "idempotent")
	require.NoError(t, e.svc.MarkListened(ctx, page2.Items[0].ID))
	n, _ = e.svc.UnreadCount(ctx)
	assert.Equal(t, 0, n, "listening marks read too")
	assert.Equal(t, 2, e.count(`SELECT count(*) FROM audit_log WHERE action IN ('messaging.notice_read', 'messaging.notice_listened')`))

	var otherNotice uuid.UUID
	require.NoError(t, e.pool.QueryRow(context.Background(), `SELECT id FROM notices WHERE farmer_id = $1`, other.ID).Scan(&otherNotice))
	assert.True(t, apperr.Is(e.svc.MarkRead(ctx, otherNotice), apperr.KindNotFound), "someone else's notice")
	assert.True(t, apperr.Is(e.svc.MarkRead(ctx, ids.New()), apperr.KindNotFound))
}
