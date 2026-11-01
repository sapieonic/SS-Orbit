import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../data/data.dart';
import 'farmer_data.dart';
import 'voice.dart';

/// Localised text for any error a repository or controller throws.
///
/// [ApiError]s go through `describeError` by code (never the server's English
/// message); `Retry-After` becomes the "try again in N seconds" detail.
String errorText(BuildContext context, Object error) =>
    errorTextIn(context.l10n, error);

/// [errorText] in the language of [l10n], for a message worded in another
/// language than the screen's (e.g. just after the farmer switched it).
String errorTextIn(OrbitLocalizations l10n, Object error) {
  if (error is! ApiError) return l10n.errorUnknown;
  return l10n.describeError(
    error.code,
    details: {
      ...error.details,
      if (error.retryAfter case final retry?)
        'retry_after_seconds': retry.inSeconds,
    },
  );
}

/// How every farmer screen reads an [AsyncValue].
extension FreshAsyncValue<T> on AsyncValue<T> {
  /// This value without data loaded for another farmer.
  ///
  /// When a provider reloads for a new scope (another farmer signed in, a
  /// dev-menu reset), Riverpod keeps the old data while it loads, and still
  /// keeps it when that load fails (an [AsyncError] with `hasValue`). That
  /// data is the previous farmer's and must never be shown
  /// ([holdsOtherScopeData]), so this is a plain [AsyncLoading], or an
  /// [AsyncError] without data, then. A pull-to-refresh, `ref.invalidate`,
  /// a refresh that follows another provider (`followFarmerData`), and a
  /// refresh that failed or is being retried keep the data: it is still
  /// this farmer's. Read every farmer-scoped provider in a widget as
  /// `ref.watch(provider).fresh`.
  AsyncValue<T> get fresh {
    if (!holdsOtherScopeData(this)) return this;
    return switch (this) {
      AsyncValue(isLoading: false, :final error?, :final stackTrace?) =>
        AsyncError<T>(error, stackTrace),
      _ => AsyncLoading<T>(),
    };
  }
}

/// Renders an [AsyncValue] the way every farmer screen does: a spinner while
/// loading with nothing to show, the data otherwise, and one card with one
/// action when it failed (offline or error, NFR-03).
///
/// While refreshing, the previous data stays on screen; while reloading for
/// another farmer, or when that failed, it does not ([FreshAsyncValue]).
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Runs the load again (usually `ref.invalidate(provider)`).
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => switch (value.fresh) {
    AsyncValue(hasValue: true, :final T value) => data(value),
    AsyncError(:final error) => ErrorStateCard(error: error, onRetry: onRetry),
    _ => const Center(child: CircularProgressIndicator()),
  };
}

/// The offline or error card for [error], with a Try again action.
///
/// For a session or permission error (401, `device_revoked`, 403) it also
/// offers Sign out, so the farmer is never stuck if the session did not
/// re-route by itself.
class ErrorStateCard extends ConsumerWidget {
  const ErrorStateCard({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  static bool _offersSignOut(Object error) =>
      error is ApiError &&
      (AuthFailureHook.endsSession(error) ||
          error.code == ApiErrorCode.forbidden);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final offline = error is ApiError && (error as ApiError).isNetwork;
    final tryAgain = OrbitButton(
      label: l10n.commonRetry,
      icon: OrbitIcons.refresh,
      variant: OrbitButtonVariant.secondary,
      onPressed: onRetry,
    );
    final retry = _offersSignOut(error)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tryAgain,
              const SizedBox(height: OrbitSpace.s8),
              TextButton(
                onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                child: Text(l10n.commonSignOut),
              ),
            ],
          )
        : tryAgain;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: offline
            ? StateCard(
                icon: OrbitIcons.offline,
                tone: StateCardTone.warning,
                title: l10n.farmerStateOfflineTitle,
                // Only shown with nothing loaded: the "saved details" case is
                // Home's banner over its data.
                subtitle: l10n.farmerStateOfflineNothingSaved,
                action: retry,
                listen: const ScreenListenButton(
                  voiceKey: VoiceKeys.farmerStateOfflineNothingVoice,
                ),
              )
            : StateCard(
                icon: OrbitIcons.error,
                tone: StateCardTone.danger,
                title: l10n.farmerStateErrorTitle,
                subtitle: errorText(context, error),
                action: retry,
                listen: const ScreenListenButton(
                  voiceKey: VoiceKeys.farmerStateErrorVoice,
                ),
              ),
      ),
    );
  }
}

/// The thing a screen was opened for does not exist (an old link, a notice
/// withdrawn, a visit's data changed): one card with a way back.
class NotFoundCard extends StatelessWidget {
  const NotFoundCard({super.key, required this.onBack});

  /// Leaves the screen.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: StateCard(
          icon: OrbitIcons.search,
          title: l10n.errorNotFound,
          action: OrbitButton(
            label: l10n.commonBack,
            icon: OrbitIcons.back,
            variant: OrbitButtonVariant.secondary,
            onPressed: onBack,
          ),
        ),
      ),
    );
  }
}

/// Shows [error] as a snack bar: for actions (send, save) that failed while
/// the screen itself is fine.
void showErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(errorText(context, error))));
}
