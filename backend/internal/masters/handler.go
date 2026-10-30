package masters

import (
	"context"

	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// handler implements StrictServerInterface. It only maps between generated
// DTOs and the service; errors from the service are returned unchanged and
// written by httpx.ResponseErrorHandler in the shared error shape.
type handler struct {
	svc *Service
}

var _ StrictServerInterface = (*handler)(nil)

func (h *handler) GetMastersVersion(ctx context.Context, _ GetMastersVersionRequestObject) (GetMastersVersionResponseObject, error) {
	v, err := h.svc.GetVersion(ctx)
	if err != nil {
		return nil, err
	}
	return GetMastersVersion200JSONResponse{Version: v.Version, UpdatedAt: v.UpdatedAt}, nil
}

// ---- crops ----

func (h *handler) ListCrops(ctx context.Context, req ListCropsRequestObject) (ListCropsResponseObject, error) {
	page, err := h.svc.ListCrops(ctx, req.Params.Active, req.Params.Limit, req.Params.Cursor)
	if err != nil {
		return nil, err
	}
	items, next := mapPage(page, toCropView)
	return ListCrops200JSONResponse(CropPage{Items: items, NextCursor: next}), nil
}

func (h *handler) CreateCrop(ctx context.Context, req CreateCropRequestObject) (CreateCropResponseObject, error) {
	b := req.Body
	in := CropInput{Code: b.Code, Name: b.Name, NameTe: b.NameTe, DurationDays: b.DurationDays}
	if b.Stages != nil {
		in.Stages = mapSlice(*b.Stages, fromStageSpec)
	}
	c, err := h.svc.CreateCrop(ctx, in)
	if err != nil {
		return nil, err
	}
	return CreateCrop201JSONResponse(toCropView(c)), nil
}

func (h *handler) GetCrop(ctx context.Context, req GetCropRequestObject) (GetCropResponseObject, error) {
	c, err := h.svc.GetCrop(ctx, req.CropId)
	if err != nil {
		return nil, err
	}
	return GetCrop200JSONResponse(toCropView(c)), nil
}

func (h *handler) UpdateCrop(ctx context.Context, req UpdateCropRequestObject) (UpdateCropResponseObject, error) {
	b := req.Body
	c, err := h.svc.UpdateCrop(ctx, req.CropId, CropPatch{Name: b.Name, NameTe: b.NameTe, DurationDays: b.DurationDays, Active: b.Active})
	if err != nil {
		return nil, err
	}
	return UpdateCrop200JSONResponse(toCropView(c)), nil
}

func (h *handler) ReplaceCropStages(ctx context.Context, req ReplaceCropStagesRequestObject) (ReplaceCropStagesResponseObject, error) {
	c, err := h.svc.ReplaceStages(ctx, req.CropId, mapSlice(req.Body.Stages, fromStageSpec))
	if err != nil {
		return nil, err
	}
	return ReplaceCropStages200JSONResponse(toCropView(c)), nil
}

func toCropView(c Crop) CropView {
	return CropView{
		Id: c.ID, Code: c.Code, Name: c.Name, NameTe: c.NameTe, DurationDays: c.DurationDays,
		Active: c.Active, CreatedAt: c.CreatedAt, Stages: mapSlice(c.Stages, toStageView),
	}
}

func toStageView(s Stage) StageView {
	return StageView{
		Id: s.ID, Code: s.Code, Name: s.Name, NameTe: s.NameTe, Seq: s.Seq,
		StartDay: s.StartDay, EndDay: s.EndDay, Active: s.Active,
	}
}

func fromStageSpec(s StageSpec) StageInput {
	return StageInput{Code: s.Code, Name: s.Name, NameTe: s.NameTe, StartDay: s.StartDay, EndDay: s.EndDay}
}

// mapSlice maps a slice, never returning nil (lists are always JSON arrays).
func mapSlice[T, U any](in []T, fn func(T) U) []U {
	out := make([]U, len(in))
	for i, v := range in {
		out[i] = fn(v)
	}
	return out
}

// mapPage maps a service page to the generated page's items and cursor.
func mapPage[T, U any](p paging.Page[T], fn func(T) U) ([]U, *string) {
	return mapSlice(p.Items, fn), p.NextCursor
}
