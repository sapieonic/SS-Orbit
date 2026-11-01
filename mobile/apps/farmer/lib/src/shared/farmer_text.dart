/// Text helpers every farmer screen uses for server data (plot, crop and
/// people names), so the same plot or crop reads the same on Home, My
/// visits, the crop calendar and My farm.
library;

import 'package:flutter/widgets.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../data/data.dart';

/// The language to pick server text in (`name_te` or `name`): the one the
/// screen is shown in (the app locale, which follows the farmer's choice),
/// so names never mix with the UI language.
Language contentLanguage(BuildContext context) =>
    Language.fromWire(Localizations.localeOf(context).languageCode);

/// Joins the non-empty [parts] with " · " (`common.dot_join`), e.g.
/// "కొండాపూర్ · పత్తి · 2 ఎ. 20 గుం.". Empty when every part is empty.
String dotJoin(OrbitLocalizations l10n, Iterable<String?> parts) {
  final present = [
    for (final p in parts)
      if (p != null && p.trim().isNotEmpty) p,
  ];
  if (present.isEmpty) return '';
  return present.reduce(
    (first, second) => l10n.commonDotJoin(first: first, second: second),
  );
}

/// Up to two capital letters for an avatar, from an English name
/// ("Suresh K" -> "SK"). Null when [name] is empty. Telugu names don't split
/// cleanly into initials, so pass the English one.
String? nameInitials(String? name) {
  final words = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  if (words.isEmpty) return null;
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

final _defaultPlotLabel = RegExp(r'^Plot (\d+)$');

/// The plot's name in the app language. The server's default label
/// ("Plot 1") becomes `farmer.farm.plot` ("పొలం 1"); a label the farmer or
/// FA typed is shown as typed.
String plotName(OrbitLocalizations l10n, Plot plot) {
  final label = plot.label.trim();
  final number = switch (_defaultPlotLabel.firstMatch(label)) {
    final match? => int.tryParse(match.group(1)!),
    null => null,
  };
  return number == null ? label : l10n.farmerFarmPlot(number: number);
}

/// "పొలం 1 · పత్తి": the plot's name and the crop of its active season, when
/// it has one and [crops] knows it.
String plotAndCrop(
  OrbitLocalizations l10n,
  HomePlot plot,
  FarmerCropList? crops,
  Language language,
) => dotJoin(l10n, [
  plotName(l10n, plot.plot),
  if (plot.activeSeason case final season?)
    cropNameById(crops, season.cropId, language),
]);

/// An area in acres as "2 ఎ. 20 గుం.".
String plotArea(OrbitLocalizations l10n, double acres) {
  final area = AcresGuntas.fromAcres(acres);
  return l10n.farmerHomeArea(acres: area.acres, guntas: area.guntas);
}

/// The crop's name in [language] (falling back to the other spelling).
String cropName(FarmerCrop crop, Language language) =>
    pickText(language, te: crop.nameTe, en: crop.name);

/// The name of crop [cropId] in [language], or null when [crops] (not
/// loaded yet) doesn't have it.
String? cropNameById(FarmerCropList? crops, String cropId, Language language) =>
    switch (crops?.byId(cropId)) {
      final crop? => cropName(crop, language),
      null => null,
    };

/// Longest name the API takes (`name` and `name_te`, 1-100 characters,
/// counted in code points: `contracts/openapi/farmers.yaml`).
const farmerNameMaxLength = 100;

/// True when [text] has any letter of the Telugu block (U+0C00 to U+0C7F).
bool hasTelugu(String text) =>
    text.runes.any((r) => r >= 0x0C00 && r <= 0x0C7F);

/// The `name` / `name_te` pair to save for a name the farmer typed at
/// sign-up (complete-profile); My farm's Change name uses [renamedProfile].
///
/// Spaces are tidied. The typed name is always `name` (the FA app, the
/// English screens and the WhatsApp greeting read it); a name typed in Telugu
/// is also `name_te`, which the farmer app shows first. A name typed in
/// English has no `name_te`.
({String name, String? nameTe}) profileName(String typed) {
  final name = typed.trim().replaceAll(RegExp(r'\s+'), ' ');
  return (name: name, nameTe: hasTelugu(name) ? name : null);
}

/// The `name` / `name_te` pair to save when the farmer changes their name on
/// My farm (`PATCH /v1/farmer/me`), typed over their name as shown in
/// [language]; [nameTe] is their Telugu spelling now.
///
/// Like [profileName], except for a name typed without Telugu letters over
/// the Telugu spelling (the app in Telugu, and the farmer has one): that is
/// saved as `name_te` too. The API cannot clear `name_te` (no null or empty
/// value), and the Telugu screens show it first, so keeping it would keep
/// showing the old name after the farmer replaced it. In English the field
/// shows `name`, and the Telugu spelling stays.
({String name, String? nameTe}) renamedProfile(
  String typed, {
  required Language language,
  required String? nameTe,
}) {
  final named = profileName(typed);
  final replacesTelugu =
      language == Language.te && (nameTe?.isNotEmpty ?? false);
  if (named.nameTe != null || !replacesTelugu) return named;
  return (name: named.name, nameTe: named.name);
}
