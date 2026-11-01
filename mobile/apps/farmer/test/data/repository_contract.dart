// Repository contract suite: written against the interfaces only, so the
// same tests run against the mock today and the API implementation later.
//
// Not a test file itself (no `_test` suffix). Run it from a test file:
//
//   void main() => runRepositoryContract('mock', createMockHarness);
//
// Against a dev backend (`make dev-up migrate backend-seed backend-run-api`
// plus `backend-run-worker`, DEV_FIXED_OTP=123456), write
// `api_repository_contract_test.dart` with a factory that builds the Api* set
// over a fresh InMemorySessionStore and AuthFailureHook and
// `ContractFixture.devSeed()`; see lib/src/data/README.md.
//
// Rules that keep it valid for a real server:
// * Only data the dev seed guarantees is asserted (Ravi K is active in
//   Kondapur with FA Suresh and a cotton plot; no logged visits or notices);
//   counts and contents that differ between mock and dev are checked for
//   shape, not value. A check whose data the seed may lack is skipped with a
//   reason, never passed silently.
// * The known farmer signs in once per group (OTP sends are rate limited per
//   phone); every other flow uses a fresh random phone.
// * Writes go to fresh self sign-ups. The seeded farmers' own data is never
//   changed, except Ravi's call-back, which the test leaves cancelled; but
//   signing in and the heartbeat still write session and device rows for
//   them (a new session per run, the device's last-seen time).
// * Every run adds self sign-ups (random phones) in Kondapur, so a dev
//   database used for many runs grows: more farmers in FA Suresh's
//   territory and work queue. The suite does not depend on their number. To
//   start over: `make backend-dev-reset` (deletes the data volume), then
//   `make dev-up migrate backend-seed` (`backend-seed` alone adds missing
//   seed rows and deletes nothing).
// * Work the server does in its worker (the welcome notice) is polled for, up
//   to `ContractFixture.asyncWait`.

import 'dart:math' as math;

import 'package:farmer/src/data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

/// Data the suite relies on; defaults match the dev seed and the mock.
class ContractFixture {
  /// Creates a fixture.
  ContractFixture({
    required this.knownPhone,
    required this.otp,
    required this.villageQuery,
    required this.villageWithLeadFa,
    this.asyncWait = const Duration(seconds: 10),
    math.Random? random,
  }) : _random = random ?? math.Random();

  /// The dev seed (`backend/cmd/seed`): Ravi K, OTP 123456, Kondapur.
  factory ContractFixture.devSeed({
    Duration asyncWait = const Duration(seconds: 10),
    math.Random? random,
  }) => ContractFixture(
    knownPhone: '+919000000101',
    otp: '123456',
    villageQuery: 'kond',
    villageWithLeadFa: '7ffb9494-9f19-5bbf-89c8-85c80065689f',
    asyncWait: asyncWait,
    random: random,
  );

  /// An active seeded farmer with an assigned FA.
  final String knownPhone;

  /// The fixed OTP (`DEV_FIXED_OTP`).
  final String otp;

  /// A search that finds [villageWithLeadFa].
  final String villageQuery;

  /// A village with a lead FA (Kondapur).
  final String villageWithLeadFa;

  /// How long to wait for work the server does in the background (the
  /// welcome notice after a sign-up).
  final Duration asyncWait;

  final math.Random _random;

  /// A random, valid phone that is very unlikely to exist yet.
  String newPhone() =>
      '+919${List.generate(9, (_) => _random.nextInt(10)).join()}';

  /// A random UUID that matches nothing.
  String unknownId() {
    String hex(int n) =>
        List.generate(n, (_) => _random.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }
}

/// One implementation under test, with a fresh session store.
class ContractHarness {
  /// Creates a harness. [repos] must report to [authFailures].
  ContractHarness({
    required this.repos,
    required this.store,
    required this.authFailures,
    required this.fixture,
    this.clock = const SystemClock(),
    this.closeCallbackAsFa,
  }) {
    authFailures.listen(
      (error, {farmerId}) => reported.add((error.code, farmerId)),
    );
  }

