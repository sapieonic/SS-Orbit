// Package platform bundles the shared infrastructure every module receives.
// Subpackages hold the actual pieces (db, auth, httpx, ...); this package only
// defines Deps so module constructors have one stable signature:
//
//	func New(deps platform.Deps, ports *Ports) *Module
package platform

import (
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/cache"
	"github.com/sapionic/orbit/backend/internal/platform/clock"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/jobs"
	"github.com/sapionic/orbit/backend/internal/platform/push"
	"github.com/sapionic/orbit/backend/internal/platform/ratelimit"
	"github.com/sapionic/orbit/backend/internal/platform/sms"
	"github.com/sapionic/orbit/backend/internal/platform/storage"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// Deps is passed by value to every module's New. All fields are set in the
// api, worker and testutil.NewDeps; modules must not replace them.
type Deps struct {
	Config  config.Config
	Pool    *pgxpool.Pool
	Cache   *cache.Cache       // tolerant of Redis being down
	Limiter *ratelimit.Limiter // Redis with Postgres fallback
	Jobs    *jobs.Client       // enqueue River jobs in a tx
	Events  *events.Publisher  // publish domain events in a tx
	Tokens  *auth.Tokens       // issue/verify access + web-link tokens
	Storage storage.Storage
	SMS     sms.Sender
	Push    push.Sender
	Clock   clock.Clock
	Logger  *slog.Logger
	// Commands is the sync command registry. Modules register handlers in
	// RegisterCommands; the sync module dispatches through it.
	Commands *commands.Registry
	// Territory is the snapshot registry. Modules register in RegisterSnapshot;
	// the sync module calls Build.
	Territory *territory.Registry
}
