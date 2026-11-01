import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';

/// What an [OrbitBanner] reports.
enum OrbitBannerKind {
  /// No internet; showing saved data.
  offline,

  /// Neutral information (syncing, new farmer).
  info,

  /// Something worked.
  success,

  /// Something failed.
  error,
}

/// A full-width message strip above the content, with an optional "saved
/// at" line and action. Announced by screen readers when it appears.
class OrbitBanner extends StatelessWidget {
  /// Creates a banner.
  const OrbitBanner({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.savedAt,
    this.action,
  });

  /// Kind: sets icon and colour.
  final OrbitBannerKind kind;

  /// Main line, e.g. "ఇంటర్నెట్ లేదు".
  final String title;

  /// Optional detail line.
  final String? message;

  /// Cache time line, already formatted, e.g. "Saved at 7:00 am".
  final String? savedAt;

  /// Optional action, e.g. a retry `TextButton`.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final orbit = OrbitColors.of(context);
    final (OrbitTone tone, IconData icon) = switch (kind) {
      OrbitBannerKind.offline => (orbit.warning, OrbitIcons.offline),
      OrbitBannerKind.info => (orbit.info, OrbitIcons.info),
      OrbitBannerKind.success => (orbit.success, OrbitIcons.success),
      OrbitBannerKind.error => (orbit.danger, OrbitIcons.warning),
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.tint,
          borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
          border: Border.all(color: tone.fg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(OrbitSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: OrbitSize.iconLg, color: tone.strong),
              const SizedBox(width: OrbitSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall!.copyWith(color: tone.strong),
                    ),
                    if (message != null)
                      Text(
                        message!,
                        style: textTheme.bodySmall!.copyWith(
                          color: tone.strong,
                        ),
                      ),
                    if (savedAt != null)
                      Text(
                        savedAt!,
                        style: textTheme.labelSmall!.copyWith(
                          color: tone.strong,
                        ),
                      ),
                    if (action != null) ...[
                      const SizedBox(height: OrbitSpace.s4),
                      action!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
