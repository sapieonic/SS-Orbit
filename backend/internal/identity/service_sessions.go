package identity

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
)

// refreshTTL is the refresh-token lifetime per subject kind (config).
func (s *Service) refreshTTL(kind auth.Kind) time.Duration {
	switch kind {
	case auth.KindFarmer:
		return s.deps.Config.RefreshTTLFarmer
	case auth.KindFA:
		return s.deps.Config.RefreshTTLFA
	default:
		return s.deps.Config.RefreshTTLHO
	}
}

// refreshGrace is how long a just-rotated refresh token keeps working. On 2G
// the refresh response is often lost and the app retries with the old token,
// and two requests that both got a 401 refresh in parallel; inside the window
// both get the same successor instead of the family being revoked.
const refreshGrace = 60 * time.Second

// startSession stores a new session for p in family familyID (uuid.Nil
// starts a new family) and mints the token pair. expiresAt zero means now +
// the kind's refresh TTL. prevRefresh is the token being rotated ("" at
// sign-in): the new refresh token is derived from it (successorToken), so a
// retry of the old token inside refreshGrace can be answered with the same
// successor without storing it.
func (s *Service) startSession(ctx context.Context, q *store.Queries, p auth.Principal, familyID uuid.UUID, expiresAt time.Time, prevRefresh string) (Tokens, error) {
	now := s.now()
	if familyID == uuid.Nil {
		familyID = ids.New()
	}
	if expiresAt.IsZero() {
		expiresAt = now.Add(s.refreshTTL(p.Kind))
	}
	expiresAt = expiresAt.UTC().Truncate(time.Microsecond) // as Postgres stores it
	p.SessionID = ids.New()
	refresh, hash := auth.NewRefreshToken()
	if prevRefresh != "" {
		refresh = s.successorToken(prevRefresh)
		hash = auth.HashRefreshToken(refresh)
	}
	if err := q.CreateSession(ctx, store.CreateSessionParams{
		ID: p.SessionID, SubjectKind: string(p.Kind), SubjectID: p.ID, DeviceID: nullUUID(p.DeviceID),
		FamilyID: familyID, RefreshTokenHash: hash, ExpiresAt: expiresAt,
		UserAgent: userAgent(ctx), Ip: ipAddr(ctx), CreatedAt: now,
	}); err != nil {
		return Tokens{}, apperr.Internalf("identity: create session: %w", err)
	}
	access, accessExp, err := s.deps.Tokens.IssueAccess(p)
	if err != nil {
		return Tokens{}, apperr.Internalf("identity: issue access token: %w", err)
	}
	return Tokens{Access: access, AccessExpiresAt: accessExp, Refresh: refresh, RefreshExpiresAt: expiresAt}, nil
}

