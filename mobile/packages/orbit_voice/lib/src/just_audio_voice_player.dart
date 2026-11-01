import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import 'notice_audio_cache.dart';
import 'voice_player.dart';

/// [VoicePlayer] backed by just_audio (ExoPlayer on Android, AVPlayer on
/// iOS). Prompts are AAC `.m4a` assets bundled in this package; both
/// platforms play them without extra set-up.
///
/// Audio focus: each prompt asks other apps to duck (lower their volume)
/// while it plays and gives focus back when it ends, is stopped or fails, so
/// the farmer's radio or music comes back by itself. See
/// [audioSessionConfiguration].
///
/// When the system pauses playback on its own (headphones unplugged, a call
/// or another app taking audio focus), the player goes back to [VoiceIdle]
/// without a [completed] event; tapping Listen plays from the start.
class JustAudioVoicePlayer implements VoicePlayer {
  /// Creates a player.
  ///
  /// [assetFor] maps an i18n key to its bundled asset, or null when there is
  /// no recording; it defaults to orbit_l10n's [voiceAsset]. [player],
  /// [cache] and [audioSession] are for tests.
  JustAudioVoicePlayer({
    AudioPlayer? player,
    NoticeAudioCache? cache,
    Future<AudioSession> Function()? audioSession,
    this._assetFor = voiceAsset,
  }) : _player = player ?? AudioPlayer(),
       _cache = cache ?? NoticeAudioCache(),
       _audioSession = audioSession ?? (() => AudioSession.instance) {
    _subscription = _player.playerStateStream.listen(
      _onPlayerState,
      onError: _onPlayerError,
    );
  }

