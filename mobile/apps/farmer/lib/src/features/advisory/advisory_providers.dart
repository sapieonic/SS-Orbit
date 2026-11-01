import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_voice/orbit_voice.dart';

import '../../data/data.dart';
import '../../shared/farmer_data.dart';
import '../../shared/paged_list.dart';
import '../../shared/voice.dart';

/// The API's largest `limit` for `GET /v1/farmer/notices`.
const maxNoticesPageSize = 100;

/// Pages fetched at most when looking for one notice that is not loaded yet.
const _maxLookupPages = 20;

/// Notices per page in the inbox (1-100). Tests override it to page sooner.
final noticesPageSizeProvider = Provider<int>((ref) => 30);

/// The first page of the inbox as it is shown: pinned first, then newest
/// first.
///
/// The server sends the inbox newest first and nothing else
/// (`GET /v1/farmer/notices`), so only the first page is reordered. Later
/// pages are added below in server order, a pinned notice among them shown
/// where it falls (with its Pinned tag): loading more never moves a notice
/// the farmer already sees.
List<Notice> inboxOrder(Iterable<Notice> notices) {
  final sorted = [...notices];
  mergeSort(
    sorted,
    compare: (a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    },
  );
  return sorted;
}

/// Loads the crop advisory inbox (F5) page by page, in the order the inbox
/// shows it ([inboxOrder]), and keeps read and listened marks in step with
/// the server without reloading every page.
class NoticesController extends AsyncNotifier<PagedList<Notice>> {
  /// Bumped on every (re)build; a page that arrives for an older build is
  /// dropped.
  int _generation = 0;

  @override
  Future<PagedList<Notice>> build() {
    _generation++;
    // Another farmer signing in on this phone must never see these notices.
    return loadFarmerData(ref, 'notices', () async {
      final pageSize = ref.watch(noticesPageSizeProvider);
      assert(pageSize >= 1 && pageSize <= maxNoticesPageSize, 'limit 1-100');
      final page = await ref
          .watch(noticesRepositoryProvider)
          .listNotices(limit: pageSize);
      return PagedList(
        items: List.unmodifiable(inboxOrder(page.items)),
        nextCursor: page.nextCursor,
      );
    });
  }

  /// Loads the next page. Does nothing while loading, refreshing or when
  /// everything is loaded. A failure shows on the list footer.
  Future<void> loadMore() async {
    final current = state;
    final loaded = current.value;
    if (current.isLoading || loaded == null || !loaded.canLoadMore) return;
    final generation = _generation;
    state = AsyncData(loaded.loading());
    try {
      final page = await ref
          .read(noticesRepositoryProvider)
          .listNotices(
            limit: ref.read(noticesPageSizeProvider),
            cursor: loaded.nextCursor,
          );
      _apply(generation, (list) => list.append(page, (n) => n.id));
    } on Object catch (error) {
      _apply(generation, (list) => list.failed(error));
    }
  }

  /// `POST .../{noticeId}/read` (the farmer opened it), then updates the
  /// card and the unread badge. Throws `ApiError` when it could not be sent.
  Future<void> markRead(String noticeId) async {
    final scope = ref.read(farmerDataScopeProvider);
    await ref.read(noticesRepositoryProvider).markRead(noticeId);
    _afterMark(
      scope,
      noticeId,
      (n, now) => n.copyWith(readAt: n.readAt ?? now),
    );
  }

  /// `POST .../{noticeId}/listened` (the voice note played to the end; also
  /// marks it read), then updates the card and the unread badge. Throws
  /// `ApiError` when it could not be sent.
  Future<void> markListened(String noticeId) async {
    final scope = ref.read(farmerDataScopeProvider);
    await ref.read(noticesRepositoryProvider).markListened(noticeId);
    _afterMark(
      scope,
      noticeId,
      (n, now) =>
          n.copyWith(readAt: n.readAt ?? now, listenedAt: n.listenedAt ?? now),
    );
  }

  /// Fetches [noticeId] again from the server (there is no single-notice
  /// endpoint: pages from the newest until it is found) and puts it in the
  /// loaded list, e.g. for a fresh presigned `audio_url`. Returns it, or
  /// null when the farmer has no such notice. Throws `ApiError`.
  Future<Notice?> refetchNotice(String noticeId) async {
    final generation = _generation;
    final fresh = await _searchPages(
      ref.read(noticesRepositoryProvider),
      noticeId,
      fromFirstPage: true,
    );
    if (fresh != null &&
        ref.mounted &&
        generation == _generation &&
        !state.isLoading) {
      final loaded = state.value;
      if (loaded != null) {
        state = AsyncData(loaded.map((n) => n.id == noticeId ? fresh : n));
      }
    }
    return fresh;
  }

  /// Applies a confirmed mark to the loaded card (no reload, so the pages
  /// already loaded stay) and refreshes the badge count from the server. A
  /// mark sent for a farmer who signed out meanwhile changes nothing.
  void _afterMark(
    FarmerDataScope scope,
    String noticeId,
    Notice Function(Notice, DateTime) mark,
  ) {
    if (!isCurrentScope(ref, scope)) return;
    final now = ref.read(clockProvider).now();
    final loaded = state.value;
    if (loaded != null && !state.isLoading) {
      state = AsyncData(loaded.map((n) => n.id == noticeId ? mark(n, now) : n));
    }
    ref.invalidate(unreadNoticesCountProvider);
  }

  void _apply(
    int generation,
    PagedList<Notice> Function(PagedList<Notice> list) update,
  ) {
    if (!ref.mounted || generation != _generation) return;
    final now = state.value;
    if (now == null) return;
    state = AsyncData(update(now));
  }
}

