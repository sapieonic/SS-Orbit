// Mock rules that mirror the backend where the app would otherwise only
// learn about them on the real API: ST_IsValid boundaries, byte-counted text
// limits, the missed-visit job and the snapshot's alert window.

import 'package:fa/src/data/data.dart';
import 'package:fa/src/local/commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../support/mock_support.dart';
import 'repository_contract.dart' show throwsApiError;

void main() {
  late MockWorld w;
  setUp(() async => w = await MockWorld.signedIn());

  /// A ring of [corners] [lat, lng] pairs near Kondapur (closed for you).
  String ring(List<(double, double)> corners) => polygonGeoJson([
    for (final (dy, dx) in corners) LatLng(17.46 + dy, 78.357 + dx),
  ]);

  SavePlotPayload plot({
    String? boundary,
    String label = 'Plot 9',
    LatLng? pin,
  }) => SavePlotPayload(
    plotId: w.newId(),
    farmerId: MockBackend.raviId,
    label: label,
    boundaryGeoJson: boundary,
    pin: pin,
    areaAcres: 1,
    areaSource: boundary == null ? AreaSource.typed : AreaSource.boundary,
  );

  Future<CommandResult> one(CommandPayload p) async =>
      (await w.push([p])).results.single;

  group('SavePlot boundary (PostGIS ST_IsValid)', () {
    const d = 0.001;

    test('a simple ring is applied, repeated points and all', () async {
      final r = await one(
        plot(boundary: ring([(0, 0), (0, d), (0, d), (d, d), (d, 0)])),
      );
      expect(r.status, CommandStatus.applied);
    });

    test(
      'a ring that crosses itself is rejected as the backend does',
      () async {
        // A bow tie: the second and fourth edges cross.
        final r = await one(
          plot(boundary: ring([(0, 0), (0, d), (d, 0), (d, d)])),
        );
        expect(r.status, CommandStatus.rejected);
        expect(
          r.error,
          'boundary_geojson: boundary crosses itself; walk it again',
        );
      },
    );

    test(
      'a spike (an edge folding back) and a flat ring are invalid',
      () async {
        final spike = await one(
          plot(
            boundary: ring([
              (0, 0),
              (0, d),
              (d, d),
              (d, 2 * d),
              (d, 1.5 * d),
              (d / 2, 0),
            ]),
          ),
        );
        expect(spike.status, CommandStatus.rejected);
        expect(spike.error, contains('crosses itself'));
        final flat = await one(
          plot(boundary: ring([(0, 0), (0, d), (0, 2 * d)])),
        );
        expect(flat.status, CommandStatus.rejected);
        expect(flat.error, contains('crosses itself'));
      },
    );

    test('a ring touching itself at a corner is invalid', () async {
      final r = await one(
        plot(
          boundary: ring([
            (0, 0),
            (0, 2 * d),
            (d, d),
            (2 * d, 2 * d),
            (2 * d, 0),
            (d, d),
          ]),
        ),
      );
      expect(r.status, CommandStatus.rejected);
      expect(r.error, contains('crosses itself'));
    });

    test('an open ring does not parse; a point is not a Polygon', () async {
      final open = await one(
        plot(
          boundary:
              '{"type":"Polygon","coordinates":[[[78.357,17.46],'
              '[78.358,17.46],[78.358,17.461],[78.357,17.461]]]}',
        ),
      );
      expect(open.error, 'boundary_geojson: not a valid GeoJSON polygon');
      final point = await one(
        plot(boundary: '{"type":"Point","coordinates":[78.357,17.46]}'),
      );
      expect(point.error, 'boundary_geojson: must be a Polygon');
    });
  });

  group('text limits are UTF-8 bytes, like Go len()', () {
    const pin = LatLng(17.46, 78.357);

    test('a plot label: 20 Telugu letters fit, 21 do not', () async {
      final ok = await one(plot(label: 'ప' * 20, pin: pin));
      expect(ok.status, CommandStatus.applied);
      final tooLong = await one(plot(label: 'ప' * 21, pin: pin));
      expect(tooLong.status, CommandStatus.rejected);
      expect(tooLong.error, 'label: must be 1-60 characters');
    });

    test('an English name of 34 Telugu letters is over 100 bytes', () async {
      final r = await one(
        EnrolFarmerPayload(
          farmerId: w.newId(),
          phone: '9876500091',
          name: 'ర' * 34,
          language: Language.te,
          villageId: MockBackend.kondapurId,
          consent: const EnrolConsent(
            purposes: [ConsentPurpose.programme],
            otpProof: null,
            audioPlayed: false,
            noticeVersion: '',
          ),
        ),
      );
      expect(r.status, CommandStatus.rejected);
      expect(r.error, 'name: must be 1-100 characters');
    });

    test('UpdateFarmer name_te allows 300 bytes', () async {
      final f = (await w.snapshot()).farmers.singleWhere(
        (f) => f.id == MockBackend.raviId,
      );
      UpdateFarmerPayload update(String nameTe) => UpdateFarmerPayload(
        farmerId: f.id,
        expectedVersion: f.version,
        fields: UpdateFarmerFields(nameTe: nameTe),
      );
      final tooLong = await one(update('ర' * 101));
      expect(tooLong.error, 'name_te: must not be blank');
      expect((await one(update('ర' * 100))).status, CommandStatus.applied);
    });
  });

  group('missed visits (visits.mark_missed, proposed snapshot contract)', () {
    PlanVisitPayload planRavi(LocalDate day, {String? id}) => PlanVisitPayload(
      visitId: id ?? w.newId(),
      farmerId: MockBackend.raviId,
      plotId: MockBackend.raviPlotId,
      seasonId: MockBackend.raviSeasonId,
      plannedFor: day,
      plannedSlot: VisitSlot.morning,
    );

    test('a planned visit turns missed after its day and stays in the '
        'snapshot for ${MockBackend.snapshotMissedDays} days', () async {
      final today = LocalDate.istOf(mockTestNow);
      final p = planRavi(today);
      expect((await one(p)).status, CommandStatus.applied);
      final before = await w.repos.sync.getStatus();

      w.clock.advance(const Duration(days: 1));
      final status = await w.repos.sync.getStatus();
      expect(status.territoryVersion, greaterThan(before.territoryVersion));
      final v = (await w.snapshot()).visits.singleWhere(
        (v) => v.id == p.visitId,
      );
      expect(v.status, VisitStatus.missed);
      expect(v.plannedFor, today);

      w.clock.advance(const Duration(days: MockBackend.snapshotMissedDays));
      final later = await w.snapshot();
      expect(later.visits.where((v) => v.id == p.visitId), isEmpty);
    });

    test('a missed visit can be re-planned or logged', () async {
      final today = LocalDate.istOf(mockTestNow);
      final a = planRavi(today);
      final b = planRavi(today);
      await w.push([a, b]);
      w.clock.advance(const Duration(days: 2));
      final now = w.clock.now();

      final replan = await one(planRavi(today.addDays(3), id: a.visitId));
      expect(replan.status, CommandStatus.applied);
      final logged = await one(
        LogVisitPayload(
          visitId: b.visitId,
          farmerId: MockBackend.raviId,
          plotId: MockBackend.raviPlotId,
          seasonId: MockBackend.raviSeasonId,
          visitedAt: now,
          farmerPresent: true,
        ),
      );
      expect(logged.status, CommandStatus.applied);

      final snap = await w.snapshot();
      expect(
        snap.visits.singleWhere((v) => v.id == a.visitId).status,
        VisitStatus.planned,
      );
      expect(
        snap.visits.singleWhere((v) => v.id == b.visitId).status,
        VisitStatus.done,
      );
    });
  });

  group('photo keys after a merge (checkPhotoKey follows the alias)', () {
    test('a key under the minted ID works while the payload carries it; '
        'not once the payload says the merged ID', () async {
      final minted = w.newId();
      Future<String> key() async =>
          (await w.repos.enrolment.createFarmerPhotoUpload(
            farmerId: minted,
            contentType: PhotoContentType.jpeg,
            bytes: 1000,
          )).storageKey;
      final enrol = await one(
        EnrolFarmerPayload(
          farmerId: minted,
          phone: MockBackend.rajuPhone,
          name: 'Raju P',
          language: Language.te,
          villageId: MockBackend.kondapurId,
          photoKey: await key(),
          consent: const EnrolConsent(
            purposes: [ConsentPurpose.programme],
            otpProof: null,
            audioPlayed: false,
            noticeVersion: '',
          ),
        ),
      );
      expect(enrol.status, CommandStatus.merged);
      expect(enrol.mergedInto, MockBackend.rajuId);
      var raju = (await w.snapshot()).farmers.singleWhere(
        (f) => f.id == MockBackend.rajuId,
      );
      expect(raju.photoKey, startsWith('farmers/$minted/'));

      final withMinted = await one(
        UpdateFarmerPayload(
          farmerId: minted,
          expectedVersion: raju.version,
          fields: UpdateFarmerFields(photoKey: await key()),
        ),
      );
      expect(withMinted.status, CommandStatus.applied);
      raju = (await w.snapshot()).farmers.singleWhere(
        (f) => f.id == MockBackend.rajuId,
      );
      final withMerged = await one(
        UpdateFarmerPayload(
          farmerId: MockBackend.rajuId,
          expectedVersion: raju.version,
          fields: UpdateFarmerFields(photoKey: await key()),
        ),
      );
      expect(withMerged.status, CommandStatus.rejected);
      expect(
        withMerged.error,
        "photo_key: must be a key from this farmer's photo upload URL",
      );
    });
  });

  group('visit photo upload URL (photoForFA)', () {
    test('404 for a visit or photo the server never stored, 403 for another '
        "FA's visit", () async {
      final visitId = w.newId();
      final photoId = w.newId();
      await w.push([
        LogVisitPayload(
          visitId: visitId,
          farmerId: MockBackend.raviId,
          plotId: MockBackend.raviPlotId,
          seasonId: MockBackend.raviSeasonId,
          visitedAt: w.clock.now(),
          farmerPresent: true,
          photos: [
            LogVisitPhoto(photoId: photoId, contentType: PhotoContentType.jpeg),
          ],
        ),
      ]);
      Future<VisitPhotoUpload> url(FaRepositories repos, String v, String p) =>
          repos.visitPhotos.createUploadUrl(
            visitId: v,
            photoId: p,
            contentType: PhotoContentType.jpeg,
            bytes: 1000,
          );
      expect((await url(w.repos, visitId, photoId)).photoId, photoId);
      await expectLater(
        url(w.repos, visitId, w.newId()),
        throwsA(
          isA<ApiError>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.code, 'code', ApiErrorCode.notFound)
              .having(
                (e) => e.message,
                'message',
                'photo not found; sync the visit log first',
              ),
        ),
      );
      await expectLater(
        url(w.repos, w.newId(), photoId),
        throwsApiError(ApiErrorCode.notFound, status: 404),
      );

      final other = w.backend.repositories(InMemorySessionStore());
      await other.auth.login(
        code: MockBackend.otherFaCode,
        password: MockBackend.otherFaPassword,
        device: const DeviceInfo(deviceKey: 'mock-test-device-2'),
      );
      await expectLater(
        url(other, visitId, w.newId()),
        throwsApiError(ApiErrorCode.forbidden, status: 403),
      );
    });
  });

  group('snapshot alerts (ListSnapshotFAAlerts)', () {
    test('not closed and from the last 30 days only', () async {
      final note = w.backend.addAlert(title: 'Old note');
      w.clock.advance(const Duration(days: MockBackend.snapshotAlertDays));
      expect((await w.snapshot()).alerts.map((a) => a.id), contains(note.id));
      w.clock.advance(const Duration(minutes: 1));
      expect(
        (await w.snapshot()).alerts.map((a) => a.id),
        isNot(contains(note.id)),
      );
    });

    test('at most 200, newest first', () async {
      for (var i = 0; i < MockBackend.snapshotAlertLimit + 5; i++) {
        w.backend.addAlert(title: 'Note $i');
        w.clock.advance(const Duration(seconds: 1));
      }
      final alerts = (await w.snapshot()).alerts;
      expect(alerts, hasLength(MockBackend.snapshotAlertLimit));
      expect(alerts.first.title, 'Note ${MockBackend.snapshotAlertLimit + 4}');
      for (var i = 1; i < alerts.length; i++) {
        expect(alerts[i].createdAt.isAfter(alerts[i - 1].createdAt), isFalse);
      }
    });
  });
}
