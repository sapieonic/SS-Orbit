import 'package:flutter/material.dart';

import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';

/// Colour of the icon disc on a [StateCard].
enum StateCardTone {
  /// Empty states ("No visits yet").
  neutral,

  /// Waiting on someone ("Your FA will call you within 2 days").
  info,

  /// Offline, pending.
  warning,

  /// Failed ("Bill upload failed").
  danger,
}

/// One card, one action: the empty, offline and error states. Shown in place
/// of the screen content while the header and Listen button stay.
class StateCard extends StatelessWidget {
  /// Creates a state card.
  const StateCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.message,
    this.action,
    this.listen,
    this.tone = StateCardTone.neutral,
  });

  /// Large icon (decorative; [title] carries the meaning).
  final IconData icon;

  /// Main line, e.g. "ఇంటర్నెట్ లేదు".
  final String title;

  /// Sub-line, e.g. "Showing saved advice, visits and weather from 7:00 am".
  final String? subtitle;

  /// Optional extra note in smaller text.
  final String? message;

  /// The single action, usually an `OrbitButton`.
  final Widget? action;

  /// Optional `ListenButton`, shown under the action.
  final Widget? listen;

  /// Icon disc colour. Defaults to [StateCardTone.neutral].
  final StateCardTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final (Color disc, Color glyph) = switch (tone) {
      StateCardTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      StateCardTone.info => (orbit.info.tint, orbit.info.strong),
      StateCardTone.warning => (orbit.warning.tint, orbit.warning.strong),
      StateCardTone.danger => (orbit.danger.tint, orbit.danger.strong),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(OrbitSpace.s16),
                child: Icon(icon, size: OrbitSize.iconXxl, color: glyph),
              ),
            ),
            const SizedBox(height: OrbitSpace.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: OrbitSpace.s4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: OrbitSpace.s8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: OrbitSpace.s20),
              action!,
            ],
            if (listen != null) ...[
              const SizedBox(height: OrbitSpace.s12),
              listen!,
            ],
          ],
        ),
      ),
    );
  }
}
