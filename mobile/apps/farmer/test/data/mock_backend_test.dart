import 'dart:convert';

import 'package:farmer/src/data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import 'repository_contract.dart' show throwsApiError;

void main() {
  late MockBackend backend;
  late FarmerRepositories repos;

  late FixedClock clock;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 11, 1, 5));
    backend = MockBackend(
      clock: clock,
      latency: Duration.zero,
      slowLatency: const Duration(milliseconds: 60),
    );
    repos = backend.repositories(InMemorySessionStore());
  });

  Future<void> signInRavi() async {
    await repos.auth.requestOtp(
      phone: MockBackend.raviPhone,
      language: Language.te,
    );
    await repos.auth.verifyOtp(
      phone: MockBackend.raviPhone,
      code: MockBackend.fixedOtp,
      device: const DeviceInfo(deviceKey: 'mock-test-device'),
    );
  }

  group('seed data', () {
    setUp(signInRavi);

    test('Ravi K: Kondapur, cotton, FA Suresh, next visit tomorrow', () async {
      final home = await repos.profile.getHome();
      expect(home.farmer.name, 'Ravi K');
      expect(home.farmer.displayName(Language.te), 'రవి కె');
      expect(home.farmer.plan, Plan.free);
      expect(home.village?.nameTe, 'కొండాపూర్');
      expect(home.village?.mandalName, 'Serilingampally');
      expect(home.fa?.code, 'FA-KDP-014');
      expect(home.fa?.displayName(Language.te), 'సురేష్ కె');
      final plot = home.plots.single;
      expect(plot.plot.areaAcres, 2.5);
      expect(
        AcresGuntas.fromAcres(plot.plot.areaAcres),
        const AcresGuntas(2, 20),
      );
      expect(plot.activeSeason?.seasonCode, 'kharif-2026');
      // Sown 1 Jul 2026; 1 Nov 2026 is day 123: picking.
      expect(plot.daysAfterSowing, 123);
      expect(plot.currentStage?.code, 'picking');
      expect(home.nextVisit?.plannedFor, LocalDate(2026, 11, 2));
      expect(home.nextVisit?.plannedSlot, PlannedSlot.morning);
    });

    test('visits match the wireframes: product, product, salt only', () async {
      final page = await repos.visits.listVisits();
      expect(page.items, hasLength(5));
      // Cotton sown 1 Jul 2026: days 103, 89, 70, 50 and 24.
      expect(page.items.map((v) => v.stageName), [
        'Boll development',
        'Boll development',
        'Flowering',
        'Square formation',
        'Square formation',
      ]);
      final issues = page.items.take(3).map((v) => v.issues.single).toList();
      expect(issues[0].issueNameTe, 'గులాబీ రంగు పురుగు');
      expect(issues[0].productName, 'Sample 5 SG');
      expect(issues[0].severity, Severity.moderate);
      expect(issues[1].issueName, 'Sucking pests');
      expect(issues[1].productName, 'Sample 50 WG');
      expect(issues[2].issueName, 'Leaf spot');
      expect(issues[2].saltOnly, isTrue);
      expect(issues[2].skuId, isNull);
      expect(issues[2].saltName, 'Mancozeb 75% WP');
      expect(page.items[3].issues.single.advicePending, isTrue);
      expect(page.items[4].issues, isEmpty);

      final next = await repos.visits.getNextVisit();
      expect(next?.fa?.name, 'Suresh K');
      expect(next?.purpose, 'Check bollworm traps');
    });

    test('inbox: 3 new, pinned visit advice, audio on HO advisories', () async {
      expect(await repos.notices.getUnreadCount(), 3);
      final notices = (await repos.notices.listNotices()).items;
      expect(
        notices.where((n) => n.pinned).single.titleTe,
        'మీ పత్తి కాయ దశలో ఉంది',
      );
      final ho = notices.firstWhere((n) => n.sender == NoticeSender.ho);
      expect(ho.audioUrl, contains(MockBackend.mockHost));
      expect(ho.title(Language.en), 'Pink bollworm watch');
    });

    test('Look for FAs: one row per level, my FA first', () async {
      final all = await repos.fieldAssistants.listFas();
      expect(all.map((o) => o.fa.code), [
        'FA-KDP-014',
        'FA-SLP-003',
        'FA-RR-001',
      ]);
      expect(all.first.isMyFa, isTrue);
      expect(all.first.isLead, isTrue);
      final mandal = await repos.fieldAssistants.listFas(
        level: AreaLevel.mandal,
      );
      expect(mandal.single.fa.name, 'Ramesh B');
    });

    test('a season sown in the future: negative days, no stage', () async {
      final home = await repos.profile.getHome();
      final plotId = home.plots.single.plot.id;
      final season = home.plots.single.activeSeason!;
      await repos.profile.closeSeason(
        seasonId: season.id,
        outcome: SeasonOutcome.harvested,
      );
      await repos.profile.startSeason(
        plotId: plotId,
        seasonCode: 'rabi-2026-27',
        cropId: season.cropId,
        sowingDate: LocalDate(2026, 11, 4),
      );

      final plot = (await repos.profile.getHome()).plots.single;
      expect(plot.daysAfterSowing, -3);
      expect(plot.currentStage, isNull);
    });

    test('past the last stage: still the last one, like the server', () async {
      // Cotton sown 1 Jul 2026 lasts about 160 days; 1 Feb 2027 is day 215.
      clock.set(DateTime.utc(2027, 2, 1, 5));
      final plot = (await repos.profile.getHome()).plots.single;
      expect(plot.daysAfterSowing, 215);
      expect(plot.currentStage?.code, 'picking');
    });

    test('crops mirror the seed and season codes follow the clock', () async {
      final crops = await repos.masters.listCrops();
      expect(crops.items.map((c) => c.code), ['cotton', 'paddy', 'chilli']);
      expect(crops.byId(crops.items.first.id)?.stages, hasLength(5));
      expect(crops.seasonCodes.current, 'rabi-2026-27');
      expect(crops.seasonCodes.allOpen, [
        'kharif-2026',
        'rabi-2026-27',
        'summer-2027',
      ]);
    });

    test('dealers filter by SKU and radius', () async {
      const near = LatLng(17.4612, 78.3555);
      final all = await repos.masters.listNearbyDealers(near: near);
      expect(all.first.name, 'Sri Sai Agro Traders');
      expect(all.first.distanceM, lessThan(1000));
      final fl = await repos.masters.listNearbyDealers(
        near: near,
        skuId: 'ab451b02-dc75-55fe-98d8-be157e8dca90',
      );
      expect(fl.single.name, 'Raithu Mitra Traders');
      final tight = await repos.masters.listNearbyDealers(
        near: near,
        radiusKm: 0.5,
      );
      expect(tight.single.name, 'Sri Sai Agro Traders');
    });
  });

  group('server behaviour', () {
    test('season start checks the plot before the crop', () async {
      await signInRavi();
      final crops = await repos.masters.listCrops();
      await expectLater(
        repos.profile.startSeason(
          plotId: '99d707d8-1d63-59ea-bf0e-ada3da7dd10e', // not Ravi's
          seasonCode: 'kharif-2026',
          cropId: 'not-a-crop',
        ),
        throwsApiError(ApiErrorCode.notFound, status: 404),
      );
      final plot = (await repos.profile.getHome()).plots.single;
      await expectLater(
        repos.profile.startSeason(
          plotId: plot.plot.id,
          seasonCode: 'rabi-2026-27',
          cropId: 'not-a-crop',
        ),
        throwsApiError(ApiErrorCode.activeSeasonExists, status: 409),
        reason: 'the active season is checked before the crop',
      );
      await repos.profile.closeSeason(
        seasonId: plot.activeSeason!.id,
        outcome: SeasonOutcome.abandoned,
      );
      await expectLater(
        repos.profile.startSeason(
          plotId: plot.plot.id,
          seasonCode: 'rabi-2026-27',
          cropId: crops.items.first.id,
          previousCropId: 'not-a-crop',
        ),
        throwsA(
          isA<ApiError>().having(
            (e) => e.details['fields'],
            'fields',
            containsPair('previous_crop_id', 'unknown crop'),
          ),
        ),
      );
    });

    test(
      'a stale cursor gives an empty last page, a malformed one 400',
      () async {
        await signInRavi();
        final first = await repos.visits.listVisits(limit: 2);
        expect(first.nextCursor, isNotNull);
        final second = await repos.visits.listVisits(
          limit: 2,
          cursor: first.nextCursor,
        );
        expect(
          second.items.map((v) => v.id),
          isNot(contains(first.items[0].id)),
        );

        backend.scenario = MockScenario.noVisits;
        final stale = await repos.visits.listVisits(cursor: first.nextCursor);
        expect(stale.items, isEmpty);
        expect(stale.nextCursor, isNull);

        backend.scenario = MockScenario.normal;
        // Not base64url; base64url of "not-a-cursor"; of "1:x" (no UUID).
        for (final bad in ['mock-visits-2!', 'bm90LWEtY3Vyc29y', 'MTp4']) {
          await expectLater(
            repos.visits.listVisits(cursor: bad),
            throwsApiError(ApiErrorCode.invalidCursor, status: 400),
          );
        }
      },
    );

    test('cursors are unpadded base64url, as the server reads them', () async {
      await signInRavi();
      final first = await repos.visits.listVisits(limit: 2);
      final cursor = first.nextCursor!;
      expect(cursor, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      final second = await repos.visits.listVisits(limit: 2, cursor: cursor);

      // The same cursor padded is refused, like any character outside the
      // base64url alphabet.
      final padded = base64Url.normalize(cursor);
      expect(padded, isNot(cursor), reason: 'this cursor needs padding');
      for (final bad in [padded, '$cursor+', '$cursor/', ' $cursor']) {
        await expectLater(
          repos.visits.listVisits(limit: 2, cursor: bad),
          throwsApiError(ApiErrorCode.invalidCursor, status: 400),
          reason: bad,
        );
      }
      // An empty cursor is the first page.
      final again = await repos.visits.listVisits(limit: 2, cursor: '');
      expect(again.items.map((v) => v.id), first.items.map((v) => v.id));
      expect(second.items, isNotEmpty);
    });

    test('the access token is the one sent when the call started', () async {
      backend.latency = const Duration(milliseconds: 30);
      final store = InMemorySessionStore();
      final repos = backend.repositories(store);
      await repos.auth.requestOtp(
        phone: MockBackend.raviPhone,
        language: Language.te,
      );
      await repos.auth.verifyOtp(
        phone: MockBackend.raviPhone,
        code: MockBackend.fixedOtp,
        device: const DeviceInfo(deviceKey: 'mock-test-device'),
      );

      final home = repos.profile.getHome();
      await Future<void>.delayed(Duration.zero);
      await store.clearSession(); // signed out while the call is on the wire
      expect((await home).farmer.phone, MockBackend.raviPhone);
    });

    test('a sign-in does not reset the hourly OTP limit', () async {
      final clock = backend.clock as FixedClock;
      const phone = '9000000556';
      for (var i = 0; i < 4; i++) {
        await repos.auth.requestOtp(phone: phone, language: Language.te);
        clock.advance(const Duration(seconds: 31));
      }
      await repos.auth.requestOtp(phone: phone, language: Language.en);
      expect(backend.otpLanguage(phone), Language.en);
      await repos.auth.verifyOtp(
        phone: phone,
        code: MockBackend.fixedOtp,
        device: const DeviceInfo(deviceKey: 'mock-test-device'),
      );
      expect(backend.otpLanguage(phone), isNull, reason: 'code used up');
      clock.advance(const Duration(seconds: 31));
      await expectLater(
        repos.auth.requestOtp(phone: phone, language: Language.te),
        throwsApiError(ApiErrorCode.rateLimited, status: 429),
      );
    });

    test('master data cannot be changed, so no backend can leak into '
        'another', () async {
      await signInRavi();
      final crops = await repos.masters.listCrops();
      expect(
        () => crops.items.first.stages.add(crops.items.first.stages.first),
        throwsUnsupportedError,
      );
      expect(() => crops.items.first.stages.clear(), throwsUnsupportedError);
      final other = MockBackend(latency: Duration.zero)..reset();
      final otherRepos = other.repositories(InMemorySessionStore());
      await otherRepos.auth.requestOtp(
        phone: MockBackend.raviPhone,
        language: Language.te,
      );
      await otherRepos.auth.verifyOtp(
        phone: MockBackend.raviPhone,
        code: MockBackend.fixedOtp,
        device: const DeviceInfo(deviceKey: 'mock-test-device'),
      );
      expect(
        (await otherRepos.masters.listCrops()).items.first.stages,
        hasLength(5),
      );
    });

    test('refresh: a retry in the grace window, then reuse ends it', () async {
      final clock = backend.clock as FixedClock;
      final store = InMemorySessionStore();
      final repos = backend.repositories(store);
      await repos.auth.requestOtp(
        phone: MockBackend.raviPhone,
        language: Language.te,
      );
      await repos.auth.verifyOtp(
        phone: MockBackend.raviPhone,
        code: MockBackend.fixedOtp,
        device: const DeviceInfo(deviceKey: 'mock-test-device'),
      );
      final first = (await store.readSession())!;
      final second = await repos.auth.refreshSession();

      clock.advance(const Duration(seconds: 59));
      await store.writeSession(first);
      expect(
        (await repos.auth.refreshSession()).refreshToken,
        second.refreshToken,
      );

      clock.advance(const Duration(seconds: 2));
      await store.writeSession(first);
      await expectLater(
        repos.auth.refreshSession(),
        throwsApiError(ApiErrorCode.refreshReused, status: 401),
      );
      // The whole session ended: the successor no longer refreshes.
      await store.writeSession(first.withTokens(second));
      await expectLater(
        repos.auth.refreshSession(),
        throwsApiError(ApiErrorCode.unauthorized, status: 401),
      );
    });
  });

  group('shared state', () {
    test(
      'a call-back and a consent are seen by other repository sets',
      () async {
        final store = InMemorySessionStore();
        final a = backend.repositories(store);
        final b = backend.repositories(
          store,
        ); // e.g. another screen's providers
        await a.auth.requestOtp(
          phone: MockBackend.raviPhone,
          language: Language.te,
        );
        await a.auth.verifyOtp(
          phone: MockBackend.raviPhone,
          code: MockBackend.fixedOtp,
          device: const DeviceInfo(deviceKey: 'mock-test-device'),
        );
        final c = await a.fieldAssistants.requestCallback();
        expect((await b.fieldAssistants.getOpenCallback())?.id, c.id);
        await a.profile.setConsent(
          purpose: ConsentPurpose.soilPartner,
          granted: false,
          noticeVersion: 'v1',
        );
        final consents = await b.profile.listConsents();
        expect(
          consents
              .firstWhere((x) => x.purpose == ConsentPurpose.soilPartner)
              .granted,
          isFalse,
        );
      },
    );

    test('reset drops changes', () async {
      await signInRavi();
      await repos.fieldAssistants.requestCallback();
      backend.reset();
      await signInRavi();
      expect(await repos.fieldAssistants.getOpenCallback(), isNull);
    });

    test('a sign-up in a village without a lead FA gets no FA', () async {
      await repos.auth.requestOtp(phone: '9123456789', language: Language.te);
      await repos.auth.verifyOtp(
        phone: '9123456789',
        code: MockBackend.fixedOtp,
        device: const DeviceInfo(deviceKey: 'mock-test-device'),
      );
      final madhapur = (await repos.geo.searchVillages(query: 'madh')).single;
      final f = await repos.profile.completeProfile(
        name: 'New Farmer',
        language: Language.te,
        villageId: madhapur.id,
      );
      expect(f.assignedFaId, isNull);
      expect((await repos.profile.getHome()).fa, isNull);
      await expectLater(
        repos.fieldAssistants.requestCallback(),
        throwsApiError(ApiErrorCode.noFaAssigned, status: 409),
      );
      // Non-lead FAs still show in Look for FAs.
      expect(await repos.fieldAssistants.listFas(), hasLength(2));
    });

    test('OTP: five wrong codes use the code up; five sends an hour', () async {
      final clock = backend.clock as FixedClock;
      const phone = '9000000555';
      await repos.auth.requestOtp(phone: phone, language: Language.te);
      for (var left = 4; left >= 0; left--) {
        await expectLater(
          repos.auth.verifyOtp(
            phone: phone,
            code: '999999',
            device: const DeviceInfo(deviceKey: 'mock-test-device'),
          ),
          throwsA(isA<ApiError>().having((e) => e.attemptsLeft, 'left', left)),
        );
      }
      await expectLater(
        repos.auth.verifyOtp(
          phone: phone,
          code: MockBackend.fixedOtp,
          device: const DeviceInfo(deviceKey: 'mock-test-device'),
        ),
        throwsApiError(ApiErrorCode.otpExpired),
      );
      for (var i = 0; i < 4; i++) {
        clock.advance(const Duration(seconds: 31));
        await repos.auth.requestOtp(phone: phone, language: Language.te);
      }
      clock.advance(const Duration(seconds: 31));
      await expectLater(
        repos.auth.requestOtp(phone: phone, language: Language.te),
        throwsApiError(ApiErrorCode.rateLimited, status: 429),
      );
      // The code expires after 5 minutes.
      clock.advance(const Duration(hours: 1));
      await repos.auth.requestOtp(phone: phone, language: Language.te);
      clock.advance(const Duration(minutes: 6));
      await expectLater(
        repos.auth.verifyOtp(
          phone: phone,
          code: MockBackend.fixedOtp,
          device: const DeviceInfo(deviceKey: 'mock-test-device'),
        ),
        throwsApiError(ApiErrorCode.otpExpired),
      );
    });
  });

  group('scenarios', () {
    setUp(signInRavi);

    test('offline: every call throws the network error', () async {
      backend.scenario = MockScenario.offline;
      final calls = <Future<Object?> Function()>[
        repos.auth.getAppConfig,
        repos.profile.getHome,
        repos.profile.listConsents,
        repos.fieldAssistants.listFas,
        repos.fieldAssistants.requestCallback,
        repos.visits.listVisits,
        repos.visits.getNextVisit,
        repos.notices.listNotices,
        repos.notices.getUnreadCount,
        repos.geo.getGeoTree,
        repos.masters.listCrops,
      ];
      for (final call in calls) {
        await expectLater(call(), throwsApiError(ApiErrorCode.network));
      }
      final e = await repos.profile.getHome().then<ApiError?>(
        (_) => null,
        onError: (Object e) => e as ApiError,
      );
      expect(e?.isNetwork, isTrue);
      expect(e?.status, isNull);
      // Sign-out still works offline.
      await repos.auth.logout();
    });

    test('server error: 503, retryable', () async {
      backend.scenario = MockScenario.serverError;
      await expectLater(
        repos.profile.getHome(),
        throwsA(
          isA<ApiError>()
              .having((e) => e.status, 'status', 503)
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );
    });

    test('no FA assigned', () async {
      backend.scenario = MockScenario.noFaAssigned;
      final home = await repos.profile.getHome();
      expect(home.fa, isNull);
      expect(home.farmer.assignedFaId, isNull);
      expect(await repos.fieldAssistants.listFas(), isEmpty);
      await expectLater(
        repos.fieldAssistants.requestCallback(),
        throwsApiError(ApiErrorCode.noFaAssigned, status: 409),
      );
      backend.scenario = MockScenario.normal;
      expect((await repos.profile.getHome()).fa, isNotNull);
    });

    test('no visits', () async {
      backend.scenario = MockScenario.noVisits;
      expect((await repos.visits.listVisits()).items, isEmpty);
      expect(await repos.visits.getNextVisit(), isNull);
      expect((await repos.profile.getHome()).nextVisit, isNull);
    });

    test('slow network adds the slow latency', () async {
      backend.scenario = MockScenario.slowNetwork;
      final watch = Stopwatch()..start();
      await repos.notices.getUnreadCount();
      expect(
        watch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 60)),
      );
    });

    test(
      'account paused: known farmers are inactive and cannot write',
      () async {
        backend.scenario = MockScenario.accountPaused;
        expect(
          (await repos.profile.getHome()).farmer.status,
          FarmerStatus.inactive,
        );
        await expectLater(
          repos.profile.updateProfile(name: 'X'),
          throwsApiError(ApiErrorCode.forbidden, status: 403),
        );
      },
    );

    test('session revoked: signed-in calls and refresh get 401 unauthorized, '
        'sign-in works', () async {
      final failures = <(String, String?)>[];
      final hook = AuthFailureHook()
        ..listen((e, {farmerId}) => failures.add((e.code, farmerId)));
      final store = InMemorySessionStore();
      final reporting = backend.repositories(store, authFailures: hook);
      await reporting.auth.requestOtp(
        phone: MockBackend.venkateshPhone,
        language: Language.te,
      );
      backend.scenario = MockScenario.sessionRevoked;
      final session = await reporting.auth.verifyOtp(
        phone: MockBackend.venkateshPhone,
        code: MockBackend.fixedOtp,
        device: const DeviceInfo(deviceKey: 'mock-revoked-device'),
      );
      expect(failures, isEmpty);

      await expectLater(
        reporting.profile.getHome(),
        throwsApiError(ApiErrorCode.unauthorized, status: 401),
      );
      await expectLater(
        reporting.auth.refreshSession(),
        throwsApiError(ApiErrorCode.unauthorized, status: 401),
      );
      expect(failures, [
        (ApiErrorCode.unauthorized, session.farmerId),
        (ApiErrorCode.unauthorized, session.farmerId),
      ]);
    });
  });

  group('providers', () {
    test('the scenario switch drives the backend', () async {
      final c = ProviderContainer.test(
        overrides: farmerDataOverrides(
          env: OrbitEnv.devMock,
          mockBackend: backend,
        ),
      );
      expect(c.read(mockScenarioProvider), MockScenario.normal);
      c.read(mockScenarioProvider.notifier).select(MockScenario.offline);
      expect(c.read(mockScenarioProvider), MockScenario.offline);
      expect(backend.scenario, MockScenario.offline);
      await expectLater(
        c.read(authRepositoryProvider).getAppConfig(),
        throwsApiError(ApiErrorCode.network),
      );
    });

    test('API data source is not built yet and says where to look', () {
      final c = ProviderContainer.test(
        overrides: farmerDataOverrides(
          env: OrbitEnv.parse(flavor: 'dev', dataSource: 'api'),
        ),
      );
      expect(c.read(mockBackendProvider), isNull);
      expect(c.read(mockScenarioProvider), isNull);
      expect(
        () => buildFarmerRepositories(
          OrbitEnv.parse(flavor: 'prod'),
          InMemorySessionStore(),
        ),
        throwsA(
          isA<UnimplementedError>().having(
            (e) => e.message,
            'message',
            contains('README'),
          ),
        ),
      );
    });

    test('retry policy: only server-side failures, twice', () {
      const unavailable = ApiError(
        code: ApiErrorCode.unavailable,
        message: 'down',
        status: 503,
      );
      expect(orbitRetry(0, unavailable), const Duration(seconds: 1));
      expect(orbitRetry(1, unavailable), const Duration(seconds: 2));
      expect(orbitRetry(2, unavailable), isNull);
      expect(orbitRetry(0, const ApiError.network()), isNull);
      expect(
        orbitRetry(
          0,
          const ApiError(
            code: ApiErrorCode.notFound,
            message: 'x',
            status: 404,
          ),
        ),
        isNull,
      );
      expect(orbitRetry(0, StateError('bug')), isNull);
    });
  });
}
