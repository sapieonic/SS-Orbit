// Small pieces the visit screens share (calendar, plan a visit, visit log):
// pick-one chips, step headings, the header's Add pill, the notice strip,
// labels for slots, issue types and purposes.

import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';

/// Shows [message] as a snack bar.
void showVisitSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Morning, afternoon or any time, in the UI language.
String slotLabel(OrbitLocalizations l10n, VisitSlot slot) => switch (slot) {
  VisitSlot.morning => l10n.enumPlannedSlotMorning,
  VisitSlot.afternoon => l10n.enumPlannedSlotAfternoon,
  _ => l10n.enumPlannedSlotAny,
};

/// Pest, disease or deficiency, in the UI language.
String issueTypeLabel(OrbitLocalizations l10n, IssueType type) =>
    switch (type) {
      IssueType.pest => l10n.faVisitLogTypePest,
      IssueType.disease => l10n.faVisitLogTypeDisease,
      IssueType.deficiency => l10n.faVisitLogTypeDeficiency,
      IssueType.unknown => l10n.commonUnknown,
    };

/// How bad an issue is, in [l10n]'s language.
String severityLabel(OrbitLocalizations l10n, Severity severity) =>
    switch (severity) {
      Severity.low => l10n.enumSeverityLow,
      Severity.moderate => l10n.enumSeverityModerate,
      Severity.high => l10n.enumSeverityHigh,
      Severity.unknown => l10n.commonUnknown,
    };

/// The purposes offered as chips on Plan a visit.
///
/// `PlanVisitPayload.purpose` is free text that HO reads too, so a chip is
/// saved as its English [wire] text ("Stage check", as the seed data has
/// it) and shown in the UI language wherever it matches; text the FA typed
/// is shown as typed.
enum VisitPurpose {
  /// Look at the crop stage.
  stageCheck('Stage check'),

  /// Check on a pest found before.
  pestFollowUp('Pest follow-up'),

  /// First visit to a farmer.
  firstVisit('First visit'),

  /// Take a soil sample.
  soilSample('Soil sample'),

  /// See whether the advice worked.
  adviceFollowUp('Advice follow-up');

  const VisitPurpose(this.wire);

  /// The text saved in the plan.
  final String wire;

  /// The chip label in the UI language.
  String label(OrbitLocalizations l10n) => switch (this) {
    stageCheck => l10n.faPlanVisitPurposeStageCheck,
    pestFollowUp => l10n.faPlanVisitPurposePestFollowUp,
    firstVisit => l10n.faPlanVisitPurposeFirstVisit,
    soilSample => l10n.faPlanVisitPurposeSoilSample,
    adviceFollowUp => l10n.faPlanVisitPurposeAdviceFollowUp,
  };

  /// The purpose saved as [text], or null for free text.
  static VisitPurpose? match(String? text) {
    final t = text?.trim().toLowerCase();
    if (t == null || t.isEmpty) return null;
    for (final p in values) {
      if (p.wire.toLowerCase() == t) return p;
    }
    return null;
  }
}

/// A visit's purpose as shown: a known one in the UI language, else the
/// saved text; null when there is none.
String? purposeText(OrbitLocalizations l10n, String? purpose) {
  final known = VisitPurpose.match(purpose);
  if (known != null) return known.label(l10n);
  final t = purpose?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// A pick-one chip: 48 dp tall, pill shaped, filled with the primary colour
/// when [selected]. Reads as a selected button to screen readers.
class OptionChip extends StatelessWidget {
  /// Creates a chip.
  const OptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.semanticLabel,
  });

  /// The text.
  final String label;

  /// Picked.
  final bool selected;

  /// Picks it; null disables the chip.
  final VoidCallback? onTap;

  /// An optional leading icon.
  final IconData? icon;

  /// What screen readers say instead of [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final fg = selected
        ? scheme.onPrimary
        : enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outline,
        width: 1.5,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: OrbitSize.controlLg,
              minWidth: OrbitSize.controlLg,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: OrbitSpace.s6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: OrbitSize.iconMd, color: fg),
                    const SizedBox(width: OrbitSpace.s6),
                  ],
                  Flexible(
                    child: Text(
                      label,
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
          ),
        ),
      ),
    );
  }
}

