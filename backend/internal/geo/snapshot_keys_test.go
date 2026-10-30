package geo

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
	assert.Equal(t, sorted("id name name_te lgd_code lat lng mandal_id mandal_name mandal_name_te district_id "+
		"district_name district_name_te created_at"), keys(VillageInfo{}))
}
