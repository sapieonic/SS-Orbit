import 'package:fa/src/data/session/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_fakes.dart';

/// How the session reacts to failures the data layer reports through the
/// auth-failure hook (the plan's error table), and to late reports from a
/// session that is gone.
void main() {
  late SessionBed bed;

  setUp(() => bed = SessionBed());

  String? faIdOf(ProviderContainer c) => c.read(sessionProvider).fa?.id;

  group('device_revoked', () {
    test('wipes and removes, once for many reports', () async {
      final c = await bed.active();
      bed.guard.pending = 4;
      final phases = <SessionPhase>[];
      c.listen(
        sessionProvider.select((s) => s.phase),
        (_, next) => phases.add(next),
      );
      for (var i = 0; i < 3; i++) {
        bed.hook.report(deviceRevoked, faId: faIdOf(c));
      }
      await settle();

      // The splash while the data goes, then removed; one wipe.
      expect(phases, [SessionPhase.restoring, SessionPhase.removed]);
      expect(bed.guard.wipes, 1);
      expect(bed.guard.pending, 0);
      expect(await bed.store.readSession(), isNull);
    });

    test('also while locked, and from a sync call', () async {
      final c = await bed.active();
      c.read(sessionProvider.notifier).lock();
      bed.auth.failNext('heartbeat', deviceRevoked);
      await expectLater(c.read(sessionProvider.notifier).recheck(), completes);
      await settle();
      expect(phaseOf(c), SessionPhase.removed);
      expect(bed.guard.wipes, 1);
    });
  });

  group('session ended (401 after a failed refresh)', () {
    test(
      'while working: keeps working offline, sync needs the password',
      () async {
        final c = await bed.active();
        bed.hook.report(sessionEnded, faId: faIdOf(c));
        await settle();

        var s = c.read(sessionProvider);
        expect(s.phase, SessionPhase.active, reason: 'no form is lost');
        expect(s.syncNeedsPassword, isTrue);
        expect(bed.auth.count('heartbeat'), 1, reason: 'only the one at login');

        // The next lock shows "Session ended" with Enter PIN.
        final session = c.read(sessionProvider.notifier);
        session.lock();
        s = c.read(sessionProvider);
        expect(s.phase, SessionPhase.passwordNeeded);
        expect(s.passwordNeededReason, PasswordNeededReason.sessionEnded);
        expect(s.canUsePin, isTrue);

        session.usePin();
        expect(await session.unlock(goodPin), isTrue);
        expect(c.read(sessionProvider).syncNeedsPassword, isTrue);

        // Further 401s change nothing.
        bed.hook.report(sessionEnded, faId: faIdOf(c));
        await settle();
        expect(phaseOf(c), SessionPhase.active);

        // A restart keeps it; the password login clears it.
        c.dispose();
        final c2 = await bed.start();
        s = c2.read(sessionProvider);
        expect(s.passwordNeededReason, PasswordNeededReason.sessionEnded);
        await c2
            .read(sessionProvider.notifier)
            .login(sureshCode, sureshPassword);
        s = c2.read(sessionProvider);
        expect(s.phase, SessionPhase.active);
        expect(s.syncNeedsPassword, isFalse);
        expect(bed.guard.wipes, 0);
      },
    );

    test('while locked: password needed, the PIN still opens', () async {
      final c = await bed.active();
      c.read(sessionProvider.notifier).lock();
      bed.hook.report(refreshReused, faId: faIdOf(c));
      await settle();

      final s = c.read(sessionProvider);
      expect(s.phase, SessionPhase.passwordNeeded);
      expect(s.passwordNeededReason, PasswordNeededReason.sessionEnded);
      expect(s.canUsePin, isTrue);
    });

    test('after the grace the PIN no longer opens', () async {
      final c = await bed.active();
      c.read(sessionProvider.notifier).lock();
      bed.clock.advance(const Duration(days: 8));
      bed.hook.report(sessionEnded, faId: faIdOf(c));
      await settle();
      expect(c.read(sessionProvider).canUsePin, isFalse);
      expect(() => c.read(sessionProvider.notifier).usePin(), throwsStateError);
    });

    test('a 401 on the login screen is the screen\'s', () async {
      final c = await bed.active();
      c.read(sessionProvider.notifier).lock();
      c.read(sessionProvider.notifier).usePassword();
      bed.hook.report(sessionEnded, faId: faIdOf(c));
      await settle();
      final s = c.read(sessionProvider);
      expect(s.passwordNeededReason, isNull);
      expect(s.syncNeedsPassword, isFalse);
    });
  });

  test('403 password_change_required goes back to the change', () async {
    final c = await bed.active();
    bed.hook.report(passwordChangeRequired, faId: faIdOf(c));
    await settle();
    expect(phaseOf(c), SessionPhase.mustChangePassword);
  });

  test('temp_password_expired asks for a new password from HO', () async {
    final c = await bed.start();
    await c.read(sessionProvider.notifier).login(tempCode, tempPassword);
    bed.hook.report(tempPasswordExpired, faId: faIdOf(c));
    await settle();
    final s = c.read(sessionProvider);
    expect(s.phase, SessionPhase.passwordNeeded);
    expect(s.passwordNeededReason, PasswordNeededReason.tempPasswordExpired);
  });

  test('a late failure of the previous FA leaves the new one', () async {
    final c = await bed.active();
    final suresh = faIdOf(c);
    final session = c.read(sessionProvider.notifier);
    await session.logout();
    await session.login(otherCode, 'chevella1');
    await session.setPin(goodPin);

    bed.hook
      ..report(sessionEnded, faId: suresh)
      ..report(deviceRevoked, faId: suresh);
    await settle();

    final s = c.read(sessionProvider);
    expect(s.phase, SessionPhase.active);
    expect(s.syncNeedsPassword, isFalse);
    expect(bed.guard.wipes, 1, reason: 'only the switch of FA');
  });

  test('signed out: failures other than a revoke change nothing', () async {
    final c = await bed.start();
    bed.hook
      ..report(sessionEnded)
      ..report(passwordChangeRequired);
    await settle();
    expect(phaseOf(c), SessionPhase.signedOut);
  });
}
