package paging

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
)

func TestCursorRoundTrip(t *testing.T) {
	c := Cursor{At: time.Date(2026, 3, 1, 10, 0, 0, 123456789, time.UTC), ID: uuid.New()}
	s := c.Encode()
	got, err := Decode(&s)
	require.NoError(t, err)
	assert.Equal(t, c, got)

	z, err := Decode(nil)
	require.NoError(t, err)
	assert.True(t, z.IsZero())
	assert.Nil(t, z.AtPtr())
	assert.False(t, z.IDNull().Valid)

	bad := "!!!"
	_, err = Decode(&bad)
	assert.True(t, apperr.Is(err, apperr.KindValidation))
}

func TestBuildAndLimit(t *testing.T) {
	ten := 10
	big := 1000
	assert.Equal(t, 50, Limit(nil, 50, 200))
	assert.Equal(t, 10, Limit(&ten, 50, 200))
	assert.Equal(t, 200, Limit(&big, 50, 200))

	base := time.Now().UTC()
	rows := []Cursor{{At: base, ID: uuid.New()}, {At: base.Add(-time.Second), ID: uuid.New()}, {At: base.Add(-2 * time.Second), ID: uuid.New()}}
	p := Build(rows, 2, func(c Cursor) Cursor { return c })
	assert.Len(t, p.Items, 2)
	require.NotNil(t, p.NextCursor)
	next, _ := Decode(p.NextCursor)
	assert.Equal(t, rows[1].ID, next.ID)

	p = Build(rows, 3, func(c Cursor) Cursor { return c })
	assert.Nil(t, p.NextCursor)
	p = Build[Cursor](nil, 3, func(c Cursor) Cursor { return c })
	assert.NotNil(t, p.Items)
}
