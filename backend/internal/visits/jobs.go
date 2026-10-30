package visits

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"

	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
	"github.com/sapionic/orbit/backend/internal/visits/store"
)

// MarkMissedArgs marks planned visits whose day has passed as missed.
type MarkMissedArgs struct{}

// Kind implements river.JobArgs.
func (MarkMissedArgs) Kind() string { return "visits.mark_missed" }

type markMissedWorker struct {
	river.WorkerDefaults[MarkMissedArgs]
	svc *Service
}

func (w *markMissedWorker) Work(ctx context.Context, _ *river.Job[MarkMissedArgs]) error {
	_, err := w.svc.MarkMissed(ctx)
	return err
}

// MarkMissedPeriodicJob is the schedule for MarkMissedArgs, for the integrator
// to add to the worker's river.Config.PeriodicJobs. Hourly (and on start) so
// visits turn missed within an hour of IST midnight; the job is idempotent.
func MarkMissedPeriodicJob() *river.PeriodicJob {
	return river.NewPeriodicJob(
		river.PeriodicInterval(time.Hour),
		func() (river.JobArgs, *river.InsertOpts) { return MarkMissedArgs{}, nil },
		&river.PeriodicJobOpts{RunOnStart: true},
	)
}

// MarkMissed turns planned visits dated before today (IST) into missed visits,
// in one transaction, and returns how many changed.
func (s *Service) MarkMissed(ctx context.Context) (int, error) {
	var n int
	err := db.WithTx(ctx, s.deps.Pool, func(tx pgx.Tx) error {
		rows, err := store.New(tx).MarkMissedVisits(ctx, s.today())
		if err != nil {
			return err
		}
		n = len(rows)
		fas := make([]uuid.UUID, 0, len(rows))
		for _, r := range rows {
			fas = append(fas, r.FaID)
			after := map[string]any{"status": StatusMissed}
			if r.PlannedFor != nil {
				after["planned_for"] = r.PlannedFor.Format(time.DateOnly)
			}
			if _, err := audit.Record(ctx, tx, audit.Entry{
				Action: "visits.missed", EntityType: "visit", EntityID: r.ID,
				FarmerID: r.FarmerID, PlotID: r.PlotID, SeasonID: r.SeasonID,
				Before: map[string]any{"status": StatusPlanned}, After: after,
			}); err != nil {
				return err
			}
		}
		return territory.Bump(ctx, tx, fas...)
	})
	return n, err
}
