package sync

import (
	"bytes"
	"compress/gzip"
	"context"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
)

func (h *handler) SubmitSyncCommands(ctx context.Context, req SubmitSyncCommandsRequestObject) (SubmitSyncCommandsResponseObject, error) {
	in := req.Body.Commands
	cmds := make([]commands.Command, len(in))
	for i, c := range in {
		cmds[i] = commands.Command{ID: c.Id, Type: c.Type, Payload: c.Payload, ClientCreatedAt: c.ClientCreatedAt}
	}
	res, err := h.svc.SubmitBatch(ctx, cmds)
	if err != nil {
		return nil, err
	}
	results := make([]CommandResult, len(res.Outcomes))
	for i, o := range res.Outcomes {
		results[i] = toResultDTO(o.CommandID, o.Result)
	}
	return SubmitSyncCommands200JSONResponse{
		Results:          results,
		RetryFrom:        res.RetryFrom,
		TerritoryVersion: res.Versions.Territory,
		MastersVersion:   res.Versions.Masters,
	}, nil
}

func (h *handler) GetSyncSnapshot(ctx context.Context, req GetSyncSnapshotRequestObject) (GetSyncSnapshotResponseObject, error) {
	snap, err := h.svc.Snapshot(ctx, deref(req.Params.IfNoneMatch))
	if err != nil {
		return nil, err
	}
	etag := snap.Versions.ETag()
	if snap.NotModified {
		return GetSyncSnapshot304Response{Headers: GetSyncSnapshot304ResponseHeaders{ETag: &etag}}, nil
	}
	resp := snapshotResponse{etag: etag, body: snap.Gzip, gzipped: true}
	if !acceptsGzip(deref(req.Params.AcceptEncoding)) {
		// The phone always accepts gzip; this is for curl and browsers.
		zr, err := gzip.NewReader(bytes.NewReader(snap.Gzip))
		if err != nil {
			return nil, apperr.Internalf("sync: gunzip snapshot: %w", err)
		}
		if resp.body, err = io.ReadAll(zr); err != nil {
			return nil, apperr.Internalf("sync: gunzip snapshot: %w", err)
		}
		resp.gzipped = false
	}
	return resp, nil
}

func (h *handler) GetSyncStatus(ctx context.Context, _ GetSyncStatusRequestObject) (GetSyncStatusResponseObject, error) {
	v, err := h.svc.Status(ctx)
	if err != nil {
		return nil, err
	}
	return GetSyncStatus200JSONResponse{TerritoryVersion: v.Territory, MastersVersion: v.Masters, Etag: v.ETag()}, nil
}

// snapshotResponse writes the already-encoded snapshot. The generated
// GetSyncSnapshot200JSONResponse would re-encode a Go value; the snapshot is
// built (and cached) as gzipped bytes, so it is written as is. The bytes are
// the spec's Snapshot schema.
type snapshotResponse struct {
	etag    string
	body    []byte
	gzipped bool
}

func (r snapshotResponse) VisitGetSyncSnapshotResponse(w http.ResponseWriter) error {
	hd := w.Header()
	hd.Set("Content-Type", "application/json")
	hd.Set("ETag", r.etag)
	hd.Set("Cache-Control", "private, no-cache")
	hd.Set("Vary", "Accept-Encoding")
	if r.gzipped {
		hd.Set("Content-Encoding", "gzip")
	}
	hd.Set("Content-Length", strconv.Itoa(len(r.body)))
	w.WriteHeader(http.StatusOK)
	_, err := w.Write(r.body)
	return err
}

// acceptsGzip reports whether an Accept-Encoding header allows gzip (by name
// or "*", without q=0).
func acceptsGzip(header string) bool {
	for part := range strings.SplitSeq(header, ",") {
		name, params, _ := strings.Cut(part, ";")
		name = strings.ToLower(strings.TrimSpace(name))
		if name != "gzip" && name != "*" {
			continue
		}
		if q, ok := strings.CutPrefix(strings.TrimSpace(params), "q="); ok {
			if f, err := strconv.ParseFloat(q, 64); err == nil && f == 0 {
				continue
			}
		}
		return true
	}
	return false
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
