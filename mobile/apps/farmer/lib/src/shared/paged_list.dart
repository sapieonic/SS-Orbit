import 'package:flutter/foundation.dart';
import 'package:orbit_core/orbit_core.dart';

/// Items loaded so far from a cursor-paged endpoint, plus the state of the
/// "load the next page" request.
///
/// Used by My visits and the crop advisory inbox; the list's last row is
/// orbit_ui's `LoadMoreFooter`.
@immutable
class PagedList<T> {
  /// Creates a paged list.
  const PagedList({
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// The first page.
  factory PagedList.firstPage(CursorPage<T> page) =>
      PagedList(items: page.items, nextCursor: page.nextCursor);

  /// Everything loaded so far, in server order.
  final List<T> items;

  /// Cursor of the next page; null when everything is loaded.
  final String? nextCursor;

  /// True while the next page is loading.
  final bool loadingMore;

  /// Why the last "next page" request failed, if it did.
  final Object? loadMoreError;

  /// True when another page can be fetched.
  bool get hasMore => nextCursor != null;

  /// True when the next page can be requested now.
  bool get canLoadMore => hasMore && !loadingMore;

  /// This list while the next page loads.
  PagedList<T> loading() =>
      PagedList(items: items, nextCursor: nextCursor, loadingMore: true);

  /// This list after the next page failed with [error].
  PagedList<T> failed(Object error) =>
      PagedList(items: items, nextCursor: nextCursor, loadMoreError: error);

  /// This list with [page] appended. Items whose [idOf] is already loaded
  /// are skipped, so a page that shifted under new data never shows twice.
  PagedList<T> append(CursorPage<T> page, String Function(T item) idOf) {
    final seen = {for (final item in items) idOf(item)};
    return PagedList(
      items: List.unmodifiable([
        ...items,
        ...page.items.where((item) => seen.add(idOf(item))),
      ]),
      nextCursor: page.nextCursor,
    );
  }

  /// This list with every item replaced by [update] (e.g. mark one read).
  PagedList<T> map(T Function(T item) update) => PagedList(
    items: List.unmodifiable(items.map(update)),
    nextCursor: nextCursor,
    loadingMore: loadingMore,
    loadMoreError: loadMoreError,
  );
}
