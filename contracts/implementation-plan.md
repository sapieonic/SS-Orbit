# Contracts implementation plan

## Purpose

`contracts/openapi/` is the single source of the API. The Go server, the Flutter apps' Dart client and the React
apps' TypeScript client are all generated from it, so none of them can drift. This file says how to change a spec,
how each side is generated, and what is still missing (client generation, breaking-change checks).

## Read first

1. `backend/docs/CONVENTIONS.md` sections 4 (surfaces, errors, pagination) and 11 (generated code).
2. `backend/README.md` "Adding an endpoint".
3. `contracts/openapi/_shared_components.yaml` and `contracts/openapi/audit.yaml` (the reference spec).
4. `contracts/ENDPOINTS.md`: the generated list of all 138 operations by surface.
5. `mobile/implementation-plan.md` and `web/implementation-plan.md` for how each client package is used.

## Current state

- 8 specs, one per backend module, all OpenAPI 3.0.3, `info.version: 0.1.0`: `identity.yaml` (34 operations),
  `masters.yaml` (28), `messaging.yaml` (20), `farmers.yaml` (20), `geo.yaml` (18), `visits.yaml` (12),
  `sync.yaml` (4), `audit.yaml` (2). 138 in all.
- `_shared_components.yaml` is documentation only: its `bearerAuth`, `Limit`/`Cursor` parameters, `ErrorResponse`
  schema and error responses are **copied verbatim** into every spec. Specs don't `$ref` across files, because
  oapi-codegen builds one Go package per spec.
- Server code is generated and committed (`backend/internal/<module>/api.gen.go`); every request is validated
  against the embedded spec before the handler runs, so the spec is enforced at runtime.
- Client bundles are built: `tools/bundle-specs.py` writes `contracts/build/mobile.yaml` and `web.yaml`
  (committed). `make specs` (in `backend/`, or `make backend-specs` from the root) regenerates `ENDPOINTS.md` and
  both bundles. No schema name is defined differently in two specs.
- `sync.yaml` has typed, doc-only payload schemas for all 10 sync commands (`<Type>Payload`, indexed by
  `SyncCommandPayloads`), and the `Snap*` schemas match the snapshot the code writes (incl. `season_codes`,
  nullable crop/salt/SKU fields, `photo_key`). Snapshot JSON keys are pinned by backend tests.
- Not built: client generation, freshness checks for `ENDPOINTS.md` and the bundles in CI (`make check` covers
  only server code), oasdiff in CI, a lint for the specs.

## Decisions (fixed)

- Spec first: no endpoint exists until it is in a spec. Handlers implement the generated `StrictServerInterface`.
- One spec per backend module (the plan said per surface). Paths are absolute (`/v1/farmer/...`); the prefix
  decides who may call it. No `servers` block.
- OpenAPI 3.0.3, not 3.1 (the plan said 3.1): oapi-codegen doesn't support 3.1.
- Generated code is committed everywhere, and CI fails if regenerating changes anything.
- Dart client: openapi-generator `dart-dio` into `mobile/packages/orbit_api`. TypeScript client: orval with
  TanStack Query hooks into `web/packages/api-client` (plan, "What is shared, and how").
- No breaking changes to the mobile surfaces. Old app versions stay on farmers' phones for months. Changes are
  additive, or go to `/v2`. A forced update is the last resort.
- CODEOWNERS: `contracts/` needs a backend reviewer plus one client reviewer.

## Spec-first workflow

1. Edit `contracts/openapi/<module>.yaml`: path, operationId (camelCase, unique across all specs), summary, tags,
   request and response schemas, shared error responses (`$ref: '#/components/responses/BadRequest'` etc.), and
   `limit`/`cursor` + `{items, next_cursor}` for lists. Describe new error codes in the operation description.
2. `cd backend && make gen` regenerates `api.gen.go` (and sqlc). The build fails until the handler implements
   the new method.
