import 'package:flutter/material.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'auth_widgets.dart';

/// Shown while the saved session is read at start: the brand mark only. The
/// read needs no network and takes a moment, so there is no spinner (it
/// would only flash); the router moves on as soon as the session phase
/// leaves `restoring`.
class SplashScreen extends StatelessWidget {
  /// Creates the screen.
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlainPage(
    child: Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(OrbitSpace.s24),
        child: BrandMark(),
      ),
    ),
  );
}
