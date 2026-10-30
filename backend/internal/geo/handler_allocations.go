package geo

import (
	"context"

	openapi_types "github.com/oapi-codegen/runtime/types"
)

func (h *handler) ListAllocations(ctx context.Context, req ListAllocationsRequestObject) (ListAllocationsResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListAllocations(ctx, AllocationFilter{
		FAID: p.FaId, DistrictID: p.DistrictId, MandalID: p.MandalId, VillageID: p.VillageId,
		IncludeEnded: p.IncludeEnded != nil && *p.IncludeEnded,
	}, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	return ListAllocations200JSONResponse{Items: toAllocationDTOs(page.Items), NextCursor: page.NextCursor}, nil
}

func (h *handler) CreateAllocation(ctx context.Context, req CreateAllocationRequestObject) (CreateAllocationResponseObject, error) {
	b := req.Body
	isLead := b.IsLead == nil || *b.IsLead
	a, err := h.svc.CreateAllocation(ctx, NewAllocation{FAID: b.FaId, Level: string(b.Level), AreaID: b.AreaId, IsLead: isLead})
	if err != nil {
		return nil, err
	}
	return CreateAllocation201JSONResponse(toAllocationDTO(a)), nil
}

func (h *handler) EndAllocation(ctx context.Context, req EndAllocationRequestObject) (EndAllocationResponseObject, error) {
	a, err := h.svc.EndAllocation(ctx, req.AllocationId)
	if err != nil {
		return nil, err
	}
	return EndAllocation200JSONResponse(toAllocationDTO(a)), nil
}

func (h *handler) HandoverAllocations(ctx context.Context, req HandoverAllocationsRequestObject) (HandoverAllocationsResponseObject, error) {
	r, err := h.svc.Handover(ctx, req.Body.FromFaId, req.Body.ToFaId)
	if err != nil {
		return nil, err
	}
	return HandoverAllocations200JSONResponse{
		FromFaId:           r.FromFAID,
		ToFaId:             r.ToFAID,
		EndedAllocationIds: nonNilIDs(r.EndedIDs),
		Allocations:        toAllocationDTOs(r.Allocations),
		AffectedVillageIds: nonNilIDs(r.AffectedVillageIDs),
	}, nil
}

func toAllocationDTO(a FAAllocation) Allocation {
	out := Allocation{
		Id: a.ID, FaId: a.FAID, Level: AllocationLevel(a.Level),
		AreaId: a.AreaID, AreaName: a.AreaName, AreaNameTe: a.AreaNameTe,
		VillageId: a.VillageID, MandalId: a.MandalID, MandalName: a.MandalName, MandalNameTe: a.MandalNameTe,
		DistrictId: a.DistrictID, DistrictName: a.DistrictName, DistrictNameTe: a.DistrictNameTe,
		IsLead: a.IsLead, ValidFrom: a.ValidFrom, ValidTo: a.ValidTo, CreatedBy: a.CreatedBy, CreatedAt: a.CreatedAt,
	}
	if a.FA != nil {
		out.Fa = &FARef{Id: a.FA.ID, Code: a.FA.Code, Name: a.FA.Name, NameTe: a.FA.NameTe, Status: FARefStatus(a.FA.Status)}
	}
	return out
}

func toAllocationDTOs(as []FAAllocation) []Allocation {
	out := make([]Allocation, len(as))
	for i, a := range as {
		out[i] = toAllocationDTO(a)
	}
	return out
}

func nonNilIDs(ids []openapi_types.UUID) []openapi_types.UUID {
	if ids == nil {
		return []openapi_types.UUID{}
	}
	return ids
}
