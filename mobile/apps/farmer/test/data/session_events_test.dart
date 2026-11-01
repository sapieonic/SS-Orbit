import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../support/harness.dart' show phaseOf;
import '../support/session_support.dart';
import 'repository_contract.dart' show throwsApiError;

/// How the session reacts to what the server says after sign-in (a session
/// that ended, a revoked phone, a paused or incomplete farmer, a start
/// without network), and to answers that arrive after the session moved on.
void main() {
  late SessionTestBed bed;
  late MockBackend backend;
  late CountingStore store;

  setUp(() {
    bed = SessionTestBed();
    backend = bed.backend;
    store = bed.store;
  });

  void report(ProviderContainer c, ApiError error, {String? farmerId}) =>
      c.read(authFailureHookProvider).report(error, farmerId: farmerId);

  group('session lost', () {
    test('a session the server ended signs out to phone entry', () async {
      final c = await bed.signedIn('9000000101');
      backend.scenario = MockScenario.sessionRevoked;

      await expectLater(
        c.read(farmerHomeProvider.future),
        throwsApiError(ApiErrorCode.unauthorized, status: 401),
      );
      await settle();

      expect(phaseOf(c), SessionPhase.signedOut);
      expect(await store.readSession(), isNull);
      expect(await store.readDeviceKey(), isNotNull, reason: 'not wiped');
    });

    test('many calls failing together sign out exactly once', () async {
      final c = await bed.signedIn('9000000101');
      final phases = <SessionPhase>[];
      c.listen(
        sessionProvider.select((s) => s.phase),
        (_, next) => phases.add(next),
      );
      store.clears = 0;
      backend.scenario = MockScenario.sessionRevoked;

      final calls = [
        c.read(farmerProfileRepositoryProvider).getHome(),
        c.read(noticesRepositoryProvider).getUnreadCount(),
        c.read(visitsRepositoryProvider).listVisits(),
        c.read(mastersRepositoryProvider).listCrops(),
      ];
      for (final call in calls) {
        await expectLater(call, throwsApiError(ApiErrorCode.unauthorized));
      }
      await settle();

      expect(store.clears, 1);
      expect(phases, [SessionPhase.signedOut]);
    });

    test('device_revoked also forgets the install ID', () async {
      final c = await bed.signedIn('9000000101');
      report(c, deviceRevoked, farmerId: c.read(sessionProvider).farmerId);
      await settle();

      expect(phaseOf(c), SessionPhase.signedOut);
      expect(await store.readDeviceKey(), isNull);
    });

    test(
      'device_revoked at start signs out and wipes the install ID',
      () async {
        final first = await bed.signedIn('9000000101');
        first.dispose();
        expect(await store.readDeviceKey(), isNotNull);

        bed.script.failNext('getHome', deviceRevoked);
        final c = await bed.start();

        expect(phaseOf(c), SessionPhase.signedOut);
        expect(await store.readSession(), isNull);
        expect(await store.readDeviceKey(), isNull);
      },
    );

    test('a late failure of the previous farmer leaves the new one', () async {
      final c = await bed.signedIn('9000000101');
      final ravi = c.read(sessionProvider).farmerId;
      await c.read(sessionProvider.notifier).signOut();
      await signInOn(c, '9000000102');

      report(c, sessionEnded, farmerId: ravi);
      await settle();

      expect(phaseOf(c), SessionPhase.active);
      expect(await store.readSession(), isNotNull);
    });

    test(
      'signed out: a late device_revoked still wipes the install ID',
      () async {
        final c = await bed.signedIn('9000000101');
        final ravi = c.read(sessionProvider).farmerId;
        await c.read(sessionProvider.notifier).signOut();
        expect(await store.readDeviceKey(), isNotNull);

        report(c, deviceRevoked, farmerId: ravi);
        await settle();

        expect(phaseOf(c), SessionPhase.signedOut);
        expect(await store.readDeviceKey(), isNull);
      },
    );

    test('signed out: a lost session changes nothing', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.requestOtp('9000000101');
      session.editPhone();
      await store.writeDeviceKey('install-id-1');
      store.clears = 0;

      await session.sessionLost(sessionEnded);
      report(c, sessionEnded);
      await settle();

      expect(phaseOf(c), SessionPhase.signedOut);
      expect(c.read(sessionProvider).phone, MockBackend.raviPhone);
      expect(store.clears, 0);
      expect(await store.readDeviceKey(), 'install-id-1');

      // A revoked device (e.g. on verify) wipes the install ID only.
      await session.sessionLost(deviceRevoked);
      expect(phaseOf(c), SessionPhase.signedOut);
      expect(await store.readDeviceKey(), isNull);
    });

    test('signed out: a revoked device whose store cannot be cleared is '
        'only logged', () async {
      final c = await bed.start();
      store.failClears = true;

      // Neither the hook nor a direct call ends in an unhandled error.
      report(c, deviceRevoked);
      await settle();
      await c.read(sessionProvider.notifier).sessionLost(deviceRevoked);

      expect(store.clears, 2);
      expect(phaseOf(c), SessionPhase.signedOut);
    });

    test('other errors are left to the screen', () async {
      final c = await bed.signedIn('9000000101');
      backend.scenario = MockScenario.serverError;
      await expectLater(
        c.read(farmerProfileRepositoryProvider).getHome(),
        throwsApiError(ApiErrorCode.unavailable),
      );
      await settle();
      expect(phaseOf(c), SessionPhase.active);
    });
  });

  group('status re-check', () {
    test('Home saying "inactive" goes to Account paused', () async {
      final c = await bed.signedIn('9000000101');
      backend.scenario = MockScenario.accountPaused;

      await c.read(farmerHomeProvider.future);
      await settle();

      expect(phaseOf(c), SessionPhase.inactive);
    });

    test('Home saying "active" brings a paused farmer back', () async {
      backend.scenario = MockScenario.accountPaused;
      final c = await bed.signedIn('9000000101');
      expect(phaseOf(c), SessionPhase.inactive);
      backend.scenario = MockScenario.normal;

      await c.read(farmerHomeProvider.future);
      await settle();

      expect(phaseOf(c), SessionPhase.active);
    });

    test('a write refused as deactivated goes to Account paused', () async {
      final c = await bed.signedIn('9000000101');
      backend.scenario = MockScenario.accountPaused;

      await expectLater(
        c.read(farmerProfileRepositoryProvider).updateProfile(name: 'Ravi'),
        throwsApiError(ApiErrorCode.forbidden),
      );
      await settle();

      expect(phaseOf(c), SessionPhase.inactive);
    });

    /// A sign-up stopped after consent whose app opened on Home anyway (an
    /// install from before the phase was saved, offline at start).
    Future<ProviderContainer> incompleteSignUpOnHome() async {
      final first = await bed.signedIn('9876543210');
      await first.read(sessionProvider.notifier).giveConsent();
      expect(phaseOf(first), SessionPhase.needsVillage);
      first.dispose();
      await store.writePhase(SessionPhase.active);

      backend.scenario = MockScenario.offline;
      final c = await bed.start();
      expect(phaseOf(c), SessionPhase.active);
      backend.scenario = MockScenario.normal;
      return c;
    }

    test('Home saying "pending_profile" resumes the sign-up', () async {
      final c = await incompleteSignUpOnHome();

      await c.read(farmerHomeProvider.future);
      await settle();

      expect(phaseOf(c), SessionPhase.needsVillage);
    });

    test('a write refused as profile_incomplete resumes the sign-up', () async {
      final c = await incompleteSignUpOnHome();

      await expectLater(
        c.read(farmerProfileRepositoryProvider).updateProfile(name: 'Ramu'),
        throwsApiError(ApiErrorCode.profileIncomplete),
      );
      await settle();

      expect(phaseOf(c), SessionPhase.needsVillage);
    });

    test('concurrent re-checks share one request', () async {
      final c = await bed.signedIn('9000000101');
      final session = c.read(sessionProvider.notifier);
      expect(identical(session.recheck(), session.recheck()), isTrue);
      await session.recheck();
      expect(phaseOf(c), SessionPhase.active);
    });

    test(
      'applyStatus keeps the phase when the consents cannot be read',
      () async {
        final c = await bed.signedIn('9000000101');
        bed.script.failNext('listConsents', const ApiError.network());

        await c
            .read(sessionProvider.notifier)
            .applyStatus(FarmerStatus.pendingProfile);

        expect(phaseOf(c), SessionPhase.active);
      },
    );
  });

  group('answers that arrive after the session moved on', () {
    test('a 401 while complete-profile routes leaves phone entry, not Home '
        'without a farmer', () async {
      final c = await bed.signedIn('9876543210');
      final session = c.read(sessionProvider.notifier);
      await session.giveConsent();
      session.pickVillage(await _kondapur(c));
      final saved = bed.script.holdNext('completeProfile');
      final read = bed.script.holdNext('getHome');

      final completing = session.completeProfile(name: 'Ramu');
      await settle();
      // The profile is saved on the server; the session then ends, so the
      // read after it gets a 401 and the hook signs out before that answer
      // reaches complete-profile.
      backend.scenario = MockScenario.sessionRevoked;
      saved.complete();
      await settle();
      expect(phaseOf(c), SessionPhase.signedOut);
      read.complete();
      await completing;
      await settle();

      final s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.signedOut);
      expect(s.farmerId, isNull);
      expect(await store.readSession(), isNull);
    });

    test('consent saved after the session ended does not move on', () async {
      final c = await bed.signedIn('9876543210');
      final session = c.read(sessionProvider.notifier);
      final saved = bed.script.holdNext('setConsent');

      final consenting = session.giveConsent();
      await settle();
      report(c, sessionEnded, farmerId: c.read(sessionProvider).farmerId);
      await settle();
      saved.complete();
      await consenting;

      expect(phaseOf(c), SessionPhase.signedOut);
      expect(c.read(sessionProvider).farmerId, isNull);
    });

    test(
      'a code verified after Edit phone does not sign that farmer in',
      () async {
        final c = await bed.start();
        final session = c.read(sessionProvider.notifier);
        await session.requestOtp('9000000101');
        final verified = bed.script.holdNext('verifyOtp');

        final verifying = session.verifyOtp(MockBackend.fixedOtp);
        await settle();
        session.editPhone();
        await session.requestOtp('9000000102');
        verified.complete();
        await verifying;
        await settle();

        final s = c.read(sessionProvider);
        expect(s.phase, SessionPhase.otpSent);
        expect(s.phone, MockBackend.venkateshPhone);
        expect(s.farmerId, isNull);
        expect(await store.readSession(), isNull, reason: 'Ravi signed out');

        await session.verifyOtp(MockBackend.fixedOtp);
        final home = await c.read(farmerProfileRepositoryProvider).getHome();
        expect(home.farmer.phone, MockBackend.venkateshPhone);
      },
    );

    test('a resend that returns after sign-in does not reopen the OTP '
        'screen', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.requestOtp('9000000101');
      bed.clock.advance(const Duration(seconds: 31));
      final resent = bed.script.holdNext('requestOtp');

      final resending = session.resendOtp();
      await settle();
      await session.verifyOtp(MockBackend.fixedOtp);
      resent.complete();
      await resending;

      expect(phaseOf(c), SessionPhase.active);
    });

    test('a re-check that returns after sign-out and sign-in again is '
        'dropped', () async {
      final c = await bed.signedIn('9000000101');
      final session = c.read(sessionProvider.notifier);
      backend.scenario = MockScenario.accountPaused;
      final answer = bed.script.holdNext('getHome');

      final rechecking = session.recheck();
      await settle();
      await session.signOut();
      backend.scenario = MockScenario.normal;
      bed.clock.advance(const Duration(seconds: 31)); // the OTP resend wait
      await signInOn(c, '9000000101'); // the same farmer, a new session
      answer.complete();
      await rechecking;

      expect(phaseOf(c), SessionPhase.active, reason: 'not the old "inactive"');
      // A re-check for the new session is a new request.
      await session.recheck();
      expect(phaseOf(c), SessionPhase.active);
    });

    test('applyStatus that returns after another farmer signed in is '
        'dropped', () async {
      final c = await bed.signedIn('9000000101');
      final session = c.read(sessionProvider.notifier);
      final answer = bed.script.holdNext('listConsents');

      final applying = session.applyStatus(FarmerStatus.pendingProfile);
      await settle();
      await session.signOut();
      await signInOn(c, '9000000102');
      answer.complete();
      await applying;

      expect(phaseOf(c), SessionPhase.active);
      expect(c.read(sessionProvider).phone, MockBackend.venkateshPhone);
    });
  });

  group('offline start', () {
    test('an unfinished sign-up resumes at its step, not Home', () async {
      final first = await bed.signedIn('9876543210');
      await first.read(sessionProvider.notifier).giveConsent();
      first.dispose();

      backend.scenario = MockScenario.offline;
      expect(phaseOf(await bed.start()), SessionPhase.needsVillage);

      backend.scenario = MockScenario.normal;
      final second = await bed.start();
      second
          .read(sessionProvider.notifier)
          .pickVillage(await _kondapur(second));
      expect(phaseOf(second), SessionPhase.needsName);
      await settle();
      second.dispose();

      // The picked village is not saved: back to the picker.
      backend.scenario = MockScenario.offline;
      expect(phaseOf(await bed.start()), SessionPhase.needsVillage);
    });

    test('a paused farmer stays paused', () async {
      backend.scenario = MockScenario.accountPaused;
      final first = await bed.signedIn('9000000101');
      expect(phaseOf(first), SessionPhase.inactive);
      await settle();
      first.dispose();

      backend.scenario = MockScenario.offline;
      expect(phaseOf(await bed.start()), SessionPhase.inactive);
    });

    test('sign-out forgets the saved phase', () async {
      final c = await bed.signedIn('9000000101');
      await settle();
      expect(await store.readPhase(), SessionPhase.active);
      await c.read(sessionProvider.notifier).signOut();
      expect(await store.readPhase(), isNull);
    });
  });
}

Future<Village> _kondapur(ProviderContainer c) async =>
    (await c.read(geoRepositoryProvider).searchVillages(query: 'Kondapur'))
        .single;
