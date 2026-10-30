package masters

import (
	"context"
	"math"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"
)

// Farmer surface. The farmer app never sees doses or chemical names outside
// FA advice, so there is deliberately no farmer endpoint for rules or salts.

func (h *handler) ListFarmerCrops(ctx context.Context, _ ListFarmerCropsRequestObject) (ListFarmerCropsResponseObject, error) {
	fc, err := h.svc.FarmerCrops(ctx)
	if err != nil {
		return nil, err
	}
	sc := fc.SeasonCodes
	until, _ := time.Parse(time.DateOnly, sc.ValidUntil) // always well-formed: built by SeasonCodesAt
	return ListFarmerCrops200JSONResponse(FarmerCropList{
		Version: fc.Version, Items: mapSlice(fc.Crops, toFarmerCrop),
		SeasonCodes: SeasonCodes{Current: sc.Current, Next: sc.Next, AllOpen: sc.AllOpen, ValidUntil: openapi_types.Date{Time: until}},
	}), nil
}

func (h *handler) ListNearbyDealers(ctx context.Context, req ListNearbyDealersRequestObject) (ListNearbyDealersResponseObject, error) {
	p := req.Params
	dealers, err := h.svc.NearbyDealers(ctx, NearbyQuery{Lat: p.Lat, Lng: p.Lng, RadiusKM: p.RadiusKm, SKUID: p.SkuId, Limit: p.Limit})
	if err != nil {
		return nil, err
	}
	return ListNearbyDealers200JSONResponse(NearbyDealerList{Items: mapSlice(dealers, toNearbyDealerView)}), nil
}

func toFarmerCrop(c Crop) FarmerCrop {
	return FarmerCrop{
		Id: c.ID, Code: c.Code, Name: c.Name, NameTe: c.NameTe, DurationDays: c.DurationDays,
		Stages: mapSlice(c.Stages, func(s Stage) FarmerStage {
			return FarmerStage{Id: s.ID, Code: s.Code, Name: s.Name, NameTe: s.NameTe, Seq: s.Seq, StartDay: s.StartDay, EndDay: s.EndDay}
		}),
	}
}

func toNearbyDealerView(d NearbyDealer) NearbyDealerView {
	return NearbyDealerView{
		Id: d.ID, Name: d.Name, NameTe: d.NameTe, Phone: d.Phone,
		Location: GeoPoint{Lat: d.Location.Lat, Lng: d.Location.Lng}, DistanceM: int32(math.Round(d.DistanceM)),
	}
}
