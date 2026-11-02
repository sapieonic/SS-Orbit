# FA app data layer

Domain models, one repository interface per concern, one mock server file, Riverpod providers that pick mock
or API, and the session state the router reads. Today the app runs on mock data; an `Api*Repository` set drops
in later with no change to screens, the offline engine or the session controller.

## Layout

```
lib/src/data/
├─ data.dart                    # the only data import screens need (plus local/local.dart)
├─ helpline.dart                # hoHelplineNumber: the one HO helpline (screens use shared/helpline.dart)
├─ models/                      # immutable app models mirroring the OpenAPI schemas (FA -> Fa); snapshot JSON both ways
├─ repositories/                # abstract interface classes, one method per FA endpoint
├─ mock/mock_backend.dart       # the mock server: ALL mock data and rules + every Mock*Repository (one file)
├─ providers.dart               # Riverpod: env -> repository set -> *RepositoryProvider, mockScenarioProvider
└─ session/
   ├─ session_store.dart        # SessionStore + InMemorySessionStore, StoredSession, PinRecord, SessionMeta
   ├─ auth_failures.dart        # AuthFailureHook: failed signed-in calls -> session
   ├─ session_phase.dart        # SessionPhase (router source of truth)
   ├─ session_controller.dart   # sessionProvider
   ├─ pin_lock.dart             # PIN hashing and checks
   └─ local_data_guard.dart     # what the session needs from the offline engine (count, push, wipe)
```

```
Screens ── territoryProvider / FaActions (local/) ── sync engine
                                                       │ ref.watch(syncRepositoryProvider) (interfaces only)
SessionController ── faAuthRepositoryProvider          ▼
                     faRepositoriesProvider ── buildFaRepositories(OrbitEnv, SessionStore)
                                │                                   │
                          DataSource.mock                     DataSource.api
                                ▼                                   ▼
                  MockBackend.repositories(store)      Api*Repository set (not built yet)
                  one in-memory server state           generated orbit_api + dio, maps DTO -> model
```

Rules:
- Screens import `package:fa/src/data/data.dart` and `local/local.dart`. Most screens never call a repository:
  they read `territoryProvider` and write through `FaActions`. Online-only steps (phone lookup, consent OTP,
  farmer photo URL, the alerts list) use the `*RepositoryProvider`s. Never `Mock*` classes: `data.dart`
  exports `MockScenario` for the dev screen and `MockBackend` only because bootstrap and tests pass one to
  `faDataOverrides(mockBackend:)`.
- The mock is never built into staging or prod: `mockBuildAllowed` is false for `--flavor staging|prod`
  (`appFlavor` is a compile-time constant), so every branch that creates a `MockBackend` is dead code there and
  the tree shaker drops the mock world and its logins.
- Every repository method is `Future<Model>` and throws only `ApiError` (orbit_core); `ApiError.network()`
  when nothing reached the server. Switch on `error.code` with `ApiErrorCode` constants and show our own
  Telugu/English text.
- Each method's dartdoc names its exact endpoint and the error codes it can throw.
- Per-command outcomes (`applied`, `merged`, `conflict`, `rejected`) are results, not errors. A rejected
  command's `error` is a code (`registered_with_another_fa`, `not_in_your_area`, `server_could_not_apply`)
  or an English sentence from the server; map the codes, show the sentence only as a fallback.
- The auth repository owns the token store: `login` saves the `StoredSession` and the last online contact,
  `refreshSession` saves the rotated pair (and the must-change flag the new token carries) and the last online
  contact, `logout` clears the store first (session, PIN, session meta, last online; language, install ID
  and `SessionMeta.lastOwner` stay) and then tells the server, best effort. Every other repository reads the access token from the store.
- Repositories report every `ApiError` of a signed-in call to the `AuthFailureHook`; login and app config are
  not signed-in calls and are not reported.
- Date-only fields (`plannedFor`, `sowingDate`, `validUntil`) are `LocalDate`; times are UTC `DateTime`.

## Auth failures

`AuthFailureHook` (`authFailureHookProvider`) is the one place a failed call reaches the session.
Repositories call `hook.report(error, faId: session.faId, sessionKey: session.signInKey)` with the
`StoredSession` the call was made with (read when it started); `SessionController` listens:

