import 'package:flutter/material.dart';

import '../theme/orbit_colors.dart';
import 'pill_box.dart';

/// Colour of an [OrbitTag].
enum OrbitTagTone {
  /// Grey: notice source (HO, CIV), plain labels.
  neutral,

  /// Primary tint: "your FA", "pinned", plan names.
  primary,

  /// Yellow with ink text: "FREE", counts that need attention.
  highlight,
}

/// A small text tag in a pill: source tags, "your FA", plan badges.
///
/// For a status (done, failed, pending) use `StatusPill`, which always adds
/// an icon.
class OrbitTag extends StatelessWidget {
  /// Creates a tag.
  const OrbitTag({
    super.key,
    required this.label,
    this.tone = OrbitTagTone.neutral,
    this.icon,
  });

  /// Tag text, already localised.
  final String label;

  /// Colour. Defaults to [OrbitTagTone.neutral].
  final OrbitTagTone tone;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final orbit = OrbitColors.of(context);
    final (Color bg, Color fg) = switch (tone) {
      OrbitTagTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      OrbitTagTone.primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      OrbitTagTone.highlight => (orbit.highlight, orbit.onHighlight),
    };
    return PillBox(label: label, background: bg, foreground: fg, icon: icon);
  }
}