  /// The audio session for short spoken prompts.
  ///
  /// - Android: transient focus that lets other apps duck
  ///   ([AndroidAudioFocusGainType.gainTransientMayDuck]), speech content.
  ///   If another app ducks us instead, playback pauses (ducked speech is
  ///   hard to follow) and the player goes idle.
  /// - iOS: the playback category (plays through the silent switch) with
  ///   [AVAudioSessionCategoryOptions.duckOthers] and the spoken-audio mode;
  ///   on deactivation other apps are told they can resume
  ///   ([AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation]).
  ///
  /// just_audio activates the session on each play; this player deactivates
  /// it once nothing is playing.
  static const AudioSessionConfiguration audioSessionConfiguration =
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: true,
      );

  final AudioPlayer _player;
  final NoticeAudioCache _cache;
  final Future<AudioSession> Function() _audioSession;
  final String? Function(String key) _assetFor;
  late final StreamSubscription<PlayerState> _subscription;

  final ValueNotifier<VoicePlayerState> _state = ValueNotifier(
    const VoiceIdle(),
  );
  final StreamController<String> _completed = StreamController.broadcast();

  /// Bumped by every play and stop, and when audio ends; async work from an
  /// older request is dropped, so a quick second tap never shows the first
  /// one's result.
  int _request = 0;

  /// The request that set [VoicePlaying], and whether the player has
  /// reported playing since. Player events from before that (the load, or
  /// our own stop) must not end it.
  int? _playingRequest;
  bool _heardPlaying = false;

  /// Deletes the current request's source when it turns out unplayable: the
  /// cached voice note file, so the next tap downloads it again. Null for
  /// bundled prompts.
  Future<void> Function()? _dropSource;

  Future<void>? _session;
  bool _disposed = false;

  @override
  ValueListenable<VoicePlayerState> get state => _state;

  @override
  Stream<String> get completed => _completed.stream;

  @override
  Future<void> playPrompt(String key) async {
    final request = await _begin(key);
    if (request == null) return;
    final asset = _assetFor(key);
    if (asset == null) {
      await _end(request, VoiceUnavailable(key), stopPlayer: false);
      return;
    }
    await _load(request, key, () => _player.setAsset(asset));
  }

  @override
  Future<void> playUrl(Uri url, {required String cacheKey}) async {
    final request = await _begin(cacheKey);
    if (request == null) return;
    final String path;
    try {
      path = (await _cache.fetch(url, cacheKey)).path;
    } on Object catch (e) {
      await _end(request, VoiceError(cacheKey, e), stopPlayer: false);
      return;
    }
    if (request != _request) return;
    _dropSource = () => _cache.remove(cacheKey);
    await _load(request, cacheKey, () => _player.setFilePath(path));
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await _end(_request, const VoiceIdle());
  }

  @override
  Future<void> clearCache() async {
    try {
      await _cache.clear();
    } on Object {
      // Left for the OS: the cache directory is cleared when storage is low.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _request++;
    await _subscription.cancel();
    await _player.dispose();
    await _releaseSession(null);
    await _completed.close();
    _state.dispose();
  }

  /// Starts a new request: stops the current audio and shows [key] loading.
  /// Returns null when the player is disposed.
  Future<int?> _begin(String key) async {
    if (_disposed) return null;
    final request = ++_request;
    _dropSource = null;
    _state.value = VoiceLoading(key);
    await _stopPlayer();
    return request;
  }

  Future<void> _load(
    int request,
    String key,
    Future<Object?> Function() setSource,
  ) async {
    try {
      await (_session ??= _configureSession());
      if (request != _request) return;
      await setSource();
    } on Object catch (e) {
      await _fail(request, key, e, stopPlayer: false);
      return;
    }
    if (_disposed || request != _request) return;
    _state.value = VoicePlaying(key);
    _playingRequest = request;
    _heardPlaying = false;
    // play() completes when playback ends or stops; the end of the audio is
    // seen in _onPlayerState.
    unawaited(
      _player.play().then(
        (_) {},
        onError: (Object e) => _fail(request, key, e, stopPlayer: true),
      ),
    );
  }

  void _onPlayerState(PlayerState state) {
    final current = _state.value;
    if (current is! VoicePlaying || _playingRequest != _request) return;
    if (state.processingState == ProcessingState.completed) {
      // _end shows idle before its first await, so listeners see idle first.
      unawaited(_end(_request, const VoiceIdle()));
      _completed.add(current.key);
    } else if (state.playing) {
      _heardPlaying = true;
    } else if (_heardPlaying) {
      // Paused by the system, not by us: our own stop and new requests
      // change _request first. just_audio would resume it after a call, but
      // a prompt half-heard minutes later only confuses; start again instead.
      unawaited(_end(_request, const VoiceIdle()));
    }
  }

  void _onPlayerError(Object error) {
    final current = _state.value;
    if (current is! VoicePlaying || _playingRequest != _request) return;
    // Load errors are seen where the load is awaited.
    unawaited(_fail(_request, current.key, error, stopPlayer: true));
  }

  /// Ends [request] in [VoiceError]. A cached voice note that failed to load
  /// or play is deleted, unless the load was cut off by a newer request.
  Future<void> _fail(
    int request,
    String key,
    Object error, {
    required bool stopPlayer,
  }) async {
    final drop = _dropSource;
    if (!await _end(request, VoiceError(key, error), stopPlayer: stopPlayer)) {
      return;
    }
    if (drop != null && error is! PlayerInterruptedException) {
      try {
        await drop();
      } on Object {
        // The next play finds the same broken file and fails again.
      }
    }
  }

  /// Ends [request] in [next] (idle, unavailable or error) if it is still the
  /// latest: shows [next], takes a new request number so nothing else from
  /// [request] lands, stops the player unless it is already stopped, and
  /// gives audio focus back. Returns whether it did.
  Future<bool> _end(
    int request,
    VoicePlayerState next, {
    bool stopPlayer = true,
  }) async {
    if (_disposed || request != _request) return false;
    final ended = ++_request;
    _state.value = next;
    _playingRequest = null;
    _dropSource = null;
    if (stopPlayer) await _stopPlayer();
    await _releaseSession(ended);
    return true;
  }

  Future<void> _stopPlayer() async {
    try {
      await _player.stop();
    } on Object {
      // Stopping an idle or failed player is not worth reporting.
    }
  }

  /// Configures [audioSessionConfiguration]. Failure only means the
  /// platform defaults are used.
  Future<void> _configureSession() async {
    try {
      final session = await _audioSession();
      await session.configure(audioSessionConfiguration);
    } on Object {
      // Not fatal: just_audio falls back to its default session.
    }
  }

  /// Deactivates the session so other apps' audio comes back to full
  /// volume, unless a request newer than [request] has started meanwhile
  /// (null: always). Skipped when no session was ever configured. Failure
  /// is not fatal.
  Future<void> _releaseSession(int? request) async {
    final configured = _session;
    if (configured == null) return;
    try {
      await configured;
      final session = await _audioSession();
      if (request != null && request != _request) return;
      await session.setActive(false);
    } on Object {
      // Other apps stay ducked until the OS takes focus back.
    }
  }
}
