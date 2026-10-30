package identity

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/identity/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
)

// Cache lifetimes for the HO session check. A live answer is kept briefly and
// dropped as soon as identity revokes the session (forgetSessions), so even a
// failed cache delete leaves a signed-out token working for at most a minute.
// Revocation is permanent, so a revoked answer can stay longer.
const (
	hoLiveCacheTTL    = time.Minute
	hoRevokedCacheTTL = 30 * time.Minute
)

func hoSessionCacheKey(sessionID uuid.UUID) string { return "identity:hosess:" + sessionID.String() }

func errSessionRevoked() *apperr.Error {
	return unauthorizedCode("session_revoked", "you have been signed out; sign in again")
}

// CheckPrincipal is the surface guard's revocation check
// (httpx.PrincipalCheckFunc), run on every token-guarded request:
//   - farmer and FA tokens: the device must not be revoked (401 device_revoked);
//   - HO tokens: the session must not be revoked and the user not disabled
//     (401 session_revoked).
//
// Answers are cached in Redis (one GET per request on the hot path); with
// Redis down it reads Postgres, so it stays correct. Any non-apperr error
// makes the guard answer 503.
func (s *Service) CheckPrincipal(ctx context.Context, p auth.Principal) error {
	switch p.Kind {
	case auth.KindFarmer, auth.KindFA:
		if p.DeviceID == uuid.Nil {
			return nil
		}
		revoked, err := s.IsDeviceRevoked(ctx, p.DeviceID)
		if err != nil {
			return err
		}
		if revoked {
			return errDeviceRevoked()
		}
	case auth.KindHO:
		live, err := s.hoAccessAllowed(ctx, p)
		if err != nil {
			return err
		}
		if !live {
			return errSessionRevoked()
		}
	}
	return nil
}

// hoAccessAllowed reports whether an HO token's session is live and its user
// enabled, through the cache.
func (s *Service) hoAccessAllowed(ctx context.Context, p auth.Principal) (bool, error) {
	key := ""
	if p.SessionID != uuid.Nil {
		key = hoSessionCacheKey(p.SessionID)
		if b, ok := s.deps.Cache.Get(ctx, key); ok && len(b) == 1 {
			return b[0] == '1', nil
		}
	}
	row, err := s.q.HOAccessAllowed(ctx, store.HOAccessAllowedParams{SessionID: p.SessionID, UserID: p.ID})
	if err != nil {
		return false, apperr.Internalf("identity: ho session check: %w", err)
	}
	live := row.SessionLive && row.UserEnabled
	if key != "" {
		if live {
			s.deps.Cache.Set(ctx, key, []byte("1"), hoLiveCacheTTL)
		} else {
			s.deps.Cache.Set(ctx, key, []byte("0"), hoRevokedCacheTTL)
		}
	}
	return live, nil
}

// forgetSessions drops cached guard answers for sessions just revoked. Call it
// after the revoking transaction commits.
func (s *Service) forgetSessions(ctx context.Context, sessionIDs ...uuid.UUID) {
	if len(sessionIDs) == 0 {
		return
	}
	keys := make([]string, len(sessionIDs))
	for i, id := range sessionIDs {
		keys[i] = hoSessionCacheKey(id)
	}
	s.deps.Cache.Delete(ctx, keys...)
}
