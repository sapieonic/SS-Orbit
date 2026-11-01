import 'package:flutter/widgets.dart';

import '../tokens/orbit_tokens.g.dart';

/// Internal: an inline leading widget plus a label and optional sub-line, as
/// one [Text.rich]. It wraps when the width is bounded, sizes to its text
/// when it is not, and supports intrinsic sizing, so buttons work in a [Row]
/// without an [Expanded] and inside an [IntrinsicHeight]. Not exported.
class IconLabel extends StatelessWidget {
  /// Creates the label.
  const IconLabel({
    super.key,
    required this.label,
    required this.style,
    this.secondary,
    this.secondaryStyle,
    this.leading,
    this.textAlign = TextAlign.center,
  });

  /// Icon or spinner before the first line.
  final Widget? leading;

  /// Main line.
  final String label;

  /// Style of [label].
  final TextStyle style;

  /// Optional second line.
  final String? secondary;

  /// Style of [secondary].
  final TextStyle? secondaryStyle;

  /// Alignment of the lines.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          if (leading != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: OrbitSpace.s8),
                child: leading,
              ),
            ),
          TextSpan(text: label, style: style),
          if (secondary != null)
            TextSpan(text: '\n$secondary', style: secondaryStyle),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
