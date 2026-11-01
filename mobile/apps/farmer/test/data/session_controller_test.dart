import 'package:farmer/src/data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../support/harness.dart' show phaseOf;
import '../support/session_support.dart';
import 'repository_contract.dart' show throwsApiError;

/// The sign-in and sign-up flow: what each action does to the session.
void main() {
  late SessionTestBed bed;
  late MockBackend backend;
  late CountingStore store;
  late FixedClock clock;

  setUp(() {
    bed = SessionTestBed();
    backend = bed.backend;
    store = bed.store;
    clock = bed.clock;
  });

  test('starts restoring, then signed out with Telugu', () async {
    final c = bed.startUnrestored();
    expect(phaseOf(c), SessionPhase.restoring);
    await c.read(sessionProvider.notifier).restored;
    expect(phaseOf(c), SessionPhase.signedOut);
    expect(c.read(appLanguageProvider), Language.te);
  });

  group('sign-in', () {
    test('known farmer: OTP, wrong code, right code -> active', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);

      await session.requestOtp('90000 00101');
      final sent = c.read(sessionProvider);
      expect(sent.phase, SessionPhase.otpSent);
      expect(sent.phone, MockBackend.raviPhone);
      expect(sent.otp?.phoneMasked, '+91******0101');
      expect(
        sent.resendAvailableAt,
        clock.now().add(const Duration(seconds: 30)),
      );

      await expectLater(
        session.verifyOtp('000000'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', ApiErrorCode.otpInvalid)
              .having((e) => e.attemptsLeft, 'attemptsLeft', 4),
        ),
      );
      expect(phaseOf(c), SessionPhase.otpSent);

      await expectLater(
        session.resendOtp(),
        throwsApiError(ApiErrorCode.rateLimited),
      );
      clock.advance(const Duration(seconds: 31));
      await session.resendOtp();

      await session.verifyOtp(MockBackend.fixedOtp);
      final s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.active);
      expect(s.farmerId, isNotNull);
      expect(s.isSignedIn, isTrue);
    });

    test('the OTP SMS goes out in the chosen language', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.requestOtp('9000000101');
      expect(backend.otpLanguage('9000000101'), Language.te);

      session.editPhone();
      await session.setLanguage(Language.en);
      await session.requestOtp('9000000102');
      expect(backend.otpLanguage('9000000102'), Language.en);
    });

    test('a bad phone fails locally, even offline', () async {
      final c = await bed.start();
      backend.scenario = MockScenario.offline;
      await expectLater(
        c.read(sessionProvider.notifier).requestOtp('12345'),
        throwsApiError(ApiErrorCode.validationFailed),
      );
      await expectLater(
        c.read(sessionProvider.notifier).requestOtp('9000000101'),
        throwsApiError(ApiErrorCode.network),
      );
      expect(phaseOf(c), SessionPhase.signedOut);
    });

    test('edit phone goes back and keeps the number', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.requestOtp('9000000101');
      session.editPhone();
      expect(phaseOf(c), SessionPhase.signedOut);
      expect(c.read(sessionProvider).phone, MockBackend.raviPhone);
    });

    test('the follow-up read failing still leaves the OTP screen', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.requestOtp('9876543210');
      bed.script.failNext('listConsents', const ApiError.network());

      await session.verifyOtp(MockBackend.fixedOtp);

      // Signed in; the consent step is safe to show again.
      expect(phaseOf(c), SessionPhase.needsConsent);
      expect(c.read(sessionProvider).isSignedIn, isTrue);
      expect(await store.readSession(), isNotNull);
    });

    test(
      'a sign-up that already gave consent resumes at the village',
      () async {
        final c = await bed.signedIn('9876543210');
        final session = c.read(sessionProvider.notifier);
        await session.giveConsent();
        await session.signOut();
        clock.advance(const Duration(seconds: 31)); // the OTP resend wait

        await signInOn(c, '9876543210');

        expect(phaseOf(c), SessionPhase.needsVillage);
      },
    );
  });

  group('self sign-up', () {
    test('consent -> village -> name -> active with an FA', () async {
      final c = await bed.signedIn('9876543210');
      final session = c.read(sessionProvider.notifier);
      expect(phaseOf(c), SessionPhase.needsConsent);

      expect(() => session.pickVillage(_kondapur), throwsStateError);

      await session.giveConsent(audioPlayed: true);
      expect(phaseOf(c), SessionPhase.needsVillage);
      final consents = await c
          .read(farmerProfileRepositoryProvider)
          .listConsents();
      expect(
        consents
            .firstWhere((x) => x.purpose == ConsentPurpose.programme)
            .granted,
        isTrue,
      );

      final villages = await c
          .read(geoRepositoryProvider)
          .searchVillages(query: 'కొండా');
      session.pickVillage(villages.single);
      expect(phaseOf(c), SessionPhase.needsName);
      expect(c.read(sessionProvider).village?.name, 'Kondapur');

      session.changeVillage();
      expect(phaseOf(c), SessionPhase.needsVillage);
      session.pickVillage(villages.single);

      await session.completeProfile(
        name: 'Lakshmi Devi',
        nameTe: 'లక్ష్మీ దేవి',
      );
      expect(phaseOf(c), SessionPhase.active);
      final home = await c.read(farmerProfileRepositoryProvider).getHome();
      expect(home.farmer.displayName(Language.te), 'లక్ష్మీ దేవి');
      expect(home.fa?.code, 'FA-KDP-014');
    });

    test(
      'complete-profile goes to Home when the read after it fails',
      () async {
        final c = await bed.signedIn('9876543210');
        final session = c.read(sessionProvider.notifier);
        await session.giveConsent();
        session.pickVillage(_kondapur);
        bed.script.failNext('getHome', const ApiError.network());

        await session.completeProfile(name: 'Ramu');

        expect(phaseOf(c), SessionPhase.active);
        expect(c.read(sessionProvider).farmerId, isNotNull);
        final home = await c.read(farmerProfileRepositoryProvider).getHome();
        expect(home.farmer.status, FarmerStatus.active);
      },
    );

    test('a restart mid sign-up resumes at the right step', () async {
      final first = await bed.signedIn('9876543210');
      first.dispose();

      final second = await bed.start();
      expect(phaseOf(second), SessionPhase.needsConsent);
      await second.read(sessionProvider.notifier).giveConsent();
      second.dispose();

      final third = await bed.start();
      expect(phaseOf(third), SessionPhase.needsVillage);
    });
  });

  group('restore', () {
    test('a signed-in farmer, also offline', () async {
      final first = await bed.signedIn('9000000102');
      first.dispose();

      expect(phaseOf(await bed.start()), SessionPhase.active);
      backend.scenario = MockScenario.offline;
      expect(phaseOf(await bed.start()), SessionPhase.active);
    });

    test('a session the server forgot restores as signed out', () async {
      final first = await bed.signedIn('9000000102');
      first.dispose();

      backend.reset(); // the server lost every token
      final c = await bed.start();
      expect(phaseOf(c), SessionPhase.signedOut);
      expect(await store.readSession(), isNull);
    });

    test('a store that cannot be read signs out, keeping the install ID '
        'until it cannot be read either', () async {
      final first = await bed.signedIn('9000000101');
      first.dispose();
      final key = await store.readDeviceKey();

      store.failSessionReads = true;
      final c = await bed.start();
      expect(phaseOf(c), SessionPhase.signedOut);
      store.failSessionReads = false;
      expect(await store.readSession(), isNull);
      expect(await store.readDeviceKey(), key, reason: 'same device');

      // Nothing readable at all: still phone entry, never the splash.
      final broken = await bed.start(store: ThrowingStore());
      expect(phaseOf(broken), SessionPhase.signedOut);
    });

    test('a session that cannot be read keeps the language the farmer '
        'chose', () async {
      final first = await bed.start();
      await first.read(sessionProvider.notifier).setLanguage(Language.en);
      first.dispose();

      store.failSessionReads = true;
      final c = await bed.start();
      expect(phaseOf(c), SessionPhase.signedOut);
      expect(c.read(sessionProvider).language, Language.en);
    });
  });

  test('paused account, then reactivated', () async {
    backend.scenario = MockScenario.accountPaused;
    final c = await bed.signedIn('9000000101');
    expect(phaseOf(c), SessionPhase.inactive);

    backend.scenario = MockScenario.normal;
    await c.read(sessionProvider.notifier).recheck();
    expect(phaseOf(c), SessionPhase.active);
  });

  group('language', () {
    test('local at once, saved to the profile when active', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.setLanguage(Language.en);
      expect(c.read(appLanguageProvider), Language.en);
      expect(await store.readLanguage(), Language.en);

      await session.requestOtp('9000000101');
      expect(c.read(appLanguageProvider), Language.en);
      await session.verifyOtp(MockBackend.fixedOtp);
      await session.setLanguage(Language.te);
      final home = await c.read(farmerProfileRepositoryProvider).getHome();
      expect(home.farmer.language, Language.te);

      // The language survives sign-out and restart.
      await session.setLanguage(Language.en);
      await session.signOut();
      expect(c.read(sessionProvider).language, Language.en);
      final restarted = await bed.start();
      expect(restarted.read(appLanguageProvider), Language.en);
    });

    test('picked on the splash, it is not lost to the restore', () async {
      await store.writeLanguage(Language.te);
      final c = bed.startUnrestored();
      final session = c.read(sessionProvider.notifier);
      expect(phaseOf(c), SessionPhase.restoring);

      await session.setLanguage(Language.en);
      await session.restored;

      expect(phaseOf(c), SessionPhase.signedOut);
      expect(c.read(appLanguageProvider), Language.en);
      expect(await store.readLanguage(), Language.en);
    });

    test('a profile save that fails keeps the local choice', () async {
      final c = await bed.signedIn('9000000101');
      final session = c.read(sessionProvider.notifier);
      bed.script.failNext('updateProfile', const ApiError.network());

      await expectLater(
        session.setLanguage(Language.en),
        throwsApiError(ApiErrorCode.network),
      );

      expect(c.read(sessionProvider).language, Language.en);
      expect(await store.readLanguage(), Language.en);
      expect(phaseOf(c), SessionPhase.active);
      final home = await c.read(farmerProfileRepositoryProvider).getHome();
      expect(home.farmer.language, Language.te, reason: 'not saved there');
    });
  });

  group('sign-out', () {
    test(
      'clears the session, keeps the install ID; device_revoked wipes it',
      () async {
        final c = await bed.signedIn('9000000101');
        final session = c.read(sessionProvider.notifier);
        final key = await store.readDeviceKey();
        expect(key, matches(RegExp(r'^[0-9a-f]{32}$')));

        await session.signOut();
        expect(phaseOf(c), SessionPhase.signedOut);
        expect(await store.readSession(), isNull);
        expect(await store.readDeviceKey(), key);
        await expectLater(
          c.read(farmerProfileRepositoryProvider).getHome(),
          throwsApiError(ApiErrorCode.unauthorized),
        );

        await signInOn(c, '9000000102');
        await session.sessionLost(deviceRevoked);
        expect(phaseOf(c), SessionPhase.signedOut);
        expect(await store.readDeviceKey(), isNull);
      },
    );

    test('works offline', () async {
      final c = await bed.signedIn('9000000101');
      backend.scenario = MockScenario.offline;

      await c.read(sessionProvider.notifier).signOut();

      expect(phaseOf(c), SessionPhase.signedOut);
      expect(await store.readSession(), isNull);
    });

    test('does not depend on the logout call', () async {
      final c = await bed.signedIn('9000000101');
      // An API logout that throws before it cleared anything.
      bed.script.failNext('logout', const ApiError.network());

      await c.read(sessionProvider.notifier).signOut();

      expect(phaseOf(c), SessionPhase.signedOut);
      expect(c.read(sessionProvider).farmerId, isNull);
      expect(await store.readSession(), isNull);
      expect(await store.readPhase(), isNull);
    });
  });
}

final _kondapur = Village(
  id: '7ffb9494-9f19-5bbf-89c8-85c80065689f',
  name: 'Kondapur',
  nameTe: 'కొండాపూర్',
  lgdCode: null,
  lat: null,
  lng: null,
  mandalId: 'm',
  mandalName: 'Serilingampally',
  mandalNameTe: null,
  districtId: 'd',
  districtName: 'Rangareddy',
  districtNameTe: null,
  createdAt: DateTime.utc(2026),
);
