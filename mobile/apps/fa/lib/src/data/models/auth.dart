import 'common.dart';

/// Release settings read at start, before sign-in (`AppConfig`,
/// `GET /v1/auth/app-config?app=fa`).
final class AppConfig {
  /// Creates the config.
  const AppConfig({
    required this.app,
    required this.minVersion,
    required this.latestVersion,
    required this.storeUrl,
    required this.flags,
  });

  /// `farmer` or `fa`.
  final String app;

  /// Versions below this must update before use (`0.0.0` forces nothing).
  /// The FA app pushes its outbox first when online, never drops it.
  final String minVersion;

  /// Newest released version (never below [minVersion]).
  final String latestVersion;

  /// Play Store link, or null when not configured.
  final String? storeUrl;

  /// Feature switches by name. Unknown names must be ignored.
  final Map<String, bool> flags;

  /// The flag [name], false when absent.
  bool flag(String name) => flags[name] ?? false;

  @override
  bool operator ==(Object other) =>
      other is AppConfig &&
      other.app == app &&
      other.minVersion == minVersion &&
      other.latestVersion == latestVersion &&
      other.storeUrl == storeUrl &&
      mapEquals(other.flags, flags);

  @override
  int get hashCode =>
      Object.hash(app, minVersion, latestVersion, storeUrl, jsonHash(flags));
}

