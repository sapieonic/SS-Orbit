import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/me/change_password_page.dart';
import 'package:fa/src/features/me/change_pin_page.dart';
import 'package:fa/src/features/me/me_screen.dart';
import 'package:fa/src/features/me/me_stats.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import '../auth/auth_test_support.dart';

Future<FaTest> _pumpMe(
  WidgetTester tester, {
  FaTest? test,
  Locale locale = const Locale('te'),
}) => pumpFaScreen(
  tester,
  const MeScreen(),
  test: test,
  location: AppRoutes.me,
  locale: locale,
);

void main() {
  group('profile and counts', () {
    testWidgets('shows the FA, the area and this month', (tester) async {
      final t = await _pumpMe(tester);
      expect(find.text('సురేష్ కుమార్'), findsOneWidget);
      expect(find.text('$sureshLogin · 98480 12345'), findsOneWidget);
      expect(find.textContaining(te.faMeArea(area: '')), findsOneWidget);
      expect(find.text('46'), findsOneWidget);
      expect(find.text(te.faMeStatFarmers(count: 46)), findsOneWidget);
      final stats = t.read(meStatsProvider)!;
      expect(find.text(te.faMeStatVisits(month: 'నవం')), findsOneWidget);
      expect(find.text('${stats.visits}'), findsWidgets);
    });

    test('counts visits and enrolments of the IST month', () async {
      final t = await createFaTest();
      final stats = MeStats.of(t.territory, LocalDate(2026, 11, 2));
      expect(stats.farmers, 46);
      // Sita R today, Lakshmi N and Gopi M yesterday (1 Nov).
      expect(stats.visits, 3);
      final october = MeStats.of(t.territory, LocalDate(2026, 10, 15));
      expect(october.visits, greaterThan(stats.visits));
      expect(stats.enrolled + october.enrolled, greaterThan(0));
    });

    test('short phone ID', () {
      expect(shortPhoneId('fa-0123456789abcdef7f3a'), '7F3A');
      expect(shortPhoneId('ab'), 'AB');
    });

    testWidgets('footer: version and phone ID', (tester) async {
      await _pumpMe(tester);
      await tester.scrollUntilVisible(
        find.textContaining('0.1.0'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining(RegExp(r'0\.1\.0 · .* [0-9A-F]{4}$')),
        findsOneWidget,
      );
    });
  });

  group('settings', () {
    testWidgets('language switches the app', (tester) async {
      final t = await _pumpMe(tester);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(t.read(sessionProvider).language, Language.en);
    });

    testWidgets('photos on Wi-Fi only is the engine setting', (tester) async {
      final t = await _pumpMe(tester);
      expect(t.read(syncStateProvider).photosOnWifiOnly, isTrue);
      expect(find.text(te.faMeWifiOn), findsOneWidget);
      await tester.tap(find.text(te.faMeWifi));
      await tester.pumpAndSettle();
      expect(t.read(syncStateProvider).photosOnWifiOnly, isFalse);
      expect(find.text(te.faMeWifiOff), findsOneWidget);
      // Every action nudges the engine (a short timer).
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('Sync opens Sync', (tester) async {
      final t = await _pumpMe(tester);
      await scrollAndTap(tester, find.text(te.faShellTitleSync));
      expect(currentPath(t.router), AppRoutes.sync);
    });

    testWidgets('Call HO dials the helpline', (tester) async {
      final t = await _pumpMe(tester);
      await scrollAndTap(tester, find.text(te.faMeCallHo));
      expect(t.launcher.calls, ['18001234567']);
    });

    testWidgets('Dev menu in dev builds', (tester) async {
      final t = await _pumpMe(tester);
      await scrollAndTap(tester, find.text(te.faShellTitleDev));
      expect(currentPath(t.router), AppRoutes.dev);
    });

    testWidgets('server session ended: Log in now', (tester) async {
      final t = await createFaTest();
      t.read(authFailureHookProvider).report(unauthorized);
      await _pumpMe(tester, test: t);
      expect(
        find.textContaining(te.faMeNeedsPasswordBody, findRichText: true),
        findsOneWidget,
      );
      await tester.tap(orbitButton(te.faMeLogInNow));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.passwordNeeded);
      expect(
        t.read(sessionProvider).passwordNeededReason,
        PasswordNeededReason.sessionEnded,
      );
    });
  });

  group('change PIN', () {
    Future<FaTest> open(WidgetTester tester) async {
      final t = await _pumpMe(tester);
      await scrollAndTap(tester, find.text(te.faMeChangePin));
      expect(find.byType(ChangePinPage), findsOneWidget);
      return t;
    }

    testWidgets('old PIN, new twice, then back on Me', (tester) async {
      final t = await open(tester);
      expect(find.text(te.faChangePinOld), findsOneWidget);
      await enterPin(tester, testPin);
      expect(find.text(te.faChangePinNew), findsOneWidget);
      await enterPin(tester, '1111');
      expect(find.text(te.faSetupPinWeak), findsOneWidget);
      await enterPin(tester, '1357');
      expect(find.text(te.faChangePinAgain), findsOneWidget);
      await enterPin(tester, '1357');

      expect(find.byType(ChangePinPage), findsNothing);
      expect(find.byType(MeScreen), findsOneWidget);
      expect(find.text(te.faChangePinChanged), findsOneWidget);
      final session = t.read(sessionProvider.notifier)..lock();
      expect(await session.unlock('1357'), isTrue);
    });

    testWidgets('a wrong current PIN costs a try and starts over', (
      tester,
    ) async {
      final t = await open(tester);
      await enterPin(tester, '0000');
      await enterPin(tester, '1357');
      await enterPin(tester, '1357');
      expect(find.byType(ChangePinPage), findsOneWidget);
      expect(find.text(te.faChangePinOld), findsOneWidget);
      expect(
        find.text(
          '${te.faChangePinWrongOld} · ${te.faUnlockTriesLeft(count: 4)}',
        ),
        findsOneWidget,
      );
      expect(t.read(sessionProvider).pinAttemptsLeft, 4);
    });

    testWidgets('a different confirm asks for the new PIN again', (
      tester,
    ) async {
      await open(tester);
      await enterPin(tester, testPin);
      await enterPin(tester, '1357');
      await enterPin(tester, '1358');
      expect(find.text(te.faSetupPinMismatch), findsOneWidget);
      expect(find.text(te.faChangePinNew), findsOneWidget);
    });

    testWidgets('back returns to Me', (tester) async {
      await open(tester);
      await tester.tap(find.byIcon(OrbitIcons.back));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePinPage), findsNothing);
      expect(find.byType(MeScreen), findsOneWidget);
    });
  });

  testWidgets('change password, then back on Me', (tester) async {
    final t = await _pumpMe(tester);
    await scrollAndTap(tester, find.text(te.faMeChangePassword));
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    expect(find.text(te.faNewPasswordCurrent), findsOneWidget);
    expect(find.text(te.faNewPasswordNote, findRichText: true), findsNothing);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), sureshPassword);
    await tester.enterText(fields.at(1), 'kondapur7');
    await tester.enterText(fields.at(2), 'kondapur7');
    await tester.pump();
    await scrollAndTap(tester, orbitButton(te.faNewPasswordSave));
    expect(find.byType(ChangePasswordPage), findsNothing);
    expect(find.text(te.faMePasswordSaved), findsOneWidget);
    expect(t.phase, SessionPhase.active);
  });

  testWidgets('change password after the session ended: not "wrong password"', (
    tester,
  ) async {
    final t = await _pumpMe(tester);
    t.selectScenario(MockScenario.sessionExpired);
    await scrollAndTap(tester, find.text(te.faMeChangePassword));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), sureshPassword);
    await tester.enterText(fields.at(1), 'kondapur7');
    await tester.enterText(fields.at(2), 'kondapur7');
    await tester.pump();
    await scrollAndTap(tester, orbitButton(te.faNewPasswordSave));
    expect(find.text(te.faNewPasswordWrongCurrent), findsNothing);
    expect(t.read(sessionProvider).syncNeedsPassword, isTrue);
  });

  group('log out', () {
    testWidgets('nothing unsynced: asks, then logs out', (tester) async {
      final t = await _pumpMe(tester);
      await scrollAndTap(tester, orbitButton(te.faCommonLogOut));
      expect(find.text(te.faMeLogoutTitle), findsOneWidget);
      await tester.tap(find.text(te.faCommonLogOut).last);
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.signedOut);
    });

    testWidgets('unsynced records: warns; Sync now or log out anyway', (
      tester,
    ) async {
      final t = await createFaTest();
      await queueRecords(tester, t, count: 2);
      await _pumpMe(tester, test: t);
      await scrollAndTap(tester, orbitButton(te.faCommonLogOut));
      expect(
        find.textContaining(
          te.faMeLogoutUnsynced(count: 2),
          findRichText: true,
        ),
        findsOneWidget,
      );

      await scrollAndTap(tester, orbitButton(te.faMeSyncNow));
      expect(currentPath(t.router), AppRoutes.sync);
      t.router.pop();
      await tester.pumpAndSettle();

      await scrollAndTap(tester, orbitButton(te.faCommonLogOut));
      await scrollAndTap(tester, orbitButton(te.faMeLogoutAnyway));
      expect(t.phase, SessionPhase.signedOut);
      // They stay on the phone and go up after the next login.
      expect(await t.read(sessionProvider.notifier).unsyncedCount(), 2);
    });
  });

  testWidgets('English', (tester) async {
    await _pumpMe(tester, locale: const Locale('en'));
    expect(find.text(en.faMeSubtitle), findsOneWidget);
    expect(find.text('Suresh Kumar'), findsOneWidget);
    expect(find.text(en.faMeStatVisits(month: 'Nov')), findsOneWidget);
  });

  screenLayoutTest('Me', () => const MeScreen(), location: AppRoutes.me);
  screenLayoutTest(
    'Me with the logout warning',
    () => const MeScreen(),
    location: AppRoutes.me,
    after: (tester, t) async {
      await queueRecords(tester, t);
      await scrollAndTap(tester, orbitButton(te.faCommonLogOut));
      expect(orbitButton(te.faMeLogoutAnyway), findsOneWidget);
    },
  );
  screenLayoutTest(
    'change PIN',
    () => const ChangePinPage(),
    after: (tester, t) => enterPin(tester, '0'),
  );
  screenLayoutTest('change password', () => const ChangePasswordPage());
}
