// The FA offline engine's sync loop: push the outbox, pull the snapshot,
// upload visit photos (implementation plan, "FA offline engine"). Pure Dart.
//
// One run: take the sync lease -> put orphaned `sending` rows back ->
// push in seq order (batches of <= 200 commands, well under 5 MiB) ->
// pull when needed (ETag / 304) -> photos -> give the lease back.
// Runs never overlap: a run asked for while one is going is queued once and
// starts right after.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:orbit_core/orbit_core.dart';

import '../data/models/models.dart';
import '../data/repositories/repositories.dart';
import 'commands.dart';
import 'local_store.dart';
import 'network.dart';
import 'outbox.dart';
import 'projector.dart';

/// Why a run started; decides backoff and whether to pull.
enum SyncTrigger {
  /// "Sync now": resets backoff, always pulls (304 when nothing changed).
  manual,

  /// The FA saved something (debounced [SyncEngine.nudge]): push, then pull
  /// only if the batch moved the versions.
  action,

  /// The 15 minute foreground timer: push, then poll the status ETag.
  timer,

  /// The app came to the foreground ([SyncEngine.start]): resets backoff.
  foreground,

  /// The network came back: resets backoff.
  connectivity,

  /// A push notification said the territory changed.
  notification,

  /// The backoff wait is over.
  retry,
}

/// Limits and timings of the engine (the plan's numbers by default).
final class SyncLimits {
  /// Creates limits.
  const SyncLimits({
    this.maxBatch = 200,
    this.maxBatchBytes = 4 * 1024 * 1024,
    this.backoff = const [
      Duration(seconds: 15),
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 15),
      Duration(minutes: 30),
    ],
    this.jitter = 0.2,
    this.pollInterval = const Duration(minutes: 15),
    this.nudgeDelay = const Duration(seconds: 2),
    this.leaseTtl = const Duration(minutes: 2),
    this.leaseRenewEvery = const Duration(seconds: 30),
    this.retention = const Duration(days: 30),
    this.stalePullEvery = const Duration(minutes: 30),
    this.lone400Limit = 3,
    this.photoGiveUpAfter = 5,
  });

  /// Most commands per `POST /v1/fa/sync/commands` (server cap 200).
  final int maxBatch;

  /// Most JSON bytes per batch (the route's cap is 5 MiB).
  final int maxBatchBytes;

  /// Backoff after 1, 2, 3, ... failures in a row; the last one is the cap.
  final List<Duration> backoff;

  /// Random spread of each backoff step (0.2 = +-20 %).
  final double jitter;

  /// Status poll while the app is in the foreground.
  final Duration pollInterval;

  /// Wait after an action before pushing (several quick saves go together).
  final Duration nudgeDelay;

  /// How long one run holds the sync lease (renewed per batch and every
  /// [leaseRenewEvery] while a request, a pull or an upload is going).
  final Duration leaseTtl;

  /// How often a running run renews its lease.
  final Duration leaseRenewEvery;

  /// Past the season codes' `valid_until` the ETag does not change; pull
  /// without `If-None-Match` at most this often until a fresh one arrives
  /// (a cached snapshot can be up to 2 h old).
  final Duration stalePullEvery;

  /// Runs in a row a command may get a 400 alone, with no other command to
  /// compare, before it is rejected as a client bug.
  final int lone400Limit;

  /// Tries after which a visit photo the server answers "not found" (or
  /// "not your visit") for, although its LogVisit was applied, is dropped.
  final int photoGiveUpAfter;

  /// How long sync log lines and finished rows are kept.
  final Duration retention;
}

/// Why a run did not happen.
enum SyncSkip {
  /// No network.
  offline,

  /// Another runner (the background worker) holds the sync lease.
  busy,
}

/// What one run did.
final class SyncRunResult {
  /// Creates a result.
  const SyncRunResult({
    this.skipped,
    this.sent = 0,
    this.applied = 0,
    this.merged = 0,
    this.conflicts = 0,
    this.rejected = 0,
    this.dropped = 0,
    this.pulled = false,
    this.notModified = false,
    this.photosUploaded = 0,
    this.waitingForBackoff = false,
    this.error,
  });

  /// Set when the run did not happen.
  final SyncSkip? skipped;

  /// Commands sent (a command sent twice counts twice).
  final int sent;

  /// Commands applied.
  final int applied;

  /// EnrolFarmers merged into an existing farmer.
  final int merged;

  /// Commands that came back as a conflict.
  final int conflicts;

  /// Commands rejected (by the server or the app).
  final int rejected;

  /// Commands dropped because their parent was rejected.
  final int dropped;

  /// A new snapshot was stored.
  final bool pulled;

  /// The snapshot was checked and had not changed (304).
  final bool notModified;

  /// Visit photos uploaded and confirmed.
  final int photosUploaded;

  /// Queued commands are waiting for their backoff to pass.
  final bool waitingForBackoff;

  /// What stopped the run early (`ApiError` for a server or network error),
  /// or null.
  final Object? error;

  /// The run happened and nothing failed.
  bool get ok => skipped == null && error == null;

  @override
  String toString() =>
      'SyncRunResult(${skipped?.name ?? 'ran'}: sent $sent, applied $applied, '
      'merged $merged, conflicts $conflicts, rejected $rejected, dropped '
      '$dropped, pulled $pulled, 304 $notModified, photos $photosUploaded'
      '${error == null ? '' : ', error $error'})';
}

/// The photos of one LogVisit: how many and their size in bytes.
typedef CommandPhotos = ({int count, int bytes});

/// What the Sync screen, the header badge and the PIN screen show.
final class SyncState {
  /// Creates a state.
  const SyncState({
    this.running = false,
    this.online = true,
    this.onWifi = true,
    this.runSent = 0,
    this.runTotal = 0,
    this.hasSnapshot = false,
    this.lastPullAt,
    this.lastPushAt,
    this.lastOnlineAt,
    this.queuedCount = 0,
    this.records = const [],
    this.conflicts = const [],
    this.rejected = const [],
    this.photosWaiting = 0,
    this.photosWaitingBytes = 0,
    this.photosHeldForWifi = false,
    this.photosOnWifiOnly = true,
    this.photosByCommand = const {},
    this.syncedToday = 0,
    this.nextRetryAt,
    this.lastError,
  });

  /// A run is going.
  final bool running;

  /// The phone has a network (follows the [ConnectivityService] all the
  /// time, also while the engine is stopped).
  final bool online;

  /// The network is Wi-Fi (false when offline or on mobile data).
  final bool onWifi;

  /// Commands of the current run the server has answered. 0 when no run is
  /// going.
  final int runSent;

  /// Commands of the current run: [runSent] plus those still queued (it
  /// grows when the FA saves during the run, shrinks when commands are
  /// dropped or rejected on the phone). 0 when no run is going.
  final int runTotal;

  /// A snapshot is stored (false right after the first sign-in).
  final bool hasSnapshot;

  /// UTC time of the last successful pull (also the login footer's "last
  /// sync").
  final DateTime? lastPullAt;

  /// UTC time of the last successful push.
  final DateTime? lastPushAt;

  /// UTC time the server last answered.
  final DateTime? lastOnlineAt;

  /// Records waiting to go up (queued or sending): the header badge.
  final int queuedCount;

  /// Every outbox row in seq order (the Sync screen's rows; applied ones
  /// show "Synced" until a snapshot carries them).
  final List<OutboxEntry> records;

  /// Conflicts waiting for Keep mine / Keep HO's.
  final List<OutboxEntry> conflicts;

  /// Rejected and dropped rows (red), until tapped away.
  final List<OutboxEntry> rejected;

  /// Visit photos still to upload.
  final int photosWaiting;

  /// Their size in bytes ("4.2 MB of photos waiting").
  final int photosWaitingBytes;

