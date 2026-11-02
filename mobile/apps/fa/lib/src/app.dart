import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'data/data.dart';
import 'routing/app_lifecycle.dart';
import 'routing/lock_overlay.dart';
import 'routing/router.dart';

/// The FA app: Telugu first (English if the FA picks it), the router driven
/// by the session phase, the PIN screen over the open pages after a lock
/// ([LockOverlay]), and the lifecycle hooks of [AppLifecycle] (sync timer,
/// heartbeat on resume, auto-lock).
class FaApp extends ConsumerStatefulWidget {
  /// Creates the app.
  const FaApp({super.key});

  @override
  ConsumerState<FaApp> createState() => _FaAppState();
}

class _FaAppState extends ConsumerState<FaApp> {
  late final AppLifecycle _lifecycle;
  late final AppLifecycleListener _listener;
  LockAwareBackButtonDispatcher? _backButton;

  @override
  void initState() {
    super.initState();
    final lifecycle = _lifecycle = ref.read(appLifecycleProvider);
    _listener = AppLifecycleListener(
      onHide: lifecycle.onBackground,
      onPause: lifecycle.onBackground,
      onResume: lifecycle.onForeground,
      onDetach: lifecycle.onDetached,
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    _lifecycle.onDetached();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    final router = ref.watch(routerProvider);
    final gate = ref.watch(appGateProvider);
    final backButton = _backButton?.gate == gate
        ? _backButton!
        : _backButton = LockAwareBackButtonDispatcher(gate);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.commonAppName,
      theme: OrbitTheme.fa(),
      locale: Locale(language.wire),
      supportedLocales: OrbitLocalizations.supportedLocales,
      localizationsDelegates: OrbitLocalizations.localizationsDelegates,
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      backButtonDispatcher: backButton,
      builder: (context, child) =>
          LockOverlay(gate: gate, child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
    );
  }
}
