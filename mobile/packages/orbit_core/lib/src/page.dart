import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// One page of a cursor-paged list: the API's `{items, next_cursor}`.
///
/// Named `CursorPage` rather than `Page` so it never clashes with Flutter's
/// navigator `Page` (widgets, go_router).
///
/// Ask for the next page with `cursor: page.nextCursor` until it is null.
/// Cursors are opaque; never build or parse one.
@immutable
final class CursorPage<T> {
  /// Creates a page.
  const CursorPage({required this.items, this.nextCursor});

  /// An empty last page.
  const CursorPage.empty() : items = const [], nextCursor = null;

  /// Items on this page, in server order.
  final List<T> items;

  /// Cursor for the next page, or null when this is the last page.
  final String? nextCursor;

  /// True when another page can be fetched.
  bool get hasMore => nextCursor != null;

  /// A page with the items mapped by [convert] and the same cursor.
  CursorPage<R> map<R>(R Function(T item) convert) =>
      CursorPage(items: items.map(convert).toList(), nextCursor: nextCursor);

  @override
  bool operator ==(Object other) =>
      other is CursorPage<T> &&
      other.nextCursor == nextCursor &&
      const ListEquality<Object?>().equals(other.items, items);

  @override
  int get hashCode =>
      Object.hash(nextCursor, const ListEquality<Object?>().hash(items));

  @override
  String toString() =>
      'CursorPage(${items.length} items, nextCursor: $nextCursor)';
}
