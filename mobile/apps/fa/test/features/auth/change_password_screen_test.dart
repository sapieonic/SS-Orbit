import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/auth/change_password_screen.dart';
import 'package:fa/src/features/auth/setup_screen.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';
import 'auth_test_support.dart';

const _newPassword = 'kondapur7';

Finder _field(int index) => find.byType(TextField).at(index);

EditableText _editable(WidgetTester tester, int index) =>
    tester.widget<EditableText>(
      find.descendant(of: _field(index), matching: find.byType(EditableText)),
    );

void main() {
  testWidgets('after the login: new password twice, then setup says saved', (
    tester,
  ) async {
    final t = await pumpFaApp(tester, signedIn: false);
    await tester.enterText(find.byType(TextField).at(0), tempLogin);
    await tester.enterText(find.byType(TextField).at(1), tempPassword);
    await tester.pump();
    await tester.tap(orbitButton(te.faLoginLogIn));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.text(te.faNewPasswordNote, findRichText: true), findsOneWidget);
    // The temporary password from the login is reused: two boxes only.
    expect(find.byType(TextField), findsNWidgets(2));
    OrbitButtonFinder.expectDisabled(tester, te.faNewPasswordSave);

    await tester.enterText(_field(0), _newPassword);
    await tester.enterText(_field(1), _newPassword);
    await tester.pump();
    OrbitButtonFinder.expectEnabled(tester, te.faNewPasswordSave);
    await scrollAndTap(tester, orbitButton(te.faNewPasswordSave));

    expect(t.phase, SessionPhase.setup);
    expect(currentPath(t.router), AppRoutes.setup);
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(
      find.textContaining(
        te.faSetupPasswordSaved(code: tempLogin),
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text(te.faSetupStepFirst), findsOneWidget);
  });

  testWidgets('after a restart it asks for the temporary password', (
    tester,
  ) async {
    final t = await createFaTestAt(SessionPhase.mustChangePassword);
    await pumpFaScreen(tester, const ChangePasswordScreen(), test: t);
    expect(find.text(te.faNewPasswordCurrentTemp), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.enterText(_field(0), tempPassword);
    await tester.enterText(_field(1), _newPassword);
    await tester.enterText(_field(2), _newPassword);
    await tester.pump();
    await scrollAndTap(tester, orbitButton(te.faNewPasswordSave));
    expect(t.phase, SessionPhase.setup);
  });

  testWidgets('the rules follow what is typed', (tester) async {
    final t = await createFaTestAt(SessionPhase.mustChangePassword);
    await pumpFaScreen(tester, const ChangePasswordScreen(), test: t);
    await tester.enterText(_field(0), tempPassword);

    Future<void> type(String next, String again) async {
      await tester.enterText(_field(1), next);
      await tester.enterText(_field(2), again);
      await tester.pump();
    }

    // Each rule reads "<rule>, done" or "<rule>, not yet".
    bool done(String rule) => tester
        .widget<Semantics>(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label ?? '').startsWith('$rule, '),
          ),
        )
        .properties
        .label!
        .endsWith(te.faNewPasswordRuleDone);

    await type('short', 'short');
    expect(done(te.faNewPasswordRuleLength), isFalse);
    expect(done(te.faNewPasswordRuleMatch), isTrue);
    OrbitButtonFinder.expectDisabled(tester, te.faNewPasswordSave);

    await type('onlyletters', 'onlyletters');
    expect(done(te.faNewPasswordRuleLength), isTrue);
    expect(done(te.faNewPasswordRuleLetterDigit), isFalse);

    await type('${tempLogin.toLowerCase()}9', '${tempLogin.toLowerCase()}9');
    expect(done(te.faNewPasswordRuleLoginId), isFalse);
    OrbitButtonFinder.expectDisabled(tester, te.faNewPasswordSave);

    await type(tempPassword, tempPassword);
    expect(done(te.faNewPasswordRuleCurrent), isFalse);

    await type(_newPassword, 'kondapur8');
    expect(done(te.faNewPasswordRuleMatch), isFalse);
    OrbitButtonFinder.expectDisabled(tester, te.faNewPasswordSave);

    await type(_newPassword, _newPassword);
    for (final rule in [
      te.faNewPasswordRuleLength,
      te.faNewPasswordRuleLetterDigit,
      te.faNewPasswordRuleLoginId,
      te.faNewPasswordRuleCurrent,
      te.faNewPasswordRuleMatch,
    ]) {
      expect(done(rule), isTrue, reason: rule);
    }
    OrbitButtonFinder.expectEnabled(tester, te.faNewPasswordSave);
  });

  testWidgets('Show reveals both boxes', (tester) async {
    final t = await createFaTestAt(SessionPhase.mustChangePassword);
    await pumpFaScreen(tester, const ChangePasswordScreen(), test: t);
    expect(_editable(tester, 1).obscureText, isTrue);
    expect(_editable(tester, 2).obscureText, isTrue);
    // The current password's own toggle, then the new one's.
    await tester.tap(find.text(te.faAuthShow).at(1));
    await tester.pump();
    expect(_editable(tester, 1).obscureText, isFalse);
    expect(_editable(tester, 2).obscureText, isFalse);
    expect(_editable(tester, 0).obscureText, isTrue);
  });

  testWidgets('a wrong temporary password asks again', (tester) async {
    final t = await createFaTestAt(SessionPhase.mustChangePassword);
    await pumpFaScreen(tester, const ChangePasswordScreen(), test: t);
    await tester.enterText(_field(0), 'not-it-1');
    await tester.enterText(_field(1), _newPassword);
    await tester.enterText(_field(2), _newPassword);
    await tester.pump();
    await scrollAndTap(tester, orbitButton(te.faNewPasswordSave));
    expect(find.text(te.faNewPasswordWrongTemp), findsOneWidget);
    expect(t.phase, SessionPhase.mustChangePassword);
  });

  testWidgets('offline: needs network', (tester) async {
    final t = await createFaTestAt(SessionPhase.mustChangePassword);
    selectScenario(t, MockScenario.offline);
    await pumpFaScreen(tester, const ChangePasswordScreen(), test: t);
    await tester.enterText(_field(0), tempPassword);
    await tester.enterText(_field(1), _newPassword);
    await tester.enterText(_field(2), _newPassword);
    await tester.pump();
    await scrollAndTap(tester, orbitButton(te.faNewPasswordSave));
    expect(find.text(te.faNewPasswordOffline), findsOneWidget);
    expect(t.phase, SessionPhase.mustChangePassword);
  });

  testWidgets('back asks, then logs out', (tester) async {
    final t = await createFaTestAt(SessionPhase.mustChangePassword);
    await pumpFaScreen(tester, const ChangePasswordScreen(), test: t);
    await tester.tap(find.byTooltip(te.faNewPasswordBackLabel));
    await tester.pumpAndSettle();
    expect(find.text(te.faNewPasswordLeaveTitle), findsOneWidget);
    await tester.tap(find.text(te.commonCancel));
    await tester.pumpAndSettle();
    expect(t.phase, SessionPhase.mustChangePassword);

    await systemBack(tester);
    expect(find.text(te.faNewPasswordLeaveTitle), findsOneWidget);
    await tester.tap(find.text(te.faCommonLogOut));
    await tester.pumpAndSettle();
    expect(t.phase, SessionPhase.signedOut);
  });

  testWidgets('English', (tester) async {
    final t = await createFaTestAt(SessionPhase.mustChangePassword);
    await pumpFaScreen(
      tester,
      const ChangePasswordScreen(),
      test: t,
      locale: const Locale('en'),
    );
    expect(find.text(en.faNewPasswordTitle), findsOneWidget);
    expect(orbitButton(en.faNewPasswordSave), findsOneWidget);
  });

  screenLayoutTest('new password', () => const ChangePasswordScreen());
  screenLayoutTest(
    'new password with an error',
    () => const ChangePasswordScreen(),
    after: (tester, t) async {
      selectScenario(t, MockScenario.offline);
      await tester.enterText(_field(0), sureshPassword);
      await tester.enterText(_field(1), _newPassword);
      await tester.enterText(_field(2), _newPassword);
      await tester.pump();
      await scrollAndTap(tester, orbitButton(te.faNewPasswordSave));
    },
  );
}
