# Farmer app data layer

Domain models, one repository interface per concern, one mock implementation file, Riverpod providers that pick
mock or API, and the session state the router reads. Today the app runs on mock data; an `Api*Repository` set
drops in later with no change to screens or controllers.

## Layout

```
lib/src/data/
├─ data.dart                    # the only import screens need
├─ models/                      # immutable app models (not JSON DTOs)
├─ repositories/                # abstract interface classes, one method per endpoint
├─ mock/mock_backend.dart       # ALL mock data + every Mock*Repository (one file)
├─ providers.dart               # Riverpod: env -> repository set -> *RepositoryProvider
└─ session/
   ├─ session_store.dart        # SessionStore interface + InMemorySessionStore
   ├─ session_phase.dart        # SessionPhase (also saved in the store)
   ├─ auth_failures.dart        # AuthFailureHook: failed calls -> session
   └─ session_controller.dart   # sessionProvider (routing source of truth)
```

```
Screens / controllers
        │  ref.watch(xxxRepositoryProvider)       (interfaces only)
        ▼
farmerRepositoriesProvider ── buildFarmerRepositories(OrbitEnv, SessionStore)
        │                                   │
   DataSource.mock                    DataSource.api
        ▼                                   ▼
MockBackend.repositories(store)     Api*Repository set (not built yet)
   one in-memory state                generated orbit_api + dio, maps DTO -> model
```

Rules:
- Screens and controllers import `package:farmer/src/data/data.dart` and use the `*RepositoryProvider`s,
  `sessionProvider` and the models. Never `Mock*` classes: `data.dart` exports `MockScenario` for the dev switch
  and `MockBackend` only because bootstrap and tests pass one to `farmerDataOverrides(mockBackend:)`.
- Every repository method is `Future<Model>` and throws only `ApiError` (orbit_core) for expected failures;
  `ApiError.network()` when nothing reached the server. Switch on `error.code` with `ApiErrorCode` constants and
  show our own Telugu/English text.
- Each method's dartdoc names its exact endpoint and the error codes it can throw.
- Repositories own the token store: `AuthRepository.verifyOtp` saves the session in `SessionStore`, `logout`
  clears it, every other call reads the access token from it.
- Repositories report every `ApiError` of a signed-in call to the `AuthFailureHook` (see "Auth failures"
  below). Screens never handle 401, `device_revoked`, a deactivated farmer or an unfinished sign-up themselves.
- Providers that load the farmer's own data (`shared/farmer_data.dart`, the feature controllers) load through
  `loadFarmerData(ref, key, load)`, which watches `farmerDataScopeProvider` (signed-in farmer ID + a data
  generation). So another farmer signing in, or a dev-menu scenario switch or reset
  (`farmerDataGenerationProvider.bump()`), refetches them. Widgets read these providers as `ref.watch(p).fresh`
  (`shared/async_view.dart`) or through `AsyncValueView`: while the new farmer's data loads they show a spinner,
  and if that load fails they show the error with no data, never the previous farmer's. Pull-to-refresh, a
  resume refresh and a failed (or retried) refresh of the same farmer keep the data on screen. Such a provider
  watches nothing else that changes: one built on another farmer-scoped provider (a notice on the inbox, a
  visit on My visits, the plot pin on Home) reads it with `followFarmerData`, so it refreshes with it rather
  than reloading. A controller action that stores a write's answer in the state checks `isCurrentScope` after
  the `await`, so one farmer's answer never lands on the next one's data (a notifier stays mounted when it
  rebuilds); a page loaded for an earlier build is dropped too (a generation counter).
- Date-only fields (`plannedFor`, `sowingDate`, `validUntil`) are `LocalDate`; times are UTC `DateTime`.
- Enums have an `unknown` value where the server may add values, and `fromWire` / `wire` for mapping.

## Models (spec schema -> Dart)

Names mirror the OpenAPI schemas with `FA` written `Fa`. `Stage` covers both `Stage` and `FarmerStage` (same
shape). Request bodies are named method parameters, not classes.

| File | Models |
|---|---|
| `auth.dart` | `AppConfig`, `OtpSent`, `TokenPair`, `FarmerStatus`, `FarmerSession`, `DeviceInfo`, `DeviceStatus` |
| `farmer.dart` | `Farmer`, `Plan`, `FarmerSource`, `FarmerVillage`, `HomePlot`, `FarmerHome`, `PhotoContentType`, `FarmerPhotoUpload` |
| `plots.dart` | `Plot`, `AreaSource`, `PlotStatus`, `Season`, `SeasonStatus`, `SeasonOutcome` |
| `fas.dart` | `FarmerFaCard`, `FaStatus`, `FaOption`, `FaName`, `Callback`, `CallbackStatus` |
| `visits.dart` | `FarmerVisit`, `FarmerAdvice`, `Severity`, `PlannedVisit`, `NextVisit`, `PlannedSlot` |
| `notices.dart` | `Notice`, `NoticeKind`, `NoticeSender` |
| `consent.dart` | `CurrentConsent`, `ConsentPurpose`, `ConsentMethod` |
| `masters.dart` | `Stage`, `FarmerCrop`, `SeasonCodes`, `FarmerCropList`, `NearbyDealer` |
| `geo.dart` | `Village`, `GeoTree`, `TreeDistrict`, `TreeMandal` |
| `common.dart` | `Language`, `LatLng`, `AreaLevel`, `WireEnum`, `pickText` |

