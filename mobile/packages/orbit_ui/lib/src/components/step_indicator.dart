import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';

/// Where a flow is, as numbered steps in a row: done steps show a green
/// tick, the current one is filled with the primary colour, the rest are
/// grey (A4 enrolment: 1 Farmer, 2 Farm, 3 Crop).
///
/// [StepLayout] shows progress as a bar for short one-question flows; use
/// this where the steps have names.
class StepIndicator extends StatelessWidget {
  /// Creates the indicator.
  const StepIndicator({
    super.key,
    required this.labels,
    required this.currentIndex,
    this.semanticLabel,
    this.doneLabel,
    this.currentLabel,
  });

  /// Step names, already localised ("Farmer", "Farm", "Crop").
  final List<String> labels;

  /// 0-based index of the current step. Steps before it are done;
  /// `labels.length` marks every step done.
  final int currentIndex;

  /// What the row is, for screen readers ("Steps").
  final String? semanticLabel;

  /// Added after a done step's name for screen readers ("done").
  final String? doneLabel;

  /// Added after the current step's name for screen readers ("current
  /// step").
  final String? currentLabel;

  @override
  Widget build(BuildContext context) {
    assert(labels.length > 1, 'need at least two steps');
    assert(
      currentIndex >= 0 && currentIndex <= labels.length,
      'currentIndex must be 0..labels.length (all done)',
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);

    Widget step(int i) {
      final done = i < currentIndex;
      final current = i == currentIndex;
      final (Color fill, Color onFill, Color text) = done
          ? (orbit.success.fg, scheme.onPrimary, orbit.success.strong)
          : current
          ? (scheme.primary, scheme.onPrimary, scheme.primary)
          : (
              scheme.surfaceContainerHighest,
              scheme.onSurfaceVariant,
              orbit.textMuted,
            );
      final extra = done ? doneLabel : (current ? currentLabel : null);
      return Semantics(
        label: [labels[i], ?extra].join(', '),
        selected: current,
        excludeSemantics: true,
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: SizedBox.square(
                dimension: 28,
                child: Center(
                  child: done
                      ? Icon(
                          OrbitIcons.check,
                          size: OrbitSize.iconSm,
                          color: onFill,
                        )
                      : Text(
                          '${i + 1}',
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontSize: 14,
                            fontWeight: OrbitFont.weightExtrabold,
                            color: onFill,
                            height: 1,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: OrbitSpace.s4),
            Text(
              labels[i],
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium!.copyWith(
                color: text,
                fontWeight: OrbitFont.weightBold,
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++) Expanded(child: step(i)),
        ],
      ),
    );
  }
}
