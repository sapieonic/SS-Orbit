import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/advisory/advisory_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_voice/orbit_voice.dart';

import '../../support/harness.dart';

/// The notices repository, but every `listNotices` signs the audio URLs
/// again (`?sig=N`), like presigned URLs from the real API.
final class ResigningNotices implements NoticesRepository {
  ResigningNotices(this._inner);

  final NoticesRepository _inner;

  /// `listNotices` calls so far.
  int lists = 0;

  @override
  Future<CursorPage<Notice>> listNotices({int? limit, String? cursor}) async {
    final page = await _inner.listNotices(limit: limit, cursor: cursor);
    final sig = ++lists;
    return CursorPage(
      items: [for (final n in page.items) _signed(n, sig)],
      nextCursor: page.nextCursor,
    );
  }

  static Notice _signed(Notice n, int sig) => n.audioUrl == null
      ? n
      : Notice(
          id: n.id,
          kind: n.kind,
          sender: n.sender,
          titleTe: n.titleTe,
          bodyTe: n.bodyTe,
          titleEn: n.titleEn,
          bodyEn: n.bodyEn,
          audioUrl: '${n.audioUrl}?sig=$sig',
          refType: n.refType,
          refId: n.refId,
          pinned: n.pinned,
          readAt: n.readAt,
          listenedAt: n.listenedAt,
          createdAt: n.createdAt,
        );

  @override
  Future<int> getUnreadCount() => _inner.getUnreadCount();

  @override
  Future<void> markListened(String noticeId) => _inner.markListened(noticeId);

  @override
  Future<void> markRead(String noticeId) => _inner.markRead(noticeId);
}

void main() {
  late FakeVoicePlayer voice;
  late ResigningNotices notices;
  late ProviderContainer container;
  late Notice notice;

  setUp(() async {
    voice = FakeVoicePlayer();
    container = await createTestContainer(
      voice: voice,
      overrides: [
        noticesRepositoryProvider.overrideWith((ref) {
          return notices = ResigningNotices(
            ref.watch(farmerRepositoriesProvider).notices,
          );
        }),
      ],
    );
    final inbox = await container.read(noticesControllerProvider.future);
    notice = inbox.items.firstWhere((n) => n.audioUrl != null);
  });

  tearDown(() => voice.dispose());

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  String? sigOf(Uri url) => url.queryParameters['sig'];

  test('an expired audio URL is fetched again and retried once', () async {
    final audio = container.read(noticeAudioProvider);
    await audio.play(notice);
    expect(sigOf(voice.urlsPlayed.single.$1), '1');

    const expired = NoticeAudioException('download failed', statusCode: 403);
    voice.fail(notice.id, expired);
    await settle();

    expect(voice.urlsPlayed, hasLength(2));
    expect(voice.urlsPlayed.last.$2, notice.id, reason: 'same cache key');
    expect(sigOf(voice.urlsPlayed.last.$1), '2', reason: 'the fresh URL');
    final loaded = container.read(noticesControllerProvider).value!;
    expect(
      loaded.items.firstWhere((n) => n.id == notice.id).audioUrl,
      endsWith('sig=2'),
      reason: 'the inbox keeps the fresh URL',
    );

    // Still refused: no loop, the farmer sees "Couldn't play the audio".
    voice.fail(notice.id, expired);
    await settle();
    expect(voice.urlsPlayed, hasLength(2));
    expect(voice.state.value, isA<VoiceError>());

    // Tapping Listen again is a new try, with its own retry.
    await audio.play(loaded.items.firstWhere((n) => n.id == notice.id));
    voice.fail(notice.id, expired);
    await settle();
    expect(voice.urlsPlayed, hasLength(4));
  });

  test('a network or playback failure is not retried', () async {
    final audio = container.read(noticeAudioProvider);
    await audio.play(notice);
    final listed = notices.lists;

    voice.fail(notice.id, const NoticeAudioException('download failed: dns'));
    await settle();
    voice.fail(notice.id);
    await settle();

    expect(voice.urlsPlayed, hasLength(1));
    expect(notices.lists, listed, reason: 'nothing refetched');
  });

  test('no retry when the farmer started something else', () async {
    final audio = container.read(noticeAudioProvider);
    await audio.play(notice);
    voice.fail(
      notice.id,
      const NoticeAudioException('download failed', statusCode: 403),
    );
    await voice.playPrompt('farmer.home.voice_help');
    await settle();

    expect(voice.urlsPlayed, hasLength(1));
  });
}
