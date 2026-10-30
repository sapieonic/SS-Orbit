package farmers

import (
	"context"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Farmer app handlers (/v1/farmer/me...).

func (h *handler) GetMyHome(ctx context.Context, _ GetMyHomeRequestObject) (GetMyHomeResponseObject, error) {
	home, err := h.svc.Home(ctx)
	if err != nil {
		return nil, err
	}
	out := FarmerHome{
		Farmer:    farmerDTO(home.Farmer),
		PhotoUrl:  home.PhotoURL,
		Village:   villageDTO(home.Village),
		Plots:     make([]HomePlot, len(home.Plots)),
		Fa:        faCardDTO(home.FA),
		NextVisit: plannedVisitDTO(home.NextVisit),
	}
	for i, p := range home.Plots {
		hp := HomePlot{Plot: plotDTO(p.Plot), DaysAfterSowing: p.DaysAfterSowing}
		if p.ActiveSeason != nil {
			se := seasonDTO(*p.ActiveSeason)
			hp.ActiveSeason = &se
		}
		if p.Stage != nil {
			hp.CurrentStage = &Stage{
				Id: p.Stage.ID, Code: p.Stage.Code, Name: p.Stage.Name, NameTe: p.Stage.NameTe,
				Seq: p.Stage.Seq, StartDay: p.Stage.StartDay, EndDay: p.Stage.EndDay,
			}
		}
		out.Plots[i] = hp
	}
	return GetMyHome200JSONResponse(out), nil
}

func (h *handler) UpdateMyProfile(ctx context.Context, req UpdateMyProfileRequestObject) (UpdateMyProfileResponseObject, error) {
	b := req.Body
	f, err := h.svc.UpdateMyProfile(ctx, ProfileInput{Name: b.Name, NameTe: b.NameTe, Language: strPtr(b.Language), PhotoKey: b.PhotoKey})
	if err != nil {
		return nil, err
	}
	return UpdateMyProfile200JSONResponse(farmerDTO(f)), nil
}

func (h *handler) CompleteMyProfile(ctx context.Context, req CompleteMyProfileRequestObject) (CompleteMyProfileResponseObject, error) {
	b := req.Body
	lang := string(b.Language)
	f, err := h.svc.CompleteProfile(ctx, ProfileInput{Name: &b.Name, NameTe: b.NameTe, Language: &lang, VillageID: &b.VillageId})
	if err != nil {
		return nil, err
	}
	return CompleteMyProfile200JSONResponse(farmerDTO(f)), nil
}

func (h *handler) ListMyConsents(ctx context.Context, _ ListMyConsentsRequestObject) (ListMyConsentsResponseObject, error) {
	cs, err := h.svc.MyConsents(ctx)
	if err != nil {
		return nil, err
	}
	return ListMyConsents200JSONResponse(CurrentConsentList{Items: consentStatesDTO(cs)}), nil
}

func (h *handler) SetMyConsent(ctx context.Context, req SetMyConsentRequestObject) (SetMyConsentResponseObject, error) {
	b := req.Body
	in := ConsentInput{Purpose: string(b.Purpose), Granted: b.Granted, NoticeVersion: b.NoticeVersion}
	if b.AudioPlayed != nil {
		in.AudioPlayed = *b.AudioPlayed
	}
	cs, err := h.svc.SetMyConsent(ctx, in)
	if err != nil {
		return nil, err
	}
	return SetMyConsent200JSONResponse(CurrentConsentList{Items: consentStatesDTO(cs)}), nil
}

func (h *handler) CreateMyPhotoUpload(ctx context.Context, req CreateMyPhotoUploadRequestObject) (CreateMyPhotoUploadResponseObject, error) {
	t, err := h.svc.PresignMyPhoto(ctx, string(req.Body.ContentType), req.Body.Bytes)
	if err != nil {
		return nil, err
	}
	return CreateMyPhotoUpload200JSONResponse(photoUploadDTO(t)), nil
}

func (h *handler) AddMyPlot(ctx context.Context, req AddMyPlotRequestObject) (AddMyPlotResponseObject, error) {
	b := req.Body
	p, err := h.svc.AddMyPlot(ctx, NewPlotInput{Label: b.Label, Pin: Point{Lat: b.Pin.Lat, Lng: b.Pin.Lng}, AreaAcres: b.AreaAcres})
	if err != nil {
		return nil, err
	}
	return AddMyPlot201JSONResponse(plotDTO(p)), nil
}

func (h *handler) StartMySeason(ctx context.Context, req StartMySeasonRequestObject) (StartMySeasonResponseObject, error) {
	b := req.Body
	se, err := h.svc.StartMySeason(ctx, req.PlotId, NewSeasonInput{
		SeasonCode: b.SeasonCode, CropID: b.CropId, SowingDate: dateTime(b.SowingDate), PreviousCropID: b.PreviousCropId,
	})
	if err != nil {
		return nil, err
	}
	return StartMySeason201JSONResponse(seasonDTO(se)), nil
}

func (h *handler) CloseMySeason(ctx context.Context, req CloseMySeasonRequestObject) (CloseMySeasonResponseObject, error) {
	se, err := h.svc.CloseMySeason(ctx, req.SeasonId, string(req.Body.Outcome))
	if err != nil {
		return nil, err
	}
	return CloseMySeason200JSONResponse(seasonDTO(se)), nil
}

func plannedVisitDTO(v *xmod.PlannedVisit) *PlannedVisit {
	if v == nil {
		return nil
	}
	return &PlannedVisit{
		VisitId: v.VisitID, FaId: v.FAID, PlotId: v.PlotID, SeasonId: v.SeasonID,
		PlannedFor: *datePtr(&v.PlannedFor), PlannedSlot: PlannedVisitPlannedSlot(v.PlannedSlot), Purpose: v.Purpose,
	}
}

func (h *handler) ListMyFAs(ctx context.Context, req ListMyFAsRequestObject) (ListMyFAsResponseObject, error) {
	fas, err := h.svc.MyFAs(ctx, strPtr(req.Params.Level))
	if err != nil {
		return nil, err
	}
	out := FAOptionList{Items: make([]FAOption, len(fas))}
	for i, o := range fas {
		out.Items[i] = FAOption{
			Fa: *faCardDTO(&o.FA), CoverageLevel: FAOptionCoverageLevel(o.CoverageLevel), IsLead: o.IsLead, IsMyFa: o.IsMyFA,
		}
	}
	return ListMyFAs200JSONResponse(out), nil
}
