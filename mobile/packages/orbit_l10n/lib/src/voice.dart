import 'voice_keys.g.dart';

/// Flutter asset key of the recorded Telugu prompt for the i18n [key], e.g.
/// `packages/orbit_voice/assets/voice/te/farmer.home.voice_help.m4a`.
///
/// Returns null when [key] is not a voice key (`voice: true` in meta.json) or
/// has no recording bundled yet, so callers can show the Listen button as
/// unavailable instead of failing to load a missing asset.
String? voiceAsset(String key) {
  final path = voiceAssetPaths[key];
  if (path == null || !recordedVoiceKeys.contains(key)) return null;
  return 'packages/$voiceAssetPackage/$path';
}

/// Whether [key] is marked `voice: true` in meta.json, recorded or not.
bool isVoiceKey(String key) => voiceAssetPaths.containsKey(key);
