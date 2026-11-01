import 'dart:async';

import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/advisory/advisory_providers.dart';
import 'package:farmer/src/features/advisory/advisory_screen.dart';
import 'package:farmer/src/features/advisory/notice_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'notices_spy.dart';

/// Ravi's pinned FA notice (unread, 4 days old).
const pinnedNotice = '73d9ad83-f57e-5b12-adc8-6a11bf1aac41';

/// A notices repository with an empty inbox.
class _EmptyNotices implements NoticesRepository {
  @override
  Future<CursorPage<Notice>> listNotices({int? limit, String? cursor}) async =>
      const CursorPage.empty();

  @override
  Future<int> getUnreadCount() async => 0;

  @override
  Future<void> markRead(String noticeId) async {}

  @override
  Future<void> markListened(String noticeId) async {}
}

Notice _notice(String id, {required bool pinned, required int ageHours}) =>
    Notice(
      id: id,
      kind: NoticeKind.advisory,
      sender: NoticeSender.ho,
      titleTe: id,
      bodyTe: id,
      titleEn: null,
      bodyEn: null,
      audioUrl: null,
      refType: null,
      refId: null,
      pinned: pinned,
      readAt: null,
      listenedAt: null,
      createdAt: testClock.now().subtract(Duration(hours: ageHours)),
    );

