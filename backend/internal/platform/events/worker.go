package events

import (
	"context"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"

	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/platform/reqctx"
)

// RegisterWorkers adds the event dispatcher and delivery workers to workers.
// Call it once in the worker process after all modules subscribed on bus.
func RegisterWorkers(workers *river.Workers, bus *Bus, pool db.Beginner, log *slog.Logger) {
	if log == nil {
		log = slog.Default()
	}
	river.AddWorker(workers, &fanoutWorker{bus: bus, pool: pool, log: log})
	river.AddWorker(workers, &deliveryWorker{bus: bus, log: log})
}

// fanoutWorker turns one domain_event job into one delivery job per
// subscriber, atomically with completing the event job.
type fanoutWorker struct {
	river.WorkerDefaults[eventArgs]
	bus  *Bus
	pool db.Beginner
	log  *slog.Logger
}

func (w *fanoutWorker) Work(ctx context.Context, job *river.Job[eventArgs]) error {
	subs := w.bus.Subscribers(job.Args.Name)
	if len(subs) == 0 {
		return nil
	}
	client, err := river.ClientFromContextSafely[pgx.Tx](ctx)
	if err != nil {
		return err
	}
	params := make([]river.InsertManyParams, 0, len(subs))
	for _, s := range subs {
		params = append(params, river.InsertManyParams{Args: deliveryArgs{Event: job.Args, Subscriber: s}})
	}
	return db.WithTx(ctx, w.pool, func(tx pgx.Tx) error {
		if _, err := client.InsertManyTx(ctx, tx, params); err != nil {
			return err
		}
		_, err := river.JobCompleteTx[*riverpgxv5.Driver](ctx, tx, job)
		return err
	})
}

// deliveryWorker calls one subscriber.
type deliveryWorker struct {
	river.WorkerDefaults[deliveryArgs]
	bus *Bus
	log *slog.Logger
}

func (w *deliveryWorker) Work(ctx context.Context, job *river.Job[deliveryArgs]) error {
	ev := job.Args.Event
	fn, ok := w.bus.handler(ev.Name, job.Args.Subscriber)
	if !ok {
		// Subscriber was removed since the event was published; nothing to do.
		w.log.WarnContext(ctx, "events: subscriber gone, dropping delivery", "event", ev.Name, "subscriber", job.Args.Subscriber)
		return nil
	}
	ctx = reqctx.With(ctx, reqctx.Meta{RequestID: ev.RequestID})
	ctx = logx.With(ctx, w.log.With(
		"request_id", ev.RequestID, "event", ev.Name, "event_id", ev.EventID,
		"subscriber", job.Args.Subscriber, "attempt", job.Attempt))
	ctx = context.WithValue(ctx, metaKey{}, Meta{
		EventID: ev.EventID, Name: ev.Name, OccurredAt: ev.OccurredAt,
		Subscriber: job.Args.Subscriber, Attempt: job.Attempt,
	})
	return fn(ctx, ev.Payload)
}
