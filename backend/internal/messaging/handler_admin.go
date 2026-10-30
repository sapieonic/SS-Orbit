package messaging

import (
	"context"

	"github.com/sapionic/orbit/backend/internal/platform/paging"
	"github.com/sapionic/orbit/backend/internal/platform/storage"
)

// HO portal: advisories, HO alerts and notes to FAs.

func (h *handler) CreateAdvisory(ctx context.Context, req CreateAdvisoryRequestObject) (CreateAdvisoryResponseObject, error) {
	b := req.Body
	in := AdvisoryInput{
		TitleTe: b.TitleTe, BodyTe: b.BodyTe, TitleEn: b.TitleEn, BodyEn: b.BodyEn,
		Class: strPtr(b.Class), Target: targetFromDTO(b.Target), Channels: make([]string, len(b.Channels)),
		AudioContentType: strPtr(b.AudioContentType), ImageContentType: strPtr(b.ImageContentType),
	}
	if b.Sender != nil {
		in.Sender = string(*b.Sender)
	}
	if b.NamesProduct != nil {
		in.NamesProduct = *b.NamesProduct
	}
	for i, c := range b.Channels {
		in.Channels[i] = string(c)
	}
	out, err := h.svc.CreateAdvisory(ctx, in)
	if err != nil {
		return nil, err
	}
	return CreateAdvisory201JSONResponse{
		Advisory: advisoryDTO(out.Advisory), AudioUpload: uploadDTO(out.AudioUpload), ImageUpload: uploadDTO(out.ImageUpload),
	}, nil
}

func (h *handler) UpdateAdvisory(ctx context.Context, req UpdateAdvisoryRequestObject) (UpdateAdvisoryResponseObject, error) {
	b := req.Body
	in := AdvisoryPatch{
		Sender: strPtr(b.Sender), TitleTe: b.TitleTe, BodyTe: b.BodyTe, TitleEn: b.TitleEn, BodyEn: b.BodyEn,
		NamesProduct: b.NamesProduct, Class: strPtr(b.Class),
		AudioContentType: strPtr(b.AudioContentType), ImageContentType: strPtr(b.ImageContentType),
		RemoveAudio: b.RemoveAudio != nil && *b.RemoveAudio, RemoveImage: b.RemoveImage != nil && *b.RemoveImage,
	}
	if b.Target != nil {
		t := targetFromDTO(*b.Target)
		in.Target = &t
	}
	if b.Channels != nil {
		ch := make([]string, len(*b.Channels))
		for i, c := range *b.Channels {
			ch[i] = string(c)
		}
		in.Channels = &ch
	}
	out, err := h.svc.UpdateAdvisory(ctx, req.AdvisoryId, in)
	if err != nil {
		return nil, err
	}
	return UpdateAdvisory200JSONResponse{
		Advisory: advisoryDTO(out.Advisory), AudioUpload: uploadDTO(out.AudioUpload), ImageUpload: uploadDTO(out.ImageUpload),
	}, nil
}

func (h *handler) ListAdvisories(ctx context.Context, req ListAdvisoriesRequestObject) (ListAdvisoriesResponseObject, error) {
	page, err := h.svc.ListAdvisories(ctx, strPtr(req.Params.Status), req.Params.Limit, req.Params.Cursor)
	if err != nil {
		return nil, err
	}
	p := paging.Map(page, advisoryDTO)
	return ListAdvisories200JSONResponse{Items: p.Items, NextCursor: p.NextCursor}, nil
}

func (h *handler) PreviewAdvisoryRecipients(ctx context.Context, req PreviewAdvisoryRecipientsRequestObject) (PreviewAdvisoryRecipientsResponseObject, error) {
	n, err := h.svc.PreviewRecipients(ctx, targetFromDTO(req.Body.Target))
	if err != nil {
		return nil, err
	}
	return PreviewAdvisoryRecipients200JSONResponse{RecipientCount: n}, nil
}

func (h *handler) GetAdvisory(ctx context.Context, req GetAdvisoryRequestObject) (GetAdvisoryResponseObject, error) {
	a, err := h.svc.GetAdvisory(ctx, req.AdvisoryId)
	if err != nil {
		return nil, err
	}
	return GetAdvisory200JSONResponse(advisoryDTO(a)), nil
}

func (h *handler) SubmitAdvisory(ctx context.Context, req SubmitAdvisoryRequestObject) (SubmitAdvisoryResponseObject, error) {
	a, err := h.svc.SubmitAdvisory(ctx, req.AdvisoryId, req.Body.SendAt)
	if err != nil {
		return nil, err
	}
	return SubmitAdvisory200JSONResponse(advisoryDTO(a)), nil
}

func (h *handler) ApproveAdvisory(ctx context.Context, req ApproveAdvisoryRequestObject) (ApproveAdvisoryResponseObject, error) {
	a, err := h.svc.ApproveAdvisory(ctx, req.AdvisoryId)
	if err != nil {
		return nil, err
	}
	return ApproveAdvisory200JSONResponse(advisoryDTO(a)), nil
}

func (h *handler) RejectAdvisory(ctx context.Context, req RejectAdvisoryRequestObject) (RejectAdvisoryResponseObject, error) {
	a, err := h.svc.RejectAdvisory(ctx, req.AdvisoryId, req.Body.Note)
	if err != nil {
		return nil, err
	}
	return RejectAdvisory200JSONResponse(advisoryDTO(a)), nil
}

