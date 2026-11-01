import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/farm/consents_screen.dart';
import 'package:farmer/src/features/farm/farm_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

void main() {
  Future<bool?> granted(ProviderContainer c, ConsentPurpose purpose) async {
    final list = await c.read(farmerProfileRepositoryProvider).listConsents();
    return list.firstWhere((x) => x.purpose == purpose).granted;
  }

  Finder purpose(ConsentPurpose p) => find.text(te.labelConsentPurpose(p.wire));

  /// The Agree / Withdraw button on [p]'s card.
  Finder action(ConsentPurpose p, String label) => find.descendant(
    of: find.ancestor(of: purpose(p), matching: find.byType(Card)),
    matching: orbitButton(label),
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every purpose with what it is for and its state', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpScreen(tester, const ConsentsScreen(), container: container);

    expect(find.text(te.farmerConsentsTitle), findsOneWidget);
    expect(purpose(ConsentPurpose.programme), findsOneWidget);
    expect(find.text(te.farmerConsentsDescProgramme), findsOneWidget);
    // Ravi agreed to the programme through his FA, with an OTP.
    expect(statusPill(te.labelConsentState('granted')), findsOneWidget);
    expect(
      find.textContaining(te.labelConsentMethod('fa_otp')),
      findsOneWidget,
    );
    expect(
      action(ConsentPurpose.programme, te.farmerConsentsWithdraw),
      findsOneWidget,
    );

    for (final p in [
      ConsentPurpose.soilPartner,
      ConsentPurpose.schemesFinance,
      ConsentPurpose.loyalty,
    ]) {
      await scrollTo(tester, purpose(p));
      expect(action(p, te.farmerConsentsAgree), findsOneWidget);
    }
    expect(statusPill(te.labelConsentState('never_asked')), findsWidgets);
  });

  testWidgets('Agree grants without asking', (tester) async {
    final container = await createTestContainer();
    await pumpScreen(tester, const ConsentsScreen(), container: container);

    final agree = action(ConsentPurpose.soilPartner, te.farmerConsentsAgree);
    await scrollTo(tester, agree);
    await tester.tap(agree);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(te.farmerConsentSaved), findsOneWidget);
    expect(await granted(container, ConsentPurpose.soilPartner), isTrue);
    expect(
      action(ConsentPurpose.soilPartner, te.farmerConsentsWithdraw),
      findsOneWidget,
    );
  });

  testWidgets('withdrawing the programme warns first, then withdraws', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpScreen(tester, const ConsentsScreen(), container: container);
    final withdraw = action(
      ConsentPurpose.programme,
      te.farmerConsentsWithdraw,
    );

    await tester.tap(withdraw);
    await tester.pumpAndSettle();
    expect(find.text(te.farmerConsentsWithdrawTitle), findsOneWidget);
    expect(
      find.text(te.farmerConsentsWithdrawProgrammeWarning),
      findsOneWidget,
    );
    expect(find.text(te.farmerConsentsWithdrawBody), findsOneWidget);
    // Listen reads the dialog, warning included.
    expect(
      dialogVoiceKey(tester),
      VoiceKeys.farmerConsentsWithdrawProgrammeVoice,
    );

    await tester.tap(find.text(te.commonCancel));
    await tester.pumpAndSettle();
    expect(await granted(container, ConsentPurpose.programme), isTrue);

    await tester.tap(withdraw);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: orbitButton(te.farmerConsentsWithdraw),
      ),
    );
    await tester.pumpAndSettle();

    expect(await granted(container, ConsentPurpose.programme), isFalse);
    expect(statusPill(te.labelConsentState('withdrawn')), findsOneWidget);
    expect(
      action(ConsentPurpose.programme, te.farmerConsentsAgree),
      findsOneWidget,
    );
    // Still signed in and active: withdrawing does not close the account.
    expect(container.read(sessionProvider).phase, SessionPhase.active);
  });

  testWidgets('withdrawing another purpose has no programme warning', (
    tester,
  ) async {
    final container = await createTestContainer();
    await container
        .read(farmerProfileRepositoryProvider)
        .setConsent(
          purpose: ConsentPurpose.loyalty,
          granted: true,
          noticeVersion: programmeConsentNoticeVersion,
        );
    await pumpScreen(tester, const ConsentsScreen(), container: container);

    final withdraw = action(ConsentPurpose.loyalty, te.farmerConsentsWithdraw);
    await scrollTo(tester, withdraw);
    await tester.tap(withdraw);
    await tester.pumpAndSettle();
    expect(find.text(te.farmerConsentsWithdrawProgrammeWarning), findsNothing);
    expect(dialogVoiceKey(tester), VoiceKeys.farmerConsentsWithdrawVoice);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: purpose(ConsentPurpose.loyalty),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed change keeps the state and says why', (tester) async {
    final backend = testBackend();
    final container = await createTestContainer(backend: backend);
    await pumpScreen(tester, const ConsentsScreen(), container: container);

    backend.scenario = MockScenario.offline;
    final agree = action(ConsentPurpose.soilPartner, te.farmerConsentsAgree);
    await scrollTo(tester, agree);
    await tester.tap(agree);
    await tester.pumpAndSettle();

    expect(find.text(te.errorNetwork), findsOneWidget);
    expect(agree, findsOneWidget);
  });

  testWidgets('the change date is the IST day', (tester) async {
    // 31 Oct 20:00 UTC is already 1 Nov (01:30) in India.
    final at = DateTime.utc(2026, 10, 31, 20);
    final container = await createTestContainer(
      overrides: [
        farmConsentsProvider.overrideWith(
          () => _FixedConsents([
            CurrentConsent(
              purpose: ConsentPurpose.programme,
              granted: true,
              method: ConsentMethod.app,
              noticeVersion: programmeConsentNoticeVersion,
              updatedAt: at,
            ),
          ]),
        ),
      ],
    );
    await pumpScreen(tester, const ConsentsScreen(), container: container);

    expect(
      find.textContaining(te.farmerConsentsChangedOn(date: DateTime(2026, 11))),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        te.farmerConsentsChangedOn(date: DateTime(2026, 10, 31)),
      ),
      findsNothing,
    );
  });

  testWidgets('no consents to show: one card to load them again', (
    tester,
  ) async {
    final container = await createTestContainer(
      overrides: [farmConsentsProvider.overrideWith(() => _FixedConsents([]))],
    );
    await pumpScreen(tester, const ConsentsScreen(), container: container);

    expect(find.text(te.farmerConsentsEmpty), findsOneWidget);
    expect(orbitButton(te.commonRetry), findsOneWidget);
    expect(find.byType(StatusPill), findsNothing);
  });

  testWidgets('offline shows the offline card', (tester) async {
    final container = await createTestContainer(scenario: MockScenario.offline);
    await pumpScreen(tester, const ConsentsScreen(), container: container);
    expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
  });

  testWidgets('renders in English', (tester) async {
    final container = await createTestContainer();
    await pumpScreen(
      tester,
      const ConsentsScreen(),
      container: container,
      locale: const Locale('en'),
    );
    expect(find.text(en.farmerConsentsTitle), findsOneWidget);
    expect(find.text(en.labelConsentPurpose('programme')), findsOneWidget);
    expect(find.text(en.farmerConsentsDescProgramme), findsOneWidget);
    expectCleanLayout(tester);
  });

  screenLayoutTest('ConsentsScreen', () => const ConsentsScreen());

  for (final scale in textScales) {
    testWidgets(
      'the withdraw dialog and the last card fit at text scale $scale',
      (tester) async {
        final container = await createTestContainer();
        await pumpScreen(
          tester,
          const ConsentsScreen(),
          container: container,
          textScale: scale,
        );
        await tester.tap(
          action(ConsentPurpose.programme, te.farmerConsentsWithdraw),
        );
        await tester.pumpAndSettle();
        expectCleanLayout(tester);
        await tester.tap(find.text(te.commonCancel));
        await tester.pumpAndSettle();
        await scrollTo(tester, purpose(ConsentPurpose.loyalty));
        expectCleanLayout(tester);
      },
    );
  }
}

/// Consents as given, without the server.
class _FixedConsents extends FarmConsentsController {
  _FixedConsents(this._consents);

  final List<CurrentConsent> _consents;

  @override
  Future<List<CurrentConsent>> build() async => _consents;
}
