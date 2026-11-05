import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../features/auth/unlock_screen.dart';
import 'router.dart';

/// Covers the app's pages with the PIN screen while [gate] shows the lock
/// over them ([AppGate.lockOverlay]); otherwise just [child].
///
/// Under the lock the pages stay built (an in-progress visit log keeps its
/// photos and answers) but are not painted, cannot be touched, focused or
/// read by a screen reader, and their animations stop. Back is held by
/// [LockAwareBackButtonDispatcher], so it cannot pop a page under the lock.
/// Used as `MaterialApp.router(builder:)`, above the navigator.
class LockOverlay extends StatelessWidget {
  /// Creates the overlay over [child] (the router).
  const LockOverlay({super.key, required this.gate, required this.child});

  /// What decides whether the lock shows.
  final AppGate gate;

  /// The app's pages (the router's navigator).
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: gate,
    child: child,
    builder: (context, pages) {
      final locked = gate.lockOverlay;
      return Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: locked,
            child: TickerMode(
              enabled: !locked,
              child: Offstage(offstage: locked, child: pages),
            ),
          ),
          if (locked)
            // Its own overlay, for anything the PIN screen floats (no
            // navigator above it here).
            Overlay(
              initialEntries: [
                OverlayEntry(builder: (_) => const UnlockScreen()),
              ],
            ),
        ],
      );
    },
  );
}

/// The app's back button dispatcher: swallows back while the lock overlay
/// shows (the PIN screen has nothing to go back to, and a page under it
/// must not be popped); otherwise back goes to the router as usual.
class LockAwareBackButtonDispatcher extends RootBackButtonDispatcher {
  /// Creates the dispatcher over [gate].
  LockAwareBackButtonDispatcher(this.gate);

  /// What says whether the lock shows.
  final AppGate gate;

  @override
  Future<bool> invokeCallback(Future<bool> defaultValue) {
    if (gate.lockOverlay) return SynchronousFuture(true);
    return super.invokeCallback(defaultValue);
  }
}
