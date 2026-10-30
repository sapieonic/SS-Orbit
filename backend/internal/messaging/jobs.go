package messaging

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/riverqueue/river"
)

// River jobs:
//   - messaging.advisory_fanout: when an advisory is due, resolve recipients and
//     create notices and deliveries in batches (idempotent, resumable).
//   - messaging.delivery: send one delivery row; River retries with backoff and
//     the row is marked failed after deliveryMaxAttempts. Snoozed to 07:00 IST
//     when it comes up in quiet hours.
//   - messaging.fa_alert_push: push a new FA alert to the FA's devices.
//   - messaging.fa_offline (periodic, hourly): HO alert for FAs not synced in 48 h.

const fanoutMaxAttempts = 10

type advisoryFanoutArgs struct {
	AdvisoryID uuid.UUID `json:"advisory_id"`
}

func (advisoryFanoutArgs) Kind() string { return "messaging.advisory_fanout" }

type advisoryFanoutWorker struct {
	river.WorkerDefaults[advisoryFanoutArgs]
	svc *Service
}

func (w *advisoryFanoutWorker) Work(ctx context.Context, job *river.Job[advisoryFanoutArgs]) error {
	return w.svc.RunAdvisoryFanout(ctx, job.Args.AdvisoryID)
}

// Timeout allows large advisories (many batches) to finish in one run. A run
// cut short resumes on retry: notices already created are skipped.
func (w *advisoryFanoutWorker) Timeout(*river.Job[advisoryFanoutArgs]) time.Duration {
	return 30 * time.Minute
}

type deliveryJobArgs struct {
	DeliveryID uuid.UUID `json:"delivery_id"`
}

func (deliveryJobArgs) Kind() string { return "messaging.delivery" }

type deliveryWorker struct {
	river.WorkerDefaults[deliveryJobArgs]
	svc *Service
}

func (w *deliveryWorker) Work(ctx context.Context, job *river.Job[deliveryJobArgs]) error {
	return w.svc.SendDelivery(ctx, job.Args.DeliveryID, job.Attempt, job.MaxAttempts)
}

type faAlertPushArgs struct {
	AlertID uuid.UUID `json:"alert_id"`
}

func (faAlertPushArgs) Kind() string { return "messaging.fa_alert_push" }

type faAlertPushWorker struct {
	river.WorkerDefaults[faAlertPushArgs]
	svc *Service
}

func (w *faAlertPushWorker) Work(ctx context.Context, job *river.Job[faAlertPushArgs]) error {
	return w.svc.PushFAAlert(ctx, job.Args.AlertID)
}

// FAOfflineArgs raises fa_offline HO alerts.
type FAOfflineArgs struct{}

// Kind implements river.JobArgs.
func (FAOfflineArgs) Kind() string { return "messaging.fa_offline" }

type faOfflineWorker struct {
	river.WorkerDefaults[FAOfflineArgs]
	svc *Service
}

func (w *faOfflineWorker) Work(ctx context.Context, _ *river.Job[FAOfflineArgs]) error {
	_, err := w.svc.RaiseFAOfflineAlerts(ctx)
	return err
}

// PeriodicJobs are this module's schedules, for the integrator to add to the
// worker's river.Config.PeriodicJobs (CONVENTIONS section 13). The fa_offline
// check runs hourly (and on start); it is idempotent per FA per IST day.
func PeriodicJobs() []*river.PeriodicJob {
	return []*river.PeriodicJob{
		river.NewPeriodicJob(
			river.PeriodicInterval(time.Hour),
			func() (river.JobArgs, *river.InsertOpts) { return FAOfflineArgs{}, nil },
			&river.PeriodicJobOpts{RunOnStart: true},
		),
	}
}
