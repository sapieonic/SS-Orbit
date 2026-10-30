package messaging

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
)

// Advisory workflow: draft -> (pending_approval ->) scheduled -> sending -> sent,
// with cancel before sending and reject back to draft. Only drafts can be
// edited (UpdateAdvisory).

// SubmitAdvisory moves a draft on: advisories that name a product wait for
// Agronomy approval; others are scheduled for sendAt (nil or past = now).
func (s *Service) SubmitAdvisory(ctx context.Context, id uuid.UUID, sendAt *time.Time) (AdvisoryRecord, error) {
	p, err := auth.RequireRole(ctx, advisoryRoles...)
	if err != nil {
		return AdvisoryRecord{}, err
	}
	return s.transition(ctx, p, id, "messaging.advisory_submitted", func(a *store.Advisory) error {
		if a.Status != StatusDraft {
			return wrongStatus(a.Status)
		}
		if err := s.checkUploads(ctx, a); err != nil {
			return err
		}
		// Again at submit: product names may have been added since the draft.
		if err := s.checkProductMentions(ctx, a.NamesProduct, &a.TitleTe, &a.BodyTe, a.TitleEn, a.BodyEn); err != nil {
			return err
		}
		a.ScheduledFor = utcPtr(sendAt)
		a.ReviewNote = nil
		if a.NamesProduct {
			a.Status = StatusPendingApproval
			return nil
		}
		a.Status = StatusScheduled
		a.ScheduledFor = ptr(s.dueAt(sendAt))
		return nil
	})
}

// ApproveAdvisory is Agronomy's approval of an advisory that names a product.
func (s *Service) ApproveAdvisory(ctx context.Context, id uuid.UUID) (AdvisoryRecord, error) {
	p, err := auth.RequireRole(ctx, auth.RoleAgronomy)
	if err != nil {
		return AdvisoryRecord{}, err
	}
	return s.transition(ctx, p, id, "messaging.advisory_approved", func(a *store.Advisory) error {
		if a.Status != StatusPendingApproval {
			return wrongStatus(a.Status)
		}
		if a.CreatedBy == p.ID || (a.UpdatedBy.Valid && a.UpdatedBy.UUID == p.ID) {
			return apperr.Forbidden("an advisory must be approved by someone other than its author or last editor")
		}
		now := s.now()
		a.Status, a.ApprovedBy, a.ApprovedAt = StatusScheduled, someUUID(p.ID), &now
		a.ScheduledFor = ptr(s.dueAt(a.ScheduledFor))
		return nil
	})
}

// RejectAdvisory sends an advisory awaiting approval back to draft.
func (s *Service) RejectAdvisory(ctx context.Context, id uuid.UUID, note string) (AdvisoryRecord, error) {
	p, err := auth.RequireRole(ctx, auth.RoleAgronomy)
	if err != nil {
		return AdvisoryRecord{}, err
	}
	note = strings.TrimSpace(note)
	if note == "" {
		return AdvisoryRecord{}, apperr.Validation("note", "say why the advisory is sent back")
	}
	return s.transition(ctx, p, id, "messaging.advisory_rejected", func(a *store.Advisory) error {
		if a.Status != StatusPendingApproval {
			return wrongStatus(a.Status)
		}
		a.Status, a.ReviewNote, a.ScheduledFor = StatusDraft, &note, nil
		return nil
	})
}

// CancelAdvisory stops an advisory that has not started sending.
func (s *Service) CancelAdvisory(ctx context.Context, id uuid.UUID) (AdvisoryRecord, error) {
	p, err := auth.RequireRole(ctx, advisoryRoles...)
	if err != nil {
		return AdvisoryRecord{}, err
	}
	return s.transition(ctx, p, id, "messaging.advisory_cancelled", func(a *store.Advisory) error {
		switch a.Status {
		case StatusDraft, StatusPendingApproval, StatusScheduled:
			a.Status = StatusCancelled
			return nil
		}
		return wrongStatus(a.Status)
	})
}

// transition loads an advisory FOR UPDATE, applies change, saves it, audits
// it and, when it became scheduled, enqueues the fan-out job for its time.
func (s *Service) transition(ctx context.Context, p auth.Principal, id uuid.UUID, action string, change func(a *store.Advisory) error) (AdvisoryRecord, error) {
	var out AdvisoryRecord
	err := s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		row, err := q.GetAdvisoryForUpdate(ctx, id)
		if err != nil {
			return notFoundOr(err, "advisory")
		}
		before := toAdvisory(row)
		if !visible(p, before) {
			return apperr.NotFound("advisory")
		}
		if err := change(&row); err != nil {
			return err
		}
		row, err = q.UpdateAdvisoryState(ctx, store.UpdateAdvisoryStateParams{
			ID: id, Status: row.Status, ScheduledFor: row.ScheduledFor, SentAt: row.SentAt,
			RecipientCount: row.RecipientCount, ApprovedBy: row.ApprovedBy, ApprovedAt: row.ApprovedAt,
			ReviewNote: row.ReviewNote,
		})
		if err != nil {
			return apperr.Internalf("messaging: update advisory: %w", err)
		}
		out = toAdvisory(row)
		if out.Status == StatusScheduled && before.Status != StatusScheduled {
			if err := s.deps.Jobs.Insert(ctx, tx, advisoryFanoutArgs{AdvisoryID: id},
				&river.InsertOpts{ScheduledAt: *out.ScheduledFor, MaxAttempts: fanoutMaxAttempts}); err != nil {
				return err
			}
		}
		_, err = audit.Record(ctx, tx, audit.Entry{
			Action: action, EntityType: "advisory", EntityID: id,
			Before: map[string]any{"status": before.Status},
			After:  map[string]any{"status": out.Status, "scheduled_for": out.ScheduledFor, "review_note": out.ReviewNote},
		})
		return err
	})
	return out, err
}

// dueAt is when a scheduled advisory fans out: the requested time, or now.
func (s *Service) dueAt(requested *time.Time) time.Time {
	now := s.now()
	if requested == nil || requested.Before(now) {
		return now
	}
	return requested.UTC()
}

// checkUploads refuses to submit an advisory whose media was never uploaded.
func (s *Service) checkUploads(ctx context.Context, a *store.Advisory) error {
	for field, key := range map[string]*string{"audio": a.AudioKey, "image": a.ImageKey} {
		if key == nil {
			continue
		}
		ok, err := s.deps.Storage.Exists(ctx, *key)
		if err != nil {
			return apperr.Internalf("messaging: check upload: %w", err)
		}
		if !ok {
			return apperr.Validation(field, "upload the file before submitting")
		}
	}
	return nil
}

func wrongStatus(status string) error {
	return apperr.Conflict("invalid_status", map[string]any{"status": status}).
		WithMessage("the advisory cannot do this while it is " + status)
}
