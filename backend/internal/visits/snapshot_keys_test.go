package visits

import (
	"encoding/json"
	"slices"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// The snapshot sections are hand-parsed by the FA app and documented in
// sync.yaml (Snap* schemas): their JSON keys must not drift. Every key is
// always present (nullable values are null, never omitted).
func TestSnapshotJSONKeysAreStable(t *testing.T) {
	keys := func(v any) string {
		raw, err := json.Marshal(v)
		require.NoError(t, err)
		var m map[string]any
		require.NoError(t, json.Unmarshal(raw, &m))
		var out []string
		for k := range m {
			out = append(out, k)
		}
		slices.Sort(out)
		return strings.Join(out, " ")
	}
	sorted := func(s string) string {
		f := strings.Fields(s)
		slices.Sort(f)
		return strings.Join(f, " ")
	}
	assert.Equal(t, sorted("id farmer_id plot_id season_id fa_id status planned_for planned_slot purpose visited_at "+
		"farmer_present stage_id stage_name stage_name_te notes photo_count issues"), keys(SnapshotVisit{}))
	assert.Equal(t, sorted("id issue_id issue_name issue_name_te severity advice_status rule_id salt_id salt_name "+
		"salt_name_te sku_id product_name product_name_te dose dose_te"), keys(SnapshotIssue{}))
	assert.Equal(t, sorted("id farmer_id requested_at"), keys(SnapshotCallback{}))
}
