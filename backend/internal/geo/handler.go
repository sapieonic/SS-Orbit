package geo

import (
	"context"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
)

// handler implements StrictServerInterface. It only maps between generated
// DTOs and the service; service errors are returned unchanged and written by
// httpx.ResponseErrorHandler in the shared error shape.
type handler struct {
	svc *Service
}

var _ StrictServerInterface = (*handler)(nil)

func (h *handler) GetAdminGeoTree(ctx context.Context, _ GetAdminGeoTreeRequestObject) (GetAdminGeoTreeResponseObject, error) {
	t, err := h.svc.AdminTree(ctx)
	if err != nil {
		return nil, err
	}
	return GetAdminGeoTree200JSONResponse(toTreeDTO(t)), nil
}

func (h *handler) GetFarmerGeoTree(ctx context.Context, _ GetFarmerGeoTreeRequestObject) (GetFarmerGeoTreeResponseObject, error) {
	t, err := h.svc.FarmerTree(ctx)
	if err != nil {
		return nil, err
	}
	return GetFarmerGeoTree200JSONResponse(toTreeDTO(t)), nil
}

func (h *handler) ListDistricts(ctx context.Context, _ ListDistrictsRequestObject) (ListDistrictsResponseObject, error) {
	ds, err := h.svc.ListDistricts(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]District, len(ds))
	for i, d := range ds {
		items[i] = toDistrictDTO(d)
	}
	return ListDistricts200JSONResponse{Items: items}, nil
}

func (h *handler) CreateDistrict(ctx context.Context, req CreateDistrictRequestObject) (CreateDistrictResponseObject, error) {
	b := req.Body
	d, err := h.svc.CreateDistrict(ctx, DistrictFields{Name: &b.Name, NameTe: b.NameTe, LGDCode: b.LgdCode, State: b.State})
	if err != nil {
		return nil, err
	}
	return CreateDistrict201JSONResponse(toDistrictDTO(d)), nil
}

func (h *handler) UpdateDistrict(ctx context.Context, req UpdateDistrictRequestObject) (UpdateDistrictResponseObject, error) {
	b := req.Body
	d, err := h.svc.UpdateDistrict(ctx, req.DistrictId, DistrictFields{Name: b.Name, NameTe: b.NameTe, LGDCode: b.LgdCode, State: b.State})
	if err != nil {
		return nil, err
	}
	return UpdateDistrict200JSONResponse(toDistrictDTO(d)), nil
}

func (h *handler) ListMandals(ctx context.Context, req ListMandalsRequestObject) (ListMandalsResponseObject, error) {
	ms, err := h.svc.ListMandals(ctx, req.Params.DistrictId)
	if err != nil {
		return nil, err
	}
	items := make([]Mandal, len(ms))
	for i, m := range ms {
		items[i] = toMandalDTO(m)
	}
	return ListMandals200JSONResponse{Items: items}, nil
}

func (h *handler) CreateMandal(ctx context.Context, req CreateMandalRequestObject) (CreateMandalResponseObject, error) {
	b := req.Body
	m, err := h.svc.CreateMandal(ctx, MandalFields{DistrictID: b.DistrictId, Name: &b.Name, NameTe: b.NameTe, LGDCode: b.LgdCode})
	if err != nil {
		return nil, err
	}
	return CreateMandal201JSONResponse(toMandalDTO(m)), nil
}

func (h *handler) UpdateMandal(ctx context.Context, req UpdateMandalRequestObject) (UpdateMandalResponseObject, error) {
	b := req.Body
	m, err := h.svc.UpdateMandal(ctx, req.MandalId, MandalFields{Name: b.Name, NameTe: b.NameTe, LGDCode: b.LgdCode})
	if err != nil {
		return nil, err
	}
	return UpdateMandal200JSONResponse(toMandalDTO(m)), nil
}

