# Local dev stack implementation plan

## Purpose

`dev/` holds the Docker Compose stack every developer and the backend tests use: Postgres + PostGIS and Redis
today, plus object storage and fake partners later, so nobody needs vendor credentials to work on a feature.

## Read first

`dev/docker-compose.yml`, `dev/initdb/10-orbit-test.sql`, `backend/Makefile` (`dev-up`, `dev-down`, `dev-reset`)
and `backend/README.md` "Quick start".

## Current state

| Service | Image | Port | Notes |
|---|---|---|---|
| `postgres` | `postgis/postgis:17-3.5` | 5432 | user/password/db `orbit`; volume `pgdata`; healthy when `orbit_test` answers |
| `redis` | `redis:7.4-alpine` | 6379 | no persistence needed; tests use DB 15 (`TEST_REDIS_URL`) |

- `initdb/10-orbit-test.sql` runs once, on the first start of an empty volume: adds `citext` and `pg_trgm` to
  `orbit` and creates `orbit_test` with `postgis`, `citext` and `pg_trgm`. `orbit` is the dev DB
  (`DATABASE_URL`); `orbit_test` is for integration tests (`TEST_DATABASE_URL`; tests truncate every table).
- Compose project name is `orbit`. CI uses the same images as services (`.github/workflows/backend.yml`).
- Commands, from `backend/` (or `make dev-up` from the repo root): `make dev-up` (start and wait until healthy,
  creates `.env`), `make dev-down` (stop, keep data), `make dev-reset` (stop and **delete** the volume), then
  `make migrate && make seed` to get back to a working dev DB.
- Seed logins: HO `admin@`, `agronomy@`, `agronomy2@` (second Agronomy user for maker-checker), `finance@`,
  `ops@orbit.dev` (password `orbit-dev-pass`); FA `FA-KDP-014`, `FA-CVL-002` (`fa-dev-pass`); farmers by OTP
  `123456`. `python3 tools/smoke_test.py` from the repo root checks the whole stack (API and worker running).
- Redis is optional: an empty `REDIS_URL` runs without it (cache misses, rate limits on Postgres).
- The backend image (`make -C backend image`) runs against this stack with `ORBIT_ENV=dev` (the image defaults to
  `prod`), for example `docker run --network host -e ORBIT_ENV=dev --env-file backend/.env orbit-backend:dev api`.
- Docker Engine or Docker Desktop both work. With Docker Desktop on Linux, make sure `docker context show` is the
  context that is running, and that nothing else holds ports 5432 or 6379 (a local Postgres often does).
- If `orbit_test` is missing (the volume was created before `initdb/` existed), `make dev-reset` fixes it.

## Decisions (fixed)

- Compose is for local dev and tests only; nothing here is used in AWS.
- No real partner credentials in dev. Dev adapters log instead of sending (`SMS_PROVIDER=log`,
  `PUSH_PROVIDER=log`, `STORAGE_PROVIDER=local` serving `/dev/files/*`); `DEV_FIXED_OTP=123456` works in dev only.

## Planned additions (build order)

1. **MinIO** (Phase 0, with the backend S3 adapter). Service `minio` on 9000 (API) and 9001 (console), a one-shot
   `minio-init` that creates the media and audit buckets (Object Lock on audit). `.env.example` gets
   `STORAGE_PROVIDER=s3` settings pointing at it as an option; `local` stays the default.
   *Done when* a visit photo uploaded through a presigned URL lands in MinIO and the S3 adapter's integration test
   runs against it.
2. **Fake SMS with an inbox page** (Phase 0-1a). A fake from `tools/fakes/sms` that accepts the real adapter's
   API, stores messages, shows a mailhog-style web inbox (latest OTPs and links per phone, Telugu rendered), and
   posts signed delivery reports back to `/hooks/sms/{provider}`. *Done when* sign-in works with
   `SMS_PROVIDER=<vendor>` pointed at the fake and the OTP is read from the inbox.
3. **Fake push** (Phase 1a). Accepts FCM-shaped requests and lists them per device token. *Done when* an FA alert
   shows up there.
4. **Fake WhatsApp, Razorpay and payout** (Phase 1b-2, once vendors are chosen). Same pattern, including signed
   webhooks and failure modes (timeouts, declines, name mismatch for UPI).
5. **Profiles.** Keep `make dev-up` lean (Postgres + Redis); add a compose profile `partners` for MinIO and fakes
   (`docker compose --profile partners up -d --wait`) and a `make dev-up-all` target.

## Definition of done for the dev folder

`make dev-up && make migrate && make seed && make run-api` works on a clean machine; with the `partners` profile,
every outbound partner call in the backend has a local fake; `make dev-reset` always returns to a known state.
