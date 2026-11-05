/// What the three enrolment steps (A4a, A4, A4c) share: the step row,
/// typed plot areas and a few small widgets in the designs' style.
/// Walked-boundary maths is in `local/geo.dart`; the network state is
/// `phoneOnlineProvider`; action errors are `showActionError`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../local/local.dart';
import '../../routing/routes.dart';

/// The step row on every enrolment screen: 1 Farmer, 2 Farm, 3 Crop, with
/// [current] (0-based) highlighted and the steps before it ticked.
class EnrolSteps extends StatelessWidget {
  /// Creates the row.
  const EnrolSteps({super.key, required this.current});

  /// The step shown (0, 1 or 2).
  final int current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StepIndicator(
      labels: [
        l10n.faEnrolStepFarmer,
        l10n.faEnrolStepFarm,
        l10n.faEnrolStepCrop,
      ],
      currentIndex: current,
      semanticLabel: l10n.faEnrolStepsLabel,
      doneLabel: l10n.faEnrolStepDone,
      currentLabel: l10n.faEnrolStepCurrent,
    );
  }
}

/// "Step 2 of 3 · Farm": the header's sub-line for [step] (1-based).
String enrolStepLine(OrbitLocalizations l10n, int step) {
  final name = switch (step) {
    1 => l10n.faEnrolStepFarmer,
    2 => l10n.faEnrolStepFarm,
    _ => l10n.faEnrolStepCrop,
  };
  return l10n.commonDotJoin(
    first: l10n.commonStepOf(step: step, total: 3),
    second: name,
  );
}

/// "Rabi 2026-27" for `rabi-2026-27`; the code itself when it is not one
/// the app knows.
String seasonLabel(OrbitLocalizations l10n, String code) {
  final dash = code.indexOf('-');
  if (dash <= 0 || dash == code.length - 1) return code;
  final kind = l10n.enumLabel('season_kind', code.substring(0, dash));
  if (kind == null) return code;
  return l10n.faEnrolCropSeasonLabel(
    season: kind,
    year: code.substring(dash + 1),
  );
}

// ---------------------------------------------------------------------------
// Plot area.

/// Acres from typed [acres] and [guntas] (40 guntas = 1 acre), or null when
/// either is not a whole number, guntas is 40 or more, or the total is zero.
double? typedAreaAcres(String acres, String guntas) {
  final a = acres.trim().isEmpty ? 0 : int.tryParse(acres.trim());
  final g = guntas.trim().isEmpty ? 0 : int.tryParse(guntas.trim());
  if (a == null || g == null || a < 0 || g < 0 || g >= guntasPerAcre) {
    return null;
  }
  final total = a + guntasToAcres(g);
  return total > 0 ? total : null;
}

// ---------------------------------------------------------------------------
// Widgets.

/// A bold label over a control, as the designs put it (not a floating
/// label, so Telugu at 130 % never clips).
class EnrolFieldLabel extends StatelessWidget {
  /// Creates the label.
  const EnrolFieldLabel(this.text, {super.key});

  /// The label.
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: OrbitSpace.s6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall!
          .copyWith(fontWeight: OrbitFont.weightBold),
    ),
  );
}

/// One option of an [EnrolChoiceChips] group.
@immutable
final class EnrolChoice<T> {
  /// Creates an option.
  const EnrolChoice(this.value, this.label, {this.secondaryLabel});

  /// What picking it means.
  final T value;

  /// Its label, already localised.
  final String label;

  /// A smaller second line (the other language's crop name), or null.
  final String? secondaryLabel;
}

/// Pick-one chips that wrap onto more lines (language, crop, sowing date,
/// previous crop): 48 dp tall, the picked one filled blue, read out as
/// toggle buttons.
class EnrolChoiceChips<T> extends StatelessWidget {
  /// Creates the group.
  const EnrolChoiceChips({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.semanticLabel,
  });

  /// The options.
  final List<EnrolChoice<T>> choices;

  /// The picked value, or null.
  final T? selected;

