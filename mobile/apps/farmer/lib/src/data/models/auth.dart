import 'package:flutter/foundation.dart';

import 'common.dart';

/// Release settings read at start, before sign-in (`AppConfig`,
/// `GET /v1/auth/app-config?app=farmer`).
@immutable
class AppConfig {
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
  int get hashCode => Object.hash(
    app,
    minVersion,
    latestVersion,
    storeUrl,
    Object.hashAllUnordered(
      flags.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// The OTP was sent (`OtpSent`, `POST /v1/auth/otp/request`).
@immutable
class OtpSent {
  /// Creates the result.
  const OtpSent({
    required this.phoneMasked,
    required this.expiresIn,
    required this.resendAfter,
  });

  /// `+91******2345`, to show on the OTP screen.
  final String phoneMasked;

  /// How long the code stays valid (`expires_in_seconds`).
  final Duration expiresIn;

  /// When the Resend button may be enabled (`resend_after_seconds`, 30 s).
  final Duration resendAfter;

  @override
  bool operator ==(Object other) =>
      other is OtpSent &&
      other.phoneMasked == phoneMasked &&
      other.expiresIn == expiresIn &&
      other.resendAfter == resendAfter;

  @override
  int get hashCode => Object.hash(phoneMasked, expiresIn, resendAfter);
}

/// Access and refresh tokens (`TokenPair`). `token_type` is always `Bearer`.
@immutable
class TokenPair {
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

  /// Single-use refresh token (rotated on every refresh).
  final String refreshToken;

  /// UTC expiry of [refreshToken] (90 days for farmers).
  final DateTime refreshExpiresAt;

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

/// Farmer account status (`FarmerStatus`).
enum FarmerStatus implements WireEnum {
  /// Self sign-up not finished: consent, village and name still to do.
  pendingProfile('pending_profile'),

  /// Normal account.
  active('active'),

  /// Deactivated by HO: "Account paused, call helpline".
  inactive('inactive'),

  /// A status this app version does not know.
  unknown('');

  const FarmerStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static FarmerStatus fromWire(String? wire) =>
      enumFromWire(values, wire, FarmerStatus.unknown);
}

/// A signed-in farmer (`FarmerSession`, `POST /v1/auth/otp/verify`).
@immutable
class FarmerSession {
  /// Creates a session.
  const FarmerSession({
    required this.tokens,
    required this.farmerId,
    required this.deviceId,
    required this.isNew,
    required this.farmerStatus,
  });

  /// The new tokens.
  final TokenPair tokens;

  /// The farmer's ID.
  final String farmerId;

  /// The registered device's ID.
  final String deviceId;

  /// True when this sign-in created the farmer (self sign-up).
  final bool isNew;

  /// Routing hint. Null when the server could not read it: then call
  /// `GET /v1/farmer/me` and decide from the farmer's status.
  final FarmerStatus? farmerStatus;

  @override
  bool operator ==(Object other) =>
      other is FarmerSession &&
      other.tokens == tokens &&
      other.farmerId == farmerId &&
      other.deviceId == deviceId &&
      other.isNew == isNew &&
      other.farmerStatus == farmerStatus;

  @override
  int get hashCode =>
      Object.hash(tokens, farmerId, deviceId, isNew, farmerStatus);
}

/// The app install signing in (`DeviceInfo`).
@immutable
class DeviceInfo {
  /// Creates device info.
  const DeviceInfo({
    required this.deviceKey,
    this.model,
    this.osVersion,
    this.appVersion,
    this.pushToken,
  });

  /// Random install ID kept in secure storage (`^[A-Za-z0-9._:-]+$`, 8-128).
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

/// Heartbeat answer (`DeviceStatus`, `PUT /v1/farmer/devices/me`).
@immutable
class DeviceStatus {
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

  /// Delete all local data and sign out now.
  final bool wipe;

  /// Server time (UTC), for the clock offset.
  final DateTime serverTime;

  /// Oldest app version allowed.
  final String minVersion;

  /// The app version sent is below [minVersion]: block and ask for the update.
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
