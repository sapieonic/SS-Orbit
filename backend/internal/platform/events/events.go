// Package events implements domain events over River.
//
// Publish inserts a "domain_event" job in the writer's transaction, so the
// event exists if and only if the write committed. In the worker, the
// dispatcher fans each event out to one "domain_event_delivery" job per
// subscriber, so subscribers are retried independently. Delivery is at least
// once: subscribers must be idempotent.
//
// Publisher side (any module, in a service, inside db.WithTx):
//
//	err := deps.Events.Publish(ctx, tx, events.VisitLogged{VisitID: id, ...})
//
// Subscriber side (module's RegisterSubscribers):
//
//	events.Handle(bus, "messaging.visit_advice", func(ctx context.Context, e events.VisitLogged) error {...})
package events

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/jobs"
	"github.com/sapionic/orbit/backend/internal/platform/reqctx"
)

// Event is a catalog payload struct.
type Event interface {
	EventName() string
}

// Publisher writes events. It is platform.Deps.Events.
type Publisher struct {
	jobs  *jobs.Client
	clock clock.Clock
}

// NewPublisher builds a Publisher on top of a jobs client.
func NewPublisher(j *jobs.Client, clk clock.Clock) *Publisher {
	if clk == nil {
		clk = clock.System()
	}
	return &Publisher{jobs: j, clock: clk}
}

// Publish enqueues e inside tx. It fails for event names not in the catalog.
func (p *Publisher) Publish(ctx context.Context, tx pgx.Tx, e Event) error {
	name := e.EventName()
	if !Known(name) {
		return fmt.Errorf("events: unknown event %q (add it to catalog.go)", name)
	}
	payload, err := json.Marshal(e)
	if err != nil {
		return fmt.Errorf("events: marshal %s: %w", name, err)
	}
	return p.jobs.Insert(ctx, tx, eventArgs{
		EventID:    ids.New(),
		Name:       name,
		Payload:    payload,
		OccurredAt: p.clock.Now(),
		RequestID:  reqctx.From(ctx).RequestID,
	}, nil)
}

// HandlerFunc handles one raw event payload.
type HandlerFunc func(ctx context.Context, payload json.RawMessage) error

type subscription struct {
	event      string
	subscriber string
	fn         HandlerFunc
}

// Bus holds subscriptions. Modules subscribe in RegisterSubscribers; the
// worker's dispatcher reads them.
type Bus struct {
	mu   sync.RWMutex
	subs map[string]map[string]HandlerFunc // event -> subscriber -> fn
}

// NewBus returns an empty bus.
func NewBus() *Bus { return &Bus{subs: map[string]map[string]HandlerFunc{}} }

// Subscribe registers fn for event under a stable subscriber name
// ("<module>.<purpose>", e.g. "messaging.new_farmer_alerts"). The name keys
// delivery jobs, so do not rename it casually. Panics on unknown events or
// duplicate (event, subscriber) pairs.
func (b *Bus) Subscribe(event, subscriber string, fn HandlerFunc) {
	if !Known(event) {
		panic(fmt.Sprintf("events: subscribe to unknown event %q", event))
	}
	if subscriber == "" || fn == nil {
		panic("events: empty subscriber or nil handler")
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.subs[event] == nil {
		b.subs[event] = map[string]HandlerFunc{}
	}
	if _, dup := b.subs[event][subscriber]; dup {
		panic(fmt.Sprintf("events: duplicate subscriber %q for %q", subscriber, event))
	}
	b.subs[event][subscriber] = fn
}

// Handle subscribes a typed handler: the payload is decoded into E.
func Handle[E Event](b *Bus, subscriber string, fn func(ctx context.Context, e E) error) {
	var zero E
	b.Subscribe(zero.EventName(), subscriber, func(ctx context.Context, payload json.RawMessage) error {
		var e E
		if err := json.Unmarshal(payload, &e); err != nil {
			return fmt.Errorf("events: decode %s: %w", zero.EventName(), err)
		}
		return fn(ctx, e)
	})
}

// Subscribers returns the subscriber names for event, sorted.
func (b *Bus) Subscribers(event string) []string {
	b.mu.RLock()
	defer b.mu.RUnlock()
	out := make([]string, 0, len(b.subs[event]))
	for s := range b.subs[event] {
		out = append(out, s)
	}
	sort.Strings(out)
	return out
}

func (b *Bus) handler(event, subscriber string) (HandlerFunc, bool) {
	b.mu.RLock()
	defer b.mu.RUnlock()
	fn, ok := b.subs[event][subscriber]
	return fn, ok
}

// Meta describes the event being handled; available to subscribers via MetaFrom.
type Meta struct {
	EventID    uuid.UUID
	Name       string
	OccurredAt time.Time
	Subscriber string
	Attempt    int
}

type metaKey struct{}

// MetaFrom returns the event metadata inside a subscriber.
func MetaFrom(ctx context.Context) (Meta, bool) {
	m, ok := ctx.Value(metaKey{}).(Meta)
	return m, ok
}

// eventArgs is the River job inserted by Publish.
type eventArgs struct {
	EventID    uuid.UUID       `json:"event_id"`
	Name       string          `json:"name"`
	Payload    json.RawMessage `json:"payload"`
	OccurredAt time.Time       `json:"occurred_at"`
	RequestID  string          `json:"request_id,omitempty"`
}

// KindDomainEvent is the River job kind for published events.
const KindDomainEvent = "domain_event"

// KindDelivery is the River job kind for one subscriber's delivery.
const KindDelivery = "domain_event_delivery"

func (eventArgs) Kind() string { return KindDomainEvent }

// deliveryArgs is one subscriber's copy of an event.
type deliveryArgs struct {
	Event      eventArgs `json:"event"`
	Subscriber string    `json:"subscriber"`
}

func (deliveryArgs) Kind() string { return KindDelivery }