/// The crop advisory inbox (F5).
final noticesControllerProvider =
    AsyncNotifierProvider<NoticesController, PagedList<Notice>>(
      NoticesController.new,
    );

/// One notice by ID, for the notice screen.
///
/// Uses the notices the inbox already loaded; when it is not among them (a
/// deep link, an old notice), fetches further pages until it is found. Null
/// when the farmer has no such notice. Refreshes with the inbox (a mark, a
/// reload), keeping the notice on screen meanwhile.
final noticeByIdProvider = FutureProvider.autoDispose.family<Notice?, String>(
  (ref, noticeId) => loadFarmerData(ref, 'notice/$noticeId', () async {
    final repo = ref.watch(noticesRepositoryProvider);
    final loaded = await followFarmerData(
      ref,
      noticesControllerProvider.future,
    );
    final hit = _findNotice(loaded.items, noticeId);
    if (hit != null) return hit;
    return _searchPages(repo, noticeId, cursor: loaded.nextCursor);
  }),
);

/// Looks for [noticeId] page by page: from [cursor], or from the newest
/// page when [fromFirstPage]. Null when it is not there (or not within
/// [_maxLookupPages]).
Future<Notice?> _searchPages(
  NoticesRepository repo,
  String noticeId, {
  String? cursor,
  bool fromFirstPage = false,
}) async {
  if (cursor == null && !fromFirstPage) return null;
  var next = cursor;
  for (var i = 0; i < _maxLookupPages; i++) {
    final page = await repo.listNotices(
      limit: maxNoticesPageSize,
      cursor: next,
    );
    final found = _findNotice(page.items, noticeId);
    if (found != null) return found;
    next = page.nextCursor;
    if (next == null) return null;
  }
  return null;
}

Notice? _findNotice(List<Notice> notices, String id) {
  for (final n in notices) {
    if (n.id == id) return n;
  }
  return null;
}

/// Plays notice voice notes and marks a notice listened (FAR-03) when its
/// voice note plays to the very end.
///
/// `audio_url` is a short-lived presigned URL and the inbox is kept for the
/// whole session, so a download refused as expired ([looksExpired]) fetches
/// the notice again and retries once with its fresh URL.
///
/// Lives for the whole app session once used, so a note that finishes after
/// the farmer scrolled away still counts.
class NoticeAudio {
  NoticeAudio._(this._player, this._markListened, this._refetch);

  final VoicePlayer _player;
  final Future<void> Function(String noticeId) _markListened;
  final Future<Notice?> Function(String noticeId) _refetch;

  /// Notices whose voice note this session started; a completion for any
  /// other key (a screen's voice prompt) is ignored.
  final Set<String> _started = {};

  /// Notices played by the farmer whose expired-URL retry is not used yet.
  final Set<String> _canRetry = {};

  /// True when a voice-note failure looks like an expired presigned URL:
  /// the storage refused the download (S3 / MinIO answer 403, some stores
  /// 400 or 401). Network failures and broken files are not retried.
  static bool looksExpired(Object error) =>
      error is NoticeAudioException &&
      const {400, 401, 403}.contains(error.statusCode);

  /// The voice-note URL of [notice], or null when it has none or it is not
  /// a valid URL.
  static Uri? audioUri(Notice notice) {
    final url = notice.audioUrl;
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    return uri == null || !uri.hasScheme ? null : uri;
  }

  /// Plays the voice note of [notice]; does nothing when it has none. Never
  /// throws: a failed download or playback shows on the player state.
  Future<void> play(Notice notice) async {
    final uri = audioUri(notice);
    if (uri == null) return;
    _started.add(notice.id);
    _canRetry.add(notice.id);
    await _player.playUrl(uri, cacheKey: notice.id);
  }

  Future<void> _onState(VoicePlayerState state) async {
    if (state is! VoiceError || !looksExpired(state.error)) return;
    final noticeId = state.key;
    if (!_canRetry.remove(noticeId)) return;
    Uri? fresh;
    try {
      final notice = await _refetch(noticeId);
      fresh = notice == null ? null : audioUri(notice);
    } on Object catch (error) {
      debugPrint('refetch notice $noticeId failed: $error');
    }
    // Retry only while the failure is still what the player shows (the
    // farmer did not start something else meanwhile).
    final now = _player.state.value;
    if (fresh == null || now is! VoiceError || now.key != noticeId) return;
    await _player.playUrl(fresh, cacheKey: noticeId);
  }

  /// Stops playback.
  Future<void> stop() => _player.stop();

  Future<void> _onCompleted(String key) async {
    if (!_started.remove(key)) return;
    try {
      await _markListened(key);
    } on Object catch (error) {
      // No outbox yet: the mark is lost while offline and the notice stays
      // "not listened" until the farmer plays it again online.
      debugPrint('markListened($key) failed: $error');
    }
  }
}

/// The app's [NoticeAudio].
final noticeAudioProvider = Provider<NoticeAudio>((ref) {
  final player = ref.watch(voicePlayerProvider);
  final audio = NoticeAudio._(
    player,
    (id) => ref.read(noticesControllerProvider.notifier).markListened(id),
    (id) => ref.read(noticesControllerProvider.notifier).refetchNotice(id),
  );
  final subscription = player.completed.listen(
    (key) => unawaited(audio._onCompleted(key)),
  );
  void onState() => unawaited(audio._onState(player.state.value));
  player.state.addListener(onState);
  ref
    ..onDispose(subscription.cancel)
    ..onDispose(() => player.state.removeListener(onState));
  return audio;
});
