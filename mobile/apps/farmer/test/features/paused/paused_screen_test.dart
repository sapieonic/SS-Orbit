import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/paused/paused_screen.dart';
import 'package:farmer/src/shared/launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('one card: account paused, call the helpline', (tester) async {
    final container = await createContainerAt(SessionPhase.inactive);
    await pumpScreen(tester, const PausedScreen(), container: container);

    expect(find.byType(StateCard), findsOneWidget);
    expect(find.text(te.farmerLoginPausedTitle), findsOneWidget);
    expect(find.text(te.farmerLoginAccountPaused), findsOneWidget);
    expect(orbitButton(te.farmerLoginCallHelpline), findsOneWidget);
    expect(find.text(te.commonSignOut), findsOneWidget);
  });

  testWidgets('Call helpline dials the helpline', (tester) async {
    final launcher = FakeContactLauncher();
    final container = await createContainerAt(
      SessionPhase.inactive,
      launcher: launcher,
    );
    await pumpScreen(tester, const PausedScreen(), container: container);

    await tester.tap(orbitButton(te.farmerLoginCallHelpline));
    await tester.pumpAndSettle();
    expect(launcher.calls, [helplinePhone]);
  });

  testWidgets('Try again checks again, busy meanwhile, and opens Home once '
      'HO re-activates', (tester) async {
    final backend = testBackend();
    final container = await createContainerAt(
      SessionPhase.inactive,
      backend: backend,
    );
    await pumpScreen(tester, const PausedScreen(), container: container);

    backend
      ..scenario = MockScenario.normal
      ..latency = const Duration(milliseconds: 300);
    await tester.tap(orbitButton(te.commonRetry));
    await tester.pump();
    final retry = tester.widget<OrbitButton>(orbitButton(te.commonRetry));
    expect(retry.loading, isTrue);
    expect(retry.onPressed, isNull, reason: 'one check at a time');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(phaseOf(container), SessionPhase.active);
  });

  testWidgets('Try again offline says so and stays', (tester) async {
    final container = await createContainerAt(SessionPhase.inactive);
    await pumpScreen(tester, const PausedScreen(), container: container);

    container.read(mockScenarioProvider.notifier).select(MockScenario.offline);
    await tester.tap(orbitButton(te.commonRetry));
    await tester.pumpAndSettle();

    expect(find.text(te.errorNetwork), findsOneWidget);
    expect(phaseOf(container), SessionPhase.inactive);
    final retry = tester.widget<OrbitButton>(orbitButton(te.commonRetry));
    expect(retry.loading, isFalse);
    expect(retry.onPressed, isNotNull);
  });

  testWidgets('Sign out goes back to the phone step', (tester) async {
    final container = await createContainerAt(SessionPhase.inactive);
    await pumpScreen(tester, const PausedScreen(), container: container);

    await tester.tap(find.text(te.commonSignOut));
    await tester.pumpAndSettle();

    expect(phaseOf(container), SessionPhase.signedOut);
  });

  testWidgets('pull to refresh checks again once HO re-activates', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.inactive);
    await pumpScreen(tester, const PausedScreen(), container: container);

    container.read(mockScenarioProvider.notifier).select(MockScenario.normal);
    await tester.fling(find.byType(StateCard), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(phaseOf(container), SessionPhase.active);
  });

  testWidgets('pull to refresh offline says so and stays', (tester) async {
    final container = await createContainerAt(SessionPhase.inactive);
    await pumpScreen(tester, const PausedScreen(), container: container);

    container.read(mockScenarioProvider.notifier).select(MockScenario.offline);
    await tester.fling(find.byType(StateCard), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text(te.errorNetwork), findsOneWidget);
    expect(phaseOf(container), SessionPhase.inactive);
  });

  testWidgets('renders in English', (tester) async {
    final container = await createContainerAt(SessionPhase.inactive);
    await pumpScreen(
      tester,
      const PausedScreen(),
      container: container,
      locale: const Locale('en'),
    );
    expect(find.text(en.farmerLoginPausedTitle), findsOneWidget);
  });

  screenLayoutTest(
    'account paused',
    () => const PausedScreen(),
    phase: SessionPhase.inactive,
  );
}