func (h *handler) CancelAdvisory(ctx context.Context, req CancelAdvisoryRequestObject) (CancelAdvisoryResponseObject, error) {
	a, err := h.svc.CancelAdvisory(ctx, req.AdvisoryId)
	if err != nil {
		return nil, err
	}
	return CancelAdvisory200JSONResponse(advisoryDTO(a)), nil
}

func (h *handler) ListAdvisoryRecipients(ctx context.Context, req ListAdvisoryRecipientsRequestObject) (ListAdvisoryRecipientsResponseObject, error) {
	page, err := h.svc.ListRecipients(ctx, req.AdvisoryId, req.Params.Limit, req.Params.Cursor)
	if err != nil {
		return nil, err
	}
	p := paging.Map(page, func(r RecipientStatus) Recipient { return recipientDTO(r) })
	return ListAdvisoryRecipients200JSONResponse{Items: p.Items, NextCursor: p.NextCursor}, nil
}

func (h *handler) ListHOAlerts(ctx context.Context, req ListHOAlertsRequestObject) (ListHOAlertsResponseObject, error) {
	page, err := h.svc.ListHOAlerts(ctx, strPtr(req.Params.Kind), req.Params.Limit, req.Params.Cursor)
	if err != nil {
		return nil, err
	}
	p := paging.Map(page, hoAlertDTO)
	return ListHOAlerts200JSONResponse{Items: p.Items, NextCursor: p.NextCursor}, nil
}

func (h *handler) CreateHONote(ctx context.Context, req CreateHONoteRequestObject) (CreateHONoteResponseObject, error) {
	b := req.Body
	a, err := h.svc.CreateHONote(ctx, HONote{FAID: b.FaId, Title: b.Title, Body: b.Body, TitleTe: b.TitleTe, BodyTe: b.BodyTe, FarmerID: b.FarmerId})
	if err != nil {
		return nil, err
	}
	return CreateHONote201JSONResponse(faAlertDTO(a)), nil
}

// DTO mapping.

func targetFromDTO(t AdvisoryTarget) Target {
	return Target{
		CropIDs: uuids(t.CropIds), DistrictIDs: uuids(t.DistrictIds), MandalIDs: uuids(t.MandalIds),
		VillageIDs: uuids(t.VillageIds), StageCodes: strs(t.StageCodes), Plan: strPtr(t.Plan),
	}
}

func targetDTO(t Target) AdvisoryTarget {
	t.normalize()
	out := AdvisoryTarget{
		CropIds: &t.CropIDs, DistrictIds: &t.DistrictIDs, MandalIds: &t.MandalIDs,
		VillageIds: &t.VillageIDs, StageCodes: &t.StageCodes,
	}
	if t.Plan != nil {
		p := AdvisoryTargetPlan(*t.Plan)
		out.Plan = &p
	}
	return out
}

func advisoryDTO(a AdvisoryRecord) Advisory {
	channels := make([]AdvisoryChannel, len(a.Channels))
	for i, c := range a.Channels {
		channels[i] = AdvisoryChannel(c)
	}
	out := Advisory{
		Id: a.ID, Sender: AdvisorySender(a.Sender), TitleTe: a.TitleTe, BodyTe: a.BodyTe, TitleEn: a.TitleEn,
		BodyEn: a.BodyEn, AudioKey: a.AudioKey, ImageKey: a.ImageKey, AudioUrl: a.AudioURL, ImageUrl: a.ImageURL,
		NamesProduct: a.NamesProduct, Class: AdvisoryClass(a.Class), Target: targetDTO(a.Target), Channels: channels,
		Status: AdvisoryStatus(a.Status), ScheduledFor: a.ScheduledFor, SentAt: a.SentAt,
		RecipientCount: a.RecipientCount, CreatedBy: a.CreatedBy, UpdatedBy: a.UpdatedBy, ApprovedBy: a.ApprovedBy, ApprovedAt: a.ApprovedAt,
		ReviewNote: a.ReviewNote, CreatedAt: a.CreatedAt, UpdatedAt: a.UpdatedAt,
	}
	if a.Stats != nil {
		out.Stats = &AdvisoryStats{Notices: a.Stats.Notices, Read: a.Stats.Read, Listened: a.Stats.Listened, Deliveries: a.Stats.Deliveries}
	}
	return out
}

func uploadDTO(p *storage.Presigned) *Upload {
	if p == nil {
		return nil
	}
	return &Upload{Url: p.URL, Method: p.Method, Headers: p.Headers, ExpiresAt: p.ExpiresAt}
}

func recipientDTO(r RecipientStatus) Recipient {
	ds := make([]RecipientDelivery, len(r.Deliveries))
	for i, d := range r.Deliveries {
		ds[i] = RecipientDelivery{
			Channel: RecipientDeliveryChannel(d.Channel), Status: RecipientDeliveryStatus(d.Status),
			Error: d.Error, SentAt: d.SentAt, Attempts: d.Attempts,
		}
	}
	return Recipient{NoticeId: r.NoticeID, FarmerId: r.FarmerID, FarmerName: r.FarmerName, FarmerNameTe: r.FarmerNameTe,
		PhoneMasked: r.PhoneMasked, CreatedAt: r.CreatedAt, ReadAt: r.ReadAt, ListenedAt: r.ListenedAt, Deliveries: ds}
}

func hoAlertDTO(a OverviewAlert) HOAlert {
	payload := map[string]any{}
	if obj := jsonObject(a.Payload); obj != nil {
		payload = obj
	}
	return HOAlert{Id: a.ID, Kind: HOAlertKind(a.Kind), FarmerId: a.FarmerID, FaId: a.FAID,
		DistrictId: a.DistrictID, Payload: payload, CreatedAt: a.CreatedAt}
}
