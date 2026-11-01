import 'package:meta/meta.dart';

import 'local_date.dart';

/// Crop season codes (`kharif-2026`, `rabi-2026-27`, `summer-2027`).
///
/// Mirrors `backend/internal/masters/seasons.go` (Telangana / AP calendar, by
/// IST date): summer 1 Apr - 31 May, kharif 1 Jun - 31 Oct, rabi 1 Nov -
/// 31 Mar (the code uses the November's year). The server is the source of
/// truth (`season_codes` in `GET /v1/farmer/crops`); use [seasonCodesOn] only
/// where the server value is not at hand (mock data, an old cache past its
/// `valid_until`).
abstract final class SeasonCode {
  /// The pattern the API enforces on `season_code`.
  static final pattern = RegExp(r'^[a-z]+-[0-9]{4}(-[0-9]{2})?$');

  /// True when [code] matches [pattern].
  static bool isValid(String code) => pattern.hasMatch(code);
}

/// Season codes to offer on [date] (an IST calendar day).
@immutable
final class SeasonCodeSet {
  /// Creates a set; prefer [seasonCodesOn].
  const SeasonCodeSet({
    required this.previous,
    required this.current,
    required this.next,
    required this.validUntil,
  });

  /// The season before [current] (a crop sown then may still be standing).
  final String previous;

  /// The season containing the date.
  final String current;

  /// The season after [current].
  final String next;

  /// Last IST day of [current].
  final LocalDate validUntil;

  /// Previous, current and next, oldest first (the API's `all_open`).
  List<String> get allOpen => [previous, current, next];

  @override
  bool operator ==(Object other) =>
      other is SeasonCodeSet &&
      other.previous == previous &&
      other.current == current &&
      other.next == next &&
      other.validUntil == validUntil;

  @override
  int get hashCode => Object.hash(previous, current, next, validUntil);

  @override
  String toString() => 'SeasonCodeSet($allOpen, until $validUntil)';
}

/// The season codes for the IST calendar day [date].
SeasonCodeSet seasonCodesOn(LocalDate date) {
  final cur = _Season.on(date);
  return SeasonCodeSet(
    previous: cur.prev.code,
    current: cur.code,
    next: cur.next.code,
    validUntil: cur.lastDay,
  );
}

enum _Kind { summer, kharif, rabi }

final class _Season {
  const _Season(this.kind, this.year);

  factory _Season.on(LocalDate d) => switch (d.month) {
    4 || 5 => _Season(_Kind.summer, d.year),
    >= 6 && <= 10 => _Season(_Kind.kharif, d.year),
    >= 11 => _Season(_Kind.rabi, d.year),
    _ => _Season(_Kind.rabi, d.year - 1),
  };

  final _Kind kind;
  final int year;

  String get code => kind == _Kind.rabi
      ? 'rabi-$year-${((year + 1) % 100).toString().padLeft(2, '0')}'
      : '${kind.name}-$year';

  LocalDate get lastDay => switch (kind) {
    _Kind.summer => LocalDate(year, 5, 31),
    _Kind.kharif => LocalDate(year, 10, 31),
    _Kind.rabi => LocalDate(year + 1, 3, 31),
  };

  _Season get next => switch (kind) {
    _Kind.summer => _Season(_Kind.kharif, year),
    _Kind.kharif => _Season(_Kind.rabi, year),
    _Kind.rabi => _Season(_Kind.summer, year + 1),
  };

  _Season get prev => switch (kind) {
    _Kind.summer => _Season(_Kind.rabi, year - 1),
    _Kind.kharif => _Season(_Kind.summer, year),
    _Kind.rabi => _Season(_Kind.kharif, year),
  };
}
