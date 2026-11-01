import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../tokens/orbit_tokens.g.dart';
import 'bilingual_text.dart';

/// One big option in a single-choice list (crop, season, harvested or
/// abandoned): icon, a label that wraps, an optional second line, and a
/// tick when selected. At least 56 dp tall. Announced as a selected or
/// unselected button in a group where one is picked.
class ChoiceTile extends StatelessWidget {
  /// Creates a choice tile.
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.secondaryLabel,
    this.icon,
    this.tag,
  });

  /// Main line, already localised.
  final String label;

  /// Optional second line (the other language, a hint).
  final String? secondaryLabel;

  /// Optional leading icon (decorative).
  final IconData? icon;

  /// Optional tag under the label, e.g. "This season".
  final Widget? tag;

  /// Whether this option is the chosen one.
  final bool selected;

  /// Called when tapped. Null disables the tile.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(OrbitRadius.lg));
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? scheme.primaryContainer : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outline,
              width: selected ? OrbitSpace.s2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: OrbitSize.controlXl),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OrbitSpace.s16,
                  vertical: OrbitSpace.s12,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: OrbitSize.iconXl,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: OrbitSpace.s12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BilingualText(label, secondary: secondaryLabel),
                          if (tag != null) ...[
                            const SizedBox(height: OrbitSpace.s4),
                            tag!,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: OrbitSpace.s8),
                    ExcludeSemantics(
                      child: Icon(
                        selected ? OrbitIcons.success : null,
                        size: OrbitSize.iconLg,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
