/// Voice playback for Orbit's Listen buttons (NFR-01, FAR-03): bundled Telugu
/// prompts by i18n key, and notice voice notes downloaded once and cached.
///
/// Phone text-to-speech is deliberately not used (patchy on cheap phones).
///
/// ```dart
/// final VoicePlayer player = JustAudioVoicePlayer();
/// await player.playPrompt(VoiceKeys.farmerHomeVoiceHelp);
/// await player.playUrl(Uri.parse(notice.audioUrl!), cacheKey: notice.id);
/// player.completed.listen((key) => markListened(key)); // played to the end
/// ```
library;

export 'src/just_audio_voice_player.dart';
export 'src/notice_audio_cache.dart';
export 'src/silent_voice_player.dart';
export 'src/voice_player.dart';
