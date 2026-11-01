import 'dart:async';

import 'package:farmer/src/data/data.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:orbit_core/orbit_core.dart';

/// Swaps the notices repository for [spy], wrapping the mock's. Pass it in
/// `createTestContainer(overrides: ...)`.
Override spyOnNotices(NoticesSpy spy) => noticesRepositoryProvider.overrideWith(
  (ref) => spy..inner = ref.watch(farmerRepositoriesProvider).notices,
);

/// Records `markRead` calls and can fail them or hold back their answers,
/// hold back the pages after the first, or fail every page; everything else
/// goes to the mock.
class NoticesSpy implements NoticesRepository {
  /// The mock repository, set when the override is built.
  late NoticesRepository inner;

  /// Notice IDs `markRead` was called with, in order.
  final markedRead = <String>[];

  /// When set, `markRead` fails with it (after recording the call).
  Object? markReadError;

  /// When set, `markRead` reaches the server at once but its answer arrives
  /// only once this completes.
  Future<void>? holdMarkAnswers;

  /// When set, a page asked for with a cursor waits for it to complete.
  Completer<void>? laterPages;

  /// When set, every page fails with it.
  Object? listError;

  @override
  Future<CursorPage<Notice>> listNotices({int? limit, String? cursor}) async {
    if (listError case final error?) throw error;
    if (cursor != null) await laterPages?.future;
    return inner.listNotices(limit: limit, cursor: cursor);
  }

  @override
  Future<int> getUnreadCount() => inner.getUnreadCount();

  @override
  Future<void> markRead(String noticeId) async {
    markedRead.add(noticeId);
    if (markReadError case final error?) throw error;
    await inner.markRead(noticeId);
    await holdMarkAnswers;
  }

  @override
  Future<void> markListened(String noticeId) => inner.markListened(noticeId);
}
