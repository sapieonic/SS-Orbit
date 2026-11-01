import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/farm/add_plot_screen.dart';
import 'package:farmer/src/features/farm/widgets/plot_steps.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'farm_test_support.dart';

void main() {
  Future<void> next(WidgetTester tester) async {
    await tester.tap(orbitButton(te.commonNext));
    await tester.pumpAndSettle();
  }

  Future<void> enterArea(
    WidgetTester tester, {
    String acres = '',
    String guntas = '',
  }) async {
    await tester.enterText(find.byType(TextField).at(0), acres);
    await tester.enterText(find.byType(TextField).at(1), guntas);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(orbitButton(te.farmerPlotAddSave));
    await tester.pumpAndSettle();
  }

  Future<List<HomePlot>> plots(ProviderContainer container) async =>
      (await container.read(farmerProfileRepositoryProvider).getHome()).plots;

  testWidgets('adds a named plot at the village and goes back', (tester) async {
    final container = await createTestContainer();
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.addPlot,
    );

    // Step 1: optional name.
    expect(find.text(te.commonStepOf(step: 1, total: 3)), findsOneWidget);
    expect(find.text(te.farmerPlotAddLabelTitle), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'బావి దగ్గర పొలం');
    await next(tester);

    // Step 2: the village location, with the note.
    expect(find.text(te.commonStepOf(step: 2, total: 3)), findsOneWidget);
    expect(find.text(te.farmerPlotAddVillagePinTitle), findsOneWidget);
    expect(find.text(te.farmerPlotAddVillagePinBody), findsOneWidget);
    expect(find.text('కొండాపూర్'), findsOneWidget);
    await next(tester);

    // Step 3: 1 acre 20 guntas.
    expect(find.text(te.farmerPlotAddAreaTitle), findsOneWidget);
    await enterArea(tester, acres: '1', guntas: '20');
    await save(tester);

    expect(currentPath(router), Routes.farm);
    expect(find.text(te.farmerPlotAddSaved), findsOneWidget);
    final added = (await plots(container)).last.plot;
    expect(added.label, 'బావి దగ్గర పొలం');
    expect(added.areaAcres, 1.5);
    expect(added.pin, kondapurPin);

    await tester.scrollUntilVisible(
      find.text('బావి దగ్గర పొలం'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 ఎకరం 20 గుంటలు'), findsOneWidget);
  });

  testWidgets('a blank name lets the server name it Plot 2', (tester) async {
    final container = await createTestContainer();
    await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.addPlot,
    );

    await next(tester);
    await next(tester);
    await enterArea(tester, guntas: '30');
    await save(tester);

    final added = (await plots(container)).last.plot;
    expect(added.label, 'Plot 2');
    expect(added.areaAcres, 0.75);
    await tester.scrollUntilVisible(
      find.text('పొలం 2'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  });

  testWidgets('checks the area before saving', (tester) async {
    final container = await createTestContainer();
    await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.addPlot,
    );
    await next(tester);
    await next(tester);

    await save(tester);
    expect(find.text(te.farmerPlotAddAreaInvalid), findsOneWidget);

    await enterArea(tester, acres: '2', guntas: '45');
    await save(tester);
    expect(find.text(te.farmerPlotAddGuntasInvalid), findsOneWidget);

    // A smallholder's field: more than 100 acres is a typing slip.
    expect(maxPlotAcres, 100);
    await enterArea(tester, acres: '100', guntas: '1');
    await save(tester);
    expect(find.text(te.farmerPlotAddAreaTooBig(max: 100)), findsOneWidget);

    await enterArea(tester, acres: '250', guntas: '0');
    await save(tester);
    expect(find.text(te.farmerPlotAddAreaTooBig(max: 100)), findsOneWidget);

    await enterArea(tester, acres: '0', guntas: '0');
    await save(tester);
    expect(find.text(te.farmerPlotAddAreaInvalid), findsOneWidget);

    expect(await plots(container), hasLength(1), reason: 'nothing saved');
  });

  testWidgets('only digits go into the area fields', (tester) async {
    final container = await createTestContainer();
    await pumpScreen(tester, const AddPlotScreen(), container: container);
    await next(tester);
    await next(tester);
    await enterArea(tester, acres: '2.5a', guntas: '123');
    expect(find.text('25'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('back goes to the previous step', (tester) async {
    final container = await createTestContainer();
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.addPlot,
    );
    await next(tester);
    await next(tester);
    expect(find.text(te.commonStepOf(step: 3, total: 3)), findsOneWidget);

    await tester.tap(find.byIcon(OrbitIcons.back));
    await tester.pumpAndSettle();
    expect(find.text(te.commonStepOf(step: 2, total: 3)), findsOneWidget);

    // The system back gesture also steps back first.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(te.commonStepOf(step: 1, total: 3)), findsOneWidget);
    expect(currentPath(router), Routes.addPlot);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(currentPath(router), Routes.farm);
  });

  testWidgets('offline on save keeps the step and says why', (tester) async {
    final backend = testBackend();
    final container = await createTestContainer(backend: backend);
    final router = await pumpFarmRoutes(
      tester,
      container: container,
      location: Routes.addPlot,
    );
    await next(tester);
    await next(tester);
    await enterArea(tester, acres: '3');

    backend.scenario = MockScenario.offline;
    await save(tester);
    expect(find.text(te.errorNetwork), findsOneWidget);
    expect(currentPath(router), Routes.addPlot);
    expect(find.text(te.farmerPlotAddAreaTitle), findsOneWidget);
  });

  testWidgets('offline before the location loads shows the offline card', (
    tester,
  ) async {
    final container = await createTestContainer(scenario: MockScenario.offline);
    await pumpScreen(tester, const AddPlotScreen(), container: container);
    await next(tester);
    expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
    expect(orbitButton(te.commonNext), findsNothing);
  });

  testWidgets('renders in English', (tester) async {
    final container = await createTestContainer();
    await pumpScreen(
      tester,
      const AddPlotScreen(),
      container: container,
      locale: const Locale('en'),
    );
    expect(find.text(en.farmerPlotAddTitle), findsOneWidget);
    expect(find.text(en.farmerPlotAddLabelTitle), findsOneWidget);
    await tester.tap(orbitButton(en.commonNext));
    await tester.pumpAndSettle();
    expect(find.text('Kondapur'), findsOneWidget);
    expectCleanLayout(tester);
  });

  for (final scale in textScales) {
    testWidgets('every step fits 360x640 at text scale $scale', (tester) async {
      final container = await createTestContainer();
      await pumpScreen(
        tester,
        const AddPlotScreen(),
        container: container,
        textScale: scale,
      );
      expectCleanLayout(tester);
      await next(tester);
      expectCleanLayout(tester);
      await next(tester);
      await save(tester); // shows the inline error too
      expectCleanLayout(tester);
    });
  }
}
