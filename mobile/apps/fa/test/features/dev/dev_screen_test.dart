import 'package:fa/src/data/data.dart';
import 'package:fa/src/device/device.dart';
import 'package:fa/src/features/dev/dev_screen.dart';
import 'package:fa/src/local/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

void main() {
  group('DevScreen', () {
    testWidgets('lists every scenario with its description', (tester) async {
      await pumpFaScreen(tester, const DevScreen());
      for (final s in MockScenario.values) {
        await tester.scrollUntilVisible(
          find.text(s.description),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(s.label), findsOneWidget);
      }
    });

    testWidgets('picking a scenario switches the mock and the network', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const DevScreen());
      await scrollAndTap(tester, find.text(MockScenario.offline.label));
      expect(t.read(mockScenarioProvider), MockScenario.offline);
      expect(t.backend.scenario, MockScenario.offline);
      expect(t.read(connectivityProvider).isOnline, isFalse);
    });

    testWidgets('mock GPS: poor and good accuracy, boundary walk', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const DevScreen());
      final gps = t.read(locationServiceProvider) as MockLocationService;
      await scrollAndTap(tester, find.text('Poor accuracy (±28 m)'));
      expect(gps.accuracyM, MockLocationService.poorAccuracyM);
      expect(find.text('Accuracy ±28 m', skipOffstage: false), findsOneWidget);
      await scrollAndTap(tester, find.text('Good accuracy'));
      expect(gps.accuracyM, MockLocationService.goodAccuracyM);

      await scrollAndTap(tester, find.text('Start a boundary walk'));
      expect(gps.walking, isTrue);
      await scrollAndTap(tester, find.text('Stop walk', skipOffstage: false));
      expect(gps.walking, isFalse);
    });

    testWidgets('HO sends a note: it reaches the phone', (tester) async {
      final t = await pumpFaScreen(tester, const DevScreen());
      final before = t.territory.openAlertCount;
      await scrollAndTap(tester, find.text('HO sends a note'));
      await tester.pumpAndSettle();
      expect(t.territory.openAlertCount, before + 1);
      expect(t.territory.alerts.first.title, 'Soil samples');
    });

    testWidgets('a farmer asks for a call-back: alert and call-back', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const DevScreen());
      await scrollAndTap(tester, find.text('Farmer asks for call-back'));
      await tester.pumpAndSettle();
      expect(t.territory.openCallback(MockBackend.venkatId), isNotNull);
      expect(t.territory.alerts.first.kind, AlertKind.callback);
    });

    testWidgets('HO edits Padma S Plot 2: the phone gets 2 ac 0 gunta', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const DevScreen());
      final version = t.territory.plot(MockBackend.padmaPlot2Id)!.version;
      await scrollAndTap(tester, find.text('HO edits Padma S Plot 2'));
      await tester.pumpAndSettle();
      final plot = t.territory.plot(MockBackend.padmaPlot2Id)!;
      expect(plot.areaAcres, 2);
      expect(plot.version, version + 1);
    });

    testWidgets('shows the ETag and versions, and forces a sync', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const DevScreen());
      final meta = t.territory.meta;
      await tester.scrollUntilVisible(
        find.textContaining('ETag ${meta.etag}'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('territory v${meta.territoryVersion}'),
        findsOneWidget,
      );
      expect(find.textContaining('0 waiting'), findsOneWidget);
      await scrollAndTap(tester, find.text('Force sync'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SyncRunResult'), findsOneWidget);
    });

    testWidgets('reset asks first, then wipes the phone and signs out', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const DevScreen());
      await scrollAndTap(tester, find.text('Reset mock data'));
      expect(find.text('Reset mock data?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.active);

      await scrollAndTap(tester, find.text('Reset mock data'));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.signedOut);
      expect(t.territory.hasData, isFalse);
      expect(t.read(syncStateProvider).records, isEmpty);
    });

    testWidgets('shows the mock logins', (tester) async {
      await pumpFaScreen(tester, const DevScreen());
      await tester.scrollUntilVisible(
        find.text('FA-KDP-014 / orbit2026'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('FA-KDP-014 / orbit2026'), findsOneWidget);
    });
  });
}
