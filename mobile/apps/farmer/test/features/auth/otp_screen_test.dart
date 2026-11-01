import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/auth/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

final _otp = find.byType(OtpInput);

String _typedCode(WidgetTester tester) =>
    tester.widget<OtpInput>(_otp).controller!.text;

OrbitButton _button(WidgetTester tester, String label) =>
    tester.widget<OrbitButton>(orbitButton(label));

/// Moves the shared test clock and puts it back after the test.
void _advanceClock(Duration by) {
  final start = testClock.now();
  addTearDown(() => testClock.set(start));
  testClock.advance(by);
}

void main() {
  testWidgets('shows the masked phone, the resend countdown and help', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.otpSent);
    await pumpScreen(tester, const OtpScreen(), container: container);

    expect(
      find.text(te.farmerLoginOtpSentTo(phone: maskPhone(newPhone))),
      findsOneWidget,
    );
    expect(find.text(te.farmerLoginChangeNumber), findsOneWidget);
    expect(find.text(te.farmerLoginNoOtp), findsOneWidget);
    // No SMS autofill yet: the hint says to type the code.
    expect(find.text(te.farmerLoginOtpHint), findsOneWidget);
    expect(
      _button(tester, te.farmerLoginResendIn(time: '0:30')).onPressed,
      isNull,
    );
    expect(_button(tester, te.farmerLoginVerify).onPressed, isNull);
  });

  testWidgets(
    'a wrong code clears the boxes and says how many tries are left',
    (tester) async {
      final container = await createContainerAt(SessionPhase.otpSent);
      await pumpScreen(tester, const OtpScreen(), container: container);

      await tester.enterText(_otp, '111111');
      await tester.pumpAndSettle();

      expect(find.textContaining(te.errorOtpInvalid), findsOneWidget);
      expect(
        find.textContaining(te.errorDetailAttemptsLeft(count: 4)),
        findsOneWidget,
      );
      expect(_typedCode(tester), isEmpty);
      expect(phaseOf(container), SessionPhase.otpSent);
    },
  );

  testWidgets('the right code signs in as soon as it is complete', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.otpSent);
    await pumpScreen(tester, const OtpScreen(), container: container);

    await tester.enterText(_otp, devOtp);
    await tester.pumpAndSettle();

    expect(phaseOf(container), SessionPhase.needsConsent);
  });

  testWidgets('Resend opens when the countdown ends', (tester) async {
    final container = await createContainerAt(SessionPhase.otpSent);
    await pumpScreen(tester, const OtpScreen(), container: container);

    _advanceClock(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    expect(orbitButton(te.farmerLoginResendIn(time: '0:18')), findsOneWidget);

    _advanceClock(const Duration(seconds: 18));
    await tester.pump(const Duration(seconds: 1));
    expect(_button(tester, te.farmerLoginResend).onPressed, isNotNull);
  });

  testWidgets('an expired code points at Resend, and a new code works', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.otpSent);
    await pumpScreen(tester, const OtpScreen(), container: container);

    _advanceClock(const Duration(minutes: 6));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(_otp, devOtp);
    await tester.pumpAndSettle();

    expect(find.text(te.errorOtpExpired), findsOneWidget);
    expect(phaseOf(container), SessionPhase.otpSent);
    final resend = _button(tester, te.farmerLoginResend);
    expect(resend.variant, OrbitButtonVariant.primary);
    expect(tester.widget<OtpInput>(_otp).enabled, isFalse);

    await tester.tap(orbitButton(te.farmerLoginResend));
    await tester.pumpAndSettle();
    expect(find.text(te.farmerLoginOtpSent), findsOneWidget);
    expect(find.text(te.errorOtpExpired), findsNothing);
    expect(orbitButton(te.farmerLoginResendIn(time: '0:30')), findsOneWidget);

    await tester.enterText(_otp, devOtp);
    await tester.pumpAndSettle();
    expect(phaseOf(container), SessionPhase.needsConsent);
  });

  testWidgets('Resend honours Retry-After from the server', (tester) async {
    // The server's clock lags the phone's: the app thinks Resend is open,
    // the server still says wait 30 s.
    final serverClock = FixedClock(testClock.now());
    final container = await createContainerAt(
      SessionPhase.otpSent,
      backend: MockBackend(clock: serverClock, latency: Duration.zero),
    );
    await pumpScreen(tester, const OtpScreen(), container: container);
    _advanceClock(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(orbitButton(te.farmerLoginResend));
    await tester.pumpAndSettle();

    expect(find.textContaining(te.errorRateLimited), findsOneWidget);
    expect(
      find.textContaining(te.errorDetailRetryAfterSeconds(count: 30)),
      findsOneWidget,
    );
    expect(orbitButton(te.farmerLoginResendIn(time: '0:30')), findsOneWidget);
  });

  testWidgets('"OTP not received?" offers the helpline', (tester) async {
    final container = await createContainerAt(SessionPhase.otpSent);
    await pumpScreen(tester, const OtpScreen(), container: container);

    await tester.tap(find.text(te.farmerLoginNoOtp));
    await tester.pumpAndSettle();

    expect(find.text(te.farmerLoginNoOtpHelp), findsOneWidget);
    expect(orbitButton(te.farmerLoginCallHelpline), findsOneWidget);
    expect(sheetVoiceKey(tester), VoiceKeys.farmerLoginVoiceHelpNoOtp);
  });

  testWidgets('"Change number" goes back to the phone step', (tester) async {
    final container = await createContainerAt(SessionPhase.otpSent);
    await pumpScreen(tester, const OtpScreen(), container: container);

    await tester.tap(find.text(te.farmerLoginChangeNumber));
    await tester.pump();

    expect(phaseOf(container), SessionPhase.signedOut);
    expect(container.read(sessionProvider).phone, '+91$newPhone');
  });

  testWidgets('system Back also goes back to the phone step', (tester) async {
    final container = await createContainerAt(SessionPhase.otpSent);
    await pumpScreen(tester, const OtpScreen(), container: container);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(phaseOf(container), SessionPhase.signedOut);
  });

  testWidgets('system Back waits while the code is being checked', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await createContainerAt(
      SessionPhase.otpSent,
      backend: backend,
    );
    await pumpScreen(tester, const OtpScreen(), container: container);

    backend.latency = const Duration(milliseconds: 300);
    await tester.enterText(_otp, '000000'); // a wrong code
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(phaseOf(container), SessionPhase.otpSent);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    backend.latency = Duration.zero;
    expect(phaseOf(container), SessionPhase.otpSent);
    expect(find.textContaining(te.errorOtpInvalid), findsOneWidget);

    // Not busy any more: Back works again.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(phaseOf(container), SessionPhase.signedOut);
  });

  testWidgets('offline: the code stays for another try', (tester) async {
    final container = await createContainerAt(
      SessionPhase.otpSent,
      scenario: MockScenario.offline,
    );
    await pumpScreen(tester, const OtpScreen(), container: container);

    await tester.enterText(_otp, devOtp);
    await tester.pumpAndSettle();

    expect(find.text(te.errorNetwork), findsOneWidget);
    expect(_typedCode(tester), devOtp);
    expect(_button(tester, te.farmerLoginVerify).onPressed, isNotNull);
  });

  testWidgets('renders in English', (tester) async {
    final container = await createContainerAt(SessionPhase.otpSent);
    await pumpScreen(
      tester,
      const OtpScreen(),
      container: container,
      locale: const Locale('en'),
    );
    expect(find.text(en.farmerLoginOtpTitle), findsOneWidget);
    expect(orbitButton(en.farmerLoginVerify), findsOneWidget);
  });

  screenLayoutTest('OTP', () => const OtpScreen(), phase: SessionPhase.otpSent);
  screenLayoutTest(
    'OTP not received sheet',
    () => const OtpScreen(),
    phase: SessionPhase.otpSent,
    after: (tester) async {
      await tester.tap(find.text(te.farmerLoginNoOtp));
      await tester.pumpAndSettle();
    },
  );
  screenLayoutTest(
    'OTP after a wrong code',
    () => const OtpScreen(),
    phase: SessionPhase.otpSent,
    after: (tester) async {
      await tester.enterText(_otp, '111111');
      await tester.pumpAndSettle();
      expect(find.textContaining(te.errorOtpInvalid), findsOneWidget);
    },
  );
}
