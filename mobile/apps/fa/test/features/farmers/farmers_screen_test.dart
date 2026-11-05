import 'package:fa/src/data/data.dart';
import 'package:fa/src/device/device.dart';
import 'package:fa/src/features/farmers/farmer_presenter.dart';
import 'package:fa/src/features/farmers/farmer_widgets.dart';
import 'package:fa/src/features/farmers/farmers_screen.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'farmers_test_support.dart';

Future<FaTest> _pump(
  WidgetTester tester, {
  FaTest? test,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  FarmerFilter? filter,
}) => pumpFaScreen(
  tester,
  FarmersScreen(filter: filter),
  test: test,
  location: filter == null
      ? AppRoutes.farmers
      : AppRoutes.farmersFiltered(filter),
  locale: locale,
  textScale: textScale,
  overrides: farmersOverrides(),
);

Finder _card(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(FarmerCard));

/// The farmer list (not the sideways chips).
final _list = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

/// Scrolls the list until [finder] is fully visible.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _list.first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Taps the chip that starts with [label] (scrolled into view first).
Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = find.textContaining('$label · ');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// A farmer after the nearest whose pin is on screen and tappable.
FarmerRow _visiblePin(WidgetTester tester, List<FarmerRow> rows) => rows
    .skip(1)
    .firstWhere(
      (r) => find
          .byKey(ValueKey('pin-${r.farmer.id}'))
          .hitTestable()
          .evaluate()
          .isNotEmpty,
    );

Future<void> _openMap(WidgetTester tester) async {
  await tester.tap(find.text(en.faFarmersViewMap));
  await tester.pumpAndSettle();
}

/// A territory with the masters and villages but no farmers.
class _NoFarmers extends TerritoryController {
  @override
  Future<Territory> build() async {
    final real = await super.build();
    return Territory(
      tables: Snapshot(
        territoryVersion: 1,
        mastersVersion: 1,
        generatedAt: real.asOf,
        farmers: const [],
        plots: const [],
        seasons: const [],
        visits: const [],
        callbacks: const [],
        alerts: const [],
        masters: real.masters,
        villages: real.villages,
      ),
      outbox: const [],
      asOf: real.asOf,
    );
  }
}

