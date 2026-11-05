import 'dart:async';
import 'dart:convert';

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/fa_actions.dart';
import 'package:fa/src/local/outbox.dart';
import 'package:fa/src/local/projector.dart';
import 'package:fa/src/local/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import 'support/fakes.dart';
import 'support/fixture.dart';

const _network = ApiError.network();

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Enrol -> plot -> season -> planned visit for a new farmer.
Future<({String farmer, String plot, String season, String visit})> _enrolChain(
  Harness h, {
  String phone = '9848012345',
}) async {
  final farmer = await h.actions.enrolFarmer(
    phone: phone,
    name: 'Suresh B',
    language: Language.te,
    villageId: kondapur,
  );
  final plot = await h.actions.savePlot(
    farmerId: farmer,
    label: 'Plot 1',
    pin: const LatLng(17.47, 78.37),
    areaAcres: 1.5,
    areaSource: AreaSource.typed,
  );
  final season = await h.actions.startSeason(
    farmerId: farmer,
    plotId: plot,
    cropId: cotton,
    sowingDate: today.addDays(-3),
  );
  final visit = await h.actions.planVisit(
    farmerId: farmer,
    plannedFor: today.addDays(1),
    slot: VisitSlot.morning,
  );
  return (farmer: farmer, plot: plot, season: season, visit: visit);
}

/// [n] planned visits for Ravi (small, independent commands).
Future<List<String>> _plans(Harness h, int n) async => [
  for (var i = 0; i < n; i++)
    await h.actions.planVisit(farmerId: ravi, plannedFor: today.addDays(i)),
];

List<String> _ids(List<OutboxEntry> rows) => [for (final r in rows) r.id];

