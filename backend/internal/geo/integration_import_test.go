package geo_test

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/geo"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/cache"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

func TestImportVillages(t *testing.T) {
	w := newWorld(t)
	lakshmi := w.fa(t, "Lakshmi Devi", "active")
	w.allocate(t, lakshmi, geo.LevelMandal, w.serilingampally, true)
	villages := func() int { return w.count(t, `SELECT count(*) FROM villages`) }
	start := villages()

	csv := "district,mandal,village,name_te,lgd_code,lat,lng\n" +
		"Rangareddy,Serilingampally,Hafeezpet,హఫీజ్‌పేట్,574200,17.4833,78.3561\n" +
		"rangareddy,SERILINGAMPALLY,Kondapur,,574123,,\n" +
		"Rangareddy,Gandipet,Kokapet,కోకాపేట్,,,\n"
	v := w.version(t, lakshmi)
	res, err := w.svc.ImportVillages(w.admin, strings.NewReader(csv), false)
	require.NoError(t, err)
	assert.Equal(t, geo.ImportResult{Rows: 3, Created: 2, Updated: 1}, res)
	assert.Equal(t, start+2, villages())
	assert.Greater(t, w.version(t, lakshmi), v, "new village in her mandal")

	kondapur, err := w.svc.GetVillage(w.admin, w.kondapur)
	require.NoError(t, err)
	assert.Equal(t, "574123", *kondapur.LGDCode, "matched ignoring case, filled from the row")
	assert.Equal(t, "కొండాపూర్", *kondapur.NameTe, "empty cells keep the stored value")

	// Same file again: idempotent.
	res, err = w.svc.ImportVillages(w.admin, strings.NewReader(csv), false)
	require.NoError(t, err)
	assert.Equal(t, geo.ImportResult{Rows: 3, Unchanged: 3}, res)
	assert.Equal(t, start+2, villages())

	// Unknown areas are row errors and nothing is written.
	bad := "district,mandal,village\nRangareddy,Serilingampally,Kothaguda\nRangareddy,Shamshabad,Tondupally\nNalgonda,Miryalaguda,Alagadapa\n"
	_, err = w.svc.ImportVillages(w.admin, strings.NewReader(bad), false)
	e, ok := apperr.As(err)
	require.True(t, ok, "%v", err)
	assert.Equal(t, "validation_failed", e.Code)
	fields := e.Details["fields"].(map[string]string)
	assert.Contains(t, fields["row 3"], "Shamshabad")
	assert.Contains(t, fields["row 4"], "Nalgonda")
	assert.NotContains(t, fields, "row 2")
	assert.Equal(t, start+2, villages(), "all or nothing")

	// create_missing adds them.
	res, err = w.svc.ImportVillages(w.admin, strings.NewReader(bad), true)
	require.NoError(t, err)
	assert.Equal(t, geo.ImportResult{Rows: 3, Created: 3, DistrictsCreated: 1, MandalsCreated: 2}, res)

	// An LGD code that belongs to another village ends the import.
	clash := "district,mandal,village,lgd_code\nRangareddy,Gandipet,Narsingi,574123\n"
	_, err = w.svc.ImportVillages(w.admin, strings.NewReader(clash), false)
	assert.Equal(t, "lgd_code_taken", errCode(t, err))

	assert.Equal(t, 3, w.count(t, `SELECT count(*) FROM audit_log WHERE action = 'geo.villages_imported'`))
}

// With Redis (dev stack) the tree and FA village lists are cached; skipped
// when Redis is not reachable.
func TestCaching(t *testing.T) {
	w := newWorld(t)
	ctx := context.Background()
	rdb, err := cache.Open("redis://localhost:6379/15")
	require.NoError(t, err)
	c := cache.New(rdb, logx.Discard())
	if err := c.Ping(ctx); err != nil {
		t.Skip("redis not reachable:", err)
	}
	c.Delete(ctx, "geo:tree")
	w.deps.Cache = c
	m := geo.New(w.deps, w.ports)
	svc := m.Service()

	tree, err := svc.AdminTree(w.admin)
	require.NoError(t, err)
	require.Len(t, tree.Districts, 2)
	// A write behind the service's back is not seen: the tree is cached...
	_, err = w.pool.Exec(ctx, `INSERT INTO districts (id, name) VALUES ($1, 'Vikarabad')`, ids.New())
	require.NoError(t, err)
	tree, _ = svc.AdminTree(w.admin)
	assert.Len(t, tree.Districts, 2)
	// ...until a write through the service drops it.
	_, err = svc.CreateDistrict(w.admin, geo.DistrictFields{Name: str("Nalgonda")})
	require.NoError(t, err)
	tree, _ = svc.AdminTree(w.admin)
	assert.Len(t, tree.Districts, 4)

	fa := w.fa(t, "Suresh K", "active")
	_, err = svc.CreateAllocation(w.admin, geo.NewAllocation{FAID: fa, Level: geo.LevelVillage, AreaID: w.kondapur, IsLead: true})
	require.NoError(t, err)
	got, err := svc.VillageIDsForFA(ctx, fa)
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{w.kondapur}, got)
	// Allocation added without a bump: still the cached list.
	_, err = w.pool.Exec(ctx, `INSERT INTO fa_allocations (id, fa_id, level, village_id) VALUES ($1, $2, 'village', $3)`, ids.New(), fa, w.gachibowli)
	require.NoError(t, err)
	got, _ = svc.VillageIDsForFA(ctx, fa)
	assert.Len(t, got, 1)
	// A bump changes the key.
	require.NoError(t, db.WithTx(ctx, w.pool, func(tx pgx.Tx) error { return territory.Bump(ctx, tx, fa) }))
	got, _ = svc.VillageIDsForFA(ctx, fa)
	assert.ElementsMatch(t, []uuid.UUID{w.kondapur, w.gachibowli}, got)
	c.Delete(ctx, "geo:tree")
}