3. `make specs` (in `backend/`; `make backend-specs` from the root) rewrites `contracts/ENDPOINTS.md` and the two
   bundles in `contracts/build/` (needs PyYAML). It fails if two specs define the same schema name with different
   bodies, or the same path or operationId.
4. Regenerate the clients (commands below) in the same PR, or in a follow-up PR before any client uses it.
5. CI: `make check` (server freshness), then the oasdiff check (to build) and client freshness checks.

## Server generation (built)

`make gen` runs `go generate ./internal/...`. Each module has `generate.go` with
`//go:generate go tool oapi-codegen -config oapi-codegen.yaml ../../../contracts/openapi/<module>.yaml` and an
`oapi-codegen.yaml` with `models`, `chi-server`, `strict-server`, `embedded-spec`. oapi-codegen is pinned as a Go
tool in `backend/go.mod` (v2.8.1). Type mapping rules are in CONVENTIONS section 11 (`format: uuid` →
`uuid.UUID`, optional or nullable → pointer, mark always-present-but-nullable fields `required` + `nullable`).
`x-go-type` is used in `sync.yaml`; other generators ignore it.

## Client generation (to build)

Clients need one input file each, so the module specs are bundled first.

### Step 1: bundle (built)

`tools/bundle-specs.py` merges the module specs into `contracts/build/mobile.yaml` (paths under `/v1/auth/`,
`/v1/farmer/`, `/v1/fa/`, `/v1/web/`; farmer and FA apps) and `contracts/build/web.yaml` (`/v1/auth/`,
`/v1/admin/`, `/v1/web/`; HO portal and farmer web pages), keeping only the components those paths reach plus
`SyncCommandPayloads` in the mobile bundle. Both were checked with kin-openapi when built. The script fails on a
schema name used by two specs with different bodies; fix a clash at the source by renaming (names are not on the
wire). The earlier clashes are renamed: farmers `Village` -> `FarmerVillage`, `FARef` -> `FarmerFARef`, `FACard`
-> `FarmerFACard`; visits `LatLng` -> `VisitLatLng`. `python3 tools/bundle-specs.py --check` exits 1 when the
committed bundles are stale; add it to CI with a freshness check for `ENDPOINTS.md`. To split differently (for
example one bundle per app), change only the `BUNDLES` surface list in the script.

### Step 2: Dart (`mobile/packages/orbit_api`)

```sh
docker run --rm -v "$PWD:/local" openapitools/openapi-generator-cli:<pinned v7.x> generate \
  -i /local/contracts/build/mobile.yaml -g dart-dio -o /local/mobile/packages/orbit_api \
  --additional-properties=pubName=orbit_api,serializationLibrary=json_serializable,enumUnknownDefaultCase=true
cd mobile/packages/orbit_api && dart run build_runner build --delete-conflicting-outputs
```

Wrap it in a Melos script (`melos run gen:api`). Phase 0 spike: check that the `allOf: [$ref] + nullable: true`
pattern (used for nullable objects, for example `Season`, `Stage`, `FarmerVillage` in `farmers.yaml`) generates usable
nullable Dart types, and that unknown enum values and unknown fields don't throw.

### Step 3: TypeScript (`web/packages/api-client`)

`web/packages/api-client/orval.config.ts` with `input: '../../../contracts/build/web.yaml'`, `client:
'react-query'`, `mode: 'tags-split'`, and a custom fetch mutator that adds the bearer token and maps the shared
error shape. Run with `pnpm --filter api-client exec orval`, wrapped as `pnpm gen:api`.

### Notes for client builders

- Sync command payloads: `CommandIn.payload` stays free-form on the wire (`x-go-type: json.RawMessage`); the
  `<Type>Payload` schemas are documentation for codegen, and each owning module stays the validator.
- The `Snap*` schemas are not validated by the server at runtime; backend tests pin the snapshot keys, so change
  both together.
- Forced update: `GET /v1/auth/app-config?app=farmer|fa` (no token) and the device heartbeats return
  `min_version`; heartbeats also return `update_required`.

