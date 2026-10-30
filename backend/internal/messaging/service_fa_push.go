package messaging

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/push"
)

// faAlertPushMaxAttempts bounds retries of an FA alert push; the alert itself
// is in the FA's snapshot anyway.
const faAlertPushMaxAttempts = 5

// PushFAAlert sends a new FA alert to every active device of the FA. FAs are
// staff, so quiet hours do not apply. An alert that is gone, closed or
// already acknowledged, or an FA with no push token, is not an error. If no
// device accepted the push the error is returned so River retries; once any
// device got it, it is not retried (no duplicate notifications).
func (s *Service) PushFAAlert(ctx context.Context, alertID uuid.UUID) error {
	a, err := s.q.GetFAAlert(ctx, alertID)
	if db.IsNoRows(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("messaging: get fa alert: %w", err)
	}
	if a.Status != "open" {
		return nil
	}
	tokens, err := s.ports.Identity.PushTokens(ctx, "fa", []uuid.UUID{a.FaID})
	if err != nil {
		return fmt.Errorf("messaging: fa push tokens: %w", err)
	}
	list := tokens[a.FaID]
	if len(list) == 0 {
		logx.From(ctx).InfoContext(ctx, "messaging: fa has no push token; alert waits for sync", "fa_id", a.FaID, "alert_id", a.ID)
		return nil
	}
	// In the FA's first language; English when the alert has no Telugu text.
	title, body := a.Title, ""
	if a.Body != nil {
		body = *a.Body
	}
	if a.TitleTe != nil && *a.TitleTe != "" {
		fa, err := s.fieldAssistant(ctx, a.FaID)
		if err != nil && !apperr.Is(err, apperr.KindNotFound) {
			return err
		}
		if err == nil && faLanguage(fa) == "te" {
			title, body = *a.TitleTe, ""
			if a.BodyTe != nil {
				body = *a.BodyTe
			}
		}
	}
	data := map[string]string{"type": "fa_alert", "alert_id": a.ID.String(), "kind": a.Kind}
	if a.FarmerID.Valid {
		data["farmer_id"] = a.FarmerID.UUID.String()
	}
	var errs []string
	sent := 0
	for _, tok := range list {
		if _, err := s.deps.Push.Send(ctx, push.Message{Token: tok, Title: title, Body: body, Data: data}); err != nil {
			errs = append(errs, err.Error())
			continue
		}
		sent++
	}
	if sent == 0 {
		return fmt.Errorf("messaging: fa alert push failed on all %d devices: %s", len(list), strings.Join(errs, "; "))
	}
	if len(errs) > 0 {
		logx.From(ctx).WarnContext(ctx, "messaging: fa alert push failed on some devices", "alert_id", a.ID, "errors", errs)
	}
	return nil
}