  /// Photos are waiting only because the phone is not on Wi-Fi.
  final bool photosHeldForWifi;

  /// "Upload photos on Wi-Fi only".
  final bool photosOnWifiOnly;

  /// Photos per LogVisit command ID, uploaded ones included (a synced visit
  /// still says "3 photos · 3.1 MB"); dropped photos are left out.
  final Map<String, CommandPhotos> photosByCommand;

  /// Records synced today (IST) from the sync log.
  final int syncedToday;

  /// When queued records are retried (backoff), or null.
  final DateTime? nextRetryAt;

  /// What stopped the last run (`ApiError`), or null after a clean run.
  final Object? lastError;

  /// How far the current run's push is, 0..1; null when no run is going or
  /// it has nothing to push.
  double? get runProgress =>
      running && runTotal > 0 ? (runSent / runTotal).clamp(0.0, 1.0) : null;

  /// Nothing waits: no queued records, conflicts, rejections or photos.
  bool get allSynced =>
      queuedCount == 0 &&
      conflicts.isEmpty &&
      rejected.isEmpty &&
      photosWaiting == 0;

  /// A copy with the given fields replaced.
  SyncState copyWith({
    bool? running,
    bool? online,
    bool? onWifi,
    int? runSent,
    int? runTotal,
    Object? lastError,
    bool clearError = false,
  }) => SyncState(
    running: running ?? this.running,
    online: online ?? this.online,
    onWifi: onWifi ?? this.onWifi,
    runSent: runSent ?? this.runSent,
    runTotal: runTotal ?? this.runTotal,
    hasSnapshot: hasSnapshot,
    lastPullAt: lastPullAt,
    lastPushAt: lastPushAt,
    lastOnlineAt: lastOnlineAt,
    queuedCount: queuedCount,
    records: records,
    conflicts: conflicts,
    rejected: rejected,
    photosWaiting: photosWaiting,
    photosWaitingBytes: photosWaitingBytes,
    photosHeldForWifi: photosHeldForWifi,
    photosOnWifiOnly: photosOnWifiOnly,
    photosByCommand: photosByCommand,
    syncedToday: syncedToday,
    nextRetryAt: nextRetryAt,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}

/// Pushes the outbox, pulls the snapshot and uploads visit photos.
final class SyncEngine {
  /// Creates the engine. [random] gives numbers in `[0, 1)` for the backoff
  /// jitter (fix it in tests); [owner] names this runner for the sync lease.
  SyncEngine({
    required this.store,
    required this.sync,
    required this.visitPhotos,
    required this.uploader,
    required this.connectivity,
    this.clock = const SystemClock(),
    double Function()? random,
    this.limits = const SyncLimits(),
    String? owner,
    this.projector = const Projector(),
  }) : _random = random ?? math.Random().nextDouble,
       owner = owner ?? 'ui-${DateTime.now().microsecondsSinceEpoch}' {
    _storeSub = store.changes.listen((_) => _scheduleRefresh());
    _wasOnline = connectivity.isOnline;
    _wasOnWifi = connectivity.isOnWifi;
    _netSub = connectivity.changes.listen((_) => _onNetwork());
    _scheduleRefresh();
  }

  /// The local database.
  final LocalStore store;

  /// Snapshot, status, commands.
  final SyncRepository sync;

  /// Visit photo upload URL and confirm.
  final VisitPhotosRepository visitPhotos;

  /// PUT to presigned URLs.
  final PhotoUploader uploader;

  /// Online / Wi-Fi.
  final ConnectivityService connectivity;

  /// Time source.
  final Clock clock;

  /// Batch sizes and timings.
  final SyncLimits limits;

  /// Holder name for the sync lease.
  final String owner;

  /// The local effect of commands.
  final Projector projector;

  final double Function() _random;

  StreamSubscription<void>? _storeSub;
  StreamSubscription<bool>? _netSub;
  Timer? _pollTimer;
  Timer? _nudgeTimer;
  Timer? _retryTimer;
  bool _started = false;
  bool _disposed = false;
  bool _wiping = false;
  bool _leaseLost = false;
  bool _holdingLease = false;
  Timer? _leaseTimer;
  bool _refreshQueued = false;

  Future<SyncRunResult>? _active;
  Completer<SyncRunResult>? _queued;
  SyncTrigger? _queuedTrigger;
  bool _queuedForce = false;

  SyncState _state = const SyncState();
  bool _running = false;
  Object? _lastError;
  bool _photosHeldForWifi = false;
  bool _wasOnline = true;
  bool _wasOnWifi = true;
  int _runSent = 0;
  int _runTotal = 0;
  final _states = StreamController<SyncState>.broadcast();

  /// The current state.
  SyncState get state => _state;

  /// Every new state.
  Stream<SyncState> get states => _states.stream;

  // -------------------------------------------------------------------------
  // Triggers

  /// "Sync now": resets the backoff, pushes everything, pulls the snapshot
  /// (with `If-None-Match` unless [force]) and uploads photos.
  Future<SyncRunResult> syncNow({bool force = false}) =>
      run(SyncTrigger.manual, force: force);

  /// Pushes soon (after [SyncLimits.nudgeDelay]); several nudges in a row
  /// make one run. Call after every action.
  void nudge() {
    if (_disposed) return;
    _nudgeTimer?.cancel();
    _nudgeTimer = Timer(limits.nudgeDelay, () {
      if (connectivity.isOnline) unawaited(run(SyncTrigger.action));
    });
  }

  /// Foreground: runs when the network comes back (or Wi-Fi does, for
  /// held photos), polls every [SyncLimits.pollInterval] and runs once now.
  void start() {
    if (_disposed || _started) return;
    _started = true;
    _pollTimer = Timer.periodic(
      limits.pollInterval,
      (_) => unawaited(run(SyncTrigger.timer)),
    );
    unawaited(run(SyncTrigger.foreground));
  }

  /// Background: stops the timers and network-triggered runs ([state] still
  /// follows the network). A run that is going finishes.
  void stop() {
    _started = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// The network changed: publish it; while started, run when the phone
  /// came online, or moved to Wi-Fi with photos held for it.
  void _onNetwork() {
    final online = connectivity.isOnline;
    final wifi = connectivity.isOnWifi;
    final cameOnline = online && !_wasOnline;
    final cameToWifi = wifi && !_wasOnWifi;
    _wasOnline = online;
    _wasOnWifi = wifi;
    _publish();
    if (!_started || _disposed) return;
    if (cameOnline || (cameToWifi && _state.photosWaiting > 0)) {
      unawaited(run(SyncTrigger.connectivity));
    }
  }

  /// Stops everything and closes [states].
  Future<void> dispose() async {
    stop();
    _disposed = true;
    _nudgeTimer?.cancel();
    await _storeSub?.cancel();
    await _netSub?.cancel();
    await _active;
    await _states.close();
  }

  /// Runs once for [trigger]. If a run is going, one more run is queued
  /// after it (requests in the meantime share it) and its result returned.
  Future<SyncRunResult> run(SyncTrigger trigger, {bool force = false}) {
    if (_wiping) {
      return Future.value(const SyncRunResult(skipped: SyncSkip.busy));
    }
    if (_active == null) {
      _active = _guarded(trigger, force);
      return _active!;
    }
    _queuedTrigger = _queuedTrigger == null
        ? trigger
        : (trigger == SyncTrigger.manual ? trigger : _queuedTrigger);
    _queuedForce = _queuedForce || force;
    return (_queued ??= Completer<SyncRunResult>()).future;
  }

  Future<SyncRunResult> _guarded(SyncTrigger trigger, bool force) async {
    try {
      return await _runOnce(trigger, force);
    } finally {
      final next = _queued;
      if (next != null && !_disposed && !_wiping) {
        final t = _queuedTrigger!;
        final f = _queuedForce;
        _queued = null;
        _queuedTrigger = null;
        _queuedForce = false;
        _active = _guarded(t, f);
        next.complete(_active);
      } else {
        _active = null;
        next?.complete(const SyncRunResult(skipped: SyncSkip.busy));
        _queued = null;
      }
    }
  }

  // -------------------------------------------------------------------------
  // For the session (LocalDataGuard): push before an update block, count.

  /// Records the server has not accepted (queued, sending, conflict) plus
  /// photos still to upload.
  Future<int> pendingCount() async {
    final rows = await store.outbox(
      states: {OutboxState.queued, OutboxState.sending, OutboxState.conflict},
    );
    final photos = await store.photos(
      states: {
        PhotoUploadState.waiting,
        PhotoUploadState.ready,
        PhotoUploadState.uploaded,
      },
    );
    return rows.length + photos.length;
  }

  /// Pushes now; true when nothing is left unsynced. Never throws.
  Future<bool> pushPending() async {
    try {
      await syncNow();
      return await pendingCount() == 0;
    } on Object {
      return false;
    }
  }

  /// Deletes all local data (device revoked, another FA on this phone).
  ///
  /// No run may start or continue meanwhile: runs asked for are refused, a
  /// queued follow-up run is dropped, the one going is waited for, and the
  /// lease is held over the wipe (so a background runner stays out too).
  Future<void> wipe() async {
    _wiping = true;
    _nudgeTimer?.cancel();
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      while (true) {
        final active = _active;
        if (active == null) break;
        await active;
      }
      final mine = await store.acquireSyncLease(
        owner,
        now: clock.now(),
        ttl: limits.leaseTtl,
      );
      try {
        await store.wipe();
      } finally {
        if (mine) await store.releaseSyncLease(owner);
      }
    } finally {
      _wiping = false;
    }
  }

