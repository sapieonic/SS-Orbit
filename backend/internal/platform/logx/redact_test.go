package logx

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRedact(t *testing.T) {
	in := "482913 మీ లాగిన్ కోడ్. See https://orbit.example.in/w/advice?t=eyJhbGciOi.eyJzdWIi.sig&x=1 now"
	out := Redact(in)
	assert.NotContains(t, out, "482913")
	assert.NotContains(t, out, "eyJhbGciOi")
	assert.Contains(t, out, "?t=[redacted]&x=1")
	assert.Contains(t, out, "లాగిన్", "the rest of the text stays readable")
	assert.Equal(t, "valid for 5 minutes", Redact("valid for 5 minutes"), "short numbers stay")
}
