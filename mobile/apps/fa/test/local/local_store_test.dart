import 'dart:async';

import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/local_store.dart';
import 'package:fa/src/local/outbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixture.dart';

OutboxEntry _ack(String id) => OutboxEntry.create(
  id: id,
  command: AckAlertPayload(alertId: 'alert-$id'),
  now: fixtureNow,
);

void main() {
  late InMemoryLocalStore store;

  setUp(() => store = InMemoryLocalStore());

  test('insert assigns seq in order; rows come back in seq order', () async {
    final a = await store.insertOutbox(_ack('a'));
    final b = await store.insertOutbox(_ack('b'));
    expect(a.seq, 1);
    expect(b.seq, 2);
    await store.updateOutbox(b.copyWith(seq: 99, state: OutboxState.sending));
    final rows = await store.outbox();
    expect([for (final r in rows) r.id], ['a', 'b']);
    expect(rows[1].seq, 2, reason: 'update keeps the seq');
    expect(await store.outbox(states: {OutboxState.sending}), [rows[1]]);
  });

  test('a command ID cannot be inserted twice', () async {
    await store.insertOutbox(_ack('a'));
    await expectLater(store.insertOutbox(_ack('a')), throwsStateError);
    expect(await store.outbox(), hasLength(1));
  });

  test('a failed transaction leaves nothing behind', () async {
    await store.insertOutbox(_ack('a'));
    await expectLater(
      store.transaction((tx) async {
        await tx.insertOutbox(_ack('b'));
        await tx.putBaseSnapshot(fixtureSnapshot());
        await tx.putSyncMeta(const SyncMeta(etag: '"t1-m1"'));
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect([for (final r in await store.outbox()) r.id], ['a']);
    expect(await store.baseSnapshot(), isNull);
    expect((await store.syncMeta()).etag, isNull);
  });

  test('a transaction commits all its writes and fires one change', () async {
    var changes = 0;
    final sub = store.changes.listen((_) => changes++);
    await store.transaction((tx) async {
      await tx.insertOutbox(_ack('a'));
      await tx.insertOutbox(_ack('b'));
      await tx.putSyncMeta(const SyncMeta(etag: '"t1-m1"'));
    });
    await sub.cancel();
    expect(await store.outbox(), hasLength(2));
    expect((await store.syncMeta()).etag, '"t1-m1"');
    expect(changes, 1);
  });

  test('store calls inside a transaction join it (no deadlock)', () async {
    await store.transaction((tx) async {
      await store.insertOutbox(_ack('a'));
      expect(await store.outbox(), hasLength(1), reason: 'sees its own write');
      await store.transaction((inner) => inner.insertOutbox(_ack('b')));
    });
    expect(await store.outbox(), hasLength(2));
  });

  test('transactions run one at a time; reads see committed data', () async {
    final gate = Completer<void>();
    final first = store.transaction((tx) async {
      await tx.insertOutbox(_ack('a'));
      await gate.future;
      await tx.insertOutbox(_ack('b'));
    });
    final second = store.transaction((tx) async {
      final rows = await tx.outbox();
      expect(rows, hasLength(2), reason: 'waits for the first to commit');
      await tx.insertOutbox(_ack('c'));
    });
    final read = store.outbox();
    gate.complete();
    await Future.wait([first, second]);
    expect(await read, hasLength(3), reason: 'a read waits for queued writes');
    expect([for (final r in await store.outbox()) r.seq], [1, 2, 3]);
  });

  test('photo queue and sync log', () async {
    await store.addSyncLog(
      SyncLogEntry(
        id: 0,
        at: fixtureNow.subtract(const Duration(days: 40)),
        kind: SyncLogKind.applied,
      ),
    );
    final kept = await store.addSyncLog(
      SyncLogEntry(id: 0, at: fixtureNow, kind: SyncLogKind.applied),
    );
    expect(kept.id, 2);
    expect(
      await store.pruneSyncLog(fixtureNow.subtract(const Duration(days: 30))),
      1,
    );
    expect(await store.syncLog(), [kept]);
    expect(
      await store.syncLog(since: fixtureNow.add(const Duration(seconds: 1))),
      isEmpty,
    );
  });

  test('the sync lease keeps a second runner out until it expires', () async {
    expect(
      await store.acquireSyncLease(
        'ui',
        now: fixtureNow,
        ttl: const Duration(minutes: 2),
      ),
      isTrue,
    );
    expect(
      await store.acquireSyncLease(
        'worker',
        now: fixtureNow,
        ttl: const Duration(minutes: 2),
      ),
      isFalse,
    );
    expect(
      await store.acquireSyncLease(
        'ui',
        now: fixtureNow,
        ttl: const Duration(minutes: 2),
      ),
      isTrue,
      reason: 'the holder renews',
    );
    expect(
      await store.acquireSyncLease(
        'worker',
        now: fixtureNow.add(const Duration(minutes: 3)),
        ttl: const Duration(minutes: 2),
      ),
      isTrue,
      reason: 'an expired lease is free',
    );
    await store.releaseSyncLease('ui');
    expect(
      await store.acquireSyncLease(
        'ui',
        now: fixtureNow,
        ttl: const Duration(minutes: 2),
      ),
      isFalse,
      reason: 'releasing someone else\'s lease does nothing',
    );
  });

  test('wipe deletes everything', () async {
    await store.putBaseSnapshot(fixtureSnapshot());
    await store.putTerritoryTables(fixtureSnapshot());
    await store.insertOutbox(_ack('a'));
    await store.putSettings(const LocalSettings(photosOnWifiOnly: false));
    await store.putSyncMeta(const SyncMeta(etag: '"t1-m1"'));
    await store.wipe();
    expect(await store.baseSnapshot(), isNull);
    expect(await store.territoryTables(), isNull);
    expect(await store.outbox(), isEmpty);
    expect(await store.settings(), const LocalSettings());
    expect(await store.syncMeta(), const SyncMeta());
  });
}
