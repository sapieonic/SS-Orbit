package messaging

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// RunAdvisoryFanout sends a due advisory: it claims it (scheduled -> sending),
// resolves recipients, creates one notice per farmer and the channel
// deliveries in batches, then marks it sent. It is safe to run again: a
// cancelled or sent advisory is skipped, and a run that stopped half way
// resumes because notices are unique per (advisory, farmer).
func (s *Service) RunAdvisoryFanout(ctx context.Context, id uuid.UUID) error {
	adv, ok, err := s.claimAdvisory(ctx, id)
	if err != nil || !ok {
		return err
	}
	target := toAdvisory(adv).Target
	farmerIDs, err := s.ports.Farmers.FarmerIDsForTargeting(ctx, target.toXmod())
	if err != nil {
		return apperr.Internalf("messaging: targeting: %w", err)
	}
	for start := 0; start < len(farmerIDs); start += fanoutBatchSize {
		end := min(start+fanoutBatchSize, len(farmerIDs))
		if err := s.fanoutBatch(ctx, adv, farmerIDs[start:end]); err != nil {
			return err
		}
	}
	return s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		row, err := q.GetAdvisoryForUpdate(ctx, id)
		if err != nil {
			return err
		}
		if row.Status != StatusSending {
			return nil
		}
		st, err := q.AdvisoryStats(ctx, someUUID(id))
		if err != nil {
			return err
		}
		now := s.now()
		row, err = q.UpdateAdvisoryState(ctx, store.UpdateAdvisoryStateParams{
			ID: id, Status: StatusSent, ScheduledFor: row.ScheduledFor, SentAt: &now, RecipientCount: &st.Notices,
			ApprovedBy: row.ApprovedBy, ApprovedAt: row.ApprovedAt, ReviewNote: row.ReviewNote,
		})
		if err != nil {
			return err
		}
		_, err = audit.Record(ctx, tx, audit.Entry{
			Action: "messaging.advisory_sent", EntityType: "advisory", EntityID: id,
			Before: map[string]any{"status": StatusSending},
			After:  map[string]any{"status": StatusSent, "recipient_count": st.Notices, "targeted": len(farmerIDs)},
		})
		return err
	})
}

// claimAdvisory moves a due advisory to sending. ok is false when there is
// nothing to do (cancelled, already sent, or not due yet).
func (s *Service) claimAdvisory(ctx context.Context, id uuid.UUID) (adv store.Advisory, ok bool, err error) {
	err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		row, err := q.GetAdvisoryForUpdate(ctx, id)
		if err != nil {
			return notFoundOr(err, "advisory")
		}
		adv = row
		switch row.Status {
		case StatusSending: // a previous run stopped half way; resume
			ok = true
			return nil
		case StatusScheduled:
		default:
			logx.From(ctx).InfoContext(ctx, "messaging: advisory not sendable, skipping", "advisory_id", id, "status", row.Status)
			return nil
		}
		if row.ScheduledFor != nil && row.ScheduledFor.After(s.now().Add(time.Minute)) {
			// Ran early (clock skew): try again at the scheduled time.
			return river.JobSnooze(row.ScheduledFor.Sub(s.now()))
		}
		adv, err = q.UpdateAdvisoryState(ctx, store.UpdateAdvisoryStateParams{
			ID: id, Status: StatusSending, ScheduledFor: row.ScheduledFor, SentAt: row.SentAt,
			RecipientCount: row.RecipientCount, ApprovedBy: row.ApprovedBy, ApprovedAt: row.ApprovedAt,
			ReviewNote: row.ReviewNote,
		})
		if err != nil {
			return err
		}
		ok = true
		_, err = audit.Record(ctx, tx, audit.Entry{
			Action: "messaging.advisory_sending", EntityType: "advisory", EntityID: id,
			Before: map[string]any{"status": StatusScheduled}, After: map[string]any{"status": StatusSending},
		})
		return err
	})
	return adv, ok, err
}

// eligible applies the message-class rule to one farmer. Promotional messages
// go only to active farmers with current programme consent:
// FarmerIDsForTargeting already returns only those, and this re-check on the
// summary keeps the rule visible here (and drops anyone changed since). The
// same rule runs again at send time (sendBlocked).
func eligible(class string, f xmod.FarmerSummary) bool {
	return sendBlocked(class, f) == ""
}

