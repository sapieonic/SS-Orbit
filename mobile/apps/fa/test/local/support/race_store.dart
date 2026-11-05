// A LocalStore that delegates to an InMemoryLocalStore and can run code right
// after a given read of the queued rows (not a test file): it lets a test
// land an FA action between the engine's read and its next transaction.

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/local/local_store.dart';
import 'package:fa/src/local/outbox.dart';

/// See the file comment.
final class RaceStore implements LocalStore {
  /// Wraps [inner].
  RaceStore(this.inner);

  /// The real store.
  final InMemoryLocalStore inner;

  /// Reads of queued rows outside a transaction so far.
  int queuedReads = 0;

  /// Runs [onQueuedRead] right after this read (1-based) was registered.
  int? fireOn;

  /// What to run.
  void Function()? onQueuedRead;

  @override
  Future<List<OutboxEntry>> outbox({Set<OutboxState>? states}) {
    final f = inner.outbox(states: states);
    if (states != null &&
        states.length == 1 &&
        states.contains(OutboxState.queued)) {
      queuedReads++;
      if (queuedReads == fireOn) onQueuedRead?.call();
    }
    return f;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(LocalTables tx) action) =>
      inner.transaction(action);

  @override
  Stream<void> get changes => inner.changes;

  @override
  Future<bool> acquireSyncLease(
    String owner, {
    required DateTime now,
    required Duration ttl,
  }) => inner.acquireSyncLease(owner, now: now, ttl: ttl);

  @override
  Future<void> releaseSyncLease(String owner) => inner.releaseSyncLease(owner);

  @override
  Future<void> wipe() => inner.wipe();

  @override
  Future<Snapshot?> baseSnapshot() => inner.baseSnapshot();

  @override
  Future<void> putBaseSnapshot(Snapshot snapshot) =>
      inner.putBaseSnapshot(snapshot);

  @override
  Future<Snapshot?> territoryTables() => inner.territoryTables();

  @override
  Future<void> putTerritoryTables(Snapshot tables) =>
      inner.putTerritoryTables(tables);

  @override
  Future<SyncMeta> syncMeta() => inner.syncMeta();

  @override
  Future<void> putSyncMeta(SyncMeta meta) => inner.putSyncMeta(meta);

  @override
  Future<LocalSettings> settings() => inner.settings();

  @override
  Future<void> putSettings(LocalSettings settings) =>
      inner.putSettings(settings);

  @override
  Future<OutboxEntry?> outboxEntry(String id) => inner.outboxEntry(id);

  @override
  Future<OutboxEntry> insertOutbox(OutboxEntry entry) =>
      inner.insertOutbox(entry);

  @override
  Future<void> updateOutbox(OutboxEntry entry) => inner.updateOutbox(entry);

  @override
  Future<void> deleteOutbox(String id) => inner.deleteOutbox(id);

  @override
  Future<List<PhotoQueueEntry>> photos({
    Set<PhotoUploadState>? states,
    String? visitId,
    String? commandId,
  }) => inner.photos(states: states, visitId: visitId, commandId: commandId);

  @override
  Future<void> putPhoto(PhotoQueueEntry photo) => inner.putPhoto(photo);

  @override
  Future<void> deletePhoto(String photoId) => inner.deletePhoto(photoId);

  @override
  Future<List<SyncLogEntry>> syncLog({DateTime? since}) =>
      inner.syncLog(since: since);

  @override
  Future<SyncLogEntry> addSyncLog(SyncLogEntry entry) =>
      inner.addSyncLog(entry);

  @override
  Future<int> pruneSyncLog(DateTime before) => inner.pruneSyncLog(before);
}