void main() {
  group('AdvisoryScreen', () {
    testWidgets('pinned first, then newest; unread dots and count', (
      tester,
    ) async {
      final container = await createTestContainer();
      await pumpScreen(tester, const AdvisoryScreen(), container: container);

      expect(find.text('సలహాలు'), findsOneWidget);
      expect(find.text('3 కొత్తవి'), findsOneWidget);
      final cards = tester
          .widgetList<NoticeCard>(find.byType(NoticeCard))
          .toList();
      expect(cards.first.title, 'మీ పత్తి కాయ దశలో ఉంది');
      expect(cards.first.pinned, isTrue);
      expect(cards[1].title, 'గులాబీ రంగు పురుగు జాగ్రత్త');
      expect(cards[1].meta, '2 గంటల క్రితం');
      expect(cards[1].source, 'షణ్ముఖ');
      expect(cards[2].meta, 'నిన్న');
      expect(cards[2].source, 'CIV');

      final all = container.read(noticesControllerProvider).requireValue.items;
      expect(all.where((n) => !n.isRead), hasLength(3));
      expect(
        tester
            .widgetList<NoticeCard>(
              find.byType(NoticeCard, skipOffstage: false),
            )
            .where((c) => c.unread),
        hasLength(3),
      );
    });

    testWidgets('a listened notice carries the Listened tag', (tester) async {
      final container = await createTestContainer();
      await pumpScreen(tester, const AdvisoryScreen(), container: container);
      await tester.scrollUntilVisible(find.textContaining('విన్నారు'), 300);
      expect(find.text('విత్తే ముందు విత్తన శుద్ధి'), findsOneWidget);
    });

    testWidgets('empty inbox: one card', (tester) async {
      final container = await createTestContainer(
        overrides: [
          noticesRepositoryProvider.overrideWithValue(_EmptyNotices()),
        ],
      );
      await pumpScreen(tester, const AdvisoryScreen(), container: container);
      expect(find.text('ఇంకా సలహాలు లేవు'), findsOneWidget);
      expect(
        find.text('కొత్త సలహాలు వస్తే ఇక్కడ కనిపిస్తాయి.'),
        findsOneWidget,
      );
      expect(find.text('కొత్తవి లేవు'), findsOneWidget);
      expect(find.byType(NoticeCard), findsNothing);
    });

    testWidgets('offline: one card, Try again reloads', (tester) async {
      final backend = testBackend();
      final container = await createTestContainer(
        backend: backend,
        scenario: MockScenario.offline,
      );
      await pumpScreen(tester, const AdvisoryScreen(), container: container);
      expect(find.text('ఇంటర్నెట్ లేదు'), findsOneWidget);

      backend.scenario = MockScenario.normal;
      await tester.tap(find.byType(OrbitButton));
      await tester.pumpAndSettle();
      expect(find.byType(NoticeCard), findsWidgets);
      expect(find.text('3 కొత్తవి'), findsOneWidget);
    });

    testWidgets('server error shows the error card', (tester) async {
      final container = await createTestContainer(
        scenario: MockScenario.serverError,
      );
      await pumpScreen(tester, const AdvisoryScreen(), container: container);
      expect(find.text('ఏదో తప్పు జరిగింది'), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      final container = await createTestContainer(language: Language.en);
      await pumpScreen(
        tester,
        const AdvisoryScreen(),
        container: container,
        locale: const Locale('en'),
      );
      expect(find.text('Crop advisory'), findsOneWidget);
      expect(find.text('3 new'), findsOneWidget);
      expect(find.text('Your cotton is at the boll stage'), findsOneWidget);
      expect(find.text('Pink bollworm watch'), findsOneWidget);
      expect(find.textContaining('Pinned'), findsOneWidget);
    });
  });

  group('inbox order and paging', () {
    test('pinned first, then newest first', () {
      final ordered = inboxOrder([
        _notice('old', pinned: false, ageHours: 48),
        _notice('pinned-old', pinned: true, ageHours: 96),
        _notice('new', pinned: false, ageHours: 1),
        _notice('pinned-new', pinned: true, ageHours: 5),
      ]);
      expect(ordered.map((n) => n.id), [
        'pinned-new',
        'pinned-old',
        'new',
        'old',
      ]);
    });

    test('pages with the cursor until the last page', () async {
      final container = await createTestContainer(
        overrides: [noticesPageSizeProvider.overrideWithValue(4)],
      );
      final first = await container.read(noticesControllerProvider.future);
      expect(first.items, hasLength(4));
      expect(first.hasMore, isTrue);
      await container.read(noticesControllerProvider.notifier).loadMore();
      final all = container.read(noticesControllerProvider).requireValue;
      expect(all.items, hasLength(6));
      expect(all.hasMore, isFalse);
    });

    test('a pinned notice on a later page stays where it falls', () async {
      final container = await createTestContainer(
        overrides: [noticesPageSizeProvider.overrideWithValue(2)],
      );
      // Server order: newest first, pinned or not.
      final server = await container
          .read(noticesRepositoryProvider)
          .listNotices(limit: maxNoticesPageSize);
      final pinnedAt = server.items.indexWhere((n) => n.pinned);
      expect(pinnedAt, greaterThanOrEqualTo(2), reason: 'not on page 1');

      await container.read(noticesControllerProvider.future);
      final notifier = container.read(noticesControllerProvider.notifier);
      while (container.read(noticesControllerProvider).requireValue.hasMore) {
        await notifier.loadMore();
      }
      final shown = container.read(noticesControllerProvider).requireValue;
      // Loading more never moved a notice already on screen.
      expect(shown.items.map((n) => n.id), server.items.map((n) => n.id));
    });

    test('a page that arrives after a refresh is dropped', () async {
      final spy = NoticesSpy();
      final container = await createTestContainer(
        overrides: [
          spyOnNotices(spy),
          noticesPageSizeProvider.overrideWithValue(2),
        ],
      );
      container.listen(noticesControllerProvider, (_, _) {});
      await container.read(noticesControllerProvider.future);

      spy.laterPages = Completer();
      final more = container
          .read(noticesControllerProvider.notifier)
          .loadMore();
      // Pulled down to refresh while page 2 is on its way.
      container.invalidate(noticesControllerProvider);
      final fresh = await container.read(noticesControllerProvider.future);
      expect(fresh.items, hasLength(2));

      spy.laterPages!.complete();
      await more;
      final now = container.read(noticesControllerProvider).requireValue;
      expect(now.items.map((n) => n.id), fresh.items.map((n) => n.id));
      expect(now.loadingMore, isFalse);
    });

    testWidgets('a failed next page shows on the footer; Try again loads it', (
      tester,
    ) async {
      final backend = testBackend();
      final container = await createTestContainer(
        backend: backend,
        overrides: [noticesPageSizeProvider.overrideWithValue(2)],
      );
      await container.read(noticesControllerProvider.future);
      backend.scenario = MockScenario.offline;
      await pumpScreen(tester, const AdvisoryScreen(), container: container);

      final footer = find.byType(LoadMoreFooter);
      await tester.scrollUntilVisible(footer, 300);
      await tester.pumpAndSettle();
      expect(find.text(te.errorNetwork), findsOneWidget);
      expect(find.byType(NoticeCard, skipOffstage: false), findsNWidgets(2));

      backend.scenario = MockScenario.normal;
      await tester.tap(
        find.descendant(of: footer, matching: find.byType(OrbitButton)),
      );
      await tester.pumpAndSettle();
      expect(find.text(te.errorNetwork), findsNothing);
      expect(
        container.read(noticesControllerProvider).requireValue.items.length,
        greaterThan(2),
      );
    });

    testWidgets('the inbox loads the next page at the end of the list', (
      tester,
    ) async {
      final container = await createTestContainer(
        overrides: [noticesPageSizeProvider.overrideWithValue(2)],
      );
      await pumpScreen(tester, const AdvisoryScreen(), container: container);
      await tester.scrollUntilVisible(find.text('మీ FA: సురేష్ కె'), 300);
      await tester.pumpAndSettle();
      expect(
        container.read(noticesControllerProvider).requireValue.hasMore,
        isFalse,
      );
    });
  });

  group('noticeTime', () {
    testWidgets('minutes, hours, yesterday, days, then the date', (
      tester,
    ) async {
      late OrbitLocalizations l10n;
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('en'),
          delegates: OrbitLocalizations.localizationsDelegates,
          child: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );
      final now = testClock.now(); // 10:30 IST, 1 Nov
      String ago(Duration d) => noticeTime(l10n, now.subtract(d), now);
      expect(ago(Duration.zero), '1 min ago');
      expect(ago(const Duration(minutes: 20)), '20 min ago');
      expect(ago(const Duration(hours: 2)), '2 h ago');
      expect(ago(const Duration(hours: 12)), 'Yesterday');
      expect(ago(const Duration(days: 4)), '4 days ago');
      expect(ago(const Duration(days: 20)), 'Oct 12');
    });
  });

  screenLayoutTest('Crop advisory inbox', () => const AdvisoryScreen());
  screenLayoutTest(
    'Crop advisory inbox offline',
    () => const AdvisoryScreen(),
    scenario: MockScenario.offline,
  );
}
