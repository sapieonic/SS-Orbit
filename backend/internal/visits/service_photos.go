package visits

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/visits/store"
)

const (
	// MaxPhotoBytes is the largest visit photo the phone may upload.
	MaxPhotoBytes = 10 << 20
	uploadURLTTL  = 15 * time.Minute
	viewURLTTL    = 15 * time.Minute
)

// photoForFA loads a visit photo for the FA who logged the visit.
func (s *Service) photoForFA(ctx context.Context, visitID, photoID uuid.UUID) (auth.Principal, store.VisitDetail, store.VisitPhoto, error) {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return p, store.VisitDetail{}, store.VisitPhoto{}, err
	}
	q := s.read()
	v, err := q.GetVisit(ctx, visitID)
	if db.IsNoRows(err) {
		return p, v, store.VisitPhoto{}, apperr.NotFound("visit")
	}
	if err != nil {
		return p, v, store.VisitPhoto{}, apperr.Internalf("visits: get visit: %w", err)
	}
	if v.FaID != p.ID {
		return p, v, store.VisitPhoto{}, apperr.Forbidden("only the field assistant who logged this visit can upload its photos")
	}
	ph, err := q.GetVisitPhoto(ctx, store.GetVisitPhotoParams{ID: photoID, VisitID: visitID})
	if db.IsNoRows(err) {
		return p, v, ph, apperr.NotFound("photo").WithMessage("photo not found; sync the visit log first")
	}
	if err != nil {
		return p, v, ph, apperr.Internalf("visits: get photo: %w", err)
	}
	return p, v, ph, nil
}

// PresignPhotoUpload returns a presigned PUT for a photo created by LogVisit.
func (s *Service) PresignPhotoUpload(ctx context.Context, visitID, photoID uuid.UUID, contentType string, size int32) (UploadTarget, error) {
	_, _, ph, err := s.photoForFA(ctx, visitID, photoID)
	if err != nil {
		return UploadTarget{}, err
	}
	if contentType != ph.ContentType {
		return UploadTarget{}, apperr.Validation("content_type", "must match the type sent with the visit log ("+ph.ContentType+")")
	}
	if size <= 0 || size > MaxPhotoBytes {
		return UploadTarget{}, apperr.Validation("bytes", "must be between 1 byte and 10 MB")
	}
	if ph.UploadedAt != nil {
		return UploadTarget{}, apperr.Conflict("photo_already_uploaded", map[string]any{"photo_id": photoID}).
			WithMessage("this photo is already uploaded")
	}
	pre, err := s.deps.Storage.PresignPut(ctx, ph.StorageKey, ph.ContentType, uploadURLTTL)
	if err != nil {
		return UploadTarget{}, apperr.Internalf("visits: presign put: %w", err)
	}
	// The declared size is upload metadata, not a business change: no audit.
	if err := s.read().SetPhotoSize(ctx, store.SetPhotoSizeParams{ID: photoID, Bytes: &size}); err != nil {
		return UploadTarget{}, apperr.Internalf("visits: photo size: %w", err)
	}
	return UploadTarget{
		PhotoID: photoID, StorageKey: ph.StorageKey, URL: pre.URL, Method: pre.Method,
		Headers: pre.Headers, ExpiresAt: pre.ExpiresAt.UTC(),
	}, nil
}

// ConfirmPhotoUpload marks a photo uploaded once the object exists. Idempotent.
func (s *Service) ConfirmPhotoUpload(ctx context.Context, visitID, photoID uuid.UUID, sha256 *string) (Photo, error) {
	_, v, ph, err := s.photoForFA(ctx, visitID, photoID)
	if err != nil {
		return Photo{}, err
	}
	if ph.UploadedAt != nil {
		return toPhoto(ph), nil
	}
	ok, err := s.deps.Storage.Exists(ctx, ph.StorageKey)
	if err != nil {
		return Photo{}, apperr.Internalf("visits: storage exists: %w", err)
	}
	if !ok {
		return Photo{}, apperr.Conflict("upload_missing", map[string]any{"photo_id": photoID}).
			WithMessage("the photo has not been uploaded yet")
	}
	now := s.deps.Clock.Now()
	err = db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		ph, err = store.New(tx).MarkPhotoUploaded(ctx, store.MarkPhotoUploadedParams{ID: photoID, UploadedAt: &now, Sha256: sha256})
		if err != nil {
			return err
		}
		_, err = audit.Record(ctx, tx, audit.Entry{
			Action: "visits.photo_uploaded", EntityType: "visit_photo", EntityID: photoID,
			FarmerID: v.FarmerID, PlotID: v.PlotID, SeasonID: v.SeasonID,
			After: map[string]any{"visit_id": visitID, "storage_key": ph.StorageKey, "bytes": ph.Bytes, "sha256": sha256},
		})
		return err
	})
	if err != nil {
		return Photo{}, apperr.Internalf("visits: confirm photo: %w", err)
	}
	return toPhoto(ph), nil
}

func toPhoto(r store.VisitPhoto) Photo {
	return Photo{
		ID: r.ID, VisitID: r.VisitID, ContentType: r.ContentType, Bytes: r.Bytes, UploadedAt: utcPtr(r.UploadedAt),
	}
}
