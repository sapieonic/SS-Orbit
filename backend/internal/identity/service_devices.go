package identity

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/paging"
)

// registerDevice upserts the signing-in device for a subject. A revoked device
// stays revoked: the app must wipe itself and come back with a new install ID.
func (s *Service) registerDevice(ctx context.Context, q *store.Queries, kind string, subjectID uuid.UUID, d AppDevice) (store.Device, error) {
	key := strings.TrimSpace(d.Key)
	if key == "" {
		return store.Device{}, apperr.Validation("device.device_key", "is required")
	}
	dev, err := q.UpsertDevice(ctx, store.UpsertDeviceParams{
		ID: ids.New(), SubjectKind: kind, SubjectID: subjectID, DeviceKey: key,
		Model: optText(d.Model), OsVersion: optText(d.OSVersion), AppVersion: optText(d.AppVersion),
		PushToken: optText(d.PushToken), SeenAt: tp(s.now()),
	})
	if err != nil {
		return store.Device{}, apperr.Internalf("identity: upsert device: %w", err)
	}
	if dev.RevokedAt != nil {
		return store.Device{}, errDeviceRevoked()
	}
	if err := s.claimPushToken(ctx, q, dev.ID, optText(d.PushToken)); err != nil {
		return store.Device{}, err
	}
	return dev, nil
}

// claimPushToken removes token from every other device row.
func (s *Service) claimPushToken(ctx context.Context, q *store.Queries, deviceID uuid.UUID, token *string) error {
	if token == nil {
		return nil
	}
	if err := q.ClearPushTokenElsewhere(ctx, store.ClearPushTokenElsewhereParams{PushToken: token, KeepID: deviceID}); err != nil {
		return apperr.Internalf("identity: clear push token: %w", err)
	}
	return nil
}

// Heartbeat records that the caller's app is alive and updates its details and
// push token. Wipe is true when the device has been revoked.
func (s *Service) Heartbeat(ctx context.Context, kind auth.Kind, u DeviceHeartbeat) (HeartbeatResult, error) {
	p, err := auth.RequireKind(ctx, kind)
	if err != nil {
		return HeartbeatResult{}, err
	}
	if p.DeviceID == uuid.Nil {
		return HeartbeatResult{}, apperr.NotFound("device")
	}
	out := HeartbeatResult{DeviceID: p.DeviceID}
	err = s.withTx(ctx, func(_ pgx.Tx, q *store.Queries) error {
		d, err := q.GetDeviceForUpdate(ctx, p.DeviceID)
		if db.IsNoRows(err) || (err == nil && (d.SubjectKind != string(kind) || d.SubjectID != p.ID)) {
			return apperr.NotFound("device")
		}
		if err != nil {
			return apperr.Internalf("identity: load device: %w", err)
		}
		if d.RevokedAt != nil {
			out.Wipe = true
			return nil
		}
		token := optText(u.PushToken)
		if _, err := q.TouchDevice(ctx, store.TouchDeviceParams{
			Model: optText(u.Model), OsVersion: optText(u.OSVersion), AppVersion: optText(u.AppVersion),
			PushToken: token, SeenAt: tp(s.now()), ID: d.ID,
		}); err != nil {
			return apperr.Internalf("identity: touch device: %w", err)
		}
		return s.claimPushToken(ctx, q, d.ID, token)
	})
	if err != nil {
		return HeartbeatResult{}, err
	}
	out.ServerTime = s.now()
	out.MinVersion, out.UpdateRequired = s.versionCheck(kind, u.AppVersion)
	return out, nil
}

// AppConfig returns the release settings of the "farmer" or "fa" app (forced
// update, feature flags) from config. No token needed.
func (s *Service) AppConfig(app string) (config.AppRelease, error) {
	r, ok := s.deps.Config.App(app)
	if !ok {
		return config.AppRelease{}, apperr.Validation("app", "must be farmer or fa")
	}
	return r, nil
}

// versionCheck returns the min version for the app of kind and whether
// appVersion (when known) is below it.
func (s *Service) versionCheck(kind auth.Kind, appVersion *string) (string, bool) {
	app := "farmer"
	if kind == auth.KindFA {
		app = "fa"
	}
	r, _ := s.deps.Config.App(app)
	if appVersion == nil || strings.TrimSpace(*appVersion) == "" {
		return r.MinVersion, false
	}
	return r.MinVersion, config.CompareVersions(strings.TrimSpace(*appVersion), r.MinVersion) < 0
}

