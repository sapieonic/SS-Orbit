import 'package:flutter/material.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';
import '../../../shared/farmer_text.dart';
import '../farm_format.dart';

/// How far back a sowing date may go: the oldest open season (the previous
/// one) started at most about a year ago.
const _sowingLookbackDays = 366;

/// Start season, step 1: which season. Options are the open season codes
/// (previous, current, next); today's season is marked.
class SeasonStep extends StatelessWidget {
  /// Creates the season step.
  const SeasonStep({
    super.key,
    required this.codes,
    required this.selected,
    required this.onSelected,
  });

  /// `season_codes` from `GET /v1/farmer/crops`.
  final SeasonCodes codes;

  /// The chosen code.
  final String selected;

  /// Called with the tapped code.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepQuestion(l10n.farmerSeasonStartWhichSeason),
        for (final code in codes.allOpen) ...[
          ChoiceTile(
            icon: OrbitIcons.calendar,
            label: seasonLabel(l10n, code),
            tag: code == codes.current
                ? OrbitTag(
                    label: l10n.farmerSeasonStartCurrent,
                    tone: OrbitTagTone.primary,
                  )
                : null,
            selected: code == selected,
            onTap: () => onSelected(code),
          ),
          const SizedBox(height: OrbitSpace.s8),
        ],
      ],
    );
  }
}

/// A big list of crops, Telugu first. Used for the crop and the previous
/// crop; with [skipLabel] the first option is "Don't know" (null).
class CropStep extends StatelessWidget {
  /// Creates a crop step.
  const CropStep({
    super.key,
    required this.question,
    required this.crops,
    required this.language,
    required this.selected,
    required this.onSelected,
    this.skipLabel,
  });

  /// The step's question.
  final String question;

  /// Active crops.
  final List<FarmerCrop> crops;

  /// The app language.
  final Language language;

  /// The chosen crop ID, or null.
  final String? selected;

  /// Called with the tapped crop ID (null for the skip option).
  final ValueChanged<String?> onSelected;

  /// Label of a leading "Don't know" option; none when null.
  final String? skipLabel;

  @override
  Widget build(BuildContext context) {
    final skip = skipLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepQuestion(question),
        if (skip != null) ...[
          ChoiceTile(
            icon: OrbitIcons.help,
            label: skip,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(height: OrbitSpace.s8),
        ],
        for (final crop in crops) ...[
          ChoiceTile(
            icon: OrbitIcons.crop,
            label: cropName(crop, language),
            secondaryLabel: cropSecondaryName(crop, language),
            selected: crop.id == selected,
            onTap: () => onSelected(crop.id),
          ),
          const SizedBox(height: OrbitSpace.s8),
        ],
      ],
    );
  }
}

/// Start season, step 3: when it was sown. "Not sown yet" or a date from the
/// picker, never in the future.
class SowingStep extends StatelessWidget {
  /// Creates the sowing step.
  const SowingStep({
    super.key,
    required this.date,
    required this.today,
    required this.onChanged,
  });

  /// The chosen sowing day, or null for "not sown yet".
  final LocalDate? date;

  /// Today (IST): the latest day allowed.
  final LocalDate today;

  /// Called with the new choice.
  final ValueChanged<LocalDate?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final initial = date ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: pickerDate(initial),
      currentDate: pickerDate(today),
      firstDate: pickerDate(today.addDays(-_sowingLookbackDays)),
      lastDate: pickerDate(today),
    );
    if (picked != null) onChanged(LocalDate.fromDateTime(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chosen = date;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepQuestion(l10n.farmerSeasonStartSowingDate),
        ChoiceTile(
          icon: OrbitIcons.cropCalendar,
          label: chosen == null
              ? l10n.commonChoose
              : l10n.commonDateFull(date: chosen.toDateTime()),
          secondaryLabel: chosen == null ? null : l10n.commonEdit,
          selected: chosen != null,
          onTap: () => _pick(context),
        ),
        const SizedBox(height: OrbitSpace.s8),
        ChoiceTile(
          icon: OrbitIcons.pending,
          label: l10n.farmerSeasonStartNotSown,
          selected: chosen == null,
          onTap: () => onChanged(null),
        ),
      ],
    );
  }
}
