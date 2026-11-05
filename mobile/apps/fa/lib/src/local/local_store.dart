// Storage of the FA offline engine, behind an interface so the Drift
// (SQLCipher) implementation replaces InMemoryLocalStore 1:1 later.
// Pure Dart, no Flutter import.
//
// Shape rules that keep the swap 1:1:
// * Every method is async and every row is an immutable value (see
//   outbox.dart); nothing relies on getting the same Dart object back.
// * Rows are found by key (outbox `id`, photo `photo_id`); `seq` and log `id`
//   are assigned by the store, like an autoincrement column.
// * Several writes that belong together go through [LocalStore.transaction]:
//   all or nothing, one at a time (Drift serialises write transactions too).

import 'dart:async';

import '../data/models/models.dart';
import 'outbox.dart';

/// The tables, as seen inside or outside a transaction.
///
/// Two copies of the territory are kept:
/// * the **base snapshot**, exactly as the server sent it (replaced wholesale
///   on every 200). Drift keeps it as one compressed JSON row.
/// * the **territory tables**: the base snapshot with the local effect of the
///   outbox applied (projection). Screens read these. Drift keeps them as the
///   queryable `farmers`, `plots`, ... tables of the plan.
///
/// Rebuilding the territory tables is always possible from the base plus the
/// outbox, which is how a projection is taken back (rejected, Keep HO's).
abstract interface class LocalTables {
  /// The last snapshot from the server, or null before the first pull.
  Future<Snapshot?> baseSnapshot();

  /// Replaces the base snapshot wholesale.
  Future<void> putBaseSnapshot(Snapshot snapshot);

  /// The projected territory (base + outbox effects), or null before the
  /// first pull.
  Future<Snapshot?> territoryTables();

  /// Replaces the projected territory wholesale.
  Future<void> putTerritoryTables(Snapshot tables);

  /// The `sync_meta` row (all nulls before the first sync).
  Future<SyncMeta> syncMeta();

  /// Writes the `sync_meta` row.
  Future<void> putSyncMeta(SyncMeta meta);

  /// The FA's local settings.
  Future<LocalSettings> settings();

  /// Writes the settings.
  Future<void> putSettings(LocalSettings settings);

  /// Outbox rows in `seq` order, optionally only those in [states].
  Future<List<OutboxEntry>> outbox({Set<OutboxState>? states});

  /// One outbox row by command ID, or null.
  Future<OutboxEntry?> outboxEntry(String id);

  /// Inserts [entry] (its `seq` is ignored) and returns it with the assigned
  /// `seq`. Throws [StateError] when the command ID is already there.
  Future<OutboxEntry> insertOutbox(OutboxEntry entry);

  /// Replaces the row with [entry]'s ID (its `seq` is kept). Throws
  /// [StateError] when there is no such row.
  Future<void> updateOutbox(OutboxEntry entry);

  /// Deletes the row with command ID [id] (no-op when missing).
  Future<void> deleteOutbox(String id);

  /// Photo queue rows in insertion order, optionally filtered.
  Future<List<PhotoQueueEntry>> photos({
    Set<PhotoUploadState>? states,
    String? visitId,
    String? commandId,
  });

  /// Inserts or replaces the row with [photo]'s ID.
  Future<void> putPhoto(PhotoQueueEntry photo);

  /// Deletes a photo row (no-op when missing).
  Future<void> deletePhoto(String photoId);

  /// Sync log lines in order, optionally only those at or after [since].
  Future<List<SyncLogEntry>> syncLog({DateTime? since});

  /// Appends a line (its `id` is ignored) and returns it with its ID.
  Future<SyncLogEntry> addSyncLog(SyncLogEntry entry);

  /// Deletes lines older than [before]; returns how many.
  Future<int> pruneSyncLog(DateTime before);
}

/// The FA app's local database.
abstract interface class LocalStore implements LocalTables {
  /// Runs [action] as one transaction: every write in it lands, or none does
  /// (an exception rolls back and is rethrown). Transactions run one at a
  /// time. Calling [transaction] again from inside [action] joins the outer
  /// one.
  Future<T> transaction<T>(Future<T> Function(LocalTables tx) action);

  /// Fires after each committed write (and after [wipe]).
  Stream<void> get changes;

  /// Takes the sync lease (`sync_lock` row) for [owner] until `now + ttl`.
  ///
  /// True when it was free, expired, or already [owner]'s. Keeps the UI and a
  /// background worker from pushing at the same time.
  Future<bool> acquireSyncLease(
    String owner, {
    required DateTime now,
    required Duration ttl,
  });

