import 'dart:async';

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/data/session/session_controller.dart';
import 'package:fa/src/data/session/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import 'session_fakes.dart';

Matcher _apiError(String code) =>
    throwsA(isA<ApiError>().having((e) => e.code, 'code', code));

Matcher _fieldError(String field, String reason) => throwsA(
  isA<ApiError>()
      .having((e) => e.code, 'code', ApiErrorCode.validationFailed)
      .having(
        (e) => (e.details['fields']! as Map<String, Object?>)[field],
        field,
        reason,
      ),
);

/// The FA session: start, login, password change, setup, PIN unlock, lock,
/// logout, heartbeat and the update block.
void main() {
  late SessionBed bed;

  setUp(() => bed = SessionBed());

  group('start', () {
    test('restoring, then signed out in Telugu, without network', () async {
      bed.auth.offline = true;
      final c = bed.startUnrestored();
      expect(phaseOf(c), SessionPhase.restoring);
      await c.read(sessionProvider.notifier).restored;
      expect(phaseOf(c), SessionPhase.signedOut);
      expect(c.read(appLanguageProvider), Language.te);
      expect(c.read(sessionProvider).isSignedIn, isFalse);
    });

    test('a saved session with a PIN opens locked, offline', () async {
      (await bed.active()).dispose();
      bed.auth.offline = true;

      final c = await bed.start();
      final s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.locked);
      expect(s.fa?.code, sureshCode);
      expect(s.pinAttemptsLeft, 5);
      expect(s.graceEndsAt, testStart.add(const Duration(days: 7)));
    });

    test('a session without a PIN resumes at setup', () async {
      final first = await bed.start();
      await first
          .read(sessionProvider.notifier)
          .login(sureshCode, sureshPassword);
      expect(phaseOf(first), SessionPhase.setup);
      first.dispose();

      expect(phaseOf(await bed.start()), SessionPhase.setup);
    });

    test('an unreadable store signs out instead of hanging', () async {
      final c = await bed.start(store: ThrowingStore());
      expect(phaseOf(c), SessionPhase.signedOut);
    });
  });

  group('login', () {
    test('first login: setup (language, PIN) -> active', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);

      await session.login('  fa-kdp-014 ', sureshPassword);
      var s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.setup);
      expect(s.fa?.name, 'Suresh Kumar');
      expect(s.pinAttemptsLeft, isNull);
      expect(await bed.store.readLastOnlineAt(), testStart);
      expect(bed.auth.deviceKeys.single, await bed.store.deviceKey());

      await session.setLanguage(Language.en);
      expect(c.read(appLanguageProvider), Language.en);
      await expectLater(
        session.setPin('1234'),
        _fieldError('pin', 'sequential'),
      );
      await expectLater(session.setPin('12'), _fieldError('pin', 'wrongShape'));
      expect(phaseOf(c), SessionPhase.setup);
      expect(await bed.store.readPin(), isNull);

      await session.setPin(goodPin);
      s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.active);
      expect(s.pinAttemptsLeft, 5);
      expect(await bed.store.readPin(), isNotNull);
      expect(await bed.store.readLanguage(), Language.en);
    });

    test('a wrong password throws and stays signed out', () async {
      final c = await bed.start();
      await expectLater(
        c.read(sessionProvider.notifier).login(sureshCode, 'nope'),
        _apiError(ApiErrorCode.unauthorized),
      );
      expect(phaseOf(c), SessionPhase.signedOut);
      expect(await bed.store.readSession(), isNull);
    });

    test(
      'an expired temporary password is the login screen\'s error',
      () async {
        final c = await bed.start();
        await expectLater(
          c.read(sessionProvider.notifier).login(expiredCode, 'temp5678'),
          _apiError(ApiErrorCode.tempPasswordExpired),
        );
        expect(phaseOf(c), SessionPhase.signedOut);
      },
    );

    test('device_revoked on login wipes the phone', () async {
      final c = await bed.start();
      final key = await bed.store.deviceKey();
      bed.auth.failNext('login', deviceRevoked);
      await expectLater(
        c.read(sessionProvider.notifier).login(sureshCode, sureshPassword),
        _apiError(ApiErrorCode.deviceRevoked),
      );
      expect(phaseOf(c), SessionPhase.removed);
      expect(bed.guard.wipes, 1);
      expect(await bed.store.deviceKey(), isNot(key));
    });

    test('logs the heartbeat after login', () async {
      final c = await bed.start();
      await c.read(sessionProvider.notifier).login(sureshCode, sureshPassword);
      await settle();
      expect(bed.auth.count('heartbeat'), 1);
    });
  });

  group('temporary password', () {
    test('change password -> clean token -> setup', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.login(tempCode, tempPassword);
      expect(phaseOf(c), SessionPhase.mustChangePassword);
      await settle();
      expect(bed.auth.count('heartbeat'), 0, reason: 'would be a 403');

      await expectLater(
        session.changePassword(tempPassword, 'short1'),
        _fieldError('new_password', 'must be at least 8 characters'),
      );
      await expectLater(
        session.changePassword(tempPassword, 'longpassword'),
        _fieldError('new_password', 'must contain a letter and a digit'),
      );
      await expectLater(
        session.changePassword(tempPassword, 'my-fa-kdp-099-x1'),
        _fieldError('new_password', 'must not contain your login ID or email'),
      );
      await expectLater(
        session.changePassword('temp1234', 'temp1234'),
        _fieldError(
          'new_password',
          'must be different from the current password',
        ),
      );
      expect(bed.auth.count('changePassword'), 0, reason: 'checked first');

      await session.changePassword(tempPassword, 'paddy2026');
      expect(phaseOf(c), SessionPhase.setup);
      expect(
        bed.auth.calls,
        containsAllInOrder(['changePassword', 'refreshSession']),
      );
      expect((await bed.store.readSession())!.mustChangePassword, isFalse);

      c.dispose();
      expect(phaseOf(await bed.start()), SessionPhase.setup);
    });

    test('a wrong current password is the screen\'s error', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.login(tempCode, tempPassword);
      // The backend's answer: 400 with fields.current_password.
      await expectLater(
        session.changePassword('wrong123', 'paddy2026'),
        _apiError(ApiErrorCode.validationFailed),
      );
      await settle();
      expect(phaseOf(c), SessionPhase.mustChangePassword);
      expect(c.read(sessionProvider).syncNeedsPassword, isFalse);
    });

    test('the clean-token refresh is retried when it failed', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.login(tempCode, tempPassword);
      bed.auth.failNext('refreshSession', const ApiError.network());

      await session.changePassword(tempPassword, 'paddy2026');
      expect(phaseOf(c), SessionPhase.setup);
      expect((await bed.store.readSession())!.mustChangePassword, isTrue);

      // A restart does not ask for the password change again.
      c.dispose();
      final c2 = await bed.start();
      expect(phaseOf(c2), SessionPhase.setup);
      // The start-up heartbeat refreshed first.
      expect(bed.auth.count('refreshSession'), 2);
      expect((await bed.store.readSession())!.mustChangePassword, isFalse);
      expect(bed.auth.count('heartbeat'), 1);
    });
  });

  group('PIN unlock', () {
    test('wrong PIN counts down, the right one opens', () async {
      final c = await bed.active();
      c.read(sessionProvider.notifier).lock();
      final session = c.read(sessionProvider.notifier);
      expect(phaseOf(c), SessionPhase.locked);

      expect(await session.unlock(wrongPin), isFalse);
      expect(c.read(sessionProvider).pinAttemptsLeft, 4);
      expect(phaseOf(c), SessionPhase.locked);
      expect((await bed.store.readPin())!.failedAttempts, 1);

      expect(await session.unlock(goodPin), isTrue);
      expect(phaseOf(c), SessionPhase.active);
      expect(c.read(sessionProvider).pinAttemptsLeft, 5);
    });

    test('5 wrong PINs need the password; unsynced work is kept', () async {
      final c = await bed.active();
      bed.guard.pending = 3;
      final session = c.read(sessionProvider.notifier);
      session.lock();

      for (var i = 0; i < 4; i++) {
        expect(await session.unlock(wrongPin), isFalse);
      }
      expect(c.read(sessionProvider).pinAttemptsLeft, 1);
      expect(await session.unlock(goodPin.split('').reversed.join()), isFalse);
      var s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.passwordNeeded);
      expect(s.passwordNeededReason, PasswordNeededReason.lockedOut);
      expect(s.canUsePin, isFalse);
      expect(bed.guard.wipes, 0);
      expect(bed.guard.pending, 3);

      // Still locked out after a restart.
      c.dispose();
      final c2 = await bed.start();
      s = c2.read(sessionProvider);
      expect(s.phase, SessionPhase.passwordNeeded);
      expect(s.passwordNeededReason, PasswordNeededReason.lockedOut);

      // The password login drops the old PIN: pick a new one.
      await c2.read(sessionProvider.notifier).login(sureshCode, sureshPassword);
      expect(phaseOf(c2), SessionPhase.setup);
      expect(await bed.store.readPin(), isNull);
      expect(bed.guard.wipes, 0);
    });

    test('a double tap does not lose a wrong try', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      session.lock();
      final results = await Future.wait([
        session.unlock(wrongPin),
        session.unlock(wrongPin),
      ]);
      expect(results, [false, false]);
      expect(c.read(sessionProvider).pinAttemptsLeft, 3);
    });

    test('the PIN stops working offline after the grace', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      session.lock();

      bed.clock.advance(const Duration(days: 6, hours: 23));
      expect(await session.unlock(goodPin), isTrue);
      session.lock();

      bed.clock.advance(const Duration(hours: 1));
      expect(await session.unlock(goodPin), isFalse);
      final s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.passwordNeeded);
      expect(s.passwordNeededReason, PasswordNeededReason.expired);
      expect(s.canUsePin, isFalse);
    });

    test('lock after the grace goes on to the password', () async {
      final c = await bed.active();
      bed.clock.advance(const Duration(days: 8));
      c.read(sessionProvider.notifier).lock();
      await settle();
      expect(
        c.read(sessionProvider).passwordNeededReason,
        PasswordNeededReason.expired,
      );
    });

    test('a refresh by the HTTP layer extends the grace', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      bed.clock.advance(const Duration(days: 5));
      await bed.store.writeLastOnlineAt(bed.clock.now()); // a refresh
      bed.clock.advance(const Duration(days: 5));
      session.lock();
      await settle();
      expect(phaseOf(c), SessionPhase.locked);
      expect(await session.unlock(goodPin), isTrue);
    });

    test('a restart after the grace asks for the password', () async {
      (await bed.active()).dispose();
      bed.clock.advance(const Duration(days: 7, minutes: 1));
      bed.auth.offline = true;
      final c = await bed.start();
      expect(phaseOf(c), SessionPhase.passwordNeeded);
      expect(
        c.read(sessionProvider).passwordNeededReason,
        PasswordNeededReason.expired,
      );
    });

    test('use password instead keeps the PIN for the same FA', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      session.lock();
      final pin = await bed.store.readPin();

      session.usePassword();
      var s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.passwordNeeded);
      expect(s.passwordNeededReason, isNull);
      expect(s.canUsePin, isTrue);
      expect(s.fa?.code, sureshCode, reason: 'prefills the login ID');

      session.usePin();
      expect(phaseOf(c), SessionPhase.locked);
      session.usePassword();

      bed.clock.advance(const Duration(hours: 2));
      await session.login(sureshCode, sureshPassword);
      s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.active);
      expect(await bed.store.readPin(), pin);
      expect(s.graceEndsAt, bed.clock.now().add(const Duration(days: 7)));
    });

    test('change PIN checks the old one', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      await expectLater(
        session.changePin(goodPin, '0000'),
        _fieldError('pin', 'repeated'),
      );
      expect(await session.changePin(wrongPin, '3691'), isFalse);
      expect(c.read(sessionProvider).pinAttemptsLeft, 4);
      expect(await session.changePin(goodPin, '3691'), isTrue);
      session.lock();
      expect(await session.unlock(goodPin), isFalse);
      expect(await session.unlock('3691'), isTrue);
    });

    test('actions outside their phase are refused', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await expectLater(session.unlock(goodPin), throwsStateError);
      await expectLater(session.setPin(goodPin), throwsStateError);
      expect(session.usePassword, throwsStateError);
    });
  });

  group('logout', () {
    test('warns with the count, keeps the outbox, forgets the PIN', () async {
      final c = await bed.active();
      bed.guard.pending = 3;
      final session = c.read(sessionProvider.notifier);
      expect(await session.unsyncedCount(), 3);

      expect(await session.logout(), 3);
      expect(phaseOf(c), SessionPhase.signedOut);
      expect(bed.auth.count('logout'), 1);
      expect(await bed.store.readSession(), isNull);
      expect(await bed.store.readPin(), isNull);
      expect(bed.guard.wipes, 0);
      expect(bed.guard.pending, 3);

      c.dispose();
      final c2 = await bed.start();
      expect(phaseOf(c2), SessionPhase.signedOut);

      // The same FA logs in again: nothing is wiped, a new PIN is set.
      await c2.read(sessionProvider.notifier).login(sureshCode, sureshPassword);
      expect(phaseOf(c2), SessionPhase.setup);
      expect(bed.guard.wipes, 0);
    });

    test('another FA is warned about unsynced records first', () async {
      final c = await bed.active();
      bed.guard.pending = 3;
      final session = c.read(sessionProvider.notifier);
      await session.logout();

      await expectLater(
        session.login(otherCode, 'chevella1'),
        throwsA(
          isA<OtherFaOnPhone>()
              .having((e) => e.previousCode, 'previousCode', sureshCode)
              .having((e) => e.previousName, 'previousName', 'Suresh Kumar')
              .having((e) => e.unsynced, 'unsynced', 3),
        ),
      );
      expect(bed.auth.count('login'), 1, reason: 'nothing sent');
      expect(bed.guard.wipes, 0);
      expect(
        (await bed.store.readMeta()).lastOwner,
        isA<PhoneOwner>().having((o) => o.code, 'code', sureshCode),
        reason: 'the owner survives the logout',
      );

      await session.login(otherCode, 'chevella1', replaceOtherFa: true);
      expect(bed.guard.wipes, 1);
      final s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.setup);
      expect(s.fa?.code, otherCode);
    });

    test('another FA on the PIN screen: the old PIN and data go', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      session.lock();
      session.usePassword();

      await session.login(otherCode, 'chevella1');
      expect(bed.guard.wipes, 1, reason: 'nothing unsynced: no question');
      expect(phaseOf(c), SessionPhase.setup);
      expect(await bed.store.readPin(), isNull);
    });

    test('a wrong password from another FA wipes nothing', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      await session.logout();
      await expectLater(
        session.login(otherCode, 'wrong'),
        _apiError(ApiErrorCode.unauthorized),
      );
      expect(bed.guard.wipes, 0);
    });

    test('discarding unsynced records wipes local data', () async {
      final c = await bed.active();
      bed.guard.pending = 2;
      await c.read(sessionProvider.notifier).logout(discardUnsynced: true);
      expect(bed.guard.wipes, 1);
      await c.read(sessionProvider.notifier).login(otherCode, 'chevella1');
      expect(bed.guard.wipes, 1, reason: 'nobody else\'s data is left');
    });

    test('logout works offline', () async {
      final c = await bed.active();
      bed.auth.offline = true;
      await c.read(sessionProvider.notifier).logout();
      expect(phaseOf(c), SessionPhase.signedOut);
      expect(await bed.store.readSession(), isNull);
    });
  });

  group('heartbeat and updates', () {
    test('wipe: local data, tokens, PIN and install ID go', () async {
      final c = await bed.active();
      final key = await bed.store.deviceKey();
      bed.auth.heartbeatWipe = true;

      await c.read(sessionProvider.notifier).recheck();
      final s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.removed);
      expect(s.fa, isNull);
      expect(bed.guard.wipes, 1);
      expect(await bed.store.readSession(), isNull);
      expect(await bed.store.readPin(), isNull);
      expect(await bed.store.deviceKey(), isNot(key));

      c.dispose();
      bed.auth.heartbeatWipe = false;
      final c2 = await bed.start();
      expect(phaseOf(c2), SessionPhase.removed);
      c2.read(sessionProvider.notifier).startOver();
      expect(phaseOf(c2), SessionPhase.signedOut);
    });

    test('update required: the outbox is pushed first, then block', () async {
      final c = await bed.active();
      bed.guard
        ..pending = 3
        ..pushGate = Completer();
      bed.auth.heartbeatUpdate = true;
      bed.auth.minVersion = '0.2.0';

      final check = c.read(sessionProvider.notifier).recheck();
      await settle();
      expect(bed.guard.pushes, 1);
      expect(phaseOf(c), SessionPhase.active, reason: 'still pushing');

      bed.guard.pushGate!.complete();
      await check;
      expect(phaseOf(c), SessionPhase.updateRequired);
      expect(bed.guard.pending, 0);
      expect(bed.guard.wipes, 0);

      // Blocked again after a restart, even offline.
      c.dispose();
      bed.auth.offline = true;
      expect(phaseOf(await bed.start()), SessionPhase.updateRequired);
    });

    test('update required offline: blocks, the outbox stays', () async {
      final c = await bed.active();
      bed.guard
        ..pending = 3
        ..pushWorks = false;
      bed.auth.heartbeatUpdate = true;
      await c.read(sessionProvider.notifier).recheck();
      expect(phaseOf(c), SessionPhase.updateRequired);
      expect(bed.guard.pending, 3);
    });

    test('app-config below min_version blocks at start', () async {
      bed.auth.minVersion = '1.0.5';
      final c = await bed.start();
      expect(phaseOf(c), SessionPhase.updateRequired);
      expect(c.read(sessionProvider).appConfig?.minVersion, '1.0.5');
      expect(bed.guard.pushes, 0, reason: 'nobody signed in');
      c.dispose();

      // After the update the block lifts, offline too.
      bed.appVersion = '1.0.5';
      bed.auth.offline = true;
      expect(phaseOf(await bed.start()), SessionPhase.signedOut);
    });

    test('a newer version shows the dismissable card only', () async {
      bed.auth.latestVersion = '0.2.0';
      final c = await bed.start();
      final s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.signedOut);
      expect(s.updateAvailable, isTrue);
    });

    test('keeps the server clock offset', () async {
      final c = await bed.active();
      bed.auth.serverAhead = const Duration(minutes: -3);
      await c.read(sessionProvider.notifier).recheck();
      expect(c.read(sessionProvider).clockOffset, const Duration(minutes: -3));
      expect(
        c.read(serverClockProvider).now(),
        bed.clock.now().subtract(const Duration(minutes: 3)),
      );
    });

    test('concurrent rechecks share one heartbeat', () async {
      final c = await bed.active();
      final before = bed.auth.count('heartbeat');
      final session = c.read(sessionProvider.notifier);
      await Future.wait([session.recheck(), session.recheck()]);
      expect(bed.auth.count('heartbeat'), before + 1);
    });

    test('recheck offline throws and changes nothing', () async {
      final c = await bed.active();
      bed.auth.offline = true;
      await expectLater(
        c.read(sessionProvider.notifier).recheck(),
        _apiError(ApiErrorCode.network),
      );
      expect(phaseOf(c), SessionPhase.active);
    });
  });

  group('races', () {
    test('a login answer after logout does not sign in', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      final gate = bed.auth.holdNext('login');
      final login = session.login(sureshCode, sureshPassword);
      await settle();

      await session.logout();
      gate.complete();
      await login;
      await settle();

      expect(phaseOf(c), SessionPhase.signedOut);
      // The answer saved the session after the logout; it was signed out.
      expect(bed.auth.count('logout'), 2);
      expect(await bed.store.readSession(), isNull, reason: 'dropped');
      c.dispose();
      expect(phaseOf(await bed.start()), SessionPhase.signedOut);
    });

    test('a login answer after a wipe keeps the phone removed', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      session.lock();
      session.usePassword();
      final gate = bed.auth.holdNext('login');
      final login = session.login(sureshCode, sureshPassword);
      await settle();

      bed.hook.report(deviceRevoked);
      await settle();
      expect(phaseOf(c), SessionPhase.removed);
      gate.complete();
      await login;
      await settle();

      expect(phaseOf(c), SessionPhase.removed);
      expect(await bed.store.readSession(), isNull);
      c.dispose();
      expect(phaseOf(await bed.start()), SessionPhase.removed);
    });

    test('a heartbeat answer after logout still blocks an old app', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      bed.auth.heartbeatUpdate = true;
      final gate = bed.auth.holdNext('heartbeat');
      final check = session.recheck();
      await settle();
      await session.logout();
      gate.complete();
      await check;
      await settle();
      // The server's word wins: the app is too old whoever is signed in.
      expect(phaseOf(c), SessionPhase.updateRequired);
      expect(await bed.store.readSession(), isNull);
    });
  });
}
