import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';
import 'package:orbit_voice/orbit_voice.dart';

import '../data/data.dart';

/// The one voice player for the app. Tests override it with a
/// [SilentVoicePlayer].
final voicePlayerProvider = Provider<VoicePlayer>((ref) {
  final player = JustAudioVoicePlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Drops the cached notice voice notes when the farmer signs out or anyone
/// signs in, so a shared phone doesn't keep the last farmer's audio. The app
/// widget calls this once in its build.
///
/// Every sign-in clears, not only one after a sign-out in this run: the
/// session may have been forgotten without one (the app killed while the
/// session store keeps nothing across runs), and the cache on disk may
/// still hold that farmer's notes. Opening the app on a saved session
/// (leaving `restoring`) is the same farmer as before and keeps them.
void clearVoiceCacheOnFarmerChange(WidgetRef ref) {
  ref.listen(
    sessionProvider.select(
      (s) =>
          (farmerId: s.farmerId, restoring: s.phase == SessionPhase.restoring),
    ),
    (previous, next) {
      if (previous == null || previous.farmerId == next.farmerId) return;
      if (previous.restoring) return;
      final player = ref.read(voicePlayerProvider);
      stopVoice(player);
      unawaited(player.clearCache());
    },
  );
}

/// Stops whatever [player] is playing (a screen's prompt or a notice's voice
/// note) and clears a failure it shows; does nothing when it is idle.
///
/// Leaving a screen calls this (one task per screen): the app shell when the
/// tab changes, [VoiceStopObserver] on every other route change.
void stopVoice(VoicePlayer player) {
  if (player.state.value is VoiceIdle) return;
  unawaited(player.stop());
}

/// Stops the voice ([stopVoice]) whenever a route is pushed, popped,
/// replaced or removed on any navigator of the app (the router passes its
/// observers to the tabs' navigators too). Tab switches don't change routes;
/// the app shell handles those.
class VoiceStopObserver extends NavigatorObserver {
  /// Creates the observer; [player] is read on each route change.
  VoiceStopObserver(this._player);

  final VoicePlayer Function() _player;

  void _stop() => stopVoice(_player());

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _stop();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _stop();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _stop();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stop();
}

/// The Listen button every farmer screen carries (NFR-01): plays the voice
/// prompt recorded for [voiceKey] and stops it on a second tap.
///
/// Wires the [VoicePlayer] state to orbit_ui's presentational [ListenButton].
/// A key with no recording yet shows the muted "unavailable" state.
class ScreenListenButton extends ConsumerWidget {
  const ScreenListenButton({
    super.key,
    required this.voiceKey,
    this.floating = false,
  });

  /// i18n key of the prompt, e.g. `VoiceKeys.farmerHomeVoiceHelp`.
  final String voiceKey;

  /// Dark floating pill instead of the inline button.
  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(voicePlayerProvider);
    final l10n = context.l10n;
    return ValueListenableBuilder<VoicePlayerState>(
      valueListenable: player.state,
      builder: (context, state, _) {
        // A key without a recording is unavailable before anyone taps it.
        final listenState = switch (listenStateFor(state, voiceKey)) {
          ListenState.idle when voiceAsset(voiceKey) == null =>
            ListenState.unavailable,
          final mine => mine,
        };
        final playing = listenState == ListenState.playing;
        // Keep the label short: it sits in narrow header slots next to Telugu
        // titles. "Unavailable" shows as the button's muted look; a tap that
        // finds no recording explains it in a snack bar.
        final label = playing ? l10n.commonStop : l10n.commonListen;
        Future<void> onPressed() async {
          if (playing) return player.stop();
          await player.playPrompt(voiceKey);
          if (player.state.value case VoiceUnavailable(key: final k)
              when k == voiceKey && context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(l10n.commonAudioUnavailable)),
              );
          }
        }

        return floating
            ? ListenButton.floating(
                label: label,
                state: listenState,
                onPressed: onPressed,
              )
            : ListenButton(
                label: label,
                state: listenState,
                onPressed: onPressed,
              );
      },
    );
  }
}

/// What the Listen button for [key] (a prompt key, or a notice ID for its
/// voice note) shows while the player is in [state]. Only the button whose
/// key the state is about changes; the others stay idle. No recording
/// ([VoiceUnavailable]) and a failed download or playback ([VoiceError])
/// both show as unavailable, and a tap tries again.
ListenState listenStateFor(VoicePlayerState state, String key) {
  if (state.key != key) return ListenState.idle;
  return switch (state) {
    VoiceLoading() => ListenState.loading,
    VoicePlaying() => ListenState.playing,
    VoiceUnavailable() || VoiceError() => ListenState.unavailable,
    VoiceIdle() => ListenState.idle,
  };
}
