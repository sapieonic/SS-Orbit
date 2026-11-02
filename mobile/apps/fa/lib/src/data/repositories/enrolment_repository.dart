import '../models/models.dart';

/// The online steps of enrolment: phone lookup, consent OTP and the farmer
/// photo upload URL (`/v1/fa/farmers/*`, `/v1/fa/consent-otp/*`).
///
/// All of these need network; offline, enrolment goes on without them
/// (consent pending, no photo) and the farmer is created by the EnrolFarmer
/// command. Every method needs an FA session and throws `ApiError`:
/// `unauthorized` / `device_revoked` (401), `password_change_required`
/// (403), `network`, plus the codes listed.
abstract interface class EnrolmentRepository {
  /// `GET /v1/fa/farmers/lookup?phone=`: is this number already registered?
  ///
  /// [phone] in any common Indian format. Rate limited (60 an hour) and
  /// audited, so call it once per enrolment, not per keystroke.
  /// Throws `validation_failed` (bad phone), `rate_limited`, `forbidden`.
  Future<PhoneLookup> lookupPhone(String phone);

  /// `POST /v1/fa/consent-otp/request {phone, language}`.
  ///
  /// Sends the farmer the consent SMS in [language] with a 6-digit code. A
  /// new request replaces the previous code. Throws `validation_failed`,
  /// `rate_limited` (one every 30 s per phone, a few an hour; see
  /// `ApiError.retryAfter`), `forbidden`.
  Future<OtpSent> requestConsentOtp({
    required String phone,
    required Language language,
  });

  /// `POST /v1/fa/consent-otp/verify {phone, code}`.
  ///
  /// Only the FA who asked for the code can use it, once. Throws
  /// `otp_invalid` (`ApiError.attemptsLeft`), `otp_expired` (ask for a new
  /// code), `validation_failed`, `rate_limited`, `forbidden`.
  Future<ConsentProof> verifyConsentOtp({
    required String phone,
    required String code,
  });

  /// `POST /v1/fa/farmers/{farmer_id}/photo/upload-url {content_type, bytes}`.
  ///
  /// [farmerId] may be the ID the app minted for an enrolment not yet synced.
  /// [bytes] 1 to 5 MB. Throws `forbidden` (the farmer exists and is another
  /// FA's), `validation_failed` (type or size), `rate_limited` (120 an hour).
  Future<FarmerPhotoUpload> createFarmerPhotoUpload({
    required String farmerId,
    required PhotoContentType contentType,
    required int bytes,
  });
}
