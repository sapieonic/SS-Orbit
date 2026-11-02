// Fakes of the repository interfaces the offline engine talks to, and a
// harness that wires them to a real InMemoryLocalStore, SyncEngine and
// FaActions (not a test file).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/data/repositories/repositories.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/fa_actions.dart';
import 'package:fa/src/local/local_store.dart';
import 'package:fa/src/local/network.dart';
import 'package:fa/src/local/outbox.dart';
import 'package:fa/src/local/projector.dart';
import 'package:fa/src/local/sync_engine.dart';
import 'package:fa/src/local/territory.dart';
import 'package:orbit_core/orbit_core.dart';

import 'fixture.dart';

/// Decides the result of a new command (default: applied).
typedef Decide = CommandResult? Function(CommandIn command);

/// A server for `/v1/fa/sync/*` that keeps command results by ID (so a
/// resend gets the stored result, as the real one does) and applies applied
/// commands to its own snapshot with the [Projector].
///
/// Without a [decide] answer it judges commands the way the backend does
/// (while [applyToSnapshot] is on, so its snapshot is the truth):
/// * farmer IDs follow merge aliases;
/// * SavePlot of an existing plot: `expected_version` (default 1) must be the
///   plot's version, else a conflict (`farmers.SavePlot`);
/// * UpdateFarmer at another version: a conflict on the first field whose
///   value differs, else applied without a write;
/// * StartSeason on a plot with an active season: conflict `active_season`
///   with `theirs: {season_id, season_code, crop_id}`;
/// * PlanVisit / LogVisit on a season that does not exist (for that plot and
///   farmer): rejected, as the foreign key does;
/// * LogVisit `visited_at` more than 15 minutes after [now]: rejected;
/// * a LogVisit of a visit already done is a replay: applied, its photos
///   are not stored.
final class FakeServer implements SyncRepository {
  /// Starts with [snapshot].
  FakeServer(this.snapshot)
    : territoryVersion = snapshot.territoryVersion,
      mastersVersion = snapshot.mastersVersion;

  /// The server's territory (what a pull returns, at [territoryVersion]).
  Snapshot snapshot;

  /// Current territory version (bumped by every applied command).
  int territoryVersion;

  /// Current masters version.
  int mastersVersion;

  /// When false, applied commands do not change [snapshot] (a stale cache).
  bool applyToSnapshot = true;

  /// When set, pulls return the snapshot at this version instead.
  int? servedVersion;

  /// Stored results by command ID.
  final stored = <String, CommandResult>{};

  /// How often each command ID was processed fresh (not from the store).
  final dispatched = <String, int>{};

  /// Every batch received, in order.
  final batches = <List<CommandIn>>[];

  /// The `If-None-Match` of every snapshot call.
  final snapshotCalls = <String?>[];

  /// Number of status polls.
  int statusCalls = 0;

  /// Merged farmer aliases (local ID -> existing ID).
  final aliases = <String, String>{};

  /// Result of a new command; null result or no [decide] = applied.
  Decide? decide;

  /// Thrown by the next submit calls, one each, before processing.
  final submitErrors = <Object>[];

  /// Thrown once after processing (the answer is lost on the way back).
  Object? errorAfterProcessing;

  /// The next batch stops at this index (`retry_from`).
  int? stopAt;

  /// A batch with any of these command IDs is a 400.
  final badIds = <String>{};

  /// A batch body bigger than this is a 413.
  int? maxBodyBytes;

  /// Completes before the next submit answers (to hold a run open).
  Completer<void>? hold;

  /// The server's clock for the `visited_at` check (null: not checked).
  DateTime Function()? now;

  /// Photo IDs stored per visit by applied LogVisits.
  final photosByVisit = <String, Set<String>>{};

  bool _busy = false;

  /// True if two submits ever overlapped.
  bool overlapped = false;

  /// The current ETag.
  String get etag => Snapshot.snapshotEtag(territoryVersion, mastersVersion);

  /// Every command received (resends included), in order.
  List<CommandIn> get received => [for (final b in batches) ...b];

