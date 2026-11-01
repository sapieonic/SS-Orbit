import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/farm/farm_screen.dart';
import 'package:farmer/src/routing/router.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:farmer/src/shared/voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../../support/harness.dart';
import '../onboarding/profile_spy.dart';
import 'farm_test_support.dart';

void main() {
  testWidgets('shows the profile, the plot with its season and the rows', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpScreen(tester, const FarmScreen(), container: container);

    expect(headerTitle(te.farmerFarmTitle), findsOneWidget);
    expect(find.text('రవి కె'), findsOneWidget);
    expect(find.text('Ravi K'), findsOneWidget);
    expect(find.text('RK'), findsOneWidget);
    expect(find.text('90000 00101'), findsOneWidget);
    expect(find.text(te.labelFarmerPlan('free')), findsOneWidget);
    expect(find.text(te.farmerFarmVillageChangeNote), findsOneWidget);

    await tester.scrollUntilVisible(
      orbitButton(te.farmerFarmCloseSeason),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('పొలం 1 · పత్తి'), findsOneWidget);
    expect(find.text('2 ఎకరాలు 20 గుంటలు'), findsOneWidget);
    // Sown 1 Jul 2026, today 1 Nov 2026: day 123 of the kharif season.
    expect(find.textContaining('ఖరీఫ్ 2026'), findsOneWidget);
    expect(find.textContaining('123వ రోజు'), findsOneWidget);
    expect(orbitButton(te.farmerFarmStartSeason), findsNothing);

    await tester.scrollUntilVisible(
      orbitButton(te.commonSignOut),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(te.farmerFarmConsents), findsOneWidget);
    expect(find.text('సురేష్ కె'), findsOneWidget);
    expect(find.text(te.farmerFarmHelp), findsOneWidget);
  });

  testWidgets('offline shows one card, and Try again loads the farm', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await createTestContainer(
      backend: backend,
      scenario: MockScenario.offline,
    );
    await pumpScreen(tester, const FarmScreen(), container: container);

    expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
    expect(find.text('రవి కె'), findsNothing);

    backend.scenario = MockScenario.normal;
    await tester.tap(orbitButton(te.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text('రవి కె'), findsOneWidget);
  });

  testWidgets('server error shows the error card', (tester) async {
    final container = await createTestContainer(
      scenario: MockScenario.serverError,
    );
    await pumpScreen(tester, const FarmScreen(), container: container);
    expect(find.text(te.farmerStateErrorTitle), findsOneWidget);
  });

  testWidgets('pull to refresh shows a changed name', (tester) async {
    final container = await createTestContainer();
    await pumpScreen(tester, const FarmScreen(), container: container);

    await container
        .read(farmerProfileRepositoryProvider)
        .updateProfile(nameTe: 'రవి కుమార్');
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('రవి కుమార్'), findsOneWidget);
  });

  testWidgets('a plot sown later says so, not a negative day', (tester) async {
    final container = await createTestContainer();
    final profile = container.read(farmerProfileRepositoryProvider);
    final crops = await container.read(mastersRepositoryProvider).listCrops();
    final plot = await profile.addPlot(pin: kondapurPin, areaAcres: 1);
    await profile.startSeason(
      plotId: plot.id,
      seasonCode: crops.seasonCodes.current,
      cropId: crops.items.firstWhere((c) => c.code == 'paddy').id,
      sowingDate: LocalDate(2026, 11, 6),
    );
    await pumpScreen(tester, const FarmScreen(), container: container);

    final line = find.text(
      [
        'రబీ 2026-27',
        te.farmerFarmSowsOn(date: DateTime(2026, 11, 6)),
      ].join(' · '),
    );
    await tester.scrollUntilVisible(
      line,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(line, findsOneWidget);
  });

  group('edit name', () {
    testWidgets('saves a Telugu name as name and name_te, like sign-up', (
      tester,
    ) async {
      final spy = ProfileSpy();
      final container = await createTestContainer(
        overrides: [spyOnProfile(spy)],
      );
      await pumpScreen(tester, const FarmScreen(), container: container);

      await tester.tap(find.text(te.farmerFarmChangeName));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'రవి కె'), findsOneWidget);
      expect(dialogVoiceKey(tester), VoiceKeys.farmerFarmChangeNameVoice);

      await tester.enterText(find.byType(TextField), '  రవి కుమార్  ');
      await tester.tap(orbitButton(te.commonSave));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('రవి కుమార్'), findsOneWidget);
      final farmer =
          (await container.read(farmerProfileRepositoryProvider).getHome())
              .farmer;
      expect(farmer.nameTe, 'రవి కుమార్');
      // English screens, the FA app and the WhatsApp greeting read `name`.
      expect(farmer.name, 'రవి కుమార్');
      expect(spy.renamed, [('రవి కుమార్', 'రవి కుమార్')]);
    });

    testWidgets('an English name typed over the Telugu one replaces both, '
        'and blank is refused', (tester) async {
      final container = await createTestContainer();
      await pumpScreen(tester, const FarmScreen(), container: container);

      await tester.tap(find.text(te.farmerFarmChangeName));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'రవి కె'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(orbitButton(te.commonSave));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerNameRequired), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Ravi Kumar');
      await tester.tap(orbitButton(te.commonSave));
      await tester.pumpAndSettle();
      final farmer =
          (await container.read(farmerProfileRepositoryProvider).getHome())
              .farmer;
      expect(farmer.name, 'Ravi Kumar');
      // The API cannot clear name_te, and the Telugu screens show it first.
      expect(farmer.nameTe, 'Ravi Kumar');
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('రవి కె'), findsNothing);

      await tester.tap(find.text(te.farmerFarmChangeName));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Ravi Kumar'), findsOneWidget);
    });

    testWidgets('in English an English name updates name; the Telugu '
        'spelling stays', (tester) async {
      final container = await createTestContainer(language: Language.en);
      await pumpScreen(
        tester,
        const FarmScreen(),
        container: container,
        locale: const Locale('en'),
      );

      await tester.tap(find.text(en.farmerFarmChangeName));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Ravi K'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Ravi Kumar');
      await tester.tap(orbitButton(en.commonSave));
      await tester.pumpAndSettle();

      final farmer =
          (await container.read(farmerProfileRepositoryProvider).getHome())
              .farmer;
      expect(farmer.name, 'Ravi Kumar');
      expect(farmer.nameTe, 'రవి కె');
      expect(find.text('Ravi Kumar'), findsOneWidget);
    });

    testWidgets('offline keeps the dialog open with the reason', (
      tester,
    ) async {
      final backend = testBackend();
      final container = await createTestContainer(backend: backend);
      await pumpScreen(tester, const FarmScreen(), container: container);

      await tester.tap(find.text(te.farmerFarmChangeName));
      await tester.pumpAndSettle();
      backend.scenario = MockScenario.offline;
      await tester.enterText(find.byType(TextField), 'రవి కుమార్');
      await tester.tap(orbitButton(te.commonSave));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(te.errorNetwork), findsOneWidget);
    });

    testWidgets('back waits for the save, and the name shows after it', (
      tester,
    ) async {
      final backend = testBackend();
      final container = await createTestContainer(backend: backend);
      await pumpScreen(tester, const FarmScreen(), container: container);
      await tester.tap(find.text(te.farmerFarmChangeName));
      await tester.pumpAndSettle();

      backend.latency = const Duration(milliseconds: 300);
      await tester.enterText(find.byType(TextField), 'రవి కుమార్');
      await tester.tap(orbitButton(te.commonSave));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'still saving');

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      backend.latency = Duration.zero;
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('రవి కుమార్'), findsOneWidget);
      expect(
        (await container.read(farmerHomeProvider.future)).farmer.name,
        'రవి కుమార్',
      );
    });
  });

  testWidgets('choosing English switches the app language live', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);
    container.read(routerProvider).go(Routes.farm);
    await tester.pumpAndSettle();
    expect(headerTitle(te.farmerFarmTitle), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('English'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(headerTitle(en.farmerFarmTitle), findsOneWidget);
    expect(headerTitle(te.farmerFarmTitle), findsNothing);
    expect(find.text(en.farmerFarmLanguageChanged), findsOneWidget);
    expect(container.read(appLanguageProvider), Language.en);
    final farmer =
        (await container.read(farmerProfileRepositoryProvider).getHome())
            .farmer;
    expect(farmer.language, Language.en, reason: 'saved to the profile');
  });

  group('language', () {
    Future<void> tapLanguage(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(label));
    }

    testWidgets('a second tap waits until the first choice is saved', (
      tester,
    ) async {
      final backend = testBackend();
      final container = await createTestContainer(backend: backend);
      await pumpScreen(tester, const FarmScreen(), container: container);

      backend.latency = const Duration(milliseconds: 300);
      await tapLanguage(tester, 'English');
      await tester.pump();
      await tester.tap(find.text('తెలుగు'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      backend.latency = Duration.zero;

      expect(container.read(appLanguageProvider), Language.en);
      final farmer =
          (await container.read(farmerProfileRepositoryProvider).getHome())
              .farmer;
      expect(farmer.language, Language.en);
    });

    testWidgets('a failure to save it on the phone is said, in the new '
        'language', (tester) async {
      final container = await createTestContainer(
        store: _FailingLanguageStore(InMemorySessionStore()),
      );
      await pumpScreen(tester, const FarmScreen(), container: container);

      await tapLanguage(tester, 'English');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(appLanguageProvider), Language.en);
      expect(find.text(en.errorUnknown), findsOneWidget);
    });

    testWidgets('a refused save says why, with the Retry-After wait', (
      tester,
    ) async {
      final spy = ProfileSpy()
        ..refuseLanguage = const ApiError(
          code: ApiErrorCode.rateLimited,
          message: 'slow down',
          status: 429,
          retryAfter: Duration(seconds: 30),
        );
      final container = await createTestContainer(
        overrides: [spyOnProfile(spy)],
      );
      await pumpScreen(tester, const FarmScreen(), container: container);

      await tapLanguage(tester, 'English');
      await tester.pumpAndSettle();

      expect(
        find.text(
          en.describeError(
            ApiErrorCode.rateLimited,
            details: {'retry_after_seconds': 30},
          ),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('sign out asks first, then lands on the login screen', (
    tester,
  ) async {
    final container = await createTestContainer();
    await pumpFarmerApp(tester, container: container);
    final router = container.read(routerProvider)..go(Routes.farm);
    await tester.pumpAndSettle();

    await scrollAndTap(tester, orbitButton(te.commonSignOut));
    expect(find.text(te.farmerFarmSignOutTitle), findsOneWidget);
    expect(dialogVoiceKey(tester), VoiceKeys.farmerFarmSignOutVoice);

    await tester.tap(find.text(te.commonCancel));
    await tester.pumpAndSettle();
    expect(currentPath(router), Routes.farm);

    await tester.tap(orbitButton(te.commonSignOut));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: orbitButton(te.commonSignOut),
      ),
    );
    await tester.pumpAndSettle();

    expect(currentPath(router), Routes.login);
    expect(container.read(sessionProvider).phase, SessionPhase.signedOut);
  });

  group('navigation', () {
    testWidgets('close season, add plot, consents and your FA', (tester) async {
      final container = await createTestContainer();
      final router = await pumpFarmRoutes(tester, container: container);

      await scrollAndTap(tester, orbitButton(te.farmerFarmCloseSeason));
      expect(currentPath(router), Routes.closeSeason(raviSeasonId));
      router.pop();
      await tester.pumpAndSettle();

      await scrollAndTap(tester, orbitButton(te.farmerFarmAddPlot));
      expect(currentPath(router), Routes.addPlot);
      router.pop();
      await tester.pumpAndSettle();

      await scrollAndTap(tester, find.text(te.farmerFarmConsents));
      expect(currentPath(router), Routes.consents);
      router.pop();
      await tester.pumpAndSettle();

      await scrollAndTap(tester, find.text(te.farmerFarmYourFa));
      expect(currentPath(router), Routes.fas);
    });

    testWidgets('a plot without a crop offers Start a season', (tester) async {
      final container = await createTestContainer();
      final plot = await container
          .read(farmerProfileRepositoryProvider)
          .addPlot(pin: kondapurPin, areaAcres: 1);
      final router = await pumpFarmRoutes(tester, container: container);

      await tester.scrollUntilVisible(
        find.text(te.farmerFarmNoCrop),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('పొలం 2'), findsOneWidget);
      await scrollAndTap(tester, orbitButton(te.farmerFarmStartSeason));
      expect(currentPath(router), Routes.startSeason(plot.id));
    });
  });

  testWidgets('renders in English', (tester) async {
    final container = await createTestContainer();
    await pumpScreen(
      tester,
      const FarmScreen(),
      container: container,
      locale: const Locale('en'),
    );
    expect(headerTitle(en.farmerFarmTitle), findsOneWidget);
    expect(find.text('Ravi K'), findsOneWidget);
    expect(find.text(en.labelFarmerPlan('free')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Plot 1 · Cotton'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Kharif 2026'), findsOneWidget);
    expectCleanLayout(tester);
  });

  screenLayoutTest('FarmScreen', () => const FarmScreen());
  screenLayoutTest(
    'FarmScreen offline',
    () => const FarmScreen(),
    scenario: MockScenario.offline,
  );

  for (final scale in textScales) {
    testWidgets('FarmScreen bottom half fits at text scale $scale', (
      tester,
    ) async {
      final container = await createTestContainer();
      await pumpScreen(
        tester,
        const FarmScreen(),
        container: container,
        textScale: scale,
      );
      await tester.scrollUntilVisible(
        orbitButton(te.commonSignOut),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expectCleanLayout(tester);
    });
  }

  screenLayoutTest(
    'FarmScreen sign-out dialog',
    () => const FarmScreen(),
    after: (tester) async {
      await scrollAndTap(tester, orbitButton(te.commonSignOut));
      expect(find.byType(ScreenListenButton), findsWidgets);
    },
  );
  screenLayoutTest(
    'FarmScreen change-name dialog',
    () => const FarmScreen(),
    after: (tester) async {
      await tester.tap(find.text(te.farmerFarmChangeName));
      await tester.pumpAndSettle();
    },
  );
}

/// A session store whose language can't be saved (the phone's storage
/// failed).
class _FailingLanguageStore implements SessionStore {
  _FailingLanguageStore(this._inner);

  final SessionStore _inner;

  @override
  Future<void> writeLanguage(Language language) =>
      Future.error(StateError('storage unavailable'));

  @override
  Future<Language?> readLanguage() => _inner.readLanguage();

  @override
  Future<StoredSession?> readSession() => _inner.readSession();

  @override
  Future<void> writeSession(StoredSession session) =>
      _inner.writeSession(session);

  @override
  Future<void> clearSession({bool wipe = false}) =>
      _inner.clearSession(wipe: wipe);

  @override
  Future<SessionPhase?> readPhase() => _inner.readPhase();

  @override
  Future<void> writePhase(SessionPhase phase) => _inner.writePhase(phase);

  @override
  Future<String?> readDeviceKey() => _inner.readDeviceKey();

  @override
  Future<void> writeDeviceKey(String deviceKey) =>
      _inner.writeDeviceKey(deviceKey);
}
