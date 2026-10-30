package farmers

import (
	"context"

	"github.com/sapionic/orbit/backend/internal/platform/phone"
)

// HO portal handlers (/v1/admin/...).

func (h *handler) ListFarmers(ctx context.Context, req ListFarmersRequestObject) (ListFarmersResponseObject, error) {
	p := req.Params
	f := ListFilter{
		DistrictID: p.DistrictId, MandalID: p.MandalId, VillageID: p.VillageId, FAID: p.FaId,
		CropID: p.CropId, Status: strPtr(p.Status), Plan: strPtr(p.Plan), Q: p.Q,
	}
	if p.Unassigned != nil {
		f.Unassigned = *p.Unassigned
	}
	page, err := h.svc.List(ctx, f, p.Limit, p.Cursor)
	if err != nil {
		return nil, err
	}
	items := make([]AdminFarmerListItem, len(page.Items))
	for i, it := range page.Items {
		items[i] = AdminFarmerListItem{
			Id:               it.Farmer.ID,
			Name:             it.Farmer.Name,
			NameTe:           it.Farmer.NameTe,
			PhoneMasked:      phone.Mask(it.Farmer.Phone),
			Language:         Language(it.Farmer.Language),
			Source:           AdminFarmerListItemSource(it.Farmer.Source),
			Plan:             Plan(it.Farmer.Plan),
			Status:           FarmerStatus(it.Farmer.Status),
			Village:          villageDTO(it.Village),
			AssignedFa:       faRefDTO(it.FA),
			ActiveCropIds:    it.ActiveCropIDs,
			TotalAreaAcres:   it.TotalAreaAcres,
			PlotCount:        it.PlotCount,
			ProgrammeConsent: it.ProgrammeConsent,
			ConsentPending:   it.ConsentPending,
			ConsentsGranted:  it.ConsentsGranted,
			CreatedAt:        it.Farmer.CreatedAt,
		}
	}
	return ListFarmers200JSONResponse(AdminFarmerPage{Items: items, NextCursor: page.NextCursor}), nil
}

func (h *handler) GetFarmer360(ctx context.Context, req GetFarmer360RequestObject) (GetFarmer360ResponseObject, error) {
	v, err := h.svc.Get360(ctx, req.FarmerId)
	if err != nil {
		return nil, err
	}
	out := Farmer360{
		Farmer:         farmerDTO(v.Farmer),
		PhotoUrl:       v.PhotoURL,
		Village:        villageDTO(v.Village),
		AssignedFa:     faCardDTO(v.AssignedFA),
		EnrolledByFa:   faRefDTO(v.EnrolledByFA),
		Consents:       consentStatesDTO(v.Consents),
		ConsentPending: v.ConsentPending,
		ConsentHistory: make([]Consent, len(v.ConsentHistory)),
		Plots:          make([]Plot360, len(v.Plots)),
	}
	for i, c := range v.ConsentHistory {
		out.ConsentHistory[i] = consentDTO(c)
	}
	for i, p := range v.Plots {
		out.Plots[i] = Plot360{Plot: plotDTO(p.Plot), Seasons: seasonsDTO(p.Seasons)}
	}
	return GetFarmer360200JSONResponse(out), nil
}

func (h *handler) UpdateFarmer(ctx context.Context, req UpdateFarmerRequestObject) (UpdateFarmerResponseObject, error) {
	b := req.Body
	f, err := h.svc.AdminUpdateFarmer(ctx, req.FarmerId, AdminUpdate{
		ExpectedVersion: b.ExpectedVersion, Name: b.Name, NameTe: b.NameTe, Language: strPtr(b.Language),
		VillageID: b.VillageId, Phone: b.Phone, Plan: strPtr(b.Plan), Reason: b.Reason,
	})
	if err != nil {
		return nil, err
	}
	return UpdateFarmer200JSONResponse(farmerDTO(f)), nil
}

func (h *handler) DeactivateFarmer(ctx context.Context, req DeactivateFarmerRequestObject) (DeactivateFarmerResponseObject, error) {
	var reason *string
	if req.Body != nil {
		reason = req.Body.Reason
	}
	f, err := h.svc.Deactivate(ctx, req.FarmerId, reason)
	if err != nil {
		return nil, err
	}
	return DeactivateFarmer200JSONResponse(farmerDTO(f)), nil
}

func (h *handler) ReactivateFarmer(ctx context.Context, req ReactivateFarmerRequestObject) (ReactivateFarmerResponseObject, error) {
	var reason *string
	if req.Body != nil {
		reason = req.Body.Reason
	}
	f, err := h.svc.Reactivate(ctx, req.FarmerId, reason)
	if err != nil {
		return nil, err
	}
	return ReactivateFarmer200JSONResponse(farmerDTO(f)), nil
}

func (h *handler) ReassignFarmers(ctx context.Context, req ReassignFarmersRequestObject) (ReassignFarmersResponseObject, error) {
	b := req.Body
	in := ReassignInput{ToFAID: b.ToFaId, FromFAID: b.FromFaId}
	if b.FarmerIds != nil {
		in.FarmerIDs = *b.FarmerIds
	}
	if b.VillageIds != nil {
		in.VillageIDs = *b.VillageIds
	}
	moved, err := h.svc.Reassign(ctx, in)
	if err != nil {
		return nil, err
	}
	return ReassignFarmers200JSONResponse(ReassignResult{Moved: len(moved), FarmerIds: moved}), nil
}

func (h *handler) RolloverSeason(ctx context.Context, req RolloverSeasonRequestObject) (RolloverSeasonResponseObject, error) {
	outcome := SeasonHarvested
	if req.Body.Outcome != nil {
		outcome = string(*req.Body.Outcome)
	}
	n, err := h.svc.Rollover(ctx, req.Body.SeasonCode, outcome)
	if err != nil {
		return nil, err
	}
	return RolloverSeason200JSONResponse(RolloverResult{Closed: n}), nil
}

func (h *handler) GetFarmerStats(ctx context.Context, req GetFarmerStatsRequestObject) (GetFarmerStatsResponseObject, error) {
	st, err := h.svc.Stats(ctx, req.Params.DistrictId)
	if err != nil {
		return nil, err
	}
	return GetFarmerStats200JSONResponse(FarmerStats{
		Total: st.Total, Active: st.Active, PendingProfile: st.PendingProfile, Inactive: st.Inactive,
		Premium: st.Premium, ConsentPending: st.ConsentPending, NewLast7Days: st.NewLast7Days,
		Unassigned: st.Unassigned,
	}), nil
}

// FA app (/v1/fa/...).

func (h *handler) LookupFarmerPhone(ctx context.Context, req LookupFarmerPhoneRequestObject) (LookupFarmerPhoneResponseObject, error) {
	res, err := h.svc.LookupPhone(ctx, req.Params.Phone)
	if err != nil {
		return nil, err
	}
	return LookupFarmerPhone200JSONResponse(PhoneLookup{Status: PhoneLookupStatus(res.Status), FarmerId: res.FarmerID}), nil
}

func (h *handler) CreateFarmerPhotoUpload(ctx context.Context, req CreateFarmerPhotoUploadRequestObject) (CreateFarmerPhotoUploadResponseObject, error) {
	t, err := h.svc.PresignFarmerPhotoForFA(ctx, req.FarmerId, string(req.Body.ContentType), req.Body.Bytes)
	if err != nil {
		return nil, err
	}
	return CreateFarmerPhotoUpload200JSONResponse(photoUploadDTO(t)), nil
}
