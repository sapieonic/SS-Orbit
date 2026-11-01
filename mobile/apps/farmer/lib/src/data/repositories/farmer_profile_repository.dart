import 'package:orbit_core/orbit_core.dart';

import '../models/models.dart';

/// The signed-in farmer: home, profile, sign-up completion, consents, photo,
/// plots and seasons (`/v1/farmer/me*`).
///
/// Every method needs a farmer session and throws `ApiError`: `unauthorized`
/// / `device_revoked` (401), `forbidden` (403, deactivated farmer for
/// writes), `network`, plus the codes listed per method.
abstract interface class FarmerProfileRepository {
  /// `GET /v1/farmer/me`: Home (F2) and My farm (F10).
  ///
  /// Throws `not_found` when the farmer row is gone.
  Future<FarmerHome> getHome();

  /// `PATCH /v1/farmer/me {name?, name_te?, language?, photo_key?}`.
  ///
  /// The village is changed through the FA or HO, never here. [photoKey] must
  /// come from [createPhotoUpload] after the image was uploaded.
  /// Throws `validation_failed`, `profile_incomplete` (409, still
  /// `pending_profile`).
  Future<Farmer> updateProfile({
    String? name,
    String? nameTe,
    Language? language,
    String? photoKey,
  });

  /// `POST /v1/farmer/me/complete-profile {name, name_te?, language,
  /// village_id}`.
  ///
  /// Finishes a self sign-up: the farmer becomes active and gets the lead FA
  /// of the village (if any). Throws `profile_already_complete` (409: already
  /// done, carry on), `validation_failed`, `not_found` (village).
  Future<Farmer> completeProfile({
    required String name,
    String? nameTe,
    required Language language,
    required String villageId,
  });

  /// `GET /v1/farmer/me/consents`: one entry per purpose, `granted: null` =
  /// never asked.
  Future<List<CurrentConsent>> listConsents();

  /// `POST /v1/farmer/me/consents {purpose, granted, notice_version,
  /// audio_played?}`.
  ///
  /// Works while `pending_profile` (F1a happens before the village picker).
  /// Returns the current consents. Throws `validation_failed`, `forbidden`
  /// (deactivated farmer).
  Future<List<CurrentConsent>> setConsent({
    required ConsentPurpose purpose,
    required bool granted,
    required String noticeVersion,
    bool? audioPlayed,
  });

  /// `POST /v1/farmer/me/photo/upload-url {content_type, bytes}`.
  ///
  /// PUT the image to the result, then save `storageKey` with
  /// [updateProfile]. At most 5 MB. Throws `validation_failed`,
  /// `rate_limited` (20 an hour), `profile_incomplete`.
  Future<FarmerPhotoUpload> createPhotoUpload({
    required PhotoContentType contentType,
    required int bytes,
  });

  /// `POST /v1/farmer/me/plots {label?, pin, area_acres}`.
  ///
  /// [label] defaults to "Plot N". Throws `validation_failed`,
  /// `profile_incomplete`.
  Future<Plot> addPlot({
    String? label,
    required LatLng pin,
    required double areaAcres,
  });

  /// `POST /v1/farmer/me/plots/{plot_id}/seasons {season_code, crop_id,
  /// sowing_date?, previous_crop_id?}`.
  ///
  /// [seasonCode] from `SeasonCodes.allOpen`. Throws `active_season_exists`
  /// (409, `details.season_id`), `season_exists` (409), `not_found` (plot),
  /// `validation_failed`, `profile_incomplete`.
  Future<Season> startSeason({
    required String plotId,
    required String seasonCode,
    required String cropId,
    LocalDate? sowingDate,
    String? previousCropId,
  });

  /// `POST /v1/farmer/me/seasons/{season_id}/close {outcome}`.
  ///
  /// Throws `season_not_active` (409), `not_found`, `profile_incomplete`.
  Future<Season> closeSeason({
    required String seasonId,
    required SeasonOutcome outcome,
  });
}
