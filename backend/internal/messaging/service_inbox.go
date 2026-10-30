package messaging

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

const (
	inboxListDefault = 30
	inboxListMax     = 100
)

// ListNotices is the farmer's "My Crop Advisory" inbox, newest first.
func (s *Service) ListNotices(ctx context.Context, limit *int, cursor *string) (paging.Page[InboxNotice], error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return paging.Page[InboxNotice]{}, err
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[InboxNotice]{}, err
	}
	n := paging.Limit(limit, inboxListDefault, inboxListMax)
	rows, err := s.q.ListFarmerNotices(ctx, store.ListFarmerNoticesParams{
		FarmerID: p.ID, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[InboxNotice]{}, apperr.Internalf("messaging: list notices: %w", err)
	}
	page := paging.Build(rows, n, func(r store.Notice) paging.Cursor { return paging.Cursor{At: r.CreatedAt, ID: r.ID} })
	return paging.Map(page, func(r store.Notice) InboxNotice { return s.noticeWithMedia(ctx, r) }), nil
}

// UnreadCount is the inbox badge.
func (s *Service) UnreadCount(ctx context.Context) (int, error) {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return 0, err
	}
	n, err := s.q.CountUnreadNotices(ctx, p.ID)
	if err != nil {
		return 0, apperr.Internalf("messaging: unread count: %w", err)
	}
	return int(n), nil
}

// MarkRead marks the farmer's notice read. Repeats are no-ops.
func (s *Service) MarkRead(ctx context.Context, noticeID uuid.UUID) error {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return err
	}
	return s.markNotice(ctx, p.ID, noticeID, "messaging.notice_read", func(q *store.Queries) (uuid.UUID, error) {
		now := s.now()
		return q.MarkNoticeRead(ctx, store.MarkNoticeReadParams{ID: noticeID, FarmerID: p.ID, At: &now})
	})
}

// MarkListened records a play of the notice's voice note (in the app).
func (s *Service) MarkListened(ctx context.Context, noticeID uuid.UUID) error {
	p, err := auth.RequireKind(ctx, auth.KindFarmer)
	if err != nil {
		return err
	}
	return s.listened(ctx, p.ID, noticeID)
}

// GetWebNotice returns a notice for the farmer web page reached from an SMS or
// WhatsApp link. The link token must be for this notice.
func (s *Service) GetWebNotice(ctx context.Context, noticeID uuid.UUID) (InboxNotice, error) {
	p, err := webPrincipal(ctx, noticeID)
	if err != nil {
		return InboxNotice{}, err
	}
	row, err := s.q.GetNotice(ctx, noticeID)
	if err != nil {
		return InboxNotice{}, notFoundOr(err, "notice")
	}
	if row.FarmerID != p.ID {
		return InboxNotice{}, apperr.NotFound("notice")
	}
	return s.noticeWithMedia(ctx, row), nil
}

// MarkWebListened records a play of the voice note on the web page.
func (s *Service) MarkWebListened(ctx context.Context, noticeID uuid.UUID) error {
	p, err := webPrincipal(ctx, noticeID)
	if err != nil {
		return err
	}
	return s.listened(ctx, p.ID, noticeID)
}

func webPrincipal(ctx context.Context, noticeID uuid.UUID) (auth.Principal, error) {
	p, err := auth.RequireKind(ctx, auth.KindWeb)
	if err != nil {
		return p, err
	}
	if p.LinkPurpose != noticePurpose(noticeID) {
		return p, apperr.Forbidden("this link is for a different page")
	}
	return p, nil
}

func (s *Service) listened(ctx context.Context, farmerID, noticeID uuid.UUID) error {
	return s.markNotice(ctx, farmerID, noticeID, "messaging.notice_listened", func(q *store.Queries) (uuid.UUID, error) {
		now := s.now()
		return q.MarkNoticeListened(ctx, store.MarkNoticeListenedParams{ID: noticeID, FarmerID: farmerID, At: &now})
	})
}

// markNotice runs an idempotent "set timestamp if unset" update. No row
// updated means either already marked (fine) or not the farmer's (404).
func (s *Service) markNotice(ctx context.Context, farmerID, noticeID uuid.UUID, action string, update func(q *store.Queries) (uuid.UUID, error)) error {
	return s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		_, err := update(q)
		if db.IsNoRows(err) {
			row, err := q.GetNotice(ctx, noticeID)
			if err != nil {
				return notFoundOr(err, "notice")
			}
			if row.FarmerID != farmerID {
				return apperr.NotFound("notice")
			}
			return nil
		}
		if err != nil {
			return apperr.Internalf("messaging: mark notice: %w", err)
		}
		_, err = audit.Record(ctx, tx, audit.Entry{
			Action: action, EntityType: "notice", EntityID: noticeID, FarmerID: farmerID,
		})
		return err
	})
}

func (s *Service) noticeWithMedia(ctx context.Context, r store.Notice) InboxNotice {
	n := toNotice(r)
	n.AudioURL = s.presignGet(ctx, r.AudioKey)
	return n
}
