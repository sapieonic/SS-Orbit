import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/alerts/alerts_screen.dart';
import 'package:fa/src/features/auth/unlock_screen.dart';
import 'package:fa/src/features/calendar/calendar_screen.dart';
import 'package:fa/src/features/calendar/plan_visit_screen.dart';
import 'package:fa/src/features/enrol/enrol_crop_screen.dart';
import 'package:fa/src/features/enrol/enrol_farmer_screen.dart';
import 'package:fa/src/features/farmer360/farmer360_screen.dart';
import 'package:fa/src/features/farmers/farmers_screen.dart';
import 'package:fa/src/features/me/me_screen.dart';
import 'package:fa/src/features/sync/sync_screen.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/app_lifecycle.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:fa/src/shared/fa_header.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../support/harness.dart';

OrbitNavigationBar _bar(WidgetTester tester) =>
    tester.widget<OrbitNavigationBar>(find.byType(OrbitNavigationBar));

void main() {
  group('tabs', () {
    testWidgets('each tab opens its root; the bar marks it', (tester) async {
      final t = await pumpFaApp(tester);
      for (final (label, path, type, index) in [
        (te.faNavCalendar, AppRoutes.calendar, CalendarScreen, 1),
        (te.faNavAlerts, AppRoutes.alerts, AlertsScreen, 3),
        (te.faNavFarmers, AppRoutes.farmers, FarmersScreen, 0),
      ]) {
        await tester.tap(navTab(label));
        await tester.pumpAndSettle();
        expect(currentPath(t.router), path);
        expect(find.byType(type), findsOneWidget);
        expect(_bar(tester).selectedIndex, index);
      }
      // Enrol fills the screen (A4a has no bar); back returns to Farmers.
      await tester.tap(navTab(te.faNavEnrol));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.enrol);
      expect(find.byType(EnrolFarmerScreen), findsOneWidget);
      expect(find.byType(OrbitNavigationBar), findsNothing);
      await systemBack(tester);
      expect(currentPath(t.router), AppRoutes.farmers);
    });

    testWidgets('the Enrol tab always opens a fresh step 1', (tester) async {
      final t = await pumpFaApp(tester);
      await tester.tap(navTab(te.faNavEnrol));
      await tester.pumpAndSettle();
      final first = tester.state(find.byType(EnrolFarmerScreen));

      // Step 3 done ("Enrolled"), then back to Farmers.
      t.router.go(AppRoutes.enrolCrop('f1', plotId: 'p1'));
      await tester.pumpAndSettle();
      expect(find.byType(EnrolCropScreen), findsOneWidget);
      t.router.go(AppRoutes.farmers);
      await tester.pumpAndSettle();

      await tester.tap(navTab(te.faNavEnrol));
      await tester.pumpAndSettle();
      expect(currentLocation(t.router), AppRoutes.enrol);
      expect(find.byType(EnrolCropScreen), findsNothing);
      expect(
        tester.state(find.byType(EnrolFarmerScreen)),
        isNot(same(first)),
        reason: 'a new step 1, not the last enrolment\'s',
      );
    });

    testWidgets('tabs keep their stacks', (tester) async {
      final t = await pumpFaApp(tester);
      t.router.go(AppRoutes.farmer('f1'));
      await tester.pumpAndSettle();
      expect(find.byType(Farmer360Screen), findsOneWidget);
      // Inner pages fill the screen.
      expect(find.byType(OrbitNavigationBar), findsNothing);

      // Links to other tabs (Farmer 360's "Plan visit", an alert).
      t.router.go(AppRoutes.planVisit(farmerId: 'f1'));
      await tester.pumpAndSettle();
      expect(find.byType(PlanVisitScreen), findsOneWidget);
      t.router.go(AppRoutes.alerts);
      await tester.pumpAndSettle();

      // Back on Farmers, Farmer 360 is still open where it was.
      await tester.tap(navTab(te.faNavFarmers));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.farmer('f1'));
      await systemBack(tester);
      expect(currentPath(t.router), AppRoutes.farmers);

      // Calendar kept Plan visit open too.
      await tester.tap(navTab(te.faNavCalendar));
      await tester.pumpAndSettle();
      expect(currentLocation(t.router), AppRoutes.planVisit(farmerId: 'f1'));
      await systemBack(tester);
      expect(currentPath(t.router), AppRoutes.calendar);
      expect(_bar(tester).selectedIndex, 1);
    });

    testWidgets(
      'Android back at another tab root goes to Farmers, then exits',
      (tester) async {
        final t = await pumpFaApp(tester);
        final calls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            calls.add(call.method);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.tap(navTab(te.faNavAlerts));
        await tester.pumpAndSettle();
        await systemBack(tester);
        expect(currentPath(t.router), AppRoutes.farmers);
        expect(calls, isNot(contains('SystemNavigator.pop')));
        await systemBack(tester);
        expect(calls, contains('SystemNavigator.pop'));
      },
    );
  });

  group('badges and the header', () {
    testWidgets('the Alerts badge counts open alerts', (tester) async {
      final t = await pumpFaApp(tester);
      final open = t.territory.openAlertCount;
      expect(open, greaterThan(0), reason: 'the seed has open alerts');
      final alerts = _bar(tester).destinations[3];
      expect(alerts.badge, '$open');
    });

    testWidgets('the sync pill opens Sync over the tabs and reads its count', (
      tester,
    ) async {
      final t = await pumpFaApp(tester);
      expect(find.byType(SyncPill), findsOneWidget);
      final queued = t.read(syncStateProvider).queuedCount;
      expect(
        find.bySemanticsLabel(
          queued == 0
              ? te.faShellSyncAllSynced
              : te.faShellSyncWaiting(count: queued),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(SyncPill));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.sync);
      expect(find.byType(SyncScreen), findsOneWidget);
      expect(find.byType(OrbitNavigationBar), findsNothing);
      await systemBack(tester);
      expect(currentPath(t.router), AppRoutes.farmers);
    });

    testWidgets("the Me avatar shows Suresh's initials and opens Me", (
      tester,
    ) async {
      final t = await pumpFaApp(tester);
      // Scoped to the header: a seeded farmer in the list is an "SK" too.
      expect(
        find.descendant(of: find.byType(MeAvatar), matching: find.text('SK')),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel(te.faShellMe));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.me);
      expect(find.byType(MeScreen), findsOneWidget);
    });

    testWidgets('fits 360x640 at text scale 1.3', (tester) async {
      await pumpFaApp(tester, textScale: 1.3);
      expectCleanLayout(tester);
    });
  });

  group('lifecycle', () {
    testWidgets('a pause over 5 minutes locks; a short one does not', (
      tester,
    ) async {
      final t = await pumpFaApp(tester);
      final lifecycle = t.read(appLifecycleProvider);

      lifecycle.onBackground();
      testClock.advance(const Duration(minutes: 4));
      lifecycle.onForeground();
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.active);

      lifecycle.onBackground();
      testClock.advance(autoLockAfter + const Duration(seconds: 1));
      lifecycle.onForeground();
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.locked);
      // The PIN screen covers Farmers, which stays where it was.
      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(currentPath(t.router), AppRoutes.farmers);
    });

    testWidgets('the app lifecycle reaches it', (tester) async {
      final t = await pumpFaApp(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      testClock.advance(const Duration(minutes: 6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.locked);
    });

    testWidgets('resume runs the heartbeat: a removed phone is wiped', (
      tester,
    ) async {
      final t = await pumpFaApp(tester);
      final lifecycle = t.read(appLifecycleProvider);
      lifecycle.onBackground();
      t.backend.scenario = MockScenario.deviceRemoved;
      lifecycle.onForeground();
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.removed);
      expect(currentPath(t.router), AppRoutes.removed);
    });
  });
}
