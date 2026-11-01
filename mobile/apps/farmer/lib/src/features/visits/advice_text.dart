import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';

/// What one issue's advice amounts to, decided only from the data.
enum AdviceType {
  /// A Shanmukha product with its dose (F8a).
  product,

  /// Only a salt (active ingredient) to ask for at the shop (F8b).
  saltOnly,

  /// The FA has not given advice yet: "Your FA will follow up".
  pending,
}

/// Classifies [advice]. A product needs a product name; a salt needs a salt
/// name. Anything else (including data the server has not filled in) is
/// treated as pending, so the screen never invents a recommendation.
AdviceType adviceTypeOf(FarmerAdvice advice) {
  if (advice.advicePending) return AdviceType.pending;
  final hasProduct = _present(advice.productName, advice.productNameTe);
  final hasSalt = _present(advice.saltName, advice.saltNameTe);
  if (!advice.saltOnly && hasProduct) return AdviceType.product;
  if (hasSalt) return AdviceType.saltOnly;
  return AdviceType.pending;
}

bool _present(String? a, String? b) =>
    (a != null && a.isNotEmpty) || (b != null && b.isNotEmpty);

/// The issue name in [language], the other language as a second line when
/// it differs (wireframe: "గులాబీ రంగు పురుగు / Pink bollworm").
(String, String?) issueNames(
  OrbitLocalizations l10n,
  Language language,
  FarmerAdvice advice,
) => bilingual(
  language,
  te: advice.issueNameTe,
  en: advice.issueName,
  fallback: l10n.commonUnknown,
);

/// Text in [language] first, plus the other language when it is present and
/// different; [fallback] when neither is set.
(String, String?) bilingual(
  Language language, {
  required String? te,
  required String? en,
  required String fallback,
}) {
  final first = pickText(language, te: te, en: en);
  if (first.isEmpty) return (fallback, null);
  final other = language == Language.te ? en : te;
  return (
    first,
    other == null || other.isEmpty || other == first ? null : other,
  );
}

/// A product or salt name for the shop: the farmer's language first and the
/// other spelling on a second line, because the pack and the shopkeeper use
/// the English name.
String shopName(Language language, {String? te, String? en}) {
  final (first, second) = bilingual(language, te: te, en: en, fallback: '');
  return second == null ? first : '$first\n$second';
}

/// The dose in [language].
String? doseText(Language language, FarmerAdvice advice) {
  final dose = pickText(language, te: advice.doseTe, en: advice.dose);
  return dose.isEmpty ? null : dose;
}

/// The orbit_ui severity for [severity]; null when this app version does
/// not know the value (the pill is then left out).
OrbitSeverity? orbitSeverity(Severity severity) => switch (severity) {
  Severity.low => OrbitSeverity.low,
  Severity.moderate => OrbitSeverity.moderate,
  Severity.high => OrbitSeverity.high,
  Severity.unknown => null,
};
