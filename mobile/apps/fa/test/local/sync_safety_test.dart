// The engine's guards against losing or duplicating an FA's work: 400s that
// are not about a command, an edit landing mid run, the sync lease, edits of
// one entity racing on the server, merges and photo keys, photos the server
// never had, and wiping while a run is queued.

import 'dart:async';

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/fa_actions.dart';
import 'package:fa/src/local/local_store.dart';
import 'package:fa/src/local/network.dart';
import 'package:fa/src/local/outbox.dart';
import 'package:fa/src/local/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import 'support/fakes.dart';
import 'support/fixture.dart';
import 'support/race_store.dart';

const _bad400 = ApiError(
  code: ApiErrorCode.invalidRequest,
  message: 'bad request',
  status: 400,
);

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Harness h;

  Future<Harness> start(Harness harness) async {
    h = harness;
    await h.seed();
    return h;
  }

  tearDown(() => h.dispose());

  group('400 for a whole batch', () {
    test('a 400 that every request gets rejects nothing: back off', () async {
      await start(Harness());
      for (var i = 0; i < 4; i++) {
        await h.actions.planVisit(farmerId: ravi, plannedFor: today.addDays(i));
      }
      await h.actions.logVisit(
        const VisitLogInput(farmerId: ravi, visitId: raviPlannedVisit),
      );
      h.server.submitErrors.addAll(List.filled(50, _bad400));
      final result = await h.engine.syncNow();
      expect(result.rejected, 0);
      expect(result.error, _bad400);
      final rows = await h.outbox();
      expect(rows.every((e) => e.state == OutboxState.queued), isTrue);
      expect(rows.first.nextAttemptAt, isNotNull, reason: 'backs off');
      expect(
        (await h.territory()).visit(raviPlannedVisit)!.status,
        VisitStatus.done,
        reason: 'the FA\'s visit stays',
      );
    });

    test('a bad head is pinned by a probe: rejected, the rest goes', () async {
      await start(Harness());
      await h.actions.ackAlert(alertNote);
      await h.actions.planVisit(farmerId: padma, plannedFor: today);
      await h.actions.planVisit(farmerId: ravi, plannedFor: today);
      final rows = await h.outbox();
      h.server.badIds.add(rows.first.id);
      final result = await h.engine.syncNow();
      expect(result.rejected, 1);
      final left = await h.outbox();
      expect(left.single.id, rows.first.id);
      expect(left.single.rejection!.code, RejectionCode.clientInvalid);
      expect(h.server.dispatched.keys, {rows[1].id, rows[2].id});
    });

    test('a lone command with nothing to compare is rejected only after '
        '${const SyncLimits().lone400Limit} runs', () async {
      await start(Harness());
      await h.actions.ackAlert(alertNote);
      final id = (await h.outbox()).single.id;
      h.server.badIds.add(id);
      for (var run = 1; run < const SyncLimits().lone400Limit; run++) {
        final r = await h.engine.syncNow();
        expect(r.rejected, 0, reason: 'run $run');
        final e = (await h.outbox()).single;
        expect(e.state, OutboxState.queued);
        expect(e.meta[OutboxMeta.lone400], run);
      }
      final r = await h.engine.syncNow();
      expect(r.rejected, 1);
      expect(
        (await h.outbox()).single.rejection!.code,
        RejectionCode.clientInvalid,
      );
    });
  });

  test('an edit of a queued visit that lands while a run reads the queue is '
      'not overwritten: the edited log is what goes', () async {
    final store = RaceStore(InMemoryLocalStore());
    final server = FakeServer(fixtureSnapshot());
    final photos = FakeVisitPhotos(server: server);
    final net = MockConnectivityService();
    final clock = fixtureClock();
    final engine = SyncEngine(
      store: store,
      sync: server,
      visitPhotos: photos,
      uploader: FakeUploader(),
      connectivity: net,
      clock: clock,
      random: () => 0.5,
      owner: 'ui',
    );
    final actions = FaActions(store: store, clock: clock);
    h = Harness(); // for tearDown only
    await engine.writeSnapshot(server.served);
    await actions.logVisit(
      VisitLogInput(
        farmerId: ravi,
        visitId: raviPlannedVisit,
        notes: 'first',
        photos: [
          VisitPhotoInput(
            bytes: photoBytes(1),
            contentType: PhotoContentType.jpeg,
          ),
        ],
      ),
    );
    Future<LoggedVisit>? edit;
    store.queuedReads = 0;
    store.fireOn = 2; // the push read after the consent check
    store.onQueuedRead = () => edit = actions.editQueuedVisit(
      raviPlannedVisit,
      VisitLogInput(
        farmerId: ravi,
        visitId: raviPlannedVisit,
        notes: 'second',
        photos: [
          VisitPhotoInput(
            bytes: photoBytes(9),
            contentType: PhotoContentType.jpeg,
          ),
        ],
      ),
    );
    await engine.syncNow();
    final edited = await edit!;
    final sent = server.received.where((c) => c.type == 'LogVisit').toList();
    expect([for (final c in sent) c.payload['notes']], ['second']);
    expect([
      for (final p in sent.single.payload['photos']! as List<Object?>)
        (p! as Map<String, Object?>)['photo_id'],
    ], edited.photoIds);
    expect(photos.confirmed.keys, edited.photoIds, reason: 'the new photo');
    await engine.dispose();
    await net.dispose();
  });

  group('the sync lease', () {
    test(
      'a runner whose lease another took stops before the next batch',
      () async {
        await start(
          Harness(
            limits: const SyncLimits(nudgeDelay: Duration.zero, maxBatch: 1),
          ),
        );
        await h.actions.ackAlert(alertNote);
        await h.actions.ackAlert(alertCallback);
        final hold = Completer<void>();
        h.server.hold = hold;
        final first = h.engine.syncNow();
        await _settle();
        h.clock.advance(const Duration(minutes: 3)); // no heartbeat came
        expect(
          await h.store.acquireSyncLease(
            'background-worker',
            now: h.clock.now(),
            ttl: const Duration(minutes: 2),
          ),
          isTrue,
        );
        hold.complete();
        final a = await first;
        expect(a.skipped, SyncSkip.busy);
        expect(h.server.batches, hasLength(1), reason: 'no second batch');
        expect((await h.outbox()).last.state, OutboxState.queued);
      },
    );

    test('a second runner that took over: the first never writes a stale row '
        'back', () async {
      await start(Harness());
      await h.actions.ackAlert(alertNote);
      final other = SyncEngine(
        store: h.store,
        sync: h.server,
        visitPhotos: h.photos,
        uploader: h.uploader,
        connectivity: h.net,
        clock: h.clock,
        random: () => 0.5,
        owner: 'background-worker',
      );
      final hold = Completer<void>();
      h.server.hold = hold;
      final first = h.engine.syncNow();
      await _settle();
      h.clock.advance(const Duration(minutes: 3)); // no heartbeat came
      final b = await other.syncNow();
      expect(b.ok, isTrue);
      hold.complete();
      final a = await first;
      expect(a.error, isNull, reason: 'no StateError from a stale row');
      expect(await h.outbox(), isEmpty);
      expect(
        (await h.store.syncLog()).where((l) => l.kind == SyncLogKind.applied),
        hasLength(1),
        reason: 'counted once',
      );
      await other.dispose();
    });

    test('a long request keeps the lease: the heartbeat renews it', () async {
      await start(
        Harness(
          limits: const SyncLimits(
            nudgeDelay: Duration.zero,
            leaseRenewEvery: Duration(milliseconds: 5),
          ),
        ),
      );
      await h.actions.ackAlert(alertNote);
      final hold = Completer<void>();
      h.server.hold = hold;
      final first = h.engine.syncNow();
      await _settle();
      h.clock.advance(const Duration(minutes: 3));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final busy = await h.store.acquireSyncLease(
        'background-worker',
        now: h.clock.now(),
        ttl: const Duration(minutes: 2),
      );
      expect(busy, isFalse, reason: 'renewed at the advanced time');
      hold.complete();
      expect((await first).ok, isTrue);
    });
  });

  group('edits of one plot / farmer', () {
    test('HO edited once; the FA edited twice offline: the second edit does '
        'not overwrite HO unseen, it folds into the one conflict, and Keep '
        'mine sends the latest values at the server version', () async {
      await start(Harness());
      // HO: Plot 2 v3 -> v4 (2.0 ac).
      h.server.snapshot = fixtureSnapshot(
        territoryVersion: 11,
        padmaPlotVersion: 4,
      );
      h.server.territoryVersion = 11;
      Future<void> edit(String label, double acres) => h.actions.savePlot(
        farmerId: padma,
        plotId: padmaPlot2,
        label: label,
        pin: padmaPin,
        areaAcres: acres,
        areaSource: AreaSource.typed,
      );
      await edit('Plot 2', 1.75);
      // The first edit is on its way when the FA edits again.
      final first = (await h.rows(CommandType.savePlot)).single;
      await h.store.updateOutbox(
        first.copyWith(state: OutboxState.sending, attempts: 1),
      );
      await edit('Plot 2 (river)', 1.8);
      final second = (await h.rows(CommandType.savePlot)).last;
      expect(second.payload['expected_version'], 4, reason: 'assumes v3+1');
      expect(second.meta[OutboxMeta.versionParent], first.id);

      final result = await h.engine.syncNow();
      expect(result.conflicts, 1);
      expect(
        h.server.received.where((c) => c.id == second.id),
        isEmpty,
        reason: 'never sent: v4 is HO\'s, it would have applied over it',
      );
      expect(
        h.server.snapshot.plots.firstWhere((p) => p.id == padmaPlot2).areaAcres,
        2.0,
        reason: 'HO\'s value stands',
      );
      final rows = await h.rows(CommandType.savePlot);
      expect(rows, hasLength(1), reason: 'one card');
      expect(rows.single.state, OutboxState.conflict);
      expect(rows.single.payload['label'], 'Plot 2 (river)');
      expect(rows.single.meta[OutboxMeta.folded], [second.id]);

      await h.actions.keepMine(rows.single.id);
      final again = (await h.rows(CommandType.savePlot)).last;
      expect(again.payload['expected_version'], 4);
      expect(again.payload['area_acres'], 1.8);
      await h.engine.syncNow();
      final p = (await h.territory()).plot(padmaPlot2)!;
      expect(p.label, 'Plot 2 (river)');
      expect(p.areaAcres, 1.8);
      expect(p.version, 5);
    });

    test('an edit made while the earlier one is a conflict folds into it '
        '(Keep mine never lands after a later edit)', () async {
      await start(Harness());
      h.server.snapshot = fixtureSnapshot(
        territoryVersion: 11,
        padmaPlotVersion: 4,
      );
      h.server.territoryVersion = 11;
      await h.actions.savePlot(
        farmerId: padma,
        plotId: padmaPlot2,
        label: 'Plot 2',
        pin: padmaPin,
        areaAcres: 1.75,
        areaSource: AreaSource.typed,
      );
      await h.engine.syncNow();
      final conflict = (await h.outbox()).single;
      expect(conflict.state, OutboxState.conflict);
      await h.actions.savePlot(
        farmerId: padma,
        plotId: padmaPlot2,
        label: 'Plot 2 (canal)',
        pin: padmaPin,
        areaAcres: 1.9,
        areaSource: AreaSource.typed,
      );
      final rows = await h.outbox();
      expect(rows, hasLength(1));
      expect(rows.single.payload['label'], 'Plot 2 (canal)');
      await h.actions.keepMine(conflict.id);
      await h.engine.syncNow();
      expect((await h.territory()).plot(padmaPlot2)!.areaAcres, 1.9);
    });

    test(
      'an edit whose parent was rejected goes at the parent\'s version',
      () async {
        await start(Harness());
        await h.actions.updateFarmer(farmerId: padma, villageId: kondapur);
        final first = (await h.outbox()).single;
        h.server.decide = (c) => c.id == first.id
            ? CommandResult(
                id: c.id,
                status: CommandStatus.rejected,
                entityId: padma,
                error: 'village_id: not in your area',
              )
            : null;
        await h.store.updateOutbox(
          first.copyWith(state: OutboxState.sending, attempts: 1),
        );
        await h.actions.updateFarmer(farmerId: padma, name: 'Padma Sri');
        final child = (await h.outbox()).last;
        expect(child.payload['expected_version'], 6);
        await h.engine.syncNow();
        final sent = h.server.received.lastWhere((c) => c.id == child.id);
        expect(sent.payload['expected_version'], 5, reason: 'rebased');
        expect(h.server.stored[child.id]!.status, CommandStatus.applied);
        expect((await h.territory()).farmer(padma)!.name, 'Padma Sri');
      },
    );
  });

  test('after a merge, a queued photo UpdateFarmer keeps the minted ID and '
      'its photo key is accepted', () async {
    await start(
      Harness(limits: const SyncLimits(nudgeDelay: Duration.zero, maxBatch: 1)),
    );
    final f = await h.actions.enrolFarmer(
      phone: '9848012345',
      name: 'Suresh B',
      language: Language.te,
      villageId: kondapur,
    );
    await h.actions.updateFarmer(farmerId: f, photoKey: 'farmers/$f/p1.jpg');
    h.server.decide = (c) => c.type == 'EnrolFarmer'
        ? CommandResult(
            id: c.id,
            status: CommandStatus.merged,
            entityId: f,
            mergedInto: venkat,
          )
        : null;
    await h.engine.syncNow();
    final upd = h.server.received.firstWhere((c) => c.type == 'UpdateFarmer');
    expect(upd.payload['farmer_id'], f);
    final r = h.server.stored[upd.id]!;
    expect(r.status, isNot(CommandStatus.rejected), reason: '${r.error}');
    final t = await h.territory();
    expect(t.farmer(f)!.id, venkat);
    expect(t.farmers.where((x) => x.phone == '+919848012345'), isEmpty);
  });

  test('a photo the server never stored is dropped after a few tries, with a '
      'log line', () async {
    await start(Harness());
    // Applied without storing the photo (as a replayed log of a visit that
    // was already done would be).
    h.server.decide = (c) => c.type == 'LogVisit'
        ? CommandResult(
            id: c.id,
            status: CommandStatus.applied,
            entityId: FakeServer.entityIdOf(c),
          )
        : null;
    final logged = await h.actions.logVisit(
      VisitLogInput(
        farmerId: ravi,
        visitId: raviPlannedVisit,
        photos: [
          VisitPhotoInput(
            bytes: photoBytes(4),
            contentType: PhotoContentType.jpeg,
          ),
        ],
      ),
    );
    for (var i = 0; i < const SyncLimits().photoGiveUpAfter; i++) {
      await h.engine.syncNow();
      final p = (await h.store.photos()).single;
      final last = i == const SyncLimits().photoGiveUpAfter - 1;
      expect(
        p.state,
        last ? PhotoUploadState.dropped : PhotoUploadState.ready,
        reason: 'try ${i + 1}',
      );
    }
    final p = (await h.store.photos()).single;
    expect(p.photoId, logged.photoIds.single);
    expect(p.state, PhotoUploadState.dropped);
    final line = (await h.store.syncLog()).lastWhere(
      (l) => l.kind == SyncLogKind.photoDropped,
    );
    expect(line.message, LocalReason.photoNotOnServer);
    expect(await h.engine.pendingCount(), 0);
  });

  test('a refused PlanVisit does not drop the visit log behind it', () async {
    await start(Harness());
    h.server.decide = (c) => c.type == 'PlanVisit'
        ? CommandResult(
            id: c.id,
            status: CommandStatus.rejected,
            entityId: FakeServer.entityIdOf(c),
            error: 'visit was cancelled; plan a new one',
          )
        : null;
    final visit = await h.actions.planVisit(farmerId: ravi, plannedFor: today);
    await h.actions.logVisit(VisitLogInput(farmerId: ravi, visitId: visit));
    final result = await h.engine.syncNow();
    expect(result.dropped, 0);
    final log = h.server.received.singleWhere((c) => c.type == 'LogVisit');
    expect(h.server.stored[log.id]!.status, CommandStatus.applied);
    expect((await h.territory()).visit(visit)!.status, VisitStatus.done);
  });

  test(
    'wipe: a queued follow-up run never starts on the wiped store',
    () async {
      await start(Harness());
      await h.actions.ackAlert(alertNote);
      final hold = Completer<void>();
      h.server.hold = hold;
      final first = h.engine.syncNow();
      await _settle();
      await h.actions.ackAlert(alertCallback);
      final queued = h.engine.syncNow();
      final wipe = h.engine.wipe();
      expect(
        (await h.engine.run(SyncTrigger.manual)).skipped,
        SyncSkip.busy,
        reason: 'no run while wiping',
      );
      hold.complete();
      final ran = await first;
      expect((await queued).skipped, SyncSkip.busy);
      await wipe;
      expect(await h.store.baseSnapshot(), isNull);
      expect(await h.outbox(), isEmpty);
      expect(ran.sent, 2, reason: 'the running run took the new one');
      expect(h.server.batches, hasLength(2), reason: 'all from that run');
    },
  );
}
