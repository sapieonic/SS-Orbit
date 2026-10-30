package events

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestBusSubscribe(t *testing.T) {
	b := NewBus()
	Handle(b, "messaging.welcome_sms", func(context.Context, FarmerRegistered) error { return nil })
	Handle(b, "messaging.ho_alert", func(context.Context, FarmerRegistered) error { return nil })
	assert.Equal(t, []string{"messaging.ho_alert", "messaging.welcome_sms"}, b.Subscribers(NameFarmerRegistered))
	assert.Panics(t, func() {
		Handle(b, "messaging.welcome_sms", func(context.Context, FarmerRegistered) error { return nil })
	}, "duplicate subscriber")
	assert.Panics(t, func() { b.Subscribe("farmer.typo", "x", func(context.Context, json.RawMessage) error { return nil }) })

	fn, ok := b.handler(NameFarmerRegistered, "messaging.ho_alert")
	assert.True(t, ok)
	assert.Error(t, fn(context.Background(), []byte(`not json`)), "typed handlers reject undecodable payloads")
}

func TestCatalogNamesMatchTypes(t *testing.T) {
	for _, e := range []Event{FarmerRegistered{}, FarmerProfileCompleted{}, FarmersReassigned{}, VisitLogged{},
		CallbackRequested{}, MastersPublished{}, DeviceRevoked{}, SystemPing{}} {
		assert.True(t, Known(e.EventName()), e.EventName())
	}
}
