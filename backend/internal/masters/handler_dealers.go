package masters

import "context"

func (h *handler) ListDealers(ctx context.Context, req ListDealersRequestObject) (ListDealersResponseObject, error) {
	p := req.Params
	page, err := h.svc.ListDealers(ctx, DealerFilter{
		Status: (*string)(p.Status), VillageID: p.VillageId, SKUID: p.SkuId, Q: p.Q,
	}, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	items, next := mapPage(page, toDealerView)
	return ListDealers200JSONResponse(DealerPage{Items: items, NextCursor: next}), nil
}

func (h *handler) CreateDealer(ctx context.Context, req CreateDealerRequestObject) (CreateDealerResponseObject, error) {
	b := req.Body
	in := DealerInput{
		Name: b.Name, NameTe: b.NameTe, Phone: b.Phone, VillageID: b.VillageId,
		Location: fromGeoPoint(b.Location), Status: (*string)(b.Status),
	}
	if b.SkuIds != nil {
		in.SKUIDs = *b.SkuIds
	}
	d, err := h.svc.CreateDealer(ctx, in)
	if err != nil {
		return nil, err
	}
	return CreateDealer201JSONResponse(toDealerView(d)), nil
}

func (h *handler) GetDealer(ctx context.Context, req GetDealerRequestObject) (GetDealerResponseObject, error) {
	d, err := h.svc.GetDealer(ctx, req.DealerId)
	if err != nil {
		return nil, err
	}
	return GetDealer200JSONResponse(toDealerView(d)), nil
}

func (h *handler) UpdateDealer(ctx context.Context, req UpdateDealerRequestObject) (UpdateDealerResponseObject, error) {
	b := req.Body
	d, err := h.svc.UpdateDealer(ctx, req.DealerId, DealerPatch{
		Name: b.Name, NameTe: b.NameTe, Phone: b.Phone, VillageID: b.VillageId,
		Location: fromGeoPoint(b.Location), Status: (*string)(b.Status), SKUIDs: b.SkuIds,
	})
	if err != nil {
		return nil, err
	}
	return UpdateDealer200JSONResponse(toDealerView(d)), nil
}

func fromGeoPoint(p *GeoPoint) *LatLng {
	if p == nil {
		return nil
	}
	return &LatLng{Lat: p.Lat, Lng: p.Lng}
}

func toDealerView(d Dealer) DealerView {
	v := DealerView{
		Id: d.ID, Name: d.Name, NameTe: d.NameTe, Phone: d.Phone, VillageId: d.VillageID,
		VillageName: d.VillageName, MandalName: d.MandalName, Status: DealerStatus(d.Status),
		Source: DealerViewSource(d.Source), SkuIds: d.SKUIDs, CreatedAt: d.CreatedAt, UpdatedAt: d.UpdatedAt,
	}
	if d.Location != nil {
		v.Location = &struct {
			Lat float64 `json:"lat"`
			Lng float64 `json:"lng"`
		}{Lat: d.Location.Lat, Lng: d.Location.Lng}
	}
	return v
}
