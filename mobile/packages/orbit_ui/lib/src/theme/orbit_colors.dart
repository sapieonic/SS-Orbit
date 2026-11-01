import 'package:flutter/material.dart';

/// A colour family for one meaning (success, a severity, ...).
///
/// - [fg]: icons, fills, borders and dots (at least 3:1 on white, except
///   warning amber, which never carries white text).
/// - [strong]: text on [tint] or on white (AA, 4.5:1 or more).
/// - [tint]: background of pills, banners and cards.
@immutable
class OrbitTone {
  /// Creates a tone.
  const OrbitTone({required this.fg, required this.strong, required this.tint});

  /// Icons, fills and borders.
  final Color fg;

  /// Text on [tint] or on white.
  final Color strong;

  /// Backgrounds.
  final Color tint;

  /// Linearly interpolates between two tones.
  static OrbitTone lerp(OrbitTone a, OrbitTone b, double t) => OrbitTone(
    fg: Color.lerp(a.fg, b.fg, t)!,
    strong: Color.lerp(a.strong, b.strong, t)!,
    tint: Color.lerp(a.tint, b.tint, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is OrbitTone &&
      other.fg == fg &&
      other.strong == strong &&
      other.tint == tint;

  @override
  int get hashCode => Object.hash(fg, strong, tint);
}

/// Orbit colours that Material's [ColorScheme] does not model.
///
/// Read with `OrbitColors.of(context)`. Components take every colour from
/// here or from the [ColorScheme], never from token constants, so the farmer
/// and FA apps differ only by theme.
@immutable
class OrbitColors extends ThemeExtension<OrbitColors> {
  /// Creates the extension. Apps get one from `OrbitTheme`.
  const OrbitColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.severityLow,
    required this.severityModerate,
    required this.severityHigh,
    required this.textMuted,
    required this.onPrimaryBar,
    required this.onPrimaryBarFill,
    required this.onPrimaryBarBorder,
    required this.highlight,
    required this.onHighlight,
    required this.accent,
  });

  /// Done, saved, "Shanmukha product found", call actions.
  final OrbitTone success;

  /// Pending, offline, needs attention. Never white text on [OrbitTone.fg].
  final OrbitTone warning;

  /// Errors, failed, reject.
  final OrbitTone danger;

  /// Neutral information; follows the app's primary colour.
  final OrbitTone info;

  /// Low severity.
  final OrbitTone severityLow;

  /// Moderate severity.
  final OrbitTone severityModerate;

  /// High severity.
  final OrbitTone severityHigh;

  /// Meta lines (dates, distances). Not for farmer body text.
  final Color textMuted;

  /// Text and icons on a primary or ink bar.
  final Color onPrimaryBar;

  /// Chips and buttons placed on a primary or ink bar.
  final Color onPrimaryBarFill;

  /// Borders on a primary or ink bar.
  final Color onPrimaryBarBorder;

  /// Highlight badge background (always with [onHighlight] text).
  final Color highlight;

  /// Text on [highlight].
  final Color onHighlight;

  /// Accent dots and icons only, never text.
  final Color accent;

  /// The [OrbitColors] of the nearest theme. The theme must come from
  /// `OrbitTheme`.
  static OrbitColors of(BuildContext context) {
    final colors = Theme.of(context).extension<OrbitColors>();
    assert(colors != null, 'No OrbitColors in the theme. Use OrbitTheme.');
    return colors!;
  }

  @override
  OrbitColors copyWith({
    OrbitTone? success,
    OrbitTone? warning,
    OrbitTone? danger,
    OrbitTone? info,
    OrbitTone? severityLow,
    OrbitTone? severityModerate,
    OrbitTone? severityHigh,
    Color? textMuted,
    Color? onPrimaryBar,
    Color? onPrimaryBarFill,
    Color? onPrimaryBarBorder,
    Color? highlight,
    Color? onHighlight,
    Color? accent,
  }) => OrbitColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    severityLow: severityLow ?? this.severityLow,
    severityModerate: severityModerate ?? this.severityModerate,
    severityHigh: severityHigh ?? this.severityHigh,
    textMuted: textMuted ?? this.textMuted,
    onPrimaryBar: onPrimaryBar ?? this.onPrimaryBar,
    onPrimaryBarFill: onPrimaryBarFill ?? this.onPrimaryBarFill,
    onPrimaryBarBorder: onPrimaryBarBorder ?? this.onPrimaryBarBorder,
    highlight: highlight ?? this.highlight,
    onHighlight: onHighlight ?? this.onHighlight,
    accent: accent ?? this.accent,
  );

  @override
  OrbitColors lerp(OrbitColors? other, double t) {
    if (other == null) return this;
    return OrbitColors(
      success: OrbitTone.lerp(success, other.success, t),
      warning: OrbitTone.lerp(warning, other.warning, t),
      danger: OrbitTone.lerp(danger, other.danger, t),
      info: OrbitTone.lerp(info, other.info, t),
      severityLow: OrbitTone.lerp(severityLow, other.severityLow, t),
      severityModerate: OrbitTone.lerp(
        severityModerate,
        other.severityModerate,
        t,
      ),
      severityHigh: OrbitTone.lerp(severityHigh, other.severityHigh, t),
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      onPrimaryBar: Color.lerp(onPrimaryBar, other.onPrimaryBar, t)!,
      onPrimaryBarFill: Color.lerp(
        onPrimaryBarFill,
        other.onPrimaryBarFill,
        t,
      )!,
      onPrimaryBarBorder: Color.lerp(
        onPrimaryBarBorder,
        other.onPrimaryBarBorder,
        t,
      )!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      onHighlight: Color.lerp(onHighlight, other.onHighlight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}
