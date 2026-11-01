import 'package:flutter/material.dart';

import '../tokens/orbit_tokens.g.dart';
import 'bilingual_text.dart';

/// An icon followed by a bilingual line, e.g. the next FA visit:
/// [calendar] "గురు 29 అక్టో" / "Next FA visit".
class InfoRow extends StatelessWidget {
  /// Creates an info row.
  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.secondaryText,
    this.trailing,
  });

  /// Leading icon (decorative).
  final IconData icon;

  /// Main line.
  final String text;

  /// Optional sub-line.
  final String? secondaryText;

  /// Optional widget at the end.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: OrbitSpace.s2),
          child: Icon(
            icon,
            size: OrbitSize.iconLg,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: OrbitSpace.s12),
        Expanded(
          child: BilingualText(
            text,
            secondary: secondaryText,
            primaryStyle: theme.textTheme.bodyLarge,
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

/// A label and its value on one row, for review screens (F8 "check and
/// book": సేవ / మట్టి పరీక్ష).
class KeyValueRow extends StatelessWidget {
  /// Creates a key-value row.
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.secondaryValue,
  });

  /// The key, e.g. "రోజు".
  final String label;

  /// The value, e.g. "గురు 30 అక్టో".
  final String value;

  /// Optional sub-line under the value.
  final String? secondaryValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OrbitSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: OrbitSpace.s12),
          Expanded(
            flex: 3,
            child: BilingualText(value, secondary: secondaryValue),
          ),
        ],
      ),
    );
  }
}
