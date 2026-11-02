import 'dart:typed_data';

import 'package:fa/src/data/data.dart';
import 'package:fa/src/local/commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../support/mock_support.dart';
import 'repository_contract.dart' show throwsApiError;

void main() {
  final today = LocalDate.istOf(mockTestNow);

  group('auth', () {
    test('Suresh signs in; the session and online contact are saved', () async {
      final w = MockWorld();
      final s = await w.login();
      expect(s.fieldAssistant.code, MockBackend.sureshCode);
      expect(s.fieldAssistant.name, 'Suresh Kumar');
      expect(s.fieldAssistant.phone, '+919848012345');
      expect(s.fieldAssistant.lastLoginAt, isNotNull);
      expect(s.mustChangePassword, isFalse);
      expect(s.offlinePolicy, OfflinePolicy.standard);
      final stored = await w.store.readSession();
      expect(stored?.faId, MockBackend.sureshId);
      expect(stored?.tokens, s.tokens);
      expect(stored?.fieldAssistant, s.fieldAssistant);
      expect(await w.store.readLastOnlineAt(), mockTestNow);
      // The login ID is case-insensitive.
      await w.login(code: ' fa-kdp-014 ');
    });

    test('wrong password and expired temporary password', () async {
      final w = MockWorld();
      await expectLater(
        w.login(password: 'nope1234'),
        throwsApiError(ApiErrorCode.unauthorized, status: 401),
      );
      await expectLater(
        w.login(code: 'FA-NOPE-1'),
        throwsApiError(ApiErrorCode.unauthorized, status: 401),
      );
      await expectLater(
        w.login(
          code: MockBackend.expiredPasswordCode,
          password: MockBackend.expiredPassword,
        ),
        throwsApiError(ApiErrorCode.tempPasswordExpired, status: 401),
      );
      // Sign-in failures are not signed-in calls: nothing is reported.
      expect(w.reported, isEmpty);
    });

    test(
      'temporary password: 403 everywhere until changed, then refresh is clean',
      () async {
        final w = MockWorld();
        final s = await w.login(
          code: MockBackend.tempPasswordCode,
          password: MockBackend.tempPassword,
        );
        expect(s.mustChangePassword, isTrue);
        expect((await w.store.readSession())!.mustChangePassword, isTrue);
        await expectLater(
          w.repos.sync.getStatus(),
          throwsApiError(ApiErrorCode.passwordChangeRequired, status: 403),
        );
        await expectLater(
          w.repos.auth.heartbeat(appVersion: '0.1.0'),
          throwsApiError(ApiErrorCode.passwordChangeRequired, status: 403),
        );
        await expectLater(
          w.repos.enrolment.lookupPhone('9876543210'),
          throwsApiError(ApiErrorCode.passwordChangeRequired, status: 403),
        );
        expect(w.reported.first.$1, ApiErrorCode.passwordChangeRequired);
        expect(w.reported.first.$2, (await w.store.readSession())!.faId);

        await expectLater(
          w.repos.auth.changePassword(
            currentPassword: 'wrong',
            newPassword: 'mango2026',
          ),
          throwsA(
            isA<ApiError>()
                .having((e) => e.code, 'code', ApiErrorCode.validationFailed)
                .having(
                  (e) => e.fieldErrors.keys,
                  'fields',
                  contains('current_password'),
                ),
          ),
        );
        for (final weak in [
          'short1',
          'lettersonly',
          MockBackend.tempPassword,
        ]) {
          await expectLater(
            w.repos.auth.changePassword(
              currentPassword: MockBackend.tempPassword,
              newPassword: weak,
            ),
            throwsA(
              isA<ApiError>().having(
                (e) => e.fieldErrors.keys,
                'fields',
                contains('new_password'),
              ),
            ),
            reason: weak,
          );
        }
        await w.repos.auth.changePassword(
          currentPassword: MockBackend.tempPassword,
          newPassword: 'mango2026',
        );
        // The current token keeps its flag until the refresh.
        await expectLater(
          w.repos.sync.getStatus(),
          throwsApiError(ApiErrorCode.passwordChangeRequired),
        );
        await w.repos.auth.refreshSession();
        expect((await w.store.readSession())!.mustChangePassword, isFalse);
        final status = await w.repos.sync.getStatus();
        expect(status.etag, startsWith('"t'));
        // The new password signs in normally.
        final again = await w.login(
          code: MockBackend.tempPasswordCode,
          password: 'mango2026',
        );
        expect(again.mustChangePassword, isFalse);
      },
    );

    test('refresh rotates, a retry within 60 s gets the same pair, later reuse '
        'ends the session', () async {
      final w = await MockWorld.signedIn();
      final first = (await w.store.readSession())!;
      final next = await w.repos.auth.refreshSession();
      expect(next.refreshToken, isNot(first.tokens.refreshToken));
      expect((await w.store.readSession())!.tokens, next);

      // A retry with the used token inside the grace: same successor.
      await w.store.writeSession(first);
      w.clock.advance(const Duration(seconds: 30));
      expect(await w.repos.auth.refreshSession(), next);

      // After the grace the reuse ends the whole session.
      await w.store.writeSession(first);
      w.clock.advance(const Duration(seconds: 61));
      await expectLater(
        w.repos.auth.refreshSession(),
        throwsApiError(ApiErrorCode.refreshReused, status: 401),
      );
      await w.store.writeSession(first.withTokens(next));
      await expectLater(
        w.repos.sync.getStatus(),
        throwsApiError(ApiErrorCode.unauthorized, status: 401),
      );
      expect(w.reported.map((r) => r.$1), [
        ApiErrorCode.refreshReused,
        ApiErrorCode.unauthorized,
      ]);
    });

    test(
      'logout clears the store and ends the session on the server',
      () async {
        final w = await MockWorld.signedIn();
        final s = (await w.store.readSession())!;
        await w.store.writePin(
          const PinRecord(salt: 's', hash: 'h', iterations: 1),
        );
        await w.store.writeLanguage(Language.en);
        final key = await w.store.deviceKey();
        await w.repos.auth.logout();
        expect(await w.store.readSession(), isNull);
        expect(await w.store.readPin(), isNull);
        expect(await w.store.readLanguage(), Language.en);
        expect(await w.store.deviceKey(), key);
        await w.store.writeSession(s);
        await expectLater(
          w.repos.sync.getStatus(),
          throwsApiError(ApiErrorCode.unauthorized),
        );
        // Never throws, even offline.
        w.backend.scenario = MockScenario.offline;
        await w.repos.auth.logout();
      },
    );

    test('heartbeat: device ID, server time, update and wipe', () async {
      final w = await MockWorld.signedIn();
      final s = (await w.store.readSession())!;
      final hb = await w.repos.auth.heartbeat(appVersion: '0.1.0');
      expect(hb.deviceId, s.deviceId);
      expect(hb.serverTime, mockTestNow);
      expect(hb.wipe, isFalse);
      expect(hb.updateRequired, isFalse);
      expect((await w.repos.auth.getAppConfig()).minVersion, '0.0.0');

      w.backend.scenario = MockScenario.updateRequired;
      final update = await w.repos.auth.heartbeat(appVersion: '0.1.0');
      expect(update.updateRequired, isTrue);
      expect(update.minVersion, '1.0.5');
      final config = await w.repos.auth.getAppConfig();
      expect(config.app, 'fa');
      expect(config.minVersion, '1.0.5');
      expect(config.storeUrl, contains('play.google.com'));
      expect(
        (await w.repos.auth.heartbeat(appVersion: '1.0.5')).updateRequired,
        isFalse,
      );
    });

    test('deviceRemoved: heartbeat says wipe, calls get device_revoked, a new '
        'install ID signs in', () async {
      final w = await MockWorld.signedIn();
      w.backend.scenario = MockScenario.deviceRemoved;
      final hb = await w.repos.auth.heartbeat();
      expect(hb.wipe, isTrue);
      await expectLater(
        w.repos.sync.getSnapshot(),
        throwsApiError(ApiErrorCode.deviceRevoked, status: 401),
      );
      await expectLater(
        w.repos.auth.refreshSession(),
        throwsApiError(ApiErrorCode.deviceRevoked),
      );
      expect(w.reported.first, (
        ApiErrorCode.deviceRevoked,
        MockBackend.sureshId,
      ));
      await expectLater(w.login(), throwsApiError(ApiErrorCode.deviceRevoked));
      await w.login(device: const DeviceInfo(deviceKey: 'fresh-install-0001'));
      expect((await w.repos.auth.heartbeat()).wipe, isFalse);
      await w.repos.sync.getStatus();
    });

    test('deviceRemoved from the start removes the first device', () async {
      final w = await MockWorld.signedIn(scenario: MockScenario.deviceRemoved);
      expect((await w.repos.auth.heartbeat()).wipe, isTrue);
      await w.login(device: const DeviceInfo(deviceKey: 'fresh-install-0002'));
      expect((await w.repos.auth.heartbeat()).wipe, isFalse);
    });

    test(
      'sessionExpired: refresh and calls fail with 401, a new login works',
      () async {
        final w = await MockWorld.signedIn();
        w.backend.scenario = MockScenario.sessionExpired;
        await expectLater(
          w.repos.auth.refreshSession(),
          throwsApiError(ApiErrorCode.unauthorized, status: 401),
        );
        await expectLater(
          w.repos.sync.getStatus(),
          throwsApiError(ApiErrorCode.unauthorized),
        );
        expect(w.reported.map((r) => r.$1).toSet(), {
          ApiErrorCode.unauthorized,
        });
        await w.login();
        await w.repos.sync.getStatus();
        await w.repos.auth.refreshSession();
      },
    );

    test('offline and server error scenarios', () async {
      final w = await MockWorld.signedIn();
      w.backend.scenario = MockScenario.offline;
      await expectLater(
        w.repos.sync.getStatus(),
        throwsA(isA<ApiError>().having((e) => e.isNetwork, 'network', true)),
      );
      await expectLater(
        w.repos.auth.getAppConfig(),
        throwsApiError(ApiErrorCode.network),
      );
      w.backend.scenario = MockScenario.serverError;
      await expectLater(
        w.repos.sync.submitCommands([
          const AckAlertPayload(alertId: '0190a5b2-7c1e-7d4a-9b3f-000000000999')
              .toCommandIn(id: '0190a5b2-7c1e-7d4a-9b3f-000000000998'),
        ]),
        throwsApiError(ApiErrorCode.unavailable, status: 503),
      );
      // Neither reaches the session hook.
      expect(w.reported, isEmpty);
      w.backend.scenario = MockScenario.normal;
      await w.repos.sync.getStatus();
    });
  });

  group('seed and snapshot', () {
    late MockWorld w;
    late Snapshot snap;
    setUp(() async {
      w = await MockWorld.signedIn();
      snap = await w.snapshot();
    });

    SnapFarmer farmer(String name) =>
        snap.farmers.singleWhere((f) => f.name == name);

    SnapSeason activeSeason(String farmerId, {String label = 'Plot 1'}) {
      final plot = snap.plots.singleWhere(
        (p) => p.farmerId == farmerId && p.label == label,
      );
      return snap.seasons.singleWhere(
        (s) => s.plotId == plot.id && s.status == SeasonStatus.active,
      );
    }

    test('46 farmers in Kondapur and Gachibowli; villages of the area', () {
      expect(snap.farmers, hasLength(46));
      expect(snap.farmers.map((f) => f.villageId).toSet(), {
        MockBackend.kondapurId,
        MockBackend.gachibowliId,
      });
      expect(snap.villages.map((v) => v.name), ['Kondapur', 'Gachibowli']);
      expect(snap.villages.first.nameTe, 'కొండాపూర్');
      expect(snap.villages.first.mandalName, 'Serilingampally');
      expect(snap.plots, hasLength(61));
      expect(snap.plots.where((p) => p.boundaryGeoJson != null), isNotEmpty);
      // Not Suresh's: Raju P (unassigned), FA-CVL-002's, deactivated.
      final phones = snap.farmers.map((f) => f.phone).toSet();
      expect(phones, isNot(contains(MockBackend.rajuPhone)));
      expect(phones, isNot(contains(MockBackend.otherFaFarmerPhone)));
      expect(phones, isNot(contains(MockBackend.deactivatedPhone)));
      // Pins are near the village centres.
      for (final p in snap.plots) {
        expect(p.pin, isNotNull);
        expect((p.pin!.lat - 17.45).abs(), lessThan(0.06), reason: p.label);
      }
    });

    test('Ravi K: cotton, Plot 1 2 ac 4 gunta, flowering, last visit 12 '
        'days ago with pink bollworm', () {
      final ravi = farmer('Ravi K');
      expect(ravi.id, MockBackend.raviId);
      expect(ravi.phone, MockBackend.raviPhone);
      expect(ravi.nameTe, 'రవి కె');
      expect(ravi.consentPending, isFalse);
      final plot = snap.plots.singleWhere(
        (p) => p.id == MockBackend.raviPlotId,
      );
      expect(AcresGuntas.fromAcres(plot.areaAcres), const AcresGuntas(2, 4));
      final season = activeSeason(ravi.id);
      final crop = snap.masters.cropById(season.cropId)!;
      expect(crop.name, 'Cotton');
      expect(crop.stageAt(season.daysAfterSowing(today)!)?.code, 'flowering');
      final done =
          snap.visits
              .where(
                (v) => v.farmerId == ravi.id && v.status == VisitStatus.done,
              )
              .toList()
            ..sort((a, b) => b.visitedAt!.compareTo(a.visitedAt!));
      expect(done, hasLength(3)); // the 3 latest of 4
      expect(LocalDate.istOf(done.first.visitedAt!), today.addDays(-12));
      final issue = done.first.issues.single;
      expect(issue.issueName, 'Pink bollworm');
      expect(issue.adviceStatus, AdviceStatus.given);
      expect(issue.productName, 'Sample 5 SG');
      expect(done.first.photoCount, 3);
      // Salt only (no Shanmukha product) on an older visit.
      final saltOnly = done[2].issues.single;
      expect(saltOnly.saltName, 'Mancozeb 75% WP');
      expect(saltOnly.skuId, isNull);
      // Ravi asked to be called back.
      expect(snap.callbacks.map((c) => c.farmerId), contains(ravi.id));
    });

    test('Padma S: premium, two plots, 34 days since the last visit', () {
      final padma = farmer('Padma S');
      expect(padma.plan, Plan.premium);
      final plots = snap.plots.where((p) => p.farmerId == padma.id).toList();
      expect(plots.map((p) => p.label), unorderedEquals(['Plot 1', 'Plot 2']));
      final plot2 = plots.singleWhere((p) => p.id == MockBackend.padmaPlot2Id);
      expect(AcresGuntas.fromAcres(plot2.areaAcres), const AcresGuntas(1, 20));
      final last = snap.visits.singleWhere(
        (v) => v.farmerId == padma.id && v.status == VisitStatus.done,
      );
      expect(LocalDate.istOf(last.visitedAt!).daysUntil(today), 34);
    });

    test('Lakshmi N joined yesterday (maize); Kumar B is consent pending', () {
      final lakshmi = farmer('Lakshmi N');
      expect(lakshmi.source, FarmerSource.self);
      expect(LocalDate.istOf(lakshmi.createdAt), today.addDays(-1));
      final season = activeSeason(lakshmi.id);
      expect(snap.masters.cropById(season.cropId)!.code, 'maize');
      expect(farmer('Kumar B').consentPending, isTrue);
      expect(
        snap.farmers.where((f) => f.consentPending).length,
        greaterThan(1),
      );
    });

    test('a week of planned visits around today', () {
      List<String> plannedOn(LocalDate day, VisitSlot slot) => [
        for (final v in snap.visits)
          if (v.status == VisitStatus.planned &&
              v.plannedFor == day &&
              v.plannedSlot == slot)
            snap.farmers.singleWhere((f) => f.id == v.farmerId).name!,
      ];
      expect(plannedOn(today, VisitSlot.morning), ['Ravi K']);
      expect(plannedOn(today, VisitSlot.afternoon), ['Venkatesh M']);
      expect(
        plannedOn(today.addDays(1), VisitSlot.morning),
        unorderedEquals(['Ravi K', 'Anil G']),
      );
      expect(
        plannedOn(today.addDays(2), VisitSlot.morning),
        unorderedEquals(['Venkat R', 'Sita R']),
      );
      expect(
        plannedOn(today.addDays(2), VisitSlot.afternoon),
        unorderedEquals(['Lakshmi N', 'Kumar B']),
      );
      expect(plannedOn(today.addDays(3), VisitSlot.morning), ['Padma S']);
      // Done today and yesterday.
      final doneDays = {
        for (final v in snap.visits)
          if (v.status == VisitStatus.done)
            snap.farmers.singleWhere((f) => f.id == v.farmerId).name!:
                LocalDate.istOf(v.visitedAt!),
      };
      expect(doneDays['Sita R'], today);
      expect(doneDays['Lakshmi N'], today.addDays(-1));
      expect(doneDays['Gopi M'], isNotNull);
    });

    test('alerts: new farmer, call-back, invoices and the HO note', () {
      final open = snap.alerts.where((a) => a.status == AlertStatus.open);
      final kinds = {for (final a in open) a.kind};
      expect(kinds, {
        AlertKind.newFarmer,
        AlertKind.callback,
        AlertKind.invoiceCheck,
        AlertKind.hoNote,
      });
      final raju = open.singleWhere((a) => a.kind == AlertKind.newFarmer);
      expect(raju.farmerId, MockBackend.rajuId);
      expect(raju.displayTitle(Language.te), contains('రాజు పి'));
      final note = open.singleWhere((a) => a.kind == AlertKind.hoNote);
      expect(
        note.body,
        'Please finish pending enrolments in Kondapur by Friday.',
      );
      expect(note.titleTe, isNull); // English-only HO note
      expect(snap.alerts.any((a) => a.status == AlertStatus.closed), isFalse);
      expect(
        snap.alerts.any((a) => a.status == AlertStatus.acknowledged),
        isTrue,
      );
    });

    test('masters: five crops in Telugu, SKUs, rules with and without SKU', () {
      final m = snap.masters;
      expect(m.version, 3);
      expect(m.crops.map((c) => c.nameTe), [
        'పత్తి',
        'వరి',
        'మిరప',
        'మొక్కజొన్న',
        'కంది',
      ]);
      for (final c in m.crops) {
        expect(c.stages, isNotEmpty, reason: c.code);
        expect(m.issuesForCrop(c.id), isNotEmpty, reason: c.code);
      }
      expect(
        m.skus.map((s) => s.productName),
        containsAll(['Sample 5 SG', 'Sample Nutri K']),
      );
      expect(m.rules.where((r) => r.skuId == null), isNotEmpty);
      expect(m.rules.where((r) => r.skuId != null), isNotEmpty);
      for (final r in m.rules) {
        expect(m.saltById(r.saltId), isNotNull);
        if (r.skuId != null) expect(m.skuById(r.skuId!), isNotNull);
      }
      final codes = seasonCodesOn(today);
      expect(m.seasonCodes.current, codes.current);
      expect(m.seasonCodes.allOpen, codes.allOpen);
      // Dev seed IDs.
      expect(MockBackend.kondapurId, '7ffb9494-9f19-5bbf-89c8-85c80065689f');
      expect(MockBackend.raviId, '0eeadea4-ce8c-518b-8d28-24b80819d868');
      expect(
        m.cropById(MockBackend.cottonId)!.stages[2].id,
        '5323a9b3-1d88-553f-af4c-d7885255125b',
      );
    });

    test('ETag "t{territory}-m{masters}", 304 when it matches', () async {
      expect(snap.etag, '"t12-m3"');
      final status = await w.repos.sync.getStatus();
      expect(status.etag, snap.etag);
      expect(status.territoryVersion, 12);
      final again = await w.repos.sync.getSnapshot(ifNoneMatch: snap.etag);
      expect(again, SnapshotNotModified(etag: snap.etag));
      final stale = await w.repos.sync.getSnapshot(ifNoneMatch: '"t1-m3"');
      expect(stale, isA<SnapshotFetched>());
      // Built fresh each time: equal, not the same objects.
      final fresh = (stale as SnapshotFetched).snapshot;
      expect(identical(fresh.farmers, snap.farmers), isFalse);
      expect(fresh.farmers, snap.farmers);
    });

    test('other FA and reset', () async {
      final other = await MockWorld.signedIn(
        code: MockBackend.otherFaCode,
        password: MockBackend.otherFaPassword,
      );
      final s = await other.snapshot();
      expect(
        s.farmers.map((f) => f.phone),
        contains(MockBackend.otherFaFarmerPhone),
      );
      expect(s.villages.map((v) => v.name), ['Chevella', 'Mudimyal']);

      w.backend.hoEditPlot(MockBackend.raviPlotId, label: 'Main plot');
      expect(w.backend.territoryVersion(), 13);
      w.backend.reset();
      expect(w.backend.territoryVersion(), 12);
      await expectLater(
        w.repos.sync.getStatus(),
        throwsApiError(ApiErrorCode.unauthorized),
      );
    });
  });

  group('commands', () {
    late MockWorld w;
    setUp(() async => w = await MockWorld.signedIn());

    EnrolFarmerPayload enrol({
      required String phone,
      String? farmerId,
      String? villageId,
      String? proof,
    }) => EnrolFarmerPayload(
      farmerId: farmerId ?? w.newId(),
      phone: phone,
      name: 'Test Farmer',
      nameTe: 'టెస్ట్ రైతు',
      language: Language.te,
      villageId: villageId ?? MockBackend.kondapurId,
      consent: EnrolConsent(
        purposes: const [ConsentPurpose.programme],
        otpProof: proof,
        audioPlayed: true,
        noticeVersion: MockBackend.consentNoticeVersion,
      ),
    );

    test('a new farmer is applied and the territory version moves', () async {
      final p = enrol(phone: '9876500001');
      final r = await w.push([p]);
      expect(r.complete, isTrue);
      expect(r.results.single.status, CommandStatus.applied);
      expect(r.results.single.entityId, p.farmerId);
      expect(r.territoryVersion, 13);
      final snap = await w.snapshot();
      final f = snap.farmers.singleWhere((f) => f.id == p.farmerId);
      expect(f.phone, '+919876500001');
      expect(f.source, FarmerSource.fa);
      expect(f.consentPending, isTrue); // no proof
    });

    test('a resend returns the stored result and changes nothing', () async {
      final cmd = enrol(phone: '9876500002').toCommandIn(id: w.newId());
      final first = await w.repos.sync.submitCommands([cmd]);
      final again = await w.repos.sync.submitCommands([cmd, cmd]);
      expect(again.results, [first.results.single, first.results.single]);
      expect(again.territoryVersion, first.territoryVersion);
      expect(w.backend.storedResult(cmd.id), first.results.single);
    });

    test('Raju P (self sign-up, no FA) is merged into his record', () async {
      final lookup = await w.repos.enrolment.lookupPhone('91234 56780');
      expect(lookup.status, PhoneLookupStatus.unassignedInMyArea);
      expect(lookup.farmerId, MockBackend.rajuId);
      final p = enrol(phone: MockBackend.rajuPhone);
      final r = (await w.push([p])).results.single;
      expect(r.status, CommandStatus.merged);
      expect(r.entityId, p.farmerId);
      expect(r.mergedInto, MockBackend.rajuId);
      final snap = await w.snapshot();
      final raju = snap.farmers.singleWhere((f) => f.id == MockBackend.rajuId);
      expect(raju.name, 'Raju P'); // his own answers win
      expect(raju.status, FarmerStatus.active);
      expect(snap.farmers, hasLength(47));
      expect(snap.alerts.where((a) => a.kind == AlertKind.newFarmer), isEmpty);
      // Commands queued under the minted ID follow the alias.
      final plot = await w.push([
        SavePlotPayload(
          plotId: w.newId(),
          farmerId: p.farmerId,
          label: 'Plot 1',
          pin: const LatLng(17.461, 78.356),
          areaAcres: 1.5,
          areaSource: AreaSource.typed,
        ),
      ]);
      expect(plot.results.single.status, CommandStatus.applied);
    });

    test('rejections: another FA, outside the area, deactivated', () async {
      final r = await w.push([
        enrol(phone: MockBackend.otherFaFarmerPhone),
        enrol(phone: '9876500003', villageId: MockBackend.madhapurId),
        enrol(phone: MockBackend.outsideAreaPhone),
        enrol(phone: MockBackend.deactivatedPhone),
        enrol(phone: '9876500004', villageId: w.newId()),
        enrol(phone: '12345'),
      ]);
      expect(r.results.map((x) => x.status).toSet(), {CommandStatus.rejected});
      expect(r.results.map((x) => x.error), [
        ApiErrorCode.registeredWithAnotherFa,
        ApiErrorCode.notInYourArea,
        ApiErrorCode.notInYourArea,
        contains('deactivated'),
        'village_id: unknown village',
        'phone: not a valid Indian mobile number',
      ]);
      expect(r.territoryVersion, 12);
    });

    test('unknown type, bad payload, future visit', () async {
      final ravi = (await w.snapshot()).seasons.firstWhere(
        (s) => s.id == MockBackend.raviSeasonId,
      );
      final r = await w.repos.sync.submitCommands([
        CommandIn(id: w.newId(), type: 'TeleportFarmer', payload: const {}),
        CommandIn(id: w.newId(), type: 'SavePlot', payload: const {'x': 1}),
        LogVisitPayload(
          visitId: w.newId(),
          farmerId: ravi.farmerId,
          plotId: ravi.plotId,
          seasonId: ravi.id,
          visitedAt: mockTestNow.add(const Duration(hours: 1)),
          farmerPresent: true,
        ).toCommandIn(id: w.newId()),
      ]);
      expect(r.results[0].error, 'unknown command type "TeleportFarmer"');
      expect(r.results[1].error, startsWith('invalid payload'));
      expect(r.results[2].error, 'visited_at is in the future');
      expect(
        r.results.every((x) => x.status == CommandStatus.rejected),
        isTrue,
      );
    });

    test('a stale plot version is a conflict with yours and theirs', () async {
      final snap = await w.snapshot();
      final plot = snap.plots.singleWhere(
        (p) => p.id == MockBackend.raviPlotId,
      );
      w.backend.hoEditPlot(plot.id, areaAcres: 2.5);
      final r = (await w.push([
        SavePlotPayload(
          plotId: plot.id,
          farmerId: plot.farmerId,
          label: plot.label,
          pin: plot.pin,
          areaAcres: 2.2,
          areaSource: AreaSource.typed,
          expectedVersion: plot.version,
        ),
      ])).results.single;
      expect(r.status, CommandStatus.conflict);
      expect(
        r.conflict,
        const Conflict(field: 'area_acres', yours: 2.2, theirs: 2.5),
      );
      // With the current version it applies.
      final ok = await w.push([
        SavePlotPayload(
          plotId: plot.id,
          farmerId: plot.farmerId,
          label: plot.label,
          pin: plot.pin,
          areaAcres: 2.2,
          areaSource: AreaSource.typed,
          expectedVersion: plot.version + 1,
        ),
      ]);
      expect(ok.results.single.status, CommandStatus.applied);
    });

    test("syncConflict: Padma S's Plot 2, HO's 2 ac 0 gunta", () async {
      w.backend.scenario = MockScenario.syncConflict;
      final snap = await w.snapshot();
      final plot2 = snap.plots.singleWhere(
        (p) => p.id == MockBackend.padmaPlot2Id,
      );
      SavePlotPayload edit(int version) => SavePlotPayload(
        plotId: plot2.id,
        farmerId: plot2.farmerId,
        label: plot2.label,
        pin: plot2.pin,
        areaAcres: guntasToAcres(70), // 1 ac 30 gunta
        areaSource: AreaSource.typed,
        expectedVersion: version,
      );
      final r = (await w.push([edit(plot2.version)])).results.single;
      expect(r.status, CommandStatus.conflict);
      expect(r.conflict!.field, 'area_acres');
      expect(r.conflict!.yours, 1.75);
      expect(r.conflict!.theirs, 2.0);
      // Keep mine: resend on top of HO's version.
      final mine = await w.push([edit(plot2.version + 1)]);
      expect(mine.results.single.status, CommandStatus.applied);
    });

    test(
      'UpdateFarmer: stale version conflicts only when values differ',
      () async {
        final ravi = (await w.snapshot()).farmers.singleWhere(
          (f) => f.id == MockBackend.raviId,
        );
        final r1 = await w.push([
          UpdateFarmerPayload(
            farmerId: ravi.id,
            expectedVersion: ravi.version,
            fields: const UpdateFarmerFields(nameTe: 'రవి కుమార్'),
          ),
        ]);
        expect(r1.results.single.status, CommandStatus.applied);
        final r2 = await w.push([
          UpdateFarmerPayload(
            farmerId: ravi.id,
            expectedVersion: ravi.version, // stale now
            fields: const UpdateFarmerFields(nameTe: 'రవి కుమార్'),
          ),
          UpdateFarmerPayload(
            farmerId: ravi.id,
            expectedVersion: ravi.version,
            fields: const UpdateFarmerFields(name: 'Ravi Kumar'),
          ),
        ]);
        expect(r2.results[0].status, CommandStatus.applied);
        expect(r2.results[1].status, CommandStatus.conflict);
        expect(
          r2.results[1].conflict,
          const Conflict(field: 'name', yours: 'Ravi Kumar', theirs: 'Ravi K'),
        );
      },
    );

    test('syncConflict also covers UpdateFarmer for Padma S', () async {
      w.backend.scenario = MockScenario.syncConflict;
      final padma = w.backend.farmerByPhone(MockBackend.padmaPhone)!;
      final r = (await w.push([
        UpdateFarmerPayload(
          farmerId: padma.id,
          expectedVersion: padma.version,
          fields: const UpdateFarmerFields(name: 'Padma Sri'),
        ),
      ])).results.single;
      expect(r.status, CommandStatus.conflict);
      expect(r.conflict!.field, 'name');
      expect(r.conflict!.yours, 'Padma Sri');
      // One-shot: the next edit on the new version applies.
      final again = await w.push([
        UpdateFarmerPayload(
          farmerId: padma.id,
          expectedVersion: padma.version + 1,
          fields: const UpdateFarmerFields(name: 'Padma Sri'),
        ),
      ]);
      expect(again.results.single.status, CommandStatus.applied);
    });

    test('StartSeason on a plot with an active season conflicts', () async {
      final r = (await w.push([
        StartSeasonPayload(
          seasonId: w.newId(),
          farmerId: MockBackend.raviId,
          plotId: MockBackend.raviPlotId,
          seasonCode: seasonCodesOn(today).current,
          cropId: MockBackend.chilliId,
        ),
      ])).results.single;
      expect(r.status, CommandStatus.conflict);
      expect(r.conflict!.field, 'active_season');
    });

    test('another FA\'s farmer is refused for plots and visits', () async {
      final narsimha = w.backend.farmerByPhone(MockBackend.otherFaFarmerPhone)!;
      final r = await w.push([
        SavePlotPayload(
          plotId: w.newId(),
          farmerId: narsimha.id,
          label: 'Plot 9',
          pin: const LatLng(17.3, 78.1),
          areaAcres: 1,
          areaSource: AreaSource.typed,
        ),
      ]);
      expect(r.results.single.error, 'this farmer is not assigned to you');
    });

    test(
      'enrol chain offline: farmer, plot, season, visit with advice',
      () async {
        final farmerId = w.newId();
        final plotId = w.newId();
        final seasonId = w.newId();
        final visitId = w.newId();
        final nextId = w.newId();
        final ring = [
          const LatLng(17.4600, 78.3570),
          const LatLng(17.4600, 78.3580),
          const LatLng(17.4610, 78.3580),
          const LatLng(17.4610, 78.3570),
        ];
        final m = (await w.snapshot()).masters;
        final cotton = m.cropById(MockBackend.cottonId)!;
        final r = await w.push([
          enrol(phone: '9876500010', farmerId: farmerId),
          SavePlotPayload(
            plotId: plotId,
            farmerId: farmerId,
            label: 'Plot 1',
            boundaryGeoJson: polygonGeoJson(ring),
            pin: ring.first,
            areaAcres: 0,
            areaSource: AreaSource.boundary,
            gpsAccuracyM: 4,
          ),
          StartSeasonPayload(
            seasonId: seasonId,
            farmerId: farmerId,
            plotId: plotId,
            seasonCode: seasonCodesOn(today).current,
            cropId: cotton.id,
            sowingDate: today.addDays(-60),
          ),
          LogVisitPayload(
            visitId: visitId,
            farmerId: farmerId,
            plotId: plotId,
            seasonId: seasonId,
            visitedAt: mockTestNow,
            farmerPresent: true,
            stageId: cotton.stageAt(60)!.id,
            issues: [
              LogVisitIssue(
                issueVisitId: w.newId(),
                issueId: MockBackend.pinkBollwormId,
                severity: Severity.high,
                advisoryRuleId: MockBackend.pinkBollwormRuleId,
              ),
              LogVisitIssue(
                issueVisitId: w.newId(),
                issueId: MockBackend.pinkBollwormId,
                severity: Severity.low,
                advisoryRuleId: MockBackend.leafSpotRuleId, // wrong issue
              ),
            ],
            nextVisit: LogVisitNextVisit(
              visitId: nextId,
              plannedFor: today.addDays(7),
              plannedSlot: VisitSlot.morning,
            ),
          ),
        ]);
        expect(r.results.map((x) => x.status).toSet(), {CommandStatus.applied});
        expect(r.territoryVersion, 16);
        final snap = await w.snapshot();
        final plot = snap.plots.singleWhere((p) => p.id == plotId);
        expect(plot.areaSource, AreaSource.boundary);
        expect(plot.areaAcres, closeTo(2.94, 0.05)); // ~107 m x 111 m
        final visit = snap.visits.singleWhere((v) => v.id == visitId);
        expect(visit.status, VisitStatus.done);
        expect(visit.stageName, 'Flowering');
        expect(visit.issues[0].adviceStatus, AdviceStatus.given);
        expect(visit.issues[0].productName, 'Sample 5 SG');
        expect(visit.issues[1].adviceStatus, AdviceStatus.unresolved);
        expect(visit.issues[1].saltId, isNull);
        final next = snap.visits.singleWhere((v) => v.id == nextId);
        expect(next.status, VisitStatus.planned);
        expect(next.plannedFor, today.addDays(7));
      },
    );

    test('logging Ravi\'s visit closes his call-back and its alert', () async {
      final snap = await w.snapshot();
      final planned = snap.visits.singleWhere(
        (v) =>
            v.farmerId == MockBackend.raviId &&
            v.status == VisitStatus.planned &&
            v.plannedFor == today,
      );
      final r = await w.push([
        LogVisitPayload(
          visitId: planned.id,
          farmerId: planned.farmerId,
          plotId: planned.plotId,
          seasonId: planned.seasonId,
          visitedAt: mockTestNow,
          farmerPresent: true,
        ),
      ]);
      expect(r.results.single.status, CommandStatus.applied);
      final after = await w.snapshot();
      expect(
        after.callbacks.map((c) => c.farmerId),
        isNot(contains(MockBackend.raviId)),
      );
      expect(
        after.alerts.where(
          (a) =>
              a.kind == AlertKind.callback && a.farmerId == MockBackend.raviId,
        ),
        isEmpty,
      );
      expect(
        after.visits.singleWhere((v) => v.id == planned.id).status,
        VisitStatus.done,
      );
      // Cancelling it now is refused.
      final cancel = await w.push([CancelVisitPayload(visitId: planned.id)]);
      expect(
        cancel.results.single.error,
        'visit is already logged and cannot be cancelled',
      );
    });

    test('PlanVisit with a known visit ID re-plans it', () async {
      final snap = await w.snapshot();
      final planned = snap.visits.firstWhere(
        (v) => v.status == VisitStatus.planned,
      );
      PlanVisitPayload plan({
        required LocalDate day,
        String? plotId,
        VisitSlot slot = VisitSlot.afternoon,
      }) => PlanVisitPayload(
        visitId: planned.id,
        farmerId: planned.farmerId,
        plotId: plotId ?? planned.plotId,
        seasonId: planned.seasonId,
        plannedFor: day,
        plannedSlot: slot,
        purpose: 'Check flowering',
      );
      final newDay = today.addDays(5);
      final r = await w.push([plan(day: newDay), plan(day: newDay)]);
      expect(r.results.map((x) => x.status), [
        CommandStatus.applied,
        CommandStatus.applied,
      ]);
      expect(r.results.first.entityId, planned.id);
      final after = await w.snapshot();
      expect(after.visits, hasLength(snap.visits.length), reason: 'same visit');
      final moved = after.visits.singleWhere((v) => v.id == planned.id);
      expect(moved.status, VisitStatus.planned);
      expect(moved.plannedFor, newDay);
      expect(moved.plannedSlot, VisitSlot.afternoon);
      expect(moved.purpose, 'Check flowering');

      // Another plot under the same ID, or a cancelled visit, is refused.
      final wrong = await w.push([plan(day: newDay, plotId: w.newId())]);
      expect(wrong.results.single.status, CommandStatus.rejected);
      await w.push([CancelVisitPayload(visitId: planned.id)]);
      final cancelled = await w.push([plan(day: today.addDays(6))]);
      expect(
        cancelled.results.single.error,
        'visit was cancelled; plan a new one',
      );
    });

    test('CancelVisit, CloseCallback, AckAlert', () async {
      final snap = await w.snapshot();
      final planned = snap.visits.firstWhere(
        (v) => v.status == VisitStatus.planned,
      );
      final callback = snap.callbacks.first;
      final alert = snap.alerts.firstWhere(
        (a) => a.kind == AlertKind.hoNote && a.status == AlertStatus.open,
      );
      final r = await w.push([
        CancelVisitPayload(visitId: planned.id, reason: 'farmer away'),
        CancelVisitPayload(visitId: planned.id),
        CloseCallbackPayload(callbackId: callback.id, note: 'Called'),
        AckAlertPayload(alertId: alert.id),
        AckAlertPayload(alertId: alert.id),
        AckAlertPayload(alertId: w.newId()),
      ]);
      expect(r.results.map((x) => x.status).toList(), [
        CommandStatus.applied,
        CommandStatus.applied,
        CommandStatus.applied,
        CommandStatus.applied,
        CommandStatus.applied,
        CommandStatus.rejected,
      ]);
      expect(r.results.last.error, 'alert not found');
      final after = await w.snapshot();
      expect(after.visits.map((v) => v.id), isNot(contains(planned.id)));
      expect(after.callbacks.map((c) => c.id), isNot(contains(callback.id)));
      expect(
        after.alerts.singleWhere((a) => a.id == alert.id).status,
        AlertStatus.acknowledged,
      );
    });

    test('partialFailure stops the next batch half way', () async {
      w.backend.scenario = MockScenario.partialFailure;
      final cmds = [
        for (var i = 0; i < 4; i++)
          enrol(phone: '98765000${20 + i}').toCommandIn(id: w.newId()),
      ];
      final first = await w.repos.sync.submitCommands(cmds);
      expect(first.retryFrom, 2);
      expect(first.results, hasLength(2));
      final rest = await w.repos.sync.submitCommands(cmds.sublist(2));
      expect(rest.complete, isTrue);
      expect(rest.results, hasLength(2));
    });

    test('RecordConsent with a proof clears consent pending', () async {
      final kumar = w.backend.farmerByPhone('+919000000109')!;
      expect(kumar.consentPending, isTrue);
      await w.repos.enrolment.requestConsentOtp(
        phone: kumar.phone,
        language: Language.te,
      );
      final proof = await w.repos.enrolment.verifyConsentOtp(
        phone: kumar.phone,
        code: MockBackend.fixedOtp,
      );
      final r = await w.push([
        RecordConsentPayload(
          farmerId: kumar.id,
          purposes: const [ConsentPurpose.programme],
          otpProof: proof.otpProof,
          audioPlayed: true,
          noticeVersion: 'v1',
        ),
        RecordConsentPayload(
          farmerId: MockBackend.raviId, // another phone
          purposes: const [ConsentPurpose.programme],
          otpProof: proof.otpProof,
          audioPlayed: true,
          noticeVersion: 'v1',
        ),
      ]);
      expect(r.results[0].status, CommandStatus.applied);
      expect(r.results[1].error, contains('another phone number'));
      expect(w.backend.farmerByPhone(kumar.phone)!.consentPending, isFalse);
    });

    test('an empty batch is a validation error', () async {
      await expectLater(
        w.repos.sync.submitCommands(const []),
        throwsApiError(ApiErrorCode.validationFailed, status: 400),
      );
    });
  });

  group('enrolment', () {
    late MockWorld w;
    setUp(() async => w = await MockWorld.signedIn());

    test('every lookup status', () async {
      Future<PhoneLookup> look(String phone) =>
          w.repos.enrolment.lookupPhone(phone);
      expect(
        await look('9876543210'),
        const PhoneLookup(status: PhoneLookupStatus.newFarmer),
      );
      expect(
        await look(MockBackend.raviPhone),
        PhoneLookup(
          status: PhoneLookupStatus.mine,
          farmerId: MockBackend.raviId,
        ),
      );
      expect(
        (await look(MockBackend.rajuPhone)).status,
        PhoneLookupStatus.unassignedInMyArea,
      );
      expect(
        await look(MockBackend.otherFaFarmerPhone),
        const PhoneLookup(status: PhoneLookupStatus.otherFa),
      );
      expect(
        await look(MockBackend.outsideAreaPhone),
        const PhoneLookup(status: PhoneLookupStatus.outsideMyArea),
      );
      expect(
        await look(MockBackend.deactivatedPhone),
        const PhoneLookup(status: PhoneLookupStatus.deactivated),
      );
      await expectLater(
        look('12345'),
        throwsApiError(ApiErrorCode.validationFailed),
      );
    });

    test('lookups are rate limited at 60 an hour', () async {
      for (var i = 0; i < 60; i++) {
        await w.repos.enrolment.lookupPhone('9876543210');
      }
      await expectLater(
        w.repos.enrolment.lookupPhone('9876543210'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', ApiErrorCode.rateLimited)
              .having((e) => e.retryAfter, 'retryAfter', isNotNull),
        ),
      );
    });

    test(
      'consent OTP: 123456, attempts left, resend wait, 7-day proof',
      () async {
        const phone = '9876543210';
        final sent = await w.repos.enrolment.requestConsentOtp(
          phone: phone,
          language: Language.te,
        );
        expect(sent.phoneMasked, maskPhone('+919876543210'));
        expect(sent.resendAfter, const Duration(seconds: 30));
        await expectLater(
          w.repos.enrolment.requestConsentOtp(
            phone: phone,
            language: Language.te,
          ),
          throwsApiError(ApiErrorCode.rateLimited, status: 429),
        );
        await expectLater(
          w.repos.enrolment.verifyConsentOtp(phone: phone, code: '000000'),
          throwsA(
            isA<ApiError>()
                .having((e) => e.code, 'code', ApiErrorCode.otpInvalid)
                .having((e) => e.attemptsLeft, 'attemptsLeft', 4),
          ),
        );
        final proof = await w.repos.enrolment.verifyConsentOtp(
          phone: phone,
          code: MockBackend.fixedOtp,
        );
        expect(proof.phone, '+919876543210');
        expect(proof.expiresAt, mockTestNow.add(const Duration(days: 7)));
        expect(proof.isValidAt(mockTestNow), isTrue);
        // Used once.
        await expectLater(
          w.repos.enrolment.verifyConsentOtp(
            phone: phone,
            code: MockBackend.fixedOtp,
          ),
          throwsApiError(ApiErrorCode.otpExpired),
        );
        // The proof records consent at enrolment.
        final farmerId = w.newId();
        final r = await w.push([
          EnrolFarmerPayload(
            farmerId: farmerId,
            phone: phone,
            name: 'Ramaiah K',
            language: Language.te,
            villageId: MockBackend.gachibowliId,
            consent: EnrolConsent(
              purposes: const [ConsentPurpose.programme],
              otpProof: proof.otpProof,
              audioPlayed: true,
              noticeVersion: 'v1',
            ),
          ),
        ]);
        expect(r.results.single.status, CommandStatus.applied);
        final f = w.backend.farmerByPhone(phone)!;
        expect(f.consentPending, isFalse);
        expect(f.consentsGranted, [ConsentPurpose.programme]);
      },
    );

    test('farmer photo: upload URL, PUT, limits', () async {
      final farmerId = w.newId();
      final up = await w.repos.enrolment.createFarmerPhotoUpload(
        farmerId: farmerId,
        contentType: PhotoContentType.jpeg,
        bytes: 120000,
      );
      expect(Uri.parse(up.url).host, MockBackend.mockHost);
      expect(up.method, 'PUT');
      expect(up.storageKey, startsWith('farmers/$farmerId/photo-'));
      await w.repos.photoUploader.upload(up, Uint8List(10));
      expect(w.backend.uploadedObjects[up.storageKey], 10);
      // Raju P signed himself up (no FA yet): his photo may go up before
      // the EnrolFarmer command lands.
      final raju = await w.repos.enrolment.createFarmerPhotoUpload(
        farmerId: MockBackend.rajuId,
        contentType: PhotoContentType.jpeg,
        bytes: 1000,
      );
      expect(raju.storageKey, startsWith('farmers/${MockBackend.rajuId}/'));
      // Another FA's farmer is refused.
      await expectLater(
        w.repos.enrolment.createFarmerPhotoUpload(
          farmerId: w.backend.farmerByPhone(MockBackend.otherFaFarmerPhone)!.id,
          contentType: PhotoContentType.jpeg,
          bytes: 1000,
        ),
        throwsApiError(ApiErrorCode.forbidden, status: 403),
      );
      await expectLater(
        w.repos.enrolment.createFarmerPhotoUpload(
          farmerId: farmerId,
          contentType: PhotoContentType.jpeg,
          bytes: 6 * 1024 * 1024,
        ),
        throwsApiError(ApiErrorCode.validationFailed),
      );
    });

    test('visit photos: URL after LogVisit, PUT, confirm', () async {
      final snap = await w.snapshot();
      final season = snap.seasons.firstWhere(
        (s) => s.id == MockBackend.raviSeasonId,
      );
      final visitId = w.newId();
      final photoId = w.newId();
      await w.push([
        LogVisitPayload(
          visitId: visitId,
          farmerId: season.farmerId,
          plotId: season.plotId,
          seasonId: season.id,
          visitedAt: mockTestNow,
          farmerPresent: true,
          photos: [
            LogVisitPhoto(photoId: photoId, contentType: PhotoContentType.jpeg),
          ],
        ),
      ]);
      await expectLater(
        w.repos.visitPhotos.createUploadUrl(
          visitId: visitId,
          photoId: w.newId(),
          contentType: PhotoContentType.jpeg,
          bytes: 1000,
        ),
        throwsApiError(ApiErrorCode.notFound, status: 404),
      );
      await expectLater(
        w.repos.visitPhotos.confirmUpload(visitId: visitId, photoId: photoId),
        throwsApiError(ApiErrorCode.uploadMissing, status: 409),
      );
      final up = await w.repos.visitPhotos.createUploadUrl(
        visitId: visitId,
        photoId: photoId,
        contentType: PhotoContentType.jpeg,
        bytes: 2048,
      );
      expect(up.storageKey, 'visits/$visitId/$photoId.jpg');
      await w.repos.photoUploader.upload(up, Uint8List(2048));
      final photo = await w.repos.visitPhotos.confirmUpload(
        visitId: visitId,
        photoId: photoId,
        sha256: 'a' * 64,
      );
      expect(photo.uploadedAt, mockTestNow);
      expect(photo.bytes, 2048);
      // Idempotent confirm; a new URL is refused.
      await w.repos.visitPhotos.confirmUpload(
        visitId: visitId,
        photoId: photoId,
      );
      await expectLater(
        w.repos.visitPhotos.createUploadUrl(
          visitId: visitId,
          photoId: photoId,
          contentType: PhotoContentType.jpeg,
          bytes: 2048,
        ),
        throwsApiError(ApiErrorCode.photoAlreadyUploaded, status: 409),
      );
      // An expired URL is refused by storage.
      final up2 = await w.repos.enrolment.createFarmerPhotoUpload(
        farmerId: MockBackend.raviId,
        contentType: PhotoContentType.png,
        bytes: 10,
      );
      w.clock.advance(const Duration(minutes: 16));
      await expectLater(
        w.repos.photoUploader.upload(up2, Uint8List(10)),
        throwsApiError(ApiErrorCode.forbidden),
      );
    });
  });

  group('alerts', () {
    late MockWorld w;
    setUp(() async => w = await MockWorld.signedIn());

    test('newest first, paged, with the farmer name and phone', () async {
      final first = await w.repos.alerts.listAlerts(limit: 3);
      expect(first.items, hasLength(3));
      expect(first.hasMore, isTrue);
      expect(first.items.first.alert.kind, AlertKind.newFarmer);
      expect(first.items.first.farmerName, 'Raju P');
      expect(first.items.first.farmerPhone, MockBackend.rajuPhone);
      expect(first.items[1].farmerName, 'Ravi K');
      final all = <FaAlert>[...first.items];
      var cursor = first.nextCursor;
      while (cursor != null) {
        final page = await w.repos.alerts.listAlerts(limit: 3, cursor: cursor);
        all.addAll(page.items);
        cursor = page.nextCursor;
      }
      expect(all.map((a) => a.id).toSet(), hasLength(all.length));
      expect(all, hasLength(w.backend.serverAlerts.length));
      for (var i = 1; i < all.length; i++) {
        expect(
          all[i].alert.createdAt.isAfter(all[i - 1].alert.createdAt),
          isFalse,
        );
      }
      final open = await w.repos.alerts.listAlerts(status: AlertStatus.open);
      expect(
        open.items.every((a) => a.alert.status == AlertStatus.open),
        isTrue,
      );
      await expectLater(
        w.repos.alerts.listAlerts(cursor: 'not a cursor!'),
        throwsApiError(ApiErrorCode.invalidCursor, status: 400),
      );
      await expectLater(
        w.repos.alerts.listAlerts(limit: 201),
        throwsApiError(ApiErrorCode.validationFailed),
      );
    });

    test('addAlert and addCallback reach the next snapshot', () async {
      final before = await w.repos.sync.getStatus();
      final note = w.backend.addAlert(
        title: 'Seed stock',
        body: 'New cotton seed stock at the Kondapur dealer.',
      );
      final cb = w.backend.addCallback(MockBackend.venkatId);
      final after = await w.repos.sync.getStatus();
      expect(after.etag, isNot(before.etag));
      final snap = await w.snapshot();
      expect(snap.alerts.map((a) => a.id), contains(note.id));
      expect(snap.callbacks.map((c) => c.id), contains(cb.id));
      expect(
        snap.alerts.where(
          (a) => a.kind == AlertKind.callback && a.refId == cb.id,
        ),
        hasLength(1),
      );
    });
  });
}