  @override
  Future<CommandBatchResult> submitCommands(List<CommandIn> commands) async {
    if (_busy) overlapped = true;
    _busy = true;
    try {
      batches.add(commands);
      if (hold != null) {
        final h = hold!;
        hold = null;
        await h.future;
      }
      if (submitErrors.isNotEmpty) throw submitErrors.removeAt(0);
      final body = jsonEncode({
        'commands': [for (final c in commands) c.toJson()],
      });
      if (maxBodyBytes != null && utf8.encode(body).length > maxBodyBytes!) {
        throw const ApiError(
          code: ApiErrorCode.payloadTooLarge,
          message: 'too large',
          status: 413,
        );
      }
      if (commands.any((c) => badIds.contains(c.id))) {
        throw const ApiError(
          code: ApiErrorCode.validationFailed,
          message: 'commands[2].payload: bad',
          status: 400,
        );
      }
      final results = <CommandResult>[];
      int? retryFrom;
      for (var i = 0; i < commands.length; i++) {
        if (stopAt != null && i == stopAt) {
          retryFrom = i;
          stopAt = null;
          break;
        }
        final c = commands[i];
        final known = stored[c.id];
        if (known != null) {
          results.add(known);
          continue;
        }
        final decided = decide?.call(c);
        final (r, write) = decided != null ? (decided, true) : _judge(c);
        stored[c.id] = r;
        dispatched[c.id] = (dispatched[c.id] ?? 0) + 1;
        if (write &&
            (r.status == CommandStatus.applied ||
                r.status == CommandStatus.merged)) {
          territoryVersion++;
          _apply(c, r);
        }
        results.add(r);
      }
      final res = CommandBatchResult(
        results: results,
        retryFrom: retryFrom,
        territoryVersion: territoryVersion,
        mastersVersion: mastersVersion,
      );
      final after = errorAfterProcessing;
      if (after != null) {
        errorAfterProcessing = null;
        throw after;
      }
      return res;
    } finally {
      _busy = false;
    }
  }

  CommandPayload _resolved(CommandIn c) {
    var command = CommandPayload.decode(
      CommandType.fromWire(c.type)!,
      c.payload,
    );
    for (final a in aliases.entries) {
      command = command.replaceId(a.key, a.value);
    }
    return command;
  }

  /// The backend's answer to a new command, and whether it writes.
  (CommandResult, bool) _judge(CommandIn c) {
    final ok = applied(c);
    if (!applyToSnapshot) return (ok, true);
    final cmd = _resolved(c);
    final snap = snapshot;
    CommandResult conflict(String field, Object? yours, Object? theirs) =>
        CommandResult(
          id: c.id,
          status: CommandStatus.conflict,
          entityId: cmd.entityId,
          conflict: Conflict(field: field, yours: yours, theirs: theirs),
        );
    CommandResult rejected(String why) => CommandResult(
      id: c.id,
      status: CommandStatus.rejected,
      entityId: cmd.entityId,
      error: why,
    );
    switch (cmd) {
      case final SavePlotPayload p:
        final cur = snap.plots.where((x) => x.id == p.plotId).firstOrNull;
        if (cur == null) return (ok, true);
        final expected = p.expectedVersion ?? 1;
        if (expected == cur.version) return (ok, true);
        if (p.areaAcres != cur.areaAcres) {
          return (conflict('area_acres', p.areaAcres, cur.areaAcres), false);
        }
        if (p.label != cur.label) {
          return (conflict('label', p.label, cur.label), false);
        }
        return (conflict('version', expected, cur.version), false);
      case final UpdateFarmerPayload p:
        final f = snap.farmers.where((x) => x.id == p.farmerId).firstOrNull;
        if (f == null) return (rejected('farmer not found'), false);
        // checkPhotoKey(key, payload farmer_id, resolved farmer id)
        final key = p.fields.photoKey;
        final sentId = c.payload['farmer_id'];
        if (key != null &&
            !key.startsWith('farmers/$sentId/') &&
            !key.startsWith('farmers/${f.id}/')) {
          return (
            rejected(
              'photo_key: must be a key from this farmer\'s photo '
              'upload URL',
            ),
            false,
          );
        }
        if (f.version == p.expectedVersion) return (ok, true);
        final fl = p.fields;
        if (fl.name != null && fl.name != f.name) {
          return (conflict('name', fl.name, f.name), false);
        }
        if (fl.nameTe != null && fl.nameTe != f.nameTe) {
          return (conflict('name_te', fl.nameTe, f.nameTe), false);
        }
        if (fl.language != null && fl.language != f.language) {
          return (
            conflict('language', fl.language!.wire, f.language.wire),
            false,
          );
        }
        if (fl.villageId != null && fl.villageId != f.villageId) {
          return (conflict('village_id', fl.villageId, f.villageId), false);
        }
        if (fl.photoKey != null && fl.photoKey != f.photoKey) {
          return (conflict('photo_key', fl.photoKey, f.photoKey), false);
        }
        return (ok, false); // already in place
      case final StartSeasonPayload p:
        if (snap.seasons.any((x) => x.id == p.seasonId)) return (ok, false);
        final active = snap.seasons
            .where(
              (x) => x.plotId == p.plotId && x.status == SeasonStatus.active,
            )
            .firstOrNull;
        if (active != null) {
          return (
            conflict(
              'active_season',
              {'season_code': p.seasonCode, 'crop_id': p.cropId},
              {
                'season_id': active.id,
                'season_code': active.seasonCode,
                'crop_id': active.cropId,
              },
            ),
            false,
          );
        }
        return (ok, true);
      case final PlanVisitPayload p:
        if (!_seasonFits(p.seasonId, p.plotId, p.farmerId)) {
          return (rejected(_noSeason), false);
        }
        return (ok, true);
      case final LogVisitPayload p:
        final at = now?.call();
        if (at != null &&
            p.visitedAt.isAfter(at.add(const Duration(minutes: 15)))) {
          return (rejected('visited_at is in the future'), false);
        }
        final v = snap.visits.where((x) => x.id == p.visitId).firstOrNull;
        if (v != null &&
            v.status == VisitStatus.done &&
            v.plotId == p.plotId &&
            v.seasonId == p.seasonId) {
          return (ok, false); // a replay: photos are not stored again
        }
        if (!_seasonFits(p.seasonId, p.plotId, p.farmerId)) {
          return (rejected(_noSeason), false);
        }
        photosByVisit[p.visitId] = {
          ...?photosByVisit[p.visitId],
          for (final ph in p.photos) ph.photoId,
        };
        return (ok, true);
      default:
        return (ok, true);
    }
  }

