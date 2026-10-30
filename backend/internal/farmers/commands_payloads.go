package farmers

import (
	"encoding/json"

	"github.com/google/uuid"
)

// Sync command payloads (CONVENTIONS section 6), decoded by commands.Typed.

// EnrolFarmerPayload is the EnrolFarmer command payload.
type EnrolFarmerPayload struct {
	FarmerID  uuid.UUID `json:"farmer_id"`
	Phone     string    `json:"phone"`
	Name      string    `json:"name"`
	NameTe    *string   `json:"name_te"`
	Language  string    `json:"language"`
	VillageID uuid.UUID `json:"village_id"`
	// PhotoKey is a key from POST /v1/fa/farmers/{farmer_id}/photo/upload-url
	// under this farmer_id. Any other key is dropped (the enrolment is kept).
	PhotoKey *string      `json:"photo_key"`
	Consent  EnrolConsent `json:"consent"`
}

// EnrolConsent is the consent the farmer gave on the FA's phone (FAR-04).
// OTPProof is the token identity's /v1/fa/consent-otp/verify returned once
// the farmer read the OTP out; without a valid one no consent is recorded and
// the farmer stays consent pending (RecordConsent can add it later).
type EnrolConsent struct {
	Purposes      []string `json:"purposes"`
	OTPProof      *string  `json:"otp_proof"`
	AudioPlayed   bool     `json:"audio_played"`
	NoticeVersion string   `json:"notice_version"`
}

// RecordConsentPayload is the RecordConsent command payload: consent captured
// after an enrolment that had no valid proof.
type RecordConsentPayload struct {
	FarmerID      uuid.UUID `json:"farmer_id"`
	Purposes      []string  `json:"purposes"`
	OTPProof      string    `json:"otp_proof"`
	AudioPlayed   bool      `json:"audio_played"`
	NoticeVersion string    `json:"notice_version"`
}

// SavePlotPayload is the SavePlot command payload. boundary_geojson may be a
// GeoJSON object or a string holding one.
type SavePlotPayload struct {
	PlotID          uuid.UUID       `json:"plot_id"`
	FarmerID        uuid.UUID       `json:"farmer_id"`
	Label           string          `json:"label"`
	BoundaryGeoJSON json.RawMessage `json:"boundary_geojson"`
	Pin             *Point          `json:"pin"`
	AreaAcres       float64         `json:"area_acres"`
	AreaSource      string          `json:"area_source"`
	GPSAccuracyM    *float64        `json:"gps_accuracy_m"`
	ExpectedVersion *int32          `json:"expected_version"`
}

// StartSeasonPayload is the StartSeason command payload.
type StartSeasonPayload struct {
	SeasonID       uuid.UUID  `json:"season_id"`
	FarmerID       uuid.UUID  `json:"farmer_id"`
	PlotID         uuid.UUID  `json:"plot_id"`
	SeasonCode     string     `json:"season_code"`
	CropID         uuid.UUID  `json:"crop_id"`
	SowingDate     *string    `json:"sowing_date"` // YYYY-MM-DD
	PreviousCropID *uuid.UUID `json:"previous_crop_id"`
}

// UpdateFarmerPayload is the UpdateFarmer command payload.
type UpdateFarmerPayload struct {
	FarmerID        uuid.UUID          `json:"farmer_id"`
	ExpectedVersion int32              `json:"expected_version"`
	Fields          UpdateFarmerFields `json:"fields"`
}

// UpdateFarmerFields are the fields an FA may change; nil = unchanged.
// PhotoKey must be a key from POST /v1/fa/farmers/{farmer_id}/photo/upload-url
// for this farmer.
type UpdateFarmerFields struct {
	Name      *string    `json:"name"`
	NameTe    *string    `json:"name_te"`
	Language  *string    `json:"language"`
	VillageID *uuid.UUID `json:"village_id"`
	PhotoKey  *string    `json:"photo_key"`
}
