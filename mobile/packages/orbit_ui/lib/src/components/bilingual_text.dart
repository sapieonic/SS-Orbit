import 'package:flutter/material.dart';

/// A label with an optional smaller second line: the wireframes' Telugu
/// primary label with an English sub-line ("సురేష్‌కు కాల్ చేయండి" /
/// "Call Suresh").
///
/// Both lines wrap; neither is ever cut with an ellipsis. Strings arrive
/// already localised.
class BilingualText extends StatelessWidget {
  /// Creates a one- or two-line label.
  const BilingualText(
    this.primary, {
    super.key,
    this.secondary,
    this.primaryStyle,
    this.secondaryStyle,
    this.textAlign = TextAlign.start,
  });

  /// Main line (Telugu-first). Defaults to `titleSmall` (16/700).
  final String primary;

  /// Optional sub-line. Defaults to `bodySmall` (13/500) in the secondary
  /// text colour.
  final String? secondary;

  /// Overrides the primary line's style.
  final TextStyle? primaryStyle;

  /// Overrides the sub-line's style.
  final TextStyle? secondaryStyle;

  /// Alignment of both lines.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cross = switch (textAlign) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.end || TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        Text(
          primary,
          textAlign: textAlign,
          style: primaryStyle ?? theme.textTheme.titleSmall,
        ),
        if (secondary != null)
          Text(
            secondary!,
            textAlign: textAlign,
            style:
                secondaryStyle ??
                theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}
