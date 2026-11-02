// Repository contract suite for the FA app: written against the interfaces
// only, so the same tests run against the mock today and the API
// implementation later.
//
// Not a test file itself (no `_test` suffix). Run it from a test file:
//
//   void main() => runRepositoryContract('mock', createMockHarness);
//
// Against a dev backend (`make dev-up migrate backend-seed backend-run-api`,
// DEV_FIXED_OTP=123456), write `api_repository_contract_test.dart` with a
// factory that builds the Api* set over a fresh InMemorySessionStore and
// AuthFailureHook and `ContractFixture.devSeed()`; see
// lib/src/data/README.md ("Swap to the real API").
//
// Rules that keep it valid for a real server:
// * Only what the dev seed guarantees is asserted: FA-KDP-014 signs in,
//   Kondapur is in that FA's area, Ravi K (+919000000101) is that FA's
//   farmer. Counts and contents that differ between the mock and dev are
//   checked for shape, not value.
// * Writes are fresh enrolments (random phones) in Kondapur, so every run
//   adds farmers to FA Suresh's territory on a dev database. The suite does
//   not depend on their number. To start over: `make backend-dev-reset`,
//   then `make dev-up migrate backend-seed`.
// * Sign-in is rate limited per login (10 in 15 minutes on the server), so
//   each test signs in at most once and the suite stays under the limit.

import 'dart:math' as math;

import 'package:fa/src/data/data.dart';
import 'package:fa/src/local/commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

/// Data the suite relies on; defaults match the dev seed and the mock.
class ContractFixture {
  /// Creates a fixture.
  ContractFixture({
    required this.faCode,
    required this.faPassword,
    required this.otp,
    required this.knownFarmerPhone,
    required this.villageInArea,
    math.Random? random,
  }) : _random = random ?? math.Random();

  /// The dev seed (`backend/cmd/seed`): FA-KDP-014 / `fa-dev-pass`, OTP
  /// 123456, Ravi K, Kondapur.
  factory ContractFixture.devSeed({math.Random? random}) => ContractFixture(
    faCode: 'FA-KDP-014',
    faPassword: 'fa-dev-pass',
    otp: '123456',
    knownFarmerPhone: '+919000000101',
    villageInArea: '7ffb9494-9f19-5bbf-89c8-85c80065689f',
    random: random,
  );

  /// The mock world: the same login with the mock password.
  factory ContractFixture.mock({math.Random? random}) => ContractFixture(
    faCode: MockBackend.sureshCode,
    faPassword: MockBackend.sureshPassword,
    otp: MockBackend.fixedOtp,
    knownFarmerPhone: MockBackend.raviPhone,
    villageInArea: MockBackend.kondapurId,
    random: random,
  );

  /// An active FA login with a permanent password.
  final String faCode;

  /// Its password.
  final String faPassword;

  /// The fixed OTP (`DEV_FIXED_OTP`).
  final String otp;

  /// A farmer assigned to [faCode].
  final String knownFarmerPhone;

  /// A village in [faCode]'s area.
  final String villageInArea;

  final math.Random _random;

  /// A random, valid phone that is very unlikely to exist yet.
  String newPhone() =>
      '+919${List.generate(9, (_) => _random.nextInt(10)).join()}';

  /// A random UUID (version 4 shape) that matches nothing.
  String newId() {
    String hex(int n) =>
        List.generate(n, (_) => _random.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }

  /// A random install ID.
  String newDeviceKey() => 'contract-${newId()}';
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
  }) {
    authFailures.listen(
      (error, {faId, sessionKey}) => reported.add((error.code, faId)),
    );
  }

  /// The repositories under test.
  final FaRepositories repos;

  /// The store those repositories read and write.
  final SessionStore store;

  /// The hook [repos] report failures to.
  final AuthFailureHook authFailures;

  /// What [repos] reported to [authFailures] so far: (code, FA ID).
  final reported = <(String, String?)>[];

  /// Test data.
  final ContractFixture fixture;

  /// The server's clock, for "today" in IST.
  final Clock clock;
}

/// Builds a fresh harness (new store; same or new backend).
typedef HarnessFactory = Future<ContractHarness> Function();

/// Matches an [ApiError] with [code] (and [status] when given).
Matcher throwsApiError(String code, {int? status}) => throwsA(
  isA<ApiError>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.status, 'status', status ?? anything),
);

