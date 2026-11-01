import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/advisory/advisory_providers.dart';
import 'package:farmer/src/features/visits/visits_providers.dart';
import 'package:farmer/src/routing/resume_refresh.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../support/harness.dart';

void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(DateTime.utc(2026, 11, 1, 5))); // 10:30 IST

  Future<ProviderContainer> signedIn() => createTestContainer(
    backend: MockBackend(clock: clock, latency: Duration.zero),
    clock: clock,
  );

  test('Home reloads on the first resume of a new IST day', () async {
    final c = await signedIn();
    c.listen(homeSavedAtProvider, (_, _) {});
    await c.read(farmerHomeProvider.future);
    expect(c.read(homeSavedAtProvider), clock.now());
    final refresh = c.read(resumeRefreshProvider);

    clock.set(DateTime.utc(2026, 11, 1, 18)); // 23:30 IST, same day
    refresh.onResume();
    expect(c.read(farmerHomeProvider).isRefreshing, isFalse);

    clock.set(DateTime.utc(2026, 11, 1, 18, 31)); // 00:01 IST, 2 Nov
    refresh.onResume();
    expect(
      c.read(farmerHomeProvider),
      isA<AsyncValue<FarmerHome>>()
          .having((v) => v.isRefreshing, 'isRefreshing', isTrue)
          .having((v) => v.hasValue, 'keeps the data meanwhile', isTrue),
    );
    await c.read(farmerHomeProvider.future);
    expect(c.read(homeSavedAtProvider), clock.now());

    refresh.onResume();
    expect(c.read(farmerHomeProvider).isRefreshing, isFalse, reason: 'once');
  });

  test('a failed refresh keeps the time of the data on screen', () async {
    final backend = MockBackend(clock: clock, latency: Duration.zero);
    final c = await createTestContainer(backend: backend, clock: clock);
    c.listen(homeSavedAtProvider, (_, _) {});
    await c.read(farmerHomeProvider.future);
    final loaded = clock.now();

    // Two hours later, offline, the farmer pulls to refresh.
    clock.advance(const Duration(hours: 2));
    backend.scenario = MockScenario.offline;
    c.invalidate(farmerHomeProvider);
    expect(c.read(homeSavedAtProvider), loaded, reason: 'while refreshing');
    await expectLater(
      c.read(farmerHomeProvider.future),
      throwsA(isA<ApiError>()),
    );
    expect(c.read(farmerHomeProvider).hasValue, isTrue);
    expect(c.read(homeSavedAtProvider), loaded);
  });

  test(
    'a new-day refresh that failed is tried again on the next resume',
    () async {
      final backend = MockBackend(clock: clock, latency: Duration.zero);
      final c = await createTestContainer(backend: backend, clock: clock);
      c.listen(homeSavedAtProvider, (_, _) {});
      await c.read(farmerHomeProvider.future);
      final loaded = clock.now();
      final refresh = c.read(resumeRefreshProvider);

      // The next morning, offline.
      clock.set(DateTime.utc(2026, 11, 2, 2)); // 07:30 IST, 2 Nov
      backend.scenario = MockScenario.offline;
      refresh.onResume();
      expect(c.read(farmerHomeProvider).isRefreshing, isTrue);
      expect(c.read(homeSavedAtProvider), loaded);
      await expectLater(
        c.read(farmerHomeProvider.future),
        throwsA(isA<ApiError>()),
      );
      expect(c.read(homeSavedAtProvider), loaded, reason: 'still yesterday\'s');

      // Back online later that day: the next resume tries again.
      clock.advance(const Duration(hours: 2));
      backend.scenario = MockScenario.normal;
      refresh.onResume();
      expect(c.read(farmerHomeProvider).isRefreshing, isTrue);
      await c.read(farmerHomeProvider.future);
      expect(c.read(homeSavedAtProvider), clock.now());
    },
  );

  test('crops reload once their season codes expire', () async {
    final c = await signedIn();
    final before = await c.read(cropsProvider.future);
    final validUntil = before.seasonCodes.validUntil;
    final refresh = c.read(resumeRefreshProvider);

    // The last valid IST day, late evening: still valid.
    clock.set(
      DateTime.utc(validUntil.year, validUntil.month, validUntil.day, 18),
    );
    refresh.onResume();
    expect(c.read(cropsProvider).isRefreshing, isFalse);

    clock.advance(const Duration(hours: 1)); // after IST midnight
    refresh.onResume();
    expect(c.read(cropsProvider).isRefreshing, isTrue);
    final after = await c.read(cropsProvider.future);
    expect(after.seasonCodes.validUntil.isAfter(validUntil), isTrue);
  });

  test('data that was never loaded is not loaded on resume', () async {
    final c = await signedIn();
    clock.advance(const Duration(days: 400));
    c.read(resumeRefreshProvider).onResume();
    expect(c.exists(farmerHomeProvider), isFalse);
    expect(c.exists(cropsProvider), isFalse);
  });

  group('messages on resume', () {
    /// Starts listening to the badge, inbox and visits and waits for them.
    Future<void> loadMessages(ProviderContainer c) async {
      c
        ..listen(unreadNoticesCountProvider, (_, _) {})
        ..listen(noticesControllerProvider, (_, _) {})
        ..listen(visitsControllerProvider, (_, _) {});
      await c.read(unreadNoticesCountProvider.future);
      await c.read(noticesControllerProvider.future);
      await c.read(visitsControllerProvider.future);
    }

    bool refreshing(ProviderContainer c) =>
        c.read(unreadNoticesCountProvider).isRefreshing &&
        c.read(noticesControllerProvider).isRefreshing &&
        c.read(visitsControllerProvider).isRefreshing;

    bool anyRefreshing(ProviderContainer c) =>
        c.read(unreadNoticesCountProvider).isRefreshing ||
        c.read(noticesControllerProvider).isRefreshing ||
        c.read(visitsControllerProvider).isRefreshing;

    test('badge, inbox and visits reload, at most every 5 minutes', () async {
      final c = await signedIn();
      final refresh = c.read(resumeRefreshProvider);
      await loadMessages(c);

      // Just loaded: a quick switch to another app reloads nothing.
      clock.advance(const Duration(minutes: 1));
      refresh.onResume();
      expect(anyRefreshing(c), isFalse);

      clock.advance(ResumeRefresh.messagesInterval);
      refresh.onResume();
      expect(refreshing(c), isTrue);
      expect(
        c.read(noticesControllerProvider).hasValue,
        isTrue,
        reason: 'the inbox stays on screen meanwhile',
      );
      await loadMessages(c);

      clock.advance(const Duration(minutes: 4));
      refresh.onResume();
      expect(anyRefreshing(c), isFalse, reason: 'throttled');

      clock.advance(const Duration(minutes: 1));
      refresh.onResume();
      expect(refreshing(c), isTrue);
    });

    test('the badge catches up with a notice read elsewhere', () async {
      final backend = MockBackend(clock: clock, latency: Duration.zero);
      final c = await createTestContainer(backend: backend, clock: clock);
      c.listen(unreadNoticesCountProvider, (_, _) {});
      final refresh = c.read(resumeRefreshProvider);
      final before = await c.read(unreadNoticesCountProvider.future);
      // Read in the background (on the web, or by the server).
      final notices = await c.read(noticesRepositoryProvider).listNotices();
      await c
          .read(noticesRepositoryProvider)
          .markRead(notices.items.firstWhere((n) => !n.isRead).id);

      clock.advance(ResumeRefresh.messagesInterval);
      refresh.onResume();
      expect(await c.read(unreadNoticesCountProvider.future), before - 1);
    });

    test('messages never loaded stay unloaded', () async {
      final c = await signedIn();
      clock.advance(const Duration(hours: 1));
      c.read(resumeRefreshProvider).onResume();
      expect(c.exists(noticesControllerProvider), isFalse);
      expect(c.exists(visitsControllerProvider), isFalse);
    });
  });

  testWidgets('the app coming back to the foreground on a new day', (
    tester,
  ) async {
    final c = await signedIn();
    await pumpFarmerApp(tester, container: c);
    final loaded = clock.now();
    expect(c.read(homeSavedAtProvider), loaded);

    clock.advance(const Duration(days: 1));
    // To the background and back, one step at a time like the engine.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(c.read(homeSavedAtProvider), clock.now());
  });
}
