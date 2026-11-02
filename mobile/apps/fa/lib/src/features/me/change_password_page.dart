import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../../shared/fa_header.dart';
import '../auth/change_password_screen.dart';

/// Me's Change password, a page pushed over Me with A1c's form (current
/// password, the new one twice, the rules). Needs network; back to Me with
/// "Password changed" once saved.
class ChangePasswordPage extends StatelessWidget {
  /// Creates the page.
  const ChangePasswordPage({super.key});

  /// Pushes the page over [context]'s navigator.
  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordPage()));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Column(
        children: [
          FaHeader(
            title: l10n.faMeChangePassword,
            subtitle: l10n.faNewPasswordNeedsNetwork,
            back: true,
            showSync: false,
          ),
          Expanded(
            child: ChangePasswordForm(
              onSaved: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(l10n.faMePasswordSaved)),
                  );
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
