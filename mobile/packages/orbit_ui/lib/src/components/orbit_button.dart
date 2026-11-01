import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';
import 'icon_label.dart';

/// What an [OrbitButton] does.
enum OrbitButtonVariant {
  /// Filled with the app's primary colour. One per screen.
  primary,

  /// Outlined on the surface colour.
  secondary,

  /// Filled red: reject, delete, cancel a booking.
  danger,

  /// Filled green with a phone icon: call the FA, call the helpline.
  call,
}

/// Height of an [OrbitButton].
enum OrbitButtonSize {
  /// 48 dp: the minimum touch target. Secondary actions.
  medium(OrbitSize.controlLg),

  /// 56 dp: primary actions.
  large(OrbitSize.controlXl),

  /// 64 dp: the farmer's main action on a screen, FA big buttons.
  hero(OrbitSize.controlXxl);

  const OrbitButtonSize(this.minHeight);

  /// Minimum height in logical pixels. The button grows when its label wraps.
  final double minHeight;
}

/// The Orbit button: big, high-contrast, with an optional English sub-line.
///
/// Disabled when [onPressed] is null. While [loading] it shows a spinner,
/// keeps its colours and ignores taps (and reports itself disabled to
/// screen readers so a request is not sent twice). The label wraps to more
/// lines instead of shrinking or being cut.
class OrbitButton extends StatelessWidget {
  /// Creates a button.
  const OrbitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondaryLabel,
    this.variant = OrbitButtonVariant.primary,
    this.size = OrbitButtonSize.large,
    this.icon,
    this.fullWidth = true,
    this.loading = false,
  });

  /// Main label (Telugu-first).
  final String label;

  /// Optional smaller second line (English).
  final String? secondaryLabel;

  /// Tap handler; null disables the button.
  final VoidCallback? onPressed;

  /// Colour role. Defaults to [OrbitButtonVariant.primary].
  final OrbitButtonVariant variant;

  /// Height. Defaults to [OrbitButtonSize.large] (56 dp).
  final OrbitButtonSize size;

  /// Leading icon. [OrbitButtonVariant.call] uses [OrbitIcons.phone] when
  /// this is null.
  final IconData? icon;

  /// Stretch to the available width. Defaults to true.
  final bool fullWidth;

  /// Shows a spinner in place of the icon and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final disabled = onPressed == null && !loading;

    final (Color background, Color foreground) = switch (variant) {
      OrbitButtonVariant.primary => (scheme.primary, scheme.onPrimary),
      OrbitButtonVariant.secondary => (scheme.surface, scheme.secondary),
      OrbitButtonVariant.danger => (scheme.error, scheme.onError),
      OrbitButtonVariant.call => (orbit.success.fg, scheme.onPrimary),
    };
    final filled = variant != OrbitButtonVariant.secondary;
    final bg = disabled && filled ? scheme.surfaceContainerHighest : background;
    final fg = disabled ? scheme.onSurfaceVariant : foreground;
    final effectiveIcon =
        icon ?? (variant == OrbitButtonVariant.call ? OrbitIcons.phone : null);

    final labelStyle = size == OrbitButtonSize.hero
        ? theme.textTheme.titleMedium!
        : theme.textTheme.labelLarge!;

    final style = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(bg),
      foregroundColor: WidgetStatePropertyAll(fg),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? fg.withValues(alpha: 0.12)
            : null,
      ),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(
        Size(OrbitSize.controlLg, size.minHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: OrbitSpace.s16,
          vertical: OrbitSpace.s8,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(OrbitRadius.lg)),
        ),
      ),
      side: WidgetStatePropertyAll(
        filled
            ? BorderSide.none
            : BorderSide(
                color: disabled ? scheme.outlineVariant : scheme.outline,
              ),
      ),
    );

    final child = IconLabel(
      leading: loading
          ? SizedBox.square(
              dimension: OrbitSize.iconMd,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
            )
          : effectiveIcon == null
          ? null
          : Icon(effectiveIcon, size: OrbitSize.iconLg, color: fg),
      label: label,
      style: labelStyle.copyWith(color: fg),
      secondary: secondaryLabel,
      secondaryStyle: theme.textTheme.bodySmall!.copyWith(color: fg),
    );

    final pressed = loading ? null : onPressed;
    final button = filled
        ? FilledButton(onPressed: pressed, style: style, child: child)
        : OutlinedButton(onPressed: pressed, style: style, child: child);
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
