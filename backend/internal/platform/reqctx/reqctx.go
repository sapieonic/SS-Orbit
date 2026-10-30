// Package reqctx carries per-request metadata (request ID, client IP, user
// agent) on the context. httpx sets it for HTTP requests; the events worker
// restores the publisher's request ID so logs and audit rows can be correlated.
// It has no dependencies so any package (logx, audit) can read it.
package reqctx

import "context"

// Meta is request metadata recorded in logs and audit rows.
type Meta struct {
	RequestID string
	IP        string // client IP without port; empty when unknown
	UserAgent string
}

type key struct{}

// With returns ctx carrying m.
func With(ctx context.Context, m Meta) context.Context {
	return context.WithValue(ctx, key{}, m)
}

// From returns the metadata on ctx, or the zero Meta.
func From(ctx context.Context) Meta {
	m, _ := ctx.Value(key{}).(Meta)
	return m
}
