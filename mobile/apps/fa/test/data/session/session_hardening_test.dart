import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/data/session/auth_failures.dart';
import 'package:fa/src/data/session/session_controller.dart';
import 'package:fa/src/data/session/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import 'session_fakes.dart';

/// The session's answers to the review findings: wipes that must finish,
/// the right message for a wrong password, PINs that keep their tries and
/// their grace, late answers that must not touch a newer sign-in.
void main() {
  late SessionBed bed;

  setUp(() => bed = SessionBed());

  String? faIdOf(ProviderContainer c) => c.read(sessionProvider).fa?.id;

  group('a wipe that fails is finished later', () {
    test(
      'no removed screen until the data is gone; a restart retries',
      () async {
        final c = await bed.active();
        bed.guard
          ..pending = 3
          ..wipeFailures = 1;
        bed.hook.report(deviceRevoked, faId: faIdOf(c));
        await settle();

        expect(phaseOf(c), SessionPhase.restoring, reason: 'the splash');
        expect(bed.guard.pending, 3);
        expect(await bed.store.readSession(), isNull, reason: 'tokens gone');
        expect((await bed.store.readMeta()).wipePending, isTrue);
        await expectLater(
          c.read(sessionProvider.notifier).login(otherCode, 'chevella1'),
          throwsStateError,
          reason: 'nobody signs in over the old data',
        );

        c.dispose();
        final c2 = await bed.start();
        expect(phaseOf(c2), SessionPhase.removed);
        expect(bed.guard.pending, 0);
        expect((await bed.store.readMeta()).wipePending, isFalse);
      },
    );

    test('the next resume (recheck) retries too', () async {
      final c = await bed.active();
      bed.guard.wipeFailures = 1;
      bed.hook.report(deviceRevoked);
      await settle();
      expect(phaseOf(c), SessionPhase.restoring);

      await c.read(sessionProvider.notifier).recheck();
      await settle();
      expect(phaseOf(c), SessionPhase.removed);
      expect(bed.guard.wipes, 2);
    });

    test('another FA cannot log in while the old data stays', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      bed.guard.pending = 2;
      await session.logout();
      bed.guard.wipeFailures = 1;

      await expectLater(
        session.login(otherCode, 'chevella1', replaceOtherFa: true),
        throwsA(isA<LocalDataWipeFailed>()),
      );
      expect(phaseOf(c), SessionPhase.signedOut);
      expect(await bed.store.readSession(), isNull, reason: 'signed out again');
      expect(bed.guard.pending, 2);
      // Still Suresh's data: the next login of another FA asks again.
      await expectLater(
        session.login(otherCode, 'chevella1'),
        throwsA(isA<OtherFaOnPhone>()),
      );

      await session.login(otherCode, 'chevella1', replaceOtherFa: true);
      expect(phaseOf(c), SessionPhase.setup);
      expect(bed.guard.pending, 0);
    });
  });

  group('the password change', () {
    test(
      'a 401 on Me\'s change ends the session; it is no wrong password',
      () async {
        final c = await bed.active();
        bed.auth.failNext('changePassword', sessionEnded);
        await expectLater(
          c
              .read(sessionProvider.notifier)
              .changePassword(sureshPassword, 'paddy2026x'),
          throwsA(isA<ApiError>()),
        );
        await settle();
        expect(c.read(sessionProvider).syncNeedsPassword, isTrue);
      },
    );

    test(
      'a 401 on the first-login change asks for the password again',
      () async {
        final c = await bed.start();
        final session = c.read(sessionProvider.notifier);
        await session.login(tempCode, tempPassword);
        bed.auth.failNext('changePassword', sessionEnded);
        await expectLater(
          session.changePassword(tempPassword, 'paddy2026'),
          throwsA(isA<ApiError>()),
        );
        await settle();
        final s = c.read(sessionProvider);
        expect(s.phase, SessionPhase.passwordNeeded);
        expect(s.passwordNeededReason, PasswordNeededReason.sessionEnded);
      },
    );

    test(
      'changed but not refreshed: the PIN still opens after "Use password"',
      () async {
        final c = await bed.start();
        final session = c.read(sessionProvider.notifier);
        await session.login(tempCode, tempPassword);
        bed.auth.failNext('refreshSession', const ApiError.network());
        await session.changePassword(tempPassword, 'paddy2026');
        await session.setPin(goodPin);
        bed.auth.offline = true;
        session
          ..lock()
          ..usePassword();
        expect(c.read(sessionProvider).canUsePin, isTrue);
        session.usePin();
        expect(await session.unlock(goodPin), isTrue);
      },
    );

    test('concurrent password_change_required share one refresh', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.login(tempCode, tempPassword);
      bed.auth.failNext('refreshSession', const ApiError.network());
      await session.changePassword(tempPassword, 'paddy2026');
      final gate = bed.auth.holdNext('refreshSession');
      for (var i = 0; i < 3; i++) {
        bed.hook.report(passwordChangeRequired, faId: faIdOf(c));
      }
      await settle();
      expect(bed.auth.count('refreshSession'), 2);
      gate.complete();
      await settle();
      final saved = (await bed.store.readSession())!;
      expect(saved.mustChangePassword, isFalse);
      expect(
        saved.tokens.refreshToken,
        'refresh-2',
        reason: 'the pair the refresh saved',
      );
    });

    test(
      'an answer lost after the server changed it: a restart finds out',
      () async {
        final c = await bed.start();
        final session = c.read(sessionProvider.notifier);
        await session.login(tempCode, tempPassword);
        bed.auth.loseNextAnswer('changePassword');
        await expectLater(
          session.changePassword(tempPassword, 'paddy2026'),
          throwsA(isA<ApiError>()),
        );
        expect(phaseOf(c), SessionPhase.mustChangePassword);
        expect((await bed.store.readMeta()).passwordChangeSent, isTrue);

        c.dispose();
        final c2 = await bed.start();
        expect(phaseOf(c2), SessionPhase.setup, reason: 'the refresh is clean');
        expect((await bed.store.readMeta()).passwordChangeSent, isFalse);
      },
    );

    test('a change that never reached the server is asked again', () async {
      final c = await bed.start();
      final session = c.read(sessionProvider.notifier);
      await session.login(tempCode, tempPassword);
      bed.auth.failNext('changePassword', const ApiError.network());
      await expectLater(
        session.changePassword(tempPassword, 'paddy2026'),
        throwsA(isA<ApiError>()),
      );
      c.dispose();
      final c2 = await bed.start();
      expect(phaseOf(c2), SessionPhase.mustChangePassword);
      expect((await bed.store.readMeta()).passwordChangeSent, isFalse);
    });
  });

  test('a late 401 of an earlier sign-in of the same FA is ignored', () async {
    final c = await bed.active();
    final session = c.read(sessionProvider.notifier);
    session
      ..lock()
      ..usePassword();
    bed.auth.failNext('heartbeat', sessionEnded);
    final gate = bed.auth.holdNext('heartbeat');
    final heartbeat = session.recheck().catchError((Object _) {});
    await settle();
    await session.login(sureshCode, sureshPassword);
    await settle();
    gate.complete();
    await heartbeat;
    await settle();
    expect(phaseOf(c), SessionPhase.active);
    expect(c.read(sessionProvider).syncNeedsPassword, isFalse);
  });

  test('the hook hands the sign-in key to listeners that take it', () {
    final hook = AuthFailureHook();
    final got = <(String?, String?)>[];
    String? plain;
    hook
      ..listen((error, {faId, sessionKey}) => got.add((faId, sessionKey)))
      ..listen((error, {faId}) => plain = faId)
      ..report(sessionEnded, faId: 'fa-1', sessionKey: 'k1');
    expect(got, [('fa-1', 'k1')]);
    expect(plain, 'fa-1');
  });

  group('the offline grace and the clock', () {
    test('a clock set back ends the grace', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      session.lock();
      bed.clock.advance(const Duration(days: 3));
      expect(await session.unlock(goodPin), isTrue);
      session.lock();
      bed.clock.set(testStart.add(const Duration(hours: 1)));
      expect(await session.unlock(goodPin), isFalse);
      final s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.passwordNeeded);
      expect(s.passwordNeededReason, PasswordNeededReason.expired);
      expect(s.canUsePin, isFalse);
    });

    test('also across a restart', () async {
      final c = await bed.active();
      bed.clock.advance(const Duration(days: 3));
      c.read(sessionProvider.notifier).lock();
      c.dispose();
      bed.clock.set(testStart);
      bed.auth.offline = true;
      final c2 = await bed.start();
      expect(phaseOf(c2), SessionPhase.passwordNeeded);
    });

    test(
      'a small correction is fine; the latest time never moves back',
      () async {
        final c = await bed.active();
        final session = c.read(sessionProvider.notifier);
        bed.clock.advance(const Duration(hours: 2));
        session.lock();
        await settle();
        final seen = (await bed.store.readMeta()).lastSeenAt;
        expect(seen, bed.clock.now());
        bed.clock.set(bed.clock.now().subtract(const Duration(minutes: 5)));
        expect(await session.unlock(goodPin), isTrue);
        await settle();
        expect((await bed.store.readMeta()).lastSeenAt, seen);
      },
    );
  });

  group('unsynced records that cannot be counted', () {
    test('another FA\'s login stops before anything is sent', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      await session.logout();
      bed.guard.countFails = true;
      final logins = bed.auth.count('login');
      await expectLater(
        session.login(otherCode, 'chevella1'),
        throwsStateError,
      );
      expect(bed.auth.count('login'), logins);
      expect(bed.guard.wipes, 0);
      await expectLater(session.unsyncedCount(), throwsStateError);
    });
  });

  group('the heartbeat verdict', () {
    test('a wipe applies even after a block landed meanwhile', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      bed.auth.heartbeatWipe = true;
      bed.guard.pending = 2;
      final gate = bed.auth.holdNext('heartbeat');
      final check = session.recheck();
      await settle();
      bed.auth.minVersion = '9.0.0';
      await session.refreshAppConfig();
      expect(phaseOf(c), SessionPhase.updateRequired);
      gate.complete();
      await check;
      await settle();
      expect(phaseOf(c), SessionPhase.removed);
      expect(bed.guard.pending, 0);
    });

    test('but not for a sign-in that another one replaced', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      bed.auth.heartbeatWipe = true;
      final gate = bed.auth.holdNext('heartbeat');
      final check = session.recheck();
      await settle();
      await session.logout();
      bed.auth.heartbeatWipe = false;
      await session.login(otherCode, 'chevella1');
      gate.complete();
      await check;
      await settle();
      expect(phaseOf(c), SessionPhase.setup);
      expect(bed.guard.wipes, 1, reason: 'only the switch of FA');
    });

    test('only a heartbeat lifts a heartbeat block', () async {
      final c = await bed.active();
      final session = c.read(sessionProvider.notifier);
      bed.auth.heartbeatUpdate = true;
      bed.auth.minVersion = '0.2.0';
      await session.recheck();
      await settle();
      expect(phaseOf(c), SessionPhase.updateRequired);

      // A cached app-config still says 0.0.0.
      bed.auth.minVersion = '0.0.0';
      await session.refreshAppConfig();
      expect(phaseOf(c), SessionPhase.updateRequired);

      bed.auth.heartbeatUpdate = false;
      await session.recheck();
      await settle();
      expect(phaseOf(c), SessionPhase.locked);
    });
  });

  test('a PIN try is counted even when saving it fails', () async {
    final store = _FlakyPinStore(bed.store);
    final c = bed.startUnrestored(store: store);
    await c.read(sessionProvider.notifier).restored;
    await settle();
    final session = c.read(sessionProvider.notifier);
    await session.login(sureshCode, sureshPassword);
    await session.setPin(goodPin);
    session.lock();
    store.failPinWrites = true;

    expect(await session.unlock(wrongPin), isFalse);
    expect(c.read(sessionProvider).pinAttemptsLeft, 4);
    expect(await session.unlock(goodPin), isTrue);
  });
}

