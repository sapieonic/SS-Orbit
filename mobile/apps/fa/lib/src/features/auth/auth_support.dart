/// Providers and helpers the sign-in screens (and Blocked, Me) share: the
/// hand-off between login, the password change and setup,
/// and the FA's area label. The HO helpline is in `shared/helpline.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data.dart';
import '../../local/local.dart';

/// What the login hands to the password change and the password change to
/// setup, in memory only (never stored).
///
/// * [tempPassword]: the temporary password just typed on the login, so A1c
///   does not ask for it again. Gone after a restart: A1c then asks.
/// * [passwordSaved]: A1c saved the new password; the setup's first step
///   says so (the phase moves to setup the moment it is saved).
@immutable
final class AuthHandoff {
  /// Creates a hand-off.
  const AuthHandoff({this.tempPassword, this.passwordSaved = false});

  /// The temporary password typed on the login, or null.
  final String? tempPassword;

  /// The first-login password change just went through.
  final bool passwordSaved;
}

/// The [AuthHandoff] between the sign-in screens.
final authHandoffProvider = NotifierProvider<AuthHandoffNotifier, AuthHandoff>(
  AuthHandoffNotifier.new,
);

/// Holds the [AuthHandoff].
class AuthHandoffNotifier extends Notifier<AuthHandoff> {
  @override
  AuthHandoff build() {
    ref.listen(sessionProvider.select((s) => s.phase), (_, phase) {
      switch (phase) {
        case SessionPhase.mustChangePassword:
          break;
        case SessionPhase.setup:
          // The temporary password is not needed past A1c.
          if (state.tempPassword != null) {
            state = AuthHandoff(passwordSaved: state.passwordSaved);
          }
        case _:
          state = const AuthHandoff();
      }
    });
    return const AuthHandoff();
  }

  /// Keeps the password a login just used (the next screen may be A1c).
  void heldPassword(String? password) =>
      state = AuthHandoff(tempPassword: password);

  /// The first-login password change went through.
  void passwordSaved() => state = const AuthHandoff(passwordSaved: true);

  /// Forgets everything.
  void clear() => state = const AuthHandoff();
}

/// The FA's area as the villages on the phone name it ("Kondapur,
/// Gachibowli"), or null before the first download.
String? areaLabel(Territory? territory, Language language) {
  final villages = territory?.villages ?? const <SnapVillage>[];
  if (villages.isEmpty) return null;
  return villages.map((v) => v.displayName(language)).join(', ');
}

/// The first word of [name] ("Suresh" from "Suresh Kumar").
String firstName(String name) {
  final trimmed = name.trim();
  final space = trimmed.indexOf(' ');
  return space < 0 ? trimmed : trimmed.substring(0, space);
}
