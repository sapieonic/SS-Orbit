import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/farm/close_season_screen.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'farm_test_support.dart';

void main() {
  Future<Season?> raviSeason(ProviderContainer c) async {
    final home = await c.read(farmerProfileRepositoryProvider).getHome();
    return home.plots.single.activeSeason;
  }

  testWidgets('harvested, then confirm: closes and goes back', (tester) async {
    final container = await createTestContainer();
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.closeSeason(raviSeasonId),
    );

    expect(find.text(te.farmerSeasonCloseQuestion), findsOneWidget);
    expect(find.text('పొలం 1 · పత్తి · ఖరీఫ్ 2026'), findsOneWidget);
    expect(find.text(te.farmerSeasonCloseNoUndo), findsOneWidget);
    final confirm = orbitButton(te.farmerFarmCloseSeason);
    expect(tester.widget<OrbitButton>(confirm).onPressed, isNull);

    await tester.tap(find.text(te.labelSeasonStatus('harvested')));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(currentPath(router), Routes.farm);
    expect(find.text(te.farmerSeasonCloseClosed), findsOneWidget);
    expect(await raviSeason(container), isNull);
    await tester.scrollUntilVisible(
      orbitButton(te.farmerFarmStartSeason),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(te.farmerFarmNoCrop), findsOneWidget);
  });

  testWidgets('back waits for the save; leaving still refreshes My farm', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await createTestContainer(backend: backend);
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.closeSeason(raviSeasonId),
    );
    await tester.tap(find.text(te.labelSeasonStatus('harvested')));
    await tester.pumpAndSettle();

    backend.latency = const Duration(milliseconds: 300);
    await tester.tap(orbitButton(te.farmerFarmCloseSeason));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(currentPath(router), Routes.closeSeason(raviSeasonId));

    // The My farm tab tapped again: back to its first screen, mid-save.
    router.go(Routes.farm);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    backend.latency = Duration.zero;

    expect(tester.takeException(), isNull);
    expect(await raviSeason(container), isNull);
    final home = await container.read(farmerHomeProvider.future);
    expect(home.plots.single.activeSeason, isNull, reason: 'Home refreshed');
    expect(find.text(te.farmerFarmNoCrop), findsOneWidget);
  });

  testWidgets('abandoned is sent as the outcome', (tester) async {
    final container = await createTestContainer();
    await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.closeSeason(raviSeasonId),
    );
    await tester.tap(find.text(te.labelSeasonStatus('abandoned')));
    await tester.pumpAndSettle();
    await tester.tap(orbitButton(te.farmerFarmCloseSeason));
    await tester.pumpAndSettle();

    // The closed season is no longer on Home; ask the repository directly.
    await expectLater(
      container
          .read(farmerProfileRepositoryProvider)
          .closeSeason(
            seasonId: raviSeasonId,
            outcome: SeasonOutcome.harvested,
          ),
      throwsA(
        isA<ApiError>().having(
          (e) => e.details['status'],
          'status',
          'abandoned',
        ),
      ),
    );
  });

  testWidgets('season_not_active goes back with the reason', (tester) async {
    final container = await createTestContainer();
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.closeSeason(raviSeasonId),
    );
    // Closed elsewhere (the FA app) while this screen was open.
    await container
        .read(farmerProfileRepositoryProvider)
        .closeSeason(seasonId: raviSeasonId, outcome: SeasonOutcome.harvested);

    await tester.tap(find.text(te.labelSeasonStatus('harvested')));
    await tester.pumpAndSettle();
    await tester.tap(orbitButton(te.farmerFarmCloseSeason));
    await tester.pumpAndSettle();

    expect(currentPath(router), Routes.farm);
    expect(find.text(te.errorSeasonNotActive), findsOneWidget);
    // My farm refreshed: no longer offers to close it.
    final home = await container.read(farmerHomeProvider.future);
    expect(home.plots.single.activeSeason, isNull);
    expect(find.text(te.farmerFarmNoCrop), findsOneWidget);
  });

  testWidgets('an unknown or closed season shows one card', (tester) async {
    final container = await createTestContainer();
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.closeSeason('gone'),
    );
    expect(find.text(te.errorSeasonNotActive), findsOneWidget);
    await tester.tap(orbitButton(te.commonBack));
    await tester.pumpAndSettle();
    expect(currentPath(router), Routes.farm);
  });

  testWidgets('offline shows the offline card', (tester) async {
    final container = await createTestContainer(scenario: MockScenario.offline);
    await pumpScreen(
      tester,
      const CloseSeasonScreen(seasonId: raviSeasonId),
      container: container,
    );
    expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
  });

  testWidgets('renders in English', (tester) async {
    final container = await createTestContainer();
    await pumpScreen(
      tester,
      const CloseSeasonScreen(seasonId: raviSeasonId),
      container: container,
      locale: const Locale('en'),
    );
    expect(find.text(en.farmerSeasonCloseQuestion), findsOneWidget);
    expect(find.text('Plot 1 · Cotton · Kharif 2026'), findsOneWidget);
    expect(find.text(en.labelSeasonStatus('harvested')), findsOneWidget);
    expectCleanLayout(tester);
  });

  screenLayoutTest(
    'CloseSeasonScreen',
    () => const CloseSeasonScreen(seasonId: raviSeasonId),
  );
  screenLayoutTest(
    'CloseSeasonScreen for a closed season',
    () => const CloseSeasonScreen(seasonId: 'gone'),
  );
}