  // -------------------------------------------------------------------------
  // One run

  Future<SyncRunResult> _runOnce(SyncTrigger trigger, bool force) async {
    if (!connectivity.isOnline) {
      _publish();
      return const SyncRunResult(skipped: SyncSkip.offline);
    }
    if (!await store.acquireSyncLease(
      owner,
      now: clock.now(),
      ttl: limits.leaseTtl,
    )) {
      return const SyncRunResult(skipped: SyncSkip.busy);
    }
    final c = _Counts();
    _running = true;
    _runSent = 0;
    _runTotal = 0;
    _leaseLost = false;
    _holdingLease = true;
    _leaseTimer = Timer.periodic(limits.leaseRenewEvery, (_) async {
      if (_leaseLost || !_holdingLease) return;
      final ok = await store.acquireSyncLease(
        owner,
        now: clock.now(),
        ttl: limits.leaseTtl,
      );
      if (!_holdingLease) {
        // The run ended while this renewal waited: give it back again.
        if (ok) await store.releaseSyncLease(owner);
        return;
      }
      if (!ok) _leaseLost = true;
    });
    _publish();
    try {
      await _recoverSending();
      final manual = trigger == SyncTrigger.manual;
      if (manual ||
          trigger == SyncTrigger.connectivity ||
          trigger == SyncTrigger.foreground) {
        await _resetBackoff();
      }
      final push = await _push(c, ignoreBackoff: manual);
      if (!push.stop) {
        final base = await store.baseSnapshot();
        var pull =
            base == null ||
            manual ||
            force ||
            push.versionsChanged ||
            push.needPull ||
            await _seasonsStalePull(base);
        if (!pull &&
            trigger != SyncTrigger.action &&
            trigger != SyncTrigger.retry) {
          pull = await _statusSaysPull();
        }
        if (pull && await _holdLease()) await _pull(c, force: force);
        if (await _holdLease()) {
          await _uploadPhotos(c, ignoreBackoff: manual);
        }
      }
      if (_leaseLost) c.leaseLost = true;
      _lastError = c.error;
    } on Object catch (e) {
      c.error = e;
      _lastError = e;
    } finally {
      _leaseTimer?.cancel();
      _leaseTimer = null;
      _holdingLease = false;
      await store.releaseSyncLease(owner);
      _running = false;
      _runSent = 0;
      _runTotal = 0;
      await _refreshState();
      _scheduleRetry();
    }
    return c.result();
  }

  /// Rows left `sending` by a run that died (app killed mid push) go back to
  /// `queued`. Safe because this runner holds the lease.
  Future<void> _recoverSending() => store.transaction((tx) async {
    for (final e in await tx.outbox(states: {OutboxState.sending})) {
      await tx.updateOutbox(e.copyWith(state: OutboxState.queued));
    }
  });

  Future<void> _resetBackoff() => store.transaction((tx) async {
    final meta = await tx.syncMeta();
    if (meta.pushFailures != 0) {
      await tx.putSyncMeta(meta.copyWith(pushFailures: 0));
    }
    for (final e in await tx.outbox(states: {OutboxState.queued})) {
      if (e.nextAttemptAt != null) {
        await tx.updateOutbox(e.copyWith(clearNextAttempt: true));
      }
    }
    for (final p in await tx.photos(
      states: {PhotoUploadState.ready, PhotoUploadState.uploaded},
    )) {
      if (p.nextAttemptAt != null) {
        await tx.putPhoto(p.copyWith(clearNextAttempt: true));
      }
    }
  });

  /// The backoff step after [failures] failures in a row, with jitter.
  Duration backoffFor(int failures) {
    final steps = limits.backoff;
    final base = steps[(math.max(failures, 1) - 1).clamp(0, steps.length - 1)];
    final factor = 1 + limits.jitter * (2 * _random() - 1);
    return Duration(milliseconds: (base.inMilliseconds * factor).round());
  }

  // -------------------------------------------------------------------------
  // Push

