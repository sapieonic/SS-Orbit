import 'package:farmer/src/data/data.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:orbit_core/orbit_core.dart';

/// Swaps the profile repository for [spy] (wrapping the mock's), so the
/// session controller's consent and complete-profile calls are recorded.
/// Pass it in `createContainerAt(overrides: ...)`.
Override spyOnProfile(ProfileSpy spy) =>
    farmerRepositoriesProvider.overrideWith((ref) {
      final base = buildFarmerRepositories(
        ref.watch(orbitEnvProvider),
        ref.watch(sessionStoreProvider),
        mock: ref.watch(mockBackendProvider),
        authFailures: ref.watch(authFailureHookProvider),
      );
      spy.inner = base.profile;
      return FarmerRepositories(
        auth: base.auth,
        profile: spy,
        fieldAssistants: base.fieldAssistants,
        visits: base.visits,
        notices: base.notices,
        geo: base.geo,
        masters: base.masters,
      );
    });

/// Records the consent, complete-profile and rename calls, passing
/// everything on to the mock (or refusing the language, see
/// [refuseLanguage]).
class ProfileSpy implements FarmerProfileRepository {
  /// The mock repository, set when the repository set is built.
  late FarmerProfileRepository inner;

  /// `audioPlayed` of each programme consent sent.
  final consentAudio = <bool?>[];

  /// `(name, nameTe)` of each complete-profile call.
  final completed = <(String, String?)>[];

  /// `(name, nameTe)` of each profile update that changed the name.
  final renamed = <(String?, String?)>[];

  /// When set, saving the language (`PATCH` with `language`) fails with it.
  ApiError? refuseLanguage;

  /// When set, a consent save reaches the server at once but its answer
  /// arrives only once this completes (a slow network on the way back).
  Future<void>? holdConsentAnswers;

  @override
  Future<FarmerHome> getHome() => inner.getHome();

  @override
  Future<Farmer> updateProfile({
    String? name,
    String? nameTe,
    Language? language,
    String? photoKey,
  }) async {
    if (name != null || nameTe != null) renamed.add((name, nameTe));
    if ((language, refuseLanguage) case (_?, final error?)) throw error;
    return inner.updateProfile(
      name: name,
      nameTe: nameTe,
      language: language,
      photoKey: photoKey,
    );
  }

  @override
  Future<Farmer> completeProfile({
    required String name,
    String? nameTe,
    required Language language,
    required String villageId,
  }) {
    completed.add((name, nameTe));
    return inner.completeProfile(
      name: name,
      nameTe: nameTe,
      language: language,
      villageId: villageId,
    );
  }

  @override
  Future<List<CurrentConsent>> listConsents() => inner.listConsents();

  @override
  Future<List<CurrentConsent>> setConsent({
    required ConsentPurpose purpose,
    required bool granted,
    required String noticeVersion,
    bool? audioPlayed,
  }) async {
    if (purpose == ConsentPurpose.programme) consentAudio.add(audioPlayed);
    final saved = await inner.setConsent(
      purpose: purpose,
      granted: granted,
      noticeVersion: noticeVersion,
      audioPlayed: audioPlayed,
    );
    await holdConsentAnswers;
    return saved;
  }

  @override
  Future<FarmerPhotoUpload> createPhotoUpload({
    required PhotoContentType contentType,
    required int bytes,
  }) => inner.createPhotoUpload(contentType: contentType, bytes: bytes);

  @override
  Future<Plot> addPlot({
    String? label,
    required LatLng pin,
    required double areaAcres,
  }) => inner.addPlot(label: label, pin: pin, areaAcres: areaAcres);

  @override
  Future<Season> startSeason({
    required String plotId,
    required String seasonCode,
    required String cropId,
    LocalDate? sowingDate,
    String? previousCropId,
  }) => inner.startSeason(
    plotId: plotId,
    seasonCode: seasonCode,
    cropId: cropId,
    sowingDate: sowingDate,
    previousCropId: previousCropId,
  );

  @override
  Future<Season> closeSeason({
    required String seasonId,
    required SeasonOutcome outcome,
  }) => inner.closeSeason(seasonId: seasonId, outcome: outcome);
}
