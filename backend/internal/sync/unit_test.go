package sync

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestETagMatches(t *testing.T) {
	const tag = `"t3-m2"`
	for h, want := range map[string]bool{
		``:                   false,
		`"t3-m2"`:            true,
		`W/"t3-m2"`:          true,
		`"t2-m2", "t3-m2"`:   true,
		`*`:                  true,
		`"t3-m1"`:            false,
		`t3-m2`:              false,
		` "a" ,  W/"t3-m2" `: true,
	} {
		assert.Equal(t, want, etagMatches(h, tag), h)
	}
	assert.Equal(t, tag, Versions{Territory: 3, Masters: 2}.ETag())
}

func TestAcceptsGzip(t *testing.T) {
	for h, want := range map[string]bool{
		"":                    false,
		"gzip":                true,
		"GZIP":                true,
		"deflate, gzip;q=1.0": true,
		"br, *":               true,
		"gzip;q=0":            false,
		"gzip; q=0.000":       false,
		"identity":            false,
		"gzip;q=0.5":          true,
	} {
		assert.Equal(t, want, acceptsGzip(h), h)
	}
}

func TestSnapshotKeys(t *testing.T) {
	v := Versions{Territory: 12, Masters: 3}
	id := [16]byte{1}
	assert.Equal(t, "scope:01000000-0000-0000-0000-000000000000:v12:m3", snapshotKey(id, v))
	assert.Equal(t, "scope:01000000-0000-0000-0000-000000000000:keys", indexKey(id))
}