  Future<_PushOutcome> _push(_Counts c, {required bool ignoreBackoff}) async {
    var limit = limits.maxBatch;
    final outcome = _PushOutcome();
    // A 400 for a whole batch is a client bug in one command only when the
    // server is evidently taking other requests: bisecting must have seen a
    // batch go through since the 400s began, or a probe (one command that
    // does not need the suspect) must pass. Otherwise the 400 is about the
    // request, not a command (a proxy, a header, a server change), and
    // nothing is rejected.
    var bisecting = false;
    var acceptedSince400 = true;
    String? suspect;
    while (true) {
      if (!await _holdLease()) {
        c.leaseLost = true;
        outcome.stop = true;
        break;
      }
      await _expireConsentProofs(c);
      final queued = await store.outbox(states: {OutboxState.queued});
      _progress(queued.length);
      if (queued.isEmpty) break;
      final now = clock.now();
      final head = queued.first;
      if (suspect == null &&
          !ignoreBackoff &&
          head.nextAttemptAt != null &&
          head.nextAttemptAt!.isAfter(now)) {
        c.waitingForBackoff = true;
        break;
      }
      final List<OutboxEntry> planned;
      if (suspect != null) {
        final s = queued.where((e) => e.id == suspect).firstOrNull;
        final probe = s == null ? null : _probeFor(queued, s);
        if (s == null) {
          suspect = null;
          bisecting = false;
          continue;
        }
        if (probe == null) {
          // Nothing to compare with: count it and try again later; only a
          // command that keeps failing alone on its own is rejected.
          final count = ((s.meta[OutboxMeta.lone400] as num?) ?? 0) + 1;
          if (count >= limits.lone400Limit) {
            await _rejectLocally(
              c,
              s,
              LocalReason.clientInvalid,
              '${outcome.last400?.message}',
            );
            suspect = null;
            bisecting = false;
            limit = limits.maxBatch;
            continue;
          }
          await store.transaction((tx) async {
            final cur = await tx.outboxEntry(s.id);
            if (cur == null || cur.state != OutboxState.queued) return;
            await tx.updateOutbox(
              cur.copyWith(meta: {...cur.meta, OutboxMeta.lone400: count}),
            );
          });
          await _requeue([s], backoff: true, alreadyQueued: true);
          c.error = outcome.last400;
          outcome.stop = true;
          break;
        }
        planned = [probe];
      } else {
        planned = _takeBatch(queued, limit);
        if (planned.isEmpty) {
          // The head alone is bigger than a batch may be.
          await _rejectLocally(
            c,
            head,
            LocalReason.clientInvalid,
            ApiErrorCode.payloadTooLarge,
          );
          continue;
        }
      }
      final batch = await _markSending(planned);
      if (batch.isEmpty) continue; // changed under us (an edit): read again
      c.sent += batch.length;
      final CommandBatchResult res;
      try {
        res = await sync.submitCommands([
          for (final e in batch) e.toCommandIn(),
        ]);
      } on ApiError catch (e) {
        if (e.code == ApiErrorCode.payloadTooLarge || e.status == 413) {
          await _requeue(batch);
          if (batch.length == 1) {
            await _rejectLocally(
              c,
              batch.single,
              LocalReason.clientInvalid,
              e.message,
            );
            limit = limits.maxBatch;
          } else {
            limit = math.max(1, batch.length ~/ 2);
          }
          continue;
        }
        if (e.status == 400 ||
            e.code == ApiErrorCode.validationFailed ||
            e.code == ApiErrorCode.invalidRequest) {
          await _requeue(batch);
          outcome.last400 = e;
          if (suspect != null) {
            // The probe failed too: the 400 is not about one command.
            suspect = null;
            bisecting = false;
            await _requeue(
              [head, ...batch],
              backoff: true,
              alreadyQueued: true,
            );
            c.error = e;
            outcome.stop = true;
            break;
          }
          if (!bisecting) {
            bisecting = true;
            acceptedSince400 = false;
          }
          if (batch.length > 1) {
            limit = math.max(1, batch.length ~/ 2);
            continue;
          }
          if (acceptedSince400) {
            // Its neighbours went through: this one is the client bug.
            await _rejectLocally(
              c,
              batch.single,
              LocalReason.clientInvalid,
              e.message,
            );
            bisecting = false;
            limit = limits.maxBatch;
          } else {
            suspect = batch.single.id;
          }
          continue;
        }
        c.error = e;
        if (e.isRetryable) {
          await _requeue(batch, backoff: true, retryAfter: e.retryAfter);
        } else {
          // 401 / 403 / other: the session decides; resend on the next run.
          await _requeue(batch);
        }
        outcome.stop = true;
        break;
      } on Object {
        // Not an API answer (a bug, or the run is being torn down): nothing
        // is lost, the batch is simply sent again later.
        await _requeue(batch);
        rethrow;
      }
      acceptedSince400 = true;
      final probed = suspect;
      if (probed != null) {
        // The probe went through, the suspect alone did not: it is the bug.
        suspect = null;
        bisecting = false;
        limit = limits.maxBatch;
        final s = await store.outboxEntry(probed);
        if (s != null && s.state == OutboxState.queued) {
          await _rejectLocally(
            c,
            s,
            LocalReason.clientInvalid,
            '${outcome.last400?.message}',
          );
        }
      }
      final applied = await _applyResults(c, batch, res);
      _runSent += applied.answered;
      _publish();
      outcome.versionsChanged |= applied.versionsChanged;
      outcome.needPull |= applied.needPull;
      if (!res.complete) break;
    }
    return outcome;
  }

  /// Renews the sync lease; false when another runner holds it now (the run
  /// must stop: that runner may be sending the same rows).
  Future<bool> _holdLease() async {
    if (_leaseLost) return false;
    final ok = await store.acquireSyncLease(
      owner,
      now: clock.now(),
      ttl: limits.leaseTtl,
    );
    if (!ok) _leaseLost = true;
    return ok;
  }

  /// One queued command to send alone after [suspect] (the head) got a 400
  /// alone: the first one that needs nothing [suspect] (or a command that
  /// needs it) creates, and is not about the same entity. Null when there is
  /// none. Sending it before [suspect] is safe: they are independent.
  OutboxEntry? _probeFor(List<OutboxEntry> queued, OutboxEntry suspect) {
    final tainted = {suspect.id};
    final created = <String>{suspect.entityId};
    try {
      created.addAll(suspect.command.createdIds);
    } on FormatException {
      // Its entity ID is enough.
    }
    for (final e in queued) {
      if (e.id == suspect.id) continue;
      Set<String> needs;
      Set<String> makes;
      try {
        needs = e.command.dependsOnIds;
        makes = e.command.createdIds;
      } on FormatException {
        needs = const {};
        makes = const {};
      }
      final linked =
          tainted.contains(e.dependsOnId) ||
          tainted.contains(e.meta[OutboxMeta.versionParent]) ||
          created.contains(e.entityId) ||
          needs.any(created.contains);
      if (linked) {
        tainted.add(e.id);
        created
          ..add(e.entityId)
          ..addAll(makes);
        continue;
      }
      return e;
    }
    return null;
  }

  /// Marks [planned] `sending` in one transaction, re-reading every row: the
  /// batch ends before the first row that changed since it was read (an
  /// "Edit this visit" that landed in between, or another runner). Returns
  /// the rows as written, which is exactly what is sent.
  Future<List<OutboxEntry>> _markSending(List<OutboxEntry> planned) =>
      store.transaction((tx) async {
        final out = <OutboxEntry>[];
        for (final e in planned) {
          final cur = await tx.outboxEntry(e.id);
          if (cur == null ||
              cur.state != OutboxState.queued ||
              cur.attempts != e.attempts ||
              !mapEquals(cur.payload, e.payload)) {
            break;
          }
          final sending = cur.copyWith(
            state: OutboxState.sending,
            attempts: cur.attempts + 1,
            clearNextAttempt: true,
          );
          await tx.updateOutbox(sending);
          out.add(sending);
        }
        return out;
      });

  /// The longest run of [queued] from the head that fits [limit] commands and
  /// [SyncLimits.maxBatchBytes]. Empty when the head alone does not fit.
  ///
  /// Two more cuts, so the phone sees an answer before it sends what hangs
  /// on it:
  /// * an edit whose `version_parent` is already in the batch waits for the
  ///   next one (its `expected_version` assumes the parent applies);
  /// * the batch ends after a StartSeason that queued commands use (if it
  ///   clashes with the plot's active season, they are moved to that season
  ///   before they go).
  List<OutboxEntry> _takeBatch(List<OutboxEntry> queued, int limit) {
    final batch = <OutboxEntry>[];
    final ids = <String>{};
    var bytes = 16; // {"commands":[]}
    for (var i = 0; i < queued.length; i++) {
      final e = queued[i];
      if (batch.length >= limit) break;
      if (ids.contains(e.meta[OutboxMeta.versionParent])) break;
      final size = utf8.encode(jsonEncode(e.toCommandIn().toJson())).length + 1;
      if (bytes + size > limits.maxBatchBytes) break;
      bytes += size;
      batch.add(e);
      ids.add(e.id);
      if (e.type == CommandType.startSeason &&
          _usedLater(e.entityId, queued.skip(i + 1))) {
        break;
      }
    }
    return batch;
  }

  static bool _usedLater(String id, Iterable<OutboxEntry> later) {
    for (final e in later) {
      try {
        if (e.command.dependsOnIds.contains(id)) return true;
      } on FormatException {
        continue;
      }
    }
    return false;
  }

