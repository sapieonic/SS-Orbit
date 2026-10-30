// Package logx sets up structured logging with log/slog and carries the
// request-scoped logger on the context. Always log through logx.From(ctx) in
// request and job code so lines carry the request ID.
package logx

import (
	"context"
	"io"
	"log/slog"
	"os"
	"strings"

	"github.com/sapionic/orbit/backend/internal/platform/reqctx"
)

// New builds the process logger. format is "json" or "text"; level is
// debug|info|warn|error (default info).
func New(level, format string) *slog.Logger {
	return NewWriter(os.Stdout, level, format)
}

// NewWriter is New with an explicit output, for tests.
func NewWriter(w io.Writer, level, format string) *slog.Logger {
	opts := &slog.HandlerOptions{Level: parseLevel(level)}
	var h slog.Handler
	if strings.EqualFold(format, "json") {
		h = slog.NewJSONHandler(w, opts)
	} else {
		h = slog.NewTextHandler(w, opts)
	}
	return slog.New(h)
}

// Discard returns a logger that drops everything (tests).
func Discard() *slog.Logger { return slog.New(slog.DiscardHandler) }

func parseLevel(s string) slog.Level {
	switch strings.ToLower(s) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

type key struct{}

// With returns ctx carrying l. httpx stores a logger enriched with the
// request ID; job workers do the same with job metadata.
func With(ctx context.Context, l *slog.Logger) context.Context {
	return context.WithValue(ctx, key{}, l)
}

// From returns the logger on ctx. If none was stored it falls back to
// slog.Default(), adding the request ID from reqctx when present.
func From(ctx context.Context) *slog.Logger {
	if l, ok := ctx.Value(key{}).(*slog.Logger); ok && l != nil {
		return l
	}
	l := slog.Default()
	if id := reqctx.From(ctx).RequestID; id != "" {
		l = l.With("request_id", id)
	}
	return l
}