/// Access and refresh tokens (`TokenPair`). `token_type` is always `Bearer`.
final class TokenPair {
  /// Creates a pair.
  const TokenPair({
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  /// Bearer token for API calls (15 min).
  final String accessToken;

  /// UTC expiry of [accessToken].
  final DateTime accessExpiresAt;

  /// Single-use refresh token (rotated on every refresh, 60 s grace).
  final String refreshToken;

  /// UTC expiry of [refreshToken] (30 days for FAs in dev config).
  final DateTime refreshExpiresAt;

  /// Reads a `TokenPair` object (also what the session store keeps).
  factory TokenPair.fromJson(Map<String, Object?> json) => TokenPair(
    accessToken: json.reqString('access_token'),
    accessExpiresAt: json.reqDateTime('access_expires_at'),
    refreshToken: json.reqString('refresh_token'),
    refreshExpiresAt: json.reqDateTime('refresh_expires_at'),
  );

  /// The `TokenPair` JSON ([fromJson] reads it back).
  Map<String, Object?> toJson() => {
    'token_type': 'Bearer',
    'access_token': accessToken,
    'access_expires_at': utcIso(accessExpiresAt),
    'refresh_token': refreshToken,
    'refresh_expires_at': utcIso(refreshExpiresAt),
  };

  @override
  bool operator ==(Object other) =>
      other is TokenPair &&
      other.accessToken == accessToken &&
      other.accessExpiresAt == accessExpiresAt &&
      other.refreshToken == refreshToken &&
      other.refreshExpiresAt == refreshExpiresAt;

  @override
  int get hashCode =>
      Object.hash(accessToken, accessExpiresAt, refreshToken, refreshExpiresAt);

  @override
  String toString() => 'TokenPair(access until $accessExpiresAt)';
}

/// The app install signing in (`DeviceInfo`, `FALogin.device`).
final class DeviceInfo {
  /// Creates device info.
  const DeviceInfo({
    required this.deviceKey,
    this.model,
    this.osVersion,
    this.appVersion,
    this.pushToken,
  });

  /// Random install ID kept in secure storage (`^[A-Za-z0-9._:-]+$`, 8-128),
  /// replaced after a wipe.
  final String deviceKey;

  /// Phone model, e.g. `Redmi 9A`.
  final String? model;

  /// OS version, e.g. `Android 11`.
  final String? osVersion;

  /// App version, e.g. `1.3.0`.
  final String? appVersion;

  /// FCM token (push is behind a flag until FCM is decided).
  final String? pushToken;

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo &&
      other.deviceKey == deviceKey &&
      other.model == model &&
      other.osVersion == osVersion &&
      other.appVersion == appVersion &&
      other.pushToken == pushToken;

  @override
  int get hashCode =>
      Object.hash(deviceKey, model, osVersion, appVersion, pushToken);
}

/// FA login status (`FAStatus`).
enum FaStatus implements WireEnum {
  /// Working.
  active('active'),

  /// Serving notice; still signs in.
  leaving('leaving'),

  /// Deactivated (cannot sign in).
  inactive('inactive'),

  /// A status this app version does not know.
  unknown('');

  const FaStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static FaStatus fromWire(String? wire) =>
      enumFromWire(values, wire, FaStatus.unknown);
}

/// The signed-in FA (`FieldAssistant`, `FASession.field_assistant`).
///
/// There is no `GET /v1/fa/me`: the profile shown on the PIN and Me screens
/// is the one from the last login, kept in the session store.
final class FieldAssistant {
  /// Creates an FA.
  const FieldAssistant({
    required this.id,
    required this.code,
    required this.name,
    required this.nameTe,
    required this.phone,
    required this.level,
    required this.languages,
    required this.workingHours,
    required this.photoKey,
    required this.status,
    required this.mustChangePassword,
    required this.lastLoginAt,
    required this.lastSyncAt,
    required this.appVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  /// FA ID.
  final String id;

  /// Login ID issued by HO, e.g. `FA-KDP-014`.
  final String code;

  /// English name ("Suresh Kumar").
  final String name;

  /// Telugu name, or null.
  final String? nameTe;

  /// E.164 phone (`+919848012345`).
  final String phone;

  /// Allocation level.
  final AreaLevel level;

  /// Language codes the FA speaks, first one preferred (`["te", "en"]`).
  /// Kept as codes: the list may hold languages the app has no UI for.
  final List<String> languages;

  /// "Mon-Sat 8 am - 5 pm", or null.
  final String? workingHours;

  /// Storage key of the FA's photo, or null.
  final String? photoKey;

  /// Login status.
  final FaStatus status;

  /// Same flag as [FaSession.mustChangePassword] at login time.
  final bool mustChangePassword;

  /// UTC time of the last login before this one, or null.
  final DateTime? lastLoginAt;

  /// UTC time of the last sync the server saw, or null.
  final DateTime? lastSyncAt;

  /// App version of the most recently seen device (lists only), or null.
  final String? appVersion;

  /// UTC creation time.
  final DateTime createdAt;

  /// UTC last update.
  final DateTime updatedAt;

  /// The name to show in [language] (Telugu falls back to English).
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  /// Reads a `FieldAssistant` object (also what the session store keeps).
  factory FieldAssistant.fromJson(Map<String, Object?> json) => FieldAssistant(
    id: json.reqString('id'),
    code: json.reqString('code'),
    name: json.reqString('name'),
    nameTe: json.optString('name_te'),
    phone: json.reqString('phone'),
    level: AreaLevel.fromWire(json.optString('level')),
    languages: json.strings('languages'),
    workingHours: json.optString('working_hours'),
    photoKey: json.optString('photo_key'),
    status: FaStatus.fromWire(json.optString('status')),
    mustChangePassword: json.optBool('must_change_password') ?? false,
    lastLoginAt: json.optDateTime('last_login_at'),
    lastSyncAt: json.optDateTime('last_sync_at'),
    appVersion: json.optString('app_version'),
    createdAt: json.reqDateTime('created_at'),
    updatedAt: json.reqDateTime('updated_at'),
  );

  /// The `FieldAssistant` JSON ([fromJson] reads it back).
  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'name_te': nameTe,
    'phone': phone,
    'level': level.wire,
    'languages': [...languages],
    'working_hours': workingHours,
    'photo_key': photoKey,
    'status': status.wire,
    'must_change_password': mustChangePassword,
    'last_login_at': lastLoginAt == null ? null : utcIso(lastLoginAt!),
    'last_sync_at': lastSyncAt == null ? null : utcIso(lastSyncAt!),
    'app_version': appVersion,
    'created_at': utcIso(createdAt),
    'updated_at': utcIso(updatedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is FieldAssistant &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.phone == phone &&
      other.level == level &&
      listEquals(other.languages, languages) &&
      other.workingHours == workingHours &&
      other.photoKey == photoKey &&
      other.status == status &&
      other.mustChangePassword == mustChangePassword &&
      other.lastLoginAt == lastLoginAt &&
      other.lastSyncAt == lastSyncAt &&
      other.appVersion == appVersion &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    nameTe,
    phone,
    level,
    Object.hashAll(languages),
    workingHours,
    photoKey,
    status,
    mustChangePassword,
    lastLoginAt,
    lastSyncAt,
    appVersion,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'FieldAssistant($code)';
}

/// How the FA app may work offline (`OfflinePolicy`). The PIN itself never
/// leaves the phone.
final class OfflinePolicy {
  /// Creates a policy.
  const OfflinePolicy({
    required this.pinLength,
    required this.offlineGraceDays,
    required this.pinMaxAttempts,
  });

  /// The defaults the server sends today (4-digit PIN, 7 days, 5 tries).
  static const standard = OfflinePolicy(
    pinLength: 4,
    offlineGraceDays: 7,
    pinMaxAttempts: 5,
  );

  /// Digits in the PIN (4).
  final int pinLength;

  /// Days the PIN keeps working without an online contact (login or
  /// refresh) (7).
  final int offlineGraceDays;

  /// Wrong PINs before the app requires the password (5).
  final int pinMaxAttempts;

  /// [offlineGraceDays] as a duration.
  Duration get offlineGrace => Duration(days: offlineGraceDays);

  /// Reads an `OfflinePolicy` object (also what the session store keeps).
  factory OfflinePolicy.fromJson(Map<String, Object?> json) => OfflinePolicy(
    pinLength: json.reqInt('pin_length'),
    offlineGraceDays: json.reqInt('offline_grace_days'),
    pinMaxAttempts: json.reqInt('pin_max_attempts'),
  );

  /// The `OfflinePolicy` JSON ([fromJson] reads it back).
  Map<String, Object?> toJson() => {
    'pin_length': pinLength,
    'offline_grace_days': offlineGraceDays,
    'pin_max_attempts': pinMaxAttempts,
  };

  @override
  bool operator ==(Object other) =>
      other is OfflinePolicy &&
      other.pinLength == pinLength &&
      other.offlineGraceDays == offlineGraceDays &&
      other.pinMaxAttempts == pinMaxAttempts;

  @override
  int get hashCode => Object.hash(pinLength, offlineGraceDays, pinMaxAttempts);
}

/// A signed-in FA (`FASession`, `POST /v1/auth/fa/login`).
final class FaSession {
  /// Creates a session.
  const FaSession({
    required this.tokens,
    required this.deviceId,
    required this.fieldAssistant,
    required this.mustChangePassword,
    required this.offlinePolicy,
  });

  /// The new tokens.
  final TokenPair tokens;

  /// The registered device's ID.
  final String deviceId;

  /// The FA's profile.
  final FieldAssistant fieldAssistant;

  /// Signed in with a temporary password: the token only works for
  /// `POST /v1/fa/me/password` (403 `password_change_required` elsewhere).
  final bool mustChangePassword;

  /// PIN and offline rules.
  final OfflinePolicy offlinePolicy;

  @override
  bool operator ==(Object other) =>
      other is FaSession &&
      other.tokens == tokens &&
      other.deviceId == deviceId &&
      other.fieldAssistant == fieldAssistant &&
      other.mustChangePassword == mustChangePassword &&
      other.offlinePolicy == offlinePolicy;

  @override
  int get hashCode => Object.hash(
    tokens,
    deviceId,
    fieldAssistant,
    mustChangePassword,
    offlinePolicy,
  );
}

/// Heartbeat answer (`DeviceStatus`, `PUT /v1/fa/devices/me`).
final class DeviceStatus {
  /// Creates a status.
  const DeviceStatus({
    required this.deviceId,
    required this.wipe,
    required this.serverTime,
    required this.minVersion,
    required this.updateRequired,
  });

  /// The device's ID.
  final String deviceId;

  /// Delete all local data and sign out now (device revoked or login
  /// deactivated): wipe exactly as for 401 `device_revoked`.
  final bool wipe;

  /// Server time (UTC), for the clock offset.
  final DateTime serverTime;

  /// Oldest app version allowed.
  final String minVersion;

  /// The app version sent is below [minVersion]: push the outbox, then block
  /// and ask for the update.
  final bool updateRequired;

  @override
  bool operator ==(Object other) =>
      other is DeviceStatus &&
      other.deviceId == deviceId &&
      other.wipe == wipe &&
      other.serverTime == serverTime &&
      other.minVersion == minVersion &&
      other.updateRequired == updateRequired;

  @override
  int get hashCode =>
      Object.hash(deviceId, wipe, serverTime, minVersion, updateRequired);
}
