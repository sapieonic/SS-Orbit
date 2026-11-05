import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../data/data.dart';
import '../local/local.dart';

/// Localised text for any error a repository, the engine, `FaActions` or
/// the session controller throws (see [faActionErrorText]).
String errorText(BuildContext context, Object error) =>
    faActionErrorText(context.l10n, error);

/// The text for an error a screen action got, in the language of [l10n]:
/// a [FaActionError] by its code (`fa.action_error.<code>`), anything else
/// through [errorTextIn].
String faActionErrorText(OrbitLocalizations l10n, Object error) {
  if (error is! FaActionError) return errorTextIn(l10n, error);
  return switch (error.code) {
    FaActionError.noData => l10n.faActionErrorNoData,
    FaActionError.invalidPhone => l10n.faActionErrorInvalidPhone,
    FaActionError.required => l10n.faActionErrorRequired,
    FaActionError.tooLong => l10n.faActionErrorTooLong,
    FaActionError.cannotClear => l10n.faActionErrorCannotClear,
    FaActionError.areaTooSmall => l10n.faActionErrorAreaTooSmall,
    FaActionError.boundaryCrossesItself =>
      l10n.faActionErrorBoundaryCrossesItself,
    FaActionError.seasonActive => l10n.errorActiveSeasonExists,
    FaActionError.outOfRange => l10n.faActionErrorOutOfRange,
    FaActionError.alreadyEnrolled => l10n.faActionErrorAlreadyEnrolled,
    FaActionError.notFound => l10n.faActionErrorNotFound,
    FaActionError.locationRequired => l10n.faActionErrorLocationRequired,
    FaActionError.noSeason => l10n.faActionErrorNoSeason,
    FaActionError.invalidSeasonCode => l10n.faActionErrorInvalidSeasonCode,
    FaActionError.invalidDate => l10n.faActionErrorInvalidDate,
    FaActionError.tooMany => l10n.faActionErrorTooMany,
    FaActionError.proofInvalid => l10n.faActionErrorProofInvalid,
    FaActionError.nothingToChange => l10n.faActionErrorNothingToChange,
    FaActionError.notPlanned => l10n.faActionErrorNotPlanned,
    FaActionError.notEditable => l10n.faActionErrorNotEditable,
    FaActionError.wrongState => l10n.faActionErrorWrongState,
    _ => l10n.errorUnknown,
  };
}

/// Localised text for an [ApiError] (or anything that is not a
/// [FaActionError]), in the language of [l10n]: for a message worded in
/// another language than the screen's (e.g. just after the FA switched it).
///
/// [ApiError]s go through `describeError` by code (never the server's English
/// message); `Retry-After` becomes the "try again in N seconds" detail.
/// Anything else is "unknown".
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

/// Renders an [AsyncValue] the way every FA screen does: a spinner while
/// loading with nothing to show, the data otherwise (also while it
/// refreshes), and one [ErrorStateCard] when it failed with nothing to show.
///
/// Most FA screens read the territory on the phone, which only fails when
/// the phone's storage does; screens that call the server (lookup, alerts
/// history) show its errors here.
class AsyncValueView<T> extends StatelessWidget {
  /// Creates the view.
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
  });

  /// What to show.
  final AsyncValue<T> value;

  /// Builds the loaded data.
  final Widget Function(T data) data;

  /// Runs the load again (usually `ref.invalidate(provider)`).
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => switch (value) {
    AsyncValue(hasValue: true, :final T value) => data(value),
    AsyncError(:final error) => ErrorStateCard(error: error, onRetry: onRetry),
    _ => const Center(child: CircularProgressIndicator()),
  };
}

/// The offline or error card for [error], with a Try again action.
///
/// For a session error (401, `device_revoked`) it also offers Log out, so
/// the FA is never stuck if the session did not re-route by itself.
class ErrorStateCard extends ConsumerWidget {
  /// Creates the card.
  const ErrorStateCard({super.key, required this.error, required this.onRetry});

  /// What failed.
  final Object error;

  /// Tries again.
  final VoidCallback onRetry;

  static bool _offersLogOut(Object error) =>
      error is ApiError && AuthFailureHook.endsSession(error);

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
    final action = _offersLogOut(error)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tryAgain,
              const SizedBox(height: OrbitSpace.s8),
              TextButton(
                onPressed: () => ref.read(sessionProvider.notifier).logout(),
                child: Text(l10n.faCommonLogOut),
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
                title: l10n.faCommonOfflineTitle,
                subtitle: l10n.faCommonOfflineBody,
                action: action,
              )
            : StateCard(
                icon: OrbitIcons.error,
                tone: StateCardTone.danger,
                title: l10n.faCommonErrorTitle,
                subtitle: errorText(context, error),
                action: action,
              ),
      ),
    );
  }
}

/// The thing a screen was opened for does not exist (an old link, a farmer
/// moved to another FA, a visit cancelled): one card with a way back.
class NotFoundCard extends StatelessWidget {
  /// Creates the card.
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

/// Shows [error] as a snack bar ([faActionErrorText]): for actions (save,
/// resolve, look up) that failed while the screen itself is fine.
void showActionError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(errorText(context, error))));
}
