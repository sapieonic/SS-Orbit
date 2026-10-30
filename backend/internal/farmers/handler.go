package farmers

import (
	"encoding/json"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/sapionic/orbit/backend/internal/xmod"
)

// handler implements StrictServerInterface. It only maps between generated
// DTOs and the service; service errors are returned unchanged and written by
// httpx.ResponseErrorHandler in the shared error shape.
type handler struct {
	svc *Service
}

var _ StrictServerInterface = (*handler)(nil)

func farmerDTO(f FarmerRecord) Farmer {
	return Farmer{
		Id:                 f.ID,
		Phone:              f.Phone,
		Name:               f.Name,
		NameTe:             f.NameTe,
		Language:           Language(f.Language),
		VillageId:          f.VillageID,
		MandalId:           f.MandalID,
		DistrictId:         f.DistrictID,
		AssignedFaId:       f.AssignedFAID,
		Source:             FarmerSource(f.Source),
		EnrolledByFaId:     f.EnrolledByFAID,
		PhotoKey:           f.PhotoKey,
		Plan:               Plan(f.Plan),
		Status:             FarmerStatus(f.Status),
		ProfileCompletedAt: f.ProfileCompletedAt,
		Version:            f.Version,
		CreatedAt:          f.CreatedAt,
		UpdatedAt:          f.UpdatedAt,
	}
}

func plotDTO(p PlotRecord) Plot {
	out := Plot{
		Id:           p.ID,
		FarmerId:     p.FarmerID,
		Label:        p.Label,
		VillageId:    p.VillageID,
		AreaAcres:    p.AreaAcres,
		AreaSource:   PlotAreaSource(p.AreaSource),
		GpsAccuracyM: p.GPSAccuracyM,
		Status:       PlotStatus(p.Status),
		Version:      p.Version,
		CreatedAt:    p.CreatedAt,
		UpdatedAt:    p.UpdatedAt,
	}
	if p.Boundary != nil {
		var m map[string]any
		if err := json.Unmarshal(p.Boundary, &m); err == nil {
			out.Boundary = &m
		}
	}
	if p.Pin != nil {
		out.Pin = &LatLng{Lat: p.Pin.Lat, Lng: p.Pin.Lng}
	}
	return out
}

func seasonDTO(s SeasonRecord) Season {
	return Season{
		Id:             s.ID,
		FarmerId:       s.FarmerID,
		PlotId:         s.PlotID,
		SeasonCode:     s.SeasonCode,
		CropId:         s.CropID,
		SowingDate:     datePtr(s.SowingDate),
		PreviousCropId: s.PreviousCropID,
		Status:         SeasonStatus(s.Status),
		Version:        s.Version,
		CreatedAt:      s.CreatedAt,
		UpdatedAt:      s.UpdatedAt,
	}
}

func seasonsDTO(in []SeasonRecord) []Season {
	out := make([]Season, len(in))
	for i, s := range in {
		out[i] = seasonDTO(s)
	}
	return out
}

func villageDTO(v *xmod.Village) *FarmerVillage {
	if v == nil {
		return nil
	}
	return &FarmerVillage{
		Id: v.ID, Name: v.Name, NameTe: v.NameTe,
		MandalId: v.MandalID, MandalName: v.MandalName, MandalNameTe: v.MandalNameTe,
		DistrictId: v.DistrictID, DistrictName: v.DistrictName, DistrictNameTe: v.DistrictNameTe,
	}
}

func faCardDTO(fa *xmod.FieldAssistant) *FarmerFACard {
	if fa == nil {
		return nil
	}
	langs := fa.Languages
	if langs == nil {
		langs = []string{}
	}
	return &FarmerFACard{
		Id: fa.ID, Code: fa.Code, Name: fa.Name, NameTe: fa.NameTe, Phone: fa.Phone,
		Level: FarmerFACardLevel(fa.Level), Languages: langs, WorkingHours: fa.WorkingHours,
		PhotoKey: fa.PhotoKey, Status: FarmerFACardStatus(fa.Status),
	}
}

func faRefDTO(fa *xmod.FieldAssistant) *FarmerFARef {
	if fa == nil {
		return nil
	}
	return &FarmerFARef{Id: fa.ID, Code: fa.Code, Name: fa.Name, NameTe: fa.NameTe}
}

func photoUploadDTO(t PhotoUploadTarget) FarmerPhotoUpload {
	headers := t.Headers
	if headers == nil {
		headers = map[string]string{}
	}
	return FarmerPhotoUpload{StorageKey: t.StorageKey, Url: t.URL, Method: t.Method, Headers: headers, ExpiresAt: t.ExpiresAt}
}

func consentStatesDTO(in []ConsentState) []CurrentConsent {
	out := make([]CurrentConsent, len(in))
	for i, c := range in {
		out[i] = CurrentConsent{
			Purpose:       ConsentPurpose(c.Purpose),
			Granted:       c.Granted,
			NoticeVersion: c.NoticeVersion,
			UpdatedAt:     c.UpdatedAt,
		}
		if c.Method != nil {
			m := CurrentConsentMethod(*c.Method)
			out[i].Method = &m
		}
	}
	return out
}

func consentDTO(c ConsentRecord) Consent {
	return Consent{
		Id:             c.ID,
		Purpose:        ConsentPurpose(c.Purpose),
		Granted:        c.Granted,
		Method:         ConsentMethod(c.Method),
		CapturedByFaId: c.CapturedByFAID,
		NoticeVersion:  c.NoticeVersion,
		Language:       Language(c.Language),
		AudioPlayed:    c.AudioPlayed,
		CreatedAt:      c.CreatedAt,
	}
}

func datePtr(t *time.Time) *openapi_types.Date {
	if t == nil {
		return nil
	}
	return &openapi_types.Date{Time: *t}
}

func dateTime(d *openapi_types.Date) *time.Time {
	if d == nil {
		return nil
	}
	t := time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, time.UTC)
	return &t
}

func strPtr[T ~string](v *T) *string {
	if v == nil {
		return nil
	}
	s := string(*v)
	return &s
}