  Future<void> _requeue(
    List<OutboxEntry> batch, {
    bool backoff = false,
    Duration? retryAfter,
    bool alreadyQueued = false,
  }) => store.transaction((tx) async {
    DateTime? next;
    if (backoff) {
      final meta = await tx.syncMeta();
      final failures = meta.pushFailures + 1;
      await tx.putSyncMeta(meta.copyWith(pushFailures: failures));
      next = clock.now().add(retryAfter ?? backoffFor(failures));
    }
    for (final e in batch) {
      final cur = await tx.outboxEntry(e.id);
      if (cur == null) continue;
      if (cur.state != OutboxState.sending &&
          !(alreadyQueued && cur.state == OutboxState.queued)) {
        continue;
      }
      await tx.updateOutbox(
        next == null
            ? cur.copyWith(state: OutboxState.queued)
            : cur.copyWith(state: OutboxState.queued, nextAttemptAt: next),
      );
    }
  });

  Future<_PushOutcome> _applyResults(
    _Counts c,
    List<OutboxEntry> batch,
    CommandBatchResult res,
  ) => store.transaction((tx) async {
    final outcome = _PushOutcome();
    final now = clock.now();
    final byId = {for (final r in res.results) r.id: r};
    final unprocessed = <OutboxEntry>[];
    var rebuild = false;
    var any = false;
    for (var i = 0; i < batch.length; i++) {
      final cur = await tx.outboxEntry(batch[i].id);
      // Gone or no longer sending: another runner took it over (it holds
      // the answer now). Never write a stale copy back.
      if (cur == null || cur.state != OutboxState.sending) continue;
      final r = byId[cur.id];
      if (r == null || (res.retryFrom != null && i >= res.retryFrom!)) {
        unprocessed.add(cur);
        continue;
      }
      any = true;
      outcome.answered++;
      switch (r.status) {
        case CommandStatus.applied:
          await tx.updateOutbox(
            cur.copyWith(
              state: OutboxState.applied,
              result: r,
              batchTerritoryVersion: res.territoryVersion,
            ),
          );
          await _log(tx, now, SyncLogKind.applied, cur);
          await _photosReady(tx, cur.id);
          c.applied++;
        case CommandStatus.merged:
          final from = cur.entityId;
          final into = r.mergedInto;
          if (into == null || into == from) {
            await tx.updateOutbox(
              cur.copyWith(
                state: OutboxState.applied,
                result: r,
                batchTerritoryVersion: res.territoryVersion,
              ),
            );
            await _log(tx, now, SyncLogKind.applied, cur);
            c.applied++;
            break;
          }
          // Queued payloads keep the minted ID (the server follows the
          // alias, and a photo key under farmers/<minted>/ is only accepted
          // with it); the projection reads them through the alias.
          await _addAlias(tx, from, into);
          await tx.updateOutbox(
            cur.copyWith(
              state: OutboxState.merged,
              result: r,
              batchTerritoryVersion: res.territoryVersion,
              meta: {...cur.meta, OutboxMeta.mergedFrom: from},
            ),
          );
          // The log line keeps the alias after the row is gone.
          await _log(
            tx,
            now,
            SyncLogKind.merged,
            cur,
            entityId: from,
            message: into,
          );
          rebuild = true;
          outcome.needPull = true;
          c.merged++;
        case CommandStatus.conflict:
          await tx.updateOutbox(
            cur.copyWith(state: OutboxState.conflict, result: r),
          );
          await _log(
            tx,
            now,
            SyncLogKind.conflict,
            cur,
            message: r.conflict?.field,
          );
          if (cur.type == CommandType.startSeason) {
            await _moveToActiveSeason(tx, cur, r);
          } else {
            await _foldLaterEdits(tx, cur);
          }
          rebuild = true;
          outcome.needPull = true;
          c.conflicts++;
        case CommandStatus.rejected || CommandStatus.unknown:
          await tx.updateOutbox(
            cur.copyWith(state: OutboxState.rejected, result: r),
          );
          await _log(tx, now, SyncLogKind.rejected, cur, message: r.error);
          await _rebaseLaterEdits(tx, cur);
          rebuild = true;
          c.rejected++;
      }
    }
    if (unprocessed.isNotEmpty) {
      // retry_from: resend the rest after backoff.
      final meta = await tx.syncMeta();
      final failures = meta.pushFailures + 1;
      await tx.putSyncMeta(meta.copyWith(pushFailures: failures));
      final next = now.add(backoffFor(failures));
      for (final e in unprocessed) {
        await tx.updateOutbox(
          e.copyWith(state: OutboxState.queued, nextAttemptAt: next),
        );
      }
    }
    final dropped = await _dropDependents(tx, now);
    c.dropped += dropped;
    if (dropped > 0) rebuild = true;
    await _dropPhotosOfDiscarded(tx, now);
    final meta = await tx.syncMeta();
    outcome.versionsChanged =
        res.territoryVersion != meta.territoryVersion ||
        res.mastersVersion != meta.mastersVersion;
    await tx.putSyncMeta(
      meta.copyWith(
        lastPushAt: any ? now : null,
        lastOnlineAt: now,
        pushFailures: unprocessed.isEmpty ? 0 : null,
      ),
    );
    if (rebuild) await rebuildTerritory(tx, projector: projector);
    return outcome;
  });

  Future<void> _addAlias(LocalTables tx, String from, String into) async {
    final meta = await tx.syncMeta();
    if (meta.idAliases[from] == into) return;
    await tx.putSyncMeta(
      meta.copyWith(idAliases: {...meta.idAliases, from: into}),
    );
  }

  /// A StartSeason that clashed with the plot's active season
  /// (`conflict{field: active_season, theirs: {season_id, season_code,
  /// crop_id}}`, backend `farmers.StartSeason`): the season was never
  /// created, so every queued command that uses it moves to the server's
  /// active season (the server does not follow season aliases; the batch cut
  /// in [_takeBatch] keeps them unsent until now). A LogVisit's stage is
  /// dropped when that season grows another crop. The conflict stays for
  /// the FA to accept (Keep HO's).
  Future<void> _moveToActiveSeason(
    LocalTables tx,
    OutboxEntry conflict,
    CommandResult r,
  ) async {
    final theirs = r.conflict?.theirs;
    if (r.conflict?.field != 'active_season' || theirs is! Map) return;
    final into = theirs['season_id'];
    if (into is! String || into.isEmpty) return;
    final from = conflict.entityId;
    final String? yourCrop;
    try {
      yourCrop = (conflict.command as StartSeasonPayload).cropId;
    } on Object {
      return;
    }
    final theirCrop = theirs['crop_id'];
    final sameCrop = theirCrop is! String || theirCrop == yourCrop;
    await _addAlias(tx, from, into);
    final cur = await tx.outboxEntry(conflict.id) ?? conflict;
    await tx.updateOutbox(
      cur.copyWith(meta: {...cur.meta, OutboxMeta.seasonReplacedBy: into}),
    );
    for (final e in await tx.outbox(states: {OutboxState.queued})) {
      final CommandPayload c;
      try {
        c = e.command;
      } on FormatException {
        continue;
      }
      if (!c.dependsOnIds.contains(from)) continue;
      var moved = c.replaceId(from, into);
      if (moved is LogVisitPayload && !sameCrop && moved.stageId != null) {
        moved = LogVisitPayload(
          visitId: moved.visitId,
          farmerId: moved.farmerId,
          plotId: moved.plotId,
          seasonId: moved.seasonId,
          visitedAt: moved.visitedAt,
          location: moved.location,
          farmerPresent: moved.farmerPresent,
          notes: moved.notes,
          issues: moved.issues,
          photos: moved.photos,
          nextVisit: moved.nextVisit,
        );
      }
      await tx.updateOutbox(e.copyWith(payload: moved.toJson()));
    }
  }

