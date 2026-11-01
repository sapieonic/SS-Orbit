import 'dart:async';

import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/advisory/advisory_providers.dart';
import 'package:farmer/src/features/farm/farm_providers.dart';
import 'package:farmer/src/features/fas/fas_providers.dart';
import 'package:farmer/src/routing/router.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/async_view.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../support/harness.dart';
import 'advisory/notices_spy.dart';
import 'onboarding/profile_spy.dart';

const _frame = Duration(milliseconds: 16);

/// Text only Ravi's data shows: his name (Home header, My farm, the FAs'
/// WhatsApp greeting is not on screen), his visits' stages (My visits), his
/// pink-bollworm advisory (Crop advice) and his cotton crop (Home, Calendar,
/// My farm).
const _raviTexts = ['రవి', 'కాయ దశ', 'పూత దశ', 'గులాబీ రంగు పురుగు', 'పత్తి'];

/// Every screen Ravi opens, each one so its providers hold his data, with
/// text only his data shows there.
const _raviScreens = [
  (Routes.home, 'రవి'),
  (Routes.fas, 'సురేష్'),
  (Routes.calendar, 'పత్తి'),
  (Routes.visits, 'కాయ దశ'),
  (Routes.advisory, 'గులాబీ రంగు పురుగు'),
  (Routes.farm, 'రవి'),
];