## Session

`sessionProvider` (`SessionController`, a Riverpod `Notifier<SessionState>`) is the router's source of truth.
Redirect on `ref.watch(sessionProvider.select((s) => s.phase))`:

| Phase | Screen | Leaves by |
|---|---|---|
| `restoring` | splash | automatic (reads the store, then the server) |
| `signedOut` | F1 phone | `requestOtp(phone)` |
| `otpSent` | F1 OTP | `verifyOtp(code)`, `resendOtp()`, `editPhone()` |
| `needsConsent` | F1a consent | `giveConsent(audioPlayed:)` |
| `needsVillage` | village picker | `pickVillage(village)` (local) |
| `needsName` | name entry | `completeProfile(name:, nameTe:)`, `changeVillage()` |
| `active` | Home and the rest | `signOut()`; automatic on auth failures and status changes (below) |
| `inactive` | "Account paused" | `recheck()`, `signOut()`; automatic when Home says `active` |

`setLanguage(language)` works in every phase, `restoring` included (Telugu default), and `appLanguageProvider`
gives the locale. Actions throw `ApiError` for the screen to show; the state changes only on success.

Every sign-in, sign-out and return to phone entry starts a new session generation. An action whose call returns
after that (a code verified after Edit phone, a sign-up step or re-check that finishes after the session was lost
or the farmer signed in again) never writes the state; a sign-in that lands after Edit phone is signed out again.
`signOut()` always forgets the session on the phone, even when the server call fails or there is no network.

The last phase of a signed-in farmer is saved in `SessionStore` (`readPhase` / `writePhase`; `needsName`
saves as `needsVillage`, the picked village is not kept). A start without network opens that phase, so an
unfinished sign-up resumes at its step, not Home. A store that cannot be read at start signs out (the session
is cleared; the install ID is kept, so a passing keystore failure does not register the phone as a new device).
If the install ID itself cannot be read at the next sign-in, a new one is made.

The server's word on the farmer's status wins: when Home's payload (`farmerHomeProvider`) says
`inactive` or `pending_profile` while the app is `active` (or `active` while `inactive`), it calls
`applyStatus(status)` and the router follows (Account paused, or back to consent / village).

### Auth failures

`AuthFailureHook` (`authFailureHookProvider`) is the one place a failed call reaches the session.
Repositories call `hook.report(error, farmerId: <farmer whose session the call used>)` for every `ApiError`
of a signed-in call; `SessionController` listens:

| Error | What happens |
|---|---|
| any 401 (for a farmer: `unauthorized` for an ended or expired session, `refresh_reused`), `device_revoked` (HO revoked the phone) | `sessionLost`: session cleared (`device_revoked` also wipes the install ID), phone entry. Many failures at once sign out once. (`session_revoked` is an HO-portal code; a farmer never gets it) |
| 403 `forbidden` (deactivated farmer's write), 409 `profile_incomplete` | `recheck()` (single-flight): `GET /v1/farmer/me`, then Account paused or the sign-up step |
| anything else | ignored here; the screen shows it |

A failure reported for another farmer (a call still in flight across a sign-out) is ignored. As a safety
net, `ErrorStateCard` offers Sign out next to Try again for 401, `device_revoked` and 403 errors.

The mock repositories report from one wrapper (`_MockRepository._call`). The API implementation must do
the same in its dio client (step 2 below).

## Run with mock data and scenarios

Mock data is the default in the dev flavour:

```bash
flutter run --flavor dev                                          # mock, normal
flutter run --flavor dev --dart-define=ORBIT_MOCK_SCENARIO=offline   # start offline
flutter run --flavor dev --dart-define=ORBIT_MOCK_LATENCY_MS=0       # no fake latency
```

Sign in with `9000000101` (Ravi K, Kondapur, cotton, FA Suresh) or `9000000102` (Venkatesh M, paddy), OTP
`123456`. Any other valid number is a new self sign-up; Kondapur and Gachibowli get FA Suresh, Madhapur has no
lead FA (natural "no FA" case).

Scenarios (`MockScenario`): `normal`, `noFaAssigned`, `noVisits`, `accountPaused`, `offline`, `slowNetwork`,
`serverError`, `sessionRevoked` (the server ended the session: every signed-in call and refresh fails with 401
`unauthorized`, as the client reports it once the refresh failed; sign-in itself works, so the app lands on phone
entry and keeps the install ID). Switch at runtime (dev-only UI):

```dart
final current = ref.watch(mockScenarioProvider);          // null when on the API: hide the switch
ref.read(mockScenarioProvider.notifier).select(MockScenario.offline);
ref.read(mockScenarioProvider.notifier).resetData();       // reload the seed (drops tokens too)
```

The change applies to the next repository call; invalidate the screen providers to see it. Resetting while
signed in drops the session's tokens, so the next call fails with 401 and the app goes to phone entry.

The mock follows the server where the contract suite can check it: refresh-token rotation with the 60 s retry
grace and `refresh_reused` after it, logout ending the whole session, keyset paging on (time, id) with cursors
that survive data changes (only a malformed cursor is `invalid_cursor`), negative `days_after_sowing` before a
future sowing date, and the order of `startSeason`'s checks.

What the mock does not simulate: per-IP and verify rate limits, access-token expiry, `device_revoked`
(the hook handles it; tests report it directly),
working upload/photo/audio URLs (they point at `MockBackend.mockHost`, `mock.orbit.invalid`; skip them in mock
mode), FA alerts.

## Swap to the real API

1. **Generate `orbit_api`.** From the repo root: `make backend-specs`, then the openapi-generator command in
   `mobile/implementation-plan.md` ("Generated API client") into `mobile/packages/orbit_api`; add it to the
   workspace and to `apps/farmer/pubspec.yaml`.
2. **HTTP client.** Build a dio client from `OrbitEnv.apiBaseUrl` (in orbit_core): an auth interceptor that reads
   the access token from `SessionStore`, a single-flight refresh `QueuedInterceptor` (it calls
   `POST /v1/auth/refresh` on its own dio and writes the new pair to the store), timeouts 20 s / 60 s. Map every
   failure to `ApiError`: a response -> `ApiError.fromResponse(status, data, retryAfterHeader:
   headers['retry-after'])`; no response or timeout -> `ApiError.network(timeout: ...)`.
   **Report failures:** after the mapping (and after a refresh failed, for a 401), call
   `authFailures.report(error, farmerId: session.farmerId)` with the `StoredSession` whose token the request
   sent (null when none). Pass the hook in from `buildFarmerRepositories(..., authFailures:)`. Reporting
   every call is safe, sign-in included: with nobody signed in the session ignores it, except
   `device_revoked`, which wipes the install ID.
3. **Write the `Api*Repository` classes** in `lib/src/data/api/`, one per interface, e.g.
   `ApiVisitsRepository implements VisitsRepository`. Each method calls the generated operation named in its
   dartdoc and maps DTO -> model in `api/mappers.dart`: enums with `X.fromWire(dto.field.value)`, date-only
   fields with `LocalDate.fromDateTime(dto.plannedFor)` (the generator's `dateLibrary=core` makes them
   `DateTime`; do not convert zones), times with `.toUtc()`, pages with `CursorPage(items:, nextCursor:)`.
   `ApiAuthRepository.verifyOtp` writes the `StoredSession`; `logout` clears the store first, then calls the
   server and swallows errors. `requestCallback` returns the body for both 200 and 201.
4. **Select it.** In `buildFarmerRepositories`, replace the `DataSource.api` branch with the Api set (given
   `authFailures`), and swap `InMemorySessionStore` for a `flutter_secure_storage` implementation of
   `SessionStore` in `sessionStoreProvider` (it also saves the phase as `SessionPhase.name`, cleared with the
   session). Nothing else changes: screens only see the interfaces.
5. **Run the contract suite against a dev backend.** From the repo root: `make dev-up && make migrate &&
   make backend-seed`, then `make backend-run-api` and, in another terminal, `make backend-run-worker` (the
   worker sends the welcome notice the suite waits for). `backend/.env`, made from `.env.example`, sets
   `DEV_FIXED_OTP=123456`. Then add `test/data/api_repository_contract_test.dart`:

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
         repos: buildFarmerRepositories(env, store, authFailures: hook),
         store: store,
         authFailures: hook,
         fixture: ContractFixture.devSeed(),
       ); // closeCallbackAsFa: null -> that one test is skipped
     });
   }
   ```

   ```bash
   flutter test --run-skipped --tags dev-backend test/data/api_repository_contract_test.dart \
     --dart-define=ORBIT_CONTRACT_BASE_URL=http://localhost:8080
   ```

   `dart_test.yaml` skips the `dev-backend` tag by default, so CI and `flutter test` without a backend stay
   green; `--run-skipped --tags dev-backend` runs it. The suite only asserts what the dev seed guarantees, changes
   only fresh self sign-ups' data (and Ravi's call-back, left cancelled; signing in and the heartbeat still write
   his session and device rows), and checks that every 401 and 409 reaches the `AuthFailureHook`. Each run adds
   self sign-ups in Kondapur; to start the dev data over: `make backend-dev-reset`, then `make dev-up migrate
   backend-seed`.
6. **Run the app on the API:** `flutter run --flavor dev --dart-define=ORBIT_DATA_SOURCE=api` (Android emulator
   reaches the host at `10.0.2.2:8080`; iOS simulator: add `--dart-define=ORBIT_API_BASE_URL=http://localhost:8080`).
   Staging and prod always use the API and need real base URLs in `OrbitEnv` first.

## Tests

```bash
cd mobile/apps/farmer
flutter test test/data          # contract suite on the mock, session flow, mock scenarios
flutter analyze --fatal-infos
```