  static const _noSeason =
      'season does not exist or does not belong to this farmer and plot';

  bool _seasonFits(String seasonId, String plotId, String farmerId) =>
      snapshot.seasons.any(
        (s) => s.id == seasonId && s.plotId == plotId && s.farmerId == farmerId,
      );

  void _apply(CommandIn c, CommandResult r) {
    if (r.status == CommandStatus.merged && r.mergedInto != null) {
      aliases[r.entityId!] = r.mergedInto!;
    }
    if (!applyToSnapshot) return;
    var command = CommandPayload.decode(
      CommandType.fromWire(c.type)!,
      c.payload,
    );
    for (final a in aliases.entries) {
      command = command.replaceId(a.key, a.value);
    }
    snapshot = const Projector().replay(snapshot, [
      OutboxEntry.create(
        id: c.id,
        command: command,
        now: c.clientCreatedAt ?? fixtureNow,
      ),
    ]);
  }

  /// An applied result for [c].
  static CommandResult applied(CommandIn c) => CommandResult(
    id: c.id,
    status: CommandStatus.applied,
    entityId: entityIdOf(c),
  );

  /// The entity a wire command is about.
  static String entityIdOf(CommandIn c) =>
      CommandPayload.decode(CommandType.fromWire(c.type)!, c.payload).entityId;

  /// The snapshot a pull returns now.
  Snapshot get served =>
      withVersion(snapshot, servedVersion ?? territoryVersion);

  @override
  Future<SnapshotResult> getSnapshot({String? ifNoneMatch}) async {
    snapshotCalls.add(ifNoneMatch);
    final s = served;
    if (ifNoneMatch != null && ifNoneMatch == s.etag) {
      return SnapshotNotModified(etag: ifNoneMatch);
    }
    return SnapshotFetched(snapshot: s, etag: s.etag);
  }

  @override
  Future<SyncStatus> getStatus() async {
    statusCalls++;
    final s = served;
    return SyncStatus(
      territoryVersion: s.territoryVersion,
      mastersVersion: s.mastersVersion,
      etag: s.etag,
    );
  }
}

/// Visit photo endpoints. With a [server], an upload URL is only given for a
/// photo an applied LogVisit stored (404 otherwise, as the backend), and a
/// confirmed photo answers 409 `photo_already_uploaded`.
final class FakeVisitPhotos implements VisitPhotosRepository {
  /// Creates the endpoints.
  FakeVisitPhotos({this.server});

  /// The sync server whose LogVisits decide which photo IDs exist.
  final FakeServer? server;

  /// `upload-url` calls (photo IDs).
  final uploadUrlCalls = <String>[];

