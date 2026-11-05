import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/alerts/alert_card.dart';
import 'package:fa/src/features/alerts/alerts_data.dart';
import 'package:fa/src/features/alerts/alerts_screen.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

SnapAlert _alertOf(FaTest t, AlertKind kind, {String? farmerId}) =>
    t.territory.alerts.firstWhere(
      (a) =>
          a.kind == kind &&
          a.status == AlertStatus.open &&
          (farmerId == null || a.farmerId == farmerId),
    );

Finder _card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(AlertCard));

/// Lets the engine's debounced nudge after an action run (or skip).
Future<void> _settleNudge(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  group('AlertsScreen', () {
    testWidgets('open alerts newest first, Telugu titles, invoices hidden', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const AlertsScreen());
      expect(t.territory.openAlertCount, 3);
      expect(find.text(te.faAlertsSubtitle(count: 3)), findsOneWidget);

      final raju = find.text('రాజు పి చేరారు · కొండాపూర్');
      final ravi = find.text('రవి కె మీకు కాల్ చేయమని అడిగారు');
      // English-only HO note falls back to English.
      final note = find.text('Pending enrolments');
      expect(raju, findsOneWidget);
      expect(ravi, findsOneWidget);
      expect(note, findsOneWidget);
      expect(tester.getTopLeft(raju).dy, lessThan(tester.getTopLeft(ravi).dy));
      expect(tester.getTopLeft(ravi).dy, lessThan(tester.getTopLeft(note).dy));
      expect(find.textContaining('బిల్లు తనిఖీ'), findsNothing);
      expect(find.textContaining('Invoice'), findsNothing);
      expect(statusPill(te.faAlertsKindNewFarmer), findsOneWidget);
      expect(findLabel(te.commonMinutesAgo(count: 10)), findsOneWidget);
    });

    testWidgets('filter chips show counts and filter by kind', (tester) async {
      await pumpFaScreen(tester, const AlertsScreen());
      expect(find.textContaining(te.faAlertsTabCallbacks), findsOneWidget);
      await tester.tap(find.textContaining(te.faAlertsTabCallbacks));
      await tester.pumpAndSettle();
      expect(find.text('రవి కె మీకు కాల్ చేయమని అడిగారు'), findsOneWidget);
      expect(find.text('రాజు పి చేరారు · కొండాపూర్'), findsNothing);
      expect(find.text('Pending enrolments'), findsNothing);

      // The last chip is past the edge: the row scrolls sideways.
      await tester.ensureVisible(find.textContaining(te.faAlertsTabHo));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(te.faAlertsTabHo));
      await tester.pumpAndSettle();
      expect(find.text('Pending enrolments'), findsOneWidget);
      expect(find.text('రవి కె మీకు కాల్ చేయమని అడిగారు'), findsNothing);
    });

    testWidgets('Finish enrolment opens enrolment with phone and alert', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const AlertsScreen());
      final alert = _alertOf(t, AlertKind.newFarmer);
      await tester.tap(orbitButton(te.faAlertsFinishEnrolment));
      await tester.pumpAndSettle();
      expect(
        currentLocation(t.router),
        AppRoutes.enrolFarmer(phone: '9123456780', alertId: alert.id),
      );
    });

    testWidgets('a sign-up outside the territory: call him from the list', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const AlertsScreen());
      // Raju P is not Suresh's yet: his phone comes from the online list.
      await tester.tap(orbitButton(te.commonCallName(name: 'Raju P')));
      await tester.pumpAndSettle();
      expect(t.launcher.calls, [MockBackend.rajuPhone]);
      expect(orbitButton(te.faAlertsCallPlanVisit), findsNothing);
    });

    testWidgets('Call · plan visit dials, then opens plan visit', (
      tester,
    ) async {
      final t = await createFaTest();
      t.backend.addAlert(
        kind: AlertKind.newFarmer,
        title: 'Lakshmi N joined · Kondapur',
        titleTe: 'లక్ష్మి ఎన్ చేరారు · కొండాపూర్',
        farmerId: MockBackend.lakshmiId,
        refId: MockBackend.lakshmiId,
      );
      await t.read(syncEngineProvider).syncNow();
      await pumpFaScreen(tester, const AlertsScreen(), test: t);
      await tester.tap(orbitButton(te.faAlertsCallPlanVisit));
      await tester.pumpAndSettle();
      expect(t.launcher.calls, [MockBackend.lakshmiPhone]);
      expect(
        currentLocation(t.router),
        AppRoutes.planVisit(farmerId: MockBackend.lakshmiId),
      );
    });

    testWidgets('a new farmer with no crop yet: Call, not Call · plan visit', (
      tester,
    ) async {
      final t = await createFaTest();
      final id = await t
          .read(faActionsProvider)
          .enrolFarmer(
            phone: '9876500021',
            name: 'Mahesh B',
            language: Language.te,
            villageId: MockBackend.kondapurId,
          );
      await t.read(syncEngineProvider).syncNow();
      t.backend.addAlert(
        kind: AlertKind.newFarmer,
        title: 'Mahesh B joined · Kondapur',
        titleTe: 'మహేష్ బి చేరారు · కొండాపూర్',
        farmerId: id,
        refId: id,
      );
      await t.read(syncEngineProvider).syncNow();
      final row = t.territory.farmerRow(id)!;
      expect(row.plots, isEmpty);
      await pumpFaScreen(tester, const AlertsScreen(), test: t);
      final card = _card('మహేష్ బి చేరారు · కొండాపూర్');
      expect(card, findsOneWidget);
      // Plan a visit needs a crop: it would only say "no crop".
      expect(
        find.descendant(
          of: card,
          matching: orbitButton(te.faAlertsCallPlanVisit),
        ),
        findsNothing,
      );
      final call = find.descendant(
        of: card,
        matching: orbitButton(te.commonCallName(name: 'Mahesh B')),
      );
      expect(call, findsOneWidget);
      await tester.tap(call);
      await tester.pumpAndSettle();
      expect(t.launcher.calls, ['+919876500021']);
      expect(currentPath(t.router), '/screen');
      await _settleNudge(tester);
    });

    testWidgets('call-back: call, then close it (CloseCallback)', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const AlertsScreen());
      final alert = _alertOf(
        t,
        AlertKind.callback,
        farmerId: MockBackend.raviId,
      );
      expect(find.text(te.faAlertsCallbackHint), findsOneWidget);
      expect(orbitButton(te.faAlertsCloseCallback), findsNothing);

      await scrollAndTap(
        tester,
        orbitButton(te.commonCallName(name: 'రవి కె')),
      );
      expect(t.launcher.calls, [MockBackend.raviPhone]);
      expect(find.text(te.faAlertsCloseCallbackHint), findsOneWidget);

      await scrollAndTap(tester, orbitButton(te.faAlertsCloseCallback));
      final entry = t.read(syncStateProvider).records.last;
      expect(entry.type, CommandType.closeCallback);
      expect(entry.entityId, alert.refId);
      expect(t.territory.callback(alert.refId!), isNull);
      // Stays in place with its confirmation.
      expect(find.text(te.faAlertsCallbackClosed), findsOneWidget);
      expect(find.text('రవి కె మీకు కాల్ చేయమని అడిగారు'), findsOneWidget);
      expect(find.text(te.faAlertsSubtitle(count: 2)), findsOneWidget);
      await _settleNudge(tester);
    });

    testWidgets('HO note: Got it acknowledges (AckAlert)', (tester) async {
      final t = await pumpFaScreen(tester, const AlertsScreen());
      t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
      await tester.pumpAndSettle();
      final alert = _alertOf(t, AlertKind.hoNote);
      await scrollAndTap(tester, orbitButton(te.faAlertsGotIt));

      expect(t.territory.alert(alert.id)!.status, AlertStatus.acknowledged);
      final entry = t.read(syncStateProvider).records.last;
      expect(entry.type, CommandType.ackAlert);
      expect(entry.entityId, alert.id);
      expect(find.text(te.faAlertsAcknowledged), findsOneWidget);
      expect(findLabel(te.faCommonNotSynced), findsOneWidget);
      expect(orbitButton(te.faAlertsGotIt), findsNothing);
      await _settleNudge(tester);
    });

    testWidgets('Earlier is collapsed and opens on tap', (tester) async {
      await pumpFaScreen(tester, const AlertsScreen());
      // Padma S's call-back and the review meeting note are acknowledged;
      // 7 closed ones come from the online list loaded on open.
      final header = find.text(te.faAlertsEarlier(count: 9));
      await tester.scrollUntilVisible(
        header,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('సమీక్ష సమావేశం'), findsNothing);
      await tester.tap(header);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('సమీక్ష సమావేశం'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('సమీక్ష సమావేశం'), findsOneWidget);
    });

    testWidgets('pull to refresh syncs and adds closed alerts to Earlier', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const AlertsScreen());
      t.backend.addAlert(title: 'Fresh note', body: 'Sent just now.');
      await tester.fling(
        find.byType(AlertCard).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh note'), findsOneWidget);
      expect(t.read(alertsHistoryProvider), isNotEmpty);
      // 2 acknowledged in the snapshot + 7 closed from the online list.
      await tester.scrollUntilVisible(
        find.text(te.faAlertsEarlier(count: 9)),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(te.faAlertsEarlier(count: 9)), findsOneWidget);
    });

    testWidgets('offline: banner, and pull says there is no internet', (
      tester,
    ) async {
      final t = await pumpFaScreen(tester, const AlertsScreen());
      t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
      await tester.pumpAndSettle();
      expect(find.text(te.faAlertsOfflineBody), findsOneWidget);
      expect(find.text('రాజు పి చేరారు · కొండాపూర్'), findsOneWidget);
      await tester.fling(
        find.byType(AlertCard).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text(te.errorNetwork), findsOneWidget);
    });

    testWidgets('empty state before any alerts are on the phone', (
      tester,
    ) async {
      await pumpFaScreen(tester, const AlertsScreen(), signedIn: false);
      expect(find.text(te.faAlertsEmptyTitle), findsOneWidget);
      expect(find.text(te.faAlertsEmptyBody), findsOneWidget);
      expect(find.byType(AlertCard), findsNothing);
    });

    testWidgets('English UI shows English titles', (tester) async {
      await pumpFaScreen(
        tester,
        const AlertsScreen(),
        locale: const Locale('en'),
      );
      expect(find.text('Raju P joined · Kondapur'), findsOneWidget);
      expect(find.text(en.faAlertsSubtitle(count: 3)), findsOneWidget);
      expect(orbitButton(en.faAlertsFinishEnrolment), findsOneWidget);
      expect(orbitButton(en.commonCallName(name: 'Ravi K')), findsOneWidget);
      expect(_card('Raju P joined · Kondapur'), findsOneWidget);
    });

    testWidgets('buttons are at least 48 dp tall', (tester) async {
      await pumpFaScreen(tester, const AlertsScreen());
      for (final e in find.byType(OrbitButton).evaluate()) {
        expect(e.size!.height, greaterThanOrEqualTo(48));
      }
    });

    screenLayoutTest('Alerts', () => const AlertsScreen());
    screenLayoutTest(
      'Alerts with Earlier open',
      () => const AlertsScreen(),
      after: (tester, t) async {
        final header = find.text(te.faAlertsEarlier(count: 9));
        await tester.scrollUntilVisible(
          header,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(header);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
        await tester.pumpAndSettle();
      },
    );
  });
}
