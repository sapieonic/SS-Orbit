import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';

/// Crop-calendar stages with the current one highlighted (F11), plus an
/// optional progress bar and line such as "day 137 of about 170".
///
/// Stages before [currentIndex] show a tick, the current one a filled
/// primary disc and bold label, later ones an empty ring, so the state is
/// never shown by colour alone. [currentLabel] and [doneLabel] are read by
/// screen readers (e.g. "now", "done").
class StageStrip extends StatelessWidget {
  /// Creates a stage strip.
  const StageStrip({
    super.key,
    required this.stages,
    required this.currentIndex,
    this.progress,
    this.progressLabel,
    this.currentLabel,
    this.doneLabel,
    this.axis = Axis.horizontal,
  }) : assert(
         progress == null || (progress >= 0 && progress <= 1),
         'progress must be 0..1',
       );

  /// Stage names in order, e.g. మొలక, కొమ్మ, మొగ్గ, పూత, కాయ, తీత.
  final List<String> stages;

  /// Index of the current stage.
  final int currentIndex;

  /// Season progress from 0 to 1; shows a bar when set.
  final double? progress;

  /// Progress line, already formatted, e.g. "day 137 of about 170".
  final String? progressLabel;

  /// Screen-reader word for the current stage.
  final String? currentLabel;

  /// Screen-reader word for finished stages.
  final String? doneLabel;

  /// Horizontal (default) or a vertical list.
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    assert(
      currentIndex >= 0 && currentIndex < stages.length,
      'currentIndex $currentIndex out of range for ${stages.length} stages',
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);

    Widget marker(int i) {
      const size = OrbitSize.iconLg;
      if (i < currentIndex) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: orbit.success.fg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            OrbitIcons.check,
            size: OrbitSize.iconSm,
            color: scheme.onPrimary,
          ),
        );
      }
      if (i == currentIndex) {
        return Container(
          width: size + OrbitSpace.s8,
          height: size + OrbitSpace.s8,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primaryContainer, width: 4),
          ),
        );
      }
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline, width: 2),
        ),
      );
    }

    Color lineColor(int afterIndex) =>
        afterIndex < currentIndex ? orbit.success.fg : scheme.outlineVariant;

    TextStyle labelStyle(int i) => i == currentIndex
        ? theme.textTheme.labelLarge!.copyWith(color: scheme.onPrimaryContainer)
        : theme.textTheme.labelMedium!.copyWith(
            color: i < currentIndex
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          );

    Widget stage(int i, Widget child) => Semantics(
      selected: i == currentIndex,
      value: i == currentIndex
          ? currentLabel
          : i < currentIndex
          ? doneLabel
          : null,
      child: child,
    );

    final Widget strip;
    if (axis == Axis.horizontal) {
      strip = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stages.length; i++)
            Expanded(
              child: stage(
                i,
                Column(
                  children: [
                    SizedBox(
                      height: OrbitSize.iconLg + OrbitSpace.s8,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 2,
                              color: i == 0
                                  ? Colors.transparent
                                  : lineColor(i - 1),
                            ),
                          ),
                          marker(i),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: i == stages.length - 1
                                  ? Colors.transparent
                                  : lineColor(i),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: OrbitSpace.s4),
                    Text(
                      stages[i],
                      textAlign: TextAlign.center,
                      style: labelStyle(i),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } else {
      strip = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stages.length; i++)
            stage(
              i,
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: OrbitSize.iconLg + OrbitSpace.s8,
                      child: Column(
                        children: [
                          marker(i),
                          if (i < stages.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                constraints: const BoxConstraints(
                                  minHeight: OrbitSpace.s16,
                                ),
                                color: lineColor(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: OrbitSpace.s12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: OrbitSpace.s2,
                          bottom: OrbitSpace.s12,
                        ),
                        child: Text(stages[i], style: labelStyle(i)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        strip,
        if (progress != null) ...[
          const SizedBox(height: OrbitSpace.s12),
          ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(OrbitRadius.pill),
            ),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: OrbitSpace.s8,
              semanticsLabel: progressLabel,
            ),
          ),
        ],
        if (progressLabel != null) ...[
          const SizedBox(height: OrbitSpace.s4),
          Text(
            progressLabel!,
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
