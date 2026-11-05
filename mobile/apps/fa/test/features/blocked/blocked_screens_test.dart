import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/auth/login_screen.dart';
import 'package:fa/src/features/blocked/removed_screen.dart';
import 'package:fa/src/features/blocked/update_required_screen.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';
import '../auth/auth_test_support.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.shanmukhaagritec.orbit.fa';

void main() {
  group('update required', () {
    testWidgets('nothing waiting: straight to Play Store', (tester) async {
      final t = await createFaTestAt(SessionPhase.updateRequired);
      await t.read(sessionProvider.notifier).refreshAppConfig();
      await pumpFaApp(tester, test: t);
      expect(find.byType(UpdateRequiredScreen), findsOneWidget);
      expect(
        find.text(te.faBlockedUpdateBody(version: '0.1.0', min: '1.0.5')),
        findsOneWidget,
      );
      expect(find.text(te.faBlockedStepNothing), findsOneWidget);

      await tester.tap(orbitButton(te.faBlockedOpenStore));
      await tester.pumpAndSettle();
      expect(t.launcher.stores, [_storeUrl]);
    });

    testWidgets('sends the waiting records first', (tester) async {
      final t = await createFaTestAt(SessionPhase.updateRequired);
      await queueRecords(tester, t);
      await pumpFaScreen(tester, const UpdateRequiredScreen(), test: t);
      expect(find.text(te.faBlockedStepSend(count: 1)), findsOneWidget);
      expect(orbitButton(te.faBlockedOpenStore), findsNothing);

      // Offline: it fails; the FA may retry or update anyway.
      await tester.tap(orbitButton(te.faBlockedSendThenUpdate));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(te.faBlockedSendFailed, findRichText: true),
        findsOneWidget,
      );
      expect(orbitButton(te.faBlockedUpdateAnyway), findsOneWidget);

      selectScenario(t, MockScenario.updateRequired);
      await scrollAndTap(tester, orbitButton(te.commonRetry));
      expect(find.text(te.faBlockedStepSent(count: 1)), findsOneWidget);
      expect(t.read(syncStateProvider).queuedCount, 0);

      await scrollAndTap(tester, orbitButton(te.faBlockedOpenStore));
      expect(t.launcher.stores, [_storeUrl]);
    });

    testWidgets('no store app: says so', (tester) async {
      final t = await createFaTestAt(SessionPhase.updateRequired);
      t.launcher.opens = false;
      await pumpFaScreen(tester, const UpdateRequiredScreen(), test: t);
      await tester.tap(orbitButton(te.faBlockedOpenStore));
      await tester.pumpAndSettle();
      expect(find.text(te.faBlockedStoreFailed), findsOneWidget);
    });

    screenLayoutTest('update required', () => const UpdateRequiredScreen());
  });

  group('removed', () {
    testWidgets('Call HO, or log in with a new password', (tester) async {
      final t = await createFaTestAt(SessionPhase.removed);
      await pumpFaApp(tester, test: t);
      expect(find.byType(RemovedScreen), findsOneWidget);
      expect(find.text(te.faBlockedRemovedBody), findsOneWidget);

      await tester.tap(orbitButton(te.faAuthCallHo(phone: '1800 123 4567')));
      await tester.pump();
      expect(t.launcher.calls, ['18001234567']);

      await tester.tap(orbitButton(te.faBlockedNewLogin));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.signedOut);
      expect(currentPath(t.router), AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    screenLayoutTest('removed', () => const RemovedScreen());
  });
}
