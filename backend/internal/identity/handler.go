package identity

import (
	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// handler implements StrictServerInterface. It only maps between generated
// DTOs and the service; errors from the service are returned unchanged and
// written by httpx.ResponseErrorHandler in the shared error shape.
type handler struct {
	svc *Service
}

var _ StrictServerInterface = (*handler)(nil)

// ---- domain -> DTO ----

func tokensDTO(t Tokens) TokenPair {
	return TokenPair{TokenType: Bearer, AccessToken: t.Access, AccessExpiresAt: t.AccessExpiresAt,
		RefreshToken: t.Refresh, RefreshExpiresAt: t.RefreshExpiresAt}
}

func faDTO(f FA) FieldAssistant {
	return FieldAssistant{
		Id: f.ID, Code: f.Code, Name: f.Name, NameTe: f.NameTe, Phone: f.Phone, Level: FALevel(f.Level),
		Languages: f.Languages, WorkingHours: f.WorkingHours, PhotoKey: f.PhotoKey, Status: FAStatus(f.Status),
		MustChangePassword: f.MustChangePassword, LastLoginAt: f.LastLoginAt, LastSyncAt: f.LastSyncAt,
		AppVersion: f.AppVersion, CreatedAt: f.CreatedAt, UpdatedAt: f.UpdatedAt,
	}
}

func faPageDTO(p paging.Page[FA]) FieldAssistantPage {
	items := make([]FieldAssistant, len(p.Items))
	for i, f := range p.Items {
		items[i] = faDTO(f)
	}
	return FieldAssistantPage{Items: items, NextCursor: p.NextCursor}
}

func hoDTO(u HOAccount) HOUser {
	districts := u.DistrictIDs
	if districts == nil {
		districts = []uuid.UUID{}
	}
	return HOUser{
		Id: u.ID, Email: u.Email, Name: u.Name, Role: HORole(u.Role), DistrictIds: districts, Status: HOStatus(u.Status),
		TotpEnabled: u.TOTPEnabled, MustChangePassword: u.MustChangePassword, LastLoginAt: u.LastLoginAt,
		CreatedAt: u.CreatedAt, UpdatedAt: u.UpdatedAt,
	}
}

func hoPageDTO(p paging.Page[HOAccount]) HOUserPage {
	items := make([]HOUser, len(p.Items))
	for i, u := range p.Items {
		items[i] = hoDTO(u)
	}
	return HOUserPage{Items: items, NextCursor: p.NextCursor}
}

func hoSessionDTO(l HOSignIn) HOSession {
	return HOSession{Tokens: tokensDTO(l.Tokens), User: hoDTO(l.User), MustChangePassword: l.User.MustChangePassword}
}

func deviceDTO(d DeviceRecord) Device {
	return Device{
		Id: d.ID, SubjectKind: DeviceSubjectKind(d.SubjectKind), SubjectId: d.SubjectID, Model: d.Model,
		OsVersion: d.OSVersion, AppVersion: d.AppVersion, HasPushToken: d.HasPushToken, RevokedAt: d.RevokedAt,
		RevokeReason: d.RevokeReason, LastSeenAt: d.LastSeenAt, LastSyncAt: d.LastSyncAt, CreatedAt: d.CreatedAt,
	}
}

func appDevice(d DeviceInfo) AppDevice {
	return AppDevice{Key: d.DeviceKey, Model: d.Model, OSVersion: d.OsVersion, AppVersion: d.AppVersion, PushToken: d.PushToken}
}

func heartbeat(b *DeviceUpdate) DeviceHeartbeat {
	if b == nil {
		return DeviceHeartbeat{}
	}
	return DeviceHeartbeat{Model: b.Model, OSVersion: b.OsVersion, AppVersion: b.AppVersion, PushToken: b.PushToken}
}

func heartbeatDTO(r HeartbeatResult) DeviceStatus {
	return DeviceStatus{DeviceId: r.DeviceID, Wipe: r.Wipe, ServerTime: r.ServerTime,
		MinVersion: r.MinVersion, UpdateRequired: r.UpdateRequired}
}

func strPtr[T ~string](v *T) *string {
	if v == nil {
		return nil
	}
	s := string(*v)
	return &s
}
