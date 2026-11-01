import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

/// Stands in for just_audio's [AudioPlayer] (which needs platform channels).
/// Tests drive it with [finish], [pauseBySystem] and [fail]; [loadGate]
/// holds a load open to test overlapping requests.
///
/// Its events follow just_audio 0.10: `stop()` reports `playing: false`
/// first, with the processing state unchanged, and only then `idle`.
class FakeAudioPlayer extends Fake implements AudioPlayer {
  final StreamController<PlayerState> _states = StreamController.broadcast();
  final List<String> calls = [];
  Completer<void>? _playing;
  ProcessingState _processing = ProcessingState.idle;

  /// When set, the next setAsset/setFilePath waits for it.
  Completer<void>? loadGate;

  /// When set, the next setAsset/setFilePath throws it.
  Object? loadError;

  /// When set, the next play() fails with it.
  Object? playError;

  bool disposed = false;

  @override
  Stream<PlayerState> get playerStateStream => _states.stream;

  void _emit(bool playing, ProcessingState processing) {
    _processing = processing;
    _states.add(PlayerState(playing, processing));
  }

  Future<Duration?> _load(String what) async {
    calls.add(what);
    _emit(false, ProcessingState.loading);
    final gate = loadGate;
    loadGate = null;
    if (gate != null) await gate.future;
    final error = loadError;
    loadError = null;
    if (error != null) throw error;
    _emit(false, ProcessingState.ready);
    return const Duration(seconds: 5);
  }

  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) => _load('asset:$assetPath');

  @override
  Future<Duration?> setFilePath(
    String filePath, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) => _load('file:$filePath');

  @override
  Future<void> play() {
    calls.add('play');
    final error = playError;
    playError = null;
    if (error != null) return Future.error(error);
    _emit(true, ProcessingState.ready);
    return (_playing = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _emit(false, _processing);
    _emit(false, ProcessingState.idle);
    _endPlay();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _endPlay();
    await _states.close();
  }

  /// The audio plays to its end.
  void finish() {
    _emit(true, ProcessingState.completed);
    _endPlay();
  }

  /// The system pauses playback (headphones unplugged, a phone call),
  /// the way just_audio's own interruption handling does.
  void pauseBySystem() {
    _emit(false, _processing);
    _endPlay();
  }

  /// Playback fails the way just_audio reports it.
  void fail(Object error) => _states.addError(error);

  void _endPlay() {
    final playing = _playing;
    _playing = null;
    if (playing != null && !playing.isCompleted) playing.complete();
  }
}

/// Stands in for audio_session's [AudioSession]: records the configuration
/// and every activation change. With [failing] set, every call throws.
class FakeAudioSession extends Fake implements AudioSession {
  FakeAudioSession({this.failing = false});

  final bool failing;
  final List<AudioSessionConfiguration> configured = [];

  /// The `active` argument of each setActive call, in order.
  final List<bool> activations = [];

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {
    if (failing) throw Exception('no audio session');
    configured.add(configuration);
  }

  @override
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? avAudioSessionSetActiveOptions,
    AndroidAudioFocusGainType? androidAudioFocusGainType,
    AndroidAudioAttributes? androidAudioAttributes,
    bool? androidWillPauseWhenDucked,
    AudioSessionConfiguration fallbackConfiguration =
        const AudioSessionConfiguration.music(),
  }) async {
    if (failing) throw Exception('no audio session');
    activations.add(active);
    return true;
  }
}
