package farmers

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
	assert.Equal(t, sorted("id phone name name_te language village_id source photo_key plan status consents_granted "+
		"consent_pending profile_completed_at version created_at updated_at"), keys(snapFarmer{}))
	assert.Equal(t, sorted("id farmer_id label village_id boundary pin area_acres area_source gps_accuracy_m status version updated_at"),
		keys(snapPlot{}))
	assert.Equal(t, sorted("lat lng"), keys(Point{}))
	assert.Equal(t, sorted("id farmer_id plot_id season_code crop_id sowing_date previous_crop_id status version updated_at"),
		keys(snapSeason{}))
}
