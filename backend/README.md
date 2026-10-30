# Orbit backend

Go API and worker for Orbit Shifting (Shanmukha Agritec): farmer app, FA app (offline-first) and HO portal.
Go 1.27, Postgres 17 + PostGIS, Redis 7, River for jobs and domain events.

Read [docs/CONVENTIONS.md](docs/CONVENTIONS.md) before writing code. It is the contract every module follows,
and section 12 lists the exact platform signatures.

## Quick start

You need Docker (Docker Desktop context is fine), Go 1.27 and sqlc 1.31 (oapi-codegen comes in via `go generate`).
The Makefile puts `~/.local/go/bin`, `~/go/bin` and `~/.local/bin` on `PATH` itself. If you don't have the tools yet:

```sh
# Go into ~/.local/go (or anywhere, then pass GO_ROOT=/that/path to make)
curl -fsSL https://go.dev/dl/go1.27.3.linux-amd64.tar.gz | tar -C ~/.local -xz
# sqlc into ~/go/bin (needs the Go above on PATH: export PATH=~/.local/go/bin:$PATH)
go install github.com/sqlc-dev/sqlc/cmd/sqlc@v1.31.1
```

Tools somewhere else? Override the paths: `make test GO_ROOT=/usr/local/go GO_BIN=/opt/bin TOOLS_BIN=/usr/local/bin`.

```sh
cd backend
make dev-up          # Postgres+PostGIS (orbit, orbit_test) and Redis; creates .env from .env.example
make migrate         # goose migrations + River's tables
make seed            # dev data; prints the dev HO, FA and farmer logins
make run-api         # :8080
make run-worker      # in another terminal (or `make ping` to also publish a test event)

curl localhost:8080/healthz
curl localhost:8080/readyz
curl -H "Authorization: Bearer $(make -s token KIND=ho ROLE=admin)" localhost:8080/v1/admin/audit
```

`make help` lists every target. Useful ones:

| Target | What it does |
|---|---|
| `make gen` | sqlc + oapi-codegen for every module (run after changing a query or a spec) |
| `make seed` | dev sample data (idempotent, refuses `ORBIT_ENV=prod`); prints the dev logins |
| `make test` | unit + integration tests (integration uses `orbit_test`; skipped if `TEST_DATABASE_URL` is empty). Set `TEST_REDIS_URL=redis://localhost:6379/15` to also run the Redis cache tests |
| `make check` | fails if generated code is stale, then gofmt, go vet and tests |
| `make token KIND=fa` | dev JWT for curl (`KIND=ho\|fa\|farmer\|web`, `ROLE=admin\|agronomy\|finance\|ops`) |
| `make migrate-status` / `migrate-down` | inspect / roll back one goose migration |
| `make dev-reset` | drop the dev containers AND their data volume |

## Layout

```
backend/
  cmd/api, cmd/worker      thin mains around internal/app
  cmd/migrate              goose (embedded) + River migrations: up | down | status
  cmd/devtoken, cmd/seed   dev token minting; dev seed data
  migrations/              schema, one goose file per module (owned centrally)
  internal/app/            wire.go: builds every module and connects ports (integrator only)
  internal/platform/       shared infrastructure (db, auth, httpx, events, jobs, ...), no business logic
  internal/<module>/       identity, geo, farmers, masters, visits, messaging, sync, audit
  sqlc.yaml                one entry per module
../contracts/openapi/      one OpenAPI 3.0.3 spec per module
../dev/docker-compose.yml  Postgres + Redis for local dev and tests
```

`internal/audit` is the reference module: copy its structure.

## Adding an endpoint

1. **Spec.** Add the path to `contracts/openapi/<module>.yaml`. Paths are absolute and the prefix decides who may
   call it (`/v1/admin/...` needs an HO token, `/v1/fa/...` an FA token, and so on). Reference the shared
   error responses (`$ref: '#/components/responses/BadRequest'`) and use `limit`/`cursor` for lists.
2. **Generate.** `make gen`. This regenerates `internal/<module>/api.gen.go`; the build now fails until the
   handler implements the new method of `StrictServerInterface`.
3. **Query.** Add SQL to `internal/<module>/queries/*.sql` with a `-- name: Foo :one|:many|:exec` header, then
   `make gen` again to get `store.Foo`.
4. **Service.** Put the rules in `service*.go`: check the caller (`auth.RequireRole(ctx, auth.RoleOps)`), validate,
   and for writes use `db.WithTx(ctx, deps.Pool, func(tx pgx.Tx) error {...})` with `store.New(tx)`,
   `audit.Record(ctx, tx, ...)`, and `deps.Events.Publish(ctx, tx, ...)` / `territory.Bump(ctx, tx, ...)` when relevant.
   Return `apperr` errors.
5. **Handler.** In `handler*.go`, map the request DTO to the service call and the result back to the response
   DTO. Return service errors unchanged; they are written in the shared error shape.
6. **Test.** Service tests with fakes; an HTTP test with `testutil.Router` (see `internal/audit/handler_test.go`);
   integration tests with `testutil.NewDB` + `testutil.NewDeps`.

## Adding a migration

The schema is owned centrally, so module owners propose changes instead of editing files directly. To add one:

1. Create `migrations/000NN_<name>.sql` with `-- +goose Up` and `-- +goose Down` sections (wrap functions in
   `-- +goose StatementBegin/End`). Number it after the last file.
2. `make migrate` to apply it to the dev DB, and `make gen` so sqlc sees the new columns.
3. Tests pick it up automatically (`testutil` migrates `orbit_test` on first use). If the migration inserts seed
   rows, add them to `reseedSQL` in `internal/platform/testutil/db.go` because tests truncate every table.
4. Check `make migrate-down && make migrate` works.

Never edit a migration that has been applied anywhere shared; add a new one.

## Configuration

All settings come from environment variables (`.env` in dev; see `.env.example` and
`internal/platform/config/config.go`). `DEV_FIXED_OTP` and the `/dev/files` storage route only work with
`ORBIT_ENV=dev`.

`ORBIT_ENV=prod` refuses to start with the dev adapters: `SMS_PROVIDER=log`, `PUSH_PROVIDER=log` and
`STORAGE_PROVIDER=local` (the log senders would put OTP codes and signed links in the logs; outside dev they
redact message bodies anyway), and without `TOTP_ENC_KEY`. Real adapters still have to be written, so prod
cannot start yet; that is deliberate.

`TOTP_ENC_KEY` encrypts HO two-step secrets at rest (AES-256-GCM). Rows written before migration 00016 hold
the secret in clear; identity seals each one at the user's next sign-in and the hourly `identity.maintenance`
job seals the rest, so no manual step is needed. Don't change the key once secrets are sealed (every HO user
would have to set up TOTP again); key rotation would be a new `v2:` prefix.
