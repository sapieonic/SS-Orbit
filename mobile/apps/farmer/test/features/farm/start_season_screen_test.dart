import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/farm/start_season_screen.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'farm_test_support.dart';

void main() {
  /// A new plot without a season (Ravi's seeded plot has one).
  Future<Plot> newPlot(ProviderContainer container) => container
      .read(farmerProfileRepositoryProvider)
      .addPlot(pin: kondapurPin, areaAcres: 2);

  Future<Season?> activeSeason(ProviderContainer c, String plotId) async {
    final home = await c.read(farmerProfileRepositoryProvider).getHome();
    return home.plots.firstWhere((p) => p.plot.id == plotId).activeSeason;
  }

  /// The season of [plotId] in the Home the app has loaded (what My farm
  /// shows), as opposed to the server's.
  Future<String?> cachedSeasonCode(ProviderContainer c, String plotId) async {
    final home = await c.read(farmerHomeProvider.future);
    return home.plots
        .firstWhere((p) => p.plot.id == plotId)
        .activeSeason
        ?.seasonCode;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(orbitButton(te.commonNext));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(orbitButton(te.farmerFarmStartSeason));
    await tester.pumpAndSettle();
  }

  /// Season (current), cotton, not sown, no previous crop.
  Future<void> answerAll(WidgetTester tester) async {
    await next(tester);
    await tester.tap(find.text('పత్తి'));
    await tester.pumpAndSettle();
    await next(tester);
    await next(tester);
  }

  testWidgets('starts a season with a crop and a sowing date', (tester) async {
    final container = await createTestContainer();
    final plot = await newPlot(container);
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.startSeason(plot.id),
    );

    // Step 1: the open seasons; today's (rabi 2026-27) is chosen and marked.
    expect(find.textContaining('పొలం 2'), findsOneWidget);
    expect(find.text(te.farmerSeasonStartWhichSeason), findsOneWidget);
    expect(find.text('ఖరీఫ్ 2026'), findsOneWidget);
    expect(find.text('రబీ 2026-27'), findsOneWidget);
    expect(find.text('వేసవి 2027'), findsOneWidget);
    expect(find.text(te.farmerSeasonStartCurrent), findsOneWidget);
    await next(tester);

    // Step 2: a crop is needed to go on.
    expect(find.text(te.farmerSeasonStartWhichCrop), findsOneWidget);
    expect(
      tester.widget<OrbitButton>(orbitButton(te.commonNext)).onPressed,
      isNull,
    );
    await tester.tap(find.text('పత్తి'));
    await tester.pumpAndSettle();
    await next(tester);

    // Step 3: sowing date from the picker; no future days.
    expect(find.text(te.farmerSeasonStartSowingDate), findsOneWidget);
    await tester.tap(find.text(te.commonChoose));
    await tester.pumpAndSettle();
    final picker = find.byType(DatePickerDialog);
    expect(picker, findsOneWidget);
    final material = MaterialLocalizations.of(tester.element(picker));
    // 1 Nov is today; 2 Nov is in the future and cannot be picked.
    await tester.tap(find.descendant(of: picker, matching: find.text('2')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: picker, matching: find.text('1')));
    await tester.tap(find.text(material.okButtonLabel));
    await tester.pumpAndSettle();
    expect(
      find.text(te.commonDateFull(date: DateTime.utc(2026, 11))),
      findsOneWidget,
    );
    await next(tester);

    // Step 4: previous crop, then start.
    expect(find.text(te.farmerSeasonStartPreviousCrop), findsOneWidget);
    await tester.tap(find.text('వరి'));
    await tester.pumpAndSettle();
    await submit(tester);

    expect(currentPath(router), Routes.farm);
    expect(find.text(te.farmerSeasonStartStarted), findsOneWidget);
    final season = await activeSeason(container, plot.id);
    expect(season, isNotNull);
    expect(season!.seasonCode, 'rabi-2026-27');
    expect(season.sowingDate, LocalDate(2026, 11, 1));
    final crops = await container.read(mastersRepositoryProvider).listCrops();
    expect(crops.byId(season.cropId)!.code, 'cotton');
    expect(crops.byId(season.previousCropId!)!.code, 'paddy');

    // My farm refreshed: plot 2 now shows the season it started.
    expect(await cachedSeasonCode(container, plot.id), 'rabi-2026-27');
    await tester.scrollUntilVisible(
      find.textContaining('రబీ 2026-27'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  });

  testWidgets('another season and "not sown, don\'t know" are optional', (
    tester,
  ) async {
    final container = await createTestContainer();
    final plot = await newPlot(container);
    await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.startSeason(plot.id),
    );
    await tester.tap(find.text('ఖరీఫ్ 2026'));
    await tester.pumpAndSettle();
    await next(tester);
    await tester.tap(find.text('మిరప'));
    await tester.pumpAndSettle();
    await next(tester);
    expect(find.text(te.farmerSeasonStartNotSown), findsOneWidget);
    await next(tester);
    await submit(tester);

    final season = await activeSeason(container, plot.id);
    expect(season!.seasonCode, 'kharif-2026');
    expect(season.sowingDate, isNull);
    expect(season.previousCropId, isNull);
  });

  testWidgets('active_season_exists goes back to My farm with the reason', (
    tester,
  ) async {
    final container = await createTestContainer();
    final plot = await newPlot(container);
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.startSeason(plot.id),
    );
    // Someone (the FA) starts a season while the farmer is answering.
    final crops = await container.read(mastersRepositoryProvider).listCrops();
    await container
        .read(farmerProfileRepositoryProvider)
        .startSeason(
          plotId: plot.id,
          seasonCode: crops.seasonCodes.current,
          cropId: crops.items.first.id,
        );

    expect(await cachedSeasonCode(container, plot.id), isNull);

    await answerAll(tester);
    await submit(tester);

    expect(currentPath(router), Routes.farm);
    expect(find.text(te.errorActiveSeasonExists), findsOneWidget);
    // My farm refreshed: it shows the season someone else started.
    expect(
      await cachedSeasonCode(container, plot.id),
      crops.seasonCodes.current,
    );
  });

  testWidgets('leaving while it saves still refreshes My farm', (tester) async {
    final backend = testBackend();
    final container = await createTestContainer(backend: backend);
    final plot = await newPlot(container);
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.startSeason(plot.id),
    );
    await answerAll(tester);

    backend.latency = const Duration(milliseconds: 300);
    await tester.tap(orbitButton(te.farmerFarmStartSeason));
    await tester.pump();
    // The My farm tab tapped again: back to its first screen, mid-save.
    router.go(Routes.farm);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    backend.latency = Duration.zero;

    expect(tester.takeException(), isNull);
    expect(await activeSeason(container, plot.id), isNotNull);
    expect(await cachedSeasonCode(container, plot.id), isNotNull);
  });

  testWidgets('a plot that already has a season shows one card', (
    tester,
  ) async {
    final container = await createTestContainer();
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.startSeason(raviPlotId),
    );
    expect(find.text(te.errorActiveSeasonExists), findsOneWidget);
    await tester.tap(orbitButton(te.commonBack));
    await tester.pumpAndSettle();
    expect(currentPath(router), Routes.farm);
  });

  testWidgets('offline shows the offline card', (tester) async {
    final container = await createTestContainer(scenario: MockScenario.offline);
    await pumpScreen(
      tester,
      const StartSeasonScreen(plotId: raviPlotId),
      container: container,
    );
    expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
  });

  testWidgets('renders in English', (tester) async {
    final container = await createTestContainer();
    final plot = await newPlot(container);
    await pumpScreen(
      tester,
      StartSeasonScreen(plotId: plot.id),
      container: container,
      locale: const Locale('en'),
    );
    expect(find.text(en.farmerSeasonStartTitle), findsOneWidget);
    expect(find.text('Rabi 2026-27'), findsOneWidget);
    await tester.tap(orbitButton(en.commonNext));
    await tester.pumpAndSettle();
    expect(find.text('Cotton'), findsOneWidget);
    expectCleanLayout(tester);
  });

  for (final scale in textScales) {
    testWidgets('every step fits 360x640 at text scale $scale', (tester) async {
      final container = await createTestContainer();
      final plot = await newPlot(container);
      await pumpScreen(
        tester,
        StartSeasonScreen(plotId: plot.id),
        container: container,
        textScale: scale,
      );
      expectCleanLayout(tester);
      await next(tester);
      expectCleanLayout(tester);
      await tester.ensureVisible(find.text('పత్తి'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('పత్తి'));
      await tester.pumpAndSettle();
      await next(tester);
      expect(find.text(te.farmerSeasonStartSowingDate), findsOneWidget);
      expectCleanLayout(tester);
      await next(tester);
      expect(find.text(te.farmerSeasonStartPreviousCrop), findsOneWidget);
      expectCleanLayout(tester);
    });
  }
}
