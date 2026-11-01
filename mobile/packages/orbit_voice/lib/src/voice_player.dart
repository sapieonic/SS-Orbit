import 'package:flutter/foundation.dart';

/// What a [VoicePlayer] is doing. Every state except [VoiceIdle] names the
/// [key] it is about: the i18n key for a prompt, or the `cacheKey` (notice ID)
/// for a voice note. A Listen button compares that key with its own to know
/// whether this state is about it.
@immutable
sealed class VoicePlayerState {
  const VoicePlayerState();

  /// The prompt key or cache key this state is about; null when idle.
  String? get key;
}

/// Nothing is playing.
final class VoiceIdle extends VoicePlayerState {
  /// Creates the idle state.
  const VoiceIdle();

  @override
  String? get key => null;

  @override
  bool operator ==(Object other) => other is VoiceIdle;

  @override
  int get hashCode => (VoiceIdle).hashCode;

  @override
  String toString() => 'VoiceIdle()';
}

/// Loading or downloading the audio for [key].
final class VoiceLoading extends VoicePlayerState {
  /// Creates a loading state for [key].
  const VoiceLoading(this.key);

  @override
  final String key;

  @override
  bool operator ==(Object other) => other is VoiceLoading && other.key == key;

  @override
  int get hashCode => Object.hash(VoiceLoading, key);

  @override
  String toString() => 'VoiceLoading($key)';
}

/// Playing the audio for [key].
final class VoicePlaying extends VoicePlayerState {
  /// Creates a playing state for [key].
  const VoicePlaying(this.key);

  @override
  final String key;

  @override
  bool operator ==(Object other) => other is VoicePlaying && other.key == key;

  @override
  int get hashCode => Object.hash(VoicePlaying, key);

  @override
  String toString() => 'VoicePlaying($key)';
}

/// [key] has no recording (not recorded yet, or not a voice key). Not an
/// error: show the Listen button as unavailable.
final class VoiceUnavailable extends VoicePlayerState {
  /// Creates an unavailable state for [key].
  const VoiceUnavailable(this.key);

  @override
  final String key;

  @override
  bool operator ==(Object other) =>
      other is VoiceUnavailable && other.key == key;

  @override
  int get hashCode => Object.hash(VoiceUnavailable, key);

  @override
  String toString() => 'VoiceUnavailable($key)';
}

/// Loading or playing [key] failed (no network, broken file, ...).
final class VoiceError extends VoicePlayerState {
  /// Creates an error state for [key].
  const VoiceError(this.key, this.error);

  @override
  final String key;

  /// What went wrong, for logging. Never shown to the user as is.
  final Object error;

  @override
  bool operator ==(Object other) =>
      other is VoiceError && other.key == key && other.error == error;

  @override
  int get hashCode => Object.hash(VoiceError, key, error);

  @override
  String toString() => 'VoiceError($key, $error)';
}

/// Plays Telugu voice prompts and notice voice notes, one at a time.
///
/// Starting anything stops whatever was playing (without a [completed]
/// event). Play methods never throw: failures end in [VoiceUnavailable] or
/// [VoiceError] on [state].
abstract interface class VoicePlayer {
  /// Current state; listen to it to drive Listen buttons.
  ValueListenable<VoicePlayerState> get state;

  /// The key of each prompt or voice note that played to the very end.
  /// Stopping, or starting something else, does not emit. The farmer app
  /// marks a notice "listened" only on this event.
  Stream<String> get completed;

  /// Plays the recorded prompt for the i18n [key] (a `VoiceKeys` constant).
  /// A key without a bundled recording ends in [VoiceUnavailable].
  Future<void> playPrompt(String key);

  /// Plays a voice note from [url] (a short-lived presigned URL), downloading
  /// it once and caching the file under [cacheKey] (the notice ID). The URL
  /// itself is never cached; a cached file plays offline.
  Future<void> playUrl(Uri url, {required String cacheKey});

  /// Stops playback and returns to [VoiceIdle].
  Future<void> stop();

  /// Deletes every downloaded voice note, e.g. on sign-out so the next user
  /// of the phone cannot play the previous farmer's notices offline. Bundled
  /// prompts are not affected. Does not stop playback; never throws (a file
  /// that cannot be deleted is left for the OS to clear).
  Future<void> clearCache();

  /// Releases the player. It cannot be used afterwards.
  Future<void> dispose();
}
