import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';

/// An error line shown in place, next to the control that failed (icon plus
/// words, never colour alone). Screen readers announce it when it appears.
class InlineError extends StatelessWidget {
  /// Creates the line.
  const InlineError(this.message, {super.key});

  /// Already localised error text.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = OrbitColors.of(context).danger;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: OrbitSpace.s2),
            child: Icon(
              OrbitIcons.alert,
              size: OrbitSize.iconMd,
              color: danger.fg,
            ),
          ),
          const SizedBox(width: OrbitSpace.s8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium!.copyWith(color: danger.strong),
            ),
          ),
        ],
      ),
    );
  }
}
