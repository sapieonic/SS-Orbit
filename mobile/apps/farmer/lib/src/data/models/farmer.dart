import 'package:flutter/foundation.dart';

import 'auth.dart';
import 'common.dart';
import 'fas.dart';
import 'masters.dart';
import 'plots.dart';
import 'visits.dart';

/// The farmer's plan (`Plan`). Premium is Phase 2.
enum Plan implements WireEnum {
  /// Free plan.
  free('free'),

  /// Paid plan.
  premium('premium'),

  /// A plan this app version does not know.
  unknown('');

  const Plan(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static Plan fromWire(String? wire) =>
      enumFromWire(values, wire, Plan.unknown);
}

/// How the farmer was registered (`Farmer.source`).
enum FarmerSource implements WireEnum {
  /// Self sign-up in the farmer app.
  self('self'),

  /// Enrolled by an FA.
  fa('fa'),

  /// Added by HO.
  ho('ho'),

  /// A source this app version does not know.
  unknown('');

  const FarmerSource(this.wire);

  @override
  final String wire;

  /// Parses a wire value.
  static FarmerSource fromWire(String? wire) =>
      enumFromWire(values, wire, FarmerSource.unknown);
}

/// The farmer's profile (`Farmer`).
@immutable
class Farmer {
  /// Creates a farmer.
  const Farmer({
    required this.id,
    required this.phone,
    required this.name,
    required this.nameTe,
    required this.language,
    required this.villageId,
    required this.mandalId,
    required this.districtId,
    required this.assignedFaId,
    required this.source,
    required this.enrolledByFaId,
    required this.photoKey,
    required this.plan,
    required this.status,
    required this.profileCompletedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Farmer ID.
  final String id;

  /// E.164, `+91XXXXXXXXXX`.
  final String phone;

  /// English name; null until the profile is complete.
  final String? name;

  /// Telugu name.
  final String? nameTe;

  /// Chosen language.
  final Language language;

  /// Village; null while `pending_profile`.
  final String? villageId;

  /// Mandal of [villageId].
  final String? mandalId;

  /// District of [villageId].
  final String? districtId;

  /// The farmer's FA; null when none is assigned yet.
  final String? assignedFaId;

  /// How the farmer was registered.
  final FarmerSource source;

  /// The FA who enrolled the farmer.
  final String? enrolledByFaId;

  /// Storage key of the photo (the URL is `FarmerHome.photoUrl`).
  final String? photoKey;

  /// Free or premium.
  final Plan plan;

  /// Account status.
  final FarmerStatus status;

  /// When self sign-up was completed.
  final DateTime? profileCompletedAt;

  /// Row version.
  final int version;

  /// Created (UTC).
  final DateTime createdAt;

  /// Last changed (UTC).
  final DateTime updatedAt;

  /// The name to show in [language], falling back to the other one.
  String displayName(Language language) =>
      pickText(language, te: nameTe, en: name);

  /// A copy with the given fields replaced (null keeps the current value).
  Farmer copyWith({
    String? name,
    String? nameTe,
    Language? language,
    String? villageId,
    String? mandalId,
    String? districtId,
    String? assignedFaId,
    String? photoKey,
    Plan? plan,
    FarmerStatus? status,
    DateTime? profileCompletedAt,
    int? version,
    DateTime? updatedAt,
  }) => Farmer(
    id: id,
    phone: phone,
    name: name ?? this.name,
    nameTe: nameTe ?? this.nameTe,
    language: language ?? this.language,
    villageId: villageId ?? this.villageId,
    mandalId: mandalId ?? this.mandalId,
    districtId: districtId ?? this.districtId,
    assignedFaId: assignedFaId ?? this.assignedFaId,
    source: source,
    enrolledByFaId: enrolledByFaId,
    photoKey: photoKey ?? this.photoKey,
    plan: plan ?? this.plan,
    status: status ?? this.status,
    profileCompletedAt: profileCompletedAt ?? this.profileCompletedAt,
    version: version ?? this.version,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Farmer &&
      other.id == id &&
      other.phone == phone &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.language == language &&
      other.villageId == villageId &&
      other.mandalId == mandalId &&
      other.districtId == districtId &&
      other.assignedFaId == assignedFaId &&
      other.source == source &&
      other.enrolledByFaId == enrolledByFaId &&
      other.photoKey == photoKey &&
      other.plan == plan &&
      other.status == status &&
      other.profileCompletedAt == profileCompletedAt &&
      other.version == version &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    phone,
    name,
    nameTe,
    language,
    villageId,
    mandalId,
    districtId,
    assignedFaId,
    source,
    enrolledByFaId,
    photoKey,
    plan,
    status,
    profileCompletedAt,
    version,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Farmer($id, $name, ${status.wire})';
}

/// The farmer's village with mandal and district names (`FarmerVillage`).
@immutable
class FarmerVillage {
  /// Creates a village.
  const FarmerVillage({
    required this.id,
    required this.name,
    required this.nameTe,
    required this.mandalId,
    required this.mandalName,
    required this.mandalNameTe,
    required this.districtId,
    required this.districtName,
    required this.districtNameTe,
  });

  /// Village ID.
  final String id;

  /// English name.
  final String name;

  /// Telugu name.
  final String? nameTe;

  /// Mandal ID.
  final String mandalId;

  /// Mandal English name.
  final String mandalName;

  /// Mandal Telugu name.
  final String? mandalNameTe;

  /// District ID.
  final String districtId;

  /// District English name.
  final String districtName;

  /// District Telugu name.
  final String? districtNameTe;

  @override
  bool operator ==(Object other) =>
      other is FarmerVillage &&
      other.id == id &&
      other.name == name &&
      other.nameTe == nameTe &&
      other.mandalId == mandalId &&
      other.mandalName == mandalName &&
      other.mandalNameTe == mandalNameTe &&
      other.districtId == districtId &&
      other.districtName == districtName &&
      other.districtNameTe == districtNameTe;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    nameTe,
    mandalId,
    mandalName,
    mandalNameTe,
    districtId,
    districtName,
    districtNameTe,
  );
}

/// A plot on Home with its active season and crop stage (`HomePlot`).
@immutable
class HomePlot {
  /// Creates a home plot.
  const HomePlot({
    required this.plot,
    required this.activeSeason,
    required this.daysAfterSowing,
    required this.currentStage,
  });

  /// The plot.
  final Plot plot;

  /// The active season, or null when the plot is fallow.
  final Season? activeSeason;

  /// Calendar days in IST from the sowing date to today (sowing day = 0).
  /// Negative when the sowing date is still ahead (-3: sowing in 3 days);
  /// null when the active season has no sowing date (or there is none).
  final int? daysAfterSowing;

  /// The crop stage for [daysAfterSowing]; null when unknown, before sowing
  /// (negative days) and past the crop's last stage.
  final Stage? currentStage;

  @override
  bool operator ==(Object other) =>
      other is HomePlot &&
      other.plot == plot &&
      other.activeSeason == activeSeason &&
      other.daysAfterSowing == daysAfterSowing &&
      other.currentStage == currentStage;

  @override
  int get hashCode =>
      Object.hash(plot, activeSeason, daysAfterSowing, currentStage);
}

/// Everything Home (F2) shows (`FarmerHome`, `GET /v1/farmer/me`).
@immutable
class FarmerHome {
  /// Creates the home payload.
  const FarmerHome({
    required this.farmer,
    required this.photoUrl,
    required this.village,
    required this.plots,
    required this.fa,
    required this.nextVisit,
  });

  /// The signed-in farmer.
  final Farmer farmer;

  /// Presigned photo URL (valid 15 minutes); never cache the URL itself.
  final String? photoUrl;

  /// The farmer's village; null while `pending_profile`.
  final FarmerVillage? village;

  /// Plots with their active seasons.
  final List<HomePlot> plots;

  /// The assigned FA; null shows "Your FA will call within 2 days".
  final FarmerFaCard? fa;

  /// The next planned FA visit, if any.
  final PlannedVisit? nextVisit;

  /// A copy with the given fields replaced (null keeps the current value).
  FarmerHome copyWith({Farmer? farmer, List<HomePlot>? plots}) => FarmerHome(
    farmer: farmer ?? this.farmer,
    photoUrl: photoUrl,
    village: village,
    plots: plots ?? this.plots,
    fa: fa,
    nextVisit: nextVisit,
  );

  @override
  bool operator ==(Object other) =>
      other is FarmerHome &&
      other.farmer == farmer &&
      other.photoUrl == photoUrl &&
      other.village == village &&
      listEquals(other.plots, plots) &&
      other.fa == fa &&
      other.nextVisit == nextVisit;

  @override
  int get hashCode => Object.hash(
    farmer,
    photoUrl,
    village,
    Object.hashAll(plots),
    fa,
    nextVisit,
  );
}

/// Image types accepted for the farmer photo.
enum PhotoContentType implements WireEnum {
  /// JPEG.
  jpeg('image/jpeg'),

  /// PNG.
  png('image/png'),

  /// WebP.
  webp('image/webp');

  const PhotoContentType(this.wire);

  /// The MIME type.
  @override
  final String wire;
}

/// Where and how to upload a photo (`FarmerPhotoUpload`).
@immutable
class FarmerPhotoUpload {
  /// Creates an upload target.
  const FarmerPhotoUpload({
    required this.storageKey,
    required this.url,
    required this.method,
    required this.headers,
    required this.expiresAt,
  });

  /// The `photo_key` to save with `PATCH /v1/farmer/me` after uploading.
  final String storageKey;

  /// Presigned upload URL.
  final String url;

  /// HTTP method, normally `PUT`.
  final String method;

  /// Headers the upload must send.
  final Map<String, String> headers;

  /// When [url] stops working (UTC).
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is FarmerPhotoUpload &&
      other.storageKey == storageKey &&
      other.url == url &&
      other.method == method &&
      mapEquals(other.headers, headers) &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(
    storageKey,
    url,
    method,
    Object.hashAllUnordered(
      headers.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    expiresAt,
  );
}
