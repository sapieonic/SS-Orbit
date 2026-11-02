import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/auth/change_password_screen.dart';
import 'package:fa/src/features/auth/login_screen.dart';
import 'package:fa/src/features/auth/setup_screen.dart';
import 'package:fa/src/features/auth/splash_screen.dart';
import 'package:fa/src/features/auth/unlock_screen.dart';
import 'package:fa/src/features/blocked/removed_screen.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';
import 'auth_test_support.dart';

Finder _field(int index) => find.byType(TextField).at(index);

Future<void> _logIn(WidgetTester tester, String code, String password) async {
  await tester.enterText(_field(0), code);
  await tester.enterText(_field(1), password);
  await tester.pump();
  await tester.tap(orbitButton(te.faLoginLogIn));
  await tester.pumpAndSettle();
}

void main() {
  group('signed out', () {
    testWidgets('logs Suresh in and goes on to setup', (tester) async {
      final t = await pumpFaApp(tester, signedIn: false);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(te.faLoginHoNote), findsOneWidget);
      expect(find.text(te.faLoginPinNote(length: 4)), findsOneWidget);

      await _logIn(tester, sureshLogin, sureshPassword);

      expect(t.phase, SessionPhase.setup);
      expect(currentPath(t.router), AppRoutes.setup);
      expect(find.byType(SetupScreen), findsOneWidget);
    });

    testWidgets('Log in stays off until both fields are filled', (
      tester,
    ) async {
      await pumpFaScreen(tester, const LoginScreen(), signedIn: false);
      OrbitButtonFinder.expectDisabled(tester, te.faLoginLogIn);
      await tester.enterText(_field(0), sureshLogin);
      await tester.pump();
      OrbitButtonFinder.expectDisabled(tester, te.faLoginLogIn);
      await tester.enterText(_field(1), 'x');
      await tester.pump();
      OrbitButtonFinder.expectEnabled(tester, te.faLoginLogIn);
    });

    testWidgets('a temporary password goes to A1c', (tester) async {
      final t = await pumpFaApp(tester, signedIn: false);
      await _logIn(tester, tempLogin, tempPassword);
      expect(t.phase, SessionPhase.mustChangePassword);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('a wrong password shows one message', (tester) async {
      final t = await pumpFaScreen(
        tester,
        const LoginScreen(),
        signedIn: false,
      );
      await _logIn(tester, sureshLogin, 'wrong-one');
      expect(find.text(te.faLoginErrorWrong), findsOneWidget);
      expect(t.phase, SessionPhase.signedOut);

      await _logIn(tester, 'FA-NOPE-000', sureshPassword);
      expect(find.text(te.faLoginErrorWrong), findsOneWidget);
    });

    testWidgets('an expired temporary password says call HO', (tester) async {
      await pumpFaScreen(tester, const LoginScreen(), signedIn: false);
      await _logIn(tester, 'FA-KDP-077', 'temp5678');
      expect(find.text(te.errorTempPasswordExpired), findsOneWidget);
    });

    testWidgets('offline without a session: needs network', (tester) async {
      final t = await createFaTest(signedIn: false);
      selectScenario(t, MockScenario.offline);
      await pumpFaScreen(tester, const LoginScreen(), test: t);
      await _logIn(tester, sureshLogin, sureshPassword);
      expect(find.text(te.faLoginErrorOfflineFirst), findsOneWidget);
      expect(t.phase, SessionPhase.signedOut);
    });

    testWidgets('too many tries: rate limited', (tester) async {
      final t = await createFaTest(signedIn: false);
      final session = t.read(sessionProvider.notifier);
      for (var i = 0; i < 10; i++) {
        await session.login(sureshLogin, 'wrong').catchError((Object _) {});
      }
      await pumpFaScreen(tester, const LoginScreen(), test: t);
      await _logIn(tester, sureshLogin, sureshPassword);
      expect(find.textContaining(te.errorRateLimited), findsOneWidget);
    });

    testWidgets('a removed phone goes to the removed screen', (tester) async {
      final t = await createFaTest(signedIn: false);
      await pumpFaApp(tester, test: t);
      selectScenario(t, MockScenario.deviceRemoved);
      await _logIn(tester, sureshLogin, sureshPassword);
      expect(t.phase, SessionPhase.removed);
      expect(find.byType(RemovedScreen), findsOneWidget);
    });

    testWidgets('Forgot password calls HO; the footer has version and HO', (
      tester,
    ) async {
      final t = await pumpFaScreen(
        tester,
        const LoginScreen(),
        signedIn: false,
      );
      expect(
        find.textContaining(te.faLoginFooterVersion(version: '0.1.0')),
        findsOneWidget,
      );
      expect(find.textContaining('1800 123 4567'), findsOneWidget);
      await tester.tap(find.text(te.faLoginForgot));
      await tester.pump();
      expect(t.launcher.calls, ['18001234567']);
    });

    testWidgets('shows English when the app is in English', (tester) async {
      await pumpFaScreen(
        tester,
        const LoginScreen(),
        signedIn: false,
        locale: const Locale('en'),
      );
      expect(orbitButton(en.faLoginLogIn), findsOneWidget);
      expect(find.text(en.faLoginLoginId), findsOneWidget);
    });
  });

  group('password needed', () {
    testWidgets('after "Use password": login ID prefilled, PIN offered', (
      tester,
    ) async {
      final t = await createFaTestAt(SessionPhase.passwordNeeded);
      await pumpFaScreen(tester, const LoginScreen(), test: t);
      expect(find.text(sureshLogin), findsOneWidget);
      expect(find.text(te.faLoginLockedTitle), findsNothing);

      await tester.tap(orbitButton(te.faLoginUsePin));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.locked);
    });

    testWidgets('logging in again goes straight back to the app', (
      tester,
    ) async {
      final t = await createFaTestAt(SessionPhase.passwordNeeded);
      await pumpFaApp(tester, test: t);
      await tester.enterText(_field(1), sureshPassword);
      await tester.pump();
      await tester.tap(orbitButton(te.faLoginLogIn));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.active);
      expect(currentPath(t.router), AppRoutes.farmers);
    });

    testWidgets('locked out: its banner, no PIN', (tester) async {
      final t = await createFaTestAt(SessionPhase.locked);
      await lockOut(t);
      expect(
        t.read(sessionProvider).passwordNeededReason,
        PasswordNeededReason.lockedOut,
      );
      await pumpFaScreen(tester, const LoginScreen(), test: t);
      expect(
        find.textContaining(te.faLoginLockedBody, findRichText: true),
        findsOneWidget,
      );
      expect(orbitButton(te.faLoginUsePin), findsNothing);
    });

    testWidgets('grace over: session ended banner', (tester) async {
      final t = await createFaTestAt(SessionPhase.active);
      testClock.advance(const Duration(days: 8));
      t.read(sessionProvider.notifier).lock();
      await tester.pump();
      await tester.pump();
      expect(
        t.read(sessionProvider).passwordNeededReason,
        PasswordNeededReason.expired,
      );
      await pumpFaScreen(tester, const LoginScreen(), test: t);
      expect(
        find.textContaining(te.faLoginExpiredBody(days: 7), findRichText: true),
        findsOneWidget,
      );
      expect(orbitButton(te.faLoginUsePin), findsNothing);
    });

    testWidgets('server session ended: banner and the PIN still works', (
      tester,
    ) async {
      final t = await createFaTestAt(SessionPhase.locked);
      t.read(authFailureHookProvider).report(unauthorized);
      await tester.pump();
      expect(
        t.read(sessionProvider).passwordNeededReason,
        PasswordNeededReason.sessionEnded,
      );
      await pumpFaScreen(tester, const LoginScreen(), test: t);
      expect(
        find.textContaining(te.faLoginEndedBody, findRichText: true),
        findsOneWidget,
      );
      await tester.tap(orbitButton(te.faLoginUsePin));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.locked);
    });

    testWidgets('another FA with unsynced records: asks, then replaces', (
      tester,
    ) async {
      final t = await createFaTestAt(SessionPhase.active);
      await queueRecords(tester, t);
      await t.read(sessionProvider.notifier).logout();
      selectScenario(t, MockScenario.normal);
      await pumpFaScreen(tester, const LoginScreen(), test: t);

      await _logIn(tester, 'FA-CVL-002', 'chevella2026');
      final body = te.faLoginOtherFaBody(count: 1, code: sureshLogin);
      expect(find.text(body), findsOneWidget);

      // Cancel keeps Suresh's record.
      await tester.tap(find.text(te.commonCancel));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.signedOut);
      expect(await t.read(sessionProvider.notifier).unsyncedCount(), 1);

      await tester.tap(orbitButton(te.faLoginLogIn));
      await tester.pumpAndSettle();
      await tester.tap(find.text(te.faLoginOtherFaConfirm));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.setup);
      expect(t.read(sessionProvider).fa?.code, 'FA-CVL-002');
      expect(await t.read(sessionProvider.notifier).unsyncedCount(), 0);
    });
  });

  testWidgets('splash shows the brand', (tester) async {
    await pumpFaScreen(tester, const SplashScreen(), signedIn: false);
    expect(find.text(te.commonAppName), findsOneWidget);
    expect(find.text(te.faAuthRole), findsOneWidget);
  });

  testWidgets('the PIN screen is where a locked app starts', (tester) async {
    final t = await createFaTestAt(SessionPhase.locked);
    await pumpFaApp(tester, test: t);
    expect(find.byType(UnlockScreen), findsOneWidget);
  });

  screenLayoutTest('login', () => const LoginScreen(), signedIn: false);
  screenLayoutTest(
    'login with the session-ended banner',
    () => const LoginScreen(),
    after: (tester, t) async {
      t.read(sessionProvider.notifier).lock();
      t.read(authFailureHookProvider).report(unauthorized);
      await tester.pumpAndSettle();
      expect(orbitButton(te.faLoginUsePin), findsOneWidget);
    },
  );

  testWidgets('screen readers hear the field labels', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpFaScreen(tester, const LoginScreen(), signedIn: false);
    expect(find.bySemanticsLabel(te.faLoginLoginId), findsOneWidget);
    expect(find.bySemanticsLabel(te.faLoginPassword), findsOneWidget);
    expect(find.bySemanticsLabel(te.faAuthShowPassword), findsOneWidget);
    semantics.dispose();
  });
  screenLayoutTest('splash', () => const SplashScreen(), signedIn: false);
  screenLayoutTest(
    'login with an error',
    () => const LoginScreen(),
    signedIn: false,
    after: (tester, t) => _logIn(tester, sureshLogin, 'wrong'),
  );
}
