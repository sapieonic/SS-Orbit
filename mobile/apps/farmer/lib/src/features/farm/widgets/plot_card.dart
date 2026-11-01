import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';
import '../../../shared/farmer_text.dart';
import '../farm_format.dart';

/// One plot on My farm: name and crop, area in acres and guntas, and the
/// active season (season, sowing date, days after sowing, or "Not sown yet"
/// before a sowing date still ahead) or "No crop yet",
/// with the one action that fits: start a season or close it.
class PlotCard extends StatelessWidget {
  /// Creates a plot card.
  const PlotCard({
    super.key,
    required this.plot,
    required this.crop,
    required this.language,
    required this.onStartSeason,
    required this.onCloseSeason,
  });

  /// The plot with its active season.
  final HomePlot plot;

  /// The active season's crop, when the crop list is loaded.
  final FarmerCrop? crop;

  /// The app language.
  final Language language;

  /// Opens Start season for this plot.
  final VoidCallback onStartSeason;

  /// Opens Close season for the active season.
  final VoidCallback onCloseSeason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final season = plot.activeSeason;
    final name = plotName(l10n, plot.plot);
    final cropText = crop == null ? null : cropName(crop!, language);
    final sown = season?.sowingDate;
    final days = plot.daysAfterSowing;
    // A negative day count: the sowing date is still ahead.
    final sowsLater = days != null && days < 0;
    final seasonLine = season == null
        ? null
        : [
            seasonLabel(l10n, season.seasonCode),
            if (sown != null)
              sowsLater
                  ? l10n.farmerFarmSowsOn(date: sown.toDateTime())
                  : l10n.farmerFarmSownOn(date: sown.toDateTime()),
            if (!sowsLater && days != null) l10n.farmerCalendarDay(day: days),
          ].reduce((a, b) => l10n.commonDotJoin(first: a, second: b));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  season == null ? OrbitIcons.location : OrbitIcons.crop,
                  size: OrbitSize.iconXl,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: OrbitSpace.s12),
                Expanded(
                  child: BilingualText(
                    cropText == null
                        ? name
                        : l10n.commonDotJoin(first: name, second: cropText),
                    secondary: plotArea(l10n, plot.plot.areaAcres),
                    primaryStyle: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: OrbitSpace.s12),
            if (season == null)
              Text(
                l10n.farmerFarmNoCrop,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              StatusPill(
                label: l10n.labelSeasonStatus(season.status.wire),
                tone: OrbitStatusTone.success,
                icon: OrbitIcons.crop,
              ),
              const SizedBox(height: OrbitSpace.s8),
              Text(seasonLine!, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: OrbitSpace.s12),
            if (season == null)
              OrbitButton(
                label: l10n.farmerFarmStartSeason,
                icon: OrbitIcons.crop,
                variant: OrbitButtonVariant.secondary,
                onPressed: onStartSeason,
              )
            else
              OrbitButton(
                label: l10n.farmerFarmCloseSeason,
                icon: OrbitIcons.check,
                variant: OrbitButtonVariant.secondary,
                size: OrbitButtonSize.medium,
                onPressed: onCloseSeason,
              ),
          ],
        ),
      ),
    );
  }
}
