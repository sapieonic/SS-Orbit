/// Display helpers only the My farm screens need: season codes, phone
/// numbers, avatar initials. Plot, crop and area names shared with other
/// screens are in `shared/farmer_text.dart`.
library;

import 'package:flutter/widgets.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../../data/data.dart';
import '../../shared/farmer_text.dart';

/// A season code (`kharif-2026`, `rabi-2026-27`) as the farmer says it:
/// "ఖరీఫ్ 2026", "రబీ 2026-27". An unknown kind keeps the raw code.
String seasonLabel(OrbitLocalizations l10n, String code) {
  final dash = code.indexOf('-');
  if (dash <= 0 || dash == code.length - 1) return code;
  final kind = l10n.enumLabel('season_kind', code.substring(0, dash));
  if (kind == null) return code;
  return l10n.farmerSeasonStartSeasonLabel(
    season: kind,
    year: code.substring(dash + 1),
  );
}

/// The other language's crop name, as an optional second line; null when it
/// is missing or the same.
String? cropSecondaryName(FarmerCrop crop, Language language) {
  final other = pickText(
    language == Language.te ? Language.en : Language.te,
    te: crop.nameTe,
    en: crop.name,
  );
  return other.isEmpty || other == cropName(crop, language) ? null : other;
}

/// An E.164 Indian mobile (`+919848012345`) as farmers write it:
/// "98480 12345". Anything else is returned unchanged.
String displayPhone(String e164) {
  final digits = e164.replaceAll(RegExp(r'\D'), '');
  final local = digits.length == 12 && digits.startsWith('91')
      ? digits.substring(2)
      : digits;
  if (local.length != 10) return e164;
  return '${local.substring(0, 5)} ${local.substring(5)}';
}

/// Up to two initials for the avatar: from the English name when there is
/// one ("Ravi K" -> "RK"), otherwise the first letter of the Telugu name.
String initialsFor(Farmer farmer) {
  if (nameInitials(farmer.name) case final initials?) return initials;
  final te = farmer.nameTe?.trim() ?? '';
  return te.isEmpty ? '' : te.characters.first;
}

/// Builds a date picker [DateTime] (local midnight) from an IST calendar day.
DateTime pickerDate(LocalDate date) =>
    DateTime(date.year, date.month, date.day);
