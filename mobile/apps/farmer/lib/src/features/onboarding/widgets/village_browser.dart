import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';
import '../../../shared/async_view.dart';
import '../../../shared/call_buttons.dart';
import '../onboarding_providers.dart';
import 'place_tile.dart';

/// The village picker's browse fallback: district, then mandal, then
/// village. The parent keeps the choices so its header and Back follow the
/// step; this widget only draws the list for the current step.
class VillageBrowser extends ConsumerWidget {
  /// Creates the browser at the step implied by [district] and [mandal].
  const VillageBrowser({
    super.key,
    required this.district,
    required this.mandal,
    required this.onDistrict,
    required this.onMandal,
    required this.onVillage,
  });

  /// The chosen district, or null on the district step.
  final TreeDistrict? district;

  /// The chosen mandal, or null before the village step.
  final TreeMandal? mandal;

  /// A district was tapped.
  final ValueChanged<TreeDistrict> onDistrict;

  /// A mandal was tapped.
  final ValueChanged<TreeMandal> onMandal;

  /// A village was tapped.
  final ValueChanged<Village> onVillage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    final l10n = context.l10n;

    if (mandal case final mandal?) {
      final provider = mandalVillagesProvider(mandal.id);
      return AsyncValueView(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (villages) => villages.isEmpty
            ? _EmptyCard(
                l10n.farmerVillageNoResults(
                  query: pickText(language, te: mandal.nameTe, en: mandal.name),
                ),
              )
            : _PlaceList([
                for (final v in villages)
                  VillageTile(village: v, language: language, onTap: onVillage),
              ]),
      );
    }

    if (district case final district?) {
      return district.mandals.isEmpty
          ? _EmptyCard(
              l10n.farmerVillageNoResults(
                query: pickText(
                  language,
                  te: district.nameTe,
                  en: district.name,
                ),
              ),
            )
          : _PlaceList([
              for (final m in district.mandals)
                _areaTile(language, m.nameTe, m.name, () => onMandal(m)),
            ]);
    }

    return AsyncValueView(
      value: ref.watch(geoTreeProvider),
      onRetry: () => ref.invalidate(geoTreeProvider),
      data: (tree) => tree.districts.isEmpty
          ? _EmptyCard(l10n.farmerStateErrorTitle)
          : _PlaceList([
              for (final d in tree.districts)
                _areaTile(language, d.nameTe, d.name, () => onDistrict(d)),
            ]),
    );
  }

  static Widget _areaTile(
    Language language,
    String? te,
    String en,
    VoidCallback onTap,
  ) {
    final name = bilingualName(language, te: te, en: en);
    return PlaceTile(
      icon: OrbitIcons.location,
      primary: name.primary,
      secondary: name.secondary,
      onTap: onTap,
    );
  }
}

class _PlaceList extends StatelessWidget {
  const _PlaceList(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(OrbitSpace.s16),
    itemCount: children.length,
    separatorBuilder: (_, _) => const SizedBox(height: OrbitSpace.s8),
    itemBuilder: (_, i) => children[i],
  );
}

/// Nothing to browse here (a mandal without villages): the helpline can add
/// the village.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(OrbitSpace.s16),
    children: [
      StateCard(
        icon: OrbitIcons.location,
        title: title,
        action: const CallHelplineButton(),
      ),
    ],
  );
}
