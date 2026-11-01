import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../tokens/orbit_tokens.g.dart';
import 'bilingual_text.dart';
import 'orbit_tag.dart';

/// A home-grid tile: icon first, Telugu label, English sub-line.
///
/// [locked] shows a padlock (FAR-06) and mutes the icon, but the tile still
/// calls [onTap] so the app can explain the plan or phase. Give
/// [lockedSemanticLabel] (e.g. "Premium") so screen readers hear why.
class IconTile extends StatelessWidget {
  /// Creates a tile.
  const IconTile({
    super.key,
    required this.icon,
    required this.label,
    this.secondaryLabel,
    this.onTap,
    this.locked = false,
    this.lockedSemanticLabel,
    this.badge,
  });

  /// Tile icon.
  final IconData icon;

  /// Main label, e.g. "క్యాలెండర్".
  final String label;

  /// Sub-line, e.g. "Crop calendar".
  final String? secondaryLabel;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Shows the padlock state.
  final bool locked;

  /// Read by screen readers on the padlock, already localised.
  final String? lockedSemanticLabel;

  /// Optional badge text, e.g. a count or "FREE".
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(OrbitRadius.lg));
    final (Color disc, Color glyph) = locked
        ? (scheme.surfaceContainerHighest, scheme.onSurfaceVariant)
        : (scheme.primaryContainer, scheme.onPrimaryContainer);

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: OrbitSize.tileMinHeight),
          child: Padding(
            padding: const EdgeInsets.all(OrbitSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: disc,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(OrbitRadius.sm),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(OrbitSpace.s8),
                        child: Icon(icon, size: OrbitSize.iconLg, color: glyph),
                      ),
                    ),
                    const Spacer(),
                    if (badge != null)
                      Flexible(
                        child: OrbitTag(
                          label: badge!,
                          tone: OrbitTagTone.highlight,
                        ),
                      ),
                    if (locked)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: OrbitSpace.s4,
                        ),
                        child: Icon(
                          OrbitIcons.lock,
                          size: OrbitSize.iconMd,
                          color: scheme.onSurfaceVariant,
                          semanticLabel: lockedSemanticLabel,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: OrbitSpace.s8),
                BilingualText(label, secondary: secondaryLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays out [IconTile]s in rows of [columns]. Tiles in a row share the
/// tallest tile's height and grow with the text, unlike a fixed-ratio
/// [GridView] that clips wrapped Telugu at large text sizes.
class IconTileGrid extends StatelessWidget {
  /// Creates a grid.
  const IconTileGrid({super.key, required this.children, this.columns = 2});

  /// The tiles.
  final List<Widget> children;

  /// Tiles per row. Defaults to 2 (360 dp phones).
  final int columns;

  @override
  Widget build(BuildContext context) {
    const gap = OrbitSpace.s8;
    return Column(
      children: [
        for (var start = 0; start < children.length; start += columns) ...[
          if (start > 0) const SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < start + columns; i++) ...[
                  if (i > start) const SizedBox(width: gap),
                  Expanded(
                    child: i < children.length
                        ? children[i]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
