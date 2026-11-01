import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/farm/farm_screen.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../../support/harness.dart';

/// The profile repository, but Home carries a loadable-looking presigned
/// photo URL, signed again on every `getHome` (`?sig=N`).
final class PhotoProfile implements FarmerProfileRepository {
  PhotoProfile(this._inner);

  final FarmerProfileRepository _inner;

  /// `getHome` calls so far.
  int homes = 0;

  @override
  Future<FarmerHome> getHome() async {
    final home = await _inner.getHome();
    final sig = ++homes;
    return FarmerHome(
      farmer: home.farmer.copyWith(photoKey: 'farmers/f/photo-1.jpg'),
      photoUrl: 'https://photos.orbit.example/f/photo-1.jpg?sig=$sig',
      village: home.village,
      plots: home.plots,
      fa: home.fa,
      nextVisit: home.nextVisit,
    );
  }

  @override
  Future<Plot> addPlot({
    String? label,
    required LatLng pin,
    required double areaAcres,
  }) => _inner.addPlot(label: label, pin: pin, areaAcres: areaAcres);

  @override
  Future<Season> closeSeason({
    required String seasonId,
    required SeasonOutcome outcome,
  }) => _inner.closeSeason(seasonId: seasonId, outcome: outcome);

  @override
  Future<Farmer> completeProfile({
    required String name,
    String? nameTe,
    required Language language,
    required String villageId,
  }) => _inner.completeProfile(
    name: name,
    nameTe: nameTe,
    language: language,
    villageId: villageId,
  );

  @override
  Future<FarmerPhotoUpload> createPhotoUpload({
    required PhotoContentType contentType,
    required int bytes,
  }) => _inner.createPhotoUpload(contentType: contentType, bytes: bytes);

  @override
  Future<List<CurrentConsent>> listConsents() => _inner.listConsents();

  @override
  Future<List<CurrentConsent>> setConsent({
    required ConsentPurpose purpose,
    required bool granted,
    required String noticeVersion,
    bool? audioPlayed,
  }) => _inner.setConsent(
    purpose: purpose,
    granted: granted,
    noticeVersion: noticeVersion,
    audioPlayed: audioPlayed,
  );

  @override
  Future<Season> startSeason({
    required String plotId,
    required String seasonCode,
    required String cropId,
    LocalDate? sowingDate,
    String? previousCropId,
  }) => _inner.startSeason(
    plotId: plotId,
    seasonCode: seasonCode,
    cropId: cropId,
    sowingDate: sowingDate,
    previousCropId: previousCropId,
  );

  @override
  Future<Farmer> updateProfile({
    String? name,
    String? nameTe,
    Language? language,
    String? photoKey,
  }) => _inner.updateProfile(
    name: name,
    nameTe: nameTe,
    language: language,
    photoKey: photoKey,
  );
}

void main() {
  testWidgets('a photo that fails to load refetches Home once', (tester) async {
    late PhotoProfile profile;
    final container = await createTestContainer(
      overrides: [
        farmerProfileRepositoryProvider.overrideWith(
          (ref) => profile = PhotoProfile(
            ref.watch(farmerRepositoriesProvider).profile,
          ),
        ),
      ],
    );
    // Every image request fails in widget tests (HTTP 400), like an expired
    // presigned URL.
    await pumpScreen(tester, const FarmScreen(), container: container);
    await tester.pumpAndSettle();

    expect(profile.homes, 2, reason: 'one refetch for a fresh URL');
    expect(
      container.read(farmerHomeProvider).value?.photoUrl,
      endsWith('sig=2'),
    );
    expect(find.text('RK'), findsOneWidget, reason: 'initials meanwhile');

    // The fresh URL fails too: no loop within the window.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(profile.homes, 2);
  });

  test('one refetch per photo per window', () async {
    final clock = FixedClock(DateTime.utc(2026, 11, 1, 5));
    final container = await createTestContainer(
      backend: MockBackend(clock: clock, latency: Duration.zero),
      clock: clock,
    );
    final refresh = container.read(photoUrlRefreshProvider);
    final home = await container.read(farmerHomeProvider.future);
    expect(refresh.photoFailed(home), isFalse, reason: 'Ravi has no photo');

    final withPhoto = FarmerHome(
      farmer: home.farmer.copyWith(photoKey: 'k'),
      photoUrl: null,
      village: home.village,
      plots: home.plots,
      fa: home.fa,
      nextVisit: home.nextVisit,
    );
    expect(refresh.photoFailed(withPhoto), isTrue);
    await container.read(farmerHomeProvider.future);
    expect(refresh.photoFailed(withPhoto), isFalse);
    clock.advance(PhotoUrlRefresh.window);
    expect(refresh.photoFailed(withPhoto), isTrue);
  });
}