// Refresh rotates a refresh token. Each token works once: presenting a token
// that was already rotated means it leaked, so the whole family is revoked and
// the user must sign in again. The exception is a retry within refreshGrace
// of the rotation while the successor is still unused: that is a lost
// response or two parallel refreshes, and gets the same successor (a fresh
// access token for it, but no new session).
func (s *Service) Refresh(ctx context.Context, refreshToken string) (Tokens, error) {
	if err := s.allowIP(ctx, "refresh", 300, time.Minute); err != nil {
		return Tokens{}, err
	}
	var out Tokens
	var failure error          // business failure; the transaction still commits (family revocation)
	var revokedIDs []uuid.UUID // sessions revoked here, to drop from the guard cache after commit
	defer func() { s.forgetSessions(ctx, revokedIDs...) }()
	revokeFamily := func(q *store.Queries, sess store.Session, now time.Time) error {
		gone, err := q.RevokeSessionFamily(ctx, store.RevokeSessionFamilyParams{RevokedAt: tp(now), FamilyID: sess.FamilyID})
		if err != nil {
			return apperr.Internalf("identity: revoke family: %w", err)
		}
		revokedIDs = append(revokedIDs, gone...)
		return nil
	}
	err := s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		sess, err := q.GetSessionByHashForUpdate(ctx, auth.HashRefreshToken(refreshToken))
		if db.IsNoRows(err) {
			failure = apperr.Unauthorized("invalid refresh token")
			return nil
		}
		if err != nil {
			return apperr.Internalf("identity: load session: %w", err)
		}
		now := s.now()
		actor := &auth.Principal{Kind: auth.Kind(sess.SubjectKind), ID: sess.SubjectID, DeviceID: sess.DeviceID.UUID}
		switch {
		case sess.RevokedAt != nil:
			failure = apperr.Unauthorized("session has ended; sign in again")
			return nil
		case sess.RotatedAt != nil:
			if now.Sub(*sess.RotatedAt) <= refreshGrace {
				done, err := s.replaySuccessor(ctx, q, sess, refreshToken, now, &out)
				if err != nil {
					if !apperr.Is(err, apperr.KindUnauthorized) {
						return err
					}
					failure = err
					return revokeFamily(q, sess, now)
				}
				if done {
					return nil
				}
			}
			if err := revokeFamily(q, sess, now); err != nil {
				return err
			}
			if err := record(ctx, tx, actor, audit.Entry{Action: "identity.refresh_reuse_detected", EntityType: "session",
				EntityID: sess.ID, Meta: map[string]any{"family_id": sess.FamilyID, "subject_kind": sess.SubjectKind}}); err != nil {
				return err
			}
			failure = unauthorizedCode("refresh_reused", "this sign-in was used elsewhere; sign in again")
			return nil
		case !now.Before(sess.ExpiresAt):
			failure = apperr.Unauthorized("session expired; sign in again").WithDetail("reason", "expired")
			return nil
		}

		p, err := s.principalForSession(ctx, q, sess)
		if err != nil {
			if apperr.Is(err, apperr.KindUnauthorized) {
				failure = err
				return revokeFamily(q, sess, now)
			}
			return err
		}
		if err := q.MarkSessionRotated(ctx, store.MarkSessionRotatedParams{RotatedAt: tp(now), ID: sess.ID}); err != nil {
			return apperr.Internalf("identity: rotate session: %w", err)
		}
		// HO sessions keep the family's absolute end (a working day); app
		// sessions slide so a farmer who opens the app now and then stays in.
		var expires time.Time
		if p.Kind == auth.KindHO {
			expires = sess.ExpiresAt
		}
		out, err = s.startSession(ctx, q, p, sess.FamilyID, expires, refreshToken)
		return err
	})
	if err != nil {
		return Tokens{}, err
	}
	if failure != nil {
		return Tokens{}, failure
	}
	return out, nil
}

// replaySuccessor answers a retried refresh inside the grace window. It
// returns done=false when the successor is gone or already used itself (the
// caller then treats the retry as reuse), and an Unauthorized error when the
// family may no longer be used at all.
func (s *Service) replaySuccessor(ctx context.Context, q *store.Queries, sess store.Session, refreshToken string, now time.Time, out *Tokens) (bool, error) {
	successor := s.successorToken(refreshToken)
	next, err := q.GetSessionByHashForUpdate(ctx, auth.HashRefreshToken(successor))
	if db.IsNoRows(err) {
		return false, nil
	}
	if err != nil {
		return false, apperr.Internalf("identity: load successor session: %w", err)
	}
	if next.FamilyID != sess.FamilyID || next.RotatedAt != nil {
		return false, nil
	}
	if next.RevokedAt != nil || !now.Before(next.ExpiresAt) {
		return false, apperr.Unauthorized("session has ended; sign in again")
	}
	p, err := s.principalForSession(ctx, q, next)
	if err != nil {
		return false, err
	}
	p.SessionID = next.ID
	access, accessExp, err := s.deps.Tokens.IssueAccess(p)
	if err != nil {
		return false, apperr.Internalf("identity: issue access token: %w", err)
	}
	*out = Tokens{Access: access, AccessExpiresAt: accessExp, Refresh: successor, RefreshExpiresAt: next.ExpiresAt.UTC()}
	return true, nil
}

