import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/advisory/advisory_providers.dart';
import 'package:farmer/src/features/advisory/notice_screen.dart';
import 'package:farmer/src/features/advisory/notice_widgets.dart';
import 'package:farmer/src/routing/resume_refresh.dart';
import 'package:farmer/src/shared/async_view.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:farmer/src/shared/voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';
import 'notices_spy.dart';

/// Ravi's unread HO notice with a voice note (2 h old).
const audioNotice = 'b6251894-3842-53dc-aafe-406269497f57';

/// Ravi's unread, pinned FA notice without audio.
const pinnedNotice = '73d9ad83-f57e-5b12-adc8-6a11bf1aac41';

/// Ravi's read notice without audio.
const readNotice = '0413afad-c331-5861-abed-16c4aa152900';

Notice _loaded(ProviderContainer container, String id) => container
    .read(noticesControllerProvider)
    .requireValue
    .items
    .firstWhere((n) => n.id == id);

/// The header's listen button.
Finder get _listen => find.byType(ListenButton);

String _listenLabel(WidgetTester tester) =>
    tester.widget<ListenButton>(_listen).label;

void main() {
  group('NoticeScreen', () {
    testWidgets('opening an unread notice marks it read and the badge drops', (
      tester,
    ) async {
      final container = await createTestContainer();
      expect(await container.read(unreadNoticesCountProvider.future), 3);

      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: pinnedNotice),
        container: container,
      );

      expect(find.text('మీ పత్తి కాయ దశలో ఉంది'), findsOneWidget);
      expect(find.text('FA చెప్పినట్లు పొటాష్ వేయండి'), findsOneWidget);
      expect(find.textContaining('ముఖ్యమైనది'), findsOneWidget);
      // No voice note: a prompt saying so (not the inbox help), and a note.
      expect(
        tester
            .widget<ScreenListenButton>(find.byType(ScreenListenButton))
            .voiceKey,
        VoiceKeys.farmerInboxNoAudioVoice,
      );
      expect(find.text('ఈ సలహాకు ఆడియో లేదు'), findsOneWidget);

      expect(_loaded(container, pinnedNotice).isRead, isTrue);
      expect(await container.read(unreadNoticesCountProvider.future), 2);
      final fromServer = await container
          .read(noticesRepositoryProvider)
          .listNotices();
      expect(
        fromServer.items.firstWhere((n) => n.id == pinnedNotice).isRead,
        isTrue,
      );
    });

    testWidgets('a notice already read is not marked again', (tester) async {
      final spy = NoticesSpy();
      final container = await createTestContainer(
        overrides: [spyOnNotices(spy)],
      );
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: readNotice),
        container: container,
      );
      expect(find.text('ఆకు మచ్చ తెగులు'), findsOneWidget);
      expect(spy.markedRead, isEmpty);
      expect(await container.read(unreadNoticesCountProvider.future), 3);
    });

    testWidgets('marking read offline leaves it unread; the next open '
        'tries again', (tester) async {
      final spy = NoticesSpy()..markReadError = const ApiError.network();
      final container = await createTestContainer(
        overrides: [spyOnNotices(spy)],
      );
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: pinnedNotice),
        container: container,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('మీ పత్తి కాయ దశలో ఉంది'), findsOneWidget);
      expect(spy.markedRead, [pinnedNotice]);
      expect(_loaded(container, pinnedNotice).isRead, isFalse);
      expect(await container.read(unreadNoticesCountProvider.future), 3);

      spy.markReadError = null;
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: pinnedNotice),
        container: container,
      );
      expect(spy.markedRead, [pinnedNotice, pinnedNotice]);
      expect(_loaded(container, pinnedNotice).isRead, isTrue);
      expect(await container.read(unreadNoticesCountProvider.future), 2);
    });

    testWidgets('marking it read keeps the notice on screen, no spinner', (
      tester,
    ) async {
      final backend = testBackend();
      final container = await createTestContainer(backend: backend);
      await container.read(noticesControllerProvider.future);
      // The mark takes a while to reach the server.
      backend.latency = const Duration(milliseconds: 300);

      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: audioNotice),
        container: container,
      );
      expect(find.textContaining('గులాబీ రంగు పురుగు'), findsWidgets);
      expect(_loaded(container, audioNotice).isRead, isFalse);
      // Every state the screen could build from, also between frames.
      final shown = <AsyncValue<Notice?>>[];
      container.listen(
        noticeByIdProvider(audioNotice),
        (_, next) => shown.add(next.fresh),
      );

      await pumpFrames(tester, const Duration(milliseconds: 700), (when) {
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: when,
        );
        expect(find.byType(NoticeAudioButton), findsOneWidget, reason: when);
      });
      expect(_loaded(container, audioNotice).isRead, isTrue);
      expect(shown, isNotEmpty, reason: 'the notice followed the mark');
      expect(shown.where((v) => !v.hasValue), isEmpty);
    });

    testWidgets('a resume refresh keeps the notice on screen', (tester) async {
      final backend = testBackend();
      final container = await createTestContainer(backend: backend);
      final resume = container.read(resumeRefreshProvider);
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: audioNotice),
        container: container,
      );

      // Back after a while: the inbox and badge reload, slowly.
      backend.latency = const Duration(milliseconds: 300);
      testClock.advance(ResumeRefresh.messagesInterval);
      resume.onResume();
      expect(container.read(noticesControllerProvider).isRefreshing, isTrue);
      await pumpFrames(tester, const Duration(milliseconds: 700), (when) {
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: when,
        );
        expect(find.textContaining('గులాబీ రంగు పురుగు'), findsWidgets);
        expect(
          find.byType(NoticeAudioButton),
          findsOneWidget,
          reason: '$when: the header keeps the notice\'s Listen',
        );
      });
      expect(container.read(noticesControllerProvider).isLoading, isFalse);
    });

    testWidgets('voice note played to the end marks it listened', (
      tester,
    ) async {
      final player = FakeVoicePlayer();
      final container = await createTestContainer(voice: player);
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: audioNotice),
        container: container,
      );
      expect(find.byType(ScreenListenButton), findsNothing);
      expect(_listenLabel(tester), 'వినండి');

      await tester.tap(_listen);
      await tester.pump();
      expect(player.urlsPlayed.single.$2, audioNotice);
      expect(player.urlsPlayed.single.$1.host, MockBackend.mockHost);
      expect(_listenLabel(tester), 'ఆపండి');
      expect(_loaded(container, audioNotice).isListened, isFalse);

      player.complete(audioNotice);
      await tester.pumpAndSettle();
      expect(_loaded(container, audioNotice).isListened, isTrue);
      expect(find.textContaining('విన్నారు'), findsOneWidget);
      expect(_listenLabel(tester), 'వినండి');
      final fromServer = await container
          .read(noticesRepositoryProvider)
          .listNotices();
      expect(
        fromServer.items.firstWhere((n) => n.id == audioNotice).isListened,
        isTrue,
      );
    });

    testWidgets('a completion this session did not start is ignored', (
      tester,
    ) async {
      final player = FakeVoicePlayer();
      final container = await createTestContainer(voice: player);
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: audioNotice),
        container: container,
      );
      // Completion for a notice this session never started.
      player.complete(audioNotice);
      await tester.pumpAndSettle();
      expect(_loaded(container, audioNotice).isListened, isFalse);
    });

    testWidgets('audio that cannot be fetched shows an error, no crash', (
      tester,
    ) async {
      final player = FakeVoicePlayer();
      final container = await createTestContainer(voice: player);
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: audioNotice),
        container: container,
      );
      await tester.tap(_listen);
      await tester.pump();
      player.fail(audioNotice);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_listenLabel(tester), 'ఆడియో ప్లే కాలేదు');
      expect(
        tester.widget<ListenButton>(_listen).state,
        ListenState.unavailable,
      );
      expect(_loaded(container, audioNotice).isListened, isFalse);

      // Tapping again retries.
      await tester.tap(_listen);
      await tester.pump();
      expect(player.urlsPlayed, hasLength(2));
    });

    testWidgets('leaving the notice stops its voice note', (tester) async {
      final player = FakeVoicePlayer();
      final container = await createTestContainer(voice: player);
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: audioNotice),
        container: container,
      );
      await tester.tap(_listen);
      await tester.pump();
      expect(player.state.value.key, audioNotice);

      await tester.pumpWidget(const SizedBox());
      expect(player.state.value.key, isNull);
    });

    testWidgets('unknown notice: not found, with a way back', (tester) async {
      final container = await createTestContainer();
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: 'no-such-notice'),
        container: container,
      );
      expect(find.text('ఇది దొరకలేదు. మళ్ళీ తెరిచి చూడండి.'), findsOneWidget);
      expect(find.textContaining('వెనక్కి'), findsOneWidget);
    });

    testWidgets('offline: one card', (tester) async {
      final container = await createTestContainer(
        scenario: MockScenario.offline,
      );
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: pinnedNotice),
        container: container,
      );
      expect(find.text('ఇంటర్నెట్ లేదు'), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      final container = await createTestContainer(language: Language.en);
      await pumpScreen(
        tester,
        const NoticeScreen(noticeId: audioNotice),
        container: container,
        locale: const Locale('en'),
      );
      expect(find.text('Pink bollworm watch'), findsOneWidget);
      expect(find.text('Set pheromone traps this week.'), findsOneWidget);
      expect(find.text('2 h ago'), findsOneWidget);
      expect(_listenLabel(tester), 'Listen');
    });
  });

  screenLayoutTest(
    'Notice with a voice note',
    () => const NoticeScreen(noticeId: audioNotice),
  );
  screenLayoutTest(
    'Pinned notice without audio',
    () => const NoticeScreen(noticeId: pinnedNotice),
  );
}
