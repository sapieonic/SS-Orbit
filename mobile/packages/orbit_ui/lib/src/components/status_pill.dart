import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import 'pill_box.dart';

/// Meaning of a [StatusPill].
enum OrbitStatusTone {
  /// Done, delivered, paid.
  success,

  /// Pending, checking, offline.
  warning,

  /// Failed, missed, rejected.
  danger,

  /// Sent, requested.
  info,

  /// Planned, scheduled, not started.
  neutral,
}

/// A status as icon plus word, never colour alone.
///
/// Each tone has a default icon; pass [icon] to choose another (for example
/// [OrbitIcons.pending] for "checking").
class StatusPill extends StatelessWidget {
  /// Creates a status pill.
  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  /// The status word, already localised ("చెల్లించారు", "Pending").
  final String label;

  /// Meaning and colour.
  final OrbitStatusTone tone;

  /// Overrides the tone's default icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final orbit = OrbitColors.of(context);
    final (Color bg, Color fg, IconData glyph) = switch (tone) {
      OrbitStatusTone.success => (
        orbit.success.tint,
        orbit.success.strong,
        OrbitIcons.success,
      ),
      OrbitStatusTone.warning => (
        orbit.warning.tint,
        orbit.warning.strong,
        OrbitIcons.pending,
      ),
      OrbitStatusTone.danger => (
        orbit.danger.tint,
        orbit.danger.strong,
        OrbitIcons.error,
      ),
      OrbitStatusTone.info => (
        orbit.info.tint,
        orbit.info.strong,
        OrbitIcons.info,
      ),
      OrbitStatusTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        OrbitIcons.calendar,
      ),
    };
    return PillBox(
      label: label,
      background: bg,
      foreground: fg,
      icon: icon ?? glyph,
    );
  }
}

/// Pest or disease severity.
enum OrbitSeverity {
  /// Low ("తక్కువ").
  low,

  /// Moderate ("మధ్యస్థం").
  moderate,

  /// High.
  high,
}

/// Severity as a signal-bars icon plus word. Green, amber and red mean the
/// same in every app; the icon shape differs too, so colour is never the
/// only signal.
class SeverityPill extends StatelessWidget {
  /// Creates a severity pill.
  const SeverityPill({super.key, required this.severity, required this.label});

  /// The severity.
  final OrbitSeverity severity;

  /// The severity word, already localised.
  final String label;

  @override
  Widget build(BuildContext context) {
    final orbit = OrbitColors.of(context);
    final (OrbitTone tone, IconData glyph) = switch (severity) {
      OrbitSeverity.low => (orbit.severityLow, OrbitIcons.severityLow),
      OrbitSeverity.moderate => (
        orbit.severityModerate,
        OrbitIcons.severityModerate,
      ),
      OrbitSeverity.high => (orbit.severityHigh, OrbitIcons.severityHigh),
    };
    return PillBox(
      label: label,
      background: tone.tint,
      foreground: tone.strong,
      icon: glyph,
    );
  }
}
