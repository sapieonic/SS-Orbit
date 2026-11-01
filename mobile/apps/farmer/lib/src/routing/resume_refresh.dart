import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';

import '../data/data.dart';
import '../features/advisory/advisory_providers.dart';
import '../features/visits/visits_providers.dart';
import '../shared/farmer_data.dart';

/// Refreshes data when the app comes back to the foreground; the app shell
/// calls [ResumeRefresh.onResume] (and creates it when it starts).
final resumeRefreshProvider = Provider<ResumeRefresh>(ResumeRefresh.new);

/// See [resumeRefreshProvider].
class ResumeRefresh {
  /// Creates the refresher over [_ref].
  ResumeRefresh(this._ref) : _messagesAt = _ref.read(clockProvider).now();

  final Ref _ref;

  /// Messages refresh at most this often, however often the farmer switches
  /// apps.
  static const messagesInterval = Duration(minutes: 5);

  /// When the messages were last refreshed, or this was created (with the
  /// app shell: they were loaded just then).
  DateTime _messagesAt;

  /// Reloads what may have changed while the app was in the background.
  /// Data that was never loaded stays unloaded, and everything refreshes in
  /// place: the old data stays on screen meanwhile.
  ///
  /// * Home when it was loaded on an earlier IST day ("today's" stage, the
  ///   next visit), and the crop list once its season codes' `validUntil`
  ///   has passed.
  /// * The unread badge, the advisory inbox and My visits (new advice, a
  ///   logged visit: there is no push yet), at most once per
  ///   [messagesInterval].
  void onResume() {
    final now = _ref.read(clockProvider).now();
    final today = LocalDate.istOf(now);
    if (_ref.exists(farmerHomeProvider)) {
      final savedAt = _ref.read(homeSavedAtProvider);
      if (savedAt != null && LocalDate.istOf(savedAt) != today) {
        _ref.invalidate(farmerHomeProvider);
      }
    }
    if (_ref.exists(cropsProvider)) {
      final crops = _ref.read(cropsProvider).value;
      if (crops != null && today.isAfter(crops.seasonCodes.validUntil)) {
        _ref.invalidate(cropsProvider);
      }
    }

    if (now.difference(_messagesAt) < messagesInterval) return;
    _messagesAt = now;
    if (_ref.exists(unreadNoticesCountProvider)) {
      _ref.invalidate(unreadNoticesCountProvider);
    }
    if (_ref.exists(noticesControllerProvider)) {
      _ref.invalidate(noticesControllerProvider);
    }
    if (_ref.exists(visitsControllerProvider)) {
      _ref.invalidate(visitsControllerProvider);
    }
  }
}
