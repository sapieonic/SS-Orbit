import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';

/// [te] and [en] in the app [language]'s order: the first is the main line,
/// the other (when it differs) the sub-line.
({String primary, String? secondary}) bilingualName(
  Language language, {
  String? te,
  required String en,
}) {
  final primary = pickText(language, te: te, en: en);
  final other = language == Language.te ? en : te;
  return (
    primary: primary,
    secondary: other == null || other.isEmpty || other == primary
        ? null
        : other,
  );
}

/// One tappable row in the village picker: a village, mandal or district.
/// Names are never cut; the row grows instead.
class PlaceTile extends StatelessWidget {
  /// Creates a row.
  const PlaceTile({
    super.key,
    required this.icon,
    required this.primary,
    required this.onTap,
    this.secondary,
    this.detail,
  });

  /// Leading icon (decorative).
  final IconData icon;

  /// Name in the app language.
  final String primary;

  /// Name in the other language.
  final String? secondary;

  /// Extra line, e.g. "Serilingampally mandal, Rangareddy district".
  final String? detail;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: OrbitSize.controlXl),
              child: Padding(
                padding: const EdgeInsets.all(OrbitSpace.s12),
                child: Row(
                  children: [
                    Icon(icon, color: scheme.primary),
                    const SizedBox(width: OrbitSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BilingualText(
                            primary,
                            secondary: secondary,
                            primaryStyle: theme.textTheme.titleMedium,
                          ),
                          if (detail case final detail?)
                            Text(
                              detail,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: OrbitSpace.s8),
                    Icon(
                      OrbitIcons.chevronRight,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A village search or browse result: Telugu and English names, then the
/// mandal and district.
class VillageTile extends StatelessWidget {
  /// Creates a row for [village].
  const VillageTile({
    super.key,
    required this.village,
    required this.language,
    required this.onTap,
  });

  /// The village shown.
  final Village village;

  /// The app language (decides which name comes first).
  final Language language;

  /// Called with [village] when tapped.
  final ValueChanged<Village> onTap;

  @override
  Widget build(BuildContext context) {
    final name = bilingualName(language, te: village.nameTe, en: village.name);
    return PlaceTile(
      icon: OrbitIcons.location,
      primary: name.primary,
      secondary: name.secondary,
      detail: villageArea(context, village, language),
      onTap: () => onTap(village),
    );
  }
}

/// "Serilingampally mandal, Rangareddy district" in the app language.
String villageArea(BuildContext context, Village village, Language language) =>
    context.l10n.farmerVillageResultArea(
      mandal: pickText(
        language,
        te: village.mandalNameTe,
        en: village.mandalName,
      ),
      district: pickText(
        language,
        te: village.districtNameTe,
        en: village.districtName,
      ),
    );