  /// The repositories under test.
  final FarmerRepositories repos;

  /// The store those repositories read and write.
  final SessionStore store;

  /// The hook [repos] report failures to.
  final AuthFailureHook authFailures;

  /// What [repos] reported to [authFailures] so far: (code, farmer ID).
  final reported = <(String, String?)>[];

  /// Test data.
  final ContractFixture fixture;

  /// The server's clock, for "today" in IST.
  final Clock clock;

  /// Closes a call-back as the FA would (mock only); tests that need it are
  /// skipped when null.
  final void Function(String callbackId)? closeCallbackAsFa;
}

/// Builds a fresh harness (new store; same or new backend).
typedef HarnessFactory = Future<ContractHarness> Function();

/// Matches an [ApiError] with [code] (and [status] when given).
Matcher throwsApiError(String code, {int? status}) => throwsA(
  isA<ApiError>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.status, 'status', status ?? anything),
);

const _device = DeviceInfo(deviceKey: 'contract-test-device-1');

/// Requests and verifies an OTP for [phone].
Future<FarmerSession> signIn(ContractHarness h, String phone) async {
  await h.repos.auth.requestOtp(phone: phone, language: Language.te);
  return h.repos.auth.verifyOtp(
    phone: phone,
    code: h.fixture.otp,
    device: _device,
  );
}

/// Signs up a new farmer in the village with a lead FA.
Future<Farmer> signUp(
  ContractHarness h, {
  String name = 'Contract Farmer',
}) async {
  final session = await signIn(h, h.fixture.newPhone());
  expect(session.farmerStatus, FarmerStatus.pendingProfile);
  await h.repos.profile.setConsent(
    purpose: ConsentPurpose.programme,
    granted: true,
    noticeVersion: 'v1',
  );
  return h.repos.profile.completeProfile(
    name: name,
    language: Language.te,
    villageId: h.fixture.villageWithLeadFa,
  );
}

