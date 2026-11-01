import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/fas/fas_providers.dart';
import 'package:farmer/src/features/fas/fas_screen.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:farmer/src/shared/launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

const _sureshPhone = '+919000000014';

void main() {
  Future<FakeContactLauncher> pumpFas(
    WidgetTester tester,
    ProviderContainer container, {
    FakeContactLauncher? launcher,
    Locale locale = const Locale('te'),
  }) async {
    final fake = launcher ?? FakeContactLauncher();
    await pumpRouted(
      tester,
      container: container,
      path: Routes.fas,
      screen: const FasScreen(),
      launcher: fake,
      locale: locale,
    );
    return fake;
  }

  group('FasScreen list', () {
    testWidgets('village tab: my FA with the tag, lead and level', (
      tester,
    ) async {
      await pumpFas(tester, await createTestContainer());

      expect(find.text(te.farmerFasTitle), findsOneWidget);
      expect(find.text(te.farmerFasCount(count: 1)), findsOneWidget);
      expect(find.text('సురేష్ కె'), findsOneWidget);
      expect(find.text(te.farmerFasYourFa), findsOneWidget);
      final card = tester.widget<FaCard>(find.byType(FaCard));
      expect(card.highlighted, isTrue);
      // Lead and level, languages, working hours: one line each.
      expect(
        card.detail,
        [
          '${te.farmerFasLead} · ${te.labelCoverageLevel('village')}',
          te.farmerFasLanguages(languages: 'తెలుగు, English'),
          te.farmerFasWorkingHours(hours: 'Mon-Sat 8am-5pm'),
        ].join('\n'),
      );
      expect(find.text(te.farmerFasCallHint), findsOneWidget);
    });

    testWidgets('a tab with no FAs says so', (tester) async {
      final container = await createTestContainer(
        overrides: [fasProvider.overrideWith((ref, level) async => const [])],
      );
      await pumpFas(tester, container);

      await tester.tap(find.text(te.labelCoverageLevel('district')));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(StateCard, te.farmerFasCount(count: 0)),
        findsOneWidget,
      );
      expect(find.byType(FaCard), findsNothing);
      expect(find.text(te.farmerFasCallHint), findsNothing);
      // The farmer has an FA (Home), so not the "no FA yet" card.
      expect(find.text(te.farmerStateNoFaTitle), findsNothing);
    });

    testWidgets('mandal and district tabs list their FAs', (tester) async {
      await pumpFas(tester, await createTestContainer());

      await tester.tap(find.text(te.labelCoverageLevel('mandal')));
      await tester.pumpAndSettle();
      expect(find.text('రమేష్ బి'), findsOneWidget);
      expect(find.text(te.farmerFasYourFa), findsNothing);
      expect(
        tester.widget<FaCard>(find.byType(FaCard)).detail,
        startsWith('${te.labelCoverageLevel('mandal')}\n'),
        reason: 'not the lead; the level, then languages and hours',
      );

      await tester.tap(find.text(te.labelCoverageLevel('district')));
      await tester.pumpAndSettle();
      expect(find.text('అనిత ఆర్'), findsOneWidget);
    });

    testWidgets('Call dials and WhatsApp opens a chat with the FA', (
      tester,
    ) async {
      final launcher = await pumpFas(tester, await createTestContainer());

      await tester.tap(findLabel(te.commonCall));
      await tester.pump();
      expect(launcher.calls, [_sureshPhone]);

      await tester.tap(findLabel(te.commonWhatsapp));
      await tester.pump();
      expect(launcher.whatsApps, [_sureshPhone]);
      // The chat opens with who is writing already typed.
      expect(launcher.whatsAppTexts, [
        te.farmerFasWhatsappMessage(name: 'రవి కె', village: 'కొండాపూర్'),
      ]);
    });

    testWidgets('WhatsApp missing: a snack bar says so', (tester) async {
      await pumpFas(
        tester,
        await createTestContainer(),
        launcher: FakeContactLauncher(opens: false),
      );

      await tester.tap(findLabel(te.commonWhatsapp));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerFasWhatsappFailed), findsOneWidget);
    });

    testWidgets('no FA assigned: one card with the helpline, no call-back', (
      tester,
    ) async {
      final launcher = await pumpFas(
        tester,
        await createTestContainer(scenario: MockScenario.noFaAssigned),
      );

      expect(find.text(te.farmerStateNoFaTitle), findsOneWidget);
      expect(findLabel(te.farmerFasCallback), findsNothing);
      await tester.tap(findLabel(te.farmerStateNoFaAction));
      await tester.pump();
      expect(launcher.calls, [helplinePhone]);
    });

    testWidgets('offline: the offline card and no call-back button', (
      tester,
    ) async {
      await pumpFas(
        tester,
        await createTestContainer(scenario: MockScenario.offline),
      );

      expect(find.text(te.farmerStateOfflineTitle), findsOneWidget);
      expect(findLabel(te.farmerFasCallback), findsNothing);
    });

    testWidgets('server error: the error card, Try again loads the list', (
      tester,
    ) async {
      final container = await createTestContainer(
        scenario: MockScenario.serverError,
      );
      await pumpFas(tester, container);
      expect(find.text(te.farmerStateErrorTitle), findsOneWidget);

      container.read(mockScenarioProvider.notifier).select(MockScenario.normal);
      await tester.tap(findLabel(te.commonRetry));
      await tester.pumpAndSettle();
      expect(find.text('సురేష్ కె'), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      await pumpFas(
        tester,
        await createTestContainer(),
        locale: const Locale('en'),
      );

      expect(find.text(en.farmerFasTitle), findsOneWidget);
      expect(find.text('Suresh K'), findsOneWidget);
      expect(find.text('1 FA'), findsOneWidget);
      expect(findLabel(en.farmerFasCallback), findsOneWidget);
    });
  });

  group('FasScreen call-back', () {
    testWidgets('ask for a call-back, then Undo', (tester) async {
      final container = await createTestContainer();
      await pumpFas(tester, container);

      await tester.tap(findLabel(te.farmerFasCallback));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerFasCallbackSent), findsOneWidget);
      expect(
        find.text(te.farmerFasCallbackSentBody(name: 'సురేష్ కె')),
        findsOneWidget,
      );
      final repo = container.read(fieldAssistantRepositoryProvider);
      expect((await repo.getOpenCallback())?.isOpen, isTrue);

      await tester.tap(findLabel(te.commonUndo));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerFasCallbackCancelled), findsOneWidget);
      expect(findLabel(te.farmerFasCallback), findsOneWidget);
      expect(await repo.getOpenCallback(), isNull);
    });

    testWidgets('an open request shows as sent on entry', (tester) async {
      final container = await createTestContainer();
      await container.read(fieldAssistantRepositoryProvider).requestCallback();
      await pumpFas(tester, container);

      expect(find.text(te.farmerFasCallbackSent), findsOneWidget);
      expect(findLabel(te.farmerFasCallback), findsNothing);
    });

    testWidgets('Undo after the FA already called: says so, clears it', (
      tester,
    ) async {
      final backend = testBackend();
      final container = await createTestContainer(backend: backend);
      final callback = await container
          .read(fieldAssistantRepositoryProvider)
          .requestCallback();
      await pumpFas(tester, container);

      backend.simulateFaClosesCallback(callback.id);
      await tester.tap(findLabel(te.commonUndo));
      await tester.pumpAndSettle();

      expect(
        find.text(te.describeError(ApiErrorCode.callbackClosed)),
        findsOneWidget,
      );
      expect(find.text(te.farmerFasCallbackSent), findsNothing);
      expect(findLabel(te.farmerFasCallback), findsOneWidget);
    });

    testWidgets('offline request: error with Try again, which sends it', (
      tester,
    ) async {
      final container = await createTestContainer();
      await pumpFas(tester, container);

      container
          .read(mockScenarioProvider.notifier)
          .select(MockScenario.offline);
      await tester.tap(findLabel(te.farmerFasCallback));
      await tester.pumpAndSettle();
      expect(find.text(te.describeError(ApiErrorCode.network)), findsOneWidget);
      expect(find.text(te.farmerFasCallbackSent), findsNothing);

      container.read(mockScenarioProvider.notifier).select(MockScenario.normal);
      await tester.tap(find.widgetWithText(SnackBarAction, te.commonRetry));
      await tester.pumpAndSettle();
      expect(find.text(te.farmerFasCallbackSent), findsOneWidget);
    });

    test('request without an FA throws no_fa_assigned', () async {
      final container = await createTestContainer(
        scenario: MockScenario.noFaAssigned,
      );
      final sub = container.listen(openCallbackProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(openCallbackProvider.future);

      await expectLater(
        container.read(openCallbackProvider.notifier).request(),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.noFaAssigned,
          ),
        ),
      );
    });

    test(
      'no_fa_assigned refreshes Home, whose FA card is out of date',
      () async {
        final backend = testBackend();
        final container = await createTestContainer(backend: backend);
        container.listen(farmerHomeProvider, (_, _) {});
        final sub = container.listen(openCallbackProvider, (_, _) {});
        addTearDown(sub.close);
        expect((await container.read(farmerHomeProvider.future)).fa, isNotNull);
        await container.read(openCallbackProvider.future);

        // HO took the FA away since Home loaded.
        backend.scenario = MockScenario.noFaAssigned;
        await expectLater(
          container.read(openCallbackProvider.notifier).request(),
          throwsA(isA<ApiError>()),
        );
        expect(container.read(farmerHomeProvider).isRefreshing, isTrue);
        expect((await container.read(farmerHomeProvider.future)).fa, isNull);
      },
    );

    test(
      'Home is refreshed also when Look for FAs was left meanwhile',
      () async {
        final backend = testBackend();
        final container = await createTestContainer(backend: backend);
        container.listen(farmerHomeProvider, (_, _) {});
        final sub = container.listen(openCallbackProvider, (_, _) {});
        await container.read(farmerHomeProvider.future);
        await container.read(openCallbackProvider.future);

        backend
          ..scenario = MockScenario.noFaAssigned
          ..latency = const Duration(milliseconds: 50);
        final request = container.read(openCallbackProvider.notifier).request();
        sub.close(); // the farmer went back: the call-back state is disposed
        await container.pump();
        expect(container.exists(openCallbackProvider), isFalse);

        await expectLater(
          request,
          throwsA(
            isA<ApiError>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.noFaAssigned,
            ),
          ),
        );
        backend.latency = Duration.zero;
        expect((await container.read(farmerHomeProvider.future)).fa, isNull);
      },
    );

    test('asking twice keeps one open request', () async {
      final container = await createTestContainer();
      final sub = container.listen(openCallbackProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(openCallbackProvider.future);
      final notifier = container.read(openCallbackProvider.notifier);

      final first = await notifier.request();
      final second = await notifier.request();
      expect(second.id, first.id);
      expect(container.read(openCallbackProvider).value?.id, first.id);
    });
  });

  group('FasScreen layout', () {
    screenLayoutTest('Look for FAs', () => const FasScreen());
    screenLayoutTest(
      'Look for FAs without an FA',
      () => const FasScreen(),
      scenario: MockScenario.noFaAssigned,
    );
    screenLayoutTest(
      'Look for FAs offline',
      () => const FasScreen(),
      scenario: MockScenario.offline,
    );

    for (final scale in textScales) {
      testWidgets('request-sent banner fits 360x640 at text scale $scale', (
        tester,
      ) async {
        final container = await createTestContainer();
        await container
            .read(fieldAssistantRepositoryProvider)
            .requestCallback();
        await pumpScreen(
          tester,
          const FasScreen(),
          container: container,
          textScale: scale,
        );
        expect(find.text(te.farmerFasCallbackSent), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
      });
    }
  });
}
