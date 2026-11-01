import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:orbit_voice/orbit_voice.dart';

import 'fake_audio_player.dart';

const recorded = 'farmer.home.voice_help';
const unrecorded = 'farmer.fas.voice_help';
const recordedAsset = 'packages/orbit_voice/assets/voice/te/$recorded.m4a';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioPlayer audio;
  late FakeAudioSession session;
  late Directory cacheDir;
  late JustAudioVoicePlayer player;
  late List<VoicePlayerState> states;
  late List<String> completed;
  late StreamSubscription<String> completedSub;

  setUp(() {
    audio = FakeAudioPlayer();
    session = FakeAudioSession();
    cacheDir = Directory.systemTemp.createTempSync('orbit_voice_test');
    player = JustAudioVoicePlayer(
      player: audio,
      cache: NoticeAudioCache(directory: () async => cacheDir),
      audioSession: () async => session,
      assetFor: (key) => key == recorded ? recordedAsset : null,
    );
    states = [];
    player.state.addListener(() => states.add(player.state.value));
    completed = [];
    completedSub = player.completed.listen(completed.add);
  });

  tearDown(() async {
    await completedSub.cancel();
    await player.dispose();
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  group('JustAudioVoicePlayer state machine', () {
    test('starts idle', () {
      expect(player.state.value, const VoiceIdle());
    });

    test('recorded prompt: loading -> playing -> idle + completed', () async {
      await player.playPrompt(recorded);
      expect(audio.calls, ['stop', 'asset:$recordedAsset', 'play']);
      expect(player.state.value, const VoicePlaying(recorded));

      audio.finish();
      await pumpEventQueue();
      expect(states, const [
        VoiceLoading(recorded),
        VoicePlaying(recorded),
        VoiceIdle(),
      ]);
      expect(completed, [recorded]);
    });

    test('missing recording is unavailable and never throws', () async {
      await player.playPrompt(unrecorded);
      expect(states, const [
        VoiceLoading(unrecorded),
        VoiceUnavailable(unrecorded),
      ]);
      expect(audio.calls, ['stop']);
      expect(completed, isEmpty);
    });

    test('stop before the end gives no completed event', () async {
      await player.playPrompt(recorded);
      await player.stop();
      audio.finish(); // a late end-of-audio from the stopped source
      await pumpEventQueue();
      expect(player.state.value, const VoiceIdle());
      expect(completed, isEmpty);
    });

    test('starting another key interrupts the first', () async {
      await player.playPrompt(recorded);
      await player.playPrompt(unrecorded);
      audio.finish(); // a late end-of-audio from the interrupted prompt
      await pumpEventQueue();
      expect(states, const [
        VoiceLoading(recorded),
        VoicePlaying(recorded),
        VoiceLoading(unrecorded),
        VoiceUnavailable(unrecorded),
      ]);
      expect(audio.calls, ['stop', 'asset:$recordedAsset', 'play', 'stop']);
      expect(completed, isEmpty);
    });

    test('a slow first load cannot overwrite a newer request', () async {
      final gate = Completer<void>();
      audio.loadGate = gate;
      final first = player.playPrompt(recorded);
      await pumpEventQueue();
      expect(player.state.value, const VoiceLoading(recorded));

      final second = player.playPrompt(unrecorded);
      gate.complete();
      await Future.wait([first, second]);
      expect(player.state.value, const VoiceUnavailable(unrecorded));
      expect(audio.calls, isNot(contains('play')));
    });

    test('load failure ends in error with the key', () async {
      final boom = Exception('broken file');
      audio.loadError = boom;
      await player.playPrompt(recorded);
      expect(player.state.value, VoiceError(recorded, boom));
      expect(completed, isEmpty);
    });

    test('playback error while playing ends in error', () async {
      await player.playPrompt(recorded);
      final boom = Exception('decoder');
      audio.fail(boom);
      await pumpEventQueue();
      expect(player.state.value, VoiceError(recorded, boom));
    });

    test('cached voice note plays from the file by cache key', () async {
      final file = File('${cacheDir.path}/notice-1.m4a')
        ..writeAsBytesSync([1, 2, 3]);
      // The URL is never fetched: the cached file wins.
      await player.playUrl(
        Uri.parse('http://127.0.0.1:9/expired'),
        cacheKey: 'notice-1',
      );
      expect(audio.calls, ['stop', 'file:${file.path}', 'play']);
      expect(player.state.value, const VoicePlaying('notice-1'));
      audio.finish();
      await pumpEventQueue();
      expect(completed, ['notice-1']);
    });

    test('voice note download failure ends in error', () async {
      await player.playUrl(
        Uri.parse('http://127.0.0.1:9/nothing-here'),
        cacheKey: 'notice-2',
      );
      final state = player.state.value;
      expect(state, isA<VoiceError>());
      expect(state.key, 'notice-2');
    });

    test('a system pause goes idle without a completed event', () async {
      await player.playPrompt(recorded);
      await pumpEventQueue();
      audio.pauseBySystem(); // headphones unplugged
      await pumpEventQueue();
      expect(states, const [
        VoiceLoading(recorded),
        VoicePlaying(recorded),
        VoiceIdle(),
      ]);
      // The player is stopped, so just_audio cannot resume it after a call.
      expect(audio.calls.last, 'stop');
      audio.finish(); // a late end-of-audio
      await pumpEventQueue();
      expect(completed, isEmpty);
    });

    test('own stop and restarts never look like a system pause', () async {
      await player.playPrompt(recorded);
      await pumpEventQueue();
      // Restart the same prompt: the old audio's stop reports
      // (not playing, ready) before idle, like just_audio.
      await player.playPrompt(recorded);
      await pumpEventQueue();
      expect(states, const [
        VoiceLoading(recorded),
        VoicePlaying(recorded),
        VoiceLoading(recorded),
        VoicePlaying(recorded),
      ]);
      audio.finish();
      await pumpEventQueue();
      expect(completed, [recorded]);

      states.clear();
      await player.playPrompt(recorded);
      await pumpEventQueue();
      await player.stop();
      await pumpEventQueue();
      expect(states, const [
        VoiceLoading(recorded),
        VoicePlaying(recorded),
        VoiceIdle(),
      ]);
    });

    test('calls after dispose are ignored', () async {
      await player.dispose();
      await player.playPrompt(recorded);
      await player.stop();
      expect(audio.disposed, isTrue);
      expect(audio.calls, isEmpty);
    });
  });

  group('cached voice notes', () {
    File cachedNote(String id) =>
        File('${cacheDir.path}/$id.m4a')..writeAsBytesSync([1, 2, 3]);

    Future<void> play(String id) =>
        player.playUrl(Uri.parse('http://127.0.0.1:9/expired'), cacheKey: id);

    test('a cached file that fails to load is deleted', () async {
      final file = cachedNote('notice-1');
      final boom = Exception('Source error');
      audio.loadError = boom;
      await play('notice-1');
      expect(player.state.value, VoiceError('notice-1', boom));
      // The next tap downloads it again instead of failing forever.
      expect(file.existsSync(), isFalse);
    });

    test('a cached file that fails to start is deleted', () async {
      final file = cachedNote('notice-2');
      audio.playError = Exception('decoder');
      await play('notice-2');
      await pumpEventQueue();
      expect(player.state.value, isA<VoiceError>());
      expect(file.existsSync(), isFalse);
    });

    test('a cached file that fails while playing is deleted', () async {
      final file = cachedNote('notice-3');
      await play('notice-3');
      expect(player.state.value, const VoicePlaying('notice-3'));
      audio.fail(Exception('decoder'));
      await pumpEventQueue();
      expect(player.state.value, isA<VoiceError>());
      expect(file.existsSync(), isFalse);
    });

    test('a load cut off by a newer request keeps the file', () async {
      final file = cachedNote('notice-4');
      final gate = Completer<void>();
      audio.loadGate = gate;
      final first = play('notice-4');
      await pumpEventQueue();
      await player.stop();
      audio.loadError = PlayerInterruptedException('Loading interrupted');
      gate.complete();
      await first;
      expect(player.state.value, const VoiceIdle());
      expect(file.existsSync(), isTrue);
    });

    test('a failing bundled prompt deletes no voice note', () async {
      final file = cachedNote('notice-5');
      audio.loadError = Exception('broken asset');
      await player.playPrompt(recorded);
      expect(player.state.value, isA<VoiceError>());
      expect(file.existsSync(), isTrue);
    });

    test('clearCache deletes downloaded voice notes', () async {
      cachedNote('notice-6');
      await player.clearCache();
      expect(cacheDir.existsSync(), isFalse);
      // Safe to call again with nothing cached.
      await player.clearCache();
    });
  });

  group('audio session', () {
    test('asks others to duck for a short spoken prompt, once', () async {
      await player.playPrompt(recorded);
      await player.playPrompt(recorded);
      expect(session.configured, hasLength(1));
      final config = session.configured.single;
      expect(
        config.androidAudioFocusGainType,
        AndroidAudioFocusGainType.gainTransientMayDuck,
      );
      expect(
        config.androidAudioAttributes?.contentType,
        AndroidAudioContentType.speech,
      );
      expect(config.avAudioSessionCategory, AVAudioSessionCategory.playback);
      expect(
        config.avAudioSessionCategoryOptions?.contains(
          AVAudioSessionCategoryOptions.duckOthers,
        ),
        isTrue,
      );
      expect(config.avAudioSessionMode, AVAudioSessionMode.spokenAudio);
      expect(
        config.avAudioSessionSetActiveOptions,
        AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
    });

    test('gives focus back whenever playback ends', () async {
      Future<void> playThen(void Function() end) async {
        await player.playPrompt(recorded);
        await pumpEventQueue();
        end();
        await pumpEventQueue();
      }

      await playThen(audio.finish);
      expect(session.activations, [false]);
      await playThen(player.stop);
      expect(session.activations, [false, false]);
      await playThen(() => audio.fail(Exception('decoder')));
      expect(session.activations, [false, false, false]);
      await playThen(audio.pauseBySystem);
      expect(session.activations, [false, false, false, false]);
      // Interrupted by a key with no recording: nothing plays any more.
      await playThen(() => player.playPrompt(unrecorded));
      expect(session.activations, hasLength(5));
    });

    test('switching prompts keeps focus until the last one ends', () async {
      await player.playPrompt(recorded);
      await player.playPrompt(recorded);
      await pumpEventQueue();
      expect(session.activations, isEmpty);
      audio.finish();
      await pumpEventQueue();
      expect(session.activations, [false]);
    });

    test('nothing to give back before anything played', () async {
      await player.stop();
      await player.playPrompt(unrecorded);
      expect(session.configured, isEmpty);
      expect(session.activations, isEmpty);
    });

    test('a broken audio session does not stop playback', () async {
      final other = FakeAudioPlayer();
      final broken = JustAudioVoicePlayer(
        player: other,
        cache: NoticeAudioCache(directory: () async => cacheDir),
        audioSession: () async => FakeAudioSession(failing: true),
        assetFor: (key) => key == recorded ? recordedAsset : null,
      );
      final done = <String>[];
      final sub = broken.completed.listen(done.add);
      await broken.playPrompt(recorded);
      expect(broken.state.value, const VoicePlaying(recorded));
      other.finish();
      await pumpEventQueue();
      expect(broken.state.value, const VoiceIdle());
      expect(done, [recorded]);
      await sub.cancel();
      await broken.dispose();
    });
  });

  group('SilentVoicePlayer', () {
    test('reports unavailable and never completes', () async {
      final silent = SilentVoicePlayer();
      final events = <String>[];
      final sub = silent.completed.listen(events.add);
      await silent.playPrompt(recorded);
      expect(silent.state.value, const VoiceUnavailable(recorded));
      await silent.playUrl(Uri.parse('https://x/y.m4a'), cacheKey: 'n');
      expect(silent.state.value, const VoiceUnavailable('n'));
      await silent.stop();
      expect(silent.state.value, const VoiceIdle());
      await silent.clearCache();
      await pumpEventQueue();
      expect(events, isEmpty);
      await sub.cancel();
      await silent.dispose();
    });
  });
}
