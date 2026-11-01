import 'package:flutter/material.dart';

import '../tokens/orbit_tokens.g.dart';

/// A section title with an optional inline English part and a trailing
/// widget: "మట్టి పరీక్ష · soil test".
class SectionHeader extends StatelessWidget {
  /// Creates a section header.
  const SectionHeader({
    super.key,
    required this.title,
    this.secondary,
    this.trailing,
  });

  /// Title (Telugu-first), styled `titleMedium`.
  final String title;

  /// Text after the title in a smaller, lighter style, e.g. "· soil test".
  final String? secondary;

  /// Optional widget at the end, e.g. a "see all" `TextButton`.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                text: title,
                style: theme.textTheme.titleMedium,
                children: [
                  if (secondary != null)
                    TextSpan(
                      text: ' $secondary',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: OrbitSpace.s8),
          trailing!,
        ],
      ],
    );
  }
}