  /// After an edit (SavePlot / UpdateFarmer) came back as a conflict: later
  /// queued edits of the same plot / farmer are folded into it (their
  /// values on top, in order) and removed, so the FA sees one card with
  /// their latest values, and Keep mine can never land after a later edit.
  /// Their `expected_version` assumed this one applied, so sent as they are
  /// they would either conflict again or, worse, match a version HO made and
  /// overwrite HO's change unseen.
  Future<void> _foldLaterEdits(LocalTables tx, OutboxEntry conflict) async {
    if (conflict.type != CommandType.savePlot &&
        conflict.type != CommandType.updateFarmer) {
      return;
    }
    final aliases = (await tx.syncMeta()).idAliases;
    String key(String id) => aliases[id] ?? id;
    var target = (await tx.outboxEntry(conflict.id))!;
    final folded = <String>[
      ...?(target.meta[OutboxMeta.folded] as List?)?.cast<String>(),
    ];
    for (final e in await tx.outbox(states: {OutboxState.queued})) {
      if (e.seq <= conflict.seq || e.type != conflict.type) continue;
      if (key(e.entityId) != key(conflict.entityId)) continue;
      final CommandPayload later;
      final CommandPayload mine;
      try {
        later = e.command;
        mine = target.command;
      } on FormatException {
        continue;
      }
      final merged = switch ((mine, later)) {
        (final UpdateFarmerPayload a, final UpdateFarmerPayload b) =>
          UpdateFarmerPayload(
            farmerId: a.farmerId,
            expectedVersion: a.expectedVersion,
            fields: UpdateFarmerFields(
              name: b.fields.name ?? a.fields.name,
              nameTe: b.fields.nameTe ?? a.fields.nameTe,
              language: b.fields.language ?? a.fields.language,
              villageId: b.fields.villageId ?? a.fields.villageId,
              photoKey: b.fields.photoKey ?? a.fields.photoKey,
            ),
          ),
        (final SavePlotPayload a, final SavePlotPayload b) => SavePlotPayload(
          plotId: a.plotId,
          farmerId: a.farmerId,
          label: b.label,
          boundaryGeoJson: b.boundaryGeoJson,
          pin: b.pin,
          areaAcres: b.areaAcres,
          areaSource: b.areaSource,
          gpsAccuracyM: b.gpsAccuracyM,
          expectedVersion: a.expectedVersion,
        ),
        _ => null,
      };
      if (merged == null) continue;
      folded.add(e.id);
      target = target.copyWith(
        payload: merged.toJson(),
        meta: {...target.meta, OutboxMeta.folded: folded},
      );
      await tx.deleteOutbox(e.id);
    }
    await tx.updateOutbox(target);
  }

  /// After an edit was rejected: later queued edits of the same entity that
  /// counted on it (`version_parent`) go at the version it was sent with.
  Future<void> _rebaseLaterEdits(LocalTables tx, OutboxEntry rejected) async {
    for (final e in await tx.outbox(states: {OutboxState.queued})) {
      if (e.meta[OutboxMeta.versionParent] != rejected.id) continue;
      final CommandPayload c;
      final CommandPayload parent;
      try {
        c = e.command;
        parent = rejected.command;
      } on FormatException {
        continue;
      }
      final CommandPayload? rebased = switch ((parent, c)) {
        (final UpdateFarmerPayload a, final UpdateFarmerPayload b) =>
          UpdateFarmerPayload(
            farmerId: b.farmerId,
            expectedVersion: a.expectedVersion,
            fields: b.fields,
          ),
        (final SavePlotPayload a, final SavePlotPayload b)
            when a.expectedVersion != null =>
          SavePlotPayload(
            plotId: b.plotId,
            farmerId: b.farmerId,
            label: b.label,
            boundaryGeoJson: b.boundaryGeoJson,
            pin: b.pin,
            areaAcres: b.areaAcres,
            areaSource: b.areaSource,
            gpsAccuracyM: b.gpsAccuracyM,
            expectedVersion: a.expectedVersion,
          ),
        _ => null,
      };
      if (rebased == null) continue;
      final meta = {...e.meta}..remove(OutboxMeta.versionParent);
      final grand = rejected.meta[OutboxMeta.versionParent];
      if (grand != null) meta[OutboxMeta.versionParent] = grand;
      await tx.updateOutbox(e.copyWith(payload: rebased.toJson(), meta: meta));
    }
  }

  /// Marks every command whose parent is rejected or dropped as dropped
  /// (transitively). Returns how many.
  ///
  /// Only commands the server has not judged (queued or sending) are
  /// dropped. One the server already answered for keeps its own result: a
  /// child rejected in the same batch as its parent stays `rejected` with
  /// the server's reason (counted once, as rejected), and a conflict stays a
  /// conflict.
  Future<int> _dropDependents(LocalTables tx, DateTime now) async {
    var count = 0;
    while (true) {
      final rows = await tx.outbox();
      final bad = {
        for (final r in rows)
          if (r.state == OutboxState.rejected || r.state == OutboxState.dropped)
            r.id,
      };
      final victims = [
        for (final r in rows)
          if (r.dependsOnId != null &&
              bad.contains(r.dependsOnId) &&
              r.state.isPending)
            r,
      ];
      if (victims.isEmpty) return count;
      for (final r in victims) {
        await tx.updateOutbox(
          r.copyWith(
            state: OutboxState.dropped,
            result: CommandResult(
              id: r.id,
              status: CommandStatus.rejected,
              entityId: r.entityId,
              error: LocalReason.parentRejected,
            ),
          ),
        );
        await _log(
          tx,
          now,
          SyncLogKind.dropped,
          r,
          message: LocalReason.parentRejected,
        );
        count++;
      }
    }
  }

  /// Photos of rejected or dropped LogVisits will never upload.
  Future<void> _dropPhotosOfDiscarded(LocalTables tx, DateTime now) async {
    for (final p in await tx.photos(
      states: {
        PhotoUploadState.waiting,
        PhotoUploadState.ready,
        PhotoUploadState.uploaded,
      },
    )) {
      final e = await tx.outboxEntry(p.commandId);
      if (e == null || !e.state.isDiscarded) continue;
      await tx.putPhoto(
        p.copyWith(state: PhotoUploadState.dropped, bytes: Uint8List(0)),
      );
      await tx.addSyncLog(
        SyncLogEntry(
          id: 0,
          at: now,
          kind: SyncLogKind.photoDropped,
          commandId: p.commandId,
          commandType: CommandType.logVisit,
          entityId: p.photoId,
          message: e.result?.error,
        ),
      );
    }
  }

  Future<void> _photosReady(LocalTables tx, String commandId) async {
    for (final p in await tx.photos(
      commandId: commandId,
      states: {PhotoUploadState.waiting},
    )) {
      await tx.putPhoto(p.copyWith(state: PhotoUploadState.ready));
    }
  }

  /// Rejects [entry] on the phone with [reason] (no server answer), drops
  /// its dependents and takes back its effect.
  Future<void> _rejectLocally(
    _Counts c,
    OutboxEntry entry,
    String reason,
    String detail,
  ) => store.transaction((tx) async {
    final now = clock.now();
    final cur = await tx.outboxEntry(entry.id) ?? entry;
    await tx.updateOutbox(
      cur.copyWith(
        state: OutboxState.rejected,
        result: CommandResult(
          id: cur.id,
          status: CommandStatus.rejected,
          entityId: cur.entityId,
          error: reason,
        ),
        meta: {...cur.meta, OutboxMeta.detail: detail},
      ),
    );
    await _log(tx, now, SyncLogKind.rejected, cur, message: reason);
    c.rejected++;
    c.dropped += await _dropDependents(tx, now);
    await _dropPhotosOfDiscarded(tx, now);
    await rebuildTerritory(tx, projector: projector);
  });

