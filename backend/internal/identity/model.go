package identity

import (
	"time"

	"github.com/google/uuid"
)

// Subject kinds stored in devices.subject_kind and sessions.subject_kind.
const (
	SubjectFarmer = "farmer"
	SubjectFA     = "fa"
	SubjectHO     = "ho"
)

// FA statuses.
const (
	FAActive   = "active"
	FALeaving  = "leaving"
	FAInactive = "inactive"
)

// HO user statuses.
const (
	HOInvited  = "invited"
	HOActive   = "active"
	HODisabled = "disabled"
)

// AppDevice describes the app install signing in. Key is the install ID the
// app generates once; nil details are left unchanged on an existing device.
type AppDevice struct {
	Key        string
	Model      *string
	OSVersion  *string
	AppVersion *string
	PushToken  *string
}

// DeviceHeartbeat is a heartbeat from the app. Nil fields keep the stored value.
type DeviceHeartbeat struct {
	Model      *string
	OSVersion  *string
	AppVersion *string
	PushToken  *string
}

// Tokens is an access + refresh token pair.
type Tokens struct {
	Access           string
	AccessExpiresAt  time.Time
	Refresh          string
	RefreshExpiresAt time.Time
}

// OTPSent is the reply to an OTP request.
type OTPSent struct {
	PhoneMasked string
	ExpiresIn   time.Duration
	ResendAfter time.Duration
}

// FarmerLogin is the result of a successful OTP sign-in.
type FarmerLogin struct {
	Tokens   Tokens
	FarmerID uuid.UUID
	DeviceID uuid.UUID
	IsNew    bool
	// FarmerStatus is a routing hint (pending_profile | active | inactive);
	// nil when it could not be read.
	FarmerStatus *string
}

// OfflineRules tells the FA app how long it may work offline on its PIN.
type OfflineRules struct {
	PinLength        int
	OfflineGraceDays int
	PinMaxAttempts   int
}

// faOfflinePolicy is fixed for now (wireframe: 4-digit PIN, 7 days offline).
var faOfflinePolicy = OfflineRules{PinLength: 4, OfflineGraceDays: 7, PinMaxAttempts: 5}

// FA is an FA as HO and the FA app see it. No secrets.
type FA struct {
	ID                 uuid.UUID
	Code               string
	Name               string
	NameTe             *string
	Phone              string
	Level              string
	Languages          []string
	WorkingHours       *string
	PhotoKey           *string
	Status             string
	MustChangePassword bool
	LastLoginAt        *time.Time
	LastSyncAt         *time.Time
	AppVersion         *string // lists only
	CreatedAt          time.Time
	UpdatedAt          time.Time
}

// FASignIn is the result of a successful FA sign-in.
type FASignIn struct {
	Tokens       Tokens
	DeviceID     uuid.UUID
	FA           FA
	OfflineRules OfflineRules
}

// FACreate is the input for issuing an FA login. Exactly one of Code and
// AreaCode is set.
type FACreate struct {
	Code         *string
	AreaCode     *string
	Name         string
	NameTe       *string
	Phone        string
	Level        string
	Languages    []string
	WorkingHours *string
	PhotoKey     *string
}

// FAPatch changes an FA's profile. Nil fields are unchanged; for NameTe,
// WorkingHours and PhotoKey an empty string clears the value.
type FAPatch struct {
	Name         *string
	NameTe       *string
	Phone        *string
	Level        *string
	Languages    *[]string
	WorkingHours *string
	PhotoKey     *string
}

// FACounts are the FA numbers on the HO overview (ADM-01).
type FACounts struct {
	Active        int
	Leaving       int
	Inactive      int
	SyncedLast24h int // FAs (any status) whose last sync was in the last 24 hours
}

// FAFilter narrows the FA list.
type FAFilter struct {
	Q      *string
	Status *string
	// NotSyncedSince keeps FAs whose last sync is before it, or who never synced.
	NotSyncedSince *time.Time
}

// HOAccount is an HO portal user. No secrets.
type HOAccount struct {
	ID                 uuid.UUID
	Email              string
	Name               string
	Role               string
	DistrictIDs        []uuid.UUID
	Status             string
	TOTPEnabled        bool
	MustChangePassword bool
	LastLoginAt        *time.Time
	CreatedAt          time.Time
	UpdatedAt          time.Time
}

// HOSignIn is the result of a successful HO sign-in.
type HOSignIn struct {
	Tokens Tokens
	User   HOAccount
}

// TOTPEnrolment is a pending TOTP secret for the authenticator app.
type TOTPEnrolment struct {
	URL    string
	Secret string
}

// NewHOAccount is the input for inviting an HO user.
type NewHOAccount struct {
	Email       string
	Name        string
	Role        string
	DistrictIDs []uuid.UUID
}

// HOAccountPatch changes an HO user. Nil fields are unchanged.
type HOAccountPatch struct {
	Name        *string
	Role        *string
	DistrictIDs *[]uuid.UUID
}

// HOFilter narrows the HO user list.
type HOFilter struct {
	Q      *string
	Role   *string
	Status *string
}

// DeviceRecord is a registered app install.
type DeviceRecord struct {
	ID           uuid.UUID
	SubjectKind  string
	SubjectID    uuid.UUID
	Model        *string
	OSVersion    *string
	AppVersion   *string
	HasPushToken bool
	RevokedAt    *time.Time
	RevokeReason *string
	LastSeenAt   *time.Time
	LastSyncAt   *time.Time
	CreatedAt    time.Time
}

// HeartbeatResult is the heartbeat reply. Wipe tells the app to delete local
// data and sign out.
type HeartbeatResult struct {
	DeviceID   uuid.UUID
	Wipe       bool
	ServerTime time.Time
	// MinVersion is the oldest allowed app version; UpdateRequired is true
	// when the app_version sent is below it.
	MinVersion     string
	UpdateRequired bool
}

// HODirectoryEntry is an HO user's display fields (no email, no scope).
type HODirectoryEntry struct {
	ID     uuid.UUID
	Name   string
	Role   string
	Status string
}