func (h *handler) ListVillages(ctx context.Context, req ListVillagesRequestObject) (ListVillagesResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListVillages(ctx, VillageFilter{Q: p.Q, MandalID: p.MandalId, DistrictID: p.DistrictId}, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	return ListVillages200JSONResponse{Items: toVillageDTOs(page.Items), NextCursor: page.NextCursor}, nil
}

func (h *handler) SearchFarmerVillages(ctx context.Context, req SearchFarmerVillagesRequestObject) (SearchFarmerVillagesResponseObject, error) {
	p := req.Params
	vs, err := h.svc.SearchVillagesForFarmer(ctx, VillageFilter{Q: p.Q, MandalID: p.MandalId, DistrictID: p.DistrictId}, p.Limit)
	if err != nil {
		return nil, err
	}
	return SearchFarmerVillages200JSONResponse{Items: toVillageDTOs(vs)}, nil
}

func (h *handler) GetVillage(ctx context.Context, req GetVillageRequestObject) (GetVillageResponseObject, error) {
	v, err := h.svc.GetVillage(ctx, req.VillageId)
	if err != nil {
		return nil, err
	}
	return GetVillage200JSONResponse(toVillageDTO(v)), nil
}

func (h *handler) CreateVillage(ctx context.Context, req CreateVillageRequestObject) (CreateVillageResponseObject, error) {
	b := req.Body
	v, err := h.svc.CreateVillage(ctx, VillageFields{MandalID: b.MandalId, Name: &b.Name, NameTe: b.NameTe, LGDCode: b.LgdCode, Lat: b.Lat, Lng: b.Lng})
	if err != nil {
		return nil, err
	}
	return CreateVillage201JSONResponse(toVillageDTO(v)), nil
}

func (h *handler) UpdateVillage(ctx context.Context, req UpdateVillageRequestObject) (UpdateVillageResponseObject, error) {
	b := req.Body
	v, err := h.svc.UpdateVillage(ctx, req.VillageId, VillageFields{Name: b.Name, NameTe: b.NameTe, LGDCode: b.LgdCode, Lat: b.Lat, Lng: b.Lng})
	if err != nil {
		return nil, err
	}
	return UpdateVillage200JSONResponse(toVillageDTO(v)), nil
}

func (h *handler) ImportVillages(ctx context.Context, req ImportVillagesRequestObject) (ImportVillagesResponseObject, error) {
	if req.Body == nil {
		return nil, apperr.Validation("body", "is required")
	}
	createMissing := req.Params.CreateMissing != nil && *req.Params.CreateMissing
	r, err := h.svc.ImportVillages(ctx, req.Body, createMissing)
	if err != nil {
		return nil, err
	}
	return ImportVillages200JSONResponse{Rows: r.Rows, Created: r.Created, Updated: r.Updated, Unchanged: r.Unchanged,
		DistrictsCreated: r.DistrictsCreated, MandalsCreated: r.MandalsCreated}, nil
}

func toTreeDTO(t Hierarchy) GeoTree {
	out := GeoTree{Districts: make([]TreeDistrict, len(t.Districts))}
	for i, d := range t.Districts {
		ms := make([]TreeMandal, len(d.Mandals))
		for j, m := range d.Mandals {
			ms[j] = TreeMandal{Id: m.ID, Name: m.Name, NameTe: m.NameTe, LgdCode: m.LGDCode, VillageCount: m.VillageCount}
		}
		out.Districts[i] = TreeDistrict{Id: d.ID, Name: d.Name, NameTe: d.NameTe, LgdCode: d.LGDCode, VillageCount: d.VillageCount, Mandals: ms}
	}
	return out
}

func toDistrictDTO(d DistrictInfo) District {
	return District{Id: d.ID, Name: d.Name, NameTe: d.NameTe, LgdCode: d.LGDCode, State: d.State, CreatedAt: d.CreatedAt}
}

func toMandalDTO(m MandalInfo) Mandal {
	return Mandal{Id: m.ID, DistrictId: m.DistrictID, DistrictName: m.DistrictName, DistrictNameTe: m.DistrictNameTe,
		Name: m.Name, NameTe: m.NameTe, LgdCode: m.LGDCode, CreatedAt: m.CreatedAt}
}

func toVillageDTO(v VillageInfo) Village {
	return Village{
		Id: v.ID, Name: v.Name, NameTe: v.NameTe, LgdCode: v.LGDCode, Lat: v.Lat, Lng: v.Lng,
		MandalId: v.MandalID, MandalName: v.MandalName, MandalNameTe: v.MandalNameTe,
		DistrictId: v.DistrictID, DistrictName: v.DistrictName, DistrictNameTe: v.DistrictNameTe, CreatedAt: v.CreatedAt,
	}
}

func toVillageDTOs(vs []VillageInfo) []Village {
	out := make([]Village, len(vs))
	for i, v := range vs {
		out[i] = toVillageDTO(v)
	}
	return out
}
