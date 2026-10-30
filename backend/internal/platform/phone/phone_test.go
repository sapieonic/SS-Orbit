package phone

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNormalize(t *testing.T) {
	valid := map[string]string{
		"9848012345":         "+919848012345",
		"98480 12345":        "+919848012345",
		"098480-12345":       "+919848012345",
		"+91 98480 12345":    "+919848012345",
		"+91-9848012345":     "+919848012345",
		"919848012345":       "+919848012345",
		"0091 9848012345":    "+919848012345",
		" (+91) 6000000000 ": "+916000000000",
	}
	for in, want := range valid {
		got, err := Normalize(in)
		require.NoError(t, err, in)
		assert.Equal(t, want, got, in)
	}

	invalid := []string{
		"", "12345", "5848012345", "+1 4155552671", "98480123456", "9848o12345",
		"+91 5848012345", "91+9848012345", "040 2345 6789",
	}
	for _, in := range invalid {
		_, err := Normalize(in)
		assert.ErrorIs(t, err, ErrInvalid, in)
	}
}

func TestMask(t *testing.T) {
	assert.Equal(t, "+91******2345", Mask("+919848012345"))
	assert.Equal(t, "****", Mask("123"))
}
