import 'package:fa/src/data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import 'session_fakes.dart'
    show
        FakeGuard,
        goodPin,
        otherCode,
        phaseOf,
        settle,
        sureshCode,
        sureshPassword,
        tempCode,
        tempPassword,
        testStart;

/// The session over the real mock backend and its scenarios, as the app
/// runs in mock mode.
void main() {
  late FixedClock clock;
  late MockBackend backend;
  late InMemorySessionStore store;
  late FakeGuard guard;

  setUp(() {
    clock = FixedClock(testStart);
    backend = MockBackend(clock: clock, latency: Duration.zero);
    store = InMemorySessionStore();
    guard = FakeGuard();
  });

  Future<ProviderContainer> start() async {
    final c = ProviderContainer.test(
      overrides: [
        ...faDataOverrides(
          env: OrbitEnv.devMock,
          store: store,
          mockBackend: backend,
        ),
        clockProvider.overrideWithValue(clock),
        localDataGuardProvider.overrideWithValue(guard),
        pinLockProvider.overrideWithValue(PinLock(iterations: 50)),
        appVersionProvider.overrideWithValue('1.0.3'),
      ],
      retry: (_, _) => null,
    );
    await c.read(sessionProvider.notifier).restored;
    await settle();
    return c;
  }

  Future<ProviderContainer> active() async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.login(sureshCode, sureshPassword);
    await session.setPin(goodPin);
    await settle();
    return c;
  }

  test('Suresh: login, setup, lock, unlock', () async {
    final c = await active();
    final s = c.read(sessionProvider);
    expect(s.phase, SessionPhase.active);
    expect(s.fa?.name, 'Suresh Kumar');
    expect(s.policy, OfflinePolicy.standard);

    final session = c.read(sessionProvider.notifier);
    session.lock();
    expect(await session.unlock(goodPin), isTrue);
  });

  test('a temporary password: change, clean token, setup', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await session.login(tempCode, tempPassword);
    expect(phaseOf(c), SessionPhase.mustChangePassword);
    await session.changePassword(tempPassword, 'paddy2026');
    expect(phaseOf(c), SessionPhase.setup);
    expect((await store.readSession())!.mustChangePassword, isFalse);
    // A heartbeat works with the clean token.
    await session.recheck();
  });

  test('a wrong password and an expired temporary one', () async {
    final c = await start();
    final session = c.read(sessionProvider.notifier);
    await expectLater(
      session.login(sureshCode, 'wrong'),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.unauthorized,
        ),
      ),
    );
    await expectLater(
      session.login('FA-KDP-077', 'temp5678'),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.tempPasswordExpired,
        ),
      ),
    );
    expect(phaseOf(c), SessionPhase.signedOut);
  });

  test('phone removed: the heartbeat wipes it', () async {
    final c = await active();
    c.read(mockScenarioProvider.notifier).select(MockScenario.deviceRemoved);
    await c.read(sessionProvider.notifier).recheck();
    await settle();
    expect(phaseOf(c), SessionPhase.removed);
    expect(guard.wipes, 1);

    // A new install ID signs in normally.
    c.read(sessionProvider.notifier).startOver();
    await c.read(sessionProvider.notifier).login(sureshCode, sureshPassword);
    expect(phaseOf(c), SessionPhase.setup);
  });

  test('update required: pushed first, then blocked', () async {
    final c = await active();
    guard.pending = 2;
    c.read(mockScenarioProvider.notifier).select(MockScenario.updateRequired);
    await c.read(sessionProvider.notifier).recheck();
    expect(guard.log, containsAllInOrder(['push']));
    expect(phaseOf(c), SessionPhase.updateRequired);
    expect(guard.pending, 0);
  });

  test('update required at start (app config)', () async {
    backend.scenario = MockScenario.updateRequired;
    final c = await start();
    final s = c.read(sessionProvider);
    expect(s.phase, SessionPhase.updateRequired);
    expect(s.appConfig?.minVersion, '1.0.5');
  });

  test('session expired: work goes on, sync needs the password', () async {
    final c = await active();
    c.read(mockScenarioProvider.notifier).select(MockScenario.sessionExpired);
    await expectLater(
      c.read(sessionProvider.notifier).recheck(),
      throwsA(isA<ApiError>()),
    );
    await settle();
    var s = c.read(sessionProvider);
    expect(s.phase, SessionPhase.active);
    expect(s.syncNeedsPassword, isTrue);

    c.read(sessionProvider.notifier).lock();
    s = c.read(sessionProvider);
    expect(s.passwordNeededReason, PasswordNeededReason.sessionEnded);
    expect(s.canUsePin, isTrue);

    // A new login works and clears it.
    await c.read(sessionProvider.notifier).login(sureshCode, sureshPassword);
    s = c.read(sessionProvider);
    expect(s.phase, SessionPhase.active);
    expect(s.syncNeedsPassword, isFalse);
  });

  test('another FA on the phone after a logout', () async {
    final c = await active();
    guard.pending = 1;
    final session = c.read(sessionProvider.notifier);
    await session.logout();
    await expectLater(
      session.login(otherCode, 'orbit2026'),
      throwsA(isA<OtherFaOnPhone>()),
    );
  });
}
