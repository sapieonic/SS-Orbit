package identity

import (
	"context"
	"time"

	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/ratelimit"
)

// Retention for identity's housekeeping job.
const (
	otpRetention     = 24 * time.Hour      // codes are worthless after a day
	sessionRetention = 30 * 24 * time.Hour // ended sessions kept a month for support questions
)

// MaintenanceArgs runs identity housekeeping: retention for OTP challenges,
// ended sessions and the rate limiter's Postgres counters, and sealing TOTP
// secrets still stored in clear.
type MaintenanceArgs struct{}

// Kind implements river.JobArgs.
func (MaintenanceArgs) Kind() string { return "identity.maintenance" }

type maintenanceWorker struct {
	river.WorkerDefaults[MaintenanceArgs]
	svc *Service
}

func (w *maintenanceWorker) Work(ctx context.Context, _ *river.Job[MaintenanceArgs]) error {
	_, err := w.svc.RunMaintenance(ctx)
	return err
}

// PeriodicJobs are identity's scheduled jobs, for the integrator to add to the
// worker's river.Config.PeriodicJobs. Maintenance runs hourly and on start;
// it is idempotent.
func PeriodicJobs() []*river.PeriodicJob {
	return []*river.PeriodicJob{
		river.NewPeriodicJob(
			river.PeriodicInterval(time.Hour),
			func() (river.JobArgs, *river.InsertOpts) { return MaintenanceArgs{}, nil },
			&river.PeriodicJobOpts{RunOnStart: true},
		),
	}
}

// MaintenanceResult counts what one run did.
type MaintenanceResult struct {
	OTPChallengesDeleted int64
	SessionsDeleted      int64
	RateCountersDeleted  int64
	TOTPSecretsSealed    int
}

// RunMaintenance deletes OTP challenges older than a day, sessions that
// expired or were revoked more than 30 days ago, and expired rate-limit
// counters, then seals legacy plaintext TOTP secrets. Housekeeping, not a
// business change, so it is logged rather than audited.
func (s *Service) RunMaintenance(ctx context.Context) (MaintenanceResult, error) {
	now := s.now()
	var r MaintenanceResult
	var err error
	if r.OTPChallengesDeleted, err = s.q.PurgeOTPChallenges(ctx, now.Add(-otpRetention)); err != nil {
		return r, apperr.Internalf("identity: purge otp challenges: %w", err)
	}
	if r.SessionsDeleted, err = s.q.PurgeSessions(ctx, now.Add(-sessionRetention)); err != nil {
		return r, apperr.Internalf("identity: purge sessions: %w", err)
	}
	if r.RateCountersDeleted, err = ratelimit.PurgeExpired(ctx, s.deps.Pool, now); err != nil {
		return r, err
	}
	if r.TOTPSecretsSealed, err = s.SealLegacyTOTPSecrets(ctx); err != nil {
		return r, err
	}
	s.deps.Logger.InfoContext(ctx, "identity maintenance done", "otp_challenges_deleted", r.OTPChallengesDeleted,
		"sessions_deleted", r.SessionsDeleted, "rate_counters_deleted", r.RateCountersDeleted, "totp_secrets_sealed", r.TOTPSecretsSealed)
	return r, nil
}
