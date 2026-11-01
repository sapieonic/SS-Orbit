import 'package:flutter/material.dart';

import '../icons/orbit_icons.dart';
import '../theme/orbit_colors.dart';
import '../tokens/orbit_tokens.g.dart';

/// Which kind of advice an [AdviceResult] shows.
enum AdviceKind {
  /// A Shanmukha product was advised (F8a).
  product,

  /// Only an active ingredient (salt) was advised: "ask for this name at
  /// the shop" (F8b).
  saltOnly,
}

/// The outcome of an FA's advice: a Shanmukha product with its dose, or a
/// salt name to ask for at the shop.
///
/// The two kinds differ by icon and heading text as well as colour.
class AdviceResult extends StatelessWidget {
  /// A Shanmukha product was found.
  const AdviceResult.product({
    super.key,
    required this.heading,
    required this.name,
    this.secondaryHeading,
    this.dose,
    this.note,
    this.action,
  }) : kind = AdviceKind.product;

  /// No Shanmukha product: show the salt name to ask for.
  const AdviceResult.saltOnly({
    super.key,
    required this.heading,
    required this.name,
    this.secondaryHeading,
    this.dose,
    this.note,
    this.action,
  }) : kind = AdviceKind.saltOnly;

  /// The kind, set by the constructor.
  final AdviceKind kind;

  /// Heading, e.g. "షణ్ముఖ మందు" or "షణ్ముఖ మందు లేదు".
  final String heading;

  /// Optional English heading line, e.g. "Shanmukha product found" or
  /// "Ask for this at the shop".
  final String? secondaryHeading;

  /// Product name ("Sample 5 SG") or salt name ("Mancozeb 75% WP").
  final String name;

  /// Dose, e.g. "ఎకరానికి 80 గ్రా · 80 g per acre".
  final String? dose;

  /// Extra instruction, e.g. "Ask for this name at the shop. If unsure,
  /// call your FA."
  final String? note;

  /// Optional action, e.g. a call-FA `OrbitButton`.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final textTheme = theme.textTheme;
    final product = kind == AdviceKind.product;
    final (Color bg, Color border, Color accent, IconData icon) = product
        ? (
            orbit.success.tint,
            orbit.success.fg,
            orbit.success.strong,
            OrbitIcons.productFound,
          )
        : (
            scheme.surfaceContainerHighest,
            scheme.outline,
            scheme.onSurfaceVariant,
            OrbitIcons.shop,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: OrbitSize.iconLg, color: accent),
                const SizedBox(width: OrbitSpace.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heading,
                        style: textTheme.titleSmall!.copyWith(color: accent),
                      ),
                      if (secondaryHeading != null)
                        Text(
                          secondaryHeading!,
                          style: textTheme.labelSmall!.copyWith(color: accent),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: OrbitSpace.s8),
            Text(name, style: textTheme.titleLarge),
            if (dose != null) Text(dose!, style: textTheme.bodyMedium),
            if (note != null) ...[
              const SizedBox(height: OrbitSpace.s8),
              Text(
                note!,
                style: textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: OrbitSpace.s12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