  /// `confirm` calls: photo ID -> sha256.
  final confirmed = <String, String?>{};

  /// Thrown by the next upload-url calls.
  final createErrors = <Object>[];

  /// Thrown by the next confirm calls.
  final confirmErrors = <Object>[];

  @override
  Future<VisitPhotoUpload> createUploadUrl({
    required String visitId,
    required String photoId,
    required PhotoContentType contentType,
    required int bytes,
  }) async {
    uploadUrlCalls.add(photoId);
    if (createErrors.isNotEmpty) throw createErrors.removeAt(0);
    final s = server;
    if (s != null && !(s.photosByVisit[visitId]?.contains(photoId) ?? false)) {
      throw const ApiError(
        code: ApiErrorCode.notFound,
        message: 'photo not found; sync the visit log first',
        status: 404,
      );
    }
    if (s != null && confirmed.containsKey(photoId)) {
      throw const ApiError(
        code: ApiErrorCode.photoAlreadyUploaded,
        message: 'this photo is already uploaded',
        status: 409,
      );
    }
    return VisitPhotoUpload(
      photoId: photoId,
      storageKey: 'visits/$visitId/$photoId.jpg',
      url: 'https://storage.test/$photoId',
      method: 'PUT',
      headers: {'content-type': contentType.wire},
      expiresAt: fixtureNow.add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<VisitPhoto> confirmUpload({
    required String visitId,
    required String photoId,
    String? sha256,
  }) async {
    if (confirmErrors.isNotEmpty) throw confirmErrors.removeAt(0);
    confirmed[photoId] = sha256;
    return VisitPhoto(
      id: photoId,
      visitId: visitId,
      contentType: PhotoContentType.jpeg,
      bytes: null,
      uploadedAt: fixtureNow,
      url: null,
    );
  }
}

/// PUT to presigned URLs.
final class FakeUploader implements PhotoUploader {
  /// Uploaded bytes by URL.
  final uploads = <String, Uint8List>{};

  /// Number of PUTs.
  int puts = 0;

  @override
  Future<void> upload(PresignedUpload target, Uint8List bytes) async {
    puts++;
    uploads[target.url] = bytes;
  }
}

/// Store + fake server + engine + actions over the fixture.
final class Harness {
  /// Creates the harness (call [seed] to store the first snapshot).
  Harness({
    Snapshot? snapshot,
    bool online = true,
    bool wifi = true,
    SyncLimits limits = const SyncLimits(nudgeDelay: Duration.zero),
    double Function()? random,
  }) : server = FakeServer(snapshot ?? fixtureSnapshot()),
       net = MockConnectivityService(online: online, wifi: wifi) {
    photos = FakeVisitPhotos(server: server);
    server.now = clock.now;
    engine = SyncEngine(
      store: store,
      sync: server,
      visitPhotos: photos,
      uploader: uploader,
      connectivity: net,
      clock: clock,
      random: random ?? () => 0.5,
      limits: limits,
      owner: 'test',
    );
    actions = FaActions(store: store, clock: clock);
  }

  /// The clock (2 Nov 2026, 10:30 IST).
  final FixedClock clock = fixtureClock();

  /// The local store.
  final InMemoryLocalStore store = InMemoryLocalStore();

  /// The server.
  final FakeServer server;

  /// Photo endpoints (strict: only photo IDs the server stored).
  late final FakeVisitPhotos photos;

  /// Presigned PUTs.
  final FakeUploader uploader = FakeUploader();

  /// Network.
  final MockConnectivityService net;

  /// The engine.
  late final SyncEngine engine;

  /// The actions.
  late final FaActions actions;

  /// Stores the server's snapshot as the first pull would.
  Future<void> seed() => engine.writeSnapshot(server.served);

  /// The territory now.
  Future<Territory> territory() => Territory.load(store, asOf: clock.now());

  /// Outbox rows in seq order.
  Future<List<OutboxEntry>> outbox() => store.outbox();

  /// The outbox rows of [type].
  Future<List<OutboxEntry>> rows(CommandType type) async => [
    for (final e in await store.outbox())
      if (e.type == type) e,
  ];

  /// Closes the engine.
  Future<void> dispose() async {
    await engine.dispose();
    await net.dispose();
  }
}

/// A tiny JPEG-ish payload.
Uint8List photoBytes(int seed, {int length = 64}) => Uint8List.fromList([
  0xFF,
  0xD8,
  for (var i = 0; i < length; i++) (seed + i) % 256,
]);
