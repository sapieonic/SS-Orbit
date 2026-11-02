import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/auth/unlock_screen.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'auth_test_support.dart';

void main() {
  testWidgets('greets the FA; the right PIN opens the app', (tester) async {
    final t = await createFaTestAt(SessionPhase.locked);
    await pumpFaApp(tester, test: t);
    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(find.text(te.faUnlockWelcome(name: 'సురేష్')), findsOneWidget);
    expect(find.textContaining(sureshLogin), findsOneWidget);
    expect(statusPill(te.faAuthOnline), findsOneWidget);
    expect(find.text(te.faUnlockEnterPin(length: 4)), findsOneWidget);
    expect(find.text(te.faUnlockGraceNote(days: 7)), findsOneWidget);
    // No biometric service yet: no fingerprint key.
    expect(find.byIcon(OrbitIcons.fingerprint), findsNothing);

    await enterPin(tester, testPin);
    expect(t.phase, SessionPhase.active);
    expect(currentPath(t.router), AppRoutes.farmers);
  });

  testWidgets('a wrong PIN says how many tries are left', (tester) async {
    final t = await createFaTestAt(SessionPhase.locked);
    await pumpFaScreen(tester, const UnlockScreen(), test: t);
    await enterPin(tester, '0000');
    expect(t.phase, SessionPhase.locked);
    expect(
      find.text('${te.faUnlockWrongPin} · ${te.faUnlockTriesLeft(count: 4)}'),
      findsOneWidget,
    );
    final dots = tester.widget<PinDots>(find.byType(PinDots));
    expect(dots.error, isTrue);
    expect(dots.filled, 0);

    // Typing again clears the error; the tries stay shown.
    await enterPin(tester, '1');
    expect(find.text(te.faUnlockTriesLeft(count: 4)), findsOneWidget);
    expect(tester.widget<PinDots>(find.byType(PinDots)).error, isFalse);
  });

  testWidgets('five wrong PINs need the password', (tester) async {
    final t = await createFaTestAt(SessionPhase.locked);
    await pumpFaApp(tester, test: t);
    for (var i = 0; i < 5; i++) {
      await enterPin(tester, '0000');
    }
    expect(t.phase, SessionPhase.passwordNeeded);
    expect(
      t.read(sessionProvider).passwordNeededReason,
      PasswordNeededReason.lockedOut,
    );
    expect(currentPath(t.router), AppRoutes.login);
  });

  testWidgets('offline pill without network', (tester) async {
    final t = await createFaTestAt(SessionPhase.locked);
    selectScenario(t, MockScenario.offline);
    await pumpFaScreen(tester, const UnlockScreen(), test: t);
    expect(statusPill(te.faAuthOfflineSaved), findsOneWidget);
    await enterPin(tester, testPin);
    expect(t.phase, SessionPhase.active);
  });

  testWidgets('Use password instead', (tester) async {
    final t = await createFaTestAt(SessionPhase.locked);
    await pumpFaScreen(tester, const UnlockScreen(), test: t);
    await scrollAndTap(tester, find.text(te.faUnlockUsePassword));
    expect(t.phase, SessionPhase.passwordNeeded);
    expect(t.read(sessionProvider).passwordNeededReason, isNull);
  });

  testWidgets('English', (tester) async {
    final t = await createFaTestAt(SessionPhase.locked);
    await pumpFaScreen(
      tester,
      const UnlockScreen(),
      test: t,
      locale: const Locale('en'),
    );
    expect(find.text(en.faUnlockWelcome(name: 'Suresh')), findsOneWidget);
  });

  for (final scale in textScales) {
    testWidgets('unlock with an error fits 360x640 at text scale $scale', (
      tester,
    ) async {
      final t = await createFaTestAt(SessionPhase.locked);
      selectScenario(t, MockScenario.offline);
      await pumpFaScreen(
        tester,
        const UnlockScreen(),
        test: t,
        textScale: scale,
      );
      await enterPin(tester, '0000');
      expectCleanLayout(tester);
    });
  }
}
