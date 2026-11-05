import 'dart:typed_data';

import 'package:fa/src/data/data.dart';
import 'package:fa/src/device/device.dart';
import 'package:fa/src/features/sync/sync_rows.dart';
import 'package:fa/src/features/sync/sync_screen.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/shared/fa_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

/// Lets the engine's debounced nudge after an action run (or skip).
Future<void> _settleNudge(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// Suresh offline with the HO note acknowledged on the phone (one record
/// waiting).
Future<FaTest> _offlineWithAck() async {
  final t = await createFaTest();
  t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
  final note = t.territory.alerts.firstWhere(
    (a) => a.kind == AlertKind.hoNote && a.status == AlertStatus.open,
  );
  await t.read(faActionsProvider).ackAlert(note.id);
  await t.read(territoryProvider.future);
  return t;
}

/// Edits Padma S's Plot 2 to 1 ac 30 gunta while HO changes it: a conflict.
Future<FaTest> _withConflict() async {
  final t = await createFaTest(scenario: MockScenario.syncConflict);
  await t
      .read(faActionsProvider)
      .savePlot(
        farmerId: MockBackend.padmaId,
        plotId: MockBackend.padmaPlot2Id,
        label: 'Plot 2',
        pin: MockLocationService.kondapur,
        areaAcres: 1.75,
        areaSource: AreaSource.typed,
      );
  final result = await t.read(syncEngineProvider).syncNow();
  expect(result.conflicts, 1);
  return t;
}

/// Enrols FA-CVL-002's farmer (refused: another FA) and a plot for them
/// (refused with it in the same batch, with the server's own reason).
Future<FaTest> _withRejection() async {
  final t = await createFaTest();
  final actions = t.read(faActionsProvider);
  final farmerId = await actions.enrolFarmer(
    phone: MockBackend.otherFaFarmerPhone,
    name: 'Narsimha G',
    nameTe: 'నర్సింహ జి',
    language: Language.te,
    villageId: MockBackend.kondapurId,
  );
  await actions.savePlot(
    farmerId: farmerId,
    label: 'Plot 1',
    pin: MockLocationService.kondapur,
    areaAcres: 1,
    areaSource: AreaSource.typed,
  );
  await t.read(syncEngineProvider).syncNow();
  expect(
    [for (final e in t.read(syncStateProvider).records) e.state],
    [OutboxState.rejected, OutboxState.rejected],
  );
  return t;
}

void main() {
  group('SyncScreen', () {
    testWidgets('all synced after sign-in', (tester) async {
      final t = await pumpFaScreen(tester, const SyncScreen());
      expect(find.text(te.faShellTitleSync), findsOneWidget);
      expect(find.text(te.faSyncLastSyncedJustNow), findsOneWidget);
      expect(find.text(te.faSyncAllSyncedTitle), findsOneWidget);
      expect(find.bySemanticsLabel(te.faShellSyncAllSynced), findsOneWidget);
      expect(find.byType(SyncPill), findsNothing);
      expect(
        find.text(
          te.faSyncSyncedToday(count: t.read(syncStateProvider).syncedToday),
        ),
        findsOneWidget,
      );
      expect(orbitButton(te.faSyncSyncNow), findsOneWidget);
    });

    testWidgets('offline: banner and a waiting row; Sync now says why', (
      tester,
    ) async {
      final t = await _offlineWithAck();
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      expect(find.text(te.faSyncOfflineTitle), findsOneWidget);
      expect(find.text(te.faSyncOfflineBody(count: 1)), findsOneWidget);
      expect(
        find.text('${te.faSyncTypeAlert} · Pending enrolments'),
        findsOneWidget,
      );
      expect(statusPill(te.faSyncPillWaiting), findsOneWidget);
      expect(
        find.bySemanticsLabel(te.faShellSyncWaiting(count: 1)),
        findsOneWidget,
      );

      await tester.tap(orbitButton(te.faSyncSyncNow));
      await tester.pumpAndSettle();
      expect(find.text(te.errorNetwork), findsOneWidget);
      await _settleNudge(tester);
    });

    testWidgets('Sync now sends what waits', (tester) async {
      final t = await _offlineWithAck();
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      t.read(mockScenarioProvider.notifier).select(MockScenario.normal);
      await tester.tap(orbitButton(te.faSyncSyncNow));
      await tester.pumpAndSettle();
      final s = t.read(syncStateProvider);
      expect(s.queuedCount, 0);
      expect(find.text(te.faSyncAllSyncedTitle), findsOneWidget);
      expect(
        find.text(te.faSyncSyncedToday(count: s.syncedToday)),
        findsOneWidget,
      );
      expect(s.syncedToday, greaterThanOrEqualTo(1));
      await _settleNudge(tester);
    });

    testWidgets('a waiting visit log row shows photos and size', (
      tester,
    ) async {
      final t = await createFaTest();
      t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
      await t
          .read(faActionsProvider)
          .logVisit(
            VisitLogInput(
              farmerId: MockBackend.raviId,
              photos: [
                VisitPhotoInput(
                  bytes: Uint8List(1500000),
                  contentType: PhotoContentType.jpeg,
                ),
              ],
            ),
          );
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      expect(find.text('${te.faSyncTypeVisit} · రవి కె'), findsOneWidget);
      expect(
        find.textContaining(te.faSyncPhotosCount(count: 1)),
        findsOneWidget,
      );
      expect(find.textContaining('1.5 MB'), findsWidgets);
      await _settleNudge(tester);
    });

    testWidgets("conflict: Yours vs HO's, then Keep HO's", (tester) async {
      final t = await _withConflict();
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      expect(find.byType(ConflictCard), findsOneWidget);
      expect(find.text(te.faCommonArea(acres: 1, guntas: 30)), findsOneWidget);
      expect(find.text(te.faCommonArea(acres: 2, guntas: 0)), findsOneWidget);
      expect(
        find.text(te.faSyncConflictMetaPlot(plot: 'Plot 2')),
        findsOneWidget,
      );
      expect(
        find.text(
          te.faSyncNeedsYouTitle(
            count: 1,
            synced: t.read(syncStateProvider).syncedToday,
          ),
        ),
        findsOneWidget,
      );

      await scrollAndTap(tester, find.text(te.faSyncKeepTheirs));
      final entry = t.read(syncStateProvider).records.single;
      expect(entry.state, OutboxState.resolved);
      expect(find.byType(ConflictCard), findsNothing);
      expect(
        find.text(
          te.faSyncResolvedTheirs(value: te.faCommonArea(acres: 2, guntas: 0)),
        ),
        findsOneWidget,
      );

      await scrollAndTap(tester, orbitButton(te.faSyncDismiss));
      expect(t.read(syncStateProvider).records, isEmpty);
      await _settleNudge(tester);
    });

    testWidgets('an edit made during the conflict waits on the card', (
      tester,
    ) async {
      final t = await _withConflict();
      t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
      // The FA changes the plot again before choosing: 1 ac 20 gunta.
      await t
          .read(faActionsProvider)
          .savePlot(
            farmerId: MockBackend.padmaId,
            plotId: MockBackend.padmaPlot2Id,
            label: 'Plot 2',
            pin: MockLocationService.kondapur,
            areaAcres: 1.5,
            areaSource: AreaSource.typed,
          );
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      expect(find.byType(ConflictCard), findsOneWidget);
      // Yours is the latest edit, and the card says it is held there.
      expect(find.text(te.faCommonArea(acres: 1, guntas: 20)), findsOneWidget);
      expect(find.text(te.faCommonArea(acres: 1, guntas: 30)), findsNothing);
      expect(find.textContaining(te.faSyncConflictWaiting), findsOneWidget);
      expect(
        [for (final e in t.read(syncStateProvider).records) e.state],
        [OutboxState.conflict],
      );
      await _settleNudge(tester);
    });

    testWidgets('a conflict with no later edit says nothing is waiting', (
      tester,
    ) async {
      final t = await _withConflict();
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      expect(find.textContaining(te.faSyncConflictWaiting), findsNothing);
      await _settleNudge(tester);
    });

    testWidgets('conflict: Keep mine queues the change again', (tester) async {
      final t = await _withConflict();
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
      await scrollAndTap(tester, find.text(te.faSyncKeepMine));
      final records = t.read(syncStateProvider).records;
      expect(records.first.state, OutboxState.resolved);
      expect(records.last.state, OutboxState.queued);
      expect(records.last.type, CommandType.savePlot);
      expect(
        find.textContaining(
          te.faSyncResolvedMine(value: te.faCommonArea(acres: 1, guntas: 30)),
        ),
        findsOneWidget,
      );
      // The resent edit shows on the resolved row, not as its own row.
      expect(statusPill(te.faSyncPillWaiting), findsOneWidget);
      await _settleNudge(tester);
    });

    testWidgets("a season clash can only keep HO's", (tester) async {
      final t = await createFaTest();
      final plot = MockBackend.padmaPlot2Id;
      final active = t.territory.activeSeason(plot);
      expect(active, isNotNull);
      final other = t.territory.masters.crops.firstWhere(
        (c) => c.id != active!.cropId,
      );
      // FaActions now refuses a second season on the phone, so queue the
      // StartSeason as a phone that had not pulled HO's season yet would
      // have it: the server answers with the clash.
      final actions = t.read(faActionsProvider);
      await t.read(localStoreProvider).transaction((tx) async {
        await tx.insertOutbox(
          OutboxEntry.create(
            id: actions.newId(),
            command: StartSeasonPayload(
              seasonId: actions.newId(),
              farmerId: MockBackend.padmaId,
              plotId: plot,
              seasonCode: t.territory.seasonCodes.current,
              cropId: other.id,
            ),
            now: testClock.now(),
          ),
        );
      });
      final result = await t.read(syncEngineProvider).syncNow();
      expect(result.conflicts, 1);
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      expect(find.byType(ConflictCard), findsOneWidget);
      expect(find.text(te.faSyncKeepMine), findsNothing);
      expect(find.textContaining(te.faSyncConflictOnlyTheirs), findsOneWidget);
      await scrollAndTap(tester, find.text(te.faSyncKeepTheirs));
      expect(
        t.read(syncStateProvider).records.first.state,
        OutboxState.resolved,
      );
      await _settleNudge(tester);
    });

    testWidgets('records waiting on mobile data say so', (tester) async {
      final t = await createFaTest();
      final net = t.read(connectivityProvider) as MockConnectivityService;
      net.setWifi(false);
      t.read(syncEngineProvider).stop();
      final note = t.territory.alerts.firstWhere(
        (a) => a.kind == AlertKind.hoNote && a.status == AlertStatus.open,
      );
      await t.read(faActionsProvider).ackAlert(note.id);
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      expect(t.read(syncStateProvider).onWifi, isFalse);
      expect(find.text(te.faSyncMobileDataTitle), findsOneWidget);
      await _settleNudge(tester);
    });

    testWidgets('refused enrolment: reason, dropped plot, Call HO, Dismiss', (
      tester,
    ) async {
      final t = await _withRejection();
      await pumpFaScreen(tester, const SyncScreen(), test: t);
      expect(find.text('${te.faSyncTypeEnrol} · నర్సింహ జి'), findsOneWidget);
      expect(find.text(te.faSyncReasonOtherFa), findsOneWidget);
      expect(find.text(te.faSyncDroppedHeading), findsOneWidget);
      expect(find.text('• ${te.faSyncTypePlot} · నర్సింహ జి'), findsOneWidget);
      expect(statusPill(te.faSyncPillNotSaved), findsOneWidget);

      await scrollAndTap(tester, orbitButton(te.faSyncCallHo));
      expect(t.launcher.calls, ['18001234567']);

      await scrollAndTap(tester, orbitButton(te.faSyncDismiss));
      expect(t.read(syncStateProvider).records, isEmpty);
      expect(find.text(te.faSyncReasonOtherFa), findsNothing);
      await _settleNudge(tester);
    });

    for (final dev in [true, false]) {
      testWidgets('the server\'s own reason shows only in dev builds '
          '(dev: $dev)', (tester) async {
        final t = await createFaTest(
          overrides: [showServerReasonsProvider.overrideWithValue(dev)],
        );
        // Offline, so the ack stays on the phone until it is rewritten.
        t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
        final note = t.territory.alerts.firstWhere(
          (a) => a.kind == AlertKind.hoNote && a.status == AlertStatus.open,
        );
        await t.read(faActionsProvider).ackAlert(note.id);
        final id = (await t.read(localStoreProvider).outbox()).single.id;
        await t.read(localStoreProvider).transaction((tx) async {
          final e = (await tx.outboxEntry(id))!;
          await tx.updateOutbox(
            e.copyWith(
              state: OutboxState.rejected,
              result: CommandResult(
                id: e.id,
                status: CommandStatus.rejected,
                error: 'alert table locked',
              ),
            ),
          );
        });
        await pumpFaScreen(tester, const SyncScreen(), test: t);
        expect(find.text(te.faSyncReasonOther), findsOneWidget);
        expect(
          find.text('alert table locked'),
          dev ? findsOneWidget : findsNothing,
        );
        await _settleNudge(tester);
      });
    }

    testWidgets('Wi-Fi only switch saves the setting', (tester) async {
      final t = await pumpFaScreen(tester, const SyncScreen());
      expect(t.read(syncStateProvider).photosOnWifiOnly, isTrue);
      expect(find.text(te.faSyncWifiOn), findsOneWidget);
      await scrollAndTap(tester, find.text(te.faSyncWifiTitle));
      expect(t.read(syncStateProvider).photosOnWifiOnly, isFalse);
      expect(find.text(te.faSyncWifiOff), findsOneWidget);
      await _settleNudge(tester);
    });

    testWidgets('English UI', (tester) async {
      final t = await _withRejection();
      await pumpFaScreen(
        tester,
        const SyncScreen(),
        test: t,
        locale: const Locale('en'),
      );
      expect(find.text(en.faSyncReasonOtherFa), findsOneWidget);
      expect(find.text('${en.faSyncTypeEnrol} · Narsimha G'), findsOneWidget);
      await _settleNudge(tester);
    });

    test('formatBytes', () {
      expect(formatBytes(en, 3100000), '3.1 MB');
      expect(formatBytes(en, 420000), '420 KB');
      expect(formatBytes(en, 10), '1 KB');
    });

    screenLayoutTest('Sync, all synced', () => const SyncScreen());
    for (final scale in textScales) {
      testWidgets('Sync with a conflict and a refusal fits at $scale', (
        tester,
      ) async {
        final t = await _withRejection();
        t.backend.scenario = MockScenario.syncConflict;
        await t
            .read(faActionsProvider)
            .savePlot(
              farmerId: MockBackend.padmaId,
              plotId: MockBackend.padmaPlot2Id,
              label: 'Plot 2',
              pin: MockLocationService.kondapur,
              areaAcres: 1.75,
              areaSource: AreaSource.typed,
            );
        await t.read(syncEngineProvider).syncNow();
        await pumpFaScreen(
          tester,
          const SyncScreen(),
          test: t,
          textScale: scale,
        );
        expectCleanLayout(tester);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expectCleanLayout(tester);
        await _settleNudge(tester);
      });
    }
  });
}
