import 'package:orbit_core/orbit_core.dart';
import 'package:test/test.dart';

void main() {
  group('ApiError', () {
    test('parses the error envelope, status and Retry-After', () {
      final e = ApiError.fromResponse(400, {
        'error': {
          'code': 'otp_invalid',
          'message': 'the code is wrong',
          'details': {'attempts_left': 3},
        },
      });
      expect(e.code, ApiErrorCode.otpInvalid);
      expect(e.status, 400);
      expect(e.message, 'the code is wrong');
      expect(e.attemptsLeft, 3);
      expect(e.isRetryable, isFalse);

      final limited = ApiError.fromResponse(429, {
        'error': {'code': 'rate_limited', 'message': 'slow down'},
      }, retryAfterHeader: '30');
      expect(limited.retryAfter, const Duration(seconds: 30));
      expect(limited.isRetryable, isTrue);
    });

    test('falls back to a code from the status for odd bodies', () {
      expect(ApiError.fromResponse(503, 'oops').code, ApiErrorCode.unavailable);
      expect(ApiError.fromResponse(404, null).code, ApiErrorCode.notFound);
      expect(ApiError.fromResponse(502, {}).isRetryable, isTrue);
    });

    test('helpers read details', () {
      const expired = ApiError(
        code: ApiErrorCode.unauthorized,
        message: 'expired',
        status: 401,
        details: {'reason': 'expired'},
      );
      expect(expired.isExpiredToken, isTrue);
      expect(expired.isUnauthorized, isTrue);

      const invalid = ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'bad',
        status: 400,
        details: {
          'fields': {'phone': 'invalid'},
        },
      );
      expect(invalid.fieldErrors, {'phone': 'invalid'});
      expect(invalid.attemptsLeft, isNull);
    });

    test('network variant', () {
      const offline = ApiError.network();
      expect(offline.code, ApiErrorCode.network);
      expect(offline.isNetwork, isTrue);
      expect(offline.isTimeout, isFalse);
      expect(offline.isRetryable, isTrue);
      expect(offline.status, isNull);

      // A timeout has its own code (its own text) but is still offline.
      const slow = ApiError.network(timeout: true);
      expect(slow.code, ApiErrorCode.timeout);
      expect(slow.isNetwork, isTrue);
      expect(slow.isTimeout, isTrue);
      expect(slow.isRetryable, isTrue);
      expect(slow.status, isNull);
      expect(slow, const ApiError.network(timeout: true));
      expect(slow, isNot(offline));
    });

    test('codes match the contract spelling', () {
      // contracts/build/mobile.yaml, backend apperr codes and sync
      // rejection reasons (CONVENTIONS section 6).
      expect(ApiErrorCode.conflict, 'conflict');
      expect(ApiErrorCode.phoneTaken, 'phone_taken');
      expect(ApiErrorCode.photoAlreadyUploaded, 'photo_already_uploaded');
      expect(ApiErrorCode.uploadMissing, 'upload_missing');
      expect(
        ApiErrorCode.registeredWithAnotherFa,
        'registered_with_another_fa',
      );
      expect(ApiErrorCode.notInYourArea, 'not_in_your_area');
      expect(ApiErrorCode.serverCouldNotApply, 'server_could_not_apply');
      expect(ApiErrorCode.totpEnrolmentRequired, 'totp_enrolment_required');
      expect(ApiErrorCode.totpAlreadyEnabled, 'totp_already_enabled');
      expect(
        ApiError.fromResponse(409, {
          'error': {'code': 'upload_missing', 'message': 'not in storage'},
        }).code,
        ApiErrorCode.uploadMissing,
      );
    });
  });

  group('OrbitEnv', () {
    test('defaults: dev uses mock, staging and prod use the API', () {
      final dev = OrbitEnv.parse(flavor: 'dev');
      expect(dev.dataSource, DataSource.mock);
      expect(dev.apiBaseUrl, 'http://10.0.2.2:8080');
      expect(OrbitEnv.parse().flavor, Flavor.dev);
      expect(OrbitEnv.parse(flavor: 'prod').dataSource, DataSource.api);
      expect(
        OrbitEnv.parse(flavor: 'staging', dataSource: '').dataSource,
        DataSource.api,
      );
    });

    test('staging and prod refuse mock data', () {
      expect(
        () => OrbitEnv.parse(flavor: 'prod', dataSource: 'mock'),
        throwsStateError,
      );
      expect(
        () => OrbitEnv.parse(flavor: 'staging', dataSource: 'mock'),
        throwsStateError,
      );
    });

    test('dev can use the API and override the base URL', () {
      final env = OrbitEnv.parse(
        flavor: 'dev',
        dataSource: 'api',
        apiBaseUrl: 'http://localhost:8080/',
      );
      expect(env.dataSource, DataSource.api);
      expect(env.apiBaseUrl, 'http://localhost:8080');
    });

    test('rejects unknown values', () {
      expect(() => OrbitEnv.parse(flavor: 'qa'), throwsFormatException);
      expect(() => OrbitEnv.parse(dataSource: 'fake'), throwsFormatException);
      expect(
        () => OrbitEnv.parse(apiBaseUrl: 'not a url'),
        throwsFormatException,
      );
    });
  });

  group('money', () {
    test('Indian grouping from paise', () {
      expect(formatInr(10000000), '₹1,00,000');
      expect(formatInr(360000), '₹3,600');
      expect(formatInr(45000), '₹450');
      expect(formatInr(360050), '₹3,600.50');
      expect(formatInr(0), '₹0');
      expect(formatInr(5), '₹0.05');
      expect(formatInr(45000, alwaysShowPaise: true), '₹450.00');
      expect(formatInr(-18000), '-₹180');
      expect(formatInr(123456789012), '₹1,23,45,67,890.12');
      expect(groupIndian(1234567), '12,34,567');
      expect(groupIndian(999), '999');
    });
  });

  group('LocalDate', () {
    test('parses strictly and prints the wire format', () {
      final d = LocalDate.parse('2026-10-29');
      expect(d.toIso(), '2026-10-29');
      expect(d.weekday, DateTime.thursday);
      expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
      expect(() => LocalDate.parse('2026-1-5'), throwsFormatException);
      expect(LocalDate.tryParse('nope'), isNull);
    });

    test('arithmetic and ordering', () {
      final d = LocalDate(2026, 12, 31);
      expect(d.addDays(1), LocalDate(2027, 1, 1));
      expect(LocalDate(2026, 7, 1).daysUntil(LocalDate(2026, 11, 1)), 123);
      expect(d.isAfter(LocalDate(2026, 1, 1)), isTrue);
      expect(LocalDate(2026, 1, 1).compareTo(d), lessThan(0));
    });

    test('IST calendar day of a UTC instant', () {
      // 18:45 UTC is 00:15 IST the next day.
      final clock = FixedClock(DateTime.utc(2026, 10, 31, 18, 45));
      expect(LocalDate.todayIst(clock), LocalDate(2026, 11, 1));
      expect(toIstWallClock(clock.now()).hour, 0);
      clock.advance(const Duration(hours: 1));
      expect(clock.now(), DateTime.utc(2026, 10, 31, 19, 45));
    });
  });

  group('phone', () {
    test('normalises common Indian formats like the server', () {
      for (final input in [
        '98480 12345',
        '098480-12345',
        '+91 98480 12345',
        '919848012345',
        '0091 9848012345',
        '(98480) 12345',
      ]) {
        expect(normalizeIndianMobile(input), '+919848012345', reason: input);
      }
      for (final input in [
        '',
        '12345',
        '5848012345',
        '98480+12345',
        '9848o12345',
      ]) {
        expect(normalizeIndianMobile(input), isNull, reason: input);
      }
      expect(isValidIndianMobile('9000000101'), isTrue);
    });

    test('masks and formats', () {
      expect(maskPhone('+919848012345'), '+91******2345');
      expect(maskPhone('garbage'), '****');
      expect(formatIndianMobile('+919876543210'), '98765 43210');
    });
  });

  group('season codes', () {
    test('validates the API pattern', () {
      expect(SeasonCode.isValid('kharif-2026'), isTrue);
      expect(SeasonCode.isValid('rabi-2026-27'), isTrue);
      expect(SeasonCode.isValid('Rabi-2026'), isFalse);
      expect(SeasonCode.isValid('rabi-26'), isFalse);
    });

    test('matches the backend calendar', () {
      final nov = seasonCodesOn(LocalDate(2026, 11, 1));
      expect(nov.current, 'rabi-2026-27');
      expect(nov.allOpen, ['kharif-2026', 'rabi-2026-27', 'summer-2027']);
      expect(nov.validUntil, LocalDate(2027, 3, 31));

      final jan = seasonCodesOn(LocalDate(2027, 1, 15));
      expect(jan.current, 'rabi-2026-27');

      final may = seasonCodesOn(LocalDate(2027, 5, 31));
      expect(may.allOpen, ['rabi-2026-27', 'summer-2027', 'kharif-2027']);

      final jul = seasonCodesOn(LocalDate(2026, 7, 1));
      expect(jul.current, 'kharif-2026');
      expect(jul.validUntil, LocalDate(2026, 10, 31));
      expect(seasonCodesOn(LocalDate(2099, 12, 1)).current, 'rabi-2099-00');
    });
  });

  group('area', () {
    test('acres and guntas', () {
      expect(guntasToAcres(4), 0.1);
      expect(acresToGuntas(2.5), 100);
      expect(AcresGuntas.fromAcres(2.1), const AcresGuntas(2, 4));
      expect(AcresGuntas.fromAcres(0.99), const AcresGuntas(1, 0));
      expect(const AcresGuntas(2, 4).totalAcres, closeTo(2.1, 1e-9));
    });

    test('any positive area is at least 1 gunta', () {
      expect(AcresGuntas.fromAcres(0), const AcresGuntas(0, 0));
      // 0.4 gunta would round to nothing; the API only has areas above 0.
      expect(AcresGuntas.fromAcres(0.01), const AcresGuntas(0, 1));
      expect(AcresGuntas.fromAcres(0.0001), const AcresGuntas(0, 1));
      // From half a gunta up, ordinary rounding.
      expect(AcresGuntas.fromAcres(0.0125), const AcresGuntas(0, 1));
      expect(AcresGuntas.fromAcres(0.04), const AcresGuntas(0, 2));
      expect(AcresGuntas.fromAcres(39.99), const AcresGuntas(40, 0));
    });

    test('rejects impossible values', () {
      expect(() => AcresGuntas.fromAcres(-0.5), throwsArgumentError);
      expect(() => AcresGuntas.fromAcres(double.nan), throwsArgumentError);
      expect(() => AcresGuntas.fromAcres(double.infinity), throwsArgumentError);
      // Built at run time, so the asserts run (tests run with asserts on).
      AcresGuntas area(int acres, int guntas) => AcresGuntas(acres, guntas);
      expect(() => area(1, 40), throwsA(isA<AssertionError>()));
      expect(() => area(1, -1), throwsA(isA<AssertionError>()));
      expect(() => area(-1, 0), throwsA(isA<AssertionError>()));
      expect(area(1, 39).totalAcres, closeTo(1.975, 1e-9));
    });
  });

  group('CursorPage', () {
    test('maps items and keeps the cursor', () {
      const page = CursorPage(items: [1, 2], nextCursor: 'c1');
      expect(page.hasMore, isTrue);
      expect(
        page.map((i) => '$i'),
        const CursorPage(items: ['1', '2'], nextCursor: 'c1'),
      );
      expect(const CursorPage<int>.empty().hasMore, isFalse);
    });
  });
}