  /// A consent proof is valid 7 days. Past that at send time, an
  /// EnrolFarmer goes without it (the farmer is enrolled consent pending,
  /// RecordConsent later) and a RecordConsent cannot be sent at all.
  Future<void> _expireConsentProofs(_Counts c) async {
    final now = clock.now();
    final expired = [
      for (final e in await store.outbox(states: {OutboxState.queued}))
        if (_proofExpired(e, now)) e,
    ];
    for (final e in expired) {
      if (e.type == CommandType.recordConsent) {
        await _rejectLocally(
          c,
          e,
          LocalReason.consentProofExpired,
          'consent proof expired',
        );
        continue;
      }
      final p = e.command as EnrolFarmerPayload;
      final stripped = EnrolFarmerPayload(
        farmerId: p.farmerId,
        phone: p.phone,
        name: p.name,
        nameTe: p.nameTe,
        language: p.language,
        villageId: p.villageId,
        photoKey: p.photoKey,
        consent: EnrolConsent(
          purposes: p.consent.purposes,
          otpProof: null,
          audioPlayed: p.consent.audioPlayed,
          noticeVersion: p.consent.noticeVersion,
        ),
      );
      await store.transaction((tx) async {
        final cur = await tx.outboxEntry(e.id);
        if (cur == null || cur.state != OutboxState.queued) return;
        await tx.updateOutbox(
          cur.copyWith(
            payload: stripped.toJson(),
            meta: {...cur.meta, OutboxMeta.consentProofDropped: true},
          ),
        );
        await rebuildTerritory(tx, projector: projector);
      });
    }
  }

  static bool _proofExpired(OutboxEntry e, DateTime now) {
    if (e.type != CommandType.enrolFarmer &&
        e.type != CommandType.recordConsent) {
      return false;
    }
    if (e.meta[OutboxMeta.consentProofDropped] == true) return false;
    final at = DateTime.tryParse('${e.meta[OutboxMeta.consentProofExpiresAt]}');
    if (at == null || at.isAfter(now)) return false;
    if (e.type == CommandType.enrolFarmer) {
      return e.payload['consent'] is Map<String, Object?> &&
          (e.payload['consent']! as Map<String, Object?>)['otp_proof'] != null;
    }
    return true;
  }