// fanoutBatch creates notices and deliveries for one batch of farmers in one
// transaction. Farmers who already have the notice are skipped.
func (s *Service) fanoutBatch(ctx context.Context, adv store.Advisory, farmerIDs []uuid.UUID) error {
	summaries, err := s.farmerSummaries(ctx, farmerIDs)
	if err != nil {
		return err
	}
	noticeIDs := make([]uuid.UUID, 0, len(farmerIDs))
	recipients := make([]uuid.UUID, 0, len(farmerIDs))
	for _, id := range farmerIDs {
		if f, ok := summaries[id]; ok && eligible(adv.Class, f) {
			noticeIDs = append(noticeIDs, ids.New())
			recipients = append(recipients, id)
		}
	}
	if len(recipients) == 0 {
		return nil
	}
	text := noticeText{TitleTe: adv.TitleTe, BodyTe: adv.BodyTe, TitleEn: adv.TitleEn, BodyEn: adv.BodyEn}
	return s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		created, err := q.InsertAdvisoryNotices(ctx, store.InsertAdvisoryNoticesParams{
			Ids: noticeIDs, FarmerIds: recipients, AdvisoryID: someUUID(adv.ID), Sender: adv.Sender,
			TitleTe: adv.TitleTe, BodyTe: adv.BodyTe, TitleEn: adv.TitleEn, BodyEn: adv.BodyEn, AudioKey: adv.AudioKey,
		})
		if err != nil {
			return apperr.Internalf("messaging: insert notices: %w", err)
		}
		var specs []deliverySpec
		for _, n := range created {
			f := summaries[n.FarmerID]
			for _, ch := range adv.Channels {
				if ch == ChannelInApp {
					continue // the notice itself is the in-app message
				}
				specs = append(specs, deliverySpec{
					NoticeID: n.ID, FarmerID: n.FarmerID, Channel: ch,
					Message: renderAdvisory(ch, adv.Class, f.Language, text),
				})
			}
		}
		return s.createDeliveries(ctx, tx, q, specs)
	})
}

// deliverySpec is one delivery to create.
type deliverySpec struct {
	NoticeID uuid.UUID
	FarmerID uuid.UUID
	Channel  string
	Message  message
}

// createDeliveries inserts delivery rows and enqueues a send job for each, in
// tx. SMS, push and WhatsApp due in quiet hours wait until 07:00 IST.
func (s *Service) createDeliveries(ctx context.Context, tx pgx.Tx, q *store.Queries, specs []deliverySpec) error {
	if len(specs) == 0 {
		return nil
	}
	due := sendAfterQuietHours(s.now())
	arg := store.InsertDeliveriesParams{}
	for _, sp := range specs {
		arg.Ids = append(arg.Ids, ids.New())
		arg.NoticeIds = append(arg.NoticeIds, sp.NoticeID)
		arg.FarmerIds = append(arg.FarmerIds, sp.FarmerID)
		arg.Channels = append(arg.Channels, sp.Channel)
		arg.ScheduledFors = append(arg.ScheduledFors, due)
		arg.Titles = append(arg.Titles, sp.Message.Title)
		arg.Bodies = append(arg.Bodies, sp.Message.Body)
		arg.TemplateIds = append(arg.TemplateIds, sp.Message.TemplateID)
	}
	rows, err := q.InsertDeliveries(ctx, arg)
	if err != nil {
		return apperr.Internalf("messaging: insert deliveries: %w", err)
	}
	params := make([]river.InsertManyParams, 0, len(rows))
	for _, r := range rows {
		at := due
		if r.ScheduledFor != nil {
			at = *r.ScheduledFor
		}
		params = append(params, river.InsertManyParams{
			Args:       deliveryJobArgs{DeliveryID: r.ID},
			InsertOpts: &river.InsertOpts{ScheduledAt: at, MaxAttempts: deliveryMaxAttempts},
		})
	}
	return s.deps.Jobs.InsertMany(ctx, tx, params)
}
