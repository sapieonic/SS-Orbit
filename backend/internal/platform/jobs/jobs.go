// Package jobs wraps River (Postgres-backed job queue).
//
// The api process uses an insert-only client: it enqueues jobs in the same
// transaction as the business write (Insert with the pgx.Tx), so a job exists
// if and only if the write committed. The worker process runs a working client
// (NewWorker) that executes the workers modules registered.
//
// Defining a job: an args struct with Kind() string (kind = "<module>.<job>")
// and a worker embedding river.WorkerDefaults[Args]; register it in the
// module's RegisterWorkers(w *river.Workers) via river.AddWorker(w, &MyWorker{}).
package jobs

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivertype"
)

// Inserter is the subset of *river.Client[pgx.Tx] used to enqueue jobs.
type Inserter interface {
	InsertTx(ctx context.Context, tx pgx.Tx, args river.JobArgs, opts *river.InsertOpts) (*rivertype.JobInsertResult, error)
	InsertManyTx(ctx context.Context, tx pgx.Tx, params []river.InsertManyParams) ([]*rivertype.JobInsertResult, error)
}

// Client enqueues jobs. It is the value in platform.Deps.Jobs.
type Client struct {
	ins Inserter
}

// NewInsertOnly builds a River client that can enqueue but not work jobs.
func NewInsertOnly(pool *pgxpool.Pool, log *slog.Logger) (*Client, error) {
	rc, err := river.NewClient(riverpgxv5.New(pool), &river.Config{Logger: log})
	if err != nil {
		return nil, fmt.Errorf("jobs: insert-only client: %w", err)
	}
	return &Client{ins: rc}, nil
}

// FromInserter wraps any Inserter (e.g. a working river client, or a fake).
func FromInserter(ins Inserter) *Client { return &Client{ins: ins} }

// Insert enqueues args inside tx. opts may be nil.
func (c *Client) Insert(ctx context.Context, tx pgx.Tx, args river.JobArgs, opts *river.InsertOpts) error {
	if _, err := c.ins.InsertTx(ctx, tx, args, opts); err != nil {
		return fmt.Errorf("jobs: insert %s: %w", args.Kind(), err)
	}
	return nil
}

// InsertMany enqueues several jobs inside tx.
func (c *Client) InsertMany(ctx context.Context, tx pgx.Tx, params []river.InsertManyParams) error {
	if len(params) == 0 {
		return nil
	}
	if _, err := c.ins.InsertManyTx(ctx, tx, params); err != nil {
		return fmt.Errorf("jobs: insert many: %w", err)
	}
	return nil
}

// WorkerConfig tunes the working client.
type WorkerConfig struct {
	// MaxWorkers for the default queue.
	MaxWorkers int
	// Queues adds extra named queues with their own concurrency (optional).
	Queues map[string]int
	// PeriodicJobs are scheduled by the leader worker (optional).
	PeriodicJobs []*river.PeriodicJob
}

// NewWorker builds a River client that works jobs for workers. Call Start and
// Stop on the returned client.
func NewWorker(pool *pgxpool.Pool, workers *river.Workers, cfg WorkerConfig, log *slog.Logger) (*river.Client[pgx.Tx], error) {
	if cfg.MaxWorkers <= 0 {
		cfg.MaxWorkers = 20
	}
	queues := map[string]river.QueueConfig{river.QueueDefault: {MaxWorkers: cfg.MaxWorkers}}
	for name, n := range cfg.Queues {
		queues[name] = river.QueueConfig{MaxWorkers: n}
	}
	rc, err := river.NewClient(riverpgxv5.New(pool), &river.Config{
		Logger:        log,
		Queues:        queues,
		Workers:       workers,
		PeriodicJobs:  cfg.PeriodicJobs,
		JobTimeout:    5 * time.Minute,
		FetchCooldown: 50 * time.Millisecond,
	})
	if err != nil {
		return nil, fmt.Errorf("jobs: worker client: %w", err)
	}
	return rc, nil
}