  /// Gives the lease back (no-op when [owner] does not hold it).
  Future<void> releaseSyncLease(String owner);

  /// Deletes everything (device revoked, sign-out with wipe).
  Future<void> wipe();
}

/// [LocalStore] in memory: the store until Drift lands, and in tests.
///
/// A transaction works on a copy of the tables and swaps it in on success,
/// so a failure half way leaves nothing behind.
final class InMemoryLocalStore implements LocalStore {
  /// Creates an empty store.
  InMemoryLocalStore();

  _Tables _tables = _Tables();
  final _changes = StreamController<void>.broadcast(sync: true);
  Future<void> _tail = Future.value();
  final Object _zoneKey = Object();
  ({String owner, DateTime until})? _lease;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<T> transaction<T>(Future<T> Function(LocalTables tx) action) {
    final current = Zone.current[_zoneKey];
    if (current is _Tables) return action(current);
    final done = Completer<T>();
    final previous = _tail;
    _tail = done.future.then<void>((_) {}, onError: (Object _) {});
    unawaited(
      previous.then((_) async {
        final work = _tables.copy();
        try {
          final result = await runZoned(
            () => action(work),
            zoneValues: {_zoneKey: work},
          );
          _tables = work;
          _changes.add(null);
          done.complete(result);
        } on Object catch (e, s) {
          done.completeError(e, s);
        }
      }),
    );
    return done.future;
  }

  Future<T> _run<T>(Future<T> Function(_Tables t) action) =>
      transaction((tx) => action(tx as _Tables));

  Future<T> _read<T>(T Function(_Tables t) read) {
    final current = Zone.current[_zoneKey];
    if (current is _Tables) return Future.value(read(current));
    // Reads wait for running writes, like a database would show only
    // committed data.
    return _tail.then((_) => read(_tables));
  }

  @override
  Future<Snapshot?> baseSnapshot() => _read((t) => t.base);

  @override
  Future<void> putBaseSnapshot(Snapshot snapshot) =>
      _run((t) => t.putBaseSnapshot(snapshot));

  @override
  Future<Snapshot?> territoryTables() => _read((t) => t.territory);

  @override
  Future<void> putTerritoryTables(Snapshot tables) =>
      _run((t) => t.putTerritoryTables(tables));

  @override
  Future<SyncMeta> syncMeta() => _read((t) => t.meta);

  @override
  Future<void> putSyncMeta(SyncMeta meta) => _run((t) => t.putSyncMeta(meta));

  @override
  Future<LocalSettings> settings() => _read((t) => t.localSettings);

  @override
  Future<void> putSettings(LocalSettings settings) =>
      _run((t) => t.putSettings(settings));

  @override
  Future<List<OutboxEntry>> outbox({Set<OutboxState>? states}) =>
      _read((t) => t.outboxRows(states));

  @override
  Future<OutboxEntry?> outboxEntry(String id) => _read((t) => t.outboxById[id]);

  @override
  Future<OutboxEntry> insertOutbox(OutboxEntry entry) =>
      _run((t) => t.insertOutbox(entry));

  @override
  Future<void> updateOutbox(OutboxEntry entry) =>
      _run((t) => t.updateOutbox(entry));

  @override
  Future<void> deleteOutbox(String id) => _run((t) => t.deleteOutbox(id));

  @override
  Future<List<PhotoQueueEntry>> photos({
    Set<PhotoUploadState>? states,
    String? visitId,
    String? commandId,
  }) => _read(
    (t) => t.photoRows(states: states, visitId: visitId, commandId: commandId),
  );

  @override
  Future<void> putPhoto(PhotoQueueEntry photo) =>
      _run((t) => t.putPhoto(photo));

  @override
  Future<void> deletePhoto(String photoId) =>
      _run((t) => t.deletePhoto(photoId));

  @override
  Future<List<SyncLogEntry>> syncLog({DateTime? since}) =>
      _read((t) => t.logRows(since));

  @override
  Future<SyncLogEntry> addSyncLog(SyncLogEntry entry) =>
      _run((t) => t.addSyncLog(entry));

  @override
  Future<int> pruneSyncLog(DateTime before) =>
      _run((t) => t.pruneSyncLog(before));

  @override
  Future<bool> acquireSyncLease(
    String owner, {
    required DateTime now,
    required Duration ttl,
  }) async {
    await _tail;
    final lease = _lease;
    if (lease != null && lease.owner != owner && lease.until.isAfter(now)) {
      return false;
    }
    _lease = (owner: owner, until: now.add(ttl));
    return true;
  }

