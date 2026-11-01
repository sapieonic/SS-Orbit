import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

/// Shown while the saved session is read at start. The router moves on by
/// itself once the session phase leaves `restoring`.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.commonAppName,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: theme.colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }
}
