import 'package:flutter/material.dart';

import '../tokens/orbit_tokens.g.dart';

/// Internal: the rounded box shared by [OrbitTag], [StatusPill] and
/// [SeverityPill]. Not exported.
class PillBox extends StatelessWidget {
  /// Creates a pill with an optional leading icon.
  const PillBox({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  /// Visible text.
  final String label;

  /// Fill colour.
  final Color background;

  /// Text and icon colour (must reach 4.5:1 on [background]).
  final Color foreground;

  /// Optional leading icon (decorative; [label] carries the meaning).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!
        .copyWith(color: foreground);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.pill)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OrbitSpace.s8,
          vertical: OrbitSpace.s2,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              if (icon != null)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: OrbitSpace.s4,
                    ),
                    child: Icon(
                      icon,
                      size: OrbitSize.iconSm,
                      color: foreground,
                    ),
                  ),
                ),
              TextSpan(text: label),
            ],
          ),
          style: style,
        ),
      ),
    );
  }
}
