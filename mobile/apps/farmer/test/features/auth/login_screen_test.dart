import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/auth/login_screen.dart';
import 'package:farmer/src/shared/launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import '../../support/session_support.dart' show CountingStore;

OrbitButton _sendButton(WidgetTester tester) =>
    tester.widget<OrbitButton>(orbitButton(te.farmerLoginSendOtp));

void main() {
  testWidgets('shows the app name, tag line, language chips and helpline', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.signedOut);
    await pumpScreen(tester, const LoginScreen(), container: container);

    expect(find.text(te.commonAppName), findsOneWidget);
    expect(find.text(te.farmerLoginTagline), findsOneWidget);
    expect(find.text('తెలుగు'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text(te.farmerLoginPhoneTitle), findsOneWidget);
    expect(find.textContaining(formatHelpline('18001234567')), findsOneWidget);
    // "OTP not received?" belongs to the code step only.
    expect(find.text(te.farmerLoginNoOtp), findsNothing);
    expect(_sendButton(tester).onPressed, isNull);
  });

  testWidgets('the helpline line dials it, or says the number to dial', (
    tester,
  ) async {
    final launcher = FakeContactLauncher(opens: false);
    final container = await createContainerAt(
      SessionPhase.signedOut,
      launcher: launcher,
    );
    await pumpScreen(tester, const LoginScreen(), container: container);

    await scrollAndTap(
      tester,
      find.textContaining(formatHelpline(helplinePhone)),
    );
    expect(launcher.calls, [helplinePhone]);
    expect(
      find.text(te.farmerFasCallFailed(phone: formatHelpline(helplinePhone))),
      findsOneWidget,
    );
  });

  testWidgets('Send OTP is enabled only for a valid Indian mobile', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.signedOut);
    await pumpScreen(tester, const LoginScreen(), container: container);

    await tester.enterText(find.byType(PhoneField), '98765');
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNull);
    expect(find.text(te.farmerLoginPhoneInvalid), findsNothing);

    await tester.enterText(find.byType(PhoneField), '5876543210');
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNull);
    expect(find.text(te.farmerLoginPhoneInvalid), findsOneWidget);

    await tester.enterText(find.byType(PhoneField), '+91 98765 43210');
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNotNull);
    expect(find.text(te.farmerLoginPhoneInvalid), findsNothing);
  });

  testWidgets('sending the OTP moves the session to the code step', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.signedOut);
    await pumpScreen(tester, const LoginScreen(), container: container);

    await tester.enterText(find.byType(PhoneField), newPhone);
    await tester.pump();
    await tester.tap(orbitButton(te.farmerLoginSendOtp));
    await tester.pumpAndSettle();

    expect(phaseOf(container), SessionPhase.otpSent);
    expect(container.read(sessionProvider).phone, '+91$newPhone');
  });

  testWidgets('offline: the error is shown in place and nothing moves', (
    tester,
  ) async {
    final container = await createContainerAt(
      SessionPhase.signedOut,
      scenario: MockScenario.offline,
    );
    await pumpScreen(tester, const LoginScreen(), container: container);

    await tester.enterText(find.byType(PhoneField), newPhone);
    await tester.pump();
    await tester.tap(orbitButton(te.farmerLoginSendOtp));
    await tester.pumpAndSettle();

    expect(find.text(te.errorNetwork), findsOneWidget);
    expect(phaseOf(container), SessionPhase.signedOut);
  });

  testWidgets('rate limited: says how many seconds to wait', (tester) async {
    // Ask for a code, go back, and ask again at once: the server says wait.
    final container = await createContainerAt(SessionPhase.otpSent);
    container.read(sessionProvider.notifier).editPhone();
    await pumpScreen(tester, const LoginScreen(), container: container);

    // The number comes back prefilled after "Change number".
    expect(find.text(newPhone), findsOneWidget);
    await tester.tap(orbitButton(te.farmerLoginSendOtp));
    await tester.pumpAndSettle();

    expect(find.textContaining(te.errorRateLimited), findsOneWidget);
    expect(
      find.textContaining(te.errorDetailRetryAfterSeconds(count: 30)),
      findsOneWidget,
    );
    expect(phaseOf(container), SessionPhase.signedOut);
  });

  testWidgets('the English chip switches the session language', (tester) async {
    final container = await createContainerAt(SessionPhase.signedOut);
    await pumpScreen(tester, const LoginScreen(), container: container);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(container.read(appLanguageProvider), Language.en);

    await tester.tap(find.text('తెలుగు'));
    await tester.pumpAndSettle();
    expect(container.read(appLanguageProvider), Language.te);
  });

  testWidgets('a language the phone cannot save still switches, and says '
      'why in the new language', (tester) async {
    final store = CountingStore();
    final container = await createTestContainer(signedIn: false, store: store);
    await pumpScreen(tester, const LoginScreen(), container: container);
    store.failLanguageWrites = true;

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(appLanguageProvider), Language.en);
    expect(find.text(en.errorUnknown), findsOneWidget);
  });

  group('the dev menu entry shows only on mock data', () {
    testWidgets('mock data: shown', (tester) async {
      final container = await createContainerAt(SessionPhase.signedOut);
      await pumpScreen(tester, const LoginScreen(), container: container);
      expect(find.byTooltip('Developer tools'), findsOneWidget);
    });

    testWidgets('the real API (no mock scenario): hidden', (tester) async {
      final container = await createContainerAt(
        SessionPhase.signedOut,
        overrides: [mockScenarioProvider.overrideWith(_NoMockScenario.new)],
      );
      await pumpScreen(tester, const LoginScreen(), container: container);
      expect(find.byTooltip('Developer tools'), findsNothing);
      expect(orbitButton(te.farmerLoginSendOtp), findsOneWidget);
    });
  });

  testWidgets('renders in English', (tester) async {
    final container = await createContainerAt(SessionPhase.signedOut);
    await pumpScreen(
      tester,
      const LoginScreen(),
      container: container,
      locale: const Locale('en'),
    );
    expect(orbitButton(en.farmerLoginSendOtp), findsOneWidget);
    expect(find.text(en.farmerLoginTagline), findsOneWidget);
  });

  screenLayoutTest(
    'login, empty',
    () => const LoginScreen(),
    phase: SessionPhase.signedOut,
  );
  screenLayoutTest(
    'login, with an error',
    () => const LoginScreen(),
    phase: SessionPhase.signedOut,
    scenario: MockScenario.offline,
    after: (tester) async {
      await tester.enterText(find.byType(PhoneField), newPhone);
      await tester.pump();
      await tester.tap(orbitButton(te.farmerLoginSendOtp));
      await tester.pumpAndSettle();
      expect(find.text(te.errorNetwork), findsOneWidget);
    },
  );
}

/// What the scenario switch says when the app runs on the real API.
class _NoMockScenario extends MockScenarioController {
  @override
  MockScenario? build() => null;
}
