import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/contact.dart';
import '../../shared/farmer_avatar.dart';
import '../../shared/formatters.dart';
import '../../shared/pending_sync_tag.dart';
import 'farmer_presenter.dart';

/// The tag after a farmer's name: "New today" / "New" for a farmer who just
/// joined or still needs enrolment, else the plan (Free, Premium).
class FarmerTag extends StatelessWidget {
  /// Creates the tag for [row] as of [today].
  const FarmerTag({super.key, required this.row, required this.today});

  /// The farmer.
  final FarmerRow row;

  /// Today (IST).
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (row.isNew) {
      final joinedToday = LocalDate.istOf(row.farmer.createdAt) == today;
      return StatusPill(
        label: joinedToday ? l10n.faFarmersTagNewToday : l10n.faFarmersTagNew,
        tone: OrbitStatusTone.success,
      );
    }
    final premium = row.farmer.plan == Plan.premium;
    return OrbitTag(
      label: premium ? l10n.enumFarmerPlanPremium : l10n.enumFarmerPlanFree,
      tone: premium ? OrbitTagTone.highlight : OrbitTagTone.neutral,
      icon: premium ? OrbitIcons.premium : null,
    );
  }
}

/// An outlined 48 dp action under a farmer card (Call, WhatsApp, Finish
/// enrolment). With no [label] it is a square icon button read out as
/// [semanticLabel].
class FarmerActionButton extends StatelessWidget {
  /// Creates the button.
  const FarmerActionButton({
    super.key,
    this.label,
    this.icon,
    this.semanticLabel,
    required this.onPressed,
    this.color,
    this.filled = false,
  }) : assert(label != null || semanticLabel != null, 'needs a label');

  /// Text, or null for an icon-only button.
  final String? label;

  /// Icon before the text.
  final IconData? icon;

  /// Screen reader label of an icon-only button.
  final String? semanticLabel;

  /// Tap; null disables it.
  final VoidCallback? onPressed;

  /// Text, icon and border colour (default: the text colour).
  final Color? color;

  /// Filled with [color] (white text), for the main action.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final base = color ?? scheme.onSurface;
    final fg = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : filled
        ? scheme.onPrimary
        : base;
    final border = !enabled
        ? scheme.outlineVariant
        : filled
        ? base
        : (color ?? scheme.outline);
    final shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.md)),
      side: BorderSide(color: border, width: 1.5),
    );
    final text = label;
    final child = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: OrbitSize.controlLg,
        minWidth: OrbitSize.controlLg,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OrbitSpace.s8,
          vertical: OrbitSpace.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, size: OrbitSize.iconMd, color: fg),
            if (icon != null && text != null)
              const SizedBox(width: OrbitSpace.s6),
            if (text != null)
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: fg,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: text == null ? semanticLabel : null,
      child: Material(
        color: filled && enabled ? base : scheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: text == null ? ExcludeSemantics(child: child) : child,
        ),
      ),
    );
  }
}

/// The farmer's avatar, name, tag, meta line and "not synced" tag: the top
/// of a list card and of the map's selected-farmer card.
class FarmerSummaryLine extends StatelessWidget {
  /// Creates the line for [row].
  const FarmerSummaryLine({
    super.key,
    required this.row,
    required this.today,
    this.chevron = true,
  });

  /// The farmer.
  final FarmerRow row;

  /// Today (IST).
  final LocalDate today;

  /// Shows a chevron at the end (the line opens the farmer).
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final language = contentLanguage(context);
    final meta = farmerMeta(l10n, row, today: today, language: language);
    return Row(
      children: [
        FarmerAvatar.of(row.farmer),
        const SizedBox(width: OrbitSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: OrbitSpace.s6,
                runSpacing: OrbitSpace.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    farmerName(row.farmer, language),
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: OrbitFont.weightExtrabold,
                      fontSize: 17,
                    ),
                  ),
                  FarmerTag(row: row, today: today),
                ],
              ),
              const SizedBox(height: OrbitSpace.s2),
              Text(
                meta.text,
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontSize: 14,
                  color: meta.alert ? orbit.danger.fg : orbit.textMuted,
                  fontWeight: meta.alert ? OrbitFont.weightBold : null,
                ),
              ),
              if (row.pendingSync) ...[
                const SizedBox(height: OrbitSpace.s4),
                const PendingSyncTag(),
              ],
            ],
          ),
        ),
        if (chevron)
          Icon(OrbitIcons.chevronRight, color: scheme.onSurfaceVariant),
      ],
    );
  }
}

/// One farmer in "Farmers near me": tap opens Farmer 360; a farmer who still
/// needs enrolment gets Finish enrolment and Call, everyone else Call,
/// WhatsApp and Directions.
class FarmerCard extends ConsumerWidget {
  /// Creates the card for [row].
  const FarmerCard({super.key, required this.row, required this.today});

  /// The farmer.
  final FarmerRow row;

  /// Today (IST).
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final orbit = OrbitColors.of(context);
    final farmer = row.farmer;
    final finish = finishEnrolmentRoute(row);
    final location = row.location;
    final call = FarmerActionButton(
      label: l10n.commonCall,
      icon: OrbitIcons.phone,
      onPressed: () => callFarmer(context, ref, farmer.phone),
    );
    final actions = finish != null
        ? [
            Expanded(
              flex: 3,
              child: FarmerActionButton(
                label: l10n.faFarmersActionFinishEnrolment,
                color: orbit.success.fg,
                filled: true,
                onPressed: () => openFrom(context, finish),
              ),
            ),
            const SizedBox(width: OrbitSpace.s8),
            Expanded(flex: 2, child: call),
          ]
        : [
            Expanded(child: call),
            const SizedBox(width: OrbitSpace.s8),
            Expanded(
              child: FarmerActionButton(
                label: l10n.commonWhatsapp,
                icon: OrbitIcons.whatsApp,
                onPressed: () => whatsAppFarmer(context, ref, farmer.phone),
              ),
            ),
            const SizedBox(width: OrbitSpace.s8),
            FarmerActionButton(
              icon: OrbitIcons.directions,
              semanticLabel: l10n.faFarmersActionDirections,
              onPressed: location == null
                  ? null
                  : () => directionsTo(context, ref, location),
            ),
          ];
    const radius = BorderRadius.all(Radius.circular(OrbitRadius.lg));
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: finish != null ? orbit.success.fg : scheme.outlineVariant,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: const BorderRadius.all(
                Radius.circular(OrbitRadius.md),
              ),
              onTap: () => openFrom(context, AppRoutes.farmer(farmer.id)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: OrbitSize.controlLg,
                ),
                child: FarmerSummaryLine(row: row, today: today),
              ),
            ),
            const SizedBox(height: OrbitSpace.s10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
