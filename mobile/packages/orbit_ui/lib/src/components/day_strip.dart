import 'package:flutter/material.dart';

import '../tokens/orbit_tokens.g.dart';

/// One day of a [DayStrip].
@immutable
class DayStripDay {
  /// Creates a day.
  const DayStripDay({
    required this.weekday,
    required this.day,
    required this.semanticLabel,
    this.dots = 0,
    this.isToday = false,
  });

  /// Short weekday, already localised ("Mon", "సోమ").
  final String weekday;

  /// Day of the month as shown ("26").
  final String day;

  /// What screen readers say for the day, already localised
  /// ("Tue 27 Oct, 3 visits").
  final String semanticLabel;

  /// How many things are on that day (visits); shown as up to
  /// [DayStrip.maxDots] dots under the date.
  final int dots;

  /// Marks today with a ring when it is not selected.
  final bool isToday;
}

/// A week as seven tappable days: weekday, date and a dot per visit, the
/// selected day filled with the primary colour (A3 Visit calendar).
///
/// Each day is at least 62 dp tall and [DayStrip.minDayWidth] wide (the gaps
/// shrink first; a strip too narrow for that scrolls sideways), grows with
/// the text scale, and reads as
/// a button in a group where one is selected, with its own
/// [DayStripDay.semanticLabel].
class DayStrip extends StatelessWidget {
  /// Creates the strip.
  const DayStrip({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
    this.semanticLabel,
  });

  /// The days, usually seven.
  final List<DayStripDay> days;

  /// Index of the selected day.
  final int selectedIndex;

  /// Called with the tapped day's index.
  final ValueChanged<int> onSelected;

  /// What the strip is, for screen readers ("Week of 26 October").
  final String? semanticLabel;

  /// Most dots drawn under a day; more visits still show this many.
  static const int maxDots = 4;

  /// The narrowest a day gets: a 48 dp touch target.
  static const double minDayWidth = 48;

  /// Space between two days when the width allows it.
  static const double maxGap = 3;

  @override
  Widget build(BuildContext context) {
    assert(days.isNotEmpty, 'need at least one day');
    final n = days.length;
    Widget day(int i) => _Day(
      day: days[i],
      selected: i == selectedIndex,
      onTap: () => onSelected(i),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final fits = !width.isFinite || width >= n * minDayWidth;
          if (fits) {
            // The gaps shrink first, so every day keeps 48 dp.
            final gap = n < 2 || !width.isFinite
                ? maxGap
                : ((width - n * minDayWidth) / (n - 1)).clamp(0.0, maxGap);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < n; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(child: day(i)),
                  ],
                ],
              ),
            );
          }
          // Too narrow for seven 48 dp days: scroll rather than shrink them.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < n; i++)
                    SizedBox(width: minDayWidth, child: day(i)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.day, required this.selected, required this.onTap});

  final DayStripDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final weekdayColor = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final dayColor = selected ? scheme.onPrimary : scheme.onSurface;
    final dotColor = selected ? scheme.onPrimary : scheme.primary;
    final dots = day.dots.clamp(0, DayStrip.maxDots);
    const radius = BorderRadius.all(Radius.circular(OrbitSpace.s12));

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: day.semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: day.isToday && !selected
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: OrbitSpace.s6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.weekday,
                    textAlign: TextAlign.center,
                    style: text.labelSmall!.copyWith(color: weekdayColor),
                  ),
                  Text(
                    day.day,
                    textAlign: TextAlign.center,
                    style: text.titleMedium!.copyWith(
                      color: dayColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: OrbitSpace.s2),
                  SizedBox(
                    height: 5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var d = 0; d < dots; d++) ...[
                          if (d > 0) const SizedBox(width: 2),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
