import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_store.dart';

/// PBKDF2 iterations for new PINs.
///
/// A 4-digit PIN has only 10,000 values, so no iteration count stops a
/// thief who has the verifier; the real protection is that the verifier sits
/// in Keystore-backed secure storage and that 5 wrong tries lock the PIN.
/// The count only makes a copied verifier slower to try, and must stay cheap
/// on a ₹7,000 phone (≈0.1 s here on a laptop, well under a second on a
/// low-end phone, run on the UI isolate). Old records keep the count they
/// were made with ([PinRecord.iterations]), so this can be raised later.
const pinIterations = 20000;

/// Why a PIN is refused when it is set (A1d: "Avoid 1234, 0000 or your birth
/// year").
enum PinProblem {
  /// Not exactly the policy's length, or not all digits.
  wrongShape,

  /// One digit repeated (`0000`, `7777`).
  repeated,

  /// Digits counting up or down (`1234`, `4321`, `6789`, `9876`).
  sequential,

  /// Looks like a birth year (1940 to 2015).
  year,
}

/// What a PIN check found.
enum PinVerdict {
  /// Right PIN: unlocked, the wrong-try count is back to 0.
  correct,

  /// Wrong PIN, tries are left.
  wrong,

  /// Wrong PIN and no tries left (or already locked out): the PIN is
  /// disabled and the password is needed. Unsynced records are kept.
  lockedOut,
}

/// The result of [PinLock.check]: the [verdict], the record to save (its
/// wrong-try count updated), and the tries left after this one.
typedef PinCheck = ({PinVerdict verdict, PinRecord record, int attemptsLeft});

/// Makes and checks the PIN verifier (PBKDF2-HMAC-SHA256, random 16-byte
/// salt, constant-time compare). The PIN itself never leaves this class:
/// only the [PinRecord] (salt and derived key, base64) is stored, and
/// nothing about the PIN is sent to the server.
final class PinLock {
  /// Creates the lock. [iterations] applies to new records only (tests pass
  /// a small number); [random] defaults to `Random.secure()`.
  PinLock({this.iterations = pinIterations, math.Random? random})
    : _random = random ?? math.Random.secure();

  /// PBKDF2 iterations for records made by [create].
  final int iterations;

  final math.Random _random;

  static const _saltBytes = 16;
  static const _keyBytes = 32;

  /// Why [pin] may not be set as a [length]-digit PIN, or null when it is
  /// fine. Screens call this before asking for the PIN a second time.
  static PinProblem? problem(String pin, {int length = 4}) {
    if (pin.length != length || !RegExp(r'^\d+$').hasMatch(pin)) {
      return PinProblem.wrongShape;
    }
    final digits = pin.codeUnits.map((c) => c - 0x30).toList();
    if (digits.every((d) => d == digits.first)) return PinProblem.repeated;
    bool steps(int by) {
      for (var i = 1; i < digits.length; i++) {
        if (digits[i] - digits[i - 1] != by) return false;
      }
      return true;
    }

    if (steps(1) || steps(-1)) return PinProblem.sequential;
    if (length == 4) {
      final year = int.parse(pin);
      if (year >= 1940 && year <= 2015) return PinProblem.year;
    }
    return null;
  }

  /// True when [pin] is too easy to guess (see [problem]).
  static bool isWeak(String pin, {int length = 4}) =>
      problem(pin, length: length) != null;

  /// A new verifier for [pin] with a fresh salt and no wrong tries. Does not
  /// check [problem]; the caller does.
  PinRecord create(String pin) {
    final salt = Uint8List(_saltBytes);
    for (var i = 0; i < salt.length; i++) {
      salt[i] = _random.nextInt(256);
    }
    return PinRecord(
      salt: base64Encode(salt),
      hash: base64Encode(_derive(pin, salt, iterations)),
      iterations: iterations,
    );
  }

  /// True when [pin] matches [record] (ignores the wrong-try count).
  bool matches(PinRecord record, String pin) {
    final Uint8List salt, expected;
    try {
      salt = base64Decode(record.salt);
      expected = base64Decode(record.hash);
    } on FormatException {
      return false;
    }
    if (record.iterations < 1) return false;
    return _equal(_derive(pin, salt, record.iterations), expected);
  }

  /// True when [record] has used up [maxAttempts] wrong tries.
  static bool isLockedOut(PinRecord record, int maxAttempts) =>
      record.failedAttempts >= maxAttempts;

  /// Tries left on [record] before the lock-out (never below 0).
  static int attemptsLeft(PinRecord record, int maxAttempts) =>
      math.max(0, maxAttempts - record.failedAttempts);

  /// Checks [pin] against [record] and counts the try. A record already
  /// locked out stays locked out without checking (so the count of a stolen
  /// phone's tries cannot be reset by a right guess).
  PinCheck check(PinRecord record, String pin, {required int maxAttempts}) {
    if (isLockedOut(record, maxAttempts)) {
      return (verdict: PinVerdict.lockedOut, record: record, attemptsLeft: 0);
    }
    if (matches(record, pin)) {
      final reset = record.failedAttempts == 0
          ? record
          : record.withFailedAttempts(0);
      return (
        verdict: PinVerdict.correct,
        record: reset,
        attemptsLeft: maxAttempts,
      );
    }
    final counted = record.withFailedAttempts(record.failedAttempts + 1);
    final left = attemptsLeft(counted, maxAttempts);
    return (
      verdict: left == 0 ? PinVerdict.lockedOut : PinVerdict.wrong,
      record: counted,
      attemptsLeft: left,
    );
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018) for one 32-byte block.
  static Uint8List _derive(String pin, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < _keyBytes; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  /// Compares without stopping at the first difference.
  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// The [PinLock] the session uses (tests override it with fewer iterations).
final pinLockProvider = Provider<PinLock>((ref) => PinLock());
