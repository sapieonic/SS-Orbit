package visits

import (
	"context"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// handler implements StrictServerInterface. It only maps between generated
// DTOs and the service; service errors are returned unchanged and written by
// httpx.ResponseErrorHandler in the shared error shape.
type handler struct {
	svc *Service
}

var _ StrictServerInterface = (*handler)(nil)

// --- FA app ---

func (h *handler) CreateVisitPhotoUpload(ctx context.Context, req CreateVisitPhotoUploadRequestObject) (CreateVisitPhotoUploadResponseObject, error) {
	up, err := h.svc.PresignPhotoUpload(ctx, req.VisitId, req.PhotoId, string(req.Body.ContentType), req.Body.Bytes)
	if err != nil {
		return nil, err
	}
	return CreateVisitPhotoUpload200JSONResponse{
		PhotoId: up.PhotoID, StorageKey: up.StorageKey, Url: up.URL, Method: up.Method,
		Headers: up.Headers, ExpiresAt: up.ExpiresAt,
	}, nil
}

func (h *handler) ConfirmVisitPhotoUpload(ctx context.Context, req ConfirmVisitPhotoUploadRequestObject) (ConfirmVisitPhotoUploadResponseObject, error) {
	var sha *string
	if req.Body != nil {
		sha = req.Body.Sha256
	}
	ph, err := h.svc.ConfirmPhotoUpload(ctx, req.VisitId, req.PhotoId, sha)
	if err != nil {
		return nil, err
	}
	return ConfirmVisitPhotoUpload200JSONResponse(toPhotoDTO(ph)), nil
}

// --- Farmer app ---

func (h *handler) ListMyVisits(ctx context.Context, req ListMyVisitsRequestObject) (ListMyVisitsResponseObject, error) {
	page, err := h.svc.MyVisits(ctx, req.Params.Limit, req.Params.Cursor)
	if err != nil {
		return nil, err
	}
	out := FarmerVisitPage{Items: make([]FarmerVisit, len(page.Items)), NextCursor: page.NextCursor}
	for i, v := range page.Items {
		out.Items[i] = toFarmerVisitDTO(v)
	}
	return ListMyVisits200JSONResponse(out), nil
}

func (h *handler) GetMyNextVisit(ctx context.Context, _ GetMyNextVisitRequestObject) (GetMyNextVisitResponseObject, error) {
	nv, err := h.svc.MyNextVisit(ctx)
	if err != nil {
		return nil, err
	}
	out := NextVisitResponse{}
	if nv != nil {
		out.NextVisit = &NextVisit{
			VisitId: nv.VisitID, PlotId: nv.PlotID, PlannedFor: date(nv.PlannedFor),
			PlannedSlot: PlannedSlot(nv.PlannedSlot), Purpose: nv.Purpose, Fa: toFADTO(nv.FA),
		}
	}
	return GetMyNextVisit200JSONResponse(out), nil
}

func (h *handler) RequestCallback(ctx context.Context, _ RequestCallbackRequestObject) (RequestCallbackResponseObject, error) {
	c, created, err := h.svc.RequestCallback(ctx)
	if err != nil {
		return nil, err
	}
	if created {
		return RequestCallback201JSONResponse(toCallbackDTO(c)), nil
	}
	return RequestCallback200JSONResponse(toCallbackDTO(c)), nil
}

func (h *handler) GetMyOpenCallback(ctx context.Context, _ GetMyOpenCallbackRequestObject) (GetMyOpenCallbackResponseObject, error) {
	c, err := h.svc.MyOpenCallback(ctx)
	if err != nil {
		return nil, err
	}
	out := CurrentCallbackResponse{}
	if c != nil {
		dto := toCallbackDTO(*c)
		out.Callback = &dto
	}
	return GetMyOpenCallback200JSONResponse(out), nil
}

func (h *handler) CancelMyCallback(ctx context.Context, req CancelMyCallbackRequestObject) (CancelMyCallbackResponseObject, error) {
	c, err := h.svc.CancelMyCallback(ctx, req.CallbackId)
	if err != nil {
		return nil, err
	}
	return CancelMyCallback200JSONResponse(toCallbackDTO(c)), nil
}

// --- HO portal ---

func (h *handler) ListVisits(ctx context.Context, req ListVisitsRequestObject) (ListVisitsResponseObject, error) {
	p := req.Params
	f := ListFilter{FAID: p.FaId, FarmerID: p.FarmerId, From: dayPtr(p.From), To: dayPtr(p.To)}
	if p.Status != nil {
		s := string(*p.Status)
		f.Status = &s
	}
	page, err := h.svc.List(ctx, f, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	return ListVisits200JSONResponse(toVisitPageDTO(page)), nil
}

func (h *handler) ListOverdueVisits(ctx context.Context, req ListOverdueVisitsRequestObject) (ListOverdueVisitsResponseObject, error) {
	page, err := h.svc.Overdue(ctx, req.Params.FaId, req.Params.Limit, req.Params.Cursor)
	if err != nil {
		return nil, err
	}
	return ListOverdueVisits200JSONResponse(toVisitPageDTO(page)), nil
}

func (h *handler) SampleVisits(ctx context.Context, req SampleVisitsRequestObject) (SampleVisitsResponseObject, error) {
	p := req.Params
	s, err := h.svc.Sample(ctx, p.From.Time, p.To.Time, p.FaId, p.Size)
	if err != nil {
		return nil, err
	}
	out := VisitSample{From: date(s.From), To: date(s.To), Size: s.Size, Items: make([]Visit, len(s.Items))}
	for i, v := range s.Items {
		out.Items[i] = toVisitDTO(v)
	}
	return SampleVisits200JSONResponse(out), nil
}

func (h *handler) GetVisitCounts(ctx context.Context, req GetVisitCountsRequestObject) (GetVisitCountsResponseObject, error) {
	p := req.Params
	c, err := h.svc.Counts(ctx, p.From.Time, p.To.Time, CountsFilter{
		FAID: p.FaId, DistrictID: p.DistrictId, ByDay: p.GroupBy != nil && *p.GroupBy == GroupByDay,
	})
	if err != nil {
		return nil, err
	}
	out := VisitCounts{From: date(c.From), To: date(c.To), Items: make([]FAVisitCounts, len(c.Items))}
	for i, r := range c.Items {
		out.Items[i] = FAVisitCounts{
			FaId: r.FAID, FaName: r.FAName, Planned: r.Planned, Done: r.Done, Missed: r.Missed, FarmersVisited: r.FarmersVisited,
		}
	}
	if c.Days != nil {
		days := make([]DayVisitCounts, len(c.Days))
		for i, d := range c.Days {
			days[i] = DayVisitCounts{Date: date(d.Date), Planned: d.Planned, Done: d.Done, Missed: d.Missed}
		}
		out.Days = &days
	}
	return GetVisitCounts200JSONResponse(out), nil
}

func (h *handler) GetVisit(ctx context.Context, req GetVisitRequestObject) (GetVisitResponseObject, error) {
	d, err := h.svc.Get(ctx, req.VisitId)
	if err != nil {
		return nil, err
	}
	out := VisitDetail{Visit: toVisitDTO(d.Visit), Photos: make([]VisitPhoto, len(d.Photos))}
	for i, ph := range d.Photos {
		out.Photos[i] = toPhotoDTO(ph)
	}
	return GetVisit200JSONResponse(out), nil
}

// --- mapping ---

func toVisitPageDTO(p paging.Page[VisitRecord]) VisitPage {
	items := make([]Visit, len(p.Items))
	for i, v := range p.Items {
		items[i] = toVisitDTO(v)
	}
	return VisitPage{Items: items, NextCursor: p.NextCursor}
}

func toVisitDTO(v VisitRecord) Visit {
	out := Visit{
		Id: v.ID, FarmerId: v.FarmerID, PlotId: v.PlotID, SeasonId: v.SeasonID, FaId: v.FAID, FaName: v.FAName,
		Status: VisitStatus(v.Status), PlannedFor: datePtr(v.PlannedFor), Purpose: v.Purpose, VisitedAt: v.VisitedAt,
		FarmerPresent: v.FarmerPresent, StageId: v.StageID, StageName: v.StageName, StageNameTe: v.StageNameTe,
		Notes: v.Notes, PhotoCount: v.PhotoCount, Issues: make([]VisitIssue, len(v.Issues)),
		CreatedAt: v.CreatedAt, UpdatedAt: v.UpdatedAt,
	}
	if v.PlannedSlot != nil {
		s := PlannedSlot(*v.PlannedSlot)
		out.PlannedSlot = &s
	}
	if v.Location != nil {
		out.Location = &VisitLatLng{Lat: v.Location.Lat, Lng: v.Location.Lng}
	}
	if f := v.Farmer; f != nil {
		out.FarmerName, out.FarmerNameTe, out.FarmerPhoneMasked = f.Name, f.NameTe, &f.PhoneMasked
		out.VillageId, out.VillageName, out.VillageNameTe = f.VillageID, f.VillageName, f.VillageNameTe
	}
	for i, is := range v.Issues {
		a := is.Advice
		out.Issues[i] = VisitIssue{
			Id: is.ID, IssueId: is.IssueID, IssueName: is.IssueName, IssueNameTe: is.IssueNameTe,
			Severity: Severity(is.Severity), AdviceStatus: VisitIssueAdviceStatus(is.AdviceStatus),
			RequestedRuleId: is.RequestedRuleID, UnresolvedReason: is.UnresolvedReason,
			Advice: Advice{
				RuleId: a.RuleID, RuleVersion: a.RuleVersion, SaltId: a.SaltID, SaltName: a.SaltName,
				SaltNameTe: a.SaltNameTe, SkuId: a.SKUID, ProductName: a.ProductName, ProductNameTe: a.ProductNameTe,
				Dose: a.Dose, DoseTe: a.DoseTe, SaltOnly: a.SaltOnly(),
			},
		}
	}
	return out
}

func toFarmerVisitDTO(v FarmerVisitRecord) FarmerVisit {
	out := FarmerVisit{
		Id: v.ID, PlotId: v.PlotID, VisitedAt: v.VisitedAt, Fa: toFADTO(v.FA),
		StageName: v.StageName, StageNameTe: v.StageNameTe, Issues: make([]FarmerAdvice, len(v.Issues)),
	}
	for i, is := range v.Issues {
		a := is.Advice
		out.Issues[i] = FarmerAdvice{
			IssueName: is.IssueName, IssueNameTe: is.IssueNameTe, Severity: Severity(is.Severity),
			AdvicePending: is.Unresolved(), SaltName: a.SaltName, SaltNameTe: a.SaltNameTe, SkuId: a.SKUID,
			ProductName: a.ProductName, ProductNameTe: a.ProductNameTe, Dose: a.Dose, DoseTe: a.DoseTe,
			SaltOnly: a.SaltOnly(),
		}
	}
	return out
}

func toPhotoDTO(p Photo) VisitPhoto {
	return VisitPhoto{
		Id: p.ID, VisitId: p.VisitID, ContentType: p.ContentType, Bytes: p.Bytes, UploadedAt: p.UploadedAt, Url: p.URL,
	}
}

func toCallbackDTO(c CallbackInfo) Callback {
	return Callback{
		Id: c.ID, FarmerId: c.FarmerID, FaId: c.FAID, Status: CallbackStatus(c.Status),
		RequestedAt: c.RequestedAt, ClosedAt: c.ClosedAt,
	}
}

func toFADTO(f *FARef) *FAName {
	if f == nil {
		return nil
	}
	return &FAName{Id: f.ID, Name: f.Name, NameTe: f.NameTe}
}

func date(t time.Time) openapi_types.Date { return openapi_types.Date{Time: t} }

func datePtr(t *time.Time) *openapi_types.Date {
	if t == nil {
		return nil
	}
	d := date(*t)
	return &d
}

func dayPtr(d *openapi_types.Date) *time.Time {
	if d == nil {
		return nil
	}
	t := d.Time
	return &t
}
