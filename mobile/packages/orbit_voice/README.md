# orbit_voice

Playback for Orbit's Listen buttons (NFR-01, FAR-03): recorded Telugu prompts bundled as assets, and
notice voice notes downloaded once and cached. No phone text-to-speech (the plan rules it out as the main
path: patchy on cheap phones).

Dependencies: `orbit_voice -> orbit_l10n` (voice key map and asset paths). It never imports `orbit_ui`:
the presentational `ListenButton` lives there and the app wires `VoicePlayer.state` into it.

## API

```dart
abstract interface class VoicePlayer {
  ValueListenable<VoicePlayerState> get state;  // VoiceIdle | VoiceLoading(key) | VoicePlaying(key)
                                                // | VoiceUnavailable(key) | VoiceError(key, error)
  Stream<String> get completed;                 // key of audio that played to the very end
  Future<void> playPrompt(String key);          // i18n key, e.g. VoiceKeys.farmerHomeVoiceHelp
  Future<void> playUrl(Uri url, {required String cacheKey}); // notice audio_url, cacheKey = notice ID
  Future<void> stop();
  Future<void> clearCache();                    // delete downloaded voice notes (sign-out)
  Future<void> dispose();
}
```

- `JustAudioVoicePlayer({AudioPlayer? player, NoticeAudioCache? cache, audioSession, assetFor})`: the real
  player (ExoPlayer on Android, AVPlayer on iOS). Audio session for short prompts
  (`JustAudioVoicePlayer.audioSessionConfiguration`): on Android it takes transient focus that lets other apps
  duck (`gainTransientMayDuck`); on iOS it uses the playback category (plays through the silent switch) with
  `duckOthers` and the spoken-audio mode. When the prompt ends, is stopped or fails, the session is
  deactivated (iOS: `notifyOthersOnDeactivation`), so the farmer's radio or music comes back to full volume.
  Session failures are not fatal.
- `SilentVoicePlayer()`: plays nothing; every request ends in `VoiceUnavailable`. For tests and previews.
- `NoticeAudioCache({timeout, maxBytes})`: `fetch(url, cacheKey)`, `cached(cacheKey)`, `remove`, `clear`.
  Files live in the app cache directory under `orbit_voice/`, named by cache key, never by URL (presigned
  URLs expire). `timeout` (60 s) covers the whole download. Only audio is kept: an empty body, a text type
  (`text/html` from a Wi-Fi login page, `application/json`) or a body starting like markup is rejected and
  nothing is written. After each download the least recently played files are deleted until the cache is
  under `maxBytes` (50 MB); the new file is always kept.

Rules:
- One thing plays at a time; starting something stops the current audio without a `completed` event.
- Play methods never throw. A key with no recording ends in `VoiceUnavailable`; network or decoder
  failures end in `VoiceError`. A cached voice note that fails to load or play is deleted, so the next tap
  downloads it again.
- When the system pauses playback (headphones unplugged, a call, another app taking audio focus), the state
  goes back to `VoiceIdle`, with no `completed` event. The next tap plays from the start.
- Mark a notice "listened" only on `completed` for its ID (the API's `/listened` call).
- Call `clearCache()` on sign-out, so the next person on the phone cannot play the last farmer's notices.

```dart
final player = JustAudioVoicePlayer();
ValueListenableBuilder<VoicePlayerState>(
  valueListenable: player.state,
  builder: (context, state, _) {
    final playing = state is VoicePlaying && state.key == VoiceKeys.farmerHomeVoiceHelp;
    return ListenButton(                                  // from orbit_ui
      label: playing ? context.l10n.commonStop : context.l10n.commonListen,
      state: playing ? ListenState.playing : ListenState.idle, // also map loading, unavailable
      onPressed: () => playing ? player.stop() : player.playPrompt(VoiceKeys.farmerHomeVoiceHelp),
    );
  },
);
player.completed.listen((key) { if (key == notice.id) markListened(notice.id); });
```

## Assets

`assets/voice/te/` is declared in `pubspec.yaml`. `tools/i18n/build.dart` copies `i18n/voice/te/<key>.m4a`
here for every `voice: true` key; `.gitkeep` keeps the folder (and the asset entry) valid before the first
recording. AAC in `.m4a` plays on both Android and iOS with no platform set-up. Notice audio uploaded as
Ogg will not play on iOS; the backend should store AAC/MP3.

## Tests

`flutter test`: the `JustAudioVoicePlayer` state machine against a fake just_audio player and audio session
(completion, stop, system pause, interruption, overlapping loads, errors, broken cached files, focus given
back), `SilentVoicePlayer`, and `NoticeAudioCache` against a local HTTP server (non-audio and empty
responses, the overall timeout, the size cap).