/// [OptionChip]s that wrap onto more lines.
class OptionChipWrap extends StatelessWidget {
  /// Creates the group.
  const OptionChipWrap({super.key, required this.children, this.label});

  /// The chips.
  final List<Widget> children;

  /// What the group is, for screen readers.
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: Wrap(
      spacing: OrbitSpace.s6,
      runSpacing: OrbitSpace.s6,
      children: children,
    ),
  );
}

/// A step or section heading ("1 · Photos · 3 photos"): bold [title] and an
/// optional lighter [detail] (green when [detailIsGood]).
class StepHeading extends StatelessWidget {
  /// Creates the heading.
  const StepHeading(
    this.title, {
    super.key,
    this.detail,
    this.detailIsGood = false,
  });

  /// The heading.
  final String title;

  /// After the heading, e.g. "3 photos", "suggested by master".
  final String? detail;

  /// Shows [detail] in the success colour.
  final bool detailIsGood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final style = theme.textTheme.titleSmall!.copyWith(
      fontSize: 14,
      fontWeight: OrbitFont.weightExtrabold,
      color: theme.colorScheme.onSurface,
    );
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          text: title,
          children: [
            if (detail case final detail?)
              TextSpan(
                text: ' · $detail',
                style: style.copyWith(
                  fontWeight: FontWeight.w600,
                  color: detailIsGood ? orbit.success.strong : orbit.textMuted,
                ),
              ),
          ],
        ),
        style: style,
      ),
    );
  }
}

/// A white pill button for the blue header (the calendar's "+ Add").
class HeaderPillButton extends StatelessWidget {
  /// Creates the button.
  const HeaderPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });

  /// The text.
  final String label;

  /// Leading icon.
  final IconData icon;

  /// Tap handler.
  final VoidCallback onPressed;

  /// What screen readers say instead of [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const shape = StadiumBorder();
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: OrbitSize.controlLg,
              minWidth: OrbitSize.controlLg,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: OrbitSize.iconMd, color: scheme.primary),
                  const SizedBox(width: OrbitSpace.s6),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: scheme.primary,
                      fontSize: 15,
                      fontWeight: OrbitFont.weightExtrabold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A green "it worked" line with a close button (the calendar's notice).
class NoticeStrip extends StatelessWidget {
  /// Creates the strip.
  const NoticeStrip({super.key, required this.message, this.onClose});

  /// The text.
  final String message;

  /// Closes it; no close button when null.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final tone = orbit.success;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.tint,
          border: Border.all(color: tone.strong, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            OrbitSpace.s12,
            OrbitSpace.s4,
            onClose == null ? OrbitSpace.s12 : OrbitSpace.s4,
            OrbitSpace.s4,
          ),
          child: Row(
            children: [
              Icon(OrbitIcons.success, color: tone.strong),
              const SizedBox(width: OrbitSpace.s10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: OrbitSpace.s8),
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: tone.fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(OrbitIcons.close),
                  color: tone.strong,
                  tooltip: context.l10n.commonClose,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tone-coloured card with an icon badge, a bold line and a second line
/// (the visit log's product / salt-only / no-rule cards).
class ToneNote extends StatelessWidget {
  /// Creates the card.
  const ToneNote({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.body,
  });

  /// Colours.
  final OrbitTone tone;

  /// The badge icon.
  final IconData icon;

  /// Bold first line.
  final String title;

  /// Second line.
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.tint,
          border: Border.all(color: tone.strong, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OrbitSpace.s12,
            vertical: OrbitSpace.s10,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tone.strong,
                  borderRadius: const BorderRadius.all(Radius.circular(9)),
                ),
                child: SizedBox.square(
                  dimension: 30,
                  child: Icon(
                    icon,
                    size: OrbitSize.iconMd,
                    color: theme.colorScheme.surface,
                  ),
                ),
              ),
              const SizedBox(width: OrbitSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: tone.fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (body case final body?)
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: tone.fg,
                        ),
                      ),
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