  @override
  Future<void> releaseSyncLease(String owner) async {
    if (_lease?.owner == owner) _lease = null;
  }

  @override
  Future<void> wipe() => _run((t) async => t.clear());
}

/// The in-memory tables. Rows are immutable, so [copy] only copies the
/// collections.
final class _Tables implements LocalTables {
  _Tables();

  Snapshot? base;
  Snapshot? territory;
  SyncMeta meta = const SyncMeta();
  LocalSettings localSettings = const LocalSettings();
  Map<String, OutboxEntry> outboxById = {};
  Map<String, PhotoQueueEntry> photoById = {};
  List<SyncLogEntry> log = [];
  int nextSeq = 1;
  int nextLogId = 1;

  _Tables copy() => _Tables()
    ..base = base
    ..territory = territory
    ..meta = meta
    ..localSettings = localSettings
    ..outboxById = {...outboxById}
    ..photoById = {...photoById}
    ..log = [...log]
    ..nextSeq = nextSeq
    ..nextLogId = nextLogId;

  void clear() {
    base = null;
    territory = null;
    meta = const SyncMeta();
    localSettings = const LocalSettings();
    outboxById = {};
    photoById = {};
    log = [];
    // seq keeps counting, as an autoincrement column would after DELETE.
  }

  List<OutboxEntry> outboxRows(Set<OutboxState>? states) {
    final rows = [
      for (final e in outboxById.values)
        if (states == null || states.contains(e.state)) e,
    ]..sort((a, b) => a.seq.compareTo(b.seq));
    return rows;
  }

  List<PhotoQueueEntry> photoRows({
    Set<PhotoUploadState>? states,
    String? visitId,
    String? commandId,
  }) => [
    for (final p in photoById.values)
      if ((states == null || states.contains(p.state)) &&
          (visitId == null || p.visitId == visitId) &&
          (commandId == null || p.commandId == commandId))
        p,
  ];

  List<SyncLogEntry> logRows(DateTime? since) => [
    for (final l in log)
      if (since == null || !l.at.isBefore(since)) l,
  ];

  @override
  Future<Snapshot?> baseSnapshot() async => base;

  @override
  Future<void> putBaseSnapshot(Snapshot snapshot) async => base = snapshot;

  @override
  Future<Snapshot?> territoryTables() async => territory;

  @override
  Future<void> putTerritoryTables(Snapshot tables) async => territory = tables;

  @override
  Future<SyncMeta> syncMeta() async => meta;

  @override
  Future<void> putSyncMeta(SyncMeta meta) async => this.meta = meta;

  @override
  Future<LocalSettings> settings() async => localSettings;

  @override
  Future<void> putSettings(LocalSettings settings) async =>
      localSettings = settings;

  @override
  Future<List<OutboxEntry>> outbox({Set<OutboxState>? states}) async =>
      outboxRows(states);

  @override
  Future<OutboxEntry?> outboxEntry(String id) async => outboxById[id];

  @override
  Future<OutboxEntry> insertOutbox(OutboxEntry entry) async {
    if (outboxById.containsKey(entry.id)) {
      throw StateError('outbox: command ${entry.id} is already there');
    }
    final row = entry.copyWith(seq: nextSeq++);
    outboxById[row.id] = row;
    return row;
  }

  @override
  Future<void> updateOutbox(OutboxEntry entry) async {
    final old = outboxById[entry.id];
    if (old == null) throw StateError('outbox: no command ${entry.id}');
    outboxById[entry.id] = entry.copyWith(seq: old.seq);
  }

  @override
  Future<void> deleteOutbox(String id) async => outboxById.remove(id);

  @override
  Future<List<PhotoQueueEntry>> photos({
    Set<PhotoUploadState>? states,
    String? visitId,
    String? commandId,
  }) async => photoRows(states: states, visitId: visitId, commandId: commandId);

  @override
  Future<void> putPhoto(PhotoQueueEntry photo) async =>
      photoById[photo.photoId] = photo;

  @override
  Future<void> deletePhoto(String photoId) async => photoById.remove(photoId);

  @override
  Future<List<SyncLogEntry>> syncLog({DateTime? since}) async => logRows(since);

  @override
  Future<SyncLogEntry> addSyncLog(SyncLogEntry entry) async {
    final row = entry.withId(nextLogId++);
    log.add(row);
    return row;
  }

  @override
  Future<int> pruneSyncLog(DateTime before) async {
    final n = log.length;
    log.removeWhere((l) => l.at.isBefore(before));
    return n - log.length;
  }
}