void main() {
  /// Ravi has agreed to two purposes (programme, loyalty); Venkatesh to one.
  Finder agreedPills() => statusPill(te.labelConsentState('granted'));

  void expectNothingOfRavi(WidgetTester tester, String when) {
    for (final text in _raviTexts) {
      expect(
        find.textContaining(text),
        findsNothing,
        reason: '$when shows Ravi\'s "$text"',
      );
    }
    expect(
      tester.widgetList(agreedPills()).length,
      lessThan(2),
      reason: '$when shows Ravi\'s consents',
    );
  }

  /// Pumps one frame at a time until [future] completes, checking each.
  Future<T> pumpUntil<T>(
    WidgetTester tester,
    Future<T> future,
    void Function(String frame) check,
  ) async {
    var done = false;
    final result = future.whenComplete(() => done = true);
    for (var i = 0; !done; i++) {
      expect(i, lessThan(500), reason: 'never completed');
      await tester.pump(_frame);
      check('frame $i');
    }
    return result;
  }

  /// Signs Ravi in (with a second consent, loyalty) and opens every farmer
  /// screen, so each provider holds his data. Ends on Home.
  Future<(ProviderContainer, GoRouter)> raviOpensEverything(
    WidgetTester tester,
    MockBackend backend,
  ) async {
    final container = await createTestContainer(backend: backend);
    await container
        .read(farmerProfileRepositoryProvider)
        .setConsent(
          purpose: ConsentPurpose.loyalty,
          granted: true,
          noticeVersion: programmeConsentNoticeVersion,
        );
    await pumpFarmerApp(tester, container: container);
    // A tall phone, so every consent card is on screen at once.
    tester.view.physicalSize = const Size(360, 2400);
    final router = container.read(routerProvider);

    for (final (path, ravi) in _raviScreens) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.textContaining(ravi), findsWidgets, reason: path);
    }
    router.go(Routes.consents);
    await tester.pumpAndSettle();
    expect(agreedPills(), findsNWidgets(2));
    router.go(Routes.home);
    await tester.pumpAndSettle();
    expect(unreadBadge(tester), '3');
    expect(container.read(homeSavedAtProvider), testClock.now());
    return (container, router);
  }

  testWidgets('a second farmer never sees a frame of the first one\'s data', (
    tester,
  ) async {
    final backend = testBackend();
    final (container, router) = await raviOpensEverything(tester, backend);
    // Venkatesh's data loads an hour after Ravi's.
    testClock.advance(const Duration(hours: 1));

    // From here every call takes a while, so loading states get frames.
    backend.latency = const Duration(milliseconds: 300);
    final session = container.read(sessionProvider.notifier);
    await pumpUntil(tester, session.signOut(), (_) {});
    await tester.pumpAndSettle();
    expect(currentPath(router), Routes.login);

    void check(String when) {
      expectNothingOfRavi(tester, when);
      expect(
        container.read(homeSavedAtProvider),
        anyOf(isNull, testClock.now()),
        reason: '$when keeps the time of Ravi\'s data',
      );
    }

    await pumpUntil(tester, session.requestOtp(venkateshPhone), check);
    await pumpUntil(tester, session.verifyOtp(devOtp), check);
    await pumpFrames(tester, const Duration(seconds: 1), check);
    expect(currentPath(router), Routes.home);
    expect(find.textContaining('వెంకటేష్'), findsWidgets);
    expect(container.read(homeSavedAtProvider), testClock.now());

    for (final path in [
      Routes.fas,
      Routes.calendar,
      Routes.visits,
      Routes.advisory,
      Routes.farm,
      Routes.consents,
    ]) {
      router.go(path);
      await pumpFrames(
        tester,
        const Duration(seconds: 1),
        (f) => check('$path $f'),
      );
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: '$path loaded',
      );
    }
    expect(agreedPills(), findsOneWidget, reason: 'Venkatesh\'s consents');
    router.go(Routes.calendar);
    await tester.pumpAndSettle();
    expect(find.textContaining('వరి'), findsWidgets, reason: 'his paddy');
    router.go(Routes.farm);
    await tester.pumpAndSettle();
    expect(find.textContaining('వెంకటేష్'), findsWidgets);
  });

  group('an answer for the first farmer that arrives after the second one '
      'signed in is dropped', () {
    Future<void> venkateshSignsIn(ProviderContainer c) async {
      final session = c.read(sessionProvider.notifier);
      await session.signOut();
      await session.requestOtp(venkateshPhone);
      await session.verifyOtp(devOtp);
    }

    test('a consent saved', () async {
      final spy = ProfileSpy();
      final c = await createTestContainer(overrides: [spyOnProfile(spy)]);
      c.listen(farmConsentsProvider, (_, _) {});
      await c.read(farmConsentsProvider.future);

      final answer = Completer<void>();
      spy.holdConsentAnswers = answer.future;
      final saving = c
          .read(farmConsentsProvider.notifier)
          .setConsent(ConsentPurpose.loyalty, granted: true);
      await pumpEventQueue(); // Ravi's loyalty consent is on the server.
      await venkateshSignsIn(c);
      final venkatesh = await c.read(farmConsentsProvider.future);

      answer.complete();
      await saving;
      expect(c.read(farmConsentsProvider).fresh.value, same(venkatesh));
    });

    test(
      'a notice marked read, over a failed load of the next inbox',
      () async {
        final spy = NoticesSpy();
        final c = await createTestContainer(overrides: [spyOnNotices(spy)]);
        c.listen(noticesControllerProvider, (_, _) {});
        final ravis = await c.read(noticesControllerProvider.future);

        final answer = Completer<void>();
        spy.holdMarkAnswers = answer.future;
        final marking = c
            .read(noticesControllerProvider.notifier)
            .markRead(ravis.items.firstWhere((n) => !n.isRead).id);
        await pumpEventQueue(); // Ravi's mark is on the server.
        // Venkatesh's inbox does not load: Riverpod keeps Ravi's under the
        // error.
        spy.listError = const ApiError.network();
        await venkateshSignsIn(c);
        await expectLater(
          c.read(noticesControllerProvider.future),
          throwsA(isA<ApiError>()),
        );
        expect(c.read(noticesControllerProvider).fresh.hasValue, isFalse);

        answer.complete();
        await marking;
        expect(c.read(noticesControllerProvider).fresh.hasValue, isFalse);
      },
    );

    Future<(ProviderContainer, _SlowCallbackAnswers)>
    withSlowCallbacks() async {
      late _SlowCallbackAnswers slow;
      final c = await createTestContainer(
        overrides: [
          fieldAssistantRepositoryProvider.overrideWith(
            (ref) => slow = _SlowCallbackAnswers(
              ref.watch(farmerRepositoriesProvider).fieldAssistants,
            ),
          ),
        ],
      );
      c.listen(openCallbackProvider, (_, _) {});
      await c.read(openCallbackProvider.future);
      return (c, slow);
    }

    test('a call-back asked for', () async {
      final (c, slow) = await withSlowCallbacks();
      expect(c.read(openCallbackProvider).value, isNull);

      final answer = Completer<void>();
      slow.hold = answer.future;
      final asking = c.read(openCallbackProvider.notifier).request();
      await pumpEventQueue(); // Ravi's request is on the server.
      await venkateshSignsIn(c);
      expect(await c.read(openCallbackProvider.future), isNull);

      answer.complete();
      final ravis = await asking;
      expect(ravis.status, CallbackStatus.open);
      expect(c.read(openCallbackProvider).fresh.value, isNull);
    });

    test('a call-back cancelled', () async {
      final (c, slow) = await withSlowCallbacks();
      await c.read(openCallbackProvider.notifier).request();

      final answer = Completer<void>();
      slow.hold = answer.future;
      final cancelling = c.read(openCallbackProvider.notifier).cancel();
      await pumpEventQueue(); // Ravi's cancel is on the server.
      await venkateshSignsIn(c);
      slow.hold = null;
      final venkatesh = await c.read(openCallbackProvider.notifier).request();
      expect(c.read(openCallbackProvider).value, same(venkatesh));

      answer.complete();
      await cancelling;
      expect(c.read(openCallbackProvider).fresh.value, same(venkatesh));
    });
  });

  testWidgets('when the second farmer\'s first load fails, every screen shows '
      'the error, never the first farmer\'s data', (tester) async {
    final backend = testBackend();
    final (container, router) = await raviOpensEverything(tester, backend);

    final session = container.read(sessionProvider.notifier);
    await session.signOut();
    await tester.pumpAndSettle();
    await session.requestOtp(venkateshPhone);
    await session.verifyOtp(devOtp);
    // Signed in; every call from here on fails (GET /me first).
    backend.scenario = MockScenario.serverError;
    await tester.pumpAndSettle();
    expect(currentPath(router), Routes.home);

    for (final path in [
      Routes.home,
      Routes.fas,
      Routes.calendar,
      Routes.visits,
      Routes.advisory,
      Routes.farm,
      Routes.consents,
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expectNothingOfRavi(tester, path);
      expect(find.text(te.farmerStateErrorTitle), findsOneWidget, reason: path);
      expect(unreadBadge(tester), isNull, reason: '$path: Ravi\'s 3 unread');
    }
    expect(container.read(homeSavedAtProvider), isNull);

    // Try again once the server is back: Venkatesh's data.
    backend.scenario = MockScenario.normal;
    router.go(Routes.home);
    await tester.pumpAndSettle();
    await tester.tap(orbitButton(te.commonRetry));
    await tester.pumpAndSettle();
    expect(find.textContaining('వెంకటేష్'), findsWidgets);
    expectNothingOfRavi(tester, 'after Try again');
  });
}

/// The FA repository of the app, except that the answers to call-back
/// requests and cancels arrive only once [hold] completes (when set): the
/// call reaches the server at once.
class _SlowCallbackAnswers implements FieldAssistantRepository {
  _SlowCallbackAnswers(this._inner);

  final FieldAssistantRepository _inner;

  Future<void>? hold;

  @override
  Future<List<FaOption>> listFas({AreaLevel? level}) =>
      _inner.listFas(level: level);

  @override
  Future<Callback?> getOpenCallback() => _inner.getOpenCallback();

  @override
  Future<Callback> requestCallback() async {
    final answer = await _inner.requestCallback();
    await hold;
    return answer;
  }

  @override
  Future<Callback> cancelCallback(String callbackId) async {
    final answer = await _inner.cancelCallback(callbackId);
    await hold;
    return answer;
  }
}

/// The badge on the Advisory tab, or null when it has none.
String? unreadBadge(WidgetTester tester) => tester
    .widget<OrbitNavigationBar>(find.byType(OrbitNavigationBar))
    .destinations[2]
    .badge;