void main() {
  late Harness h;

  Future<Harness> start(Harness harness) async {
    h = harness;
    await h.seed();
    return h;
  }

  tearDown(() => h.dispose());

  group('push order and batching', () {
    test('sends in seq order, then pulls; applied rows go once the snapshot '
        'carries them', () async {
      await start(Harness());
      final chain = await _enrolChain(h);
      await h.actions.logVisit(
        VisitLogInput(farmerId: chain.farmer, visitId: chain.visit),
      );
      final queued = await h.outbox();

      final result = await h.engine.syncNow();

      expect(result.ok, isTrue, reason: '$result');
      expect(
        [
          for (final b in h.server.batches) [for (final c in b) c.type],
        ],
        [
          ['EnrolFarmer', 'SavePlot', 'StartSeason'],
          ['PlanVisit', 'LogVisit'],
        ],
        reason: 'a batch ends after a StartSeason that later commands use',
      );
      expect([for (final c in h.server.received) c.id], _ids(queued));
      expect(result.applied, 5);
      expect(result.pulled, isTrue);
      expect(await h.outbox(), isEmpty, reason: 'snapshot t15 carries t15');

      final t = await h.territory();
      expect(t.meta.territoryVersion, 15);
      expect(t.farmer(chain.farmer)!.name, 'Suresh B');
      expect(t.visit(chain.visit)!.status, VisitStatus.done);
      expect(t.pendingEntityIds, isEmpty);

      final log = await h.store.syncLog();
      expect(log.where((l) => l.kind == SyncLogKind.applied), hasLength(5));
      await _settle();
      expect(h.engine.state.syncedToday, 5);
      expect(h.engine.state.queuedCount, 0);
      expect(h.engine.state.lastPushAt, fixtureNow);
      expect(h.engine.state.lastPullAt, fixtureNow);
    });

    test('batches hold at most maxBatch commands, in order', () async {
      await start(Harness(limits: const SyncLimits(maxBatch: 3)));
      await _plans(h, 7);
      final queued = await h.outbox();
      await h.engine.syncNow();
      expect([for (final b in h.server.batches) b.length], [3, 3, 1]);
      expect([for (final c in h.server.received) c.id], _ids(queued));
    });

    test('batches stay under the byte limit', () async {
      await start(Harness(limits: const SyncLimits(maxBatchBytes: 1000)));
      await _plans(h, 7);
      await h.engine.syncNow();
      expect(h.server.batches.length, greaterThan(1));
      expect(h.server.received, hasLength(7));
      for (final b in h.server.batches) {
        final body = jsonEncode({
          'commands': [for (final c in b) c.toJson()],
        });
        expect(utf8.encode(body).length, lessThanOrEqualTo(1000));
      }
    });

    test('retry_from: the first part is applied, the rest is resent from that '
        'index after backoff', () async {
      await start(Harness());
      await _plans(h, 4);
      final queued = await h.outbox();
      h.server.stopAt = 2;

      await h.engine.syncNow();
      var rows = await h.outbox();
      expect(
        h.server.stored.keys,
        _ids(queued).sublist(0, 2),
        reason: 'the first two were processed',
      );
      expect(
        _ids(rows),
        _ids(queued).sublist(2),
        reason: 'applied ones covered',
      );
      expect(rows.every((r) => r.state == OutboxState.queued), isTrue);
      expect(
        rows[0].nextAttemptAt,
        fixtureNow.add(const Duration(seconds: 15)),
      );

      final early = await h.engine.run(SyncTrigger.retry);
      expect(early.waitingForBackoff, isTrue);
      expect(h.server.batches, hasLength(1));

      h.clock.advance(const Duration(seconds: 15));
      await h.engine.run(SyncTrigger.retry);
      expect(h.server.batches, hasLength(2));
      expect([
        for (final c in h.server.batches[1]) c.id,
      ], _ids(queued).sublist(2));
      rows = await h.outbox();
      expect(rows.every((r) => r.state != OutboxState.queued), isTrue);
    });
  });

  group('backoff', () {
    test(
      'network errors back off 15 s, 1 min, 5 min, 15 min, 30 min, capped',
      () async {
        await start(Harness());
        await h.actions.ackAlert(alertNote);
        h.server.submitErrors.addAll(List.filled(6, _network));
        final delays = <Duration>[];
        var result = await h.engine.run(SyncTrigger.action);
        expect(result.error, _network);
        for (var i = 0; i < 6; i++) {
          final e = (await h.outbox()).single;
          expect(e.state, OutboxState.queued);
          delays.add(e.nextAttemptAt!.difference(h.clock.now()));
          h.clock.set(e.nextAttemptAt!);
          if (i < 5) result = await h.engine.run(SyncTrigger.retry);
        }
        expect(delays, const [
          Duration(seconds: 15),
          Duration(minutes: 1),
          Duration(minutes: 5),
          Duration(minutes: 15),
          Duration(minutes: 30),
          Duration(minutes: 30),
        ]);
        expect((await h.outbox()).single.attempts, 6);
        await _settle();
        expect(h.engine.state.lastError, _network);
        expect(h.engine.state.nextRetryAt, isNotNull);

        await h.engine.run(SyncTrigger.retry);
        expect(await h.outbox(), isEmpty, reason: 'applied and covered');
        await _settle();
        expect(h.engine.state.lastError, isNull);
      },
    );

    test('jitter stays within +-20 %', () async {
      await start(Harness(random: () => 0));
      expect(h.engine.backoffFor(1), const Duration(seconds: 12));
      expect(h.engine.backoffFor(9), const Duration(minutes: 24));
      final high = Harness(random: () => 1);
      expect(high.engine.backoffFor(1), const Duration(seconds: 18));
      expect(high.engine.backoffFor(5), const Duration(minutes: 36));
      await high.dispose();
    });

    test(
      'Sync now and a connectivity change start the schedule again',
      () async {
        await start(Harness());
        await h.actions.ackAlert(alertNote);
        h.server.submitErrors.addAll(List.filled(5, _network));
        Future<Duration> delay() async =>
            (await h.outbox()).single.nextAttemptAt!.difference(h.clock.now());

        await h.engine.run(SyncTrigger.action);
        h.clock.advance(await delay());
        await h.engine.run(SyncTrigger.retry);
        h.clock.advance(await delay());
        await h.engine.run(SyncTrigger.retry);
        expect(await delay(), const Duration(minutes: 5));

        await h.engine.syncNow(); // ignores the wait, resets the count
        expect(h.server.batches, hasLength(4));
        expect(await delay(), const Duration(seconds: 15));

        h.clock.advance(await delay());
        await h.engine.run(SyncTrigger.retry);
        expect(await delay(), const Duration(minutes: 1));
        await h.engine.run(SyncTrigger.connectivity);
        expect(h.server.batches, hasLength(6), reason: 'the wait is cleared');
        expect(await h.outbox(), isEmpty, reason: 'applied and covered');
      },
    );

    test('coming online runs the engine (when started)', () async {
      await start(Harness(online: false));
      await h.actions.ackAlert(alertNote);
      h.engine.start();
      await _settle();
      expect(h.server.batches, isEmpty);
      h.net.setOnline(true);
      await _settle();
      expect(h.server.batches, hasLength(1));
      h.engine.stop();
    });

    test('5xx backs off; 401 stops the run without backoff', () async {
      await start(Harness());
      await h.actions.ackAlert(alertNote);
      h.server.submitErrors.add(
        const ApiError(
          code: ApiErrorCode.unavailable,
          message: '503',
          status: 503,
        ),
      );
      await h.engine.run(SyncTrigger.action);
      expect((await h.outbox()).single.nextAttemptAt, isNotNull);

      await h.engine.syncNow();
      expect(await h.outbox(), isEmpty, reason: 'applied and covered');

      await h.actions.ackAlert(alertCallback);
      final calls = h.server.snapshotCalls.length;
      h.server.submitErrors.add(
        const ApiError(
          code: ApiErrorCode.unauthorized,
          message: '401',
          status: 401,
        ),
      );
      final result = await h.engine.syncNow();
      expect((result.error! as ApiError).code, ApiErrorCode.unauthorized);
      final row = (await h.rows(CommandType.ackAlert)).last;
      expect(row.state, OutboxState.queued);
      expect(row.nextAttemptAt, isNull);
      expect(h.server.snapshotCalls, hasLength(calls), reason: 'no pull');
    });
  });

  group('results', () {
    test('applied: replayed until a snapshot carries it', () async {
      await start(Harness());
      h.server.applyToSnapshot = false;
      h.server.servedVersion = 10; // a stale cached snapshot
      await h.actions.logVisit(
        const VisitLogInput(farmerId: ravi, visitId: raviPlannedVisit),
      );
      final result = await h.engine.syncNow();
      expect(result.notModified, isTrue);
      final e = (await h.outbox()).single;
      expect(e.state, OutboxState.applied);
      expect(e.batchTerritoryVersion, 11);
      var t = await h.territory();
      expect(t.visit(raviPlannedVisit)!.status, VisitStatus.done);
      expect(t.isPending(raviPlannedVisit), isFalse, reason: 'synced');

      // Now the server's snapshot has it.
      h.server.snapshot = const Projector().apply(h.server.snapshot, e);
      h.server.servedVersion = null;
      await h.engine.syncNow();
      expect(await h.outbox(), isEmpty);
      t = await h.territory();
      expect(t.visit(raviPlannedVisit)!.status, VisitStatus.done);
    });

    test('merged: the screens show the existing farmer; queued commands keep '
        'the minted ID (the server follows the alias)', () async {
      await start(Harness());
      h.server.decide = (c) => c.type == 'EnrolFarmer'
          ? CommandResult(
              id: c.id,
              status: CommandStatus.merged,
              entityId: FakeServer.entityIdOf(c),
              mergedInto: 'f-server',
            )
          : null;
      final chain = await _enrolChain(h);
      h.server.stopAt = 1; // only the EnrolFarmer this time

      final result = await h.engine.syncNow();
      expect(result.merged, 1);
      final merged = (await h.store.syncLog()).singleWhere(
        (l) => l.kind == SyncLogKind.merged,
      );
      expect(merged.entityId, chain.farmer);
      expect(merged.message, 'f-server');
      final rows = await h.outbox();
      expect(
        rows.map((r) => r.type),
        isNot(contains(CommandType.enrolFarmer)),
        reason: 'merged, and the pulled snapshot carries it',
      );
      for (final r in rows) {
        expect(r.state, OutboxState.queued);
        expect(r.payload['farmer_id'], chain.farmer, reason: r.type.wire);
      }
      expect((await h.store.syncMeta()).idAliases, {chain.farmer: 'f-server'});

      final t = await h.territory();
      expect(t.farmers.where((f) => f.id == chain.farmer), isEmpty);
      expect(t.farmer(chain.farmer)!.id, 'f-server', reason: 'alias');
      expect(t.search('9848012345'), hasLength(1));
      expect([for (final p in t.plotsOf('f-server')) p.id], [chain.plot]);
      expect(t.activeSeason(chain.plot)!.id, chain.season);
      expect(result.pulled, isTrue, reason: 'pull the existing farmer');

      final before = h.server.received.length;
      h.clock.advance(const Duration(seconds: 15));
      await h.engine.run(SyncTrigger.retry);
      final sent = h.server.received.skip(before).toList();
      expect(
        [for (final c in sent) c.payload['farmer_id']],
        [chain.farmer, chain.farmer, chain.farmer],
      );
      expect(await h.outbox(), isEmpty);
      expect((await h.territory()).plotsOf('f-server'), hasLength(1));
    });

    group('conflict', () {
      Future<String> conflicted() async {
        // HO edited Padma's Plot 2 (1.5 ac, v3 -> 2.0 ac, v4) while the FA,
        // offline, changed it to 1.75 ac.
        await start(Harness(snapshot: fixtureSnapshot(padmaPlotAcres: 1.5)));
        h.server.snapshot = fixtureSnapshot(
          territoryVersion: 11,
          padmaPlotVersion: 4,
        );
        h.server.territoryVersion = 11;
        h.server.decide = (c) {
          if (c.type != 'SavePlot') return null;
          final p = SavePlotPayload.fromJson(c.payload);
          final cur = h.server.snapshot.plots.firstWhere(
            (x) => x.id == p.plotId,
          );
          if ((p.expectedVersion ?? 1) == cur.version) return null;
          return CommandResult(
            id: c.id,
            status: CommandStatus.conflict,
            entityId: p.plotId,
            conflict: Conflict(
              field: 'area_acres',
              yours: p.areaAcres,
              theirs: cur.areaAcres,
            ),
          );
        };
        await h.actions.savePlot(
          farmerId: padma,
          plotId: padmaPlot2,
          label: 'Plot 2',
          pin: padmaPin,
          areaAcres: 1.75,
          areaSource: AreaSource.typed,
        );
        expect((await h.territory()).plot(padmaPlot2)!.areaAcres, 1.75);
        final result = await h.engine.syncNow();
        expect(result.conflicts, 1);
        return (await h.outbox()).single.id;
      }

      test('the entry waits with yours and HO\'s; HO\'s value shows', () async {
        final id = await conflicted();
        final e = (await h.store.outboxEntry(id))!;
        expect(e.state, OutboxState.conflict);
        expect(
          e.conflict,
          const Conflict(field: 'area_acres', yours: 1.75, theirs: 2.0),
        );
        expect(e.canKeepMine, isTrue);
        final t = await h.territory();
        expect(t.plot(padmaPlot2)!.areaAcres, 2.0, reason: 'snapshot pulled');
        expect(t.plot(padmaPlot2)!.version, 4);
        expect(t.isPending(padmaPlot2), isTrue, reason: 'needs the FA');
        await _settle();
        expect(h.engine.state.conflicts.single.id, id);
        expect(h.engine.state.queuedCount, 0);
      });

      test(
        'Keep mine sends the change again, new ID, server version',
        () async {
          final id = await conflicted();
          await h.actions.keepMine(id);
          final rows = await h.outbox();
          expect(rows, hasLength(2));
          final old = rows[0];
          final again = rows[1];
          expect(old.state, OutboxState.resolved);
          expect(old.meta[OutboxMeta.resolution], 'mine');
          expect(old.meta[OutboxMeta.replacedBy], again.id);
          expect(again.id, isNot(id));
          expect(again.state, OutboxState.queued);
          expect(again.payload['expected_version'], 4);
          expect(again.payload['area_acres'], 1.75);
          expect(again.meta[OutboxMeta.replaces], id);
          expect(again.clientCreatedAt, old.clientCreatedAt);
          expect((await h.territory()).plot(padmaPlot2)!.areaAcres, 1.75);

          await h.engine.syncNow();
          expect(h.server.received.where((c) => c.id == id), hasLength(1));
          expect(h.server.stored[again.id]!.status, CommandStatus.applied);
          final t = await h.territory();
          expect(t.plot(padmaPlot2)!.areaAcres, 1.75);
          expect(t.plot(padmaPlot2)!.version, 5);
          expect(
            [for (final r in await h.outbox()) r.state],
            [OutboxState.resolved],
            reason: 'only the resolved row stays (until tapped away)',
          );
        },
      );

      test('Keep HO\'s resolves it; nothing is sent', () async {
        final id = await conflicted();
        final sent = h.server.received.length;
        await h.actions.keepTheirs(id);
        final e = (await h.store.outboxEntry(id))!;
        expect(e.state, OutboxState.resolved);
        expect(e.meta[OutboxMeta.resolution], 'theirs');
        expect((await h.territory()).plot(padmaPlot2)!.areaAcres, 2.0);
        await h.engine.syncNow();
        expect(h.server.received, hasLength(sent));
        await h.actions.dismiss(id);
        expect(await h.outbox(), isEmpty);
        expect(
          [for (final l in await h.store.syncLog()) l.kind],
          containsAllInOrder([
            SyncLogKind.conflict,
            SyncLogKind.keptTheirs,
            SyncLogKind.dismissed,
          ]),
        );
      });

      test(
        'UpdateFarmer: Keep mine takes the farmer version from the snapshot',
        () async {
          // The fake judges UpdateFarmer like the backend: another version
          // and another value is a conflict.
          await start(Harness());
          await h.actions.updateFarmer(farmerId: padma, nameTe: 'పద్మ');
          // HO renamed her (v6) meanwhile.
          h.server.snapshot = withVersion(fixtureSnapshot(), 11);
          h.server.snapshot = Snapshot(
            territoryVersion: 11,
            mastersVersion: 3,
            generatedAt: fixtureNow,
            farmers: [
              for (final f in h.server.snapshot.farmers)
                f.id == padma
                    ? SnapFarmer(
                        id: f.id,
                        phone: f.phone,
                        name: f.name,
                        nameTe: 'పద్మావతి',
                        language: f.language,
                        villageId: f.villageId,
                        source: f.source,
                        photoKey: f.photoKey,
                        plan: f.plan,
                        status: f.status,
                        consentsGranted: f.consentsGranted,
                        consentPending: f.consentPending,
                        profileCompletedAt: f.profileCompletedAt,
                        version: 6,
                        createdAt: f.createdAt,
                        updatedAt: f.updatedAt,
                      )
                    : f,
            ],
            plots: h.server.snapshot.plots,
            seasons: h.server.snapshot.seasons,
            visits: h.server.snapshot.visits,
            callbacks: h.server.snapshot.callbacks,
            alerts: h.server.snapshot.alerts,
            masters: h.server.snapshot.masters,
            villages: h.server.snapshot.villages,
          );
          h.server.territoryVersion = 11;
          await h.engine.syncNow();
          final e = (await h.outbox()).single;
          expect(e.state, OutboxState.conflict);
          expect((await h.territory()).farmer(padma)!.nameTe, 'పద్మావతి');
          await h.actions.keepMine(e.id);
          final again = (await h.outbox()).last;
          expect(again.payload['expected_version'], 6);
          expect(again.payload['fields'], {'name_te': 'పద్మ'});
          await h.engine.syncNow();
          expect((await h.territory()).farmer(padma)!.nameTe, 'పద్మ');
        },
      );

      test('an active-season clash: the queued visits move to the server\'s '
          'season and go; the clash can only be accepted', () async {
        await start(Harness());
        // Venkat's new plot syncs; then he starts a paddy season on it from
        // the farmer app, which this phone has not pulled.
        final plot = await h.actions.savePlot(
          farmerId: venkat,
          label: 'Plot 1',
          pin: const LatLng(17.46, 78.36),
          areaAcres: 1,
          areaSource: AreaSource.typed,
        );
        await h.engine.syncNow();
        const theirs = 's-venkat-farmer-app';
        h.server.snapshot = withVersion(
          h.server.snapshot,
          h.server.territoryVersion + 1,
          seasons: [
            ...h.server.snapshot.seasons,
            SnapSeason(
              id: theirs,
              farmerId: venkat,
              plotId: plot,
              seasonCode: 'rabi-2026-27',
              cropId: paddy,
              sowingDate: today.addDays(-20),
              previousCropId: null,
              status: SeasonStatus.active,
              version: 1,
              updatedAt: fixtureNow,
            ),
          ],
        );
        h.server.territoryVersion++;

        final mine = await h.actions.startSeason(
          farmerId: venkat,
          plotId: plot,
          cropId: cotton,
          sowingDate: today.addDays(-3),
        );
        final visit = await h.actions.planVisit(
          farmerId: venkat,
          plannedFor: today,
        );
        await h.actions.logVisit(
          VisitLogInput(
            farmerId: venkat,
            visitId: visit,
            stageId: stEmergence,
            photos: [
              VisitPhotoInput(
                bytes: photoBytes(3),
                contentType: PhotoContentType.jpeg,
              ),
            ],
          ),
        );
        final before = h.server.received.length;
        final result = await h.engine.syncNow();
        expect(result.conflicts, 1);
        final sent = h.server.batches.skip(1).toList();
        expect(
          [
            for (final b in sent) [for (final c in b) c.type],
          ],
          [
            ['StartSeason'],
            ['PlanVisit', 'LogVisit'],
          ],
          reason: 'the visits wait for the StartSeason answer',
        );
        final visits = h.server.received.skip(before + 1).toList();
        for (final c in visits) {
          expect(c.payload['season_id'], theirs, reason: c.type);
        }
        expect(
          visits.last.payload.containsKey('stage_id'),
          isFalse,
          reason: 'a cotton stage means nothing on a paddy season',
        );
        for (final c in visits) {
          expect(h.server.stored[c.id]!.status, CommandStatus.applied);
        }
        expect(h.photos.confirmed, hasLength(1), reason: 'the photo went up');

        final e = (await h.outbox()).single;
        expect(e.entityId, mine);
        expect(e.state, OutboxState.conflict);
        expect(e.meta[OutboxMeta.seasonReplacedBy], theirs);
        expect(e.canKeepMine, isFalse);
        await expectLater(
          h.actions.keepMine(e.id),
          throwsA(
            isA<FaActionError>().having(
              (x) => x.code,
              'code',
              FaActionError.wrongState,
            ),
          ),
        );
        await h.actions.keepTheirs(e.id);
        final t = await h.territory();
        expect(t.activeSeason(plot)!.id, theirs);
        expect(t.season(mine)!.id, theirs, reason: 'the old ID resolves');
        expect(t.visit(visit)!.seasonId, theirs);
        expect(t.visit(visit)!.status, VisitStatus.done);
      });
    });

    test('rejected in one batch: each command keeps the server\'s own reason; '
        'photos dropped', () async {
      await start(Harness());
      h.server.decide = (c) => CommandResult(
        id: c.id,
        status: CommandStatus.rejected,
        entityId: c.type == 'EnrolFarmer' ? null : FakeServer.entityIdOf(c),
        error: c.type == 'EnrolFarmer'
            ? ApiErrorCode.registeredWithAnotherFa
            : 'farmer: not found',
      );
      final chain = await _enrolChain(h);
      await h.actions.logVisit(
        VisitLogInput(
          farmerId: chain.farmer,
          visitId: chain.visit,
          photos: [
            VisitPhotoInput(
              bytes: photoBytes(1),
              contentType: PhotoContentType.jpeg,
            ),
            VisitPhotoInput(
              bytes: photoBytes(2),
              contentType: PhotoContentType.jpeg,
            ),
          ],
        ),
      );

      final result = await h.engine.syncNow();
      expect(
        h.server.batches,
        hasLength(1),
        reason: 'the batch ends after the StartSeason its visits use',
      );
      expect(
        [for (final c in h.server.batches.single) c.type],
        ['EnrolFarmer', 'SavePlot', 'StartSeason'],
      );
      expect(result.rejected, 3);
      expect(result.dropped, 2, reason: 'the visits never went');
      final rows = await h.outbox();
      expect(rows.first.state, OutboxState.rejected);
      expect(rows.first.rejection!.code, RejectionCode.registeredWithAnotherFa);
      for (final r in rows.skip(1).take(2)) {
        expect(r.state, OutboxState.rejected, reason: r.type.wire);
        expect(r.rejection!.code, RejectionCode.other);
        expect(r.rejection!.message, 'farmer: not found');
      }
      for (final r in rows.skip(3)) {
        expect(r.state, OutboxState.dropped, reason: r.type.wire);
        expect(r.rejection!.code, RejectionCode.parentRejected);
      }
      final photos = await h.store.photos();
      expect(photos.every((p) => p.state == PhotoUploadState.dropped), isTrue);
      expect(photos.every((p) => p.bytes.isEmpty), isTrue);
      expect(h.uploader.puts, 0);

      final t = await h.territory();
      expect(t.farmer(chain.farmer), isNull);
      expect(t.search('9848012345'), isEmpty);
      await _settle();
      expect(h.engine.state.rejected, hasLength(5));
      expect(h.engine.state.photosWaiting, 0);
    });

    test('a batch cut by retry_from: children the server judged keep their '
        'result, the unjudged rest is dropped', () async {
      await start(Harness());
      h.server.decide = (c) => switch (c.type) {
        'EnrolFarmer' => CommandResult(
          id: c.id,
          status: CommandStatus.rejected,
          error: ApiErrorCode.notInYourArea,
        ),
        'SavePlot' => CommandResult(
          id: c.id,
          status: CommandStatus.rejected,
          entityId: FakeServer.entityIdOf(c),
          error: 'farmer: not found',
        ),
        _ => null,
      };
      h.server.stopAt = 2;
      final chain = await _enrolChain(h);
      await h.actions.logVisit(
        VisitLogInput(
          farmerId: chain.farmer,
          visitId: chain.visit,
          photos: [
            VisitPhotoInput(
              bytes: photoBytes(1),
              contentType: PhotoContentType.jpeg,
            ),
          ],
        ),
      );

      final result = await h.engine.syncNow();
      expect(result.rejected, 2);
      expect(result.dropped, 3);
      final byType = {for (final r in await h.outbox()) r.type: r};
      expect(
        byType[CommandType.enrolFarmer]!.rejection!.code,
        RejectionCode.notInYourArea,
      );
      final plot = byType[CommandType.savePlot]!;
      expect(plot.state, OutboxState.rejected);
      expect(
        plot.rejection,
        const Rejection(RejectionCode.other, 'farmer: not found'),
      );
      for (final type in [
        CommandType.startSeason,
        CommandType.planVisit,
        CommandType.logVisit,
      ]) {
        expect(byType[type]!.state, OutboxState.dropped, reason: type.wire);
        expect(byType[type]!.rejection!.code, RejectionCode.parentRejected);
      }
      expect(
        [for (final c in h.server.received) c.type],
        ['EnrolFarmer', 'SavePlot', 'StartSeason'],
        reason: 'the batch ends at the StartSeason; dropped ones never go',
      );
      expect((await h.store.photos()).single.state, PhotoUploadState.dropped);
    });

    test(
      'a rejected parent drops queued children before they are sent',
      () async {
        await start(Harness(limits: const SyncLimits(maxBatch: 1)));
        h.server.decide = (c) => c.type == 'EnrolFarmer'
            ? CommandResult(
                id: c.id,
                status: CommandStatus.rejected,
                error: ApiErrorCode.notInYourArea,
              )
            : null;
        final chain = await _enrolChain(h);
        await h.actions.ackAlert(alertNote); // unrelated: still goes
        final result = await h.engine.syncNow();
        expect(
          [for (final c in h.server.received) c.type],
          ['EnrolFarmer', 'AckAlert'],
        );
        expect(result.rejected, 1);
        expect(result.dropped, 3);
        final byType = {for (final r in await h.outbox()) r.type: r};
        expect(
          byType[CommandType.enrolFarmer]!.rejection!.code,
          RejectionCode.notInYourArea,
        );
        expect(byType[CommandType.savePlot]!.state, OutboxState.dropped);
        expect(byType[CommandType.startSeason]!.state, OutboxState.dropped);
        expect(byType[CommandType.planVisit]!.state, OutboxState.dropped);
        expect((await h.territory()).plot(chain.plot), isNull);
      },
    );

    test('an unknown status counts as rejected', () async {
      await start(Harness());
      h.server.decide = (c) =>
          CommandResult(id: c.id, status: CommandStatus.unknown);
      await h.actions.ackAlert(alertNote);
      await h.engine.syncNow();
      final e = (await h.outbox()).single;
      expect(e.state, OutboxState.rejected);
      expect(e.rejection!.code, RejectionCode.other);
      expect((await h.territory()).alert(alertNote)!.status, AlertStatus.open);
    });

    test('rejection codes', () {
      expect(
        Rejection.fromError('registered_with_another_fa').code,
        RejectionCode.registeredWithAnotherFa,
      );
      expect(
        Rejection.fromError('not_in_your_area').code,
        RejectionCode.notInYourArea,
      );
      expect(
        Rejection.fromError('server_could_not_apply').code,
        RejectionCode.serverCouldNotApply,
      );
      expect(
        Rejection.fromError('client_invalid').code,
        RejectionCode.clientInvalid,
      );
      expect(
        Rejection.fromError('label: must be 1-60 characters').code,
        RejectionCode.other,
      );
      expect(Rejection.fromError(null).message, '');
    });
  });

  group('pull', () {
    test('304 only touches the pull time', () async {
      await start(Harness());
      h.clock.advance(const Duration(minutes: 5));
      final result = await h.engine.syncNow();
      expect(result.notModified, isTrue);
      expect(h.server.snapshotCalls, ['"t10-m3"']);
      expect((await h.store.syncMeta()).lastPullAt, h.clock.now());
      expect((await h.store.syncMeta()).etag, '"t10-m3"');
    });

    test(
      'a new snapshot keeps showing a queued LogVisit (projection replay)',
      () async {
        await start(Harness());
        await h.actions.logVisit(
          const VisitLogInput(
            farmerId: ravi,
            visitId: raviPlannedVisit,
            issues: [
              VisitIssueInput(
                issueId: issBollworm,
                severity: Severity.high,
                ruleId: ruleEmamectin,
              ),
            ],
          ),
        );
        // HO renamed Ravi's plot (t12); the LogVisit has not gone up.
        final fresh = withVersion(
          fixtureSnapshot(),
          12,
          plots: [
            for (final p in fixtureSnapshot().plots)
              p.id == raviPlot
                  ? SnapPlot(
                      id: p.id,
                      farmerId: p.farmerId,
                      label: 'Plot 1 (canal)',
                      villageId: p.villageId,
                      boundaryGeoJson: p.boundaryGeoJson,
                      pin: p.pin,
                      areaAcres: p.areaAcres,
                      areaSource: p.areaSource,
                      gpsAccuracyM: p.gpsAccuracyM,
                      status: p.status,
                      version: 2,
                      updatedAt: p.updatedAt,
                    )
                  : p,
          ],
        );
        await h.engine.writeSnapshot(fresh);
        final t = await h.territory();
        expect(t.meta.etag, '"t12-m3"');
        expect(t.plot(raviPlot)!.label, 'Plot 1 (canal)');
        final v = t.visit(raviPlannedVisit)!;
        expect(v.status, VisitStatus.done, reason: 'still logged');
        expect(v.issues.single.productName, 'Sample 5 SG');
        expect(t.openCallback(ravi), isNull);
        expect((await h.outbox()).single.state, OutboxState.queued);
      },
    );

    test(
      'the timer polls the status and pulls only when the ETag moved',
      () async {
        await start(Harness());
        await h.engine.run(SyncTrigger.timer);
        expect(h.server.statusCalls, 1);
        expect(h.server.snapshotCalls, isEmpty);
        h.server.territoryVersion = 11; // HO changed something
        final result = await h.engine.run(SyncTrigger.timer);
        expect(result.pulled, isTrue);
        expect(h.server.snapshotCalls, ['"t10-m3"']);
        expect((await h.store.syncMeta()).territoryVersion, 11);
      },
    );

    test(
      'force, or season codes past valid_until, pull without If-None-Match',
      () async {
        await start(Harness());
        await h.engine.syncNow(force: true);
        expect(h.server.snapshotCalls, [null]);
        // Past valid_until the ETag does not move: the timer run (not only
        // Sync now) must still pull, once per stalePullEvery.
        h.clock.set(DateTime.utc(2027, 4, 2, 5));
        await h.engine.run(SyncTrigger.timer);
        expect(h.server.snapshotCalls, [null, null]);
        await h.engine.run(SyncTrigger.timer);
        expect(h.server.snapshotCalls, hasLength(2), reason: 'throttled');
        h.clock.advance(const Duration(minutes: 31));
        await h.engine.run(SyncTrigger.connectivity);
        expect(h.server.snapshotCalls, [null, null, null]);
      },
    );

    test('the first run pulls even without a trigger that asks', () async {
      h = Harness();
      final result = await h.engine.run(SyncTrigger.action);
      expect(result.pulled, isTrue);
      expect((await h.territory()).farmerCount, 5);
    });
  });

  group('a killed run', () {
    test('the answer lost after the server applied: nothing lost, nothing '
        'applied twice', () async {
      await start(Harness());
      await h.actions.logVisit(
        const VisitLogInput(farmerId: ravi, visitId: raviPlannedVisit),
      );
      await h.actions.planVisit(farmerId: padma, plannedFor: today.addDays(2));
      final queued = await h.outbox();
      h.server.errorAfterProcessing = StateError('app killed mid push');

      final first = await h.engine.syncNow();
      expect(first.error, isStateError);
      var rows = await h.outbox();
      expect(
        [for (final r in rows) r.state],
        [OutboxState.queued, OutboxState.queued],
      );
      expect(
        (await h.territory()).visit(raviPlannedVisit)!.status,
        VisitStatus.done,
      );

      await h.engine.syncNow();
      expect(
        [for (final c in h.server.received) c.id],
        [..._ids(queued), ..._ids(queued)],
        reason: 'sent again with the same IDs',
      );
      for (final id in _ids(queued)) {
        expect(h.server.dispatched[id], 1, reason: 'processed once');
      }
      rows = await h.outbox();
      expect(rows, isEmpty);
      final t = await h.territory();
      expect(t.visit(raviPlannedVisit)!.status, VisitStatus.done);
      expect(
        t.visitsOf(padma).where((v) => v.status == VisitStatus.planned),
        hasLength(1),
      );
    });

    test('the app killed mid push (rows left sending, the server already '
        'applied them): sent again, applied once', () async {
      await start(Harness());
      await h.actions.ackAlert(alertNote);
      await h.actions.planVisit(farmerId: padma, plannedFor: today);
      final rows = await h.outbox();
      // The killed run had marked them sending and the server got them.
      for (final e in rows) {
        await h.store.updateOutbox(
          e.copyWith(state: OutboxState.sending, attempts: 1),
        );
      }
      await h.server.submitCommands([for (final e in rows) e.toCommandIn()]);
      expect(
        (await h.territory()).alert(alertNote)!.status,
        AlertStatus.acknowledged,
      );
      // A new engine (the app started again) once the old lease ran out.
      h.clock.advance(const Duration(minutes: 3));
      await h.engine.syncNow();
      expect(
        [for (final c in h.server.received) c.id],
        [..._ids(rows), ..._ids(rows)],
      );
      for (final e in rows) {
        expect(h.server.dispatched[e.id], 1, reason: 'processed once');
      }
      expect(await h.outbox(), isEmpty);
    });
  });

  group('photos', () {
    Future<LoggedVisit> logWithPhotos() => h.actions.logVisit(
      VisitLogInput(
        farmerId: ravi,
        visitId: raviPlannedVisit,
        photos: [
          VisitPhotoInput(
            bytes: photoBytes(1),
            contentType: PhotoContentType.jpeg,
          ),
          VisitPhotoInput(
            bytes: photoBytes(2, length: 1000),
            contentType: PhotoContentType.jpeg,
          ),
        ],
      ),
    );

    test('wait for the LogVisit, then upload; Wi-Fi only holds them on mobile '
        'data', () async {
      await start(Harness(wifi: false));
      final logged = await logWithPhotos();
      await _settle();
      expect(h.engine.state.photosWaiting, 2);
      expect(h.engine.state.photosWaitingBytes, 66 + 1002);

      await h.engine.syncNow();
      expect(h.uploader.puts, 0);
      expect(
        [for (final p in await h.store.photos()) p.state],
        [PhotoUploadState.ready, PhotoUploadState.ready],
      );
      await _settle();
      expect(h.engine.state.photosHeldForWifi, isTrue);
      expect(
        h.engine.state.queuedCount,
        0,
        reason: 'records went on mobile data',
      );

      h.net.setWifi(true);
      final result = await h.engine.syncNow();
      expect(result.photosUploaded, 2);
      expect(h.photos.uploadUrlCalls, logged.photoIds);
      final photos = await h.store.photos();
      for (final p in photos) {
        expect(p.state, PhotoUploadState.done);
        expect(p.bytes, isEmpty);
        expect(h.photos.confirmed[p.photoId], p.sha256);
      }
      expect(
        h.uploader.uploads['https://storage.test/${logged.photoIds[1]}'],
        photoBytes(2, length: 1000),
      );
      await _settle();
      expect(h.engine.state.photosWaiting, 0);
      expect(h.engine.state.photosHeldForWifi, isFalse);
    });

    test(
      'a started engine uploads held photos when Wi-Fi comes back',
      () async {
        await start(Harness(wifi: false));
        await logWithPhotos();
        h.engine.start();
        await h.engine.syncNow();
        await _settle();
        expect(h.engine.state.photosHeldForWifi, isTrue);
        expect(h.engine.state.onWifi, isFalse);

        h.net.setWifi(true);
        for (var i = 0; i < 50 && h.uploader.puts < 2; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(h.uploader.puts, 2, reason: 'no Sync now needed');
        await _settle();
        expect(h.engine.state.onWifi, isTrue);
        expect(h.engine.state.photosWaiting, 0);
      },
    );

    test('with Wi-Fi only off they go on mobile data', () async {
      await start(Harness(wifi: false));
      await h.actions.setPhotosOnWifiOnly(false);
      await logWithPhotos();
      final result = await h.engine.syncNow();
      expect(result.photosUploaded, 2);
    });

    test(
      'upload_missing PUTs again; photo_already_uploaded just confirms',
      () async {
        await start(Harness());
        await logWithPhotos();
        h.photos.confirmErrors.add(
          const ApiError(
            code: ApiErrorCode.uploadMissing,
            message: 'missing',
            status: 409,
          ),
        );
        h.photos.createErrors.addAll([
          const ApiError(
            code: ApiErrorCode.photoAlreadyUploaded,
            message: 'done',
            status: 409,
          ),
        ]);
        final first = await h.engine.syncNow();
        // Photo 1: already uploaded -> confirm fails upload_missing -> ready.
        // Photo 2: uploaded and confirmed.
        expect(first.photosUploaded, 1);
        final waiting = await h.store.photos(states: {PhotoUploadState.ready});
        expect(waiting, hasLength(1));
        expect(waiting.single.lastError, ApiErrorCode.uploadMissing);
        final second = await h.engine.syncNow();
        expect(second.photosUploaded, 1);
        expect(h.uploader.puts, 2);
      },
    );

    test('a network error keeps the photo for later', () async {
      await start(Harness());
      await logWithPhotos();
      h.photos.createErrors.add(_network);
      final first = await h.engine.syncNow();
      expect(first.photosUploaded, 0);
      final p = (await h.store.photos()).first;
      expect(p.state, PhotoUploadState.ready);
      expect(p.attempts, 1);
      expect(p.nextAttemptAt, isNotNull);
      final later = await h.engine.run(SyncTrigger.timer);
      expect(
        h.photos.uploadUrlCalls.where((id) => id == p.photoId),
        hasLength(1),
        reason: 'waits for its backoff',
      );
      expect(later.photosUploaded, 1, reason: 'the other one goes');
      final again = await h.engine.syncNow();
      expect(again.photosUploaded, 1);
    });
  });

  group('consent proofs', () {
    test('an EnrolFarmer whose proof expired goes without it', () async {
      await start(Harness());
      await h.actions.enrolFarmer(
        phone: '9848012345',
        name: 'Suresh B',
        language: Language.te,
        villageId: kondapur,
        proof: ConsentProof(
          phone: '+919848012345',
          otpProof: 'signed-proof',
          verifiedAt: fixtureNow,
          expiresAt: fixtureNow.add(const Duration(days: 7)),
        ),
        noticeVersion: 'v3',
      );
      final id = (await h.outbox()).single.id;
      expect((await h.territory()).farmers.last.consentPending, isFalse);
      h.net.setOnline(false);
      h.clock.advance(const Duration(days: 8));
      h.net.setOnline(true);
      h.server.applyToSnapshot = false;
      h.server.servedVersion = 10;
      await h.engine.syncNow();
      final sent = h.server.received.single;
      expect(sent.id, id, reason: 'same command, never sent before');
      expect(
        (sent.payload['consent']! as Map<String, Object?>)['otp_proof'],
        isNull,
      );
      final e = (await h.outbox()).single;
      expect(e.meta[OutboxMeta.consentProofDropped], isTrue);
      expect((await h.territory()).farmers.last.consentPending, isTrue);
    });

    test(
      'a RecordConsent whose proof expired is rejected on the phone',
      () async {
        await start(Harness());
        await h.actions.recordConsent(
          farmerId: raju,
          proof: ConsentProof(
            phone: '+919000000150',
            otpProof: 'signed-proof',
            verifiedAt: fixtureNow,
            expiresAt: fixtureNow.add(const Duration(days: 7)),
          ),
          noticeVersion: 'v3',
        );
        h.clock.advance(const Duration(days: 8));
        await h.engine.syncNow();
        expect(h.server.received, isEmpty);
        final e = (await h.outbox()).single;
        expect(e.rejection!.code, RejectionCode.consentProofExpired);
        expect((await h.territory()).farmer(raju)!.consentPending, isTrue);
      },
    );
  });

  group('client errors', () {
    test(
      '400 for the whole batch: bisect, reject the bad one, send the rest',
      () async {
        await start(Harness());
        final ids = await _plans(h, 5);
        final queued = await h.outbox();
        h.server.badIds.add(queued[2].id);
        final result = await h.engine.syncNow();
        final rows = await h.outbox();
        expect(rows, hasLength(1), reason: 'the 4 good ones are synced');
        final bad = rows.single;
        expect(bad.id, queued[2].id);
        expect(bad.rejection!.code, RejectionCode.clientInvalid);
        expect(bad.meta[OutboxMeta.detail], 'commands[2].payload: bad');
        expect(result.rejected, 1);
        expect(h.server.dispatched.keys.toList(), [
          for (final e in queued)
            if (e.id != bad.id) e.id,
        ], reason: 'the rest went in order');
        expect(
          (await h.territory()).visit(ids[2]),
          isNull,
          reason: 'taken back',
        );
        expect(h.server.batches.length, lessThanOrEqualTo(6));
      },
    );

    test('413: halve the batch', () async {
      await start(Harness());
      await _plans(h, 4);
      final two = jsonEncode({
        'commands': [
          for (final e in (await h.outbox()).take(2)) e.toCommandIn().toJson(),
        ],
      });
      h.server.maxBodyBytes = utf8.encode(two).length + 10;
      await h.engine.syncNow();
      expect([for (final b in h.server.batches) b.length], [4, 2, 2]);
      expect(await h.outbox(), isEmpty);
    });

    test('a command bigger than any batch is rejected on the phone', () async {
      await start(Harness(limits: const SyncLimits(maxBatchBytes: 100)));
      await h.actions.ackAlert(alertNote);
      await h.engine.syncNow();
      expect(h.server.received, isEmpty);
      final e = (await h.outbox()).single;
      expect(e.rejection!.code, RejectionCode.clientInvalid);
      expect(e.meta[OutboxMeta.detail], ApiErrorCode.payloadTooLarge);
    });
  });

  group('runner', () {
    test(
      'runs never overlap; asks meanwhile share one follow-up run',
      () async {
        await start(Harness());
        await h.actions.ackAlert(alertNote);
        final hold = Completer<void>();
        h.server.hold = hold;
        final first = h.engine.syncNow();
        await _settle();
        await h.actions.ackAlert(alertCallback);
        final second = h.engine.syncNow();
        final third = h.engine.run(SyncTrigger.action);
        await _settle();
        expect(h.server.batches, hasLength(1));
        hold.complete();
        final results = await Future.wait([first, second, third]);
        expect(h.server.overlapped, isFalse);
        expect(h.server.batches, hasLength(2));
        expect(results[0].sent, 2, reason: 'the first run took the new one');
        expect(results[1].sent, 0);
        expect(identical(results[1], results[2]), isTrue);
        expect(await h.outbox(), isEmpty);
      },
    );

    test('another runner holding the lease keeps this one out', () async {
      await start(Harness());
      await h.store.acquireSyncLease(
        'background-worker',
        now: fixtureNow,
        ttl: const Duration(minutes: 2),
      );
      final result = await h.engine.syncNow();
      expect(result.skipped, SyncSkip.busy);
      expect(h.server.batches, isEmpty);
      h.clock.advance(const Duration(minutes: 3));
      expect((await h.engine.syncNow()).skipped, isNull);
    });

    test('the state follows the network while the engine is stopped', () async {
      await start(Harness());
      await _settle();
      expect(h.engine.state.online, isTrue);
      expect(h.engine.state.onWifi, isTrue);

      h.net.setOnline(false);
      await _settle();
      expect(h.engine.state.online, isFalse);
      expect(h.engine.state.onWifi, isFalse);

      h.net.setOnline(true);
      h.net.setWifi(false);
      await _settle();
      expect(h.engine.state.online, isTrue);
      expect(h.engine.state.onWifi, isFalse);
      expect(h.server.batches, isEmpty, reason: 'not started: no runs');
    });

    test('run progress counts the answered commands of this run', () async {
      await start(Harness(limits: const SyncLimits(maxBatch: 2)));
      await _plans(h, 3);
      expect(h.engine.state.runProgress, isNull);

      final first = Completer<void>();
      h.server.hold = first;
      final run = h.engine.syncNow();
      await _settle();
      expect(h.engine.state.running, isTrue);
      expect(h.engine.state.runSent, 0);
      expect(h.engine.state.runTotal, 3);
      expect(h.engine.state.runProgress, 0);

      final second = Completer<void>();
      first.complete();
      h.server.hold = second;
      await _settle();
      expect(h.engine.state.runSent, 2);
      expect(h.engine.state.runTotal, 3);
      expect(h.engine.state.runProgress, closeTo(2 / 3, 1e-9));

      // A save during the run joins it.
      await h.actions.ackAlert(alertNote);
      second.complete();
      await run;
      expect(h.server.received, hasLength(4));
      await _settle();
      expect(h.engine.state.running, isFalse);
      expect(h.engine.state.runSent, 0);
      expect(h.engine.state.runTotal, 0);
      expect(h.engine.state.runProgress, isNull);
    });

    test('offline: nothing is tried', () async {
      await start(Harness(online: false));
      await h.actions.ackAlert(alertNote);
      final result = await h.engine.syncNow();
      expect(result.skipped, SyncSkip.offline);
      expect(h.server.batches, isEmpty);
      await _settle();
      expect(h.engine.state.online, isFalse);
      expect(h.engine.state.queuedCount, 1);
    });
  });

  test('the session guard: pending count, push, wipe', () async {
    await start(Harness());
    await h.actions.ackAlert(alertNote);
    await h.actions.logVisit(
      VisitLogInput(
        farmerId: ravi,
        photos: [
          VisitPhotoInput(
            bytes: photoBytes(1),
            contentType: PhotoContentType.jpeg,
          ),
        ],
      ),
    );
    expect(await h.engine.pendingCount(), 3, reason: '2 records + 1 photo');
    h.net.setOnline(false);
    expect(await h.engine.pushPending(), isFalse);
    h.net.setOnline(true);
    expect(await h.engine.pushPending(), isTrue);
    await h.engine.wipe();
    expect(await h.store.baseSnapshot(), isNull);
    expect((await h.territory()).hasData, isFalse);
  });
}
