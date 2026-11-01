import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/shared/voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';
import 'package:orbit_voice/orbit_voice.dart';

import '../support/harness.dart';

void main() {
  group('listenStateFor', () {
    const key = 'farmer.home.voice_help';

    test('follows the player for its own key', () {
      expect(listenStateFor(const VoiceIdle(), key), ListenState.idle);
      expect(listenStateFor(const VoiceLoading(key), key), ListenState.loading);
      expect(listenStateFor(const VoicePlaying(key), key), ListenState.playing);
      expect(
        listenStateFor(const VoiceUnavailable(key), key),
        ListenState.unavailable,
      );
      expect(
        listenStateFor(VoiceError(key, Exception('offline')), key),
        ListenState.unavailable,
        reason: 'a failure shows like no audio; a tap tries again',
      );
    });

    test('stays idle while another key plays or fails', () {
      for (final state in [
        const VoiceLoading('other'),
        const VoicePlaying('other'),
        const VoiceUnavailable('other'),
        VoiceError('other', Exception('offline')),
      ]) {
        expect(listenStateFor(state, key), ListenState.idle, reason: '$state');
      }
    });
  });

  testWidgets('signing out stops the voice and clears cached voice notes', (
    tester,
  ) async {
    final voice = FakeVoicePlayer();
    final container = await createTestContainer(voice: voice);
    await pumpFarmerApp(tester, container: container);
    await voice.playUrl(Uri.parse('https://x.test/n1.m4a'), cacheKey: 'n1');
    expect(voice.cacheClears, 0);

    await container.read(sessionProvider.notifier).signOut();
    await tester.pumpAndSettle();

    expect(voice.cacheClears, 1);
    expect(voice.state.value, isA<VoiceIdle>());
  });

  testWidgets('a sign-in clears voice notes the app may still have cached '
      'from a farmer whose session it forgot', (tester) async {
    // A new run of the app that kept no session (the in-memory store): the
    // last farmer never signed out, so nothing was cleared then.
    final voice = FakeVoicePlayer();
    final container = await createTestContainer(signedIn: false, voice: voice);
    await pumpFarmerApp(tester, container: container);
    expect(voice.cacheClears, 0);

    final session = container.read(sessionProvider.notifier);
    await session.requestOtp(venkateshPhone);
    await session.verifyOtp(devOtp);
    await tester.pumpAndSettle();

    expect(voice.cacheClears, 1);
  });
}
