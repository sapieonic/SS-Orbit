import 'package:flutter/foundation.dart';

import '../../data/data.dart';

/// What the crop calendar (F11) shows for one plot's active season, worked
/// out from Home (`days_after_sowing`, `current_stage`) and the crop list
/// (stages, `duration_days`).
@immutable
class CalendarPlot {
  /// Builds the calendar for [plot] with [crops]; [plot] must have an active
  /// season.
  factory CalendarPlot.of(HomePlot plot, FarmerCropList crops) {
    final season = plot.activeSeason!;
    final crop = crops.byId(season.cropId);
    final sownIn = plot.daysAfterSowing;
    // Negative: the sowing date is still ahead; the crop has no days yet.
    final days = sownIn == null || sownIn < 0 ? null : sownIn;
    return CalendarPlot._(
      plot: plot,
      season: season,
      crop: crop,
      daysAfterSowing: days,
      sowsLater: sownIn != null && sownIn < 0,
      currentIndex: _currentIndex(crop, plot.currentStage, days),
      progress: _progress(crop?.durationDays, days),
    );
  }

  const CalendarPlot._({
    required this.plot,
    required this.season,
    required this.crop,
    required this.daysAfterSowing,
    required this.sowsLater,
    required this.currentIndex,
    required this.progress,
  });

  /// The plot.
  final HomePlot plot;

  /// Its active season.
  final Season season;

  /// The season's crop; null when the crop list doesn't have it (retired).
  final FarmerCrop? crop;

  /// Days since sowing; null without a sowing date, or before it.
  final int? daysAfterSowing;

  /// True when the sowing date is still ahead (the API's
  /// `days_after_sowing` is negative then): not sown yet.
  final bool sowsLater;

  /// Index into `crop.stages` of the stage today; null when unknown (no
  /// sowing date or no crop).
  final int? currentIndex;

  /// Share of the crop's duration gone, 0 to 1; null when the duration or
  /// the sowing date is unknown.
  final double? progress;

  /// The stage today, if known.
  Stage? get currentStage {
    final i = currentIndex;
    return i == null ? null : crop!.stages[i];
  }

  /// Home's `current_stage` wins (the server's word); otherwise the stage
  /// whose days contain [days]; past the last stage the crop stays in it
  /// (picking runs late).
  static int? _currentIndex(FarmerCrop? crop, Stage? current, int? days) {
    if (crop == null || crop.stages.isEmpty || days == null) return null;
    final stages = crop.stages;
    if (current != null) {
      final i = stages.indexWhere((s) => s.id == current.id);
      if (i >= 0) return i;
    }
    final i = stages.indexWhere((s) => s.contains(days));
    if (i >= 0) return i;
    return days > stages.last.endDay ? stages.length - 1 : null;
  }

  static double? _progress(int? durationDays, int? days) {
    if (durationDays == null || durationDays <= 0 || days == null) return null;
    return (days / durationDays).clamp(0, 1).toDouble();
  }
}

/// The plots that have an active season, in Home's order.
List<HomePlot> seasonPlots(FarmerHome home) =>
    home.plots.where((p) => p.activeSeason != null).toList();
