import 'dart:convert';

import 'package:fa/src/data/session/pin_lock.dart';
import 'package:fa/src/data/session/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _hex(String hex) => [
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

/// The PIN verifier: PBKDF2, wrong-try counting and the weak-PIN rules.
void main() {
  final lock = PinLock(iterations: 100);

  group('verifier', () {
    test('the right PIN matches, a wrong one does not', () {
      final record = lock.create('2580');
      expect(lock.matches(record, '2580'), isTrue);
      expect(lock.matches(record, '2581'), isFalse);
      expect(lock.matches(record, ''), isFalse);
      expect(record.iterations, 100);
      expect(record.failedAttempts, 0);
    });

    test('the record holds no trace of the PIN; salts differ', () {
      final a = lock.create('2580');
      final b = lock.create('2580');
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      expect(base64Decode(a.salt), hasLength(16));
      expect(base64Decode(a.hash), hasLength(32));
      expect('${a.salt}${a.hash}', isNot(contains('2580')));
    });

    test('is PBKDF2-HMAC-SHA256 (RFC 7914 test vectors)', () {
      // P = "password", S = "salt", dkLen = 32.
      for (final (iterations, key) in [
        (1, '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b'),
        (2, 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43'),
        (
          4096,
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
        ),
      ]) {
        final record = PinRecord(
          salt: base64Encode(utf8.encode('salt')),
          hash: base64Encode(_hex(key)),
          iterations: iterations,
        );
        expect(lock.matches(record, 'password'), isTrue, reason: '$iterations');
        expect(lock.matches(record, 'passwore'), isFalse);
      }
    });

    test('a record keeps its own iteration count', () {
      final old = PinLock(iterations: 10).create('2580');
      expect(PinLock().matches(old, '2580'), isTrue);
      expect(PinLock().create('2580').iterations, pinIterations);
    });

    test('an unreadable record never matches', () {
      const broken = PinRecord(salt: '!!', hash: '??', iterations: 10);
      expect(lock.matches(broken, '2580'), isFalse);
      final zero = PinRecord(
        salt: lock.create('2580').salt,
        hash: lock.create('2580').hash,
        iterations: 0,
      );
      expect(lock.matches(zero, '2580'), isFalse);
    });
  });

  group('wrong tries', () {
    test('count down to the lock-out at 5', () {
      var record = lock.create('2580');
      for (var left = 4; left >= 1; left--) {
        final check = lock.check(record, '0000', maxAttempts: 5);
        expect(check.verdict, PinVerdict.wrong);
        expect(check.attemptsLeft, left);
        record = check.record;
      }
      final last = lock.check(record, '0000', maxAttempts: 5);
      expect(last.verdict, PinVerdict.lockedOut);
      expect(last.attemptsLeft, 0);
      expect(PinLock.isLockedOut(last.record, 5), isTrue);

      // Locked out: even the right PIN no longer opens.
      final after = lock.check(last.record, '2580', maxAttempts: 5);
      expect(after.verdict, PinVerdict.lockedOut);
      expect(after.record.failedAttempts, 5);
    });

    test('the right PIN resets the count', () {
      var record = lock.create('2580');
      record = lock.check(record, '1111', maxAttempts: 5).record;
      record = lock.check(record, '1112', maxAttempts: 5).record;
      expect(record.failedAttempts, 2);
      expect(PinLock.attemptsLeft(record, 5), 3);

      final ok = lock.check(record, '2580', maxAttempts: 5);
      expect(ok.verdict, PinVerdict.correct);
      expect(ok.record.failedAttempts, 0);
      expect(ok.attemptsLeft, 5);
    });
  });

  group('weak PINs', () {
    test('repeated, sequential and year-like PINs are refused', () {
      for (final (pin, problem) in [
        ('0000', PinProblem.repeated),
        ('1111', PinProblem.repeated),
        ('9999', PinProblem.repeated),
        ('1234', PinProblem.sequential),
        ('4321', PinProblem.sequential),
        ('0123', PinProblem.sequential),
        ('6789', PinProblem.sequential),
        ('9876', PinProblem.sequential),
        ('1987', PinProblem.year),
        ('2001', PinProblem.year),
      ]) {
        expect(PinLock.problem(pin), problem, reason: pin);
        expect(PinLock.isWeak(pin), isTrue, reason: pin);
      }
    });

    test('ordinary PINs pass', () {
      for (final pin in ['2580', '1357', '7392', '0852', '3141', '2468']) {
        expect(PinLock.problem(pin), isNull, reason: pin);
      }
    });

    test('the length and digits follow the policy', () {
      expect(PinLock.problem('258'), PinProblem.wrongShape);
      expect(PinLock.problem('25801'), PinProblem.wrongShape);
      expect(PinLock.problem('25a0'), PinProblem.wrongShape);
      expect(PinLock.problem('２５８０'), PinProblem.wrongShape);
      expect(PinLock.problem('258013', length: 6), isNull);
      expect(PinLock.problem('123456', length: 6), PinProblem.sequential);
      expect(PinLock.problem('199000', length: 6), isNull);
    });
  });
}
