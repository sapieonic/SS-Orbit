// Package push sends mobile push notifications. Only the dev "log" provider
// exists today: it logs and never sends (config refuses it in prod).
package push

import (
	"context"
	"log/slog"

	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

// Message is one push notification to one device token.
type Message struct {
	Token string            // provider device token
	Title string            // shown in the notification tray
	Body  string            // shown in the notification tray
	Data  map[string]string // deep-link data for the app
}

// Sender sends pushes. Send returns the provider's message reference.
type Sender interface {
	Send(ctx context.Context, m Message) (providerRef string, err error)
}

// Log is a Sender that only logs (dev, tests).
type Log struct {
	log      *slog.Logger
	showBody bool
}

// NewLog returns a logging Sender that redacts codes and link tokens from the
// title, body and data (logx.Redact). The device token is never logged.
func NewLog(log *slog.Logger) *Log { return &Log{log: log} }

// NewDevLog returns a logging Sender that prints the text in clear. Only for
// ORBIT_ENV=dev.
func NewDevLog(log *slog.Logger) *Log { return &Log{log: log, showBody: true} }

// Send logs the notification.
func (l *Log) Send(ctx context.Context, m Message) (string, error) {
	ref := "log-" + ids.New().String()
	title, body, data := m.Title, m.Body, m.Data
	if !l.showBody {
		title, body = logx.Redact(title), logx.Redact(body)
		data = make(map[string]string, len(m.Data))
		for k, v := range m.Data {
			data[k] = logx.Redact(v)
		}
	}
	l.log.InfoContext(ctx, "push (not sent)", "title", title, "body", body, "data", data, "ref", ref)
	return ref, nil
}
