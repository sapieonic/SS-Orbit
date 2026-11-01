import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/farm/add_plot_screen.dart';
import 'package:farmer/src/features/farm/close_season_screen.dart';
import 'package:farmer/src/features/farm/start_season_screen.dart';
import 'package:farmer/src/features/home/home_screen.dart';
import 'package:farmer/src/features/visits/advice_screen.dart';
import 'package:farmer/src/routing/router.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../features/farm/farm_test_support.dart';
import '../support/harness.dart';

void main() {
  group('redirectFor', () {
    test('each sign-in phase owns exactly one screen', () {
      expect(redirectFor(SessionPhase.restoring, Routes.home), Routes.splash);
      expect(redirectFor(SessionPhase.signedOut, Routes.home), Routes.login);
      expect(redirectFor(SessionPhase.otpSent, Routes.login), Routes.otp);
      expect(
        redirectFor(SessionPhase.needsConsent, Routes.otp),
        Routes.consent,
      );
      expect(
        redirectFor(SessionPhase.needsVillage, Routes.consent),
        Routes.village,
      );
      expect(redirectFor(SessionPhase.needsName, Routes.village), Routes.name);
      expect(redirectFor(SessionPhase.inactive, Routes.farm), Routes.paused);
      expect(redirectFor(SessionPhase.signedOut, Routes.login), isNull);
    });

    test('an active farmer leaves sign-in screens and moves freely', () {
      for (final path in Routes.signInPaths) {
        expect(redirectFor(SessionPhase.active, path), Routes.home);
      }
      expect(redirectFor(SessionPhase.active, Routes.fas), isNull);
      expect(redirectFor(SessionPhase.active, Routes.notice('n1')), isNull);
    });

    test('the dev menu is reachable in every phase', () {
      for (final phase in SessionPhase.values) {
        expect(redirectFor(phase, Routes.dev), isNull);
      }
    });
  });

  testWidgets('signed-out start lands on the login screen', (tester) async {
    final container = await createTestContainer(signedIn: false);
    await pumpFarmerApp(tester, container: container);
    expect(currentPath(container.read(routerProvider)), Routes.login);
  });

  testWidgets('a signed-in farmer lands on Home with the bottom bar', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);
    final router = container.read(routerProvider);
    expect(currentPath(router), Routes.home);
    expect(find.byType(HomeScreen), findsOneWidget);
    final bar = tester.widget<OrbitNavigationBar>(
      find.byType(OrbitNavigationBar),
    );
    expect(bar.destinations.map((d) => d.label), [
      te.farmerNavHome,
      te.farmerNavVisits,
      te.farmerNavAdvisory,
      te.farmerNavFarm,
    ]);
    expect(bar.selectedIndex, 0);
  });

  group('the app router', () {
    testWidgets('opens the My farm screens at their paths', (tester) async {
      final container = await createTestContainer();
      await pumpFarmerApp(tester, container: container);
      final router = container.read(routerProvider);

      router.go(Routes.addPlot);
      await tester.pumpAndSettle();
      expect(currentPath(router), Routes.addPlot);
      expect(find.byType(AddPlotScreen), findsOneWidget);

      router.go(Routes.startSeason(raviPlotId));
      await tester.pumpAndSettle();
      expect(
        tester.widget<StartSeasonScreen>(find.byType(StartSeasonScreen)).plotId,
        raviPlotId,
      );

      router.go(Routes.closeSeason(raviSeasonId));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CloseSeasonScreen>(find.byType(CloseSeasonScreen))
            .seasonId,
        raviSeasonId,
      );
      expect(find.text(te.farmerSeasonCloseQuestion), findsOneWidget);
      // On the My farm tab, with the bottom bar.
      expect(
        tester
            .widget<OrbitNavigationBar>(find.byType(OrbitNavigationBar))
            .selectedIndex,
        3,
      );
    });

    testWidgets('an issue index that is not a number is not found', (
      tester,
    ) async {
      final container = await createTestContainer();
      await pumpFarmerApp(tester, container: container);
      final visits = await container
          .read(visitsRepositoryProvider)
          .listVisits();
      final router = container.read(routerProvider)
        ..go('/visits/${visits.items.first.id}/issues/abc');
      await tester.pumpAndSettle();

      expect(
        currentPath(router),
        '/visits/${visits.items.first.id}/issues/abc',
      );
      expect(
        tester.widget<AdviceScreen>(find.byType(AdviceScreen)).issueIndex,
        isNegative,
      );
      expect(find.text(te.errorNotFound), findsOneWidget);
    });
  });
}
