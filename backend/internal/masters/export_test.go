package masters

import (
	"context"

	"github.com/sapionic/orbit/backend/internal/platform/events"
)

// OnPublishedForTest exposes the masters.published subscriber to external tests.
func OnPublishedForTest(m *Module) func(context.Context, events.MastersPublished) error {
	return m.svc.onPublished
}