  /// Called with the tapped value; null disables the group.
  final ValueChanged<T>? onSelected;

  /// What the group is, for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget chip(EnrolChoice<T> c) {
      final on = c.value == selected;
      final fg = on ? scheme.onPrimary : scheme.onSurface;
      final shape = RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
        side: on
            ? BorderSide.none
            : BorderSide(color: scheme.outline, width: 1.5),
      );
      return Semantics(
        button: true,
        toggled: on,
        child: Material(
          color: on ? scheme.primary : scheme.surface,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onSelected == null ? null : () => onSelected!(c.value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: OrbitSize.controlLg,
                minWidth: OrbitSize.controlLg,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OrbitSpace.s16,
                  vertical: OrbitSpace.s6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      c.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: fg,
                        fontWeight: OrbitFont.weightBold,
                        fontSize: 15,
                      ),
                    ),
                    if (c.secondaryLabel case final second?)
                      Text(
                        second,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: on
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
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

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Wrap(
        spacing: OrbitSpace.s8,
        runSpacing: OrbitSpace.s8,
        children: [for (final c in choices) chip(c)],
      ),
    );
  }
}

/// A white rounded card with a thin border: the designs' section box.
class EnrolCard extends StatelessWidget {
  /// Creates the card.
  const EnrolCard({super.key, required this.child, this.tone});

  /// The content.
  final Widget child;

  /// A tinted card (success, warning, danger, info) instead of white.
  final OrbitTone? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = this.tone;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone?.tint ?? scheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
        border: Border.all(
          color: tone?.fg.withValues(alpha: 0.35) ?? scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s12),
        child: child,
      ),
    );
  }
}

/// An icon with a bold title and a body, side by side: the designs' notice
/// inside a tinted [EnrolCard] ("Already registered", "GPS is ±28 m").
class EnrolNotice extends StatelessWidget {
  /// Creates the notice.
  const EnrolNotice({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    required this.tone,
    this.actions = const [],
    this.live = false,
  });

  /// Leading icon.
  final IconData icon;

  /// Bold first line.
  final String title;

  /// Text under it, or null.
  final String? body;

  /// Colours.
  final OrbitTone tone;

  /// Buttons under the text, stacked.
  final List<Widget> actions;

  /// Announce it when it appears (a status that changed).
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: live,
      container: true,
      child: EnrolCard(
        tone: tone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: tone.fg, size: OrbitSize.iconMd),
                const SizedBox(width: OrbitSpace.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall!.copyWith(
                          color: tone.strong,
                          fontWeight: OrbitFont.weightExtrabold,
                        ),
                      ),
                      if (body case final body?) ...[
                        const SizedBox(height: OrbitSpace.s2),
                        Text(
                          body,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: tone.strong,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            for (final a in actions) ...[
              const SizedBox(height: OrbitSpace.s8),
              a,
            ],
          ],
        ),
      ),
    );
  }
}

/// Where "Finish enrolment" takes [farmerId]: step 2 when the farmer has no
/// active plot, step 3 on the first plot without an active season, else
/// null (only consent may be missing: Farmer 360 records it).
String? finishEnrolmentLocation(Territory territory, String farmerId) {
  final plots = territory.plotsOf(farmerId);
  if (plots.isEmpty) return AppRoutes.enrolPlot(farmerId);
  for (final p in plots) {
    if (territory.activeSeason(p.id) == null) {
      return AppRoutes.enrolCrop(farmerId, plotId: p.id);
    }
  }
  return null;
}

/// The territory, for the steps that only read the phone.
AsyncValue<Territory> watchTerritory(WidgetRef ref) =>
    ref.watch(territoryProvider);

/// The scrolling body of an enrolment step. Every part is built at once (a
/// form, not a long list), so a field scrolled away keeps its error line.
class EnrolScroll extends StatelessWidget {
  /// Creates the body.
  const EnrolScroll({super.key, required this.padding, required this.children});

  /// Space around the content.
  final EdgeInsetsGeometry padding;

  /// The parts, top to bottom, full width.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}
