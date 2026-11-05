# FA offline engine (`lib/src/local`)

The FA works offline most of the day. The phone keeps a copy of the FA's
territory (the snapshot), every change the FA makes goes into an outbox of
commands, and the sync engine pushes the outbox and pulls a fresh snapshot
when it can. This folder is that engine. It is real logic: when Drift and the
API land, only the storage class and the repository implementations change.

Spec: `mobile/implementation-plan.md`, "FA offline engine (orbit_sync)" and
"Screen map: FA app". Backend behaviour: `backend/internal/sync/service_commands.go`,
`backend/internal/farmers/commands*.go`, CONVENTIONS section 6.

Everything here is pure Dart (no Flutter import) except `providers.dart`, so
it moves to `packages/orbit_sync` as it is.

| File | What |
|---|---|
| `commands.dart` | The 10 command payloads (`<Type>Payload`), `createdIds` / `dependsOnIds`, `replaceId` |
| `outbox.dart` | Rows: `OutboxEntry` + `OutboxState`, `PhotoQueueEntry`, `SyncLogEntry`, `SyncMeta`, `LocalSettings`, `Rejection` |
| `local_store.dart` | `LocalStore` interface (tables + `transaction` + sync lease + `wipe`) and `InMemoryLocalStore` |
| `projector.dart` | `Projector`: the local effect of each command on the territory tables; `rebuildTerritory` |
| `territory.dart` | `Territory`: the read model screens use, with its queries |
| `sync_engine.dart` | `SyncEngine`: push, pull, photos, backoff, lease; `SyncState`, `SyncRunResult` |
| `fa_actions.dart` | `FaActions`: every write the UI makes |
| `network.dart` | `ConnectivityService` (re-exported by `device/connectivity.dart` with its provider) |
| `geo.dart` | Distances, plot centres, walked-boundary area and path length |
| `providers.dart` | Riverpod wiring (`territoryProvider`, `syncStateProvider`, `faActionsProvider`, ...) |

## How screens use it

```dart
final territory = ref.watch(territoryProvider);      // AsyncValue<Territory>
final sync = ref.watch(syncStateProvider);           // badge, Sync screen
final online = ref.watch(phoneOnlineProvider);       // network now
await ref.read(faActionsProvider).logVisit(input);   // every write
```

Screens never build commands or IDs; they call `FaActions`. Each action
checks its input against the territory (throws `FaActionError` with a code the
UI translates), mints UUIDv7 IDs, writes the outbox entry and its projection
in **one transaction**, and nudges the engine (debounced 2 s).

* Time comes from the server-corrected clock (`serverClockProvider`, wired in
  `providers.dart`): `visited_at`, `client_created_at` and the "not more than
  15 minutes in the future" check are judged by the server's clock. The engine
  keeps the device clock (the session depends on it, so it cannot read the
  session); nothing it stamps is checked by the server.
* Text limits are UTF-8 bytes, as the backend counts them (`len` in Go):
  name 100, Telugu name 300, plot label 60. A Telugu letter is 3 bytes.
* Codes the screens show besides the generic ones: `season_active` (the plot
  has an active season; one per plot), `cannot_clear` (a Telugu name cannot be
  blanked; the server refuses it), `area_too_small` (a walked boundary with
  its corners in a line), `boundary_crosses_itself` (walk it again; the server
  runs `ST_IsValid`).
