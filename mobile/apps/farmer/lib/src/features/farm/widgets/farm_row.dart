import 'package:flutter/material.dart';
import 'package:orbit_ui/orbit_ui.dart';

/// A tappable settings-style row on My farm: icon, label with an optional
/// second line, and a chevron. At least 56 dp tall; the label wraps.
class FarmRow extends StatelessWidget {
  /// Creates a row.
  const FarmRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.secondaryLabel,
  });

  /// Leading icon (decorative).
  final IconData icon;

  /// Main line.
  final String label;

  /// Optional second line.
  final String? secondaryLabel;

  /// Called when tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: OrbitSize.controlXl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OrbitSpace.s16,
              vertical: OrbitSpace.s12,
            ),
            child: InfoRow(
              icon: icon,
              text: label,
              secondaryText: secondaryLabel,
              trailing: ExcludeSemantics(
                child: Icon(
                  OrbitIcons.chevronRight,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
