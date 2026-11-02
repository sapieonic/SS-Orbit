/// Call, WhatsApp and directions buttons for a farmer: open the app through
/// the `Launcher`, and say so in a snack bar when none opened. The HO
/// helpline is `callHo` in `helpline.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../data/data.dart';
import '../device/device.dart';

/// Opens the dialer for [phone]; a snack bar with the number when no app
/// opened. Returns whether it opened.
Future<bool> callFarmer(
  BuildContext context,
  WidgetRef ref,
  String phone,
) async {
  final text = context.l10n.faCommonCallFailed(
    phone: formatIndianMobile(phone),
  );
  final messenger = ScaffoldMessenger.of(context);
  final opened = await ref.read(launcherProvider).call(phone);
  if (!opened) _snack(messenger, text);
  return opened;
}

/// Opens a WhatsApp chat with [phone]; a snack bar when it did not open.
Future<void> whatsAppFarmer(
  BuildContext context,
  WidgetRef ref,
  String phone,
) async {
  final text = context.l10n.faCommonWhatsappFailed;
  final messenger = ScaffoldMessenger.of(context);
  if (!await ref.read(launcherProvider).whatsApp(phone)) {
    _snack(messenger, text);
  }
}

/// Opens maps at [point]; a snack bar when no maps app opened.
Future<void> directionsTo(
  BuildContext context,
  WidgetRef ref,
  LatLng point,
) async {
  final text = context.l10n.faCommonDirectionsFailed;
  final messenger = ScaffoldMessenger.of(context);
  if (!await ref.read(launcherProvider).directions(point.lat, point.lng)) {
    _snack(messenger, text);
  }
}

void _snack(ScaffoldMessengerState messenger, String text) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