void main() {
  group('list', () {
    testWidgets('shows the territory nearest first with the area and count', (
      tester,
    ) async {
      final t = await _pump(tester);
      expect(find.text(en.faFarmersTitle), findsOneWidget);
      final area = t.territory.nearestVillage(MockLocationService.kondapur)!;
      expect(
        find.text(
          '${area.name} · ${en.faFarmersCount(count: t.territory.farmerCount)}'
          ' · ${en.faFarmersNearestFirst}',
        ),
        findsOneWidget,
      );
      final nearest = t.territory.farmerRows(
        from: MockLocationService.kondapur,
      );
      expect(find.text(nearest.first.farmer.name!), findsOneWidget);
      // The first card is the nearest farmer.
      final firstCard = tester.getTopLeft(_card(nearest.first.farmer.name!));
      final secondCard = tester.getTopLeft(_card(nearest[1].farmer.name!));
      expect(firstCard.dy, lessThan(secondCard.dy));
    });

    testWidgets('chips show the territory counts and filter the list', (
      tester,
    ) async {
      final t = await _pump(tester);
      final counts = t.territory.filterCounts();
      expect(
        find.text(
          '${en.faFarmersFilter30Days} · ${counts[FarmerFilter.notVisited30]}',
        ),
        findsOneWidget,
      );
      await _tapChip(tester, en.faFarmersFilter30Days);
      await _scrollTo(tester, find.text('Padma S'));
      expect(find.text('Padma S'), findsOneWidget);
      expect(find.text('Lakshmi N'), findsNothing);
      // Padma: 34 days, in red.
      final meta = find.textContaining(
        en.faFarmersMetaDaysSinceVisit(count: 34),
      );
      expect(meta, findsOneWidget);
      expect(
        tester.widget<Text>(meta).style!.color,
        OrbitColors.of(tester.element(meta)).danger.fg,
      );
      expect(
        find.textContaining(
          en.faFarmersShown(count: counts[FarmerFilter.notVisited30]!),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a filter link opens with its chip picked', (tester) async {
      final t = await _pump(tester, filter: FarmerFilter.visitDue);
      final bar = tester.widget<FilterChipsBar>(find.byType(FilterChipsBar));
      expect(bar.selectedIndex, FarmerFilter.visitDue.index);
      final due = t.territory.filterCounts()[FarmerFilter.visitDue]!;
      expect(
        find.textContaining(en.faFarmersShown(count: due)),
        findsOneWidget,
      );
    });

    testWidgets('new farmers are tagged and the meta says when they joined', (
      tester,
    ) async {
      await _pump(tester);
      await _tapChip(tester, en.faFarmersFilterNew);
      await _scrollTo(tester, find.text('Lakshmi N'));
      final lakshmi = _card('Lakshmi N');
      expect(
        find.descendant(of: lakshmi, matching: statusPill(en.faFarmersTagNew)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: lakshmi,
          matching: find.textContaining(en.faFarmersMetaJoinedYesterday),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a card opens Farmer 360', (tester) async {
      final t = await _pump(tester);
      final ravi = t.territory.farmerByPhone(MockBackend.raviPhone)!;
      await _scrollTo(tester, find.text('Ravi K'));
      await tester.tap(find.text('Ravi K'));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.farmer(ravi.id));
    });

    testWidgets('Call, WhatsApp and Directions open the other apps', (
      tester,
    ) async {
      final t = await _pump(tester);
      final row = rowNamed(t.territory, 'Ravi K');
      final card = _card('Ravi K');
      await _scrollTo(tester, card);
      await tester.tap(
        find.descendant(of: card, matching: find.text(en.commonCall)),
      );
      await tester.tap(
        find.descendant(of: card, matching: find.text(en.commonWhatsapp)),
      );
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.bySemanticsLabel(en.faFarmersActionDirections),
        ),
      );
      await tester.pumpAndSettle();
      expect(t.launcher.calls, [row.farmer.phone]);
      expect(t.launcher.whatsApps.single.$1, row.farmer.phone);
      expect(t.launcher.directionsTo.single, (
        row.location!.lat,
        row.location!.lng,
      ));
    });

    testWidgets('a call that cannot open shows the number', (tester) async {
      final t = await createFaTest(overrides: farmersOverrides());
      t.launcher.opens = false;
      await _pump(tester, test: t);
      await tester.tap(find.text(en.commonCall).first);
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't open the dialer"), findsOneWidget);
    });

    testWidgets('a farmer enrolled on this phone is tagged and continues to '
        'the farm step', (tester) async {
      final t = await createFaTest(overrides: farmersOverrides());
      t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
      final id = await t
          .read(faActionsProvider)
          .enrolFarmer(
            phone: '9876501234',
            name: 'Aaaa Test',
            language: Language.te,
            villageId: MockBackend.kondapurId,
          );
      await _pump(tester, test: t);
      final card = _card('Aaaa Test');
      await _scrollTo(tester, card);
      expect(
        find.descendant(of: card, matching: statusPill(en.faCommonNotSynced)),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.text(en.faFarmersActionFinishEnrolment),
        ),
      );
      await tester.pumpAndSettle();
      expect(currentLocation(t.router), AppRoutes.enrolPlot(id));
      // Let the engine's nudge timer run out.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a consent-only gap finishes on Farmer 360', (tester) async {
      final t = await _pump(tester);
      final kumar = rowNamed(t.territory, 'Kumar B');
      expect(kumar.enrolmentGaps, {EnrolmentGap.consent});
      await _tapChip(tester, en.faFarmersFilterFinishEnrolment);
      final finish = find.descendant(
        of: _card('Kumar B'),
        matching: find.text(en.faFarmersActionFinishEnrolment),
      );
      await _scrollTo(tester, finish);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.farmer(kumar.farmer.id));
    });
  });

  group('search', () {
    testWidgets('finds by name and by phone, and says when nothing matches', (
      tester,
    ) async {
      final t = await _pump(tester);
      await tester.tap(find.byTooltip(en.faFarmersSearchOpen));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'padma s');
      await tester.pumpAndSettle();
      expect(find.text('Padma S'), findsOneWidget);
      expect(find.text('Ravi K'), findsNothing);
      expect(find.textContaining(en.faFarmersShown(count: 1)), findsOneWidget);

      await tester.enterText(find.byType(TextField), '90000 00101');
      await tester.pumpAndSettle();
      expect(find.text('Ravi K'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text(en.faFarmersNoMatchTitle), findsOneWidget);
      expect(
        find.text(en.faFarmersNoMatchSearch(query: 'zzz')),
        findsOneWidget,
      );
      await tester.tap(find.text(en.faFarmersShowAll));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        find.textContaining(en.faFarmersCount(count: t.territory.farmerCount)),
        findsOneWidget,
      );
    });

    for (final typed in ['+91 90000 00101', '090000 00101', '+91-9000000101']) {
      testWidgets('finds a phone typed with a prefix: "$typed"', (
        tester,
      ) async {
        await _pump(tester);
        await tester.tap(find.byTooltip(en.faFarmersSearchOpen));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), typed);
        await tester.pumpAndSettle();
        expect(find.text('Ravi K'), findsOneWidget);
        expect(find.text(en.faFarmersNoMatchTitle), findsNothing);
      });
    }

    testWidgets('closing search clears it', (tester) async {
      final t = await _pump(tester);
      await tester.tap(find.byTooltip(en.faFarmersSearchOpen));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'padma');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(en.faFarmersSearchClose));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        find.textContaining(en.faFarmersCount(count: t.territory.farmerCount)),
        findsOneWidget,
      );
    });
  });

  group('empty states', () {
    testWidgets('before the first sync: open Sync', (tester) async {
      final t = await createFaTest(
        signedIn: false,
        overrides: farmersOverrides(),
      );
      await _pump(tester, test: t);
      expect(find.text(en.faFarmersNoDataTitle), findsOneWidget);
      await tester.tap(find.text(en.faFarmersNoDataAction));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.sync);
    });

    testWidgets('no farmers yet: enrol one', (tester) async {
      final t = await createFaTest(
        overrides: [
          ...farmersOverrides(),
          territoryProvider.overrideWith(_NoFarmers.new),
        ],
      );
      await _pump(tester, test: t);
      expect(find.text(en.faFarmersEmptyTitle), findsOneWidget);
      await tester.tap(find.text(en.faFarmersEmptyAction));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.enrol);
    });

    testWidgets('no GPS: measured from the middle of the area', (tester) async {
      final t = await createFaTest(overrides: farmersOverrides());
      (t.read(locationServiceProvider) as MockLocationService).setProblem(
        LocationProblem.permissionDenied,
      );
      await _pump(tester, test: t);
      final centre = territoryCentre(t.territory)!;
      final fromCentre = t.territory.farmerRows(from: centre);
      // The cards on screen are the farmers nearest the centre, in order.
      final first = tester.getTopLeft(_card(fromCentre[0].farmer.name!));
      final second = tester.getTopLeft(_card(fromCentre[1].farmer.name!));
      expect(first.dy, lessThan(second.dy));
      final shown = tester
          .widgetList<FarmerCard>(find.byType(FarmerCard))
          .map((c) => c.row.farmer.id)
          .toList();
      expect(shown, fromCentre.take(shown.length).map((r) => r.farmer.id));
      await _openMap(tester);
      expect(find.bySemanticsLabel(en.faFarmersMapYou), findsNothing);
    });
  });

  group('finish enrolment route', () {
    test('goes to the step that is missing', () async {
      final t = await createFaTest();
      final ravi = rowNamed(t.territory, 'Ravi K');
      FarmerRow withGaps(Set<EnrolmentGap> gaps) => FarmerRow(
        farmer: ravi.farmer,
        village: ravi.village,
        location: ravi.location,
        distanceKm: ravi.distanceKm,
        plots: gaps.contains(EnrolmentGap.plot)
            ? const []
            : gaps.contains(EnrolmentGap.season)
            ? [
                PlotSummary(
                  plot: ravi.plots.first.plot,
                  season: null,
                  crop: null,
                  stage: null,
                  daysAfterSowing: null,
                  pendingSync: false,
                ),
              ]
            : ravi.plots,
        lastDoneVisit: ravi.lastDoneVisit,
        daysSinceLastVisit: ravi.daysSinceLastVisit,
        nextPlannedVisit: ravi.nextPlannedVisit,
        enrolmentGaps: gaps,
        isNew: true,
        isVisitDue: false,
        isNotVisited30: false,
        pendingSync: false,
      );
      final id = ravi.farmer.id;
      expect(finishEnrolmentRoute(ravi), isNull);
      expect(
        finishEnrolmentRoute(
          withGaps({EnrolmentGap.profile, EnrolmentGap.plot}),
        ),
        AppRoutes.enrolFarmer(phone: '9000000101'),
      );
      expect(
        finishEnrolmentRoute(withGaps({EnrolmentGap.plot})),
        AppRoutes.enrolPlot(id),
      );
      expect(
        finishEnrolmentRoute(withGaps({EnrolmentGap.season})),
        AppRoutes.enrolCrop(id, plotId: ravi.plots.first.plot.id),
      );
      expect(
        finishEnrolmentRoute(withGaps({EnrolmentGap.consent})),
        AppRoutes.farmer(id),
      );
    });
  });

  group('map', () {
    testWidgets('pins every farmer with the legend and the nearest selected', (
      tester,
    ) async {
      final t = await _pump(tester);
      await _openMap(tester);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);
      expect(statusPill(en.faFarmersMapOffline), findsNothing);
      expect(find.text(en.faFarmersMapAttribution), findsOneWidget);
      expect(find.text(en.faFarmersMapLegendOthers), findsOneWidget);
      expect(find.bySemanticsLabel(en.faFarmersMapYou), findsOneWidget);
      final rows = t.territory.farmerRows(from: MockLocationService.kondapur);
      expect(
        find.byKey(ValueKey('pin-${rows.first.farmer.id}')),
        findsOneWidget,
      );
      expect(find.text(rows.first.farmer.name!), findsOneWidget);
      expect(find.byType(FilterChipsBar), findsNothing);
    });

    testWidgets('tapping a pin selects it; Open farmer opens Farmer 360', (
      tester,
    ) async {
      final t = await _pump(tester);
      await _openMap(tester);
      final rows = t.territory.farmerRows(from: MockLocationService.kondapur);
      final other = _visiblePin(tester, rows);
      await tester.tap(find.byKey(ValueKey('pin-${other.farmer.id}')));
      await tester.pumpAndSettle();
      expect(find.text(other.farmer.name!), findsOneWidget);
      final main = finishEnrolmentRoute(other) == null
          ? en.faFarmersActionOpenFarmer
          : en.faFarmersActionFinishEnrolment;
      await tester.tap(find.text(main));
      await tester.pumpAndSettle();
      expect(
        currentLocation(t.router),
        finishEnrolmentRoute(other) ?? AppRoutes.farmer(other.farmer.id),
      );
    });

    testWidgets('the selected card calls and opens directions', (tester) async {
      final t = await _pump(tester);
      await _openMap(tester);
      final first = t.territory
          .farmerRows(from: MockLocationService.kondapur)
          .first;
      await tester.tap(find.text(en.commonCall));
      await tester.tap(find.bySemanticsLabel(en.faFarmersActionDirections));
      await tester.pumpAndSettle();
      expect(t.launcher.calls, [first.farmer.phone]);
      expect(t.launcher.directionsTo.single, (
        first.location!.lat,
        first.location!.lng,
      ));
    });

    testWidgets('offline: no tiles, the pill says so, pins still work', (
      tester,
    ) async {
      final t = await createFaTest(overrides: farmersOverrides());
      t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
      await _pump(tester, test: t);
      await _openMap(tester);
      expect(statusPill(en.faFarmersMapOffline), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      expect(find.text(en.faFarmersMapAttribution), findsNothing);
      final rows = t.territory.farmerRows(from: MockLocationService.kondapur);
      final other = _visiblePin(tester, rows);
      await tester.tap(find.byKey(ValueKey('pin-${other.farmer.id}')));
      await tester.pumpAndSettle();
      expect(find.text(other.farmer.name!), findsOneWidget);

      // Back online: the tiles come back.
      t.read(mockScenarioProvider.notifier).select(MockScenario.normal);
      await tester.pumpAndSettle();
      expect(find.byType(TileLayer), findsOneWidget);
      expect(statusPill(en.faFarmersMapOffline), findsNothing);
    });

    testWidgets('plot boundaries show when zoomed in', (tester) async {
      await _pump(tester);
      await _openMap(tester);
      expect(find.byType(PolygonLayer), findsNothing);
      final controller = MapController.maybeOf(
        tester.element(find.byType(MarkerLayer)),
      )!;
      controller.move(controller.camera.center, 16);
      await tester.pumpAndSettle();
      expect(find.byType(PolygonLayer), findsOneWidget);
    });
  });

  group('Telugu', () {
    testWidgets('renders the screen and farmer names in Telugu', (
      tester,
    ) async {
      final t = await _pump(tester, locale: const Locale('te'));
      expect(find.text(te.faFarmersTitle), findsOneWidget);
      final first = t.territory
          .farmerRows(from: MockLocationService.kondapur)
          .first;
      expect(find.text(first.farmer.nameTe!), findsOneWidget);
      expect(find.text(te.faFarmersViewMap), findsOneWidget);
    });
  });

  group('layout', () {
    for (final scale in textScales) {
      testWidgets('list fits 360x640 at text scale $scale', (tester) async {
        await _pump(tester, locale: const Locale('te'), textScale: scale);
        expectCleanLayout(tester);
      });

      testWidgets('search fits 360x640 at text scale $scale', (tester) async {
        await _pump(tester, locale: const Locale('te'), textScale: scale);
        await tester.tap(find.byTooltip(te.faFarmersSearchOpen));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
        expectCleanLayout(tester);
      });

      testWidgets('map fits 360x640 at text scale $scale', (tester) async {
        final t = await createFaTest(overrides: farmersOverrides());
        t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
        await _pump(
          tester,
          test: t,
          locale: const Locale('te'),
          textScale: scale,
        );
        await tester.tap(find.text(te.faFarmersViewMap));
        await tester.pumpAndSettle();
        expectCleanLayout(tester);
      });
    }
  });
}
