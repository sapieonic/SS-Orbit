package messaging

import (
	"context"
	"encoding/json"

	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// Farmer app inbox, farmer web page and the FA Alerts tab.

func (h *handler) ListFarmerNotices(ctx context.Context, req ListFarmerNoticesRequestObject) (ListFarmerNoticesResponseObject, error) {
	page, err := h.svc.ListNotices(ctx, req.Params.Limit, req.Params.Cursor)
	if err != nil {
		return nil, err
	}
	p := paging.Map(page, noticeDTO)
	return ListFarmerNotices200JSONResponse{Items: p.Items, NextCursor: p.NextCursor}, nil
}

func (h *handler) GetUnreadNoticeCount(ctx context.Context, _ GetUnreadNoticeCountRequestObject) (GetUnreadNoticeCountResponseObject, error) {
	n, err := h.svc.UnreadCount(ctx)
	if err != nil {
		return nil, err
	}
	return GetUnreadNoticeCount200JSONResponse{Unread: n}, nil
}

func (h *handler) MarkNoticeRead(ctx context.Context, req MarkNoticeReadRequestObject) (MarkNoticeReadResponseObject, error) {
	if err := h.svc.MarkRead(ctx, req.NoticeId); err != nil {
		return nil, err
	}
	return MarkNoticeRead204Response{}, nil
}

func (h *handler) MarkNoticeListened(ctx context.Context, req MarkNoticeListenedRequestObject) (MarkNoticeListenedResponseObject, error) {
	if err := h.svc.MarkListened(ctx, req.NoticeId); err != nil {
		return nil, err
	}
	return MarkNoticeListened204Response{}, nil
}

func (h *handler) GetWebNotice(ctx context.Context, req GetWebNoticeRequestObject) (GetWebNoticeResponseObject, error) {
	n, err := h.svc.GetWebNotice(ctx, req.NoticeId)
	if err != nil {
		return nil, err
	}
	return GetWebNotice200JSONResponse(noticeDTO(n)), nil
}

func (h *handler) MarkWebNoticeListened(ctx context.Context, req MarkWebNoticeListenedRequestObject) (MarkWebNoticeListenedResponseObject, error) {
	if err := h.svc.MarkWebListened(ctx, req.NoticeId); err != nil {
		return nil, err
	}
	return MarkWebNoticeListened204Response{}, nil
}

func (h *handler) ListFAAlerts(ctx context.Context, req ListFAAlertsRequestObject) (ListFAAlertsResponseObject, error) {
	page, err := h.svc.ListFAAlerts(ctx, strPtr(req.Params.Status), req.Params.Limit, req.Params.Cursor)
	if err != nil {
		return nil, err
	}
	p := paging.Map(page, faAlertDTO)
	return ListFAAlerts200JSONResponse{Items: p.Items, NextCursor: p.NextCursor}, nil
}

func noticeDTO(n InboxNotice) Notice {
	return Notice{
		Id: n.ID, Kind: NoticeKind(n.Kind), Sender: NoticeSender(n.Sender), TitleTe: n.TitleTe, BodyTe: n.BodyTe,
		TitleEn: n.TitleEn, BodyEn: n.BodyEn, AudioUrl: n.AudioURL, RefType: n.RefType, RefId: n.RefID,
		Pinned: n.Pinned, ReadAt: n.ReadAt, ListenedAt: n.ListenedAt, CreatedAt: n.CreatedAt,
	}
}

func faAlertDTO(a FieldAlert) FAAlert {
	return FAAlert{
		Id: a.ID, FaId: a.FAID, Kind: FAAlertKind(a.Kind), FarmerId: a.FarmerID, RefId: a.RefID, Title: a.Title,
		Body: a.Body, TitleTe: a.TitleTe, BodyTe: a.BodyTe, Status: FAAlertStatus(a.Status), CreatedAt: a.CreatedAt,
		AcknowledgedAt: a.AcknowledgedAt,
		FarmerName:     a.FarmerName, FarmerPhone: a.FarmerPhone,
	}
}

// jsonObject decodes a stored JSON object; anything else gives nil.
func jsonObject(raw json.RawMessage) map[string]any {
	var m map[string]any
	if len(raw) == 0 || json.Unmarshal(raw, &m) != nil {
		return nil
	}
	return m
}
