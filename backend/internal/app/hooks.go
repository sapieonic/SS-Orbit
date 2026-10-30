package app

import (
	"fmt"
	"reflect"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Optional module hooks. A module implements any subset; wiring discovers
// them by interface assertion, so adding a hook needs no change to wire.go.
type (
	mounter             interface{ Mount(r chi.Router) }
	workerRegistrar     interface{ RegisterWorkers(w *river.Workers) }
	commandRegistrar    interface{ RegisterCommands(reg *commands.Registry) }
	subscriberRegistrar interface{ RegisterSubscribers(bus *events.Bus) }
	snapshotRegistrar   interface{ RegisterSnapshot(reg *territory.Registry) }
)

// hookTypes maps each hook method name to the interface it must satisfy.
var hookTypes = map[string]reflect.Type{
	"Mount":               reflect.TypeFor[mounter](),
	"RegisterWorkers":     reflect.TypeFor[workerRegistrar](),
	"RegisterCommands":    reflect.TypeFor[commandRegistrar](),
	"RegisterSubscribers": reflect.TypeFor[subscriberRegistrar](),
	"RegisterSnapshot":    reflect.TypeFor[snapshotRegistrar](),
}

type namedModule struct {
	name string
	mod  any
}

// checkHooks panics if a module has a Mount/Register* method whose signature
// does not match the hook interface, which would otherwise be silently skipped.
func checkHooks(mods []namedModule) {
	for _, nm := range mods {
		t := reflect.TypeOf(nm.mod)
		for i := range t.NumMethod() {
			name := t.Method(i).Name
			if name != "Mount" && !strings.HasPrefix(name, "Register") {
				continue
			}
			want, known := hookTypes[name]
			if !known {
				panic(fmt.Sprintf("app: module %s has unknown hook method %s (known: Mount, RegisterWorkers, RegisterCommands, RegisterSubscribers, RegisterSnapshot)", nm.name, name))
			}
			if !t.Implements(want) {
				panic(fmt.Sprintf("app: module %s method %s has the wrong signature; want %s", nm.name, name, want.Method(0).Type))
			}
		}
	}
}

// Mount mounts every module's routes.
func (m *Modules) Mount(r chi.Router) {
	for _, nm := range m.all() {
		if h, ok := nm.mod.(mounter); ok {
			h.Mount(r)
		}
	}
}

// RegisterWorkers adds every module's River workers.
func (m *Modules) RegisterWorkers(w *river.Workers) {
	for _, nm := range m.all() {
		if h, ok := nm.mod.(workerRegistrar); ok {
			h.RegisterWorkers(w)
		}
	}
}

// RegisterCommands registers every module's sync command handlers.
func (m *Modules) RegisterCommands(reg *commands.Registry) {
	for _, nm := range m.all() {
		if h, ok := nm.mod.(commandRegistrar); ok {
			h.RegisterCommands(reg)
		}
	}
}

// RegisterSubscribers subscribes every module's event handlers.
func (m *Modules) RegisterSubscribers(bus *events.Bus) {
	for _, nm := range m.all() {
		if h, ok := nm.mod.(subscriberRegistrar); ok {
			h.RegisterSubscribers(bus)
		}
	}
}

// RegisterSnapshot registers every module's territory snapshot providers.
func (m *Modules) RegisterSnapshot(reg *territory.Registry) {
	for _, nm := range m.all() {
		if h, ok := nm.mod.(snapshotRegistrar); ok {
			h.RegisterSnapshot(reg)
		}
	}
}

// Hooks describes which hooks each module implements (logged at startup).
func (m *Modules) Hooks() map[string][]string {
	out := map[string][]string{}
	for _, nm := range m.all() {
		var hs []string
		for name, typ := range hookTypes {
			if reflect.TypeOf(nm.mod).Implements(typ) {
				hs = append(hs, name)
			}
		}
		out[nm.name] = hs
	}
	return out
}
