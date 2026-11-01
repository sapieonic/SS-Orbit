import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../tokens/orbit_tokens.g.dart';

/// The fonts bundled in orbit_ui.
///
/// The theme already sets these on every text style, so apps never need them.
/// They are public for the rare custom [TextStyle] built outside the theme:
/// `TextStyle(fontFamily: OrbitFonts.latin, fontFamilyFallback:
/// OrbitFonts.fallback, package: OrbitFonts.package)`.
abstract final class OrbitFonts {
  /// The package that ships the font files.
  static const String package = 'orbit_ui';

  /// Figtree: Latin text and all digits (including the rupee sign).
  static const String latin = OrbitFont.familyLatin;

  /// Noto Sans Telugu: every Telugu glyph, picked by font fallback.
  static const String telugu = OrbitFont.familyTelugu;

  /// Fallback list used with [latin] as the primary family.
  static const List<String> fallback = [telugu];

  static bool _licensesRegistered = false;

  /// Adds the SIL OFL texts of the bundled fonts to Flutter's
  /// [LicenseRegistry], so they appear on the app's licence page. Call once
  /// from `main()`; later calls do nothing.
  static void registerLicenses() {
    if (_licensesRegistered) return;
    _licensesRegistered = true;
    LicenseRegistry.addLicense(() async* {
      for (final (name, file) in const [
        ('Figtree', 'OFL-Figtree.txt'),
        ('Noto Sans Telugu', 'OFL-NotoSansTelugu.txt'),
      ]) {
        final text = await rootBundle.loadString(
          'packages/$package/fonts/$file',
        );
        yield LicenseEntryWithLineBreaks([name], text);
      }
    });
  }
}
