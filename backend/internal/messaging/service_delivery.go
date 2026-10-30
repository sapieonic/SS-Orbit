package messaging

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/push"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Delivery statuses.
const (
	deliveryQueued  = "queued"
	deliverySent    = "sent"
	deliveryFailed  = "failed"
	deliverySkipped = "skipped"
)

// skipError means the delivery cannot be made at all (no phone, no push
// token); it is marked skipped and not retried.
type skipError struct{ reason string }

func (e skipError) Error() string { return e.reason }

// Skip reasons stored in deliveries.error.
const (
	skipWhatsAppNotConfigured = "whatsapp_not_configured"
	skipFarmerNotFound        = "farmer not found"
	skipFarmerInactive        = "farmer_inactive"
	skipNoProgrammeConsent    = "no_programme_consent"
)

// SendDelivery sends one queued delivery. attempt and maxAttempts come from
// the River job. A failed send is recorded and returned so River retries it
// with backoff; on the last attempt the delivery is marked failed instead.
// Delivery rows are themselves the send log, so they are not audited.
//
// Rules are checked at send time, not only at fan-out, because a delivery can
// wait (quiet hours, retry backoff):
//   - inside quiet hours (21:00-07:00 IST) the job is snoozed to 07:00 IST
//     instead of sending (a snooze does not use up an attempt);
//   - the farmer is read again: a deactivated farmer, or for a promotional
//     advisory one without current programme consent, is skipped.
//
// WhatsApp has no provider yet: those deliveries are skipped
// (whatsapp_not_configured) and nothing is sent.
func (s *Service) SendDelivery(ctx context.Context, id uuid.UUID, attempt, maxAttempts int) error {
	d, err := s.q.GetDelivery(ctx, id)
	if db.IsNoRows(err) {
		logx.From(ctx).WarnContext(ctx, "messaging: delivery not found", "delivery_id", id)
		return nil
	}
	if err != nil {
		return fmt.Errorf("messaging: get delivery: %w", err)
	}
	if d.Status != deliveryQueued {
		return nil // already sent, failed or skipped
	}
	ref, sendErr := s.checkAndSend(ctx, d)
	var snooze *river.JobSnoozeError
	if errors.As(sendErr, &snooze) {
		return sendErr
	}
	arg := store.UpdateDeliveryResultParams{ID: id, Attempts: int32(attempt)}
	var skip skipError
	switch {
	case sendErr == nil:
		now := s.now()
		arg.Status, arg.ProviderRef, arg.SentAt = deliverySent, &ref, &now
	case errors.As(sendErr, &skip):
		arg.Status, arg.Error = deliverySkipped, ptr(skip.reason)
	case attempt >= maxAttempts:
		arg.Status, arg.Error = deliveryFailed, ptr(sendErr.Error())
	default:
		arg.Status, arg.Error = deliveryQueued, ptr(sendErr.Error())
	}
	if err := s.q.UpdateDeliveryResult(ctx, arg); err != nil {
		return fmt.Errorf("messaging: update delivery: %w", err)
	}
	if arg.Status == deliveryQueued {
		return sendErr // retry
	}
	return nil
}

// checkAndSend applies the send-time rules, then sends. It returns a
// skipError, a river snooze error, a send error, or the provider reference.
func (s *Service) checkAndSend(ctx context.Context, d store.Delivery) (string, error) {
	switch d.Channel {
	case ChannelWhatsApp:
		return "", skipError{skipWhatsAppNotConfigured}
	case ChannelSMS, ChannelPush:
	default:
		return "", skipError{"unknown channel " + d.Channel}
	}
	now := s.now()
	if at := sendAfterQuietHours(now); at.After(now) {
		return "", river.JobSnooze(at.Sub(now))
	}
	f, err := s.farmerSummary(ctx, d.FarmerID)
	if apperr.Is(err, apperr.KindNotFound) {
		return "", skipError{skipFarmerNotFound}
	}
	if err != nil {
		return "", err
	}
	class, err := s.q.GetDeliveryClass(ctx, d.ID)
	if err != nil {
		return "", fmt.Errorf("messaging: delivery class: %w", err)
	}
	if reason := sendBlocked(class, f); reason != "" {
		return "", skipError{reason}
	}
	if d.Channel == ChannelPush {
		return s.sendPush(ctx, d)
	}
	body, err := s.expandLink(d)
	if err != nil {
		return "", err
	}
	tpl := ""
	if d.TemplateID != nil {
		tpl = *d.TemplateID
	}
	return s.deps.SMS.Send(ctx, sms.Message{To: f.Phone, Body: body, TemplateID: tpl})
}

// sendBlocked is the send-time farmer check: "" when the message may go, or
// the skip reason. Service messages (welcome, visit advice) go to any farmer
// who is not inactive, including a self sign-up still completing the
// profile; promotional ones need an active farmer with programme consent.
func sendBlocked(class string, f xmod.FarmerSummary) string {
	if f.Status == "inactive" {
		return skipFarmerInactive
	}
	if class == ClassPromotional {
		if f.Status != "active" {
			return skipFarmerInactive
		}
		if !f.ProgrammeConsent {
			return skipNoProgrammeConsent
		}
	}
	return ""
}

func (s *Service) sendPush(ctx context.Context, d store.Delivery) (string, error) {
	tokens, err := s.ports.Identity.PushTokens(ctx, "farmer", []uuid.UUID{d.FarmerID})
	if err != nil {
		return "", fmt.Errorf("messaging: push tokens: %w", err)
	}
	list := tokens[d.FarmerID]
	if len(list) == 0 {
		return "", skipError{"no push token"}
	}
	title := ""
	if d.Title != nil {
		title = *d.Title
	}
	data := map[string]string{"type": "notice"}
	if d.NoticeID.Valid {
		data["notice_id"] = d.NoticeID.UUID.String()
	}
	var refs []string
	var lastErr error
	for _, tok := range list {
		ref, err := s.deps.Push.Send(ctx, push.Message{Token: tok, Title: title, Body: d.Body, Data: data})
		if err != nil {
			lastErr = err
			continue
		}
		refs = append(refs, ref)
	}
	if len(refs) == 0 {
		return "", lastErr
	}
	return strings.Join(refs, ","), nil
}

// expandLink replaces linkMarker with a signed link to the notice web page.
// Links are minted at send time so a delivery held over quiet hours still
// gets a full-lifetime link.
func (s *Service) expandLink(d store.Delivery) (string, error) {
	if !strings.Contains(d.Body, linkMarker) {
		return d.Body, nil
	}
	if !d.NoticeID.Valid {
		return strings.TrimSpace(strings.ReplaceAll(d.Body, linkMarker, "")), nil
	}
	link, err := s.noticeLink(d.FarmerID, d.NoticeID.UUID)
	if err != nil {
		return "", err
	}
	return strings.ReplaceAll(d.Body, linkMarker, link), nil
}

// noticeLink is the farmer web page URL for a notice, with a signed token
// (kind web, purpose "notice:<id>").
func (s *Service) noticeLink(farmerID, noticeID uuid.UUID) (string, error) {
	tok, _, err := s.deps.Tokens.IssueLink(farmerID, noticePurpose(noticeID), s.deps.Config.WebLinkTTL)
	if err != nil {
		return "", fmt.Errorf("messaging: link token: %w", err)
	}
	// FARMER_WEB_BASE_URL (the farmer-web app; defaults to PUBLIC_BASE_URL).
	return s.deps.Config.FarmerWebBase() + "/web/notices/" + noticeID.String() + "?t=" + tok, nil
}

func noticePurpose(noticeID uuid.UUID) string { return "notice:" + noticeID.String() }
