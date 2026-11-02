import 'dart:async';

import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/auth/change_password_screen.dart';
import 'package:fa/src/features/auth/login_screen.dart';
import 'package:fa/src/features/auth/setup_screen.dart';
import 'package:fa/src/features/auth/unlock_screen.dart';
import 'package:fa/src/features/blocked/removed_screen.dart';
import 'package:fa/src/features/blocked/update_required_screen.dart';
import 'package:fa/src/features/calendar/plan_visit_screen.dart';
import 'package:fa/src/features/enrol/enrol_crop_screen.dart';
import 'package:fa/src/features/enrol/enrol_farmer_screen.dart';
import 'package:fa/src/features/enrol/enrol_plot_screen.dart';
import 'package:fa/src/features/farmer360/farmer360_screen.dart';
import 'package:fa/src/features/farmers/farmers_screen.dart';
import 'package:fa/src/features/visit_log/visit_log_screen.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/router.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../support/harness.dart';

void main() {
  group('AppRoutes', () {
    test('helpers build paths and queries, leaving out empty values', () {
      expect(AppRoutes.farmer('f 1'), '/farmers/f%201');
      expect(AppRoutes.planVisit(), '/calendar/plan');
      expect(AppRoutes.planVisit(farmerId: 'f1'), '/calendar/plan?farmerId=f1');
      expect(
        AppRoutes.visit(farmerId: 'f1', visitId: 'v1', plotId: ''),
        '/visit?farmerId=f1&visitId=v1',
      );
      expect(AppRoutes.enrolFarmer(), '/enrol');
      expect(
        AppRoutes.enrolFarmer(phone: '+919000000101', alertId: 'a1'),
        '/enrol?phone=%2B919000000101&alertId=a1',
      );
      expect(AppRoutes.farmersFiltered(FarmerFilter.all), '/farmers');
      expect(
        AppRoutes.farmersFiltered(FarmerFilter.visitDue),
        '/farmers?filter=visit_due',
      );
      for (final f in FarmerFilter.values) {
        expect(
          AppRoutes.farmerFilterFromWire(AppRoutes.farmerFilterWire(f)),
          f,
        );
      }
      expect(AppRoutes.farmerFilterFromWire(null), isNull);
      expect(AppRoutes.farmerFilterFromWire('soon'), isNull);
      expect(AppRoutes.enrolPlot('f1'), '/enrol/f1/plot');
      expect(
        AppRoutes.enrolCrop('f1', plotId: 'p1'),
        '/enrol/f1/crop?plotId=p1',
      );
    });
  });

  group('redirectFor', () {
    String? at(SessionPhase phase, String location, {bool devMenu = true}) =>
        redirectFor(phase, location, devMenu: devMenu);

    test('each phase before active owns exactly one page', () {
      final expected = {
        SessionPhase.restoring: AppRoutes.splash,
        SessionPhase.signedOut: AppRoutes.login,
        SessionPhase.passwordNeeded: AppRoutes.login,
        SessionPhase.mustChangePassword: AppRoutes.changePassword,
        SessionPhase.setup: AppRoutes.setup,
        SessionPhase.locked: AppRoutes.unlock,
        SessionPhase.updateRequired: AppRoutes.updateRequired,
        SessionPhase.removed: AppRoutes.removed,
      };
      for (final MapEntry(key: phase, value: page) in expected.entries) {
        expect(at(phase, AppRoutes.farmers), page, reason: '$phase');
        expect(at(phase, AppRoutes.farmer('f1')), page, reason: '$phase');
        expect(at(phase, page), isNull, reason: '$phase on its page');
      }
      expect(at(SessionPhase.locked, AppRoutes.login), AppRoutes.unlock);
    });

    test('an active FA leaves the entry pages and moves freely', () {
      for (final path in AppRoutes.entryPaths) {
        expect(at(SessionPhase.active, path), AppRoutes.farmers);
      }
      for (final location in [
        AppRoutes.farmers,
        AppRoutes.farmer('f1'),
        AppRoutes.visit(farmerId: 'f1', visitId: 'v1'),
        AppRoutes.enrolCrop('f1', plotId: 'p1'),
        AppRoutes.sync,
        AppRoutes.me,
      ]) {
        expect(at(SessionPhase.active, location), isNull, reason: location);
      }
      expect(
        redirectFor(
          SessionPhase.active,
          AppRoutes.unlock,
          devMenu: false,
          resumeTo: '/farmers/f1',
        ),
        '/farmers/f1',
      );
    });

    test('the dev menu: every phase in dev mock builds, nowhere else', () {
      for (final phase in SessionPhase.values) {
        expect(at(phase, AppRoutes.dev), isNull, reason: '$phase');
        expect(
          at(phase, AppRoutes.dev, devMenu: false),
          phaseLocation(phase) ?? AppRoutes.farmers,
          reason: '$phase',
        );
      }
    });

    test('dev builds on mock data have the menu', () {
      expect(devMenuEnabled(OrbitEnv.devMock), isTrue);
      expect(
        devMenuEnabled(
          const OrbitEnv(
            flavor: Flavor.dev,
            dataSource: DataSource.api,
            apiBaseUrl: OrbitEnv.devApiBaseUrl,
          ),
        ),
        isFalse,
      );
      expect(
        devMenuEnabled(
          const OrbitEnv(
            flavor: Flavor.prod,
            dataSource: DataSource.api,
            apiBaseUrl: OrbitEnv.prodApiBaseUrl,
          ),
        ),
        isFalse,
      );
    });
  });

  group('RedirectMemory', () {
    test('a deep link at start survives the PIN', () {
      final memory = RedirectMemory();
      final link = AppRoutes.visit(farmerId: 'f1', visitId: 'v1');
      String? go(SessionPhase phase, String location) =>
          memory.redirect(phase, location, devMenu: true);

      expect(go(SessionPhase.restoring, link), AppRoutes.splash);
      expect(go(SessionPhase.restoring, AppRoutes.splash), isNull);
      expect(go(SessionPhase.locked, AppRoutes.splash), AppRoutes.unlock);
      expect(go(SessionPhase.locked, AppRoutes.unlock), isNull);
      expect(go(SessionPhase.active, AppRoutes.unlock), link);
      expect(go(SessionPhase.active, link), isNull);
      expect(memory.held, isNull);
      // Used once: the next lock starts over.
      expect(go(SessionPhase.locked, AppRoutes.farmers), AppRoutes.unlock);
      expect(go(SessionPhase.active, AppRoutes.unlock), AppRoutes.farmers);
    });

    test('signing out forgets the page', () {
      final memory = RedirectMemory();
      memory.redirect(SessionPhase.locked, '/farmers/f1', devMenu: true);
      expect(memory.held, '/farmers/f1');
      memory.redirect(SessionPhase.signedOut, AppRoutes.unlock, devMenu: true);
      expect(memory.held, isNull);
      expect(
        memory.redirect(SessionPhase.active, AppRoutes.login, devMenu: true),
        AppRoutes.farmers,
      );
    });
  });

  group('the app router', () {
    testWidgets('each phase lands on its page', (tester) async {
      final pages = {
        SessionPhase.signedOut: LoginScreen,
        SessionPhase.passwordNeeded: LoginScreen,
        SessionPhase.mustChangePassword: ChangePasswordScreen,
        SessionPhase.setup: SetupScreen,
        SessionPhase.locked: UnlockScreen,
        SessionPhase.updateRequired: UpdateRequiredScreen,
        SessionPhase.removed: RemovedScreen,
      };
      for (final MapEntry(key: phase, value: type) in pages.entries) {
        final t = await pumpFaApp(tester, test: await createFaTestAt(phase));
        expect(currentPath(t.router), phaseLocation(phase), reason: '$phase');
        expect(find.byType(type), findsOneWidget, reason: '$phase');
        expect(find.byType(OrbitNavigationBar), findsNothing);
        // Not past the gate by a link either.
        t.router.go(AppRoutes.farmers);
        await tester.pumpAndSettle();
        expect(currentPath(t.router), phaseLocation(phase), reason: '$phase');
        // A fresh app for the next phase.
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('an active FA lands on Farmers with the bar', (tester) async {
      final t = await pumpFaApp(tester);
      expect(currentPath(t.router), AppRoutes.farmers);
      expect(find.byType(FarmersScreen), findsOneWidget);
      final bar = tester.widget<OrbitNavigationBar>(
        find.byType(OrbitNavigationBar),
      );
      expect(bar.destinations.map((d) => d.label), [
        te.faNavFarmers,
        te.faNavCalendar,
        te.faNavEnrol,
        te.faNavAlerts,
      ]);
      expect(bar.selectedIndex, 0);
    });

    testWidgets('signing in from the login page goes to Farmers', (
      tester,
    ) async {
      final t = await pumpFaApp(tester, signedIn: false);
      expect(currentPath(t.router), AppRoutes.login);
      await signInSuresh(t);
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.farmers);
    });

    testWidgets('opens every page with its parameters', (tester) async {
      final t = await pumpFaApp(tester);
      Future<T> open<T extends Widget>(String location) async {
        t.router.go(location);
        await tester.pumpAndSettle();
        expect(currentLocation(t.router), location);
        return tester.widget<T>(find.byType(T));
      }

      expect(
        (await open<FarmersScreen>(
          AppRoutes.farmersFiltered(FarmerFilter.notVisited30),
        )).filter,
        FarmerFilter.notVisited30,
      );
      expect(
        (await open<Farmer360Screen>(AppRoutes.farmer('f1'))).farmerId,
        'f1',
      );
      expect(
        (await open<PlanVisitScreen>(AppRoutes.planVisit(farmerId: 'f2')))
            .farmerId,
        'f2',
      );
      expect(
        (await open<PlanVisitScreen>(AppRoutes.planVisit())).farmerId,
        isNull,
      );
      final visit = await open<VisitLogScreen>(
        AppRoutes.visit(farmerId: 'f1', visitId: 'v1', plotId: 'p1'),
      );
      expect((visit.farmerId, visit.visitId, visit.plotId), ('f1', 'v1', 'p1'));
      final enrol = await open<EnrolFarmerScreen>(
        AppRoutes.enrolFarmer(phone: '9000000101', alertId: 'a1'),
      );
      expect((enrol.phone, enrol.alertId), ('9000000101', 'a1'));
      expect(
        (await open<EnrolPlotScreen>(AppRoutes.enrolPlot('f3'))).farmerId,
        'f3',
      );
      final crop = await open<EnrolCropScreen>(
        AppRoutes.enrolCrop('f3', plotId: 'p9'),
      );
      expect((crop.farmerId, crop.plotId), ('f3', 'p9'));
    });

    testWidgets('a filter link picks the chip on the open Farmers tab', (
      tester,
    ) async {
      final t = await pumpFaApp(tester);
      FilterChipsBar bar() =>
          tester.widget<FilterChipsBar>(find.byType(FilterChipsBar));
      expect(bar().selectedIndex, FarmerFilter.all.index);
      t.router.go(AppRoutes.calendar);
      await tester.pumpAndSettle();
      t.router.go(AppRoutes.farmersFiltered(FarmerFilter.visitDue));
      await tester.pumpAndSettle();
      expect(bar().selectedIndex, FarmerFilter.visitDue.index);
    });

    testWidgets('the lock covers the open page; unlocking keeps its state', (
      tester,
    ) async {
      final t = await pumpFaApp(tester);
      final link = AppRoutes.visit(farmerId: 'f1', visitId: 'v1');
      t.router.go(link);
      await tester.pumpAndSettle();
      final before = tester.state(find.byType(VisitLogScreen));

      t.read(sessionProvider.notifier).lock();
      await tester.pumpAndSettle();
      // The page stays (not on screen, not touchable, not read out) under
      // the PIN screen.
      expect(currentLocation(t.router), link);
      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(find.byType(VisitLogScreen), findsNothing);
      expect(find.byType(VisitLogScreen, skipOffstage: false), findsOneWidget);

      expect(await t.read(sessionProvider.notifier).unlock(testPin), isTrue);
      await tester.pumpAndSettle();
      expect(currentLocation(t.router), link);
      expect(find.byType(UnlockScreen), findsNothing);
      expect(
        identical(tester.state(find.byType(VisitLogScreen)), before),
        isTrue,
        reason: 'the same page, with what the FA had entered',
      );
    });

    testWidgets('back cannot pop a page under the lock', (tester) async {
      final t = await pumpFaApp(tester);
      unawaited(t.router.push(AppRoutes.farmer('f1')));
      await tester.pumpAndSettle();
      t.read(sessionProvider.notifier).lock();
      await tester.pumpAndSettle();

      await systemBack(tester);
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.farmer('f1'));
      expect(find.byType(UnlockScreen), findsOneWidget);
      expect(t.read(sessionProvider).phase, SessionPhase.locked);
    });

    testWidgets('"Use password instead" from the lock goes to the login', (
      tester,
    ) async {
      final t = await pumpFaApp(tester);
      t.read(sessionProvider.notifier).lock();
      await tester.pumpAndSettle();
      t.read(sessionProvider.notifier).usePassword();
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.login);
      expect(find.byType(UnlockScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a cold start that is locked shows the PIN page', (
      tester,
    ) async {
      final test = await createFaTestAt(SessionPhase.locked);
      final t = await pumpFaApp(tester, test: test);
      expect(currentPath(t.router), AppRoutes.unlock);
      expect(await t.read(sessionProvider.notifier).unlock(testPin), isTrue);
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.farmers);
    });

    testWidgets('the dev menu opens in dev mock builds', (tester) async {
      final t = await pumpFaApp(tester, signedIn: false);
      t.router.go(AppRoutes.dev);
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.dev);
    });
  });
}
