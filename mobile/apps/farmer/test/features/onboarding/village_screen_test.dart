import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/onboarding/village_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

final _search = find.byType(TextField);

Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(_search, query);
  await tester.pump(villageSearchDebounce);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts with the search box and the browse option', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.needsVillage);
    await pumpScreen(tester, const VillageScreen(), container: container);

    expect(find.text(te.farmerVillageTitle), findsOneWidget);
    expect(find.text(te.farmerVillageSearchHint), findsOneWidget);
    expect(orbitButton(te.farmerVillageBrowse), findsOneWidget);
  });

  testWidgets('English search shows Telugu and English names, mandal and '
      'district; a tap picks the village', (tester) async {
    final container = await createContainerAt(SessionPhase.needsVillage);
    await pumpScreen(tester, const VillageScreen(), container: container);

    await _type(tester, 'kond');

    expect(find.text('కొండాపూర్'), findsOneWidget);
    expect(find.text('Kondapur'), findsOneWidget);
    expect(
      find.text(
        te.farmerVillageResultArea(
          mandal: 'శేరిలింగంపల్లి',
          district: 'రంగారెడ్డి',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('కొండాపూర్'));
    await tester.pump();
    expect(phaseOf(container), SessionPhase.needsName);
    expect(container.read(sessionProvider).village?.name, 'Kondapur');
  });

  testWidgets('searches in Telugu too', (tester) async {
    final container = await createContainerAt(SessionPhase.needsVillage);
    await pumpScreen(tester, const VillageScreen(), container: container);

    await _type(tester, 'గచ్చి');

    expect(find.text('గచ్చిబౌలి'), findsOneWidget);
    expect(find.text('కొండాపూర్'), findsNothing);
  });

  testWidgets('waits for typing to pause before searching', (tester) async {
    final container = await createContainerAt(SessionPhase.needsVillage);
    await pumpScreen(tester, const VillageScreen(), container: container);

    await tester.enterText(_search, 'kond');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Kondapur'), findsNothing);
    await tester.pump(villageSearchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('Kondapur'), findsOneWidget);
  });

  testWidgets('no results: one card with the browse action', (tester) async {
    final container = await createContainerAt(SessionPhase.needsVillage);
    await pumpScreen(tester, const VillageScreen(), container: container);

    await _type(tester, 'zzzz');

    expect(find.text(te.farmerVillageNoResults(query: 'zzzz')), findsOneWidget);
    await tester.tap(orbitButton(te.farmerVillageBrowse));
    await tester.pumpAndSettle();
    expect(find.text(te.farmerVillageChooseDistrict), findsOneWidget);
  });

  testWidgets('offline: the offline card, and Try again searches again', (
    tester,
  ) async {
    final container = await createContainerAt(
      SessionPhase.needsVillage,
      scenario: MockScenario.offline,
    );
    await pumpScreen(tester, const VillageScreen(), container: container);

    await _type(tester, 'kond');
    expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);

    container.read(mockScenarioProvider.notifier).select(MockScenario.normal);
    await tester.tap(orbitButton(te.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text('Kondapur'), findsOneWidget);
  });

  testWidgets('browse district > mandal > village, with Back between steps', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.needsVillage);
    await pumpScreen(tester, const VillageScreen(), container: container);

    await tester.tap(orbitButton(te.farmerVillageBrowse));
    await tester.pumpAndSettle();
    expect(find.text(te.farmerVillageChooseDistrict), findsOneWidget);

    await tester.tap(find.text('రంగారెడ్డి'));
    await tester.pumpAndSettle();
    expect(find.text(te.farmerVillageChooseMandal), findsOneWidget);
    expect(find.text('చేవెళ్ల'), findsOneWidget);

    await tester.tap(find.text('శేరిలింగంపల్లి'));
    await tester.pumpAndSettle();
    expect(find.text(te.farmerVillageChooseVillage), findsOneWidget);
    expect(find.text('మాదాపూర్'), findsOneWidget);
    expect(find.text('చేవెళ్ల'), findsNothing);

    // Back: village step -> mandal step (system Back works the same).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(te.farmerVillageChooseMandal), findsOneWidget);

    await tester.tap(find.text('శేరిలింగంపల్లి'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('మాదాపూర్'));
    await tester.pump();
    expect(phaseOf(container), SessionPhase.needsName);
    expect(container.read(sessionProvider).village?.name, 'Madhapur');
  });

  testWidgets('browse back from the first step returns to search', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.needsVillage);
    await pumpScreen(tester, const VillageScreen(), container: container);

    await tester.tap(orbitButton(te.farmerVillageBrowse));
    await tester.pumpAndSettle();
    final back = MaterialLocalizations.of(
      tester.element(find.byType(VillageScreen)),
    ).backButtonTooltip;
    await tester.tap(find.byTooltip(back));
    await tester.pumpAndSettle();
    expect(find.text(te.farmerVillageTitle), findsOneWidget);
  });

  testWidgets('browse offline shows the offline card', (tester) async {
    final container = await createContainerAt(
      SessionPhase.needsVillage,
      scenario: MockScenario.offline,
    );
    await pumpScreen(tester, const VillageScreen(), container: container);

    await tester.tap(orbitButton(te.farmerVillageBrowse));
    await tester.pumpAndSettle();
    expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
  });

  testWidgets('renders in English, English names first', (tester) async {
    final container = await createContainerAt(SessionPhase.needsVillage);
    await container.read(sessionProvider.notifier).setLanguage(Language.en);
    await pumpScreen(
      tester,
      const VillageScreen(),
      container: container,
      locale: const Locale('en'),
    );
    expect(find.text(en.farmerVillageTitle), findsOneWidget);

    await _type(tester, 'kond');
    expect(
      find.text(
        en.farmerVillageResultArea(
          mandal: 'Serilingampally',
          district: 'Rangareddy',
        ),
      ),
      findsOneWidget,
    );
  });

  screenLayoutTest(
    'village picker',
    () => const VillageScreen(),
    phase: SessionPhase.needsVillage,
  );
  screenLayoutTest(
    'village search results',
    () => const VillageScreen(),
    phase: SessionPhase.needsVillage,
    after: (tester) => _type(tester, 'a'),
  );
  screenLayoutTest(
    'village no results',
    () => const VillageScreen(),
    phase: SessionPhase.needsVillage,
    after: (tester) => _type(tester, 'zzzz'),
  );
  screenLayoutTest(
    'village browse, mandals',
    () => const VillageScreen(),
    phase: SessionPhase.needsVillage,
    after: (tester) async {
      await tester.tap(orbitButton(te.farmerVillageBrowse));
      await tester.pumpAndSettle();
      await tester.tap(find.text('రంగారెడ్డి'));
      await tester.pumpAndSettle();
    },
  );
}
