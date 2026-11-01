/// Source of "now", so code that depends on time can be tested.
///
/// Always returns UTC. Convert to the IST calendar with
/// `LocalDate.todayIst(clock)` or `toIstWallClock`.
abstract interface class Clock {
  /// The current instant, in UTC.
  DateTime now();
}

/// The device clock.
final class SystemClock implements Clock {
  /// Creates the device clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// A clock that only moves when told to. For tests and mock data.
final class FixedClock implements Clock {
  /// Starts at [start] (converted to UTC).
  FixedClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Moves the clock forward by [by].
  void advance(Duration by) => _now = _now.add(by);

  /// Jumps to [instant].
  void set(DateTime instant) => _now = instant.toUtc();
}
