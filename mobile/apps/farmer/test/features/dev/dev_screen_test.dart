import 'dart:async';

import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/auth/login_screen.dart';
import 'package:farmer/src/features/dev/dev_screen.dart';
import 'package:farmer/src/features/home/home_sections.dart';
import 'package:farmer/src/routing/router.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('switching scenario keeps the screen under the dev menu', (
    tester,
  ) async {
    final container = await createTestContainer(signedIn: false);
    await pumpFarmerApp(tester, container: container);
    final router = container.read(routerProvider);
    unawaited(router.push(Routes.dev));
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text(MockScenario.sessionRevoked.label));
    await tester.pumpAndSettle();
    expect(container.read(mockScenarioProvider), MockScenario.sessionRevoked);
    // A pushed route doesn't change the router's URI, so check what's shown.
    expect(find.byType(DevScreen), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'login is still under /dev');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(DevScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(currentPath(router), Routes.login);
  });

  /// Opens the dev menu over the current screen, picks [scenario] and goes
  /// back.
  Future<void> switchScenario(
    WidgetTester tester,
    GoRouter router,
    MockScenario scenario,
  ) async {
    unawaited(router.push(Routes.dev));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text(scenario.label));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
  }

  testWidgets('a scenario switch refetches the signed-in farmer data', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);
    final router = container.read(routerProvider);
    expect(find.byType(HomeNoFaCard), findsNothing, reason: 'Ravi has an FA');

    await switchScenario(tester, router, MockScenario.noFaAssigned);

    expect(container.read(farmerHomeProvider).value?.fa, isNull);
    expect(find.byType(HomeNoFaCard), findsOneWidget);
  });

  testWidgets('Look for FAs refetches too', (tester) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);
    final router = container.read(routerProvider)..go(Routes.fas);
    await tester.pumpAndSettle();
    expect(find.byType(FaCard), findsOneWidget);

    await switchScenario(tester, router, MockScenario.noFaAssigned);

    expect(find.byType(FaCard), findsNothing);
    expect(find.text(te.farmerStateNoFaTitle), findsOneWidget);
  });

  testWidgets('a scenario switch to a revoked session signs out', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);
    final router = container.read(routerProvider);
    unawaited(router.push(Routes.dev));
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text(MockScenario.sessionRevoked.label));
    await tester.pumpAndSettle();

    // The refetch under the new scenario gets a 401, so the session ends.
    expect(container.read(sessionProvider).phase, SessionPhase.signedOut);
  });
}
