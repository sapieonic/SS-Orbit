import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/onboarding/consent_screen.dart';
import 'package:farmer/src/shared/voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../../support/harness.dart';
import 'profile_spy.dart';

void main() {
  testWidgets('shows the purpose and the three points', (tester) async {
    final container = await createContainerAt(SessionPhase.needsConsent);
    await pumpScreen(tester, const ConsentScreen(), container: container);

    expect(find.text(te.farmerConsentTitle), findsOneWidget);
    expect(find.text(te.farmerConsentPurpose), findsOneWidget);
    expect(find.text(te.farmerConsentPointSafe), findsOneWidget);
    expect(find.text(te.farmerConsentPointPartners), findsOneWidget);
    expect(find.text(te.farmerConsentPointChange), findsOneWidget);
    expect(orbitButton(te.farmerConsentAgree), findsOneWidget);
    // The soil-partner question waits for the first soil-test booking.
    expect(find.textContaining('మట్టి'), findsNothing);
  });

  testWidgets('"OK, I agree" stores the consent and moves on', (tester) async {
    final spy = ProfileSpy();
    final container = await createContainerAt(
      SessionPhase.needsConsent,
      overrides: [spyOnProfile(spy)],
    );
    await pumpScreen(tester, const ConsentScreen(), container: container);

    await tester.tap(orbitButton(te.farmerConsentAgree));
    await tester.pumpAndSettle();

    expect(phaseOf(container), SessionPhase.needsVillage);
    expect(spy.consentAudio, [false]);
    final consents = await container
        .read(farmerProfileRepositoryProvider)
        .listConsents();
    expect(
      consents
          .singleWhere((c) => c.purpose == ConsentPurpose.programme)
          .granted,
      isTrue,
    );
  });

  testWidgets(
    'audio_played is true after the Listen prompt played to the end',
    (tester) async {
      final voice = FakeVoicePlayer();
      final spy = ProfileSpy();
      final container = await createContainerAt(
        SessionPhase.needsConsent,
        voice: voice,
        overrides: [spyOnProfile(spy)],
      );
      await pumpScreen(tester, const ConsentScreen(), container: container);

      await tester.tap(find.byType(ScreenListenButton));
      await tester.pump();
      expect(voice.played, [VoiceKeys.farmerConsentVoiceHelp]);
      voice.complete();
      await tester.pump();

      await tester.tap(orbitButton(te.farmerConsentAgree));
      await tester.pumpAndSettle();
      expect(spy.consentAudio, [true]);
    },
  );

  testWidgets('a Listen prompt stopped early does not count', (tester) async {
    final voice = FakeVoicePlayer();
    final spy = ProfileSpy();
    final container = await createContainerAt(
      SessionPhase.needsConsent,
      voice: voice,
      overrides: [spyOnProfile(spy)],
    );
    await pumpScreen(tester, const ConsentScreen(), container: container);

    await tester.tap(find.byType(ScreenListenButton));
    await tester.pump();
    await tester.tap(find.byType(ScreenListenButton)); // stop
    await tester.pump();

    await tester.tap(orbitButton(te.farmerConsentAgree));
    await tester.pumpAndSettle();
    expect(spy.consentAudio, [false]);
  });

  testWidgets('"Not now" explains why and offers the helpline', (tester) async {
    final container = await createContainerAt(SessionPhase.needsConsent);
    await pumpScreen(tester, const ConsentScreen(), container: container);

    await tester.tap(find.text(te.farmerConsentNotNow));
    await tester.pumpAndSettle();

    expect(find.text(te.farmerConsentDeclined), findsOneWidget);
    expect(orbitButton(te.farmerLoginCallHelpline), findsOneWidget);
    expect(sheetVoiceKey(tester), VoiceKeys.farmerConsentVoiceHelpDeclined);
    expect(phaseOf(container), SessionPhase.needsConsent);

    // Agreeing from the sheet works too.
    await tester.tap(orbitButton(te.farmerConsentAgree).last);
    await tester.pumpAndSettle();
    expect(phaseOf(container), SessionPhase.needsVillage);
  });

  testWidgets('offline: says so and stays on the screen', (tester) async {
    final container = await createContainerAt(
      SessionPhase.needsConsent,
      scenario: MockScenario.offline,
    );
    await pumpScreen(tester, const ConsentScreen(), container: container);

    await tester.tap(orbitButton(te.farmerConsentAgree));
    await tester.pumpAndSettle();

    expect(find.text(te.errorNetwork), findsOneWidget);
    expect(phaseOf(container), SessionPhase.needsConsent);
  });

  testWidgets('renders in English', (tester) async {
    final container = await createContainerAt(SessionPhase.needsConsent);
    await pumpScreen(
      tester,
      const ConsentScreen(),
      container: container,
      locale: const Locale('en'),
    );
    expect(find.text(en.farmerConsentPointSafe), findsOneWidget);
    expect(orbitButton(en.farmerConsentAgree), findsOneWidget);
  });

  screenLayoutTest(
    'consent',
    () => const ConsentScreen(),
    phase: SessionPhase.needsConsent,
  );
  screenLayoutTest(
    'consent, Not now sheet',
    () => const ConsentScreen(),
    phase: SessionPhase.needsConsent,
    after: (tester) async {
      await tester.tap(find.text(te.farmerConsentNotNow));
      await tester.pumpAndSettle();
    },
  );
}
