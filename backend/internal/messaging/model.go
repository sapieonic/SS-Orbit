package messaging

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/storage"
)

// Advisory statuses.
const (
	StatusDraft           = "draft"
	StatusPendingApproval = "pending_approval"
	StatusScheduled       = "scheduled"
	StatusSending         = "sending"
	StatusSent            = "sent"
	StatusCancelled       = "cancelled"
)

// Channels. in_app is implicit: every recipient gets a notice.
const (
	ChannelPush     = "push"
	ChannelSMS      = "sms"
	ChannelWhatsApp = "whatsapp"
	ChannelInApp    = "in_app"
)

// Message classes decide which SMS/WhatsApp templates may be used and who may
// receive the message.
const (
	ClassService     = "service"
	ClassPromotional = "promotional"
)

// Target selects advisory recipients. Empty lists mean "any". It is stored
// as JSON in advisories.target.
type Target struct {
	CropIDs     []uuid.UUID `json:"crop_ids"`
	DistrictIDs []uuid.UUID `json:"district_ids"`
	MandalIDs   []uuid.UUID `json:"mandal_ids"`
	VillageIDs  []uuid.UUID `json:"village_ids"`
	StageCodes  []string    `json:"stage_codes"`
	Plan        *string     `json:"plan"`
}

// AdvisoryInput is what HO submits to create a draft.
type AdvisoryInput struct {
	Sender           string // ho | civ
	TitleTe, BodyTe  string
	TitleEn, BodyEn  *string
	NamesProduct     bool
	Class            *string // nil = derived from NamesProduct
	Target           Target
	Channels         []string
	AudioContentType *string
	ImageContentType *string
}

// AdvisoryPatch edits a draft advisory. Nil fields are unchanged; TitleEn or
// BodyEn "" removes the English text.
type AdvisoryPatch struct {
	Sender           *string
	TitleTe, BodyTe  *string
	TitleEn, BodyEn  *string
	NamesProduct     *bool
	Class            *string // nil = keep, or derive again when NamesProduct changes
	Target           *Target
	Channels         *[]string
	AudioContentType *string
	ImageContentType *string
	RemoveAudio      bool
	RemoveImage      bool
}

// AdvisoryRecord is an HO/CIV message to a targeted set of farmers.
type AdvisoryRecord struct {
	ID             uuid.UUID
	Sender         string
	TitleTe        string
	BodyTe         string
	TitleEn        *string
	BodyEn         *string
	AudioKey       *string
	ImageKey       *string
	AudioURL       *string
	ImageURL       *string
	NamesProduct   bool
	Class          string
	Target         Target
	Channels       []string
	Status         string
	ScheduledFor   *time.Time
	SentAt         *time.Time
	RecipientCount *int
	CreatedBy      uuid.UUID
	UpdatedBy      *uuid.UUID // last editor of the draft
	ApprovedBy     *uuid.UUID
	ApprovedAt     *time.Time
	ReviewNote     *string
	CreatedAt      time.Time
	UpdatedAt      time.Time
	Stats          *Reach // only on Get
}

// Reach is the reach of an advisory so far.
type Reach struct {
	Notices    int
	Read       int
	Listened   int
	Deliveries map[string]int // "<channel>.<status>" -> count
}

// NewAdvisory is a new draft plus upload instructions for its media.
type NewAdvisory struct {
	Advisory    AdvisoryRecord
	AudioUpload *storage.Presigned
	ImageUpload *storage.Presigned
}

// RecipientStatus is one farmer who got an advisory.
type RecipientStatus struct {
	NoticeID uuid.UUID
	FarmerID uuid.UUID
	// Display details from the farmers module; nil if the lookup failed.
	FarmerName   *string
	FarmerNameTe *string
	PhoneMasked  *string
	CreatedAt    time.Time
	ReadAt       *time.Time
	ListenedAt   *time.Time
	Deliveries   []ChannelDelivery
}

// ChannelDelivery is one channel's delivery for a recipient.
type ChannelDelivery struct {
	Channel  string     `json:"channel"`
	Status   string     `json:"status"`
	Error    *string    `json:"error"`
	SentAt   *time.Time `json:"sent_at"`
	Attempts int        `json:"attempts"`
}

// InboxNotice is one item in a farmer's inbox.
type InboxNotice struct {
	ID         uuid.UUID
	FarmerID   uuid.UUID
	Kind       string // advisory | visit_advice | system
	Sender     string // ho | civ | fa | system
	TitleTe    string
	BodyTe     string
	TitleEn    *string
	BodyEn     *string
	AudioURL   *string
	RefType    *string
	RefID      *uuid.UUID
	Pinned     bool
	ReadAt     *time.Time
	ListenedAt *time.Time
	CreatedAt  time.Time
}

// FieldAlert is one card in the FA app's Alerts tab. The JSON form is the
// offline snapshot's "alerts" section.
type FieldAlert struct {
	ID             uuid.UUID  `json:"id"`
	FAID           uuid.UUID  `json:"fa_id"`
	Kind           string     `json:"kind"` // new_farmer | callback | invoice_check | ho_note
	FarmerID       *uuid.UUID `json:"farmer_id"`
	RefID          *uuid.UUID `json:"ref_id"`
	Title          string     `json:"title"` // English
	Body           *string    `json:"body"`
	TitleTe        *string    `json:"title_te"` // Telugu; nil for older alerts and English-only notes
	BodyTe         *string    `json:"body_te"`
	Status         string     `json:"status"` // open | acknowledged | closed
	CreatedAt      time.Time  `json:"created_at"`
	AcknowledgedAt *time.Time `json:"acknowledged_at"`
	// Filled for the HTTP list only (the snapshot has the farmers section).
	FarmerName  *string `json:"-"`
	FarmerPhone *string `json:"-"`
}

// HONote is an HO note to an FA.
type HONote struct {
	FAID            uuid.UUID
	Title           string
	Body            *string
	TitleTe, BodyTe *string // optional Telugu text
	FarmerID        *uuid.UUID
}

// OverviewAlert is one item on the HO overview.
type OverviewAlert struct {
	ID         uuid.UUID
	Kind       string // new_farmer | farmer_without_fa | fa_offline
	FarmerID   *uuid.UUID
	FAID       *uuid.UUID
	DistrictID *uuid.UUID
	Payload    json.RawMessage
	CreatedAt  time.Time
}