## Breaking-change check (to build, Phase 0)

A CI job on every PR touching `contracts/**`, per module spec, comparing with `main`:

```sh
for f in contracts/openapi/[a-z]*.yaml; do
  git show origin/main:"$f" > /tmp/base.yaml 2>/dev/null || continue   # new spec: nothing to compare
  oasdiff breaking /tmp/base.yaml "$f" --fail-on ERR \
    --match-path '^/v1/(farmer|fa|auth|web)/'
done
```

The agreed scope is `/v1/farmer` and `/v1/fa`. This plan also adds `/v1/auth` (both apps sign in through it) and
`/v1/web` (SMS links stay live for 7 days); drop them if the team disagrees. `/v1/admin` changes are reported as
warnings only: the HO portal ships with the backend. Pin the oasdiff version (`go install
github.com/oasdiff/oasdiff@<version>` or its GitHub Action). Wrap it as `tools/check-breaking.sh` so it runs the
same locally. An override needs a label (for example `breaking-approved`) plus the tech lead's review.

## Versioning rules

- The URL carries the major version (`/v1`). A breaking change on a mobile surface gets a new operation or a `/v2`
  path; `/v1` keeps working until the minimum supported app version is past it.
- Bump `info.version` in the changed spec: minor for additions, patch for wording. Clients don't depend on it.
- Additive means: new paths, new optional request fields, new response fields. Clients must ignore unknown fields
  and unknown enum values (generator settings above). Adding a required request field, removing or renaming a
  field, narrowing a type or a pattern, or changing an error code is breaking.
- Error codes (`validation_failed`, `version_mismatch`, `device_revoked`, `password_change_required`, ...) and
  sync rejection reasons (`registered_with_another_fa`, `not_in_your_area`) are part of the contract.
- Deprecate with `deprecated: true` and a removal note in the description; remove only after the check above
  allows it.

## 3.0.3 vs 3.1

Stay on 3.0.3 until oapi-codegen supports 3.1, then move all specs at once. In 3.0.3:
- nullable is `nullable: true`, not `type: [string, 'null']`;
- a nullable reference is `allOf: [{$ref: ...}]` + `nullable: true` (siblings next to `$ref` are ignored);
- use `example`, not `examples`; a constant is a one-value `enum`;
- no `webhooks` section: partner callbacks are ordinary paths under `/hooks/`.

## Build order

1. **Phase 0 (wk 0-4):** (schema renames, `tools/bundle-specs.py`, committed bundles and sync payload schemas are
   done.) `bundle-specs.py --check` and `ENDPOINTS.md` freshness in CI; Dart and TS generation wired with freshness
   checks; oasdiff job; a spec lint (Spectral or Redocly)
   for operationId uniqueness, snake_case properties and shared error responses on every operation.
   *Done when* a PR that removes a field from a `/v1/fa/` response fails CI, and both clients regenerate cleanly.
2. **Phase 1a/1b:** every backend backlog item lands spec first (adapters webhooks, templates, CSV, hand-over,
   `Idempotency-Key` header, calendar, weather, Add farmer, phone change, and the smaller additions in backend
   items 12 and 18). *Done when* `ENDPOINTS.md` lists them.
3. **Phase 2:** new specs per new module (`plans`, `services`, `invoices`, `payouts`) with Razorpay and payout
   webhooks under `/hooks/`. *Done when* the clients use them through the generated packages only.

## Open decisions

- Whether `/v1/auth` and `/v1/web` are inside the breaking-change gate (recommended).
- PATCH semantics for clearing optional fields (explicit `null`), before more PATCH endpoints are added.

## Definition of done for the contracts folder

- Every backend route is in a spec; `ENDPOINTS.md` and the bundles are fresh (CI checks).
- Server, Dart and TS code are generated from these files only, and CI fails if any is stale.
- oasdiff blocks breaking changes on the mobile surfaces.
- No schema name collisions across specs; sync command payloads are typed in `sync.yaml`.