| Error | Hook test | What happens |
|---|---|---|
| 401 `device_revoked` | `isDeviceRevoked` | phone removed: local data, tokens, PIN and install ID wiped (`removed`) |
| any other 401 (`unauthorized`, `refresh_reused`, `session_revoked`, `temp_password_expired`) | `endsSession` | password needed (`passwordNeeded`); outbox and local data kept |
| 403 `password_change_required` | `needsPasswordChange` | back to the password change |
| anything else | | ignored here; the caller shows or retries it |

The mock repositories report from one wrapper (`_MockRepository._signedIn`). The API implementation must do
the same in its dio client (step 2 below).

## Run with mock data

Mock data is the default in the dev flavour:

```bash
flutter run --flavor dev                                                # mock, normal
flutter run --flavor dev --dart-define=ORBIT_MOCK_SCENARIO=offline      # start offline
flutter run --flavor dev --dart-define=ORBIT_MOCK_LATENCY_MS=0          # no fake latency
```

### Logins

| Login ID | Password | What happens |
|---|---|---|
| `FA-KDP-014` | `orbit2026` | Suresh Kumar, 98480 12345, Kondapur and Gachibowli (Serilingampally, Rangareddy). The main mock world |
| `FA-KDP-099` | `temp1234` | temporary password: `mustChangePassword`; every `/v1/fa/*` call is 403 `password_change_required` until the password is changed and the session refreshed |
| `FA-KDP-077` | `temp5678` | temporary password older than 72 hours: 401 `temp_password_expired` |
| `FA-CVL-002` | `chevella2026` | Lakshmi P, Chevella mandal: owns the `other_fa` farmers |
| anything else | | 401 `unauthorized` (same message for an unknown ID, a wrong password or an inactive login) |

Consent OTP (and anything OTP-like): `123456`. The consent proof is valid for 7 days. HO helpline 1800 123 4567.

### The world (dates are relative to the device's today)

- 46 farmers of Suresh in Kondapur and Gachibowli (61 plots, some with walked boundaries, pins near the village
  centres), with seasons sown so stages match the designs. The named ones: **Ravi K** (9000000101, cotton,
  Plot 1 2 ac 4 gunta, flowering, last visit 12 days ago with pink bollworm and Sample 5 SG, asked for a
  call-back 25 min ago), **Venkatesh M** (9000000102, paddy), **Venkat R** (cotton, visit due in 2 days),
  **Padma S** (premium, paddy, 34 days since visit; Plot 2 is the conflict case), **Lakshmi N** (self sign-up
  yesterday, maize), Gopi M, Anil G (red gram), Sita R (chilli), Kumar B (enrolled without consent:
  `consent_pending`).
- Visits: Ravi K (morning) and Venkatesh M (afternoon) planned today, Sita R done today; Lakshmi N and Gopi M
  done yesterday; more planned over the next 3 days; done visits with advice (Shanmukha SKU, salt only, or
  unresolved) for most farmers.
- Alerts: Raju P new farmer (10 min), Ravi K call-back, two invoice checks (the UI hides them), the HO note
  "Please finish pending enrolments in Kondapur by Friday", plus acknowledged and closed older ones.
- Masters: cotton, paddy, chilli, maize, red gram with Telugu names and stage calendars; issues per crop;
  salts; SKUs "Sample 5 SG", "Sample Guard 17.8", "Sample 50 WG", "Sample Nutri K"; approved rules, some with a
  SKU and some salt only; season codes from the clock (orbit_core `seasonCodesOn`).
- IDs that the dev seed also has (villages, FA Suresh and FA-CVL-002, crops, stages, seed salts, SKUs, issues
  and rules, Ravi K and Venkatesh M with their plots and seasons) are the seed's UUIDv5 values
  (`MockBackend.sid`), so mock and dev data line up.

### Phone lookup and enrolment

| Phone | Lookup | EnrolFarmer |
|---|---|---|
| any new number | `new` | `applied` (village must be Kondapur or Gachibowli, else `not_in_your_area`) |
| 9000000101 (Ravi K) and Suresh's other farmers | `mine` | `merged`, `merged_into` = the farmer's ID (`applied` only when `farmer_id` is already that ID). The app refuses it locally (`alreadyEnrolled`) |
| 91234 56780 (Raju P, self sign-up, no FA) | `unassigned_in_my_area` | `merged`, `merged_into` = Raju's ID; he becomes Suresh's |
| 9000000201 (Narsimha G, FA-CVL-002) | `other_fa` | `rejected` `registered_with_another_fa` |
| 9000000301 (Srinivas D, Madhapur, no FA) | `outside_my_area` | `rejected` `not_in_your_area` |
| 9000000302 (Mallesh T) | `deactivated` | `rejected` (deactivated by HO) |

