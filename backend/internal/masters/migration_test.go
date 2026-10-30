package masters_test

import (
	"context"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/masters"
	"github.com/sapionic/orbit/backend/migrations"
)

// gooseSection returns the Up or Down SQL of an embedded migration file.
func gooseSection(t *testing.T, file, section string) string {
	t.Helper()
	raw, err := migrations.FS.ReadFile(file)
	require.NoError(t, err)
	src := string(raw)
	up := strings.Index(src, "-- +goose Up")
	down := strings.Index(src, "-- +goose Down")
	require.True(t, up >= 0 && down > up, file)
	if section == "Up" {
		return src[up:down]
	}
	return src[down:]
}

// TestMastersMigrationsRollBack rolls 00018 and then 00012 back and forward
// again, inside a transaction that is rolled back, with data that used to make
// 00012's Down fail: an inactive stage sharing its seq with an active one, and
// an issue with two live rules (one per salt).
func TestMastersMigrationsRollBack(t *testing.T) {
	f := newFixture(t)
	c := f.seedCatalog(t)
	ctx := context.Background()

	// Seedling (seq 1) is dropped from the calendar: it stays, inactive, at seq 1,
	// and square becomes the active seq 1.
	_, err := f.svc.ReplaceStages(f.agronomyA, c.crop.ID, []masters.StageInput{
		{Code: "square", Name: "Square", NameTe: "మొగ్గ", StartDay: 0, EndDay: 70},
		{Code: "boll", Name: "Boll", NameTe: "కాయ", StartDay: 71, EndDay: 160},
	})
	require.NoError(t, err)
	assert.Equal(t, 2, f.count(t, `SELECT count(*) FROM crop_stages WHERE crop_id = $1 AND seq = 1`, c.crop.ID))

	salt2, err := f.svc.CreateSalt(f.admin, "Chlorantraniliprole 18.5% SC", nil)
	require.NoError(t, err)
	var live []masters.Rule
	for _, salt := range []masters.Salt{c.salt, salt2} {
		r, err := f.svc.CreateRuleDraft(f.agronomyA, masters.RuleInput{IssueID: c.issue.ID, SaltID: salt.ID, Dose: "1 kg", DoseTe: "1 కిలో"})
		require.NoError(t, err)
		_, err = f.svc.SubmitRule(f.agronomyA, r.ID)
		require.NoError(t, err)
		r, err = f.svc.ApproveRule(f.agronomyB, r.ID, nil)
		require.NoError(t, err)
		live = append(live, r)
	}

	tx, err := f.pool.Begin(ctx)
	require.NoError(t, err)
	defer func() { _ = tx.Rollback(ctx) }()
	exec := func(file, section string) {
		t.Helper()
		_, err := tx.Exec(ctx, gooseSection(t, file, section))
		require.NoError(t, err, "%s %s", file, section)
	}
	count := func(sql string, args ...any) int {
		t.Helper()
		var n int
		require.NoError(t, tx.QueryRow(ctx, sql, args...).Scan(&n))
		return n
	}

	exec("00018_masters_rules_per_salt.sql", "Down")
	assert.Equal(t, 1, count(`SELECT count(*) FROM advisory_rules WHERE issue_id = $1 AND status = 'approved'`, c.issue.ID))
	assert.Equal(t, 1, count(`SELECT count(*) FROM advisory_rules WHERE id = $1 AND status = 'approved'`, live[1].ID),
		"the most recently approved rule stays live")
	assert.Equal(t, 0, count(`SELECT count(*) FROM (SELECT seq FROM crop_stages WHERE crop_id = $1 GROUP BY seq HAVING count(*) > 1) d`, c.crop.ID),
		"inactive stages moved out of the way")
	assert.Equal(t, 1, count(`SELECT count(*) FROM crop_stages s WHERE crop_id = $1 AND code = 'seedling'
		AND seq > (SELECT max(seq) FROM crop_stages a WHERE a.crop_id = s.crop_id AND a.active)`, c.crop.ID))

	exec("00012_masters_review.sql", "Down")
	exec("00012_masters_review.sql", "Up")
	exec("00018_masters_rules_per_salt.sql", "Up")
	assert.Equal(t, 1, count(`SELECT count(*) FROM pg_indexes WHERE indexname = 'advisory_rules_one_live_per_issue_salt'`))
	require.NoError(t, tx.Rollback(ctx))
	assert.ErrorIs(t, tx.Commit(ctx), pgx.ErrTxClosed)
}

func TestProductTerms(t *testing.T) {
	f := newFixture(t)
	c := f.seedCatalog(t)
	_, err := f.svc.UpdateSKU(f.admin, c.sku.ID, masters.SKUPatch{ProductNameTe: ptr(" శాంపిల్ 5 SG ")})
	require.NoError(t, err)
	off, err := f.svc.CreateSalt(f.admin, "Retired Salt", nil)
	require.NoError(t, err)
	_, err = f.svc.UpdateSalt(f.admin, off.ID, masters.SaltPatch{Active: ptr(false)})
	require.NoError(t, err)

	terms, err := f.svc.ProductTerms(context.Background())
	require.NoError(t, err)
	assert.Equal(t, []string{"emamectin benzoate 5% sg", "sample 5 sg", "ఎమామెక్టిన్", "శాంపిల్ 5 sg"}, terms,
		"active products and salts, English and Telugu, lower-cased; inactive salts left out")
}
