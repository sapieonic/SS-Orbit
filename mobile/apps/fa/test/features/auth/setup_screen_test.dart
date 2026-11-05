import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/auth/setup_screen.dart';
import 'package:fa/src/features/farmers/farmers_screen.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'auth_test_support.dart';

Future<void> _toPin(WidgetTester tester, String nextLabel) async {
  await tester.tap(orbitButton(nextLabel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('language, PIN twice, summary, then Farmers', (tester) async {
    final t = await createFaTestAt(SessionPhase.setup);
    await pumpFaApp(tester, test: t);
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(find.text(te.faSetupQuestion), findsOneWidget);

    // English applies at once.
    await tester.tap(find.text(en.labelLanguage('en')));
    await tester.pumpAndSettle();
    expect(t.read(sessionProvider).language, Language.en);
    expect(find.text(en.faSetupQuestion), findsOneWidget);
    await tester.tap(find.text(te.labelLanguage('te')));
    await tester.pumpAndSettle();
    expect(t.read(sessionProvider).language, Language.te);
    expect(find.text(te.faSetupQuestion), findsOneWidget);

    await _toPin(tester, te.faSetupToPin);
    expect(find.text(te.faSetupPinPick), findsOneWidget);
    expect(find.text(te.faSetupPinHintFirst(days: 7)), findsOneWidget);

    await enterPin(tester, '1234');
    expect(find.text(te.faSetupPinWeak), findsOneWidget);
    await enterPin(tester, '1990');
    expect(find.text(te.faSetupPinYear), findsOneWidget);

    await enterPin(tester, testPin);
    expect(find.text(te.faSetupPinAgain), findsOneWidget);
    await enterPin(tester, '2581');
    expect(find.text(te.faSetupPinMismatch), findsOneWidget);
    expect(find.text(te.faSetupPinPick), findsOneWidget);

    await enterPin(tester, testPin);
    await enterPin(tester, testPin);

    // The summary shows before the PIN is saved (saving routes away).
    expect(t.phase, SessionPhase.setup);
    expect(find.text(te.faSetupTitleDone), findsOneWidget);
    expect(find.text(te.faSetupDoneTitle(name: 'సురేష్')), findsOneWidget);
    final territory = t.territory;
    expect(territory.farmerCount, 46);
    expect(
      find.textContaining(te.faAuthFarmersCount(count: 46)),
      findsOneWidget,
    );
    expect(
      find.textContaining(te.faAuthPlotsCount(count: territory.plotCount)),
      findsOneWidget,
    );
    expect(find.text(te.commonDone), findsOneWidget);

    await tester.tap(orbitButton(te.faSetupOpenFarmers));
    await tester.pumpAndSettle();
    expect(t.phase, SessionPhase.active);
    expect(currentPath(t.router), AppRoutes.farmers);
    expect(find.byType(FarmersScreen), findsOneWidget);
    // The PIN saved is the one typed.
    t.read(sessionProvider.notifier).lock();
    await tester.pumpAndSettle();
    expect(await t.read(sessionProvider.notifier).unlock(testPin), isTrue);
  });

  testWidgets('Back on the pad returns to the language', (tester) async {
    final t = await createFaTestAt(SessionPhase.setup);
    await pumpFaScreen(tester, const SetupScreen(), test: t);
    await _toPin(tester, te.faSetupToPin);
    await enterPin(tester, '25');
    await tester.tap(find.text(te.commonBack));
    await tester.pumpAndSettle();
    expect(find.text(te.faSetupQuestion), findsOneWidget);
  });

  testWidgets('offline: the download waits, the app still opens', (
    tester,
  ) async {
    final t = await createFaTestAt(SessionPhase.setup);
    selectScenario(t, MockScenario.offline);
    await pumpFaScreen(tester, const SetupScreen(), test: t);
    await _toPin(tester, te.faSetupToPin);
    await enterPin(tester, testPin);
    await enterPin(tester, testPin);
    expect(find.text(te.faSetupDownloadFailed), findsOneWidget);

    // Back online, Try again downloads.
    selectScenario(t, MockScenario.normal);
    await tester.tap(find.text(te.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text(te.faSetupDownloadFailed), findsNothing);
    expect(
      find.textContaining(te.faAuthFarmersCount(count: 46)),
      findsOneWidget,
    );

    await tester.tap(orbitButton(te.faSetupOpenFarmers));
    await tester.pumpAndSettle();
    expect(t.phase, SessionPhase.active);
  });

  testWidgets('a later login without a PIN is not "first login"', (
    tester,
  ) async {
    final t = await createFaTestAt(SessionPhase.locked);
    await lockOut(t);
    await t.read(sessionProvider.notifier).login(sureshLogin, sureshPassword);
    expect(t.phase, SessionPhase.setup);
    await pumpFaScreen(tester, const SetupScreen(), test: t);
    expect(find.text(te.faSetupStepAgain), findsOneWidget);
  });

  testWidgets('a temporary-password FA set up again is not "first login"', (
    tester,
  ) async {
    final t = await createFaTestAt(SessionPhase.mustChangePassword);
    final session = t.read(sessionProvider.notifier);
    await session.changePassword(tempPassword, 'kondapur7');
    await session.setPin('2580');
    session.lock();
    await lockOut(t);
    await session.login(tempLogin, 'kondapur7');
    expect(t.phase, SessionPhase.setup);
    // The password login brought a profile without the must-change flag.
    expect(t.read(sessionProvider).fa?.mustChangePassword, isFalse);
    await pumpFaScreen(tester, const SetupScreen(), test: t);
    expect(find.text(te.faSetupStepAgain), findsOneWidget);
    expect(find.text(te.faSetupStepFirst), findsNothing);
  });

  testWidgets('English', (tester) async {
    final t = await createFaTestAt(SessionPhase.setup);
    await t.read(sessionProvider.notifier).setLanguage(Language.en);
    await pumpFaApp(tester, test: t);
    expect(find.text(en.faSetupTitleLanguage), findsOneWidget);
    expect(orbitButton(en.faSetupToPin), findsOneWidget);
  });

  screenLayoutTest('setup language', () => const SetupScreen());
  screenLayoutTest(
    'setup PIN',
    () => const SetupScreen(),
    after: (tester, t) => _toPin(tester, te.faSetupToPin),
  );
  screenLayoutTest(
    'setup PIN with an error',
    () => const SetupScreen(),
    after: (tester, t) async {
      await _toPin(tester, te.faSetupToPin);
      await enterPin(tester, '1111');
    },
  );
  screenLayoutTest(
    'setup done',
    () => const SetupScreen(),
    after: (tester, t) async {
      await _toPin(tester, te.faSetupToPin);
      await enterPin(tester, testPin);
      await enterPin(tester, testPin);
      expect(find.byType(PinPad), findsNothing);
    },
  );
}
