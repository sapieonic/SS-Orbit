import 'package:fa/src/data/data.dart';
import 'package:fa/src/device/device.dart';
import 'package:fa/src/features/enrol/consent_panel.dart';
import 'package:fa/src/features/enrol/enrol_farmer_screen.dart';
import 'package:fa/src/features/enrol/enrol_plot_screen.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:fa/src/shared/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'enrol_test_support.dart';

Finder _field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextField),
  matchRoot: true,
);

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(_field(key), text);
  await tester.pumpAndSettle();
}

Future<FaTest> _pump(
  WidgetTester tester, {
  String? phone,
  String? alertId,
  MockScenario scenario = MockScenario.normal,
  Locale locale = const Locale('te'),
}) async {
  final t = await enrolTest(
    language: locale.languageCode == 'en' ? Language.en : Language.te,
  );
  if (scenario != MockScenario.normal) {
    t.read(mockScenarioProvider.notifier).select(scenario);
  }
  await pumpFaScreen(
    tester,
    EnrolFarmerScreen(phone: phone, alertId: alertId),
    test: t,
    locale: locale,
  );
  return t;
}

/// Sends the consent OTP, types [code] and confirms.
Future<void> _consent(WidgetTester tester, {String code = devOtp}) async {
  await scrollAndTap(tester, orbitButton(te.faConsentSendOtp));
  await tester.enterText(
    find.descendant(
      of: find.byType(OtpInput),
      matching: find.byType(TextField),
    ),
    code,
  );
  await tester.pumpAndSettle();
  await scrollAndTap(tester, orbitButton(te.faConsentConfirm));
}

