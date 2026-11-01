import 'package:meta/meta.dart';

import 'clock.dart';

/// India Standard Time offset (UTC+05:30, no daylight saving).
const istOffset = Duration(hours: 5, minutes: 30);

/// The IST wall-clock time of [instant], for display and day arithmetic.
///
/// The result is a UTC-flagged [DateTime] whose fields read as IST (e.g. an
/// instant of 18:45Z gives 00:15 the next day). Use it only to show or bucket
/// times; never send it back to the API (send the original UTC instant).
DateTime toIstWallClock(DateTime instant) => instant.toUtc().add(istOffset);

/// A calendar date with no time or zone: the API's `format: date`
/// (`YYYY-MM-DD`, e.g. `planned_for`, `sowing_date`, `valid_until`).
///
/// Dates in the API are IST calendar days. Keep them as [LocalDate] end to
/// end; do not turn them into [DateTime] instants (midnight in which zone?).
/// Times (`format: date-time`) stay [DateTime] in UTC.
@immutable
final class LocalDate implements Comparable<LocalDate> {
  /// Creates a date. Out-of-range parts roll over like [DateTime]
  /// (`LocalDate(2026, 2, 30)` is 2 March); [parse] is strict instead.
  factory LocalDate(int year, int month, int day) {
    final d = DateTime.utc(year, month, day);
    return LocalDate._(d.year, d.month, d.day);
  }

  const LocalDate._(this.year, this.month, this.day);

  /// The calendar day part of [dateTime] as its fields read (no conversion).
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate._(dateTime.year, dateTime.month, dateTime.day);

  /// The IST calendar day of [instant].
  factory LocalDate.istOf(DateTime instant) =>
      LocalDate.fromDateTime(toIstWallClock(instant));

  /// Today in IST according to [clock].
  factory LocalDate.todayIst(Clock clock) => LocalDate.istOf(clock.now());

  /// Parses `YYYY-MM-DD` strictly. Throws [FormatException] otherwise
  /// (including impossible dates such as `2026-02-30`).
  factory LocalDate.parse(String text) {
    final m = _pattern.firstMatch(text);
    if (m == null) throw FormatException('Expected YYYY-MM-DD', text);
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    final date = LocalDate(y, mo, d);
    if (date.year != y || date.month != mo || date.day != d) {
      throw FormatException('Not a calendar date', text);
    }
    return date;
  }

  /// Like [parse] but returns null for null or invalid input.
  static LocalDate? tryParse(String? text) {
    if (text == null) return null;
    try {
      return LocalDate.parse(text);
    } on FormatException {
      return null;
    }
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Year, e.g. 2026.
  final int year;

  /// Month, 1-12.
  final int month;

  /// Day of month, 1-31.
  final int day;

  /// [DateTime.monday] (1) to [DateTime.sunday] (7).
  int get weekday => _utcMidnight.weekday;

  DateTime get _utcMidnight => DateTime.utc(year, month, day);

  /// This date plus [days] (may be negative).
  LocalDate addDays(int days) => LocalDate(year, month, day + days);

  /// Whole days from this date to [other] (negative if [other] is earlier).
  int daysUntil(LocalDate other) =>
      other._utcMidnight.difference(_utcMidnight).inDays;

  /// True if this date is before [other].
  bool isBefore(LocalDate other) => compareTo(other) < 0;

  /// True if this date is after [other].
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  /// The date at midnight UTC, for formatting with `intl` `DateFormat`
  /// (format it as-is, do not convert it to local time).
  DateTime toDateTime() => _utcMidnight;

  /// `YYYY-MM-DD`, the API wire format.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) => year != other.year
      ? year - other.year
      : month != other.month
      ? month - other.month
      : day - other.day;

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