### Mock against backend

Where the backend has a rule the app would otherwise meet only on the real API, the mock has it too:

- **Boundaries** (`farmers/service_plots.go` `measurePlot`): a `boundary_geojson` that does not parse, or an
  open ring or one with fewer than 4 positions, is rejected `boundary_geojson: not a valid GeoJSON polygon`;
  another geometry type `boundary_geojson: must be a Polygon`; a ring that crosses or touches itself, folds
  back on itself or has no area (PostGIS `ST_IsValid`) `boundary_geojson: boundary crosses itself; walk it
  again`. A rejected SavePlot drops the StartSeason, PlanVisit and LogVisit queued behind it.
- **Text limits are UTF-8 bytes**, as Go `len()` counts them: plot `label` 60, `name` 100, UpdateFarmer
  `name_te` 300 (blank or longer: `name_te: must not be blank`). A Telugu letter is 3 bytes, so a label of 21
  Telugu letters is rejected. Backend fix to suggest: count characters (`utf8.RuneCountInString`) so the
  limits mean what the app shows.
- **Missed visits** (`visits/jobs.go` `MarkMissed`, hourly): before every call the mock turns planned visits
  dated before today (IST) into `missed` and moves the FA's territory version. A missed visit can still be
  re-planned (PlanVisit, same ID), logged or cancelled.
- **Snapshot alerts** (`messaging` `ListSnapshotFAAlerts`): not closed, created in the last 30 days, newest
  first, at most 200 (`MockBackend.snapshotAlertDays`, `snapshotAlertLimit`).

Where the mock differs on purpose:

- **Proposed contract, not the backend yet:** the snapshot's `visits` section also carries `missed` visits
  planned in the last 14 days (`MockBackend.snapshotMissedDays`), so the app can show them as overdue and the
  FA can move or log them. The real snapshot sends planned and done visits only, so a missed visit drops out
  of the phone at the next pull. See "Not done yet" in `mobile/README.md`.
- Stricter: a brand-new phone enrolled into a village outside the FA's area is rejected `not_in_your_area`
  (the backend checks the area only when merging an unassigned farmer).
- The mock closes `new_farmer` and `callback` alerts; the backend never closes FA alerts (`mobile/README.md`).

### Commands