/// Reads with [read] until [done] holds, for up to the fixture's
/// `asyncWait`; fails with [reason] when it never does.
Future<T> eventually<T>(
  ContractHarness h,
  Future<T> Function() read,
  bool Function(T value) done, {
  required String reason,
}) async {
  final deadline = DateTime.now().add(h.fixture.asyncWait);
  while (true) {
    final value = await read();
    if (done(value) || !DateTime.now().isBefore(deadline)) {
      expect(done(value), isTrue, reason: reason);
      return value;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

/// True when dotted version [a] is below [b] (`0.9.0` < `0.10.0`).
bool versionBelow(String a, String b) {
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < math.max(x.length, y.length); i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d < 0;
  }
  return false;
}

/// Registers the contract tests for one implementation.
void runRepositoryContract(String label, HarnessFactory create) {
  group('$label repository contract', () {
    group('auth', () {
      late ContractHarness h;
      setUp(() async => h = await create());

      test('app config', () async {
        final c = await h.repos.auth.getAppConfig();
        expect(c.app, 'farmer');
        expect(c.minVersion, isNotEmpty);
        expect(c.latestVersion, isNotEmpty);
      });

      test('OTP request masks the phone and sets the resend wait', () async {
        final phone = h.fixture.newPhone();
        final sent = await h.repos.auth.requestOtp(
          phone: phone.substring(3), // 10 digits, as typed
          language: Language.te,
        );
        expect(sent.phoneMasked, maskPhone(phone));
        expect(sent.resendAfter, greaterThan(Duration.zero));
        expect(sent.expiresIn, greaterThan(Duration.zero));
      });

      test('a resend inside the wait is rate limited', () async {
        final phone = h.fixture.newPhone();
        await h.repos.auth.requestOtp(phone: phone, language: Language.te);
        await expectLater(
          h.repos.auth.requestOtp(phone: phone, language: Language.en),
          throwsA(
            isA<ApiError>()
                .having((e) => e.code, 'code', ApiErrorCode.rateLimited)
                .having((e) => e.status, 'status', 429)
                .having((e) => e.retryAfter, 'retryAfter', isNotNull),
          ),
        );
      });

      test('a bad phone is a validation error', () async {
        await expectLater(
          h.repos.auth.requestOtp(phone: '1234567890', language: Language.te),
          throwsApiError(ApiErrorCode.validationFailed, status: 400),
        );
      });

      test('a wrong code says how many tries are left', () async {
        final phone = h.fixture.newPhone();
        await h.repos.auth.requestOtp(phone: phone, language: Language.te);
        final wrong = h.fixture.otp == '000000' ? '111111' : '000000';
        await expectLater(
          h.repos.auth.verifyOtp(phone: phone, code: wrong, device: _device),
          throwsA(
            isA<ApiError>()
                .having((e) => e.code, 'code', ApiErrorCode.otpInvalid)
                .having((e) => e.attemptsLeft, 'attemptsLeft', 4),
          ),
        );
        // The right code still works afterwards.
        final s = await h.repos.auth.verifyOtp(
          phone: phone,
          code: h.fixture.otp,
          device: _device,
        );
        expect(s.isNew, isTrue);
      });

      test('verifying without a live code is otp_expired', () async {
        await expectLater(
          h.repos.auth.verifyOtp(
            phone: h.fixture.newPhone(),
            code: h.fixture.otp,
            device: _device,
          ),
          throwsApiError(ApiErrorCode.otpExpired, status: 400),
        );
      });

      test('farmer calls without a session are unauthorized', () async {
        await expectLater(
          h.repos.profile.getHome(),
          throwsApiError(ApiErrorCode.unauthorized, status: 401),
        );
        await expectLater(
          h.repos.notices.getUnreadCount(),
          throwsApiError(ApiErrorCode.unauthorized, status: 401),
        );
      });

      test(
        'verify saves the session; refresh rotates; logout clears',
        () async {
          final s = await signIn(h, h.fixture.newPhone());
          final saved = await h.store.readSession();
          expect(saved?.farmerId, s.farmerId);
          expect(saved?.tokens, s.tokens);

          final next = await h.repos.auth.refreshSession();
          expect(next.refreshToken, isNot(s.tokens.refreshToken));
          expect((await h.store.readSession())?.tokens, next);
          await h.repos.profile.listConsents(); // the new token works

          await h.repos.auth.logout();
          expect(await h.store.readSession(), isNull);
          await expectLater(
            h.repos.profile.listConsents(),
            throwsApiError(ApiErrorCode.unauthorized),
          );
        },
      );

      test('a refresh token reused after its retry window ends the session '
          '(refresh_reused, reported)', () async {
        final s = await signIn(h, h.fixture.newPhone());
        final first = (await h.store.readSession())!;
        final second = await h.repos.auth.refreshSession();

        // A retry with the used token (a lost response) gets the same
        // successor.
        await h.store.writeSession(first);
        final retried = await h.repos.auth.refreshSession();
        expect(retried.refreshToken, second.refreshToken);

        // Once the successor was used too, the old token is a reuse.
        await h.repos.auth.refreshSession();
        await h.store.writeSession(first);
        h.reported.clear();
        await expectLater(
          h.repos.auth.refreshSession(),
          throwsApiError(ApiErrorCode.refreshReused, status: 401),
        );
        expect(h.reported, [(ApiErrorCode.refreshReused, s.farmerId)]);
      });
    });

    group('self sign-up', () {
      late ContractHarness h;
      setUp(() async => h = await create());

      test('new phone -> consent -> village -> complete', () async {
        final s = await signIn(h, h.fixture.newPhone());
        expect(s.isNew, isTrue);
        expect(s.farmerStatus, FarmerStatus.pendingProfile);

        final before = await h.repos.profile.listConsents();
        expect(
          before.map((c) => c.purpose),
          containsAll(<ConsentPurpose>[
            ConsentPurpose.programme,
            ConsentPurpose.soilPartner,
            ConsentPurpose.schemesFinance,
            ConsentPurpose.loyalty,
          ]),
        );
        expect(
          before
              .firstWhere((c) => c.purpose == ConsentPurpose.programme)
              .granted,
          isNull,
        );

        // Consent works while pending_profile; other writes do not.
        final after = await h.repos.profile.setConsent(
          purpose: ConsentPurpose.programme,
          granted: true,
          noticeVersion: 'v1',
          audioPlayed: true,
        );
        final programme = after.firstWhere(
          (c) => c.purpose == ConsentPurpose.programme,
        );
        expect(programme.granted, isTrue);
        expect(programme.method, ConsentMethod.app);
        expect(programme.noticeVersion, 'v1');
        h.reported.clear();
        await expectLater(
          h.repos.profile.addPlot(
            pin: const LatLng(17.46, 78.35),
            areaAcres: 1,
          ),
          throwsApiError(ApiErrorCode.profileIncomplete, status: 409),
        );
        expect(h.reported, [
          (ApiErrorCode.profileIncomplete, s.farmerId),
        ], reason: 'a 409 profile_incomplete reaches the session');

        final villages = await h.repos.geo.searchVillages(
          query: h.fixture.villageQuery,
        );
        expect(
          villages.map((v) => v.id),
          contains(h.fixture.villageWithLeadFa),
        );

        final farmer = await h.repos.profile.completeProfile(
          name: 'Contract Farmer',
          nameTe: 'కాంట్రాక్ట్ రైతు',
          language: Language.te,
          villageId: h.fixture.villageWithLeadFa,
        );
        expect(farmer.status, FarmerStatus.active);
        expect(farmer.villageId, h.fixture.villageWithLeadFa);
        expect(farmer.assignedFaId, isNotNull, reason: 'lead FA assigned');
        expect(farmer.source, FarmerSource.self);

        await expectLater(
          h.repos.profile.completeProfile(
            name: 'Again',
            language: Language.te,
            villageId: h.fixture.villageWithLeadFa,
          ),
          throwsApiError(ApiErrorCode.profileAlreadyComplete, status: 409),
        );

        final home = await h.repos.profile.getHome();
        expect(home.farmer.id, s.farmerId);
        expect(home.village?.id, h.fixture.villageWithLeadFa);
        expect(home.fa?.id, farmer.assignedFaId);
        expect(home.plots, isEmpty);
      });

      test('complete-profile validates the name and the village', () async {
        await signIn(h, h.fixture.newPhone());
        await expectLater(
          h.repos.profile.completeProfile(
            name: '  ',
            language: Language.te,
            villageId: h.fixture.villageWithLeadFa,
          ),
          throwsApiError(ApiErrorCode.validationFailed),
        );
        await expectLater(
          h.repos.profile.completeProfile(
            name: 'X',
            language: Language.te,
            villageId: h.fixture.unknownId(),
          ),
          throwsApiError(ApiErrorCode.notFound, status: 404),
        );
      });
    });

    group('my farm (fresh farmer)', () {
      late ContractHarness h;
      late Farmer farmer;
      setUp(() async {
        h = await create();
        farmer = await signUp(h);
      });

      test('profile update and photo upload target', () async {
        final updated = await h.repos.profile.updateProfile(
          name: 'Renamed Farmer',
          language: Language.en,
        );
        expect(updated.name, 'Renamed Farmer');
        expect(updated.language, Language.en);
        expect(updated.version, greaterThan(farmer.version));

        final up = await h.repos.profile.createPhotoUpload(
          contentType: PhotoContentType.jpeg,
          bytes: 120000,
        );
        expect(up.storageKey, startsWith('farmers/${farmer.id}/'));
        expect(up.method, 'PUT');
        expect(up.url, isNotEmpty);

        await expectLater(
          h.repos.profile.updateProfile(photoKey: 'farmers/someone-else/x.jpg'),
          throwsApiError(ApiErrorCode.validationFailed),
        );
      });

      test('plot and season lifecycle', () async {
        final crops = await h.repos.masters.listCrops();
        final crop = crops.items.first;
        final codes = crops.seasonCodes;

        final plot = await h.repos.profile.addPlot(
          pin: const LatLng(17.4612, 78.3555),
          areaAcres: AcresGuntas.fromAcres(2.1).totalAcres,
        );
        expect(plot.label, 'Plot 1');
        expect(plot.areaAcres, closeTo(2.1, 1e-9));
        expect(plot.areaSource, AreaSource.typed);

        final season = await h.repos.profile.startSeason(
          plotId: plot.id,
          seasonCode: codes.current,
          cropId: crop.id,
        );
        expect(season.status, SeasonStatus.active);
        expect(season.seasonCode, codes.current);

        await expectLater(
          h.repos.profile.startSeason(
            plotId: plot.id,
            seasonCode: codes.next,
            cropId: crop.id,
          ),
          throwsA(
            isA<ApiError>()
                .having((e) => e.code, 'code', ApiErrorCode.activeSeasonExists)
                .having((e) => e.details['season_id'], 'season_id', season.id),
          ),
        );

        final home = await h.repos.profile.getHome();
        final hp = home.plots.single;
        expect(hp.plot.id, plot.id);
        expect(hp.activeSeason?.id, season.id);

        final closed = await h.repos.profile.closeSeason(
          seasonId: season.id,
          outcome: SeasonOutcome.harvested,
        );
        expect(closed.status, SeasonStatus.harvested);
        await expectLater(
          h.repos.profile.closeSeason(
            seasonId: season.id,
            outcome: SeasonOutcome.abandoned,
          ),
          throwsApiError(ApiErrorCode.seasonNotActive, status: 409),
        );
        await expectLater(
          h.repos.profile.closeSeason(
            seasonId: h.fixture.unknownId(),
            outcome: SeasonOutcome.harvested,
          ),
          throwsApiError(ApiErrorCode.notFound, status: 404),
        );
        await expectLater(
          h.repos.profile.startSeason(
            plotId: h.fixture.unknownId(),
            seasonCode: codes.current,
            cropId: crop.id,
          ),
          throwsApiError(ApiErrorCode.notFound, status: 404),
        );

        // Once closed, the plot takes a new season, the same code included
        // (a second crop in one season), with the crop before it.
        final previous = crops.items.last;
        final again = await h.repos.profile.startSeason(
          plotId: plot.id,
          seasonCode: codes.current,
          cropId: crop.id,
          sowingDate: LocalDate.todayIst(h.clock).addDays(3),
          previousCropId: previous.id,
        );
        expect(again.id, isNot(season.id));
        expect(again.status, SeasonStatus.active);
        expect(again.previousCropId, previous.id);

        // Sowing is still ahead: negative days, no stage yet.
        final ahead = (await h.repos.profile.getHome()).plots.single;
        expect(ahead.activeSeason?.id, again.id);
        expect(ahead.daysAfterSowing, -3);
        expect(ahead.currentStage, isNull);
      });

      test('no visits yet: empty list, no next visit', () async {
        final visits = await h.repos.visits.listVisits();
        expect(visits.items, isEmpty);
        expect(visits.nextCursor, isNull);
        expect(await h.repos.visits.getNextVisit(), isNull);
        expect((await h.repos.profile.getHome()).nextVisit, isNull);
      });

      test('notices: welcome, read, listened, errors', () async {
        final n = h.repos.notices;
        final inbox = await eventually(
          h,
          n.listNotices,
          (page) => page.items.any((x) => !x.isRead),
          reason:
              'a completed sign-up gets an unread welcome notice '
              '(the API needs its worker running)',
        );
        final unread = await n.getUnreadCount();
        expect(unread, inbox.items.where((x) => !x.isRead).length);

        final notice = inbox.items.firstWhere((x) => !x.isRead);
        await n.markRead(notice.id);
        await n.markRead(notice.id); // idempotent
        expect(await n.getUnreadCount(), unread - 1);

        await n.markListened(notice.id);
        await n.markListened(notice.id); // idempotent
        final after = (await n.listNotices(limit: 100)).items
            .firstWhere((x) => x.id == notice.id);
        expect(after.isListened, isTrue);
        expect(after.isRead, isTrue);

        await expectLater(
          n.markRead(h.fixture.unknownId()),
          throwsApiError(ApiErrorCode.notFound, status: 404),
        );
        await expectLater(
          n.markListened(h.fixture.unknownId()),
          throwsApiError(ApiErrorCode.notFound, status: 404),
        );
        await expectLater(
          n.listNotices(cursor: 'not-a-cursor'),
          throwsApiError(ApiErrorCode.invalidCursor, status: 400),
        );
      });

      // Paged one at a time, so even the welcome notice alone (all the dev
      // seed guarantees) goes through a cursor; the seed has no notices for
      // the known farmer.
      test('notices page newest first; unread count agrees', () async {
        final n = h.repos.notices;
        await eventually(
          h,
          n.listNotices,
          (page) => page.items.isNotEmpty,
          reason:
              'a completed sign-up gets a welcome notice '
              '(the API needs its worker running)',
        );
        final all = <Notice>[];
        String? cursor;
        do {
          final page = await n.listNotices(limit: 1, cursor: cursor);
          expect(page.items.length, lessThanOrEqualTo(1));
          all.addAll(page.items);
          cursor = page.nextCursor;
        } while (cursor != null && all.length < 200);
        expect(all, isNotEmpty);
        expect(all.map((x) => x.id).toSet(), hasLength(all.length));
        final times = all.map((x) => x.createdAt).toList();
        expect(
          times,
          orderedEquals(<DateTime>[...times]..sort((a, b) => b.compareTo(a))),
        );
        expect(await n.getUnreadCount(), all.where((x) => !x.isRead).length);
      });

      test('bad plot and season input is a validation error', () async {
        await expectLater(
          h.repos.profile.addPlot(
            pin: const LatLng(17.46, 78.35),
            areaAcres: 0,
          ),
          throwsApiError(ApiErrorCode.validationFailed),
        );
        final plot = await h.repos.profile.addPlot(
          label: 'Back field',
          pin: const LatLng(17.46, 78.35),
          areaAcres: 0.5,
        );
        expect(plot.label, 'Back field');
        final crops = await h.repos.masters.listCrops();
        await expectLater(
          h.repos.profile.startSeason(
            plotId: plot.id,
            seasonCode: 'Kharif 2026',
            cropId: crops.items.first.id,
          ),
          throwsApiError(ApiErrorCode.validationFailed),
        );
      });
    });

    group('known farmer', () {
      late ContractHarness h;
      setUpAll(() async {
        h = await create();
        final s = await signIn(h, h.fixture.knownPhone);
        expect(s.isNew, isFalse);
        expect(s.farmerStatus, FarmerStatus.active);
      });

      test('home', () async {
        final home = await h.repos.profile.getHome();
        expect(home.farmer.phone, h.fixture.knownPhone);
        expect(home.farmer.status, FarmerStatus.active);
        expect(home.village, isNotNull);
        expect(home.fa, isNotNull);
        expect(home.fa!.phone, startsWith('+91'));
        expect(home.plots, isNotEmpty);
        final today = LocalDate.todayIst(h.clock);
        for (final p in home.plots) {
          final sown = p.activeSeason?.sowingDate;
          expect(p.daysAfterSowing, sown?.daysUntil(today));
        }
      });

      test('look for FAs', () async {
        final all = await h.repos.fieldAssistants.listFas();
        expect(all.where((o) => o.isMyFa), hasLength(1));
        final village = await h.repos.fieldAssistants.listFas(
          level: AreaLevel.village,
        );
        expect(village, isNotEmpty);
        expect(
          village.every((o) => o.coverageLevel == AreaLevel.village),
          isTrue,
        );
        // Most specific level first.
        final order = all.map((o) => o.coverageLevel.index).toList();
        expect(order, orderedEquals([...order]..sort()));
      });

      test('call-back: request is idempotent, cancel is idempotent', () async {
        final fas = h.repos.fieldAssistants;
        final open = await fas.getOpenCallback();
        if (open != null) await fas.cancelCallback(open.id);

        final first = await fas.requestCallback();
        expect(first.status, CallbackStatus.open);
        final again = await fas.requestCallback();
        expect(again.id, first.id);
        expect((await fas.getOpenCallback())?.id, first.id);

        final cancelled = await fas.cancelCallback(first.id);
        expect(cancelled.status, CallbackStatus.cancelled);
        expect(cancelled.closedAt, isNotNull);
        expect(
          (await fas.cancelCallback(first.id)).status,
          CallbackStatus.cancelled,
        );
        expect(await fas.getOpenCallback(), isNull);
        await expectLater(
          fas.cancelCallback(h.fixture.unknownId()),
          throwsApiError(ApiErrorCode.notFound, status: 404),
        );
      });

      test('call-back closed by the FA cannot be cancelled', () async {
        final closeAsFa = h.closeCallbackAsFa;
        if (closeAsFa == null) {
          markTestSkipped('needs the FA side (CloseCallback) to close it');
          return;
        }
        final fas = h.repos.fieldAssistants;
        final c = await fas.requestCallback();
        closeAsFa(c.id);
        await expectLater(
          fas.cancelCallback(c.id),
          throwsApiError(ApiErrorCode.callbackClosed, status: 409),
        );
        expect(await fas.getOpenCallback(), isNull);
      });

      test('visits page without gaps or repeats', () async {
        final all = await h.repos.visits.listVisits(limit: 50);
        final times = all.items.map((v) => v.visitedAt).toList();
        expect(
          times,
          orderedEquals(<DateTime>[...times]..sort((a, b) => b.compareTo(a))),
        );
        for (final v in all.items) {
          for (final i in v.issues) {
            if (i.saltOnly) expect(i.skuId, isNull);
            if (i.skuId != null) expect(i.productName, isNotNull);
          }
        }
        final count = all.items.length;
        if (count < 2 || all.nextCursor != null) {
          markTestSkipped(
            'paging needs 2 to 50 logged visits for the known farmer; '
            'it has $count${all.nextCursor != null ? '+' : ''}',
          );
          return;
        }

        final limit = (count + 2) ~/ 3; // at least two pages
        final seen = <String>[];
        String? cursor;
        var pages = 0;
        do {
          final page = await h.repos.visits.listVisits(
            limit: limit,
            cursor: cursor,
          );
          expect(page.items.length, lessThanOrEqualTo(limit));
          seen.addAll(page.items.map((v) => v.id));
          cursor = page.nextCursor;
          pages++;
        } while (cursor != null && pages < 50);
        expect(pages, (count / limit).ceil());
        expect(seen, all.items.map((v) => v.id).toList());
      });

      test('paging rejects a bad cursor and a bad limit', () async {
        await expectLater(
          h.repos.visits.listVisits(cursor: 'not-a-cursor'),
          throwsApiError(ApiErrorCode.invalidCursor, status: 400),
        );
        await expectLater(
          h.repos.notices.listNotices(cursor: 'not-a-cursor'),
          throwsApiError(ApiErrorCode.invalidCursor, status: 400),
        );
        await expectLater(
          h.repos.notices.listNotices(limit: 101),
          throwsApiError(ApiErrorCode.validationFailed, status: 400),
        );
      });

      test('next visit is today or later', () async {
        final next = await h.repos.visits.getNextVisit();
        if (next == null) {
          markTestSkipped('the known farmer has no planned visit ahead');
          return;
        }
        expect(
          next.plannedFor.isBefore(LocalDate.todayIst(h.clock)),
          isFalse,
          reason: 'planned for ${next.plannedFor}',
        );
        expect(next.plannedSlot, isNot(PlannedSlot.unknown));
        final home = await h.repos.profile.getHome();
        expect(home.nextVisit?.visitId, next.visitId);
        expect(home.nextVisit?.plannedFor, next.plannedFor);
      });

      // Read only: the seeded farmer's inbox is never written (see the fresh
      // farmer's notices tests for read, listened and the welcome notice).
      test('notices across pages, newest first', () async {
        final n = h.repos.notices;
        final first = await n.listNotices(limit: 100);
        final count = first.items.length;
        if (count < 2 || first.nextCursor != null) {
          markTestSkipped(
            'paging needs 2 to 100 notices for the known farmer; '
            'it has $count${first.nextCursor != null ? '+' : ''}',
          );
          return;
        }
        final all = <Notice>[];
        String? cursor;
        do {
          final page = await n.listNotices(limit: 2, cursor: cursor);
          expect(page.items.length, lessThanOrEqualTo(2));
          all.addAll(page.items);
          cursor = page.nextCursor;
        } while (cursor != null && all.length < 200);
        expect(all.map((x) => x.id), first.items.map((x) => x.id));
        final times = all.map((x) => x.createdAt).toList();
        expect(
          times,
          orderedEquals(<DateTime>[...times]..sort((a, b) => b.compareTo(a))),
        );
        expect(await n.getUnreadCount(), all.where((x) => !x.isRead).length);
      });

      test('crops and season codes', () async {
        final crops = await h.repos.masters.listCrops();
        expect(crops.items, isNotEmpty);
        for (final c in crops.items) {
          final seqs = c.stages.map((s) => s.seq).toList();
          expect(seqs, orderedEquals([...seqs]..sort()));
          expect(c.nameTe, isNotEmpty);
        }
        final codes = crops.seasonCodes;
        expect(codes.allOpen, hasLength(3));
        expect(codes.allOpen[1], codes.current);
        expect(codes.allOpen[2], codes.next);
        expect(codes.allOpen.every(SeasonCode.isValid), isTrue);
      });

      test('geo tree and village browse', () async {
        final tree = await h.repos.geo.getGeoTree();
        expect(tree.districts, isNotEmpty);
        final mandal = tree.districts.first.mandals.first;
        final villages = await h.repos.geo.searchVillages(mandalId: mandal.id);
        expect(villages, isNotEmpty);
        expect(villages.every((v) => v.mandalId == mandal.id), isTrue);
        final limited = await h.repos.geo.searchVillages(limit: 1);
        expect(limited, hasLength(1));
      });

      test('dealers nearest first', () async {
        final home = await h.repos.profile.getHome();
        final pin = home.plots.first.plot.pin ?? const LatLng(17.46, 78.357);
        final dealers = await h.repos.masters.listNearbyDealers(near: pin);
        final d = dealers.map((x) => x.distanceM).toList();
        expect(d, orderedEquals([...d]..sort()));
      });

      test('consents list every purpose', () async {
        final consents = await h.repos.profile.listConsents();
        final purposes = consents.map((c) => c.purpose).toList();
        expect(purposes, hasLength(purposes.toSet().length), reason: 'once');
        expect(
          purposes,
          containsAll(<ConsentPurpose>[
            ConsentPurpose.programme,
            ConsentPurpose.soilPartner,
            ConsentPurpose.schemesFinance,
            ConsentPurpose.loyalty,
          ]),
        );
        final programme = consents.firstWhere(
          (c) => c.purpose == ConsentPurpose.programme,
        );
        expect(programme.granted, isTrue);
        expect(programme.method, isNotNull);
        expect(programme.method, isNot(ConsentMethod.unknown));
      });

      test('heartbeat', () async {
        const version = '0.1.0';
        final status = await h.repos.auth.heartbeat(appVersion: version);
        expect(status.wipe, isFalse);
        expect(status.deviceId, isNotEmpty);
        expect(status.minVersion, isNotEmpty);
        expect(status.updateRequired, versionBelow(version, status.minVersion));
      });
    });
  });
}
