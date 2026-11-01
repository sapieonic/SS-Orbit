import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_player.dart';

/// A [VoicePlayer] that plays nothing: every request ends in
/// [VoiceUnavailable]. Use it in tests and widget previews, or where audio is
/// switched off.
class SilentVoicePlayer implements VoicePlayer {
  final ValueNotifier<VoicePlayerState> _state = ValueNotifier(
    const VoiceIdle(),
  );
  final StreamController<String> _completed = StreamController.broadcast();

  @override
  ValueListenable<VoicePlayerState> get state => _state;

  @override
  Stream<String> get completed => _completed.stream;

  @override
  Future<void> playPrompt(String key) async =>
      _state.value = VoiceUnavailable(key);

  @override
  Future<void> playUrl(Uri url, {required String cacheKey}) async =>
      _state.value = VoiceUnavailable(cacheKey);

  @override
  Future<void> stop() async => _state.value = const VoiceIdle();

  /// Nothing is ever downloaded, so there is nothing to delete.
  @override
  Future<void> clearCache() async {}

  @override
  Future<void> dispose() async {
    await _completed.close();
    _state.dispose();
  }
}
