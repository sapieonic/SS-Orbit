import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/calendar/calendar_screen.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

void main() {
  /// Gives Ravi a second plot with paddy this season, sown on [sowingDate]
  /// (or with no sowing date).
  Future<void> addPaddyPlot(
    ProviderContainer container, {
    LocalDate? sowingDate,
  }) async {
    final profile = container.read(farmerProfileRepositoryProvider);
    final crops = await container.read(mastersRepositoryProvider).listCrops();
    final plot = await profile.addPlot(
      pin: const LatLng(17.46, 78.36),
      areaAcres: 1,
    );
    await profile.startSeason(
      plotId: plot.id,
      seasonCode: crops.seasonCodes.current,
      cropId: crops.items.firstWhere((c) => c.code == 'paddy').id,
      sowingDate: sowingDate,
    );
  }

  Future<GoRouter> pumpCalendar(
    WidgetTester tester,
    ProviderContainer container, {
    Locale locale = const Locale('te'),
    List<Override> overrides = const [],
  }) => pumpRouted(
    tester,
    container: container,
    path: Routes.calendar,
    screen: const CalendarScreen(),
    locale: locale,
    overrides: overrides,
  );

  group('CalendarScreen', () {
    testWidgets('cotton on day 123 of about 160, in the picking stage', (
      tester,
    ) async {
      await pumpCalendar(tester, await createTestContainer());

      expect(find.text(te.farmerCalendarTitle), findsOneWidget);
      expect(
        find.text('${te.farmerFarmPlot(number: 1)} · పత్తి'),
        findsOneWidget,
      );
      // Sown 1 Jul 2026; today is 1 Nov 2026.
      expect(
        find.text(te.farmerCalendarDayOf(day: 123, total: 160)),
        findsOneWidget,
      );
      expect(
        find.text(te.farmerFarmSownOn(date: DateTime.utc(2026, 7))),
        findsOneWidget,
      );
      expect(find.text('${te.farmerCalendarNow} · తీత దశ'), findsOneWidget);
      final strip = tester.widget<StageStrip>(find.byType(StageStrip));
      expect(strip.stages, [
        'మొలక దశ',
        'మొగ్గ దశ',
        'పూత దశ',
        'కాయ దశ',
        'తీత దశ',
      ]);
      expect(strip.currentIndex, 4);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(123 / 160, 1e-9));
      // Tasks are blocked on the calendar module.
      await tester.scrollUntilVisible(
        find.text(te.farmerCalendarTasksLater),
        200,
      );
      expect(find.text(te.farmerCalendarTasks), findsOneWidget);
      // One plot in season: no chips.
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('no season: one card that opens My farm', (tester) async {
      final container = await createTestContainer();
      final home = await container
          .read(farmerProfileRepositoryProvider)
          .getHome();
      await container
          .read(farmerProfileRepositoryProvider)
          .closeSeason(
            seasonId: home.plots.single.activeSeason!.id,
            outcome: SeasonOutcome.harvested,
          );
      final router = await pumpCalendar(tester, container);

      expect(find.text(te.farmerCalendarNoSeason), findsOneWidget);
      expect(find.byType(StageStrip), findsNothing);
      await tester.tap(findLabel(te.farmerFarmStartSeason));
      await tester.pumpAndSettle();
      expect(currentPath(router), Routes.farm);
    });

    testWidgets('several plots in season: chips switch the plot', (
      tester,
    ) async {
      final container = await createTestContainer();
      await addPaddyPlot(container, sowingDate: LocalDate(2026, 10, 1));
      await pumpCalendar(tester, container);

      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(
        find.text(te.farmerCalendarDayOf(day: 123, total: 160)),
        findsOneWidget,
      );

      await tester.tap(find.text('${te.farmerFarmPlot(number: 2)} · వరి'));
      await tester.pumpAndSettle();
      expect(
        find.text(te.farmerCalendarDayOf(day: 31, total: 120)),
        findsOneWidget,
      );
      expect(find.text('${te.farmerCalendarNow} · పిలకల దశ'), findsOneWidget);
      expect(
        tester.widget<StageStrip>(find.byType(StageStrip)).currentIndex,
        1,
      );
    });

    testWidgets('no sowing date: says to add it, no stage strip', (
      tester,
    ) async {
      final container = await createTestContainer();
      await addPaddyPlot(container);
      await pumpCalendar(tester, container);

      await tester.tap(find.text('${te.farmerFarmPlot(number: 2)} · వరి'));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerCalendarNoSowingDate), findsOneWidget);
      expect(find.byType(StageStrip), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('sowing date still ahead: "sowing <date>", "not sown yet"', (
      tester,
    ) async {
      final container = await createTestContainer();
      await addPaddyPlot(container, sowingDate: LocalDate(2026, 11, 6));
      await pumpCalendar(tester, container);

      await tester.tap(find.text('${te.farmerFarmPlot(number: 2)} · వరి'));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerSeasonStartNotSown), findsOneWidget);
      expect(
        find.text(te.farmerFarmSowsOn(date: DateTime(2026, 11, 6))),
        findsOneWidget,
      );
      expect(find.textContaining('-'), findsNothing, reason: 'no "Day -5"');
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('crop without a duration: "day 123", no bar', (tester) async {
      final container = await createTestContainer();
      final crops = await container.read(mastersRepositoryProvider).listCrops();
      final noDuration = FarmerCropList(
        version: crops.version,
        seasonCodes: crops.seasonCodes,
        items: [
          for (final c in crops.items)
            FarmerCrop(
              id: c.id,
              code: c.code,
              nameTe: c.nameTe,
              name: c.name,
              durationDays: null,
              stages: c.stages,
            ),
        ],
      );
      await pumpCalendar(
        tester,
        container,
        overrides: [cropsProvider.overrideWith((ref) async => noDuration)],
      );

      expect(find.text(te.farmerCalendarDay(day: 123)), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.widget<StageStrip>(find.byType(StageStrip)).currentIndex,
        4,
      );
    });

    testWidgets('offline: the offline card', (tester) async {
      await pumpCalendar(
        tester,
        await createTestContainer(scenario: MockScenario.offline),
      );
      expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
      expect(find.byType(StageStrip), findsNothing);
    });

    testWidgets('server error: the error card, Try again loads it', (
      tester,
    ) async {
      final container = await createTestContainer(
        scenario: MockScenario.serverError,
      );
      await pumpCalendar(tester, container);
      expect(find.text(te.farmerStateErrorTitle), findsOneWidget);

      container.read(mockScenarioProvider.notifier).select(MockScenario.normal);
      await tester.tap(findLabel(te.commonRetry));
      await tester.pumpAndSettle();
      expect(find.byType(StageStrip), findsOneWidget);
    });

    testWidgets('a failed pull-to-refresh keeps the calendar', (tester) async {
      final container = await createTestContainer();
      await pumpCalendar(tester, container);

      container
          .read(mockScenarioProvider.notifier)
          .select(MockScenario.offline);
      await pullToRefresh(tester, find.byType(ListView));

      expect(find.byType(StageStrip), findsOneWidget);
      expect(find.text(te.describeError(ApiErrorCode.network)), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      await pumpCalendar(
        tester,
        await createTestContainer(),
        locale: const Locale('en'),
      );

      expect(find.text('Crop calendar'), findsOneWidget);
      expect(find.text('Plot 1 · Cotton'), findsOneWidget);
      expect(find.text('Day 123 of about 160'), findsOneWidget);
      expect(
        tester.widget<StageStrip>(find.byType(StageStrip)).stages.last,
        'Picking',
      );
    });
  });

  group('CalendarScreen layout', () {
    screenLayoutTest('Crop calendar', () => const CalendarScreen());
    screenLayoutTest(
      'Crop calendar offline',
      () => const CalendarScreen(),
      scenario: MockScenario.offline,
    );

    for (final scale in textScales) {
      testWidgets('two plots fit 360x640 at text scale $scale', (tester) async {
        final container = await createTestContainer();
        await addPaddyPlot(container, sowingDate: LocalDate(2026, 10, 1));
        await pumpScreen(
          tester,
          const CalendarScreen(),
          container: container,
          textScale: scale,
        );
        expect(find.byType(ChoiceChip), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
      });
    }
  });
}
