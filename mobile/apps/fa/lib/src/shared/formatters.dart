/// How the FA app writes numbers, areas, distances, dates and times, so the
/// same value reads the same on every screen, in the UI language.
///
/// Times from the server are UTC; everything shown is IST (`toIstWallClock`,
/// `LocalDate.istOf`), whatever the phone's time zone. Phone numbers: use
/// orbit_core's `formatIndianMobile` ("98480 12345") to show one and
/// [nationalMobile] to fill a phone field.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../data/models/common.dart';
import '../data/models/snapshot.dart';

/// The language to pick server text in (`name_te` or `name`): the one the
/// screen is shown in, so names never mix with the UI language.
Language contentLanguage(BuildContext context) =>
    Language.fromWire(Localizations.localeOf(context).languageCode);

/// A farmer's name in [language] (Telugu when it is Telugu and set, else
/// English), or the phone number ("90000 00101") while a self sign-up has
/// no name yet. Empty for no farmer.
String farmerName(SnapFarmer? farmer, Language language) {
  if (farmer == null) return '';
  final name = farmer.displayName(language);
  return name.isEmpty ? formatIndianMobile(farmer.phone) : name;
}

/// The 10 national digits of an Indian mobile number (`+919000000101` ->
/// `9000000101`), the way the enrol form's phone field takes them; null when
/// [phone] is null or not a mobile number.
String? nationalMobile(String? phone) =>
    phone == null ? null : normalizeIndianMobile(phone)?.substring(3);

/// Joins the non-empty [parts] with " · " (`common.dot_join`), e.g.
/// "1.2 km · Chilli · joined today". Empty when every part is empty.
String dotJoin(OrbitLocalizations l10n, Iterable<String?> parts) {
  final present = [
    for (final p in parts)
      if (p != null && p.trim().isNotEmpty) p,
  ];
  if (present.isEmpty) return '';
  return present.reduce(
    (first, second) => l10n.commonDotJoin(first: first, second: second),
  );
}

/// Up to two capital letters for an avatar, from an English name
/// ("Suresh Kumar" -> "SK", "Raju P" -> "RP"). Null when [name] is empty.
/// Telugu names don't split cleanly into initials, so pass the English one.
String? nameInitials(String? name) {
  final words = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  if (words.isEmpty) return null;
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// A distance from the FA: "350 m" under 1 km (to the nearest 10 m), then
/// "1.2 km" (one decimal) and "14 km" from 10 km.
String formatDistance(OrbitLocalizations l10n, double meters) {
  if (meters < 1000) {
    final rounded = (meters / 10).round() * 10;
    if (rounded < 1000) return l10n.faCommonDistanceM(distance: rounded);
  }
  final km = meters / 1000;
  final format = NumberFormat(km < 10 ? '0.0' : '0', l10n.localeName);
  return l10n.faCommonDistanceKm(distance: format.format(km));
}

/// A plot area in acres as "2 ac 4 gunta" (40 guntas to the acre; any area
/// above zero is at least 1 gunta).
String formatArea(OrbitLocalizations l10n, double acres) {
  final area = AcresGuntas.fromAcres(acres);
  return l10n.faCommonArea(acres: area.acres, guntas: area.guntas);
}

/// A day relative to [today]: "Today", "Yesterday", "12 days ago". A day
/// after [today] is shown as its date ("29 Oct").
String formatDaysAgo(
  OrbitLocalizations l10n,
  LocalDate date, {
  required LocalDate today,
}) {
  final days = date.daysUntil(today);
  return switch (days) {
    0 => l10n.commonToday,
    1 => l10n.commonYesterday,
    < 0 => formatDateShort(l10n, date),
    _ => l10n.commonDaysAgo(count: days),
  };
}

/// How long ago [at] was, for "Saved 5 min ago" style lines: minutes within
/// the hour (at least 1), hours within the day, then IST calendar days as in
/// [formatDaysAgo].
String formatTimeAgo(
  OrbitLocalizations l10n,
  DateTime at, {
  required DateTime now,
}) {
  final elapsed = now.difference(at);
  if (elapsed.inMinutes < 60) {
    return l10n.commonMinutesAgo(count: elapsed.inMinutes.clamp(1, 59));
  }
  if (elapsed.inHours < 24) return l10n.commonHoursAgo(count: elapsed.inHours);
  return formatDaysAgo(l10n, LocalDate.istOf(at), today: LocalDate.istOf(now));
}

/// The IST time of day of [at] (UTC), e.g. "11:05 AM".
String formatTime(OrbitLocalizations l10n, DateTime at) =>
    l10n.faCommonTime(time: toIstWallClock(at));

/// A day and short month, e.g. "12 Oct" (`common.date_short`).
String formatDateShort(OrbitLocalizations l10n, LocalDate date) =>
    l10n.commonDateShort(date: date.toDateTime());

/// A date with its short weekday, e.g. "Thu, 29 Oct" (`common.date_weekday`).
String formatDateWeekday(OrbitLocalizations l10n, LocalDate date) =>
    l10n.commonDateWeekday(date: date.toDateTime());

/// A full date with the year, e.g. "12 Oct 2026" (`common.date_full`).
String formatDateFull(OrbitLocalizations l10n, LocalDate date) =>
    l10n.commonDateFull(date: date.toDateTime());

/// The short weekday of [date] in the UI language ("Mon", "సోమ"), for the
/// calendar's day strip.
String formatWeekdayShort(OrbitLocalizations l10n, LocalDate date) =>
    DateFormat.E(l10n.localeName).format(date.toDateTime());

/// The day of the month of [date] in the UI language's digits ("26").
String formatDayOfMonth(OrbitLocalizations l10n, LocalDate date) =>
    DateFormat.d(l10n.localeName).format(date.toDateTime());
