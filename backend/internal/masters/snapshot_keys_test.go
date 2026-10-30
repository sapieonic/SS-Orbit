package masters

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
	assert.Equal(t, sorted("version crops issues salts skus rules season_codes"), keys(Snapshot{}))
	assert.Equal(t, sorted("current next all_open valid_until"), keys(SeasonCodeSet{}))
	assert.Equal(t, sorted("id code name name_te duration_days stages"), keys(SnapCrop{}))
	assert.Equal(t, sorted("id code name name_te seq start_day end_day"), keys(SnapStage{}))
	assert.Equal(t, sorted("id crop_id type name name_te"), keys(SnapIssue{}))
	assert.Equal(t, sorted("id name name_te"), keys(SnapSalt{}))
	assert.Equal(t, sorted("id code product_name product_name_te salt_id pack_size mrp_paise cashback_eligible"), keys(SnapSKU{}))
	assert.Equal(t, sorted("id rule_key version issue_id salt_id sku_id dose_per_acre dose_per_acre_te"), keys(SnapRule{}))
}
