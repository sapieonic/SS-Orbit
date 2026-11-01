import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/routing/router.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../support/harness.dart';

void main() {
  group('a revoked session lands on the login screen', () {
    for (final path in [
      Routes.home,
      Routes.visits,
      Routes.advisory,
      Routes.farm,
      Routes.consents,
    ]) {
      testWidgets('from $path', (tester) async {
        final backend = testBackend();
        final container = await createTestContainer(backend: backend);
        await pumpFarmerApp(tester, container: container);
        final router = container.read(routerProvider)..go(path);
        await tester.pumpAndSettle();

        backend.scenario = MockScenario.sessionRevoked;
        await pullToRefresh(
          tester,
          find
              .descendant(
                of: find.byType(RefreshIndicator),
                matching: find.byType(Scrollable),
              )
              .first,
        );

        expect(phaseOf(container), SessionPhase.signedOut);
        expect(currentPath(router), Routes.login);
        expect(
          await container.read(sessionStoreProvider).readSession(),
          isNull,
        );
      });
    }

    testWidgets('at start, when Home is the first call', (tester) async {
      final container = await createTestContainer(
        scenario: MockScenario.sessionRevoked,
      );
      await pumpFarmerApp(tester, container: container);

      expect(phaseOf(container), SessionPhase.signedOut);
      expect(currentPath(container.read(routerProvider)), Routes.login);
    });
  });

  testWidgets('Reset mock data while signed in goes back to sign-in', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);
    final router = container.read(routerProvider)..go(Routes.dev);
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('Reset mock data'));
    router.go(Routes.home);
    await tester.pumpAndSettle();

    expect(phaseOf(container), SessionPhase.signedOut);
    expect(currentPath(router), Routes.login);
  });

  group('error card', () {
    testWidgets('offers Sign out for a refused session', (tester) async {
      final container = await createTestContainer();
      await pumpScreen(
        tester,
        Scaffold(
          body: ErrorStateCard(
            error: const ApiError(
              code: ApiErrorCode.forbidden,
              message: 'forbidden',
              status: 403,
            ),
            onRetry: () {},
          ),
        ),
        container: container,
      );

      expect(orbitButton(te.commonRetry), findsOneWidget);
      await tester.tap(find.text(te.commonSignOut));
      await tester.pumpAndSettle();

      expect(phaseOf(container), SessionPhase.signedOut);
    });

    testWidgets('offline or a server error: its own card, Try again only', (
      tester,
    ) async {
      final container = await createTestContainer();
      for (final (error, title, notTitle) in [
        (
          const ApiError.network(),
          te.farmerStateOfflineTitle,
          te.farmerStateErrorTitle,
        ),
        (
          const ApiError(
            code: ApiErrorCode.unavailable,
            message: 'down',
            status: 503,
          ),
          te.farmerStateErrorTitle,
          te.farmerStateOfflineTitle,
        ),
      ]) {
        var retried = 0;
        await pumpScreen(
          tester,
          Scaffold(
            body: ErrorStateCard(error: error, onRetry: () => retried++),
          ),
          container: container,
        );
        expect(find.text(title), findsOneWidget, reason: error.code);
        expect(find.text(notTitle), findsNothing, reason: error.code);
        expect(find.text(te.commonSignOut), findsNothing);
        await tester.tap(orbitButton(te.commonRetry));
        expect(retried, 1);
      }
    });
  });
}
