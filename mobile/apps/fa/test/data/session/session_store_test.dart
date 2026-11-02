import 'dart:convert';
import 'dart:math' as math;

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/data/session/session_phase.dart';
import 'package:fa/src/data/session/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_fakes.dart';

const _owner = PhoneOwner(
  faId: 'fa-1',
  code: 'FA-KDP-014',
  name: 'Suresh Kumar',
);

const _meta = SessionMeta(
  phase: SessionPhase.passwordNeeded,
  passwordNeededReason: 'sessionEnded',
  updateMinVersion: '1.2.0',
  sessionEnded: true,
  cleanTokenPending: true,
  lastOwner: _owner,
);

/// The in-memory session store: meta fields, what `clear` keeps, the
/// install ID.
/// Through a JSON string and back, as the secure-storage store keeps it.
Map<String, Object?> _roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  group('JSON for the secure-storage store', () {
    final tokens = TokenPair(
      accessToken: 'access-1',
      accessExpiresAt: DateTime.utc(2026, 11, 2, 4, 45),
      refreshToken: 'refresh-1',
      refreshExpiresAt: DateTime.utc(2026, 12, 2, 4, 30),
    );

    test('StoredSession round-trips, the sign-in key included', () {
      final login = FaSession(
        tokens: tokens,
        deviceId: 'device-1',
        fieldAssistant: faFor(sureshCode),
        mustChangePassword: false,
        offlinePolicy: OfflinePolicy.standard,
      );
      final session = StoredSession.fromLogin(login);
      expect(session.signInKey, isNotNull);
      final back = StoredSession.fromJson(_roundTrip(session.toJson()));
      expect(back, session);
      // A refresh keeps the key through the JSON too.
      final refreshed = back.withTokens(tokens, mustChangePassword: true);
      expect(StoredSession.fromJson(_roundTrip(refreshed.toJson())), refreshed);
    });

    test('a session saved without a key reads back without one', () {
      final session = StoredSession(
        tokens: tokens,
        faId: 'fa-1',
        deviceId: 'device-1',
        fieldAssistant: faFor(tempCode),
        offlinePolicy: OfflinePolicy.standard,
        mustChangePassword: true,
      );
      final json = _roundTrip(session.toJson());
      expect(json.containsKey('sign_in_key'), isFalse);
      expect(StoredSession.fromJson(json), session);
    });

    test('PinRecord round-trips; a missing count is 0', () {
      const pin = PinRecord(
        salt: 'c2FsdA==',
        hash: 'aGFzaA==',
        iterations: 20000,
        failedAttempts: 3,
      );
      expect(PinRecord.fromJson(_roundTrip(pin.toJson())), pin);
      expect(
        PinRecord.fromJson({
          'salt': 'c2FsdA==',
          'hash': 'aGFzaA==',
          'iterations': 20000,
        }).failedAttempts,
        0,
      );
    });

    test('SessionMeta round-trips every field', () {
      final full = _meta.copyWith(
        updateFromHeartbeat: true,
        passwordChangeSent: true,
        wipePending: true,
        lastSeenAt: DateTime.utc(2026, 11, 2, 10, 15),
      );
      expect(SessionMeta.fromJson(_roundTrip(full.toJson())), full);
      expect(
        SessionMeta.fromJson(_roundTrip(SessionMeta.empty.toJson())),
        SessionMeta.empty,
      );
      expect(SessionMeta.empty.toJson(), isEmpty);
      // An owner without a name.
      const noName = SessionMeta(
        lastOwner: PhoneOwner(faId: 'fa-2', code: 'FA-CVL-002'),
      );
      expect(SessionMeta.fromJson(_roundTrip(noName.toJson())), noName);
    });

    test('an unknown phase reads as null; a wrong type throws', () {
      expect(SessionMeta.fromJson({'phase': 'hibernating'}).phase, isNull);
      expect(
        () => SessionMeta.fromJson({'wipe_pending': 'yes'}),
        throwsFormatException,
      );
      expect(
        () => PinRecord.fromJson({'salt': 's', 'hash': 'h'}),
        throwsFormatException,
      );
    });
  });

  group('SessionMeta', () {
    test('defaults are nothing saved', () {
      const m = SessionMeta();
      expect(m, SessionMeta.empty);
      expect(m.phase, isNull);
      expect(m.passwordNeededReason, isNull);
      expect(m.updateMinVersion, isNull);
      expect(m.sessionEnded, isFalse);
      expect(m.cleanTokenPending, isFalse);
      expect(m.lastOwner, isNull);
    });

    test('copyWith keeps what is not given and clears what is null', () {
      expect(_meta.copyWith(), _meta);
      final m = _meta.copyWith(
        phase: SessionPhase.active,
        passwordNeededReason: null,
        updateMinVersion: null,
        sessionEnded: false,
      );
      expect(m.phase, SessionPhase.active);
      expect(m.passwordNeededReason, isNull);
      expect(m.updateMinVersion, isNull);
      expect(m.sessionEnded, isFalse);
      expect(m.cleanTokenPending, isTrue);
      expect(m.lastOwner, _owner);
      expect(_meta.copyWith(lastOwner: null).lastOwner, isNull);
    });

    test('equality covers every field', () {
      expect(_meta, _meta.copyWith());
      expect(_meta.hashCode, _meta.copyWith().hashCode);
      for (final other in [
        _meta.copyWith(phase: SessionPhase.locked),
        _meta.copyWith(passwordNeededReason: 'expired'),
        _meta.copyWith(updateMinVersion: '1.3.0'),
        _meta.copyWith(sessionEnded: false),
        _meta.copyWith(cleanTokenPending: false),
        _meta.copyWith(
          lastOwner: const PhoneOwner(faId: 'fa-1', code: 'FA-KDP-014'),
        ),
      ]) {
        expect(other, isNot(_meta));
      }
    });
  });

  group('InMemorySessionStore', () {
    late InMemorySessionStore store;

    setUp(() => store = InMemorySessionStore(random: math.Random(1)));

    test('reads empty meta first, then what was written', () async {
      expect(await store.readMeta(), SessionMeta.empty);
      await store.writeMeta(_meta);
      expect(await store.readMeta(), _meta);
      await store.writeMeta(const SessionMeta(phase: SessionPhase.locked));
      expect(
        await store.readMeta(),
        const SessionMeta(phase: SessionPhase.locked),
        reason: 'a write replaces every field',
      );
    });

    test('clear forgets the meta but keeps the owner and language', () async {
      await store.writeMeta(_meta);
      await store.writeLanguage(Language.en);
      await store.writePin(
        const PinRecord(salt: 's', hash: 'h', iterations: 1),
      );
      await store.writeLastOnlineAt(DateTime.utc(2026, 11, 2));
      final key = await store.deviceKey();

      await store.clear();

      expect(await store.readMeta(), const SessionMeta(lastOwner: _owner));
      expect(await store.readPin(), isNull);
      expect(await store.readLastOnlineAt(), isNull);
      expect(await store.readSession(), isNull);
      expect(await store.readLanguage(), Language.en);
      expect(await store.deviceKey(), key);
    });

    test('a wiping clear forgets the owner and the install ID too', () async {
      await store.writeMeta(_meta);
      final key = await store.deviceKey();

      await store.clear(wipeDeviceKey: true);

      expect(await store.readMeta(), SessionMeta.empty);
      expect(await store.deviceKey(), isNot(key));
    });

    test('install IDs match the contract pattern', () async {
      final key = await store.deviceKey();
      expect(key, matches(RegExp(r'^fa-[0-9a-f]{32}$')));
      expect(await store.deviceKey(), key, reason: 'kept');
      await store.resetDeviceKey();
      expect(await store.deviceKey(), isNot(key));
    });
  });
}
