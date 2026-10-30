// Package sms sends SMS through a provider. Only the dev "log" provider exists
// today: it logs the message and never sends (config refuses it in prod).
// Indian A2P SMS needs a DLT template ID per message; callers pass it in
// Message.TemplateID.
package sms

import (
	"context"
	"log/slog"

	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
)

// Message is one SMS.
type Message struct {
	To         string // E.164
	Body       string // final text (Telugu allowed; providers send as Unicode)
	TemplateID string // DLT template ID
}

// Sender sends SMS. Send returns the provider's message reference.
type Sender interface {
	Send(ctx context.Context, m Message) (providerRef string, err error)
}

// Log is a Sender that only logs (dev, tests).
type Log struct {
	log      *slog.Logger
	showBody bool
}

// NewLog returns a logging Sender that redacts codes and link tokens from the
// body (logx.Redact). Use it everywhere except a developer's machine.
func NewLog(log *slog.Logger) *Log { return &Log{log: log} }

// NewDevLog returns a logging Sender that prints bodies in clear, so a
// developer can read the OTP. Only for ORBIT_ENV=dev.
func NewDevLog(log *slog.Logger) *Log { return &Log{log: log, showBody: true} }

// Send logs the message with the phone number masked.
func (l *Log) Send(ctx context.Context, m Message) (string, error) {
	ref := "log-" + ids.New().String()
	body := m.Body
	if !l.showBody {
		body = logx.Redact(body)
	}
	l.log.InfoContext(ctx, "sms (not sent)", "to", phone.Mask(m.To), "template", m.TemplateID, "body", body, "ref", ref)
	return ref, nil
}
