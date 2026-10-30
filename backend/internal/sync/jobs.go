package sync

import (
	"context"
	"time"

	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/sync/store"
)

// Retention of sync_commands (and the failure counters). Applied and merged
// commands are only an idempotency record and an audit trail of what the
// phone sent (the data itself is audited by the owning module), so they go
// after 180 days. Conflicts and rejections are what HO reviews; they stay a
// year.
const (
	routineRetention = 180 * 24 * time.Hour
	reviewRetention  = 365 * 24 * time.Hour
)

// RetentionArgs deletes old sync_commands rows.
type RetentionArgs struct{}

// Kind implements river.JobArgs.
func (RetentionArgs) Kind() string { return "sync.retention" }

type retentionWorker struct {
	river.WorkerDefaults[RetentionArgs]
	svc *Service
}

func (w *retentionWorker) Work(ctx context.Context, _ *river.Job[RetentionArgs]) error {
	_, err := w.svc.PruneCommands(ctx)
	return err
}

// PeriodicJobs are this module's schedules, for the integrator to add to the
// worker's river.Config.PeriodicJobs (CONVENTIONS section 13). Retention runs
// daily; it is idempotent.
func PeriodicJobs() []*river.PeriodicJob {
	return []*river.PeriodicJob{
		river.NewPeriodicJob(
			river.PeriodicInterval(24*time.Hour),
			func() (river.JobArgs, *river.InsertOpts) { return RetentionArgs{}, nil },
			&river.PeriodicJobOpts{RunOnStart: true},
		),
	}
}

// PruneCommands deletes stored commands past retention, and failure counters
// not touched for a year (they explain rejected rows, which stay a year). It returns how many commands went.
// A command ID deleted here would be dispatched again if a phone resent it
// after 180 days; phones drop acknowledged commands long before that.
func (s *Service) PruneCommands(ctx context.Context) (int64, error) {
	now := s.deps.Clock.Now()
	n, err := s.q.DeleteOldSyncCommands(ctx, store.DeleteOldSyncCommandsParams{
		RoutineBefore: now.Add(-routineRetention),
		ReviewBefore:  now.Add(-reviewRetention),
	})
	if err != nil {
		return 0, err
	}
	f, err := s.q.DeleteOldSyncCommandFailures(ctx, now.Add(-reviewRetention))
	if err != nil {
		return n, err
	}
	logx.From(ctx).InfoContext(ctx, "sync: retention", "commands_deleted", n, "failures_deleted", f)
	return n, nil
}
