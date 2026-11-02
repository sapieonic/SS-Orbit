// What the Farmers list, the map and Farmer 360 say about a farmer: the meta
// line, where "Finish enrolment" goes, the point distances are measured
// from, and the GPS provider behind them.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../../data/data.dart';
import '../../device/device.dart';
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/formatters.dart';

/// The FA's GPS position for "nearest first", or null when there is no fix
/// (permission refused, location off, no fix in time). Screens then measure
/// from [territoryCentre].
final farmersGpsProvider = FutureProvider.autoDispose<LatLng?>((ref) async {
  try {
    final fix = await ref.watch(locationServiceProvider).currentFix();
    return fix.point;
  } on LocationUnavailable {
    return null;
  }
});

/// The middle of the FA's area: the average of the villages' points, else of
/// the farmers' points; null when nothing has a location.
LatLng? territoryCentre(Territory territory) {
  LatLng? average(Iterable<LatLng?> points) {
    var lat = 0.0;
    var lng = 0.0;
    var n = 0;
    for (final p in points) {
      if (p == null) continue;
      lat += p.lat;
      lng += p.lng;
      n++;
    }
    return n == 0 ? null : LatLng(lat / n, lng / n);
  }

  return average(territory.villages.map((v) => v.location)) ??
      average(territory.farmers.map((f) => territory.farmerLocation(f.id)));
}

/// Where "Finish enrolment" continues for [row], by what is missing: the
/// profile (a self sign-up) on enrol step 1 with the phone typed in, a plot
/// on step 2, a crop on step 3 (first plot without one). Consent alone is
/// recorded on Farmer 360. Null when nothing is missing.
String? finishEnrolmentRoute(FarmerRow row) {
  final gaps = row.enrolmentGaps;
  final id = row.farmer.id;
  if (gaps.contains(EnrolmentGap.profile)) {
    return AppRoutes.enrolFarmer(phone: nationalMobile(row.farmer.phone));
  }
  if (gaps.contains(EnrolmentGap.plot)) return AppRoutes.enrolPlot(id);
  if (gaps.contains(EnrolmentGap.season)) {
    final plot = row.plots.firstWhere((p) => p.season == null).plot;
    return AppRoutes.enrolCrop(id, plotId: plot.id);
  }
  if (gaps.isNotEmpty) return AppRoutes.farmer(id);
  return null;
}

/// Opens [location]: pushed when it is in the Farmers tab or a full-screen
/// page (back returns here), gone to when it is another tab's page (Enrol,
/// Plan a visit), which switches the tab.
void openFrom(BuildContext context, String location) {
  final path = Uri.parse(location).path;
  final otherTab =
      path.startsWith(AppRoutes.enrol) || path.startsWith(AppRoutes.calendar);
  if (otherTab) {
    context.go(location);
  } else {
    context.push(location);
  }
}

/// The crop name to show for [row]: the first plot with a crop.
String? cropName(FarmerRow row, Language language) {
  for (final p in row.plots) {
    if (p.crop case final crop?) return crop.displayName(language);
  }
  return null;
}

/// The card's meta line: distance · crop · where the farmer stands (joined,
/// last visit, visit due, days since the visit). [alert] is true for 30+ days
/// without a visit (shown in red).
({String text, bool alert}) farmerMeta(
  OrbitLocalizations l10n,
  FarmerRow row, {
  required LocalDate today,
  required Language language,
}) {
  final distance = row.distanceKm == null
      ? null
      : formatDistance(l10n, row.distanceKm! * 1000);
  final crop = cropName(row, language) ?? l10n.faFarmersMetaNoCrop;
  final (status, alert) = _status(l10n, row, today);
  return (text: dotJoin(l10n, [distance, crop, status]), alert: alert);
}

(String, bool) _status(
  OrbitLocalizations l10n,
  FarmerRow row,
  LocalDate today,
) {
  final joined = LocalDate.istOf(row.farmer.createdAt);
  final age = joined.daysUntil(today);
  final since = row.daysSinceLastVisit;
  if (row.isNew) {
    return (
      switch (age) {
        <= 0 => l10n.faFarmersMetaJoinedToday,
        1 => l10n.faFarmersMetaJoinedYesterday,
        _ => l10n.faFarmersMetaJoinedOn(date: formatDateShort(l10n, joined)),
      },
      false,
    );
  }
  if (row.isNotVisited30) {
    return (
      since == null
          ? l10n.faFarmersMetaNeverVisited(count: age)
          : l10n.faFarmersMetaDaysSinceVisit(count: since),
      true,
    );
  }
  final next = row.nextPlannedVisit?.plannedFor;
  if (next != null &&
      !next.isAfter(today.addDays(TerritoryRules.dueAheadDays))) {
    if (next.isBefore(today)) return (l10n.faFarmersMetaVisitOverdue, false);
    if (next == today) return (l10n.faFarmersMetaVisitDueToday, false);
    return (
      l10n.faFarmersMetaVisitDueOn(day: formatWeekdayShort(l10n, next)),
      false,
    );
  }
  if (since != null) {
    return (
      switch (since) {
        <= 0 => l10n.faFarmersMetaVisitedToday,
        1 => l10n.faFarmersMetaVisitedYesterday,
        _ => l10n.faFarmersMetaLastVisitDays(count: since),
      },
      false,
    );
  }
  return (
    l10n.faFarmersMetaJoinedOn(date: formatDateShort(l10n, joined)),
    false,
  );
}
