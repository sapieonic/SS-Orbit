import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens other apps: the dialer, WhatsApp, maps and the Play Store.
///
/// Every method returns false when nothing opened (no app for the link, or
/// url_launcher threw a `PlatformException` on an odd phone), so the screen
/// can show a fallback (e.g. the number to dial by hand). Never throws.
abstract interface class Launcher {
  /// Opens the dialer with [phone] filled in (`tel:`). The FA still presses
  /// call, so nothing is dialled by mistake.
  Future<bool> call(String phone);

  /// Opens a WhatsApp chat with [phone] (`https://wa.me/91XXXXXXXXXX`),
  /// with [text] typed in when given.
  Future<bool> whatsApp(String phone, {String? text});

  /// Opens maps at a plot (`geo:lat,lng?q=lat,lng`, Directions on Farmer
  /// 360).
  Future<bool> directions(double lat, double lng);

  /// Opens the app's store page ([url] from `AppConfig.storeUrl`).
  Future<bool> openStore(String url);
}

/// The links [UrlLauncher] opens, kept apart so tests can check them.
abstract final class LaunchLinks {
  /// `tel:` with the digits (and a leading `+`) of [phone].
  static Uri call(String phone) =>
      Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));

  /// `https://wa.me/<country code + number>`: wa.me wants digits only, so a
  /// 10-digit Indian number gets `91` in front and E.164 loses its `+`.
  static Uri whatsApp(String phone, {String? text}) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '91$digits';
    return Uri.https(
      'wa.me',
      '/$digits',
      text == null || text.isEmpty ? null : {'text': text},
    );
  }

  /// `geo:lat,lng?q=lat,lng`, which drops a pin in Google Maps and most
  /// other map apps.
  static Uri directions(double lat, double lng) {
    final at = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    return Uri.parse('geo:$at?q=$at');
  }
}

/// A [Launcher] on url_launcher.
final class UrlLauncher implements Launcher {
  /// Creates the launcher.
  const UrlLauncher();

  static Future<bool> _open(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    try {
      return await launchUrl(uri, mode: mode);
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> call(String phone) => _open(LaunchLinks.call(phone));

  @override
  Future<bool> whatsApp(String phone, {String? text}) => _open(
    LaunchLinks.whatsApp(phone, text: text),
    mode: LaunchMode.externalApplication,
  );

  @override
  Future<bool> directions(double lat, double lng) => _open(
    LaunchLinks.directions(lat, lng),
    mode: LaunchMode.externalApplication,
  );

  @override
  Future<bool> openStore(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return Future.value(false);
    return _open(uri, mode: LaunchMode.externalApplication);
  }
}

/// The [Launcher] screens use. Widget tests override it with a recorder.
final launcherProvider = Provider<Launcher>((ref) => const UrlLauncher());
