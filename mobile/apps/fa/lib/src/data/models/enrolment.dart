import 'common.dart';

/// What a phone number is to this FA (`PhoneLookup.status`,
/// `GET /v1/fa/farmers/lookup`).
enum PhoneLookupStatus implements WireEnum {
  /// Not registered: enrol as new.
  newFarmer('new'),

  /// Already this FA's farmer: open Farmer 360 ([PhoneLookup.farmerId]).
  mine('mine'),

  /// A farmer with no FA in this FA's area: enrolling claims them
  /// ([PhoneLookup.farmerId] is the farmer).
  unassignedInMyArea('unassigned_in_my_area'),

  /// No FA, but their village is outside this FA's area: call HO.
  outsideMyArea('outside_my_area'),

  /// Another FA's farmer: enrolment would be rejected
  /// `registered_with_another_fa`. Call HO.
  otherFa('other_fa'),

  /// Deactivated by HO: call HO.
  deactivated('deactivated'),

  /// A status this app version does not know.
  unknown('');

  const PhoneLookupStatus(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static PhoneLookupStatus fromWire(String? wire) =>
      enumFromWire(values, wire, PhoneLookupStatus.unknown);
}

/// Is this phone already registered? (`PhoneLookup`).
final class PhoneLookup {
  /// Creates a lookup result.
  const PhoneLookup({required this.status, this.farmerId});

  /// What the number is.
  final PhoneLookupStatus status;

  /// The farmer, only for [PhoneLookupStatus.mine] and
  /// [PhoneLookupStatus.unassignedInMyArea].
  final String? farmerId;

  @override
  bool operator ==(Object other) =>
      other is PhoneLookup &&
      other.status == status &&
      other.farmerId == farmerId;

  @override
  int get hashCode => Object.hash(status, farmerId);

  @override
  String toString() => 'PhoneLookup(${status.wire}, $farmerId)';
}

/// The consent SMS was sent (`OtpSent`, `POST /v1/fa/consent-otp/request`).
final class OtpSent {
  /// Creates the result.
  const OtpSent({
    required this.phoneMasked,
    required this.expiresIn,
    required this.resendAfter,
  });

  /// `+91******2345`, to show on the consent screen.
  final String phoneMasked;

  /// How long the code stays valid (`expires_in_seconds`).
  final Duration expiresIn;

  /// When Resend may be enabled (`resend_after_seconds`, 30 s).
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

/// Proof that the farmer read out the consent code (`ConsentProof`,
/// `POST /v1/fa/consent-otp/verify`).
///
/// Bound to this FA and [phone], valid for 7 days: put [otpProof] in
/// `EnrolFarmerPayload.consent.otp_proof` or `RecordConsentPayload.otp_proof`.
final class ConsentProof {
  /// Creates a proof.
  const ConsentProof({
    required this.phone,
    required this.otpProof,
    required this.verifiedAt,
    required this.expiresAt,
  });

  /// The farmer's phone, normalised (`+919848012345`).
  final String phone;

  /// The signed proof.
  final String otpProof;

  /// UTC time verified.
  final DateTime verifiedAt;

  /// UTC time after which the server rejects it (and the farmer is enrolled
  /// consent pending).
  final DateTime expiresAt;

  /// True when the proof is still valid at [now].
  bool isValidAt(DateTime now) => now.isBefore(expiresAt);

  @override
  bool operator ==(Object other) =>
      other is ConsentProof &&
      other.phone == phone &&
      other.otpProof == otpProof &&
      other.verifiedAt == verifiedAt &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(phone, otpProof, verifiedAt, expiresAt);

  @override
  String toString() => 'ConsentProof($phone, until $expiresAt)';
}
