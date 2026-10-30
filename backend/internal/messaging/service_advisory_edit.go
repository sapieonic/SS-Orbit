package messaging

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
)

// UpdateAdvisory edits a draft, including one Agronomy sent back (reject
// returns it to draft with a review note). The result gets the same checks as
// a new draft: input rules, product mentions and the editor's area scope. The
// editor is recorded so ApproveAdvisory can refuse them (maker-checker).
func (s *Service) UpdateAdvisory(ctx context.Context, id uuid.UUID, in AdvisoryPatch) (NewAdvisory, error) {
	p, err := auth.RequireRole(ctx, advisoryRoles...)
	if err != nil {
		return NewAdvisory{}, err
	}
	if in.RemoveAudio && in.AudioContentType != nil {
		return NewAdvisory{}, apperr.Validation("remove_audio", "cannot remove and replace the voice note at once")
	}
	if in.RemoveImage && in.ImageContentType != nil {
		return NewAdvisory{}, apperr.Validation("remove_image", "cannot remove and replace the image at once")
	}
	var out NewAdvisory
	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		row, err := q.GetAdvisoryForUpdate(ctx, id)
		if err != nil {
			return notFoundOr(err, "advisory")
		}
		before := toAdvisory(row)
		if !visible(p, before) {
			return apperr.NotFound("advisory")
		}
		if row.Status != StatusDraft {
			return wrongStatus(row.Status)
		}

		next := AdvisoryInput{
			Sender: row.Sender, TitleTe: row.TitleTe, BodyTe: row.BodyTe, TitleEn: row.TitleEn, BodyEn: row.BodyEn,
			NamesProduct: row.NamesProduct, Class: &row.Class, Target: before.Target, Channels: row.Channels,
		}
		applyAdvisoryPatch(&next, in)
		class, channels, err := validateAdvisoryInput(&next)
		if err != nil {
			return err
		}
		if err := s.checkProductMentions(ctx, next.NamesProduct, &next.TitleTe, &next.BodyTe, next.TitleEn, next.BodyEn); err != nil {
			return err
		}
		if err := s.scopeTarget(ctx, p, &next.Target); err != nil {
			return err
		}
		target, err := json.Marshal(next.Target)
		if err != nil {
			return apperr.Internalf("messaging: marshal target: %w", err)
		}

		audioKey, imageKey := row.AudioKey, row.ImageKey
		if in.RemoveAudio {
			audioKey = nil
		}
		if in.RemoveImage {
			imageKey = nil
		}
		if in.AudioContentType != nil {
			ext, ok := audioExt[*in.AudioContentType]
			if !ok {
				return apperr.Validation("audio_content_type", "unsupported audio type")
			}
			audioKey = ptr("messaging/advisories/" + id.String() + "/audio" + ext)
			if out.AudioUpload, err = s.presignPut(ctx, *audioKey, *in.AudioContentType); err != nil {
				return err
			}
		}
		if in.ImageContentType != nil {
			ext, ok := imageExt[*in.ImageContentType]
			if !ok {
				return apperr.Validation("image_content_type", "unsupported image type")
			}
			imageKey = ptr("messaging/advisories/" + id.String() + "/image" + ext)
			if out.ImageUpload, err = s.presignPut(ctx, *imageKey, *in.ImageContentType); err != nil {
				return err
			}
		}

		row, err = q.UpdateAdvisoryContent(ctx, store.UpdateAdvisoryContentParams{
			ID: id, Sender: next.Sender, TitleTe: next.TitleTe, BodyTe: next.BodyTe, TitleEn: next.TitleEn,
			BodyEn: next.BodyEn, AudioKey: audioKey, ImageKey: imageKey, NamesProduct: next.NamesProduct,
			Class: class, Target: target, Channels: channels, UpdatedBy: someUUID(p.ID),
		})
		if err != nil {
			return apperr.Internalf("messaging: update advisory: %w", err)
		}
		out.Advisory = toAdvisory(row)
		_, err = audit.Record(ctx, tx, audit.Entry{
			Action: "messaging.advisory_updated", EntityType: "advisory", EntityID: id,
			Before: before, After: out.Advisory,
		})
		return err
	})
	return out, err
}

// applyAdvisoryPatch copies the set fields of in onto next. "" for an English
// field removes it (validateAdvisoryInput turns it into nil). When
// names_product changes and no class is given, the class is derived again.
func applyAdvisoryPatch(next *AdvisoryInput, in AdvisoryPatch) {
	if in.Sender != nil {
		next.Sender = *in.Sender
	}
	if in.TitleTe != nil {
		next.TitleTe = *in.TitleTe
	}
	if in.BodyTe != nil {
		next.BodyTe = *in.BodyTe
	}
	if in.TitleEn != nil {
		next.TitleEn = in.TitleEn
	}
	if in.BodyEn != nil {
		next.BodyEn = in.BodyEn
	}
	if in.NamesProduct != nil && *in.NamesProduct != next.NamesProduct {
		next.NamesProduct = *in.NamesProduct
		next.Class = nil
	}
	if in.Class != nil {
		next.Class = in.Class
	}
	if in.Target != nil {
		next.Target = *in.Target
	}
	if in.Channels != nil {
		next.Channels = *in.Channels
	}
}
