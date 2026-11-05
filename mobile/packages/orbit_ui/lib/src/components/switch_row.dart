import 'package:flutter/material.dart';

import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';

/// A setting that is on or off: a title, an optional sub-line that wraps,
/// and a switch, at least 60 dp tall (A7 Sync, A11 Me).
///
/// The whole row toggles, and reads as one switch with the title and
/// sub-line as its label. [bordered] draws it as its own card; leave it off
/// inside a grouped card of rows.
class SwitchRow extends StatelessWidget {
  /// Creates a switch row.
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.bordered = false,
  });

  /// What the setting is, e.g. "Upload photos on Wi-Fi only".
  final String title;

  /// Optional line under the title, e.g. "On · records still sync on mobile
  /// data".
  final String? subtitle;

  /// Whether the setting is on.
  final bool value;

  /// Called with the new value. Null disables the row.
  final ValueChanged<bool>? onChanged;

  /// Draws a card border around the row.
  final bool bordered;

  /// Minimum row height.
  static const double minHeight = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    const radius = BorderRadius.all(Radius.circular(OrbitSpace.s16));
    final enabled = onChanged != null;

    final row = InkWell(
      borderRadius: bordered ? radius : null,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: OrbitSpace.s8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        fontWeight: OrbitFont.weightBold,
                        color: enabled
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    if (subtitle case final subtitle?)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: orbit.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: OrbitSpace.s12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );

    return MergeSemantics(
      child: Material(
        color: bordered ? scheme.surface : Colors.transparent,
        shape: bordered
            ? RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(color: scheme.outlineVariant, width: 1.5),
              )
            : null,
        child: row,
      ),
    );
  }
}
