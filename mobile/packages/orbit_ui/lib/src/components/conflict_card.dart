import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';
import 'status_pill.dart';

/// A record HO changed while the FA's own change was waiting to sync (A7
/// Sync): what it is, both values side by side, and one button for each
/// version.
///
/// Red-edged until resolved. Pass [resolving] while the choice is being
/// saved: both buttons ignore taps and the chosen one is not known here, so
/// both read as disabled.
///
/// Leave [keepMineLabel] null when only HO's version can be kept (e.g. a
/// crop season clash): Keep mine is not shown and Keep HO's takes the full
/// width.
class ConflictCard extends StatelessWidget {
  /// Creates a conflict card.
  const ConflictCard({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.mineLabel,
    required this.mineValue,
    required this.theirsLabel,
    required this.theirsValue,
    required this.keepTheirsLabel,
    required this.onKeepTheirs,
    this.keepMineLabel,
    this.onKeepMine,
    this.meta,
    this.resolving = false,
  });

  /// What changed, e.g. "Visit log · Padma S".
  final String title;

  /// Optional line under the title, e.g. "HO changed Plot 2 while you were
  /// offline".
  final String? meta;

  /// The status pill's word, e.g. "Conflict".
  final String statusLabel;

  /// Heading of the FA's value, e.g. "Yours".
  final String mineLabel;

  /// The FA's value, e.g. "1 ac 30 gunta".
  final String mineValue;

  /// Heading of HO's value, e.g. "HO's".
  final String theirsLabel;

  /// HO's value, e.g. "2 ac 0 gunta".
  final String theirsValue;

  /// "Keep mine", or null to hide the button (only HO's version can be
  /// kept).
  final String? keepMineLabel;

  /// "Keep HO's".
  final String keepTheirsLabel;

  /// Keeps the FA's version (the button is disabled when null and
  /// [keepMineLabel] is set).
  final VoidCallback? onKeepMine;

  /// Keeps HO's version.
  final VoidCallback? onKeepTheirs;

  /// The choice is being saved: buttons ignore taps.
  final bool resolving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final danger = orbit.danger;
    const radius = BorderRadius.all(Radius.circular(OrbitSpace.s16));
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(OrbitSpace.s12)),
    );
    const minButton = Size(OrbitSize.controlLg, OrbitSize.controlLg);

    Widget value(String label, String text) => Expanded(
      child: MergeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.all(
              Radius.circular(OrbitSpace.s12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OrbitSpace.s10,
              vertical: OrbitSpace.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: orbit.textMuted,
                  ),
                ),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontWeight: OrbitFont.weightBold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: danger.fg, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: danger.tint,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(OrbitRadius.md),
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: 36,
                      child: Icon(
                        OrbitIcons.alert,
                        size: OrbitSize.iconMd,
                        color: danger.fg,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: OrbitSpace.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          fontWeight: OrbitFont.weightBold,
                        ),
                      ),
                      if (meta case final meta?)
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: orbit.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: OrbitSpace.s8),
                StatusPill(label: statusLabel, tone: OrbitStatusTone.danger),
              ],
            ),
            const SizedBox(height: OrbitSpace.s8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  value(mineLabel, mineValue),
                  const SizedBox(width: OrbitSpace.s8),
                  value(theirsLabel, theirsValue),
                ],
              ),
            ),
            const SizedBox(height: OrbitSpace.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (keepMineLabel case final keepMineLabel?) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: resolving ? null : onKeepMine,
                      style: OutlinedButton.styleFrom(
                        minimumSize: minButton,
                        shape: buttonShape,
                        foregroundColor: danger.strong,
                        side: BorderSide(color: danger.fg, width: 1.5),
                      ),
                      child: Text(keepMineLabel, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: OrbitSpace.s8),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: resolving ? null : onKeepTheirs,
                    style: FilledButton.styleFrom(
                      minimumSize: minButton,
                      shape: buttonShape,
                      backgroundColor: danger.fg,
                      foregroundColor: scheme.onError,
                    ),
                    child: Text(keepTheirsLabel, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