void main() {
  testWidgets('shows step 1 with the step row and the fields', (tester) async {
    await _pump(tester);
    expect(find.text(te.faEnrolTitle), findsOneWidget);
    expect(find.byType(StepIndicator), findsOneWidget);
    expect(find.text(te.faEnrolPhoneLabel), findsOneWidget);
    expect(find.text(te.faConsentTitle), findsOneWidget);
    // The notice is in the farmer's language (Telugu by default).
    expect(find.text(te.faConsentNotice), findsOneWidget);
    expectCleanLayout(tester);
  });

  testWidgets('new number online: consent OTP, then EnrolFarmer with proof '
      'and step 2', (tester) async {
    final t = await _pump(tester);
    await _type(tester, 'enrol.phone', '9876500001');
    expect(find.text(te.faEnrolRegisteredTitle), findsNothing);
    expect(find.text(te.faEnrolMineTitle), findsNothing);
    await _type(tester, 'enrol.name', 'Mahesh B');
    await _type(tester, 'enrol.name_te', 'మహేష్ బి');

    // No recording exists yet: Listen says so and nothing counts as
    // played.
    await scrollAndTap(tester, find.byType(ListenButton));
    expect(
      tester.widget<ListenButton>(find.byType(ListenButton)).label,
      te.commonAudioUnavailable,
    );
    expect(find.text(te.faConsentPlayed), findsNothing);

    await _consent(tester);
    final recorded = te.faConsentRecorded(time: '').split(' · ').first;
    expect(find.textContaining(recorded), findsOneWidget);
    expect(
      find.textContaining(
        te.faConsentRecordedPlayed(time: '', language: '').split(' · ').last,
      ),
      findsNothing,
    );

    await scrollAndTap(tester, orbitButton(te.commonNext));
    final enrol = queued<EnrolFarmerPayload>(t).single;
    expect(enrol.phone, '+919876500001');
    expect(enrol.name, 'Mahesh B');
    expect(enrol.nameTe, 'మహేష్ బి');
    expect(enrol.consent.otpProof, isNotNull);
    expect(enrol.consent.audioPlayed, isFalse);
    expect(enrol.consent.noticeVersion, faConsentNoticeVersion);
    expect(enrol.villageId, MockBackend.kondapurId);
    expect(currentLocation(t.router), AppRoutes.enrolPlot(enrol.farmerId));
    final f = t.territory.farmer(enrol.farmerId)!;
    expect(f.consentPending, isFalse);
  });

  testWidgets('online without consent asks first, then enrols consent '
      'pending', (tester) async {
    final t = await _pump(tester);
    await _type(tester, 'enrol.phone', '9876500002');
    await _type(tester, 'enrol.name', 'Kiran P');
    await scrollAndTap(tester, orbitButton(te.commonNext));
    expect(find.text(te.faEnrolNoConsentTitle), findsOneWidget);
    await tester.tap(find.text(te.commonCancel));
    await tester.pumpAndSettle();
    expect(queued<EnrolFarmerPayload>(t), isEmpty);

    await scrollAndTap(tester, orbitButton(te.commonNext));
    await tester.tap(find.text(te.faEnrolNoConsentConfirm));
    await tester.pumpAndSettle();
    final enrol = queued<EnrolFarmerPayload>(t).single;
    expect(enrol.consent.otpProof, isNull);
    expect(t.territory.farmer(enrol.farmerId)!.consentPending, isTrue);
  });

  testWidgets('validates the phone and the name', (tester) async {
    final t = await _pump(tester);
    await scrollAndTap(tester, orbitButton(te.commonNext));
    expect(find.text(te.faEnrolPhoneInvalid), findsOneWidget);
    expect(find.text(te.faEnrolNameRequired), findsOneWidget);
    expect(queued<EnrolFarmerPayload>(t), isEmpty);
  });

  testWidgets('a wrong OTP says how many tries are left', (tester) async {
    await _pump(tester);
    await _type(tester, 'enrol.phone', '9876500003');
    await _consent(tester, code: '000000');
    expect(find.textContaining(te.errorOtpInvalid), findsOneWidget);
    expect(find.textContaining(te.errorDetailAttemptsLeft(count: 4)), findsOne);
    expect(orbitButton(te.faConsentConfirm), findsOneWidget);
  });

  testWidgets('a number already on the phone shows Already your farmer', (
    tester,
  ) async {
    final t = await _pump(tester, phone: MockBackend.raviPhone);
    expect(find.text(te.faEnrolMineTitle), findsOneWidget);
    expect(orbitButton(te.commonNext), findsNothing);
    await scrollAndTap(tester, orbitButton(te.faEnrolOpenFarmer));
    expect(currentPath(t.router), AppRoutes.farmer(MockBackend.raviId));
  });

  testWidgets('a farmer of mine without a plot links to step 2', (
    tester,
  ) async {
    final t = await enrolTest();
    final id = await enrolDirect(t, phone: '9876500004');
    await pumpFaScreen(
      tester,
      const EnrolFarmerScreen(phone: '9876500004'),
      test: t,
    );
    expect(find.text(te.faEnrolMineTitle), findsOneWidget);
    expect(orbitButton(te.faEnrolRecordConsent), findsOneWidget);
    await scrollAndTap(tester, orbitButton(te.faEnrolFinishEnrolment));
    expect(currentLocation(t.router), AppRoutes.enrolPlot(id));
  });

  testWidgets('a self sign-up with no FA: Already registered, continue and '
      'the alert is acknowledged', (tester) async {
    final alertId = MockBackend.sid('mock:alert:raju-new');
    final t = await _pump(
      tester,
      phone: MockBackend.rajuPhone,
      alertId: alertId,
    );
    expect(t.territory.alert(alertId)?.status, AlertStatus.open);
    expect(find.text(te.faEnrolRegisteredTitle), findsOneWidget);
    expect(orbitButton(te.faEnrolContinueClaim), findsOneWidget);
    await _type(tester, 'enrol.name', 'Raju P');
    await scrollAndTap(tester, orbitButton(te.faEnrolContinueClaim));
    await tester.tap(find.text(te.faEnrolNoConsentConfirm));
    await tester.pumpAndSettle();
    final enrol = queued<EnrolFarmerPayload>(t).single;
    expect(enrol.phone, MockBackend.rajuPhone);
    // Not on the phone, so the enrolment cannot close the alert here.
    expect(t.territory.farmer(enrol.farmerId)?.source, FarmerSource.fa);
    expect(queued<AckAlertPayload>(t).single.alertId, alertId);
    expect(t.territory.alert(alertId)?.status, AlertStatus.acknowledged);
    expect(currentLocation(t.router), AppRoutes.enrolPlot(enrol.farmerId));
  });

  testWidgets('another FA\'s farmer stops with Call HO', (tester) async {
    final t = await _pump(tester, phone: MockBackend.otherFaFarmerPhone);
    expect(find.text(te.faEnrolOtherFaTitle), findsOneWidget);
    expect(orbitButton(te.commonNext), findsNothing);
    expect(find.text(te.faEnrolNameLabel), findsNothing);
    await scrollAndTap(tester, orbitButton(te.faEnrolCallHo));
    expect(t.launcher.calls, ['18001234567']);
  });

  testWidgets('outside my area stops with Call HO', (tester) async {
    await _pump(tester, phone: MockBackend.outsideAreaPhone);
    expect(find.text(te.faEnrolOutsideTitle), findsOneWidget);
    expect(orbitButton(te.faEnrolCallHo), findsOneWidget);
    expect(orbitButton(te.commonNext), findsNothing);
  });

  testWidgets('deactivated stops without a way on', (tester) async {
    await _pump(tester, phone: MockBackend.deactivatedPhone);
    expect(find.text(te.faEnrolDeactivatedTitle), findsOneWidget);
    expect(orbitButton(te.faEnrolCallHo), findsNothing);
    expect(orbitButton(te.commonNext), findsNothing);
  });

  testWidgets('offline: no lookup, no OTP, no photo; enrols consent pending', (
    tester,
  ) async {
    final t = await _pump(tester, scenario: MockScenario.offline);
    await _type(tester, 'enrol.phone', MockBackend.otherFaFarmerPhone);
    // Not looked up: the number is checked again at sync.
    expect(find.text(te.faEnrolOtherFaTitle), findsNothing);
    expect(find.text(te.faEnrolOfflineTitle), findsOneWidget);
    expect(find.text(te.faConsentOfflineTitle), findsOneWidget);
    expect(find.text(te.faEnrolPhotoOffline), findsOneWidget);
    expect(orbitButton(te.faConsentSendOtp), findsNothing);
    await _type(tester, 'enrol.name', 'Narsimha G');
    await scrollAndTap(tester, orbitButton(te.commonNext));
    // No "without consent?" question offline.
    expect(find.text(te.faEnrolNoConsentTitle), findsNothing);
    final enrol = queued<EnrolFarmerPayload>(t).single;
    expect(enrol.consent.otpProof, isNull);
    expect(enrol.photoKey, isNull);
  });

  testWidgets('a lookup that fails with no network counts as offline', (
    tester,
  ) async {
    final t = await _pump(tester);
    // The connectivity still says online; the call fails.
    t.backend.scenario = MockScenario.offline;
    await _type(tester, 'enrol.phone', '9876500005');
    expect(find.text(te.faEnrolOfflineTitle), findsOneWidget);
    expect(find.text(te.faConsentOfflineTitle), findsOneWidget);
    // Back online: Try again looks the number up.
    t.backend.scenario = MockScenario.normal;
    await tester.tap(find.text(te.commonRetry).first);
    await tester.pumpAndSettle();
    expect(find.text(te.faEnrolOfflineTitle), findsNothing);
    expect(orbitButton(te.faConsentSendOtp), findsOneWidget);
  });

  testWidgets('the farmer photo uploads online and goes in EnrolFarmer', (
    tester,
  ) async {
    final t = await _pump(tester);
    await _type(tester, 'enrol.phone', '9876500006');
    await _type(tester, 'enrol.name', 'Swathi K');
    await scrollAndTap(tester, orbitButton(te.faEnrolPhoto));
    expect(find.text(te.faEnrolPhotoAdded), findsOneWidget);
    await scrollAndTap(tester, orbitButton(te.commonNext));
    await tester.tap(find.text(te.faEnrolNoConsentConfirm));
    await tester.pumpAndSettle();
    final enrol = queued<EnrolFarmerPayload>(t).single;
    expect(enrol.photoKey, startsWith('farmers/${enrol.farmerId}/'));
  });

  testWidgets('a camera that fails says so', (tester) async {
    final t = await _pump(tester);
    (t.read(photoCaptureProvider) as MockPhotoCapture).failNext();
    await _type(tester, 'enrol.phone', '9876500007');
    await scrollAndTap(tester, orbitButton(te.faEnrolPhoto));
    expect(find.text(te.faEnrolPhotoNoCamera), findsOneWidget);
  });

  testWidgets('back with details filled in asks before leaving', (
    tester,
  ) async {
    final t = await _pump(tester);
    await _type(tester, 'enrol.name', 'Someone');
    await tester.tap(find.byTooltip(te.faEnrolBackToFarmers));
    await tester.pumpAndSettle();
    expect(find.text(te.faEnrolLeaveTitle), findsOneWidget);
    await tester.tap(find.text(te.faEnrolLeaveStay));
    await tester.pumpAndSettle();
    expect(currentPath(t.router), '/screen');
    await tester.tap(find.byTooltip(te.faEnrolBackToFarmers));
    await tester.pumpAndSettle();
    await tester.tap(find.text(te.faEnrolLeaveConfirm));
    await tester.pumpAndSettle();
    expect(currentPath(t.router), AppRoutes.farmers);
  });

  testWidgets('English UI with an English-speaking farmer', (tester) async {
    await _pump(tester, locale: const Locale('en'));
    expect(find.text(en.faEnrolTitle), findsOneWidget);
    await scrollAndTap(tester, find.text(en.enumLanguageEn));
    expect(find.text(en.faConsentNotice), findsOneWidget);
    expectCleanLayout(tester);
  });

  screenLayoutTest('enrol step 1', () => const EnrolFarmerScreen());

  screenLayoutTest(
    'enrol step 1 with the OTP sent',
    () => const EnrolFarmerScreen(phone: '9876500008'),
    after: (tester, t) async {
      await scrollAndTap(tester, orbitButton(te.faConsentSendOtp));
    },
  );

  screenLayoutTest(
    'enrol step 1 stopped (another FA)',
    () => const EnrolFarmerScreen(phone: MockBackend.otherFaFarmerPhone),
  );

  screenLayoutTest(
    'enrol step 1 already registered',
    () => const EnrolFarmerScreen(phone: MockBackend.rajuPhone),
  );

  testWidgets('a new number after consent starts consent over', (tester) async {
    final t = await _pump(tester);
    await _type(tester, 'enrol.phone', '9876500001');
    await _type(tester, 'enrol.name', 'Mahesh B');
    await _consent(tester);
    expect(tester.takeException(), isNull);
    // Another number: the code was read out for the first one.
    await tester.ensureVisible(_field('enrol.phone'));
    await _type(tester, 'enrol.phone', '9876500003');
    expect(tester.takeException(), isNull);
    expect(orbitButton(te.faConsentSendOtp), findsOneWidget);
    await scrollAndTap(tester, orbitButton(te.commonNext));
    expect(find.text(te.faEnrolNoConsentTitle), findsOneWidget);
    await tester.tap(find.text(te.faEnrolNoConsentConfirm));
    await tester.pumpAndSettle();
    final enrol = queued<EnrolFarmerPayload>(t).single;
    expect(enrol.phone, '+919876500003');
    expect(enrol.consent.otpProof, isNull);
  });

  testWidgets('a number that hides the form drops the consent too', (
    tester,
  ) async {
    final t = await _pump(tester);
    final mine = t.territory.farmers.firstWhere(
      (f) => f.status == FarmerStatus.active,
    );
    await _type(tester, 'enrol.phone', '9876500001');
    await _type(tester, 'enrol.name', 'Mahesh B');
    await _consent(tester);
    await tester.ensureVisible(_field('enrol.phone'));
    // One of mine: the form (and the consent box) goes away.
    await _type(tester, 'enrol.phone', nationalMobile(mine.phone)!);
    expect(find.text(te.faEnrolMineTitle), findsOneWidget);
    await _type(tester, 'enrol.phone', '9876500004');
    await scrollAndTap(tester, orbitButton(te.commonNext));
    // The proof was for the first number: Next asks instead of enrolling
    // with a proof the farmer never gave for this one.
    expect(find.text(te.faEnrolNoConsentTitle), findsOneWidget);
    expect(queued<EnrolFarmerPayload>(t), isEmpty);
  });

  testWidgets('back from step 2 leaves step 1 usable', (tester) async {
    final t = await enrolTest();
    t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
    await pumpFaApp(tester, test: t);
    t.router.go(AppRoutes.enrol);
    await tester.pumpAndSettle();
    await _type(tester, 'enrol.phone', '9876500001');
    await _type(tester, 'enrol.name', 'Mahesh B');
    await scrollAndTap(tester, orbitButton(te.commonNext));
    expect(find.byType(EnrolPlotScreen), findsOneWidget);
    await systemBack(tester);
    expect(find.byType(EnrolFarmerScreen), findsOneWidget);
    expect(find.text(te.faEnrolMineTitle), findsOneWidget);
    // Back works again (it asks first: the typed name is still there).
    await tester.tap(find.byTooltip(te.faEnrolBackToFarmers));
    await tester.pumpAndSettle();
    await tester.tap(find.text(te.faEnrolLeaveConfirm));
    await tester.pumpAndSettle();
    expect(currentPath(t.router), AppRoutes.farmers);
  });

  testWidgets('a Telugu name too long in bytes is marked on its field', (
    tester,
  ) async {
    final t = await _pump(tester, scenario: MockScenario.offline);
    await _type(tester, 'enrol.phone', '9876500005');
    await _type(tester, 'enrol.name', 'Mahesh B');
    // 101 Telugu letters: 101 characters, 303 bytes (the limit is 300).
    await _type(tester, 'enrol.name_te', 'మ' * 101);
    await scrollAndTap(tester, orbitButton(te.commonNext));
    expect(find.text(te.faActionErrorTooLong), findsOneWidget);
    expect(queued<EnrolFarmerPayload>(t), isEmpty);
    await _type(tester, 'enrol.name_te', 'మహేష్');
    expect(find.text(te.faActionErrorTooLong), findsNothing);
  });
}