// principalForSession rebuilds the access-token principal from current data,
// so role or area changes and deactivations apply at the next refresh.
// Returns Unauthorized when the subject may no longer sign in.
func (s *Service) principalForSession(ctx context.Context, q *store.Queries, sess store.Session) (auth.Principal, error) {
	p := auth.Principal{Kind: auth.Kind(sess.SubjectKind), ID: sess.SubjectID, DeviceID: sess.DeviceID.UUID}
	ended := apperr.Unauthorized("this login is no longer active")
	switch p.Kind {
	case auth.KindHO:
		u, err := q.GetHOUser(ctx, sess.SubjectID)
		if db.IsNoRows(err) {
			return p, ended
		}
		if err != nil {
			return p, apperr.Internalf("identity: load ho user: %w", err)
		}
		if u.Status == HODisabled || !u.TotpEnabled {
			return p, ended
		}
		if tempPasswordExpired(u.MustChangePassword, u.TempPasswordExpiresAt, s.now()) {
			return p, errTempPasswordExpired()
		}
		p.Role, p.DistrictIDs, p.MustChangePassword = auth.Role(u.Role), u.DistrictIds, u.MustChangePassword
	case auth.KindFA:
		fa, err := q.GetFieldAssistant(ctx, sess.SubjectID)
		if db.IsNoRows(err) {
			return p, ended
		}
		if err != nil {
			return p, apperr.Internalf("identity: load fa: %w", err)
		}
		if fa.Status == FAInactive {
			return p, ended
		}
		if tempPasswordExpired(fa.MustChangePassword, fa.TempPasswordExpiresAt, s.now()) {
			return p, errTempPasswordExpired()
		}
		p.MustChangePassword = fa.MustChangePassword
	case auth.KindFarmer:
		// Farmer records are never deleted; a farmer whose phone was taken
		// over is handled by revoking the device.
	default:
		return p, ended
	}
	if sess.DeviceID.Valid {
		d, err := q.GetDevice(ctx, sess.DeviceID.UUID)
		if err != nil && !db.IsNoRows(err) {
			return p, apperr.Internalf("identity: load device: %w", err)
		}
		if err != nil || d.RevokedAt != nil {
			return p, errDeviceRevoked()
		}
	}
	return p, nil
}

// Logout revokes the caller's session family: the bearer token's session, or
// else the one the refresh token belongs to. Unknown sessions are ignored so
// logout is always safe to retry.
func (s *Service) Logout(ctx context.Context, refreshToken *string) error {
	p, hasPrincipal := auth.FromContext(ctx)
	if (!hasPrincipal || p.SessionID == uuid.Nil) && refreshToken == nil {
		return nil
	}
	var revoked []uuid.UUID
	defer func() { s.forgetSessions(ctx, revoked...) }()
	return s.withTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		var sess store.Session
		var err error
		if hasPrincipal && p.SessionID != uuid.Nil {
			sess, err = q.GetSession(ctx, p.SessionID)
		} else {
			sess, err = q.GetSessionByHashForUpdate(ctx, auth.HashRefreshToken(*refreshToken))
		}
		if db.IsNoRows(err) {
			return nil
		}
		if err != nil {
			return apperr.Internalf("identity: load session: %w", err)
		}
		revoked, err = q.RevokeSessionFamily(ctx, store.RevokeSessionFamilyParams{RevokedAt: tp(s.now()), FamilyID: sess.FamilyID})
		if err != nil {
			return apperr.Internalf("identity: revoke session: %w", err)
		}
		if len(revoked) == 0 {
			return nil
		}
		actor := &auth.Principal{Kind: auth.Kind(sess.SubjectKind), ID: sess.SubjectID, DeviceID: sess.DeviceID.UUID}
		return record(ctx, tx, actor, audit.Entry{Action: "identity.logged_out", EntityType: "session", EntityID: sess.ID,
			Meta: map[string]any{"subject_kind": sess.SubjectKind}})
	})
}

// revokeSubjectSessions ends every session of a subject, optionally keeping
// one family (the caller's own after a password change), and returns the
// revoked session IDs. Callers pass them to forgetSessions after commit.
func (s *Service) revokeSubjectSessions(ctx context.Context, q *store.Queries, kind string, id, keepFamily uuid.UUID) ([]uuid.UUID, error) {
	gone, err := q.RevokeSubjectSessions(ctx, store.RevokeSubjectSessionsParams{
		RevokedAt: tp(s.now()), SubjectKind: kind, SubjectID: id, KeepFamilyID: nullUUID(keepFamily),
	})
	if err != nil {
		return nil, apperr.Internalf("identity: revoke sessions: %w", err)
	}
	return gone, nil
}

// currentFamily returns the session family of the caller's access token, or
// uuid.Nil if unknown.
func (s *Service) currentFamily(ctx context.Context, q *store.Queries, p auth.Principal) uuid.UUID {
	if p.SessionID == uuid.Nil {
		return uuid.Nil
	}
	sess, err := q.GetSession(ctx, p.SessionID)
	if err != nil || sess.SubjectID != p.ID {
		return uuid.Nil
	}
	return sess.FamilyID
}