// authorizeManage allows the HO roles that manage FA logins and devices.
func authorizeManage(ctx context.Context) (auth.Principal, error) {
	return auth.RequireRole(ctx, auth.RoleAdmin, auth.RoleOps)
}

// ListDevices lists one subject's devices, newest first.
func (s *Service) ListDevices(ctx context.Context, subjectKind string, subjectID uuid.UUID, limit *int, cursor *string) (paging.Page[DeviceRecord], error) {
	p, err := authorizeManage(ctx)
	if err != nil {
		return paging.Page[DeviceRecord]{}, err
	}
	if subjectKind != SubjectFA && subjectKind != SubjectFarmer {
		return paging.Page[DeviceRecord]{}, apperr.Validation("subject_kind", "must be fa or farmer")
	}
	if subjectKind == SubjectFA {
		if err := s.checkFAScope(ctx, p, subjectID); err != nil {
			return paging.Page[DeviceRecord]{}, err
		}
	}
	cur, err := paging.Decode(cursor)
	if err != nil {
		return paging.Page[DeviceRecord]{}, err
	}
	n := paging.Limit(limit, listDefaultLimit, listMaxLimit)
	rows, err := s.q.ListSubjectDevices(ctx, store.ListSubjectDevicesParams{
		SubjectKind: subjectKind, SubjectID: subjectID, CursorAt: cur.AtPtr(), CursorID: cur.IDNull(), RowLimit: int32(n + 1),
	})
	if err != nil {
		return paging.Page[DeviceRecord]{}, apperr.Internalf("identity: list devices: %w", err)
	}
	return paging.Map(paging.Build(rows, n, func(d store.Device) paging.Cursor {
		return paging.Cursor{At: d.CreatedAt, ID: d.ID}
	}), toDevice), nil
}

// RevokeDevice revokes a device: its sessions end, its push token is dropped,
// the app wipes itself at its next contact, and the sync module drops the
// cached snapshot (device.revoked). Revoking twice changes nothing.
func (s *Service) RevokeDevice(ctx context.Context, id uuid.UUID, reason string) (DeviceRecord, error) {
	p, err := authorizeManage(ctx)
	if err != nil {
		return DeviceRecord{}, err
	}
	reason = clip(reason, 200)
	if reason == "" {
		return DeviceRecord{}, apperr.Validation("reason", "is required")
	}
	if p.HasAreaScope() { // FA devices only; area scope for farmers is not checked here
		d, err := s.q.GetDevice(ctx, id)
		if db.IsNoRows(err) {
			return DeviceRecord{}, apperr.NotFound("device")
		}
		if err != nil {
			return DeviceRecord{}, apperr.Internalf("identity: load device: %w", err)
		}
		if d.SubjectKind == SubjectFA {
			if err := s.checkFAScope(ctx, p, d.SubjectID); err != nil {
				return DeviceRecord{}, apperr.NotFound("device")
			}
		}
	}
	var out store.Device
	err = s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		d, err := q.GetDeviceForUpdate(ctx, id)
		if db.IsNoRows(err) {
			return apperr.NotFound("device")
		}
		if err != nil {
			return apperr.Internalf("identity: load device: %w", err)
		}
		if d.RevokedAt != nil {
			out = d
			return nil
		}
		revoked, err := s.revokeDevices(ctx, tx, q, []store.Device{d}, reason)
		if err != nil {
			return err
		}
		out = revoked[0]
		return nil
	})
	if err != nil {
		return DeviceRecord{}, err
	}
	s.forgetRevocation(ctx, out.ID)
	return toDevice(out), nil
}