  Future<void> _log(
    LocalTables tx,
    DateTime now,
    SyncLogKind kind,
    OutboxEntry e, {
    String? entityId,
    String? message,
  }) async {
    String? farmerId;
    try {
      farmerId = e.farmerId;
    } on FormatException {
      farmerId = null;
    }
    await tx.addSyncLog(
      SyncLogEntry(
        id: 0,
        at: now,
        kind: kind,
        commandId: e.id,
        commandType: e.type,
        entityId: entityId ?? e.entityId,
        farmerId: farmerId,
        message: message,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Pull

  /// True when the season codes are past `valid_until` (IST) and no pull
  /// was tried for [SyncLimits.stalePullEvery]: the ETag does not change on a
  /// season boundary, so the status poll would never ask for one.
  Future<bool> _seasonsStalePull(Snapshot base) async {
    if (!_seasonsStale(base)) return false;
    final last = (await store.syncMeta()).lastPullAt;
    return last == null ||
        clock.now().difference(last) >= limits.stalePullEvery;
  }

  bool _seasonsStale(Snapshot base) =>
      LocalDate.istOf(clock.now()).isAfter(base.masters.seasonCodes.validUntil);

  Future<bool> _statusSaysPull() async {
    final status = await sync.getStatus();
    final meta = await store.syncMeta();
    await store.putSyncMeta(meta.copyWith(lastOnlineAt: clock.now()));
    return status.etag != meta.etag;
  }

  Future<void> _pull(_Counts c, {required bool force}) async {
    final meta = await store.syncMeta();
    final base = await store.baseSnapshot();
    // The ETag does not change on a season boundary: past valid_until, pull
    // without If-None-Match.
    final seasonsStale = base != null && _seasonsStale(base);
    final ifNoneMatch = force || seasonsStale || base == null
        ? null
        : meta.etag;
    final result = await sync.getSnapshot(ifNoneMatch: ifNoneMatch);
    switch (result) {
      case SnapshotNotModified():
        await store.transaction((tx) async {
          final now = clock.now();
          final m = await tx.syncMeta();
          await tx.putSyncMeta(m.copyWith(lastPullAt: now, lastOnlineAt: now));
          if (await _deleteCovered(tx, m.territoryVersion) > 0) {
            await rebuildTerritory(tx, projector: projector);
          }
        });
        c.notModified = true;
      case SnapshotFetched(:final snapshot, :final etag):
        await writeSnapshot(snapshot, etag: etag);
        c.pulled = true;
    }
  }

  /// Stores [snapshot] in one transaction: base tables replaced, applied
  /// rows it carries deleted, the outbox replayed on top, `sync_meta`
  /// updated, old log lines and finished rows pruned.
  Future<void> writeSnapshot(Snapshot snapshot, {String? etag}) =>
      store.transaction((tx) async {
        final now = clock.now();
        await tx.putBaseSnapshot(snapshot);
        await _deleteCovered(tx, snapshot.territoryVersion);
        await _prune(tx, now);
        await rebuildTerritory(tx, projector: projector);
        final meta = await tx.syncMeta();
        await tx.putSyncMeta(
          meta.copyWith(
            etag: etag ?? snapshot.etag,
            territoryVersion: snapshot.territoryVersion,
            mastersVersion: snapshot.mastersVersion,
            generatedAt: snapshot.generatedAt,
            lastPullAt: now,
            lastOnlineAt: now,
          ),
        );
      });

  /// Deletes applied / merged rows a snapshot at [territoryVersion] carries.
  Future<int> _deleteCovered(LocalTables tx, int? territoryVersion) async {
    if (territoryVersion == null) return 0;
    var n = 0;
    for (final e in await tx.outbox(
      states: {OutboxState.applied, OutboxState.merged},
    )) {
      final v = e.batchTerritoryVersion;
      if (v != null && v <= territoryVersion) {
        await tx.deleteOutbox(e.id);
        n++;
      }
    }
    return n;
  }

  /// Drops log lines and finished rows (rejected, dropped, resolved; done and
  /// dropped photos) older than [SyncLimits.retention]. Conflicts are kept
  /// until the FA picks a side.
  Future<void> _prune(LocalTables tx, DateTime now) async {
    final before = now.subtract(limits.retention);
    await tx.pruneSyncLog(before);
    for (final e in await tx.outbox(
      states: {OutboxState.rejected, OutboxState.dropped, OutboxState.resolved},
    )) {
      if (e.createdAt.isBefore(before)) await tx.deleteOutbox(e.id);
    }
    for (final p in await tx.photos(
      states: {PhotoUploadState.done, PhotoUploadState.dropped},
    )) {
      if (p.createdAt.isBefore(before)) await tx.deletePhoto(p.photoId);
    }
  }

  // -------------------------------------------------------------------------
  // Photos

  Future<void> _uploadPhotos(_Counts c, {required bool ignoreBackoff}) async {
    final settings = await store.settings();
    final rows = await store.photos(
      states: {PhotoUploadState.ready, PhotoUploadState.uploaded},
    );
    _photosHeldForWifi =
        rows.isNotEmpty && settings.photosOnWifiOnly && !connectivity.isOnWifi;
    if (_photosHeldForWifi) return;
    for (final row in rows) {
      if (_leaseLost) break;
      final now = clock.now();
      if (!ignoreBackoff &&
          row.nextAttemptAt != null &&
          row.nextAttemptAt!.isAfter(now)) {
        continue;
      }
      var p = row;
      var askingForUrl = false;
      try {
        if (p.state == PhotoUploadState.ready) {
          askingForUrl = true;
          VisitPhotoUpload? target;
          try {
            target = await visitPhotos.createUploadUrl(
              visitId: p.visitId,
              photoId: p.photoId,
              contentType: p.contentType,
              bytes: p.byteCount,
            );
          } on ApiError catch (e) {
            if (e.code != ApiErrorCode.photoAlreadyUploaded) rethrow;
          }
          askingForUrl = false;
          if (target != null) {
            await uploader.upload(target, p.bytes);
            p = p.copyWith(
              state: PhotoUploadState.uploaded,
              storageKey: target.storageKey,
            );
            await store.putPhoto(p);
          }
        }
        try {
          await visitPhotos.confirmUpload(
            visitId: p.visitId,
            photoId: p.photoId,
            sha256: p.sha256,
          );
        } on ApiError catch (e) {
          if (e.code != ApiErrorCode.uploadMissing) rethrow;
          // Not in storage after all: PUT again next time.
          await store.putPhoto(
            p.copyWith(
              state: PhotoUploadState.ready,
              attempts: p.attempts + 1,
              lastError: e.code,
            ),
          );
          continue;
        }
        await store.transaction((tx) async {
          await tx.putPhoto(
            p.copyWith(
              state: PhotoUploadState.done,
              bytes: Uint8List(0),
              clearNextAttempt: true,
            ),
          );
          await tx.addSyncLog(
            SyncLogEntry(
              id: 0,
              at: clock.now(),
              kind: SyncLogKind.photoUploaded,
              commandId: p.commandId,
              commandType: CommandType.logVisit,
              entityId: p.photoId,
            ),
          );
        });
        c.photosUploaded++;
      } on ApiError catch (e) {
        final failed = p.copyWith(
          attempts: p.attempts + 1,
          nextAttemptAt: now.add(e.retryAfter ?? backoffFor(p.attempts + 1)),
          lastError: e.code,
        );
        if (e.code == ApiErrorCode.validationFailed) {
          // A wrong content type is a client bug: retrying cannot help.
          await store.putPhoto(
            failed.copyWith(
              state: PhotoUploadState.dropped,
              bytes: Uint8List(0),
            ),
          );
          continue;
        }
        final notOurs =
            e.code == ApiErrorCode.notFound ||
            (askingForUrl && e.code == ApiErrorCode.forbidden);
        if (notOurs) {
          // The server has no such photo on a visit of this FA: drop at once
          // if its LogVisit was refused; drop after a few tries when the
          // LogVisit was applied (or is long gone) and the server still has
          // no such photo ID, so it does not wait forever. While the LogVisit
          // is still pending, wait.
          final cmd = await store.outboxEntry(p.commandId);
          final refused = cmd != null && cmd.state.isDiscarded;
          final settled = cmd == null || cmd.state.isSynced;
          if (refused ||
              (settled && failed.attempts >= limits.photoGiveUpAfter)) {
            await store.transaction((tx) async {
              await tx.putPhoto(
                failed.copyWith(
                  state: PhotoUploadState.dropped,
                  bytes: Uint8List(0),
                ),
              );
              await tx.addSyncLog(
                SyncLogEntry(
                  id: 0,
                  at: clock.now(),
                  kind: SyncLogKind.photoDropped,
                  commandId: p.commandId,
                  commandType: CommandType.logVisit,
                  entityId: p.photoId,
                  message: refused
                      ? cmd.result?.error
                      : LocalReason.photoNotOnServer,
                ),
              );
            });
            continue;
          }
        }
        // forbidden (URL expired) keeps the state: a new URL next time.
        await store.putPhoto(failed);
        if (e.isNetwork) {
          c.error ??= e;
          break;
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // State

  void _scheduleRefresh() {
    if (_refreshQueued || _disposed) return;
    _refreshQueued = true;
    scheduleMicrotask(() async {
      _refreshQueued = false;
      if (_disposed) return;
      await _refreshState();
    });
  }

  /// The run's progress with [queued] commands still to send.
  void _progress(int queued) {
    final total = _runSent + queued;
    if (total == _runTotal) return;
    _runTotal = total;
    _publish();
  }

  void _publish() {
    if (_disposed) return;
    _state = _state.copyWith(
      running: _running,
      online: connectivity.isOnline,
      onWifi: connectivity.isOnWifi,
      runSent: _runSent,
      runTotal: _runTotal,
      lastError: _lastError,
      clearError: _lastError == null,
    );
    _states.add(_state);
  }

  Future<void> _refreshState() async {
    if (_disposed) return;
    final now = clock.now();
    final today = LocalDate.istOf(now);
    final istMidnightUtc = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(hours: 5, minutes: 30));
    final rows = await store.outbox();
    final allPhotos = await store.photos();
    final photos = [
      for (final p in allPhotos)
        if (p.state == PhotoUploadState.waiting ||
            p.state == PhotoUploadState.ready ||
            p.state == PhotoUploadState.uploaded)
          p,
    ];
    final byCommand = <String, CommandPhotos>{};
    for (final p in allPhotos) {
      if (p.state == PhotoUploadState.dropped) continue;
      final c = byCommand[p.commandId] ?? (count: 0, bytes: 0);
      byCommand[p.commandId] = (
        count: c.count + 1,
        bytes: c.bytes + p.byteCount,
      );
    }
    final log = await store.syncLog(since: istMidnightUtc);
    final meta = await store.syncMeta();
    final settings = await store.settings();
    final hasSnapshot = await store.baseSnapshot() != null;
    final queued = [
      for (final e in rows)
        if (e.state.isPending) e,
    ];
    DateTime? retry;
    for (final e in queued) {
      final at = e.nextAttemptAt;
      if (at != null && (retry == null || at.isBefore(retry))) retry = at;
    }
    if (_disposed) return;
    _state = SyncState(
      running: _running,
      online: connectivity.isOnline,
      onWifi: connectivity.isOnWifi,
      runSent: _runSent,
      runTotal: _runTotal,
      hasSnapshot: hasSnapshot,
      lastPullAt: meta.lastPullAt,
      lastPushAt: meta.lastPushAt,
      lastOnlineAt: meta.lastOnlineAt,
      queuedCount: queued.length,
      records: rows,
      conflicts: [
        for (final e in rows)
          if (e.state == OutboxState.conflict) e,
      ],
      rejected: [
        for (final e in rows)
          if (e.state == OutboxState.rejected || e.state == OutboxState.dropped)
            e,
      ],
      photosWaiting: photos.length,
      photosWaitingBytes: photos.fold(0, (sum, p) => sum + p.byteCount),
      photosHeldForWifi:
          _photosHeldForWifi &&
          settings.photosOnWifiOnly &&
          !connectivity.isOnWifi,
      photosOnWifiOnly: settings.photosOnWifiOnly,
      photosByCommand: byCommand,
      syncedToday: log.where((l) => l.isSynced).length,
      nextRetryAt: retry,
      lastError: _lastError,
    );
    _states.add(_state);
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final at = _state.nextRetryAt;
    if (!_started || _disposed || at == null) return;
    final wait = at.difference(clock.now());
    _retryTimer = Timer(
      wait.isNegative ? Duration.zero : wait,
      () => unawaited(run(SyncTrigger.retry)),
    );
  }
}

final class _PushOutcome {
  bool stop = false;
  ApiError? last400;
  int answered = 0;
  bool versionsChanged = false;
  bool needPull = false;
}

final class _Counts {
  int sent = 0;
  int applied = 0;
  int merged = 0;
  int conflicts = 0;
  int rejected = 0;
  int dropped = 0;
  bool pulled = false;
  bool notModified = false;
  int photosUploaded = 0;
  bool waitingForBackoff = false;
  bool leaseLost = false;
  Object? error;

  SyncRunResult result() => SyncRunResult(
    skipped: leaseLost ? SyncSkip.busy : null,
    sent: sent,
    applied: applied,
    merged: merged,
    conflicts: conflicts,
    rejected: rejected,
    dropped: dropped,
    pulled: pulled,
    notModified: notModified,
    photosUploaded: photosUploaded,
    waitingForBackoff: waitingForBackoff,
    error: error,
  );
}
