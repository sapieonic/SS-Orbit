import 'package:fa/src/shared/formatters.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

void main() {
  final en = lookupOrbitLocalizations(const Locale('en'));
  final te = lookupOrbitLocalizations(const Locale('te'));

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('te');
  });

  test('initials from the English name', () {
    expect(nameInitials('Suresh Kumar'), 'SK');
    expect(nameInitials(' raju  p '), 'RP');
    expect(nameInitials('Padma'), 'P');
    expect(nameInitials(''), isNull);
    expect(nameInitials(null), isNull);
  });

  test('distances: metres under 1 km, one decimal under 10 km', () {
    expect(formatDistance(en, 346), '350 m');
    expect(formatDistance(en, 996), '1.0 km');
    expect(formatDistance(en, 1200), '1.2 km');
    expect(formatDistance(en, 820), '820 m');
    expect(formatDistance(en, 14321), '14 km');
    expect(formatDistance(te, 2400), '2.4 కి.మీ.');
  });

  test('areas in acres and guntas, 40 guntas to the acre', () {
    expect(formatArea(en, 2.1), '2 ac 4 gunta');
    expect(formatArea(en, 2), '2 ac 0 gunta');
    expect(formatArea(en, 1.75), '1 ac 30 gunta');
    expect(formatArea(te, 0.01), '0 ఎ. 1 గుం.');
  });

  test('days ago on the IST calendar', () {
    final today = LocalDate(2026, 11, 2);
    expect(formatDaysAgo(en, today, today: today), en.commonToday);
    expect(
      formatDaysAgo(en, LocalDate(2026, 11, 1), today: today),
      'Yesterday',
    );
    expect(
      formatDaysAgo(en, LocalDate(2026, 10, 21), today: today),
      '12 days ago',
    );
    expect(
      formatDaysAgo(te, LocalDate(2026, 10, 21), today: today),
      te.commonDaysAgo(count: 12),
    );
    // A day ahead reads as its date.
    expect(
      formatDaysAgo(en, LocalDate(2026, 11, 5), today: today),
      formatDateShort(en, LocalDate(2026, 11, 5)),
    );
  });

  test('time ago: minutes, hours, then IST days', () {
    final now = DateTime.utc(2026, 11, 2, 5); // 10:30 IST
    expect(
      formatTimeAgo(en, now.subtract(const Duration(seconds: 10)), now: now),
      en.commonMinutesAgo(count: 1),
    );
    expect(
      formatTimeAgo(en, now.subtract(const Duration(minutes: 42)), now: now),
      en.commonMinutesAgo(count: 42),
    );
    expect(
      formatTimeAgo(en, now.subtract(const Duration(hours: 3)), now: now),
      en.commonHoursAgo(count: 3),
    );
    // 34 h earlier is 00:30 IST yesterday; 40 h is the day before.
    expect(
      formatTimeAgo(en, now.subtract(const Duration(hours: 34)), now: now),
      en.commonYesterday,
    );
    expect(
      formatTimeAgo(en, now.subtract(const Duration(hours: 40)), now: now),
      en.commonDaysAgo(count: 2),
    );
  });

  test('times and dates are IST, in the UI language', () {
    // 05:35 UTC is 11:05 IST.
    // (intl puts a narrow no-break space before AM.)
    expect(formatTime(en, DateTime.utc(2026, 10, 27, 5, 35)), '11:05\u202fAM');
    final date = LocalDate(2026, 10, 29);
    expect(formatDateShort(en, date), 'Oct 29');
    expect(formatWeekdayShort(en, date), 'Thu');
    expect(formatWeekdayShort(te, date), isNot('Thu'));
    expect(formatDayOfMonth(en, date), '29');
  });

  test('dot join skips empty parts', () {
    expect(dotJoin(en, ['1.2 km', null, ' ', 'Chilli']), '1.2 km · Chilli');
    expect(dotJoin(en, [null]), '');
  });
}