// revokeDevices revokes each device (already locked or freshly read by the
// caller) with its sessions, publishes device.revoked and audits it.
func (s *Service) revokeDevices(ctx context.Context, tx pgx.Tx, q *store.Queries, devs []store.Device, reason string) ([]store.Device, error) {
	now := s.now()
	out := make([]store.Device, 0, len(devs))
	for _, d := range devs {
		r, err := q.RevokeDevice(ctx, store.RevokeDeviceParams{RevokedAt: tp(now), RevokeReason: &reason, ID: d.ID})
		if db.IsNoRows(err) { // revoked meanwhile
			continue
		}
		if err != nil {
			return nil, apperr.Internalf("identity: revoke device: %w", err)
		}
		if _, err := q.RevokeDeviceSessions(ctx, store.RevokeDeviceSessionsParams{RevokedAt: tp(now), DeviceID: nullUUID(d.ID)}); err != nil {
			return nil, apperr.Internalf("identity: revoke device sessions: %w", err)
		}
		if err := s.deps.Events.Publish(ctx, tx, events.DeviceRevoked{DeviceID: d.ID, SubjectKind: d.SubjectKind, SubjectID: d.SubjectID}); err != nil {
			return nil, apperr.Internalf("identity: publish device.revoked: %w", err)
		}
		entry := audit.Entry{Action: "identity.device_revoked", EntityType: "device", EntityID: d.ID,
			After: map[string]any{"subject_kind": d.SubjectKind, "subject_id": d.SubjectID, "reason": reason}}
		if d.SubjectKind == SubjectFarmer {
			entry.FarmerID = d.SubjectID
		}
		if err := record(ctx, tx, nil, entry); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, nil
}

// revokeSubjectDevices revokes every live device of a subject.
func (s *Service) revokeSubjectDevices(ctx context.Context, tx pgx.Tx, q *store.Queries, kind string, id uuid.UUID, reason string) ([]uuid.UUID, error) {
	rows, err := q.ListSubjectDevices(ctx, store.ListSubjectDevicesParams{SubjectKind: kind, SubjectID: id, RowLimit: 1000})
	if err != nil {
		return nil, apperr.Internalf("identity: list devices: %w", err)
	}
	live := rows[:0]
	for _, d := range rows {
		if d.RevokedAt == nil {
			live = append(live, d)
		}
	}
	revoked, err := s.revokeDevices(ctx, tx, q, live, reason)
	if err != nil {
		return nil, err
	}
	out := make([]uuid.UUID, len(revoked))
	for i, d := range revoked {
		out[i] = d.ID
	}
	return out, nil
}

// ---- revocation check (surface guard) ----

// Cache lifetimes for IsDeviceRevoked. Revocation is permanent, so "revoked"
// can be cached long; "not revoked" is cached briefly so a revocation applies
// within seconds even if the cache delete after revoking failed.
const (
	revokedCacheTTL    = 30 * time.Minute
	notRevokedCacheTTL = 30 * time.Second
)

func revokedCacheKey(id uuid.UUID) string { return "identity:revoked:" + id.String() }

// IsDeviceRevoked reports whether a device is revoked. It is called on every
// farmer and FA request by the surface guard (directly or via CheckPrincipal),
// so the answer is cached in Redis; with Redis down every call reads Postgres,
// so it stays correct. Unknown devices are not revoked.
func (s *Service) IsDeviceRevoked(ctx context.Context, deviceID uuid.UUID) (bool, error) {
	key := revokedCacheKey(deviceID)
	if b, ok := s.deps.Cache.Get(ctx, key); ok && len(b) == 1 {
		return b[0] == '1', nil
	}
	revoked, err := s.q.IsDeviceRevoked(ctx, deviceID)
	if err != nil && !db.IsNoRows(err) {
		return false, apperr.Internalf("identity: device revoked check: %w", err)
	}
	if revoked {
		s.deps.Cache.Set(ctx, key, []byte("1"), revokedCacheTTL)
	} else {
		s.deps.Cache.Set(ctx, key, []byte("0"), notRevokedCacheTTL)
	}
	return revoked, nil
}

// forgetRevocation drops cached revocation answers after a commit.
func (s *Service) forgetRevocation(ctx context.Context, deviceIDs ...uuid.UUID) {
	keys := make([]string, len(deviceIDs))
	for i, id := range deviceIDs {
		keys[i] = revokedCacheKey(id)
	}
	s.deps.Cache.Delete(ctx, keys...)
}

func toDevice(d store.Device) DeviceRecord {
	return DeviceRecord{
		ID: d.ID, SubjectKind: d.SubjectKind, SubjectID: d.SubjectID, Model: d.Model, OSVersion: d.OsVersion,
		AppVersion: d.AppVersion, HasPushToken: d.PushToken != nil && *d.PushToken != "", RevokedAt: utcPtr(d.RevokedAt),
		RevokeReason: d.RevokeReason, LastSeenAt: utcPtr(d.LastSeenAt), LastSyncAt: utcPtr(d.LastSyncAt), CreatedAt: d.CreatedAt.UTC(),
	}
}

func utcPtr(t *time.Time) *time.Time {
	if t == nil {
		return nil
	}
	u := t.UTC()
	return &u
}
