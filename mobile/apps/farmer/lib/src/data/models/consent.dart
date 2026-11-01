import 'package:flutter/foundation.dart';

import 'common.dart';

/// What a consent is for (`ConsentPurpose`).
enum ConsentPurpose implements WireEnum {
  /// Joining the programme (asked on F1a, before the village picker).
  programme('programme'),

  /// Sharing the field location with the soil-test partner (Phase 2+).
  soilPartner('soil_partner'),

  /// Schemes, insurance and lenders (Phase 3).
  schemesFinance('schemes_finance'),

  /// Loyalty and cashback (Phase 2).
  loyalty('loyalty'),

  /// A purpose this app version does not know (never send it).
  unknown('');

  const ConsentPurpose(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static ConsentPurpose fromWire(String? wire) =>
      enumFromWire(values, wire, ConsentPurpose.unknown);
}

/// How a consent was captured (`CurrentConsent.method`).
enum ConsentMethod implements WireEnum {
  /// In the farmer app.
  app('app'),

  /// By an FA with an SMS OTP.
  faOtp('fa_otp'),

  /// By HO.
  ho('ho'),

  /// A method this app version does not know.
  unknown('');

  const ConsentMethod(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static ConsentMethod fromWire(String? wire) =>
      enumFromWire(values, wire, ConsentMethod.unknown);
}

/// The current answer for one purpose (`CurrentConsent`).
@immutable
class CurrentConsent {
  /// Creates a consent entry.
  const CurrentConsent({
    required this.purpose,
    required this.granted,
    required this.method,
    required this.noticeVersion,
    required this.updatedAt,
  });

  /// The purpose.
  final ConsentPurpose purpose;

  /// True granted, false withdrawn or refused, null never asked.
  final bool? granted;

  /// How it was captured; null when never asked.
  final ConsentMethod? method;

  /// The consent notice version the farmer saw.
  final String? noticeVersion;

  /// When last answered (UTC).
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      other is CurrentConsent &&
      other.purpose == purpose &&
      other.granted == granted &&
      other.method == method &&
      other.noticeVersion == noticeVersion &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(purpose, granted, method, noticeVersion, updatedAt);

  @override
  String toString() => 'CurrentConsent(${purpose.wire}: $granted)';
}
