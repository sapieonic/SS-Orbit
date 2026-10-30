package messaging

import (
	"context"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

// handler implements the generated StrictServerInterface. It only maps
// between DTOs and the service (handler_*.go by surface); service errors are
// returned unchanged and written by httpx.ResponseErrorHandler.
type handler struct {
	svc *Service
}

var _ StrictServerInterface = (*handler)(nil)

// SmsDeliveryReport is a STUB: it accepts and logs provider callbacks. When a
// provider is integrated it must verify the provider signature and update
// deliveries.status/delivered_at by provider_ref.
func (h *handler) SmsDeliveryReport(ctx context.Context, req SmsDeliveryReportRequestObject) (SmsDeliveryReportResponseObject, error) {
	logx.From(ctx).InfoContext(ctx, "messaging: sms delivery report received (stub, ignored)", "provider", req.Provider)
	return SmsDeliveryReport204Response{}, nil
}

func uuids(p *[]uuid.UUID) []uuid.UUID {
	if p == nil {
		return []uuid.UUID{}
	}
	return *p
}

func strs(p *[]string) []string {
	if p == nil {
		return []string{}
	}
	return *p
}

func strPtr[T ~string](p *T) *string {
	if p == nil {
		return nil
	}
	s := string(*p)
	return &s
}
