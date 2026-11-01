import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/auth/login_screen.dart';
import 'package:farmer/src/features/auth/otp_screen.dart';
import 'package:farmer/src/features/dev/dev_screen.dart';
import 'package:farmer/src/features/onboarding/consent_screen.dart';
import 'package:farmer/src/features/onboarding/name_screen.dart';
import 'package:farmer/src/features/onboarding/village_screen.dart';
import 'package:farmer/src/routing/router.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

Future<void> _sendOtp(WidgetTester tester, String phone, String label) async {
  await tester.enterText(find.byType(PhoneField), phone);
  await tester.pump();
  await tester.tap(orbitButton(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new phone signs up end to end in Telugu and lands on Home', (
    tester,
  ) async {
    final container = await createContainerAt(SessionPhase.signedOut);
    await pumpFarmerApp(tester, container: container);
    expect(find.byType(LoginScreen), findsOneWidget);

    // Phone.
    await _sendOtp(tester, newPhone, te.farmerLoginSendOtp);
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(currentPath(container.read(routerProvider)), Routes.otp);

    // Wrong code first: stays, with the tries left.
    await tester.enterText(find.byType(OtpInput), '111111');
    await tester.pumpAndSettle();
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(
      find.textContaining(te.errorDetailAttemptsLeft(count: 4)),
      findsOneWidget,
    );

    // Right code: a new farmer goes to consent.
    await tester.enterText(find.byType(OtpInput), devOtp);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);

    // Consent is stored before the village is picked.
    await tester.tap(orbitButton(te.farmerConsentAgree));
    await tester.pumpAndSettle();
    expect(find.byType(VillageScreen), findsOneWidget);
    final consents = await container
        .read(farmerProfileRepositoryProvider)
        .listConsents();
    expect(
      consents
          .singleWhere((c) => c.purpose == ConsentPurpose.programme)
          .granted,
      isTrue,
    );

    // Village search.
    await tester.enterText(find.byType(TextField), 'కొండా');
    await tester.pump(villageSearchDebounce);
    await tester.pumpAndSettle();
    await tester.tap(find.text('కొండాపూర్'));
    await tester.pumpAndSettle();
    expect(find.byType(NameScreen), findsOneWidget);

    // Name, then Home.
    await tester.enterText(find.byType(TextField), 'రాము');
    await tester.tap(orbitButton(te.farmerNameFinish));
    await tester.pumpAndSettle();

    expect(phaseOf(container), SessionPhase.active);
    expect(currentPath(container.read(routerProvider)), Routes.home);
    final home = await container
        .read(farmerProfileRepositoryProvider)
        .getHome();
    expect(home.farmer.nameTe, 'రాము');
    expect(home.farmer.status, FarmerStatus.active);
  });

  testWidgets('Ravi signs in and lands straight on Home', (tester) async {
    final container = await createContainerAt(SessionPhase.signedOut);
    await pumpFarmerApp(tester, container: container);

    await _sendOtp(tester, raviPhone, te.farmerLoginSendOtp);
    await tester.enterText(find.byType(OtpInput), devOtp);
    await tester.pumpAndSettle();

    expect(phaseOf(container), SessionPhase.active);
    expect(currentPath(container.read(routerProvider)), Routes.home);
  });

  testWidgets('the language chip switches the whole app live', (tester) async {
    final container = await createContainerAt(SessionPhase.signedOut);
    await pumpFarmerApp(tester, container: container);
    expect(orbitButton(te.farmerLoginSendOtp), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(orbitButton(en.farmerLoginSendOtp), findsOneWidget);
    expect(find.text(en.farmerLoginPhoneTitle), findsOneWidget);

    // The OTP SMS is asked for in English too, and the next screen is English.
    await _sendOtp(tester, newPhone, en.farmerLoginSendOtp);
    expect(find.text(en.farmerLoginOtpTitle), findsOneWidget);
  });

  testWidgets('the dev menu opens from the login screen', (tester) async {
    final container = await createContainerAt(SessionPhase.signedOut);
    await pumpFarmerApp(tester, container: container);

    await tester.tap(find.byTooltip('Developer tools'));
    await tester.pumpAndSettle();
    expect(find.byType(DevScreen), findsOneWidget);
  });

  testWidgets('an account paused by HO lands on the paused screen', (
    tester,
  ) async {
    final container = await createContainerAt(
      SessionPhase.signedOut,
      scenario: MockScenario.accountPaused,
    );
    await pumpFarmerApp(tester, container: container);

    await _sendOtp(tester, raviPhone, te.farmerLoginSendOtp);
    await tester.enterText(find.byType(OtpInput), devOtp);
    await tester.pumpAndSettle();

    expect(currentPath(container.read(routerProvider)), Routes.paused);
    expect(find.text(te.farmerLoginPausedTitle), findsOneWidget);
  });
}
