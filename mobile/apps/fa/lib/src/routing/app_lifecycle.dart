import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../local/local.dart';

/// What the app does as it goes to the background and comes back; the app
/// widget forwards the lifecycle here ([FaApp]) and creates it at start.
///
/// * The sync engine's foreground timer runs only while the FA is active
///   and the app is in the foreground.
/// * Coming back runs the heartbeat (`recheck`: removed phone, forced
///   update, server time).
/// * Coming back after more than [autoLockAfter] in the background locks the
///   app (PIN unlock).
final appLifecycleProvider = Provider<AppLifecycle>((ref) {
  final lifecycle = AppLifecycle(ref);
  ref.listen(
    sessionProvider.select((s) => s.phase),
    (_, phase) => lifecycle._phaseChanged(phase),
    fireImmediately: true,
  );
  ref.onDispose(lifecycle._stopEngine);
  return lifecycle;
});

/// See [appLifecycleProvider].
class AppLifecycle {
  /// Creates the controller over [_ref].
  AppLifecycle(this._ref);

  final Ref _ref;
  bool _foreground = true;

  /// The engine whose timer this started, until stopped.
  SyncEngine? _running;
  DateTime? _backgroundSince;

  /// The app went to the background (hidden or paused).
  void onBackground() {
    if (!_foreground) return;
    _foreground = false;
    _backgroundSince = _ref.read(clockProvider).now();
    _stopEngine();
  }

  /// The app is in the foreground again.
  void onForeground() {
    if (_foreground) return;
    _foreground = true;
    final since = _backgroundSince;
    _backgroundSince = null;
    final session = _ref.read(sessionProvider.notifier);
    final now = _ref.read(clockProvider).now();
    if (since != null && now.difference(since) > autoLockAfter) {
      session.lock();
    }
    unawaited(
      session.recheck().catchError((Object e) {
        // Offline or a server error: the next resume tries again.
        debugPrint('recheck on resume failed: $e');
      }),
    );
    _phaseChanged(_ref.read(sessionProvider).phase);
  }

  /// The app widget is gone (the engine dies with the process, or a test
  /// ends): stops the timer until [onForeground].
  void onDetached() {
    _foreground = false;
    _backgroundSince = null;
    _stopEngine();
  }

  void _phaseChanged(SessionPhase phase) {
    if (phase == SessionPhase.active && _foreground) {
      _startEngine();
    } else {
      _stopEngine();
    }
  }

  void _startEngine() {
    if (_running != null) return;
    final engine = _ref.read(syncEngineProvider)..start();
    _running = engine;
  }

  void _stopEngine() {
    _running?.stop();
    _running = null;
  }
}