/// The bed's store, whose PIN writes can fail.
final class _FlakyPinStore implements SessionStore {
  _FlakyPinStore(this._inner);

  final SessionStore _inner;
  bool failPinWrites = false;

  @override
  Future<void> writePin(PinRecord pin) async {
    if (failPinWrites) throw StateError('keystore busy');
    return _inner.writePin(pin);
  }

  @override
  Future<void> clear({bool wipeDeviceKey = false}) =>
      _inner.clear(wipeDeviceKey: wipeDeviceKey);
  @override
  Future<void> clearPin() => _inner.clearPin();
  @override
  Future<String> deviceKey() => _inner.deviceKey();
  @override
  Future<Language?> readLanguage() => _inner.readLanguage();
  @override
  Future<DateTime?> readLastOnlineAt() => _inner.readLastOnlineAt();
  @override
  Future<SessionMeta> readMeta() => _inner.readMeta();
  @override
  Future<PinRecord?> readPin() => _inner.readPin();
  @override
  Future<StoredSession?> readSession() => _inner.readSession();
  @override
  Future<void> resetDeviceKey() => _inner.resetDeviceKey();
  @override
  Future<void> writeLanguage(Language language) =>
      _inner.writeLanguage(language);
  @override
  Future<void> writeLastOnlineAt(DateTime at) => _inner.writeLastOnlineAt(at);
  @override
  Future<void> writeMeta(SessionMeta meta) => _inner.writeMeta(meta);
  @override
  Future<void> writeSession(StoredSession session) =>
      _inner.writeSession(session);
}