/// Signs the fixture's FA in on a new install ID.
Future<FaSession> signIn(ContractHarness h) => h.repos.auth.login(
  code: h.fixture.faCode,
  password: h.fixture.faPassword,
  device: DeviceInfo(
    deviceKey: h.fixture.newDeviceKey(),
    model: 'Contract test',
    osVersion: 'Android 11',
    appVersion: '0.1.0',
  ),
);

/// A minimal enrolment of a new phone in the fixture's village, without
/// consent proof (enrolled consent pending).
EnrolFarmerPayload newEnrolment(ContractHarness h, {String? proof}) =>
    EnrolFarmerPayload(
      farmerId: h.fixture.newId(),
      phone: h.fixture.newPhone(),
      name: 'Contract Farmer',
      language: Language.te,
      villageId: h.fixture.villageInArea,
      consent: EnrolConsent(
        purposes: const [ConsentPurpose.programme],
        otpProof: proof,
        audioPlayed: true,
        noticeVersion: 'v1',
      ),
    );

final _etag = RegExp(r'^"t\d+-m\d+"$');

/// Registers the contract tests for one implementation.
void runRepositoryContract(String label, HarnessFactory create) {
  group('$label repository contract', () {
    late ContractHarness h;
    setUp(() async => h = await create());

    group('auth', () {
      test('app config', () async {
        final c = await h.repos.auth.getAppConfig();
        expect(c.app, 'fa');
        expect(c.minVersion, isNotEmpty);
        expect(c.latestVersion, isNotEmpty);
      });

      test(
        'login saves the session with the FA and the offline rules',
        () async {
          final s = await signIn(h);
          expect(s.fieldAssistant.code, h.fixture.faCode);
          expect(s.mustChangePassword, isFalse);
          expect(s.offlinePolicy.pinLength, greaterThanOrEqualTo(4));
          expect(s.offlinePolicy.offlineGraceDays, greaterThan(0));
          expect(s.offlinePolicy.pinMaxAttempts, greaterThan(0));
          expect(s.deviceId, isNotEmpty);
          final stored = await h.store.readSession();
          expect(stored?.tokens, s.tokens);
          expect(stored?.faId, s.fieldAssistant.id);
          expect(stored?.deviceId, s.deviceId);
          expect(await h.store.readLastOnlineAt(), isNotNull);
        },
      );

      test('a wrong password is 401 unauthorized', () async {
        await expectLater(
          h.repos.auth.login(
            code: h.fixture.faCode,
            password: '${h.fixture.faPassword}-wrong',
            device: DeviceInfo(deviceKey: h.fixture.newDeviceKey()),
          ),
          throwsApiError(ApiErrorCode.unauthorized, status: 401),
        );
        expect(await h.store.readSession(), isNull);
      });

      test('FA calls without a session are 401 and reported', () async {
        await expectLater(
          h.repos.sync.getStatus(),
          throwsApiError(ApiErrorCode.unauthorized, status: 401),
        );
        await expectLater(
          h.repos.enrolment.lookupPhone(h.fixture.newPhone()),
          throwsApiError(ApiErrorCode.unauthorized, status: 401),
        );
        expect(h.reported.map((r) => r.$1), [
          ApiErrorCode.unauthorized,
          ApiErrorCode.unauthorized,
        ]);
      });

      test('refresh rotates the pair; logout clears the store', () async {
        final s = await signIn(h);
        final next = await h.repos.auth.refreshSession();
        expect(next.refreshToken, isNot(s.tokens.refreshToken));
        expect((await h.store.readSession())?.tokens, next);
        await h.repos.sync.getStatus();
        await h.repos.auth.logout();
        expect(await h.store.readSession(), isNull);
      });

      test('heartbeat answers for this device', () async {
        final s = await signIn(h);
        final hb = await h.repos.auth.heartbeat(appVersion: '0.1.0');
        expect(hb.deviceId, s.deviceId);
        expect(hb.wipe, isFalse);
        expect(hb.minVersion, isNotEmpty);
        expect(
          hb.serverTime.difference(h.clock.now()).abs(),
          lessThan(const Duration(minutes: 5)),
        );
      });
    });

    group('sync', () {
      setUp(() async => signIn(h));

      test('snapshot shape, ETag and 304', () async {
        final r = await h.repos.sync.getSnapshot();
        expect(r, isA<SnapshotFetched>());
        final fetched = r as SnapshotFetched;
        final snap = fetched.snapshot;
        expect(fetched.etag, matches(_etag));
        expect(fetched.etag, snap.etag);
        expect(snap.masters.crops, isNotEmpty);
        expect(snap.masters.seasonCodes.allOpen, hasLength(3));
        expect(
          snap.villages.map((v) => v.id),
          contains(h.fixture.villageInArea),
        );
        expect(
          snap.farmers.map((f) => f.phone),
          contains(h.fixture.knownFarmerPhone),
        );
        final farmerIds = {for (final f in snap.farmers) f.id};
        expect(snap.plots.every((p) => farmerIds.contains(p.farmerId)), isTrue);
        expect(
          snap.alerts.every((a) => a.status != AlertStatus.closed),
          isTrue,
        );

        final status = await h.repos.sync.getStatus();
        expect(status.etag, matches(_etag));
        expect(status.mastersVersion, snap.mastersVersion);
        final again = await h.repos.sync.getSnapshot(ifNoneMatch: status.etag);
        expect(again, SnapshotNotModified(etag: status.etag));
      });

      test('commands are idempotent by ID', () async {
        final cmd = newEnrolment(h)
            .toCommandIn(id: h.fixture.newId(), clientCreatedAt: h.clock.now());
        final first = await h.repos.sync.submitCommands([cmd]);
        expect(first.complete, isTrue);
        expect(first.results.single.id, cmd.id);
        expect(first.results.single.status, CommandStatus.applied);
        final status = await h.repos.sync.getStatus();
        expect(status.territoryVersion, first.territoryVersion);

        final again = await h.repos.sync.submitCommands([cmd]);
        expect(again.results.single, first.results.single);
        expect(again.territoryVersion, first.territoryVersion);

        final snap =
            (await h.repos.sync.getSnapshot() as SnapshotFetched).snapshot;
        final f = snap.farmers.singleWhere(
          (f) => f.id == cmd.payload['farmer_id'],
        );
        expect(f.consentPending, isTrue);
      });

      test('an unknown command type is rejected, not an error', () async {
        final r = await h.repos.sync.submitCommands([
          CommandIn(
            id: h.fixture.newId(),
            type: 'NoSuchCommand',
            payload: const {},
          ),
        ]);
        expect(r.results.single.status, CommandStatus.rejected);
        expect(r.results.single.error, isNotEmpty);
      });
    });

    group('enrolment', () {
      setUp(() async => signIn(h));

      test('lookup: a new number is new, the known farmer is mine', () async {
        final fresh = await h.repos.enrolment.lookupPhone(h.fixture.newPhone());
        expect(fresh, const PhoneLookup(status: PhoneLookupStatus.newFarmer));
        final known = await h.repos.enrolment.lookupPhone(
          h.fixture.knownFarmerPhone,
        );
        expect(known.status, PhoneLookupStatus.mine);
        expect(known.farmerId, isNotNull);
      });

      test(
        'consent OTP: wrong code, then the fixed code gives a proof',
        () async {
          final phone = h.fixture.newPhone();
          final sent = await h.repos.enrolment.requestConsentOtp(
            phone: phone,
            language: Language.te,
          );
          expect(sent.phoneMasked, maskPhone(phone));
          expect(sent.resendAfter, greaterThan(Duration.zero));
          final wrong = h.fixture.otp == '000000' ? '111111' : '000000';
          await expectLater(
            h.repos.enrolment.verifyConsentOtp(phone: phone, code: wrong),
            throwsA(
              isA<ApiError>()
                  .having((e) => e.code, 'code', ApiErrorCode.otpInvalid)
                  .having((e) => e.attemptsLeft, 'attemptsLeft', isNotNull),
            ),
          );
          final proof = await h.repos.enrolment.verifyConsentOtp(
            phone: phone,
            code: h.fixture.otp,
          );
          expect(proof.phone, phone);
          expect(proof.otpProof, isNotEmpty);
          expect(
            proof.expiresAt.difference(proof.verifiedAt),
            greaterThan(const Duration(days: 6)),
          );
        },
      );
    });
  });
}
