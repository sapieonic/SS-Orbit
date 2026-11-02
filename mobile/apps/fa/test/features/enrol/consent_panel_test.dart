import 'package:fa/src/data/data.dart';
import 'package:fa/src/features/enrol/consent_panel.dart';
import 'package:fa/src/features/enrol/enrol_support.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'enrol_test_support.dart';

/// A page with one button that opens the record-consent sheet, as Farmer
/// 360 would.
class _Host extends StatefulWidget {
  const _Host({required this.farmerId});

  final String farmerId;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool? saved;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              final r = await showRecordConsentSheet(
                context,
                farmerId: widget.farmerId,
              );
              setState(() => saved = r);
            },
            child: const Text('open'),
          ),
          Text('saved: $saved'),
        ],
      ),
    ),
  );
}

Finder get _otp => find.descendant(
  of: find.byType(OtpInput),
  matching: find.byType(TextField),
);

void main() {
  testWidgets('Record consent from Farmer 360: OTP, Save, RecordConsent', (
    tester,
  ) async {
    final t = await enrolTest();
    final id = await enrolDirect(t);
    expect(t.territory.farmer(id)!.consentPending, isTrue);
    await pumpFaScreen(tester, _Host(farmerId: id), test: t);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(te.faConsentSheetTitle(name: 'Mahesh B')), findsOneWidget);
    expect(orbitButton(te.faConsentSave), findsOneWidget);
    expect(
      tester.widget<OrbitButton>(orbitButton(te.faConsentSave)).onPressed,
      isNull,
    );

    await tester.tap(orbitButton(te.faConsentSendOtp));
    await tester.pumpAndSettle();
    expect(find.text(te.faConsentResendIn(seconds: 30)), findsOneWidget);
    await tester.enterText(_otp, devOtp);
    await tester.pumpAndSettle();
    await tester.tap(orbitButton(te.faConsentConfirm));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, orbitButton(te.faConsentSave));

    final consent = queued<RecordConsentPayload>(t).single;
    expect(consent.farmerId, id);
    expect(consent.otpProof, isNotEmpty);
    expect(consent.noticeVersion, faConsentNoticeVersion);
    expect(consent.audioPlayed, isFalse);
    expect(t.territory.farmer(id)!.consentPending, isFalse);
    expect(find.text('saved: true'), findsOneWidget);
    expect(find.text(te.faConsentSaved), findsOneWidget);
  });

  testWidgets('Send again is held for 30 seconds', (tester) async {
    final t = await enrolTest();
    final id = await enrolDirect(t);
    await pumpFaScreen(tester, _Host(farmerId: id), test: t);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(orbitButton(te.faConsentSendOtp));
    await tester.pumpAndSettle();
    expect(find.text(te.faConsentResend), findsNothing);
    testClock.advance(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text(te.faConsentResend), findsOneWidget);
    await tester.tap(find.text(te.faConsentResend));
    await tester.pumpAndSettle();
    expect(find.text(te.faConsentResendIn(seconds: 30)), findsOneWidget);
  });

  testWidgets('an expired code asks for a new one', (tester) async {
    final t = await enrolTest();
    final id = await enrolDirect(t);
    await pumpFaScreen(tester, _Host(farmerId: id), test: t);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(orbitButton(te.faConsentSendOtp));
    await tester.pumpAndSettle();
    testClock.advance(const Duration(minutes: 11));
    await tester.pump(const Duration(seconds: 30));
    await tester.enterText(_otp, devOtp);
    await tester.pumpAndSettle();
    await tester.tap(orbitButton(te.faConsentConfirm));
    await tester.pumpAndSettle();
    expect(find.text(te.errorOtpExpired), findsOneWidget);
    expect(orbitButton(te.faConsentSendOtp), findsOneWidget);
    expect(find.byType(OtpInput), findsNothing);
  });

  testWidgets('offline the sheet says consent needs internet', (tester) async {
    final t = await enrolTest();
    final id = await enrolDirect(t);
    t.read(mockScenarioProvider.notifier).select(MockScenario.offline);
    await pumpFaScreen(tester, _Host(farmerId: id), test: t);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(te.faConsentOfflineTitle), findsOneWidget);
    expect(orbitButton(te.faConsentSendOtp), findsNothing);
  });

  group('area and helpers', () {
    test('typedAreaAcres', () {
      expect(typedAreaAcres('2', '4'), 2.1);
      expect(typedAreaAcres('', '20'), 0.5);
      expect(typedAreaAcres('1', ''), 1);
      expect(typedAreaAcres('0', '0'), isNull);
      expect(typedAreaAcres('1', '40'), isNull);
      expect(typedAreaAcres('x', '1'), isNull);
    });

    test('finishEnrolmentLocation: plot, then crop, then nothing', () async {
      final t = await enrolTest();
      final id = await enrolDirect(t);
      expect(finishEnrolmentLocation(t.territory, id), AppRoutes.enrolPlot(id));
      final plotId = await plotDirect(t, id);
      await t.container.read(territoryProvider.notifier).reload();
      expect(
        finishEnrolmentLocation(t.territory, id),
        AppRoutes.enrolCrop(id, plotId: plotId),
      );
      await t
          .read(faActionsProvider)
          .startSeason(
            farmerId: id,
            plotId: plotId,
            cropId: MockBackend.paddyId,
          );
      await t.container.read(territoryProvider.notifier).reload();
      expect(finishEnrolmentLocation(t.territory, id), isNull);
    });

    test('seasonLabel', () {
      expect(seasonLabel(en, 'rabi-2026-27'), 'Rabi 2026-27');
      expect(seasonLabel(en, 'kharif-2026'), 'Kharif 2026');
      expect(seasonLabel(en, 'odd'), 'odd');
    });

    test('step line', () {
      expect(enrolStepLine(en, 2), 'Step 2 of 3 · Farm');
    });
  });

  test('ConsentOutcome equality', () {
    final proof = ConsentProof(
      phone: '+919876500011',
      otpProof: 'p',
      verifiedAt: DateTime.utc(2026),
      expiresAt: DateTime.utc(2026, 1, 8),
    );
    expect(
      ConsentOutcome(proof: proof, audioPlayed: true),
      ConsentOutcome(proof: proof, audioPlayed: true),
    );
  });
}
