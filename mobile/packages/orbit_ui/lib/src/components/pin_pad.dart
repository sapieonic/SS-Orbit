import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/orbit_icons.dart';
import '../tokens/orbit_tokens.g.dart';

/// The on-screen number pad for a PIN: 1-9 in three rows, then an optional
/// [leading] key (fingerprint, Back), 0 and delete.
///
/// Keys are [keyHeight] tall (64 dp by default, as on the unlock screen) and
/// grow with the text scale. The pad keeps no state: the screen holds the
/// digits typed so far and shows them with [PinDots].
class PinPad extends StatelessWidget {
  /// Creates a PIN pad.
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    required this.deleteLabel,
    this.leading,
    this.enabled = true,
    this.keyHeight = OrbitSize.controlXxl,
  });

  /// Called with the tapped digit, `'0'` to `'9'`.
  final ValueChanged<String> onDigit;

  /// Deletes the last digit.
  final VoidCallback onDelete;

  /// What screen readers say for the delete key, already localised
  /// ("Delete digit").
  final String deleteLabel;

  /// The key left of 0, usually a [PinPadKey.icon] (fingerprint) or a
  /// [PinPadKey.text] (Back). Empty when null.
  final Widget? leading;

  /// False while the PIN is being checked or the pad is locked: keys ignore
  /// taps and read as disabled.
  final bool enabled;

  /// Minimum key height.
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => PinPadKey.digit(
      digit: d,
      height: keyHeight,
      onPressed: enabled ? () => onDigit(d) : null,
    );

    final rows = [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        [for (final d in row) digit(d)],
      [
        leading ?? SizedBox(height: keyHeight),
        digit('0'),
        PinPadKey.icon(
          icon: OrbitIcons.backspace,
          semanticLabel: deleteLabel,
          height: keyHeight,
          onPressed: enabled ? onDelete : null,
        ),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: OrbitSpace.s10),
          // Every key in a row as tall as the tallest (a wrapped word key).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) const SizedBox(width: OrbitSpace.s10),
                  Expanded(child: rows[r][c]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One key of a [PinPad]: a digit, an icon or a short word. Use the named
/// constructors for [PinPad.leading].
class PinPadKey extends StatelessWidget {
  /// A digit key (used by the pad itself).
  const PinPadKey.digit({
    super.key,
    required String this.digit,
    required this.onPressed,
    this.height = OrbitSize.controlXxl,
  }) : icon = null,
       label = null,
       semanticLabel = null;

  /// An icon key, e.g. fingerprint. [semanticLabel] is what screen readers
  /// say ("Use fingerprint").
  const PinPadKey.icon({
    super.key,
    required IconData this.icon,
    required String this.semanticLabel,
    required this.onPressed,
    this.height = OrbitSize.controlXxl,
  }) : digit = null,
       label = null;

  /// A short word key in the primary colour, e.g. "Back". [semanticLabel]
  /// replaces [label] for screen readers when the word alone is unclear
  /// ("Back to language").
  const PinPadKey.text({
    super.key,
    required String this.label,
    required this.onPressed,
    this.semanticLabel,
    this.height = OrbitSize.controlXxl,
  }) : digit = null,
       icon = null;

  /// The digit, for a digit key.
  final String? digit;

  /// The icon, for an icon key.
  final IconData? icon;

  /// The word, for a text key.
  final String? label;

  /// Screen reader label for icon and text keys.
  final String? semanticLabel;

  /// Tap handler; null disables the key.
  final VoidCallback? onPressed;

  /// Minimum height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final ink = enabled ? scheme.onSurface : scheme.onSurfaceVariant;
    const radius = BorderRadius.all(Radius.circular(OrbitSpace.s16));

    final Widget face;
    if (digit case final digit?) {
      face = Text(
        digit,
        style: theme.textTheme.headlineMedium!.copyWith(
          fontSize: 26,
          fontWeight: OrbitFont.weightBold,
          color: ink,
        ),
      );
    } else if (icon case final icon?) {
      face = Icon(
        icon,
        size: OrbitSize.iconLg,
        color: enabled ? scheme.primary : ink,
      );
    } else {
      face = Text(
        label!,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge!.copyWith(
          color: enabled ? scheme.primary : ink,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? digit ?? label,
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        child: InkWell(
          borderRadius: radius,
          splashColor: scheme.primaryContainer,
          highlightColor: scheme.primaryContainer,
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.all(OrbitSpace.s4),
              child: Center(child: face),
            ),
          ),
        ),
      ),
    );
  }
}

/// How many PIN digits are typed: [length] dots, the first [filled] solid.
///
/// Read out as [semanticLabel] ("2 of 4 digits entered"), never digit by
/// digit. [error] colours the dots red after a wrong PIN.
class PinDots extends StatelessWidget {
  /// Creates the dots.
  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    required this.semanticLabel,
    this.error = false,
  }) : assert(length > 0, 'length must be positive'),
       assert(filled >= 0 && filled <= length, 'filled must be 0..length');

  /// Digits in the PIN.
  final int length;

  /// Digits typed so far.
  final int filled;

  /// Already localised, e.g. "2 of 4 digits entered".
  final String semanticLabel;

  /// Shows the dots in the danger colour.
  final bool error;

  /// Diameter of one dot.
  static const double dotSize = 18;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = error ? scheme.error : scheme.primary;
    final off = error ? scheme.error : scheme.outline;
    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < length; i++) ...[
            if (i > 0) const SizedBox(width: dotSize),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? on : Colors.transparent,
                border: i < filled ? null : Border.all(color: off, width: 2.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
