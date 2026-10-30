package farmers

import (
	"context"
	"fmt"
	"regexp"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

// Farmer photos. The phone asks for a presigned PUT, uploads the image and
// then saves the returned key on the farmer: the FA app through EnrolFarmer
// or UpdateFarmer (photo_key), the farmer app through PATCH /v1/farmer/me.
// Keys are farmers/{farmer_id}/photo-{uuid}.{ext}; a farmer only ever accepts
// a key under their own prefix, so nobody can point a farmer at another
// farmer's (or a visit's) object.

const (
	// MaxFarmerPhotoBytes is the largest farmer photo the phone may upload.
	MaxFarmerPhotoBytes = 5 << 20
	photoUploadTTL      = 15 * time.Minute
	photoViewTTL        = 15 * time.Minute

	// Upload URL rate limits: an FA at an enrolment camp, a farmer retrying.
	faPhotoLimit     = 120
	farmerPhotoLimit = 20
	photoLimitWindow = time.Hour
)

// photoExts maps the accepted content types to the key's file extension.
var photoExts = map[string]string{"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}

var photoKeyRe = regexp.MustCompile(`^farmers/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/photo-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$`)

// PhotoUploadTarget is where and how the phone uploads a farmer photo.
type PhotoUploadTarget struct {
	StorageKey string
	URL        string
	Method     string
	Headers    map[string]string
	ExpiresAt  time.Time
}

// newPhotoKey is a fresh key under the farmer's prefix.
func newPhotoKey(farmerID uuid.UUID, contentType string) string {
	return fmt.Sprintf("farmers/%s/photo-%s.%s", farmerID, ids.New(), photoExts[contentType])
}

// checkPhotoKey accepts a nil key, or a well-formed photo key under one of
// the given farmer IDs (an FA's command may name the farmer by the ID the
// phone minted or by the canonical one after a merge).
func checkPhotoKey(key *string, farmerIDs ...uuid.UUID) error {
	if key == nil {
		return nil
	}
	m := photoKeyRe.FindStringSubmatch(*key)
	if m != nil {
		for _, id := range farmerIDs {
			if id != uuid.Nil && m[1] == id.String() {
				return nil
			}
		}
	}
	return apperr.Validation("photo_key", "must be a key from this farmer's photo upload URL")
}

func checkPhotoUpload(contentType string, size int32) error {
	if _, ok := photoExts[contentType]; !ok {
		return apperr.Validation("content_type", "must be image/jpeg, image/png or image/webp")
	}
	if size <= 0 || size > MaxFarmerPhotoBytes {
		return apperr.Validation("bytes", "must be between 1 byte and 5 MB")
	}
	return nil
}

// PresignFarmerPhotoForFA returns an upload URL for a farmer's photo taken on
// the FA's phone. The farmer may not exist on the server yet (the ID is
// minted offline before EnrolFarmer syncs); if it does, or it is a merge
// alias, the FA must be allowed to act on that farmer.
func (s *Service) PresignFarmerPhotoForFA(ctx context.Context, farmerID uuid.UUID, contentType string, size int32) (PhotoUploadTarget, error) {
	p, err := auth.RequireKind(ctx, auth.KindFA)
	if err != nil {
		return PhotoUploadTarget{}, err
	}
	if err := checkPhotoUpload(contentType, size); err != nil {
		return PhotoUploadTarget{}, err
	}
	if err := s.allowPhotoUpload(ctx, "farmers:photo_upload:fa:"+p.ID.String(), faPhotoLimit); err != nil {
		return PhotoUploadTarget{}, err
	}
	id, err := resolveAlias(ctx, s.q, farmerID)
	if err != nil {
		return PhotoUploadTarget{}, err
	}
	f, err := s.q.GetFarmer(ctx, id)
	switch {
	case db.IsNoRows(err): // enrolled offline, not synced yet
	case err != nil:
		return PhotoUploadTarget{}, apperr.Internalf("farmers: photo farmer: %w", err)
	default:
		if err := faMayActOn(p.ID, f); err != nil {
			return PhotoUploadTarget{}, err
		}
	}
	return s.presignPhoto(ctx, farmerID, contentType)
}

// PresignMyPhoto returns an upload URL for the signed-in farmer's own photo.
func (s *Service) PresignMyPhoto(ctx context.Context, contentType string, size int32) (PhotoUploadTarget, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return PhotoUploadTarget{}, err
	}
	if err := checkPhotoUpload(contentType, size); err != nil {
		return PhotoUploadTarget{}, err
	}
	f, err := s.q.GetFarmer(ctx, p.ID)
	if err != nil {
		return PhotoUploadTarget{}, notFound(err, "farmer")
	}
	if err := ownWriteAllowed(f.Status); err != nil {
		return PhotoUploadTarget{}, err
	}
	if err := s.allowPhotoUpload(ctx, "farmers:photo_upload:farmer:"+p.ID.String(), farmerPhotoLimit); err != nil {
		return PhotoUploadTarget{}, err
	}
	return s.presignPhoto(ctx, p.ID, contentType)
}

func (s *Service) allowPhotoUpload(ctx context.Context, key string, limit int) error {
	ok, err := s.deps.Limiter.Allow(ctx, key, limit, photoLimitWindow)
	if err != nil {
		return apperr.Unavailable("rate limiter unavailable")
	}
	if !ok {
		return apperr.RateLimited(photoLimitWindow / time.Duration(limit))
	}
	return nil
}

func (s *Service) presignPhoto(ctx context.Context, farmerID uuid.UUID, contentType string) (PhotoUploadTarget, error) {
	key := newPhotoKey(farmerID, contentType)
	pre, err := s.deps.Storage.PresignPut(ctx, key, contentType, photoUploadTTL)
	if err != nil {
		return PhotoUploadTarget{}, apperr.Internalf("farmers: presign photo: %w", err)
	}
	return PhotoUploadTarget{
		StorageKey: key, URL: pre.URL, Method: pre.Method, Headers: pre.Headers, ExpiresAt: pre.ExpiresAt.UTC(),
	}, nil
}

// photoURL is a presigned GET for a farmer's photo, nil without one. Best
// effort: a storage failure leaves the photo out rather than failing the page.
func (s *Service) photoURL(ctx context.Context, key *string) *string {
	if key == nil || *key == "" || s.deps.Storage == nil {
		return nil
	}
	u, err := s.deps.Storage.PresignGet(ctx, *key, photoViewTTL)
	if err != nil {
		logx.From(ctx).Warn("farmers: presign photo get", "err", err)
		return nil
	}
	return &u
}
