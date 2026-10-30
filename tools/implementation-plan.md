# Tools implementation plan

## Purpose

`tools/` holds repo-wide scripts that don't belong to one toolchain: generators that read the single sources
(`contracts/`, `design/`, `i18n/`), CI checks, and dev helpers. Toolchain-specific commands stay in their own
workspace (`backend/Makefile`, Melos scripts in `mobile/`, pnpm scripts in `web/`); those may call into `tools/`.

## Read first

1. `tools/list-endpoints.py` and `tools/bundle-specs.py` (copy their style), `tools/smoke_test.py` (usage in its
   docstring).
2. `contracts/implementation-plan.md` (bundles, client codegen, oasdiff).
3. `dev/implementation-plan.md` (fake partners) and `backend/implementation-plan.md` (seed data).

## Current state

| Tool | What it does | Run |
|---|---|---|
| `list-endpoints.py` | Reads `contracts/openapi/*.yaml` (skips `_*.yaml`) and writes `contracts/ENDPOINTS.md`: every operation grouped by surface (auth, farmer, FA, HO, web, hooks); 138 today | `python3 tools/list-endpoints.py` from anywhere (paths resolve from the script). Needs PyYAML |
| `bundle-specs.py` | Merges the module specs into `contracts/build/mobile.yaml` (`/v1/auth/`, `/v1/farmer/`, `/v1/fa/`, `/v1/web/`) and `contracts/build/web.yaml` (`/v1/auth/`, `/v1/admin/`, `/v1/web/`), keeping reachable components; fails on a schema name with two bodies, a duplicate path or operationId, or a broken `$ref` | `python3 tools/bundle-specs.py` (write) or `--check` (exit 1 if stale). Needs PyYAML |
| `smoke_test.py` | End-to-end flow against a running dev API + worker with seed data: farmer OTP + home, self sign-up + village, FA login, snapshot + ETag, enrol + visit by sync, inbox, call-back -> FA alert, HO login with TOTP, admin reads and advisory preview, merge and NUL-payload sync checks, device revoke, wrong surface | From the repo root after `make dev-up`, `make migrate`, `make backend-seed`, with `make backend-run-api` and `make backend-run-worker` running: `python3 tools/smoke_test.py`. Env `ORBIT_API`, `ORBIT_PG_CONTAINER`. Dev only (fixed OTP, seed logins, `docker exec` into Postgres); safe to rerun |

`make specs` (in `backend/`; `make backend-specs` from the root) runs the first two. Nothing in CI checks yet that
`ENDPOINTS.md` and the bundles are fresh. Dev seed data lives in the backend (`make seed`, `cmd/seed`), not here.

## Decisions (fixed)

- The plan puts "generator scripts; fake Razorpay, SMS, WhatsApp, payout servers" in `tools/`.
- Generated output is committed; every generator has a CI freshness check (regenerate, `git diff --exit-code`).
- Makefile in `backend/`, not Taskfile (the plan said Taskfile). The root `Makefile` forwards `backend-<target>`.

## Tools to add

In build order. Phase 0 is weeks 0-4 from 9 Nov 2026.

1. **Bundle check in CI** (Phase 0). `bundle-specs.py` is built; add `python3 tools/bundle-specs.py --check` and an
   `ENDPOINTS.md` freshness check to CI. *Done when* a spec change without `make specs` fails CI and the Dart and
   TS generators accept both bundles.
2. **`check-breaking.sh`** (Phase 0). oasdiff wrapper: compares each `contracts/openapi/<module>.yaml` with
   `origin/main`, `--fail-on ERR` for `^/v1/(farmer|fa|auth|web)/`, warnings for `/v1/admin/`. Same script locally
   and in CI. Pins the oasdiff version. *Done when* removing a field from an FA response fails it.
3. **`gen-clients.sh`** (Phase 0). Runs `make -C backend specs` (ENDPOINTS.md + bundles), then `melos run gen:api`
   and `pnpm gen:api`. One command after any spec change. *Done when* a clean checkout regenerates with no diff.
4. **`check-generated.sh`** (Phase 0). CI helper: runs a generator and fails with a clear message if
   `git status --porcelain` shows changes. Used for `ENDPOINTS.md`, bundles, clients, design tokens and strings.
5. **Fake partners** (Phase 0-1a, with the backend adapters). Small Go or Python servers under
   `tools/fakes/<partner>/`: SMS (accepts sends, keeps an inbox page, posts signed delivery reports to
   `/hooks/sms/{provider}`), FCM (accepts pushes, shows them), later WhatsApp, Razorpay and payout. Run from
   `dev/docker-compose.yml`. *Done when* the backend runs end to end locally with real adapter code pointed at
   fakes, and no developer needs vendor credentials.
6. **Smoke test on staging** (Phase 1a). `tools/smoke_test.py` is in the repo but dev-only: it relies on
   `DEV_FIXED_OTP`, the seed logins and `docker exec` into the compose Postgres. Make a staging mode (OTP read
   from the fake SMS inbox or a test-number hook, no direct DB access, `ORBIT_API` pointing at staging) and extend
   it to the round-2 features (app-config, consent before village, farmer photo upload). *Done when* the deploy
   workflow runs it against staging.
7. **Fixture and seed helpers** (Phase 1a). Generate realistic test data at pilot scale (5,000 farmers, 25 FAs,
   villages from a CSV) through the public API or sync commands, never by writing tables directly; useful for load
   tests of the snapshot. Refuses `ORBIT_ENV=prod`. *Done when* a staging territory of a few hundred farmers can be
   built in minutes.
8. **Telugu string lint** (Phase 1a, with `i18n/`). Checks `i18n/te.json` and `en.json` have the same keys, no
   empty Telugu values, matching `{placeholders}`, every key has a voice prompt under `i18n/voice/te/` where one is
   required, and no competitor brand names (list kept with Agronomy). *Done when* it runs in CI for `i18n/**`.
9. **Design token build** (Phase 0, owned with the design plan). Style Dictionary run from `design/tokens/` to
   the Dart and CSS outputs, plus its freshness check.
10. **SMS template check** (Phase 1a). A script that compares `sms.All()` (`backend/internal/platform/sms/templates.go`;
    later the DB rows) against the DLT portal export (template ID, text with `{#var#}`) and fails on any
    placeholder ID before a release.
11. **Staging back-dating tool** (Phase 1a, backlog). Moves a staging record's timestamps back so time-based
    journeys (missed visits, FA offline, season-code boundary, temp password expiry) can run without waiting.
    Refuses anything but staging and dev.

## Conventions for scripts

- One purpose per script; a docstring or header comment with what it does and how to run it, as in
  `list-endpoints.py`.
- Resolve paths from the script's location (`pathlib.Path(__file__).resolve().parent.parent`), so it works from any
  directory.
- Python 3 with the standard library plus PyYAML only; shell scripts in bash with `set -euo pipefail`. Anything
  heavier (oasdiff, openapi-generator) is pinned and run through `go install`, Docker or the toolchain workspace.
- Deterministic output (sorted keys and rows) so freshness checks don't flap.
- Exit non-zero on any problem, with a message that says how to fix it.
- Never read or print secrets; never talk to prod. Anything that writes data refuses `ORBIT_ENV=prod`.
- Add a line for each new tool to the "Current state" table above.

## Open decisions

- Language for fake partners (Go keeps one toolchain with the backend; Python is quicker to write).

## Definition of done for the tools folder

Every generator has a freshness check in CI, every script runs from a clean checkout with the documented
command, and a new developer can run the whole stack, the smoke test and the generators without vendor
credentials.