* **One live edit per plot / farmer.** A SavePlot edit or an UpdateFarmer
  whose latest earlier edit of the same plot / farmer is still queued and was
  never sent replaces that command's payload in place (same ID, same
  `expected_version`). If that earlier edit is a conflict, the new values are
  folded into the conflict (Keep mine sends them, Keep HO's drops them). If it
  is on its way, the new one is queued with `meta.version_parent`; the engine
  never sends the two in one batch and folds the new one into the earlier one
  if that one comes back as a conflict, or re-bases it on the earlier one's
  version if that one is rejected. So a guessed `expected_version` (the
  earlier one's + 1) can never match a version HO made and overwrite HO's
  change unseen, and Keep mine can never land after a later edit.
* Planned and `missed` visits (the server's hourly job marks a passed plan
  missed) can both be logged, moved and cancelled (`Territory.isOpenPlan`).

The app shell starts the engine while the session is active and the app is in
the foreground (`syncEngineProvider` -> `start()` / `stop()`), and adds
`localEngineOverrides()` to the root `ProviderScope` so the session's
`LocalDataGuard` counts, pushes and wipes through the engine.

## Two copies of the territory

The store keeps the **base snapshot** exactly as the server sent it, and the
**territory tables**: base + the effect of the outbox (projection). Screens
read the territory tables. Every projection is an upsert by entity ID and
takes its time from the entry, so replaying an entry twice changes nothing,
and rebuilding the territory tables from base + outbox is always safe. That is
how an effect is taken back (rejected, dropped, Keep HO's) or changed (an
edited queued visit, a merged farmer ID).

An entry is replayed while it is `queued` or `sending`, and while it is
`applied` / `merged` with a `batch_territory_version` newer than the stored
snapshot. Conflicts, rejections, dropped and resolved entries are not.

## Outbox entry life

```text
               FaActions (one transaction: entry + projection)
                         |
                         v
     +--------------> queued <------------------------------+
     |                   |  run takes a batch               |
     |                   v                                  |
     |                sending --- network / timeout / 5xx --+  (backoff)
     |                   |    --- retry_from: the rest -----+  (backoff)
     |                   |    --- 400: bisect / 413: halve -+  (no backoff)
     |                   |    --- app killed: next run -----+
     |        +----------+-----------+-----------+
     |        v          v           v           v
     |     applied    merged     conflict     rejected ---> dependents: dropped
     |        |          |        |      |                  (and their photos)
     |        +----+-----+    Keep HO's  Keep mine
     |             |             |      |
     |   snapshot carries it     v      v
     |   (t >= batch version)  resolved  resolved + a NEW queued entry
     |             |                              (new ID, server's version)
     |             v                                      |
     |          deleted                                   |
     +----------------------------------------------------+
```

Rejected, dropped and resolved rows stay on the Sync screen until the FA taps
them away (`FaActions.dismiss`), 30 days at most. Every outcome writes a
`sync_log` line ("records synced today").

## Push

* Push always comes before pull, in `seq` order.
* A batch is the longest run from the head of the queue with at most 200
  commands and at most 4 MiB of JSON (the route caps at 5 MiB). It also ends
  after a StartSeason that later queued commands use (see `conflict` below),
  and before an edit whose `version_parent` is already in it.
* Rows are marked `sending` before the request, in one transaction that
  re-reads every row: the batch ends before a row that changed since it was
  read (an "Edit this visit" that landed in between), and exactly what was
  written is sent. A run that dies leaves them `sending`; the next run
  (holding the lease) puts them back to `queued`. Command IDs are idempotency
  keys, so a resend gets the stored result: nothing is lost and nothing is
  applied twice.
* Network error, timeout, 5xx, 429: the batch goes back to `queued` with
  backoff 15 s, 1 min, 5 min, 15 min, then 30 min, each +-20 % jitter (429 uses
  `Retry-After`). The count resets on Sync now, a connectivity change and app
  foreground.
* `retry_from`: results cover `[0, retry_from)`; those are applied, the rest go
  back to `queued` with backoff and are resent from that index.
* 400 for the whole batch: halve until one command is alone. It is rejected
  locally (`client_invalid`, server message in `meta.detail`) only when the
  server evidently takes other requests: a batch went through since the 400s
  began, or a probe (the first queued command that needs nothing the suspect
  creates, sent alone) passes. If the probe gets a 400 too, the 400 is about
  the request, not a command (a proxy, a header, a server change): nothing is
  rejected, the queue backs off. With nothing to compare, the lone command is
  rejected after 3 runs in a row (`meta.lone_400`). 413: halve the batch. One
  command bigger than a batch: rejected locally.
* 401 / 403: back to `queued` without backoff; the run stops and the session
  decides (refresh, password).
* Consent proof (valid 7 days): an EnrolFarmer whose proof expired before it
  went up is sent without it (the farmer is enrolled consent pending; the FA
  records consent again from Farmer 360). An expired RecordConsent is
  rejected locally (`consent_proof_expired`).

## Results

| Status | Effect |
|---|---|
| `applied` | Row kept and replayed until a snapshot at least as new as the batch is stored, then deleted. Photos of a LogVisit become uploadable. |
| `merged` | `minted -> merged_into` goes into `sync_meta.id_aliases`; queued payloads **keep the minted ID** (the backend follows farmer aliases for every command, and accepts a `photo_key` under `farmers/<minted>/` only while the payload carries the minted ID). The projection reads every payload through the aliases (one farmer, not two), the territory resolves the old ID, a pull follows. The alias is also in the sync log. |
| `conflict` | Not replayed (the screen shows HO's value after the pull that follows). `entry.conflict` has field, yours and theirs. **SavePlot / UpdateFarmer:** later queued edits of the same plot / farmer are folded into it (`meta.folded`). **Keep mine** queues the (folded) change under a **new command ID** with `expected_version` = the version in the snapshot now (the server answers a known ID with its stored conflict, so the old ID cannot be reused). **StartSeason** (`active_season`, `theirs: {season_id, season_code, crop_id}`): the season was never created, so every queued command that uses it moves to `theirs.season_id` (payloads rewritten: the server does not follow season aliases; a LogVisit's stage is dropped when that season's crop differs), `season -> theirs` goes into `id_aliases`, and the clash can only be accepted (Keep HO's). **Keep HO's** marks it `resolved`; nothing is sent. |
| `rejected` (or an unknown status) | Not replayed; every entry depending on it (transitively, via `depends_on_id`) that the server has not judged yet (queued or sending) becomes `dropped` with `parent_rejected`, and their queued photos are dropped. A queued edit that counted on it (`version_parent`) is re-based on its `expected_version`. A child the server answered in the same batch keeps its own result and reason (the Sync screen still groups it under its parent). Reasons map to `RejectionCode` (`registered_with_another_fa`, `not_in_your_area`, `server_could_not_apply`, ...); other reasons are English sentences shown under a generic heading. |

`depends_on_id` is the latest earlier entry (not rejected, dropped or
resolved) whose `createdIds` meet this command's `dependsOnIds`: EnrolFarmer
-> SavePlot -> StartSeason -> PlanVisit / LogVisit; PlanVisit / LogVisit ->
CancelVisit. A LogVisit does not depend on the PlanVisit of its visit (the
server logs a visit it never saw planned), so a refused plan does not drop the
FA's visit log.

`SyncState` follows the network all the time (`online`, `onWifi`, also
while the engine is stopped), carries the current run's progress
(`runSent` / `runTotal`, `runProgress`) and the photos per LogVisit
(`photosByCommand`). A started engine runs when the network comes back, and
when Wi-Fi comes back with photos waiting.

"Move to another day" is `FaActions.replanVisit`: a PlanVisit that reuses
the visit ID (the server's `visits.replanned`), farmer, plot and season
unchanged.

## Pull

* After a push whose batch reported other versions than `sync_meta`, after a
  merge or a conflict, on Sync now, and when `GET /v1/fa/sync/status` shows
  another ETag (foreground, connectivity, push notification, the 15 minute
  timer). The first run always pulls.
* `If-None-Match` with the stored ETag; 304 only touches `last_pull_at`.
  Without it on Sync now with `force`, and once the masters' season codes are
  past `valid_until`: the ETag does not change on a season boundary, so every
  run (timer, foreground, connectivity too) pulls then, at most every 30
  minutes until a fresh snapshot arrives.
* 200: one transaction replaces the base snapshot, deletes the applied rows it
  carries, prunes the 30-day log and finished rows, replays the outbox and
  writes `sync_meta`.

Alerts: the projector closes `new_farmer` alerts on EnrolFarmer (and a
merge) and `callback` alerts on CloseCallback / LogVisit, as the mock server
does. The real backend does not close FA alerts yet (`fa_alerts.sql` has no
close query), so on the API a pull would bring them back as open until
messaging closes them on farmer enrolled / merged and call-back closed. See
"Not done yet" in `mobile/README.md`.

## Photos

A LogVisit's photos go into `photo_queue` (`waiting`) in the same transaction
as the command. Once the LogVisit is applied they are `ready`: upload URL ->
PUT with exactly the URL's method and headers -> confirm with the SHA-256 ->
`done` (bytes let go). `photo_already_uploaded` skips the PUT;
`upload_missing` on confirm PUTs again; `not_found` (or a 403 on the upload
URL: "not your visit") drops at once if the LogVisit was rejected, waits while
it is pending, and drops after 5 tries once it is applied (the server never
stored that photo ID), with a `photo_dropped` log line
(`photo_not_on_server`); a network error backs off. "Upload photos on Wi-Fi
only" (`LocalSettings`, on by default) holds them on mobile data; records
still sync. Visit data never waits for photos.

## One runner at a time

A run takes the `sync_lock` lease in the store (2 min), renews it before
every batch, the pull and the photos, and every 30 s while a request, a pull
or an upload is going. If another runner got it anyway (this one stalled past
the TTL), the run stops at the next step (`skipped: busy`) and never writes a
stale row back: answers for rows that are no longer `sending` are ignored.
Inside one engine, a run asked for while one is going is queued once and
shared. `wipe()` refuses new runs, drops a queued one, waits for the one going
and holds the lease over the wipe.

## Later: Drift and orbit_sync

* `DriftLocalStore implements LocalStore`, SQLCipher-encrypted, key in the
  Android Keystore. Tables 1:1 with the row classes: `outbox`, `photo_queue`
  (a file path instead of bytes), `sync_log`, `sync_meta`, `sync_lock`
  (lease row), the plan's snapshot tables for the territory tables, and the
  base snapshot as one compressed JSON row. `transaction` maps to Drift's.
  `changes` maps to table update streams.
* Snapshot parsing in a background isolate; inserts in batches of 500.
* **Row-level projection writes (Drift-time task).** Today every action
  projects one entry onto the in-memory tables and `putTerritoryTables`
  replaces all territory tables, and every rebuild (rejection, merge, Keep
  HO's, snapshot) replays the whole outbox; `Territory.load` reads the full
  outbox and the 30-day sync log on every store change. Fine in memory; on
  Drift with a few hundred farmers on a 2 GB phone it is a full-table rewrite
  per tap. With Drift: let the projector return the rows it touched and
  upsert just those (`LocalTables.upsertTerritoryRows`), keep the wholesale
  rebuild for take-backs and snapshots (one transaction, batches of 500), and
  watch only the tables a screen reads.
* A WorkManager job (15 min, network required, and on connectivity change)
  builds its own `SyncEngine` over the same database; the lease keeps it and
  the UI apart.
* `ConnectivityService` over connectivity_plus.
* Move `local/` (minus `providers.dart`) and the models it uses to
  `packages/orbit_sync`.

## Tests

`test/local/**`: store, projector, territory queries, actions, and the engine
against a fake server that stores results by command ID (ordering, batching,
retry_from, backoff with a fixed clock, every result status, merges,
conflicts, 304 / 200 with replay, a killed run, photos with Wi-Fi only, 400
bisect, 413, consent expiry, the lease).
