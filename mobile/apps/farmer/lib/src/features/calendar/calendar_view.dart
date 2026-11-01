import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/farmer_text.dart';
import 'calendar_model.dart';

/// The calendar for one plot: plot chips (when there are several), the
/// summary card, the stage strip and the "tasks come later" note.
class CalendarView extends StatelessWidget {
  /// Creates the view.
  const CalendarView({
    super.key,
    required this.calendar,
    required this.seasonPlots,
    required this.crops,
    required this.onPlotSelected,
  });

  /// The selected plot's calendar.
  final CalendarPlot calendar;

  /// Plots with an active season: the chips.
  final List<HomePlot> seasonPlots;

  /// The crop list, for the chips' crop names.
  final FarmerCropList crops;

  /// A chip was tapped (plot ID).
  final ValueChanged<String> onPlotSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = contentLanguage(context);
    final crop = calendar.crop;
    final current = calendar.currentIndex;
    const gap = SizedBox(height: OrbitSpace.s16);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        0,
        OrbitSpace.s16,
        OrbitSpace.s24,
      ),
      children: [
        if (seasonPlots.length > 1) ...[
          _PlotChips(
            plots: seasonPlots,
            crops: crops,
            selectedId: calendar.plot.plot.id,
            onSelected: onPlotSelected,
          ),
          gap,
        ],
        _SummaryCard(calendar: calendar),
        if (crop != null && current != null) ...[
          gap,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(OrbitSpace.s16),
              child: StageStrip(
                stages: [
                  for (final s in crop.stages)
                    pickText(language, te: s.nameTe, en: s.name),
                ],
                currentIndex: current,
                axis: Axis.vertical,
                currentLabel: l10n.farmerCalendarNow,
                doneLabel: l10n.commonDone,
              ),
            ),
          ),
        ],
        gap,
        SectionHeader(title: l10n.farmerCalendarTasks),
        const SizedBox(height: OrbitSpace.s8),
        InfoRow(icon: OrbitIcons.tasks, text: l10n.farmerCalendarTasksLater),
      ],
    );
  }
}

/// Crop name, sowing date, "day 123 of about 160" with a bar, and the stage
/// today. Without a sowing date: "Add the sowing date to see the calendar";
/// with one still ahead: that date and "Not sown yet".
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.calendar});

  final CalendarPlot calendar;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = contentLanguage(context);
    final crop = calendar.crop;
    final sown = calendar.season.sowingDate;
    final days = calendar.daysAfterSowing;
    final duration = crop?.durationDays;
    final stage = calendar.currentStage;
    final progress = calendar.progress;
    final dayLine = days == null
        ? null
        : duration == null
        ? l10n.farmerCalendarDay(day: days)
        : l10n.farmerCalendarDayOf(day: days, total: duration);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  OrbitIcons.crop,
                  size: OrbitSize.iconXl,
                  color: scheme.primary,
                ),
                const SizedBox(width: OrbitSpace.s12),
                Expanded(
                  child: BilingualText(
                    crop == null
                        ? l10n.commonUnknown
                        : pickText(language, te: crop.nameTe, en: crop.name),
                    secondary: switch (sown) {
                      // A date still ahead: "sowing 12 Jun", not "sown on".
                      final date? when calendar.sowsLater =>
                        l10n.farmerFarmSowsOn(date: date.toDateTime()),
                      final date? => l10n.farmerFarmSownOn(
                        date: date.toDateTime(),
                      ),
                      null => null,
                    },
                    primaryStyle: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: OrbitSpace.s12),
            if (dayLine == null)
              InfoRow(
                icon: OrbitIcons.info,
                text: calendar.sowsLater
                    ? l10n.farmerSeasonStartNotSown
                    : l10n.farmerCalendarNoSowingDate,
              )
            else ...[
              Text(dayLine, style: theme.textTheme.titleMedium),
              if (progress != null) ...[
                const SizedBox(height: OrbitSpace.s8),
                ClipRRect(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(OrbitRadius.pill),
                  ),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: OrbitSpace.s8,
                    semanticsLabel: dayLine,
                  ),
                ),
              ],
              if (stage != null) ...[
                const SizedBox(height: OrbitSpace.s8),
                Text(
                  dotJoin(l10n, [
                    l10n.farmerCalendarNow,
                    pickText(language, te: stage.nameTe, en: stage.name),
                  ]),
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// One chip per plot in season: "పొలం 1 · పత్తి".
class _PlotChips extends StatelessWidget {
  const _PlotChips({
    required this.plots,
    required this.crops,
    required this.selectedId,
    required this.onSelected,
  });

  final List<HomePlot> plots;
  final FarmerCropList crops;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = contentLanguage(context);
    return Wrap(
      spacing: OrbitSpace.s8,
      runSpacing: OrbitSpace.s8,
      children: [
        for (final p in plots)
          ChoiceChip(
            label: Text(plotAndCrop(l10n, p, crops, language)),
            selected: p.plot.id == selectedId,
            onSelected: (_) => onSelected(p.plot.id),
          ),
      ],
    );
  }
}
