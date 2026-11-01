import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'data/data.dart';
import 'routing/router.dart';
import 'shared/voice.dart';

/// The farmer app: Telugu first, the locale follows the farmer's language.
class FarmerApp extends ConsumerWidget {
  const FarmerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    clearVoiceCacheOnFarmerChange(ref);
    final language = ref.watch(appLanguageProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.commonAppName,
      theme: OrbitTheme.farmer(),
      locale: Locale(language.wire),
      supportedLocales: OrbitLocalizations.supportedLocales,
      localizationsDelegates: OrbitLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
