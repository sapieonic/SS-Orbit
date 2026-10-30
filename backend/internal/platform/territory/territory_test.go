package territory

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRegistryBuild(t *testing.T) {
	ctx := context.Background()
	r := NewRegistry()
	fa := uuid.New()
	village, farmer := uuid.New(), uuid.New()

	_, err := r.Build(ctx, fa)
	require.ErrorIs(t, err, ErrNoResolver)

	r.SetResolver(func(_ context.Context, id uuid.UUID) (Scope, error) {
		return Scope{VillageIDs: []uuid.UUID{village}, FarmerIDs: []uuid.UUID{farmer}}, nil
	})
	assert.Panics(t, func() { r.SetResolver(func(context.Context, uuid.UUID) (Scope, error) { return Scope{}, nil }) })

	r.Register(SectionFarmers, func(_ context.Context, s Scope) (any, error) {
		assert.Equal(t, fa, s.FAID, "resolver output gets the FA ID filled in")
		return s.FarmerIDs, nil
	})
	r.Register(SectionMasters, func(context.Context, Scope) (any, error) { return map[string]int{"version": 3}, nil })
	assert.Panics(t, func() { r.Register(SectionMasters, func(context.Context, Scope) (any, error) { return nil, nil }) })
	assert.Equal(t, []string{"farmers", "masters"}, r.Sections())

	got, err := r.Build(ctx, fa)
	require.NoError(t, err)
	assert.Equal(t, []uuid.UUID{farmer}, got["farmers"])
	assert.Equal(t, map[string]int{"version": 3}, got["masters"])

	r.Register("broken", func(context.Context, Scope) (any, error) { return nil, errors.New("boom") })
	_, err = r.Build(ctx, fa)
	require.ErrorContains(t, err, "section broken")
}