`submitCommands` applies each command in order with the backend's rules (`backend/internal/farmers/commands*.go`,
`visits/commands.go`, `visits/service_log.go`, CONVENTIONS section 6): a command ID already stored returns its
stored result (another FA's ID is rejected); every applied or merged command bumps the territory version, so
the ETag (`"t{territory}-m{masters}"`) changes. Conflicts: SavePlot with a stale `expected_version`
(`area_acres`, `label`, `boundary` or `version` with yours/theirs), UpdateFarmer whose changed field differs
on the server, StartSeason on a plot with an active season (`active_season`). Rejections use the backend's
sentences (`this farmer is not assigned to you`, `visited_at is in the future`, `unknown command type "X"`,
`invalid payload: ...`). A LogVisit closes the farmer's open call-back (and its alert); an issue whose rule is
missing or for another issue is stored unresolved, never rejected. Merge aliases are followed, so commands
queued under the ID the phone minted keep working after a `merged` EnrolFarmer.

### Scenarios

`MockScenario`, switched at runtime from the dev screen (or `ORBIT_MOCK_SCENARIO`):

| Scenario | Behaviour |
|---|---|
| `normal` | the seeded world |
| `offline` | every call throws `ApiError.network()` |
| `slowNetwork` | every call takes 4 s |
| `serverError` | every call is 503 `unavailable` |
| `deviceRemoved` | the devices signed in so far are revoked: heartbeat answers `wipe: true`, every other call (refresh, and login with that install ID) is 401 `device_revoked`; a new install ID signs in. Selected before any sign-in, the first device that signs in is removed |
| `updateRequired` | heartbeat and app config say `min_version` 1.0.5 (`updateRequired` for 0.1.0) |
| `syncConflict` | the next SavePlot or UpdateFarmer for Padma S (Plot 2) conflicts: HO changed it meanwhile (Plot 2 becomes 2 ac 0 gunta) |
| `partialFailure` | the next command batch stops half way with `retry_from` |
| `sessionExpired` | the sessions signed in so far ended: refresh and every call are 401 `unauthorized` (PIN still opens local data; syncing needs the password, and a new login works) |

```dart
final current = ref.watch(mockScenarioProvider);          // null on the API: hide the switch
ref.read(mockScenarioProvider.notifier).select(MockScenario.syncConflict);
ref.read(mockScenarioProvider.notifier).resetData();       // reload the server seed (drops tokens too)
```

Dev and test helpers on `MockBackend`: `latency`, `reset()`, `hoEditPlot(plotId, areaAcres:, label:)` (HO edits
a plot: version and territory bump), `addAlert(...)` (an HO note or any alert), `addCallback(farmerId)`, and
read access to server state (`serverFarmers`, `serverPlots`, `serverSeasons`, `serverVisits`,
`serverCallbacks`, `openCallbacks`, `serverAlerts`, `farmerByPhone`, `territoryVersion`, `storedResult`,
`uploadedObjects`). Phones and IDs of the mock world are constants on `MockBackend` (`raviPhone`, `raviId`,
`padmaPlot2Id`, `kondapurId`, ...).

Photo upload URLs point at `MockBackend.mockHost` (`mock.orbit.invalid`, never resolves); the mock
`PhotoUploader` accepts a PUT to a URL the mock handed out within its 15 minutes, so `confirmUpload` then
finds the object (`upload_missing` before, `photo_already_uploaded` for a new URL after).

What the mock does not simulate: per-IP rate limits, access-token expiry (tokens never expire, only end),
gzip, invoice checks, push, an FA deactivated by HO (the backend revokes the FA's devices, so the app gets
`device_revoked` and wipes).

The camera, GPS and network (`device/`) are mocks too, and only on mock data: on the API,
`photoCaptureProvider`, `locationServiceProvider` and `connectivityProvider` throw `UnimplementedError` naming
the plugin still needed (`image_picker`, `geolocator`, `connectivity_plus`), so real data never gets generated
photos or scripted GPS.

## Swap to the real API

1. **Generate `orbit_api`.** From the repo root: `make backend-specs`, then the openapi-generator command in
   `mobile/implementation-plan.md` ("Generated API client") into `mobile/packages/orbit_api`; add it to the
   workspace and to `apps/fa/pubspec.yaml`.
2. **HTTP client.** Build a dio client from `OrbitEnv.apiBaseUrl`: an auth interceptor that reads the access
   token from `SessionStore`, a single-flight refresh `QueuedInterceptor` (it calls `POST /v1/auth/refresh` on
   its own dio and writes the new pair and `writeLastOnlineAt` to the store), timeouts 20 s / 60 s (longer for
   the snapshot).
   **One refresher for everything.** `ApiFaAuthRepository.refreshSession()` must join that same single flight
   (return the interceptor's in-flight `Future<TokenPair>`, or start it), never send its own
   `POST /v1/auth/refresh`: the session controller calls it after the first-login password change, and two
   refreshes racing with the same refresh token can land out of order and revoke the whole family
   (`refresh_reused`). The refresher, and only it, writes the rotated pair: `StoredSession.withTokens(pair,
   mustChangePassword: <the new access token's pwc claim>)`, which keeps `signInKey`. Decode `pwc` from the
   JWT; the controller no longer rewrites the pair or the flag after a refresh, it reads them back. Save the
   pair before using it, and on a network failure retry the same old refresh token at most until 50 s after
   the first try (the server's 60 s grace), then treat the session as lost. A refresh answer that arrives
   after a logout (the store has no session, or another `signInKey`) must not be written.
   **One time base.** `writeLastOnlineAt` takes the device clock (`clockProvider.now()`), never the server's
   `Date` or `server_time`: the session compares it with the device clock and with
   `SessionMeta.lastSeenAt` (the latest device time seen; a clock set more than 10 minutes behind it ends
   the PIN's offline grace). Map every failure to `ApiError`: a response -> `ApiError.fromResponse(status, data,
   retryAfterHeader: headers['retry-after'])`; no response or timeout -> `ApiError.network(timeout: ...)`.
   **Report failures:** after the mapping (and after a refresh failed, for a 401), call
   `authFailures.report(error, faId: session.faId, sessionKey: session.signInKey)` for signed-in calls, with
   the `StoredSession` whose token the request sent. Pass the hook in from `buildFaRepositories(..., authFailures:)`.
3. **Write the `Api*Repository` classes** in `lib/src/data/api/`, one per interface. Each method calls the
   generated operation named in its dartdoc and maps DTO -> model in `api/mappers.dart`. The snapshot is not
   generated (its sections are documentation-only schemas): fetch it with `ResponseType.bytes` and parse it
   with `Snapshot.fromJson` off the UI isolate. Do not inflate it yourself: dio's IO adapter uses `HttpClient`,
   which sends `Accept-Encoding: gzip` and already inflates a `Content-Encoding: gzip` body (`autoUncompress`
   is on by default), so a second `gzip.decode` throws. The ETag comes from the response header; 304 is
   `SnapshotNotModified`. Command results parse with `CommandBatchResult.fromJson`. `ApiPhotoUploader` PUTs
   with exactly the target's method, URL and headers on a plain dio (no auth interceptor).
4. **Select it.** In `buildFaRepositories`, replace the `DataSource.api` branch with the Api set (given
   `authFailures`), and swap `InMemorySessionStore` for a `flutter_secure_storage` implementation of
   `SessionStore` in `sessionStoreProvider`. Every store field is one key: the session and PIN as JSON
   (`StoredSession.toJson` / `fromJson` and `PinRecord.toJson` / `fromJson`; `TokenPair`, `FieldAssistant`
   and `OfflinePolicy` nest in the spec's shape),
   language, last online contact and install ID as strings, and each `SessionMeta` field as listed in its
   dartdoc (`session.phase`, `session.password_needed_reason`, `session.update_min_version`,
   `session.session_ended`, `session.clean_token_pending`, `session.update_from_heartbeat`,
   `session.password_change_sent`, `session.wipe_pending`, `session.last_seen_at`, `owner.fa_id` /
   `owner.code` / `owner.name`). `StoredSession.signInKey` is part of the session JSON.
   `clear()` deletes all but the language, install ID, `owner.*` and `session.wipe_pending` keys (all but the
   language and `session.wipe_pending` with `wipeDeviceKey`). Nothing else changes.
5. **Run the contract suite against a dev backend.** From the repo root: `make dev-up && make migrate &&
   make backend-seed`, then `make backend-run-api`. `backend/.env`, made from `.env.example`, sets
   `DEV_FIXED_OTP=123456` (the dev seed's FA password is `fa-dev-pass`). Then add
   `test/data/api_repository_contract_test.dart`:

   ```dart
   @Tags(['dev-backend'])
   library;

   void main() {
     const base = String.fromEnvironment('ORBIT_CONTRACT_BASE_URL');
     runRepositoryContract('api', () async {
       final store = InMemorySessionStore();
       final hook = AuthFailureHook();
       final env = OrbitEnv.parse(flavor: 'dev', dataSource: 'api', apiBaseUrl: base);
       return ContractHarness(
         repos: buildFaRepositories(env, store, authFailures: hook),
         store: store,
         authFailures: hook,
         fixture: ContractFixture.devSeed(),
       );
     });
   }
   ```

   ```bash
   flutter test --run-skipped --tags dev-backend test/data/api_repository_contract_test.dart \
     --dart-define=ORBIT_CONTRACT_BASE_URL=http://localhost:8080
   ```

   `dart_test.yaml` skips the `dev-backend` tag by default, so CI and `flutter test` without a backend stay
   green. The suite asserts only what the dev seed guarantees (FA-KDP-014 signs in; the snapshot has
   Kondapur, Ravi K and masters; ETag and 304; idempotent commands; lookup of a new number; consent OTP
   `123456`) and checks that signed-in 401s reach the `AuthFailureHook`. Each run enrols a few random phones
   in Kondapur; to start the dev data over: `make backend-dev-reset`, then `make dev-up migrate backend-seed`.
6. **Run the app on the API:** `flutter run --flavor dev --dart-define=ORBIT_DATA_SOURCE=api` (the Android
   emulator reaches the host at `10.0.2.2:8080`). This also needs the platform camera, GPS and network
   behind `PhotoCapture`, `LocationService` and `ConnectivityService` (`image_picker`, `geolocator`,
   `connectivity_plus`): until then those providers throw on the API. Staging and prod always use the API and
   need real base URLs in `OrbitEnv` first.

## Tests

```bash
cd mobile/apps/fa
flutter test test/data          # mock server rules, contract suite on the mock, session
flutter analyze --fatal-infos
```

`test/support/mock_support.dart` has `MockWorld` (a mock server with no latency and a fixed clock, 2 Nov 2026
10:30 IST, a store and a hook; `MockWorld.signedIn()`, `push(payloads)`, `snapshot()`, `overrides()` for a
`ProviderContainer`).
