import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/onboarding/name_screen.dart';
import 'package:farmer/src/shared/farmer_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'profile_spy.dart';

final _nameField = find.byType(TextField);

void main() {
  testWidgets('shows the picked village with Change', (tester) async {
    final container = await createContainerAt(SessionPhase.needsName);
    await pumpScreen(tester, const NameScreen(), container: container);

    // The title in the header, and again as the field's label.
    expect(
      find.widgetWithText(ScreenHeader, te.farmerNameTitle),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, te.farmerNameTitle), findsOneWidget);
    expect(
      find.text(te.commonDotJoin(first: 'కొండాపూర్', second: 'Kondapur')),
      findsOneWidget,
    );

    await tester.tap(find.text(te.commonEdit));
    await tester.pump();
    expect(phaseOf(container), SessionPhase.needsVillage);
  });

  testWidgets('system Back also goes to the village picker', (tester) async {
    final container = await createContainerAt(SessionPhase.needsName);
    await pumpScreen(tester, const NameScreen(), container: container);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(phaseOf(container), SessionPhase.needsVillage);
  });

  testWidgets('a blank name is not sent', (tester) async {
    final spy = ProfileSpy();
    final container = await createContainerAt(
      SessionPhase.needsName,
      overrides: [spyOnProfile(spy)],
    );
    await pumpScreen(tester, const NameScreen(), container: container);

    await tester.enterText(_nameField, '   ');
    await tester.tap(orbitButton(te.farmerNameFinish));
    await tester.pumpAndSettle();

    expect(find.text(te.farmerNameRequired), findsOneWidget);
    expect(spy.completed, isEmpty);
    expect(phaseOf(container), SessionPhase.needsName);
  });

  testWidgets('Finish completes the profile and the farmer is active', (
    tester,
  ) async {
    final spy = ProfileSpy();
    final container = await createContainerAt(
      SessionPhase.needsName,
      overrides: [spyOnProfile(spy)],
    );
    await pumpScreen(tester, const NameScreen(), container: container);

    await tester.enterText(_nameField, 'రాము');
    await tester.tap(orbitButton(te.farmerNameFinish));
    await tester.pumpAndSettle();

    expect(spy.completed, [('రాము', 'రాము')]);
    expect(phaseOf(container), SessionPhase.active);
    expect(find.text(te.farmerNameDone), findsOneWidget);
    final home = await container
        .read(farmerProfileRepositoryProvider)
        .getHome();
    expect(home.farmer.nameTe, 'రాము');
    expect(home.village?.name, 'Kondapur');
  });

  testWidgets('profile_already_complete counts as done', (tester) async {
    final container = await createContainerAt(SessionPhase.needsName);
    // Completed on an earlier try (say the app died before the answer).
    await container
        .read(farmerProfileRepositoryProvider)
        .completeProfile(
          name: 'Ramu',
          language: Language.te,
          villageId: (await kondapur(container)).id,
        );
    await pumpScreen(tester, const NameScreen(), container: container);

    await tester.enterText(_nameField, 'Ramu');
    await tester.tap(orbitButton(te.farmerNameFinish));
    await tester.pumpAndSettle();

    expect(phaseOf(container), SessionPhase.active);
  });

  testWidgets('offline: says so and keeps the name', (tester) async {
    final container = await createContainerAt(
      SessionPhase.needsName,
      scenario: MockScenario.offline,
    );
    await pumpScreen(tester, const NameScreen(), container: container);

    await tester.enterText(_nameField, 'Ramu');
    await tester.tap(orbitButton(te.farmerNameFinish));
    await tester.pumpAndSettle();

    expect(find.text(te.errorNetwork), findsOneWidget);
    expect(find.text('Ramu'), findsOneWidget);
    expect(phaseOf(container), SessionPhase.needsName);
  });

  testWidgets('caps the name at the API limit', (tester) async {
    final container = await createContainerAt(SessionPhase.needsName);
    await pumpScreen(tester, const NameScreen(), container: container);

    await tester.enterText(_nameField, 'a' * (farmerNameMaxLength + 20));
    await tester.pump();
    expect(
      tester.widget<TextField>(_nameField).controller!.text,
      hasLength(farmerNameMaxLength),
    );
  });

  testWidgets('renders in English', (tester) async {
    final container = await createContainerAt(SessionPhase.needsName);
    await pumpScreen(
      tester,
      const NameScreen(),
      container: container,
      locale: const Locale('en'),
    );
    expect(orbitButton(en.farmerNameFinish), findsOneWidget);
    expect(find.text(en.farmerNameSubtitle), findsOneWidget);
  });

  screenLayoutTest(
    'name',
    () => const NameScreen(),
    phase: SessionPhase.needsName,
  );
  screenLayoutTest(
    'name, blank error',
    () => const NameScreen(),
    phase: SessionPhase.needsName,
    after: (tester) async {
      await tester.tap(orbitButton(te.farmerNameFinish));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerNameRequired), findsOneWidget);
    },
  );
}
