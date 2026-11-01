import 'package:flutter/widgets.dart';

import '../l10n/generated/orbit_localizations.dart';

/// `context.l10n.someKey` instead of `OrbitLocalizations.of(context).someKey`.
extension OrbitL10nContext on BuildContext {
  /// Strings for the current locale. Needs [OrbitLocalizations.delegate] in
  /// the app's `localizationsDelegates`.
  OrbitLocalizations get l10n => OrbitLocalizations.of(this);
}
