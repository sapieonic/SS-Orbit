import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helpline for "call helpline" actions.
///
/// PLACEHOLDER from the wireframe: the real number is an open business
/// decision (mobile/implementation-plan.md, "Open decisions"). The API has no
/// field for it yet; move it to app config when it does.
const helplinePhone = '18001234567';

/// A toll-free number split for reading aloud and on screen:
/// `18001234567` -> `1800 123 4567`. Other shapes are returned unchanged.
String formatHelpline(String phone) {
  if (phone.length == 11 && phone.startsWith('1800')) {
    return '${phone.substring(0, 4)} ${phone.substring(4, 7)} '
        '${phone.substring(7)}';
  }
  return phone;
}

/// Opens the phone dialer or WhatsApp for an FA, a dealer or the helpline.
///
/// Screens reach it through [contactLauncherProvider], so widget tests can
/// record taps instead of opening apps. Use [callPhone], [callHelpline] and
/// [openWhatsApp] from widgets: they add the snack-bar fallback.
class ContactLauncher {
  /// Creates the launcher that uses the phone's apps.
  const ContactLauncher();

  /// Opens the dialer with [phone] filled in (FAR-07: the FA is one tap
  /// away). The farmer still presses call, so nothing is dialled by mistake.
  /// False when the phone has no dialer (tablets, simulators).
  Future<bool> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

  /// Opens a WhatsApp chat with [phone] (FAR-09), with [text] typed in and
  /// ready to send. [phone] is E.164 or 10 digits; wa.me wants digits with
  /// the country code. False when neither WhatsApp nor a browser opened.
  Future<bool> whatsApp(String phone, {String? text}) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '91$digits';
    return launchUrl(
      Uri.https('wa.me', '/$digits', {
        if (text != null && text.isNotEmpty) 'text': text,
      }),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// The [ContactLauncher] screens use. Tests override it with a fake.
final contactLauncherProvider = Provider<ContactLauncher>(
  (ref) => const ContactLauncher(),
);

/// Opens the dialer with [phone]. When the phone has no dialer (a tablet),
/// a snack bar gives the number to dial by hand. [displayPhone] is how the
/// number reads in that message (defaults to [phone]).
Future<void> callPhone(
  BuildContext context,
  WidgetRef ref,
  String phone, {
  String? displayPhone,
}) => launchOrExplain(
  context,
  () => ref.read(contactLauncherProvider).call(phone),
  fallback: context.l10n.farmerFasCallFailed(phone: displayPhone ?? phone),
);

/// [callPhone] for the helpline.
Future<void> callHelpline(BuildContext context, WidgetRef ref) => callPhone(
  context,
  ref,
  helplinePhone,
  displayPhone: formatHelpline(helplinePhone),
);

/// Opens a WhatsApp chat with [phone], [text] pre-filled; a snack bar says
/// so when WhatsApp can't be opened.
Future<void> openWhatsApp(
  BuildContext context,
  WidgetRef ref,
  String phone, {
  String? text,
}) => launchOrExplain(
  context,
  () => ref.read(contactLauncherProvider).whatsApp(phone, text: text),
  fallback: context.l10n.farmerFasWhatsappFailed,
);

/// Runs [launch] and shows [fallback] in a snack bar when nothing opened.
///
/// url_launcher returns false when no app handles the link, and throws a
/// `PlatformException` on some phones; both count as "could not open".
Future<void> launchOrExplain(
  BuildContext context,
  Future<bool> Function() launch, {
  required String fallback,
}) async {
  // Read before the gap: the screen may be gone when the launch returns.
  final messenger = ScaffoldMessenger.of(context);
  bool opened;
  try {
    opened = await launch();
  } on Exception {
    opened = false;
  }
  if (opened) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(fallback)));
}
