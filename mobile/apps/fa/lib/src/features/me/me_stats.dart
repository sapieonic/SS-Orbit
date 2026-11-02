import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';

import '../../data/data.dart';
import '../../local/local.dart';

/// The counts on Me's "This month" row, from the territory on the phone
/// ([Territory.doneVisitsInMonth] says what "visits" can miss).
@immutable
final class MeStats {
  /// Creates the counts.
  const MeStats({
    required this.farmers,
    required this.visits,
    required this.enrolled,
  });

  /// Counts [territory] for the IST month of [today].
  factory MeStats.of(Territory territory, LocalDate today) => MeStats(
    farmers: territory.farmerCount,
    visits: territory.doneVisitsInMonth(today),
    enrolled: territory.enrolledInMonth(today),
  );

  /// Farmers on the phone.
  final int farmers;

  /// Visits done this month.
  final int visits;

  /// Farmers enrolled this month.
  final int enrolled;
}

/// [MeStats] for today, or null while the territory loads.
final meStatsProvider = Provider<MeStats?>((ref) {
  final territory = ref.watch(territoryProvider).value;
  if (territory == null) return null;
  return MeStats.of(territory, territory.today);
});

/// A short ID of this phone for HO ("7F3A"): the last four letters or
/// digits of the install ID, upper case.
String shortPhoneId(String deviceKey) {
  final chars = deviceKey.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  final tail = chars.length <= 4 ? chars : chars.substring(chars.length - 4);
  return tail.toUpperCase();
}

/// [shortPhoneId] of this phone's install ID.
final phoneIdProvider = FutureProvider<String>((ref) async {
  final key = await ref.watch(sessionStoreProvider).deviceKey();
  return shortPhoneId(key);
});
