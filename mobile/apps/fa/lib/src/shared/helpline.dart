import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../data/data.dart';
import '../device/device.dart';

/// The HO helpline (digits only), [hoHelplineNumber] until the app-config
/// contract carries one (see the TODO there).
final hoHelplineProvider = Provider<String>((ref) => hoHelplineNumber);

/// [digits] spaced the way people read them: "1800 123 4567" for a toll-free
/// number, "98480 12345" for a mobile; anything else as given.
String formatHelpline(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('1800')) {
    return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
  }
  if (d.length == 10) return '${d.substring(0, 5)} ${d.substring(5)}';
  return digits;
}

/// Opens the dialer with the HO helpline; says the number in a snack bar when
/// no dialer opened.
Future<void> callHo(BuildContext context, WidgetRef ref) async {
  final phone = ref.read(hoHelplineProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final text = context.l10n.faAuthCallFailed(phone: formatHelpline(phone));
  final opened = await ref.read(launcherProvider).call(phone);
  if (opened) return;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
