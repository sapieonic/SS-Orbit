import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import 'all_messages.g.dart';

/// Pumps a MaterialApp the way the apps set it up and returns its context.
Future<BuildContext> pumpApp(WidgetTester tester, Locale locale) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: OrbitLocalizations.localizationsDelegates,
      supportedLocales: OrbitLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

final _telugu = RegExp('[ఀ-౿]');

void main() {
  test('supported locales are Telugu first, then English', () {
    expect(OrbitLocalizations.supportedLocales, const [
      Locale('te'),
      Locale('en'),
    ]);
  });

  test('the generated message list covers every ARB key', () {
    final arb = jsonDecode(
      File('lib/l10n/app_te.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    final keys = [
      for (final e in arb.entries)
        if (e.key.startsWith('@') && !e.key.startsWith('@@'))
          (e.value! as Map<String, Object?>)['x-key']! as String,
    ];
    expect(allMessages.keys.toSet(), keys.toSet());
  });

  for (final locale in OrbitLocalizations.supportedLocales) {
    testWidgets('every key resolves in ${locale.languageCode}', (tester) async {
      final context = await pumpApp(tester, locale);
      final l10n = context.l10n;
      expect(l10n.localeName, locale.languageCode);
      for (final MapEntry(key: key, value: render) in allMessages.entries) {
        final text = render(l10n);
        expect(text.trim(), isNotEmpty, reason: key);
        expect(text, isNot(contains('{')), reason: '$key: $text');
      }
    });
  }

  testWidgets('Telugu is the default and differs from English', (tester) async {
    final te = (await pumpApp(tester, const Locale('te'))).l10n;
    expect(te.farmerLoginSendOtp, 'OTP పంపండి');
    expect(te.farmerNavHome, 'హోమ్');
    final en = (await pumpApp(tester, const Locale('en'))).l10n;
    expect(en.farmerLoginSendOtp, 'Send OTP');
    // An unsupported device locale falls back to the first one, Telugu.
    final fallback = (await pumpApp(tester, const Locale('hi'))).l10n;
    expect(fallback.localeName, 'te');
  });

  testWidgets('Material and Cupertino strings are Telugu for te', (
    tester,
  ) async {
    final context = await pumpApp(tester, const Locale('te'));
    final material = MaterialLocalizations.of(context);
    final cupertino = CupertinoLocalizations.of(context);
    expect(material.okButtonLabel, matches(_telugu));
    expect(material.cancelButtonLabel, matches(_telugu));
    expect(cupertino.todayLabel, matches(_telugu));
  });

  group('placeholders and plurals', () {
    testWidgets('Telugu', (tester) async {
      final l = (await pumpApp(tester, const Locale('te'))).l10n;
      expect(l.farmerHomeGreeting(name: 'రవి'), 'నమస్కారం, రవి');
      expect(l.farmerHomeArea(acres: 2, guntas: 4), '2 ఎకరాలు 4 గుంటలు');
      expect(l.farmerHomeArea(acres: 2, guntas: 0), '2 ఎకరాలు');
      expect(l.farmerHomeArea(acres: 1, guntas: 1), '1 ఎకరం 1 గుంట');
      expect(l.farmerHomeArea(acres: 0, guntas: 20), '20 గుంటలు');
      expect(l.commonStepOf(step: 1, total: 3), '1/3');
      expect(l.farmerFasCount(count: 0), 'ఇక్కడ ఇంకా FA లు లేరు');
      expect(l.farmerFasCount(count: 1), '1 FA');
      expect(l.farmerFasCount(count: 4), '4 FA లు');
      expect(
        l.farmerCalendarDayOf(day: 137, total: 170),
        '137వ రోజు (మొత్తం సుమారు 170 రోజులు)',
      );
      final date = l.commonDateWeekday(date: DateTime(2026, 10, 29));
      expect(date, contains('29'));
      expect(date, matches(_telugu));
    });

    testWidgets('English', (tester) async {
      final l = (await pumpApp(tester, const Locale('en'))).l10n;
      expect(l.farmerHomeGreeting(name: 'Ravi'), 'Hello, Ravi');
      expect(l.farmerHomeArea(acres: 2, guntas: 0), '2 acres');
      expect(l.farmerHomeArea(acres: 1, guntas: 20), '1 acre 20 guntas');
      expect(l.farmerFasCount(count: 0), 'No FAs here yet');
      expect(l.farmerFasCount(count: 1), '1 FA');
      expect(l.farmerFasCount(count: 4), '4 FAs');
      expect(l.commonHoursAgo(count: 1), '1 h ago');
      expect(
        l.farmerCalendarDayOf(day: 137, total: 170),
        'Day 137 of about 170',
      );
      expect(l.farmerLoginResendIn(time: '0:24'), 'Resend OTP in 0:24');
      expect(l.commonDateWeekday(date: DateTime(2026, 10, 29)), 'Thu, Oct 29');
      // CLDR puts a narrow no-break space before AM.
      expect(
        l.commonSavedAt(time: DateTime(2026, 10, 29, 7)),
        matches(r'^Saved at 7:00\sAM$'),
      );
    });
  });

  group('describeError', () {
    late OrbitLocalizations en;
    late OrbitLocalizations te;

    setUpAll(() async {
      en = await OrbitLocalizations.delegate.load(const Locale('en'));
      te = await OrbitLocalizations.delegate.load(const Locale('te'));
    });

    test('maps known codes', () {
      expect(en.describeError('otp_expired'), en.errorOtpExpired);
      expect(en.describeError('no_fa_assigned'), en.errorNoFaAssigned);
      expect(te.describeError('network'), te.errorNetwork);
    });

    test('falls back to error.unknown', () {
      expect(en.describeError('made_up_code'), en.errorUnknown);
      expect(en.describeError(null), en.errorUnknown);
      expect(en.describeError(''), en.errorUnknown);
      expect(
        en.describeError('made_up_code', details: {'attempts_left': 2}),
        en.errorUnknown,
      );
    });

    test('adds detail sentences', () {
      expect(
        en.describeError('otp_invalid', details: {'attempts_left': 2}),
        'Wrong OTP. Check the SMS and try again. 2 more tries left.',
      );
      expect(
        en.describeError('otp_invalid', details: {'attempts_left': 0}),
        'Wrong OTP. Check the SMS and try again. '
        'No tries left. Ask for a new OTP.',
      );
      expect(
        te.describeError('otp_invalid', details: {'attempts_left': 1}),
        '${te.errorOtpInvalid} ఇంకా 1 సారి ప్రయత్నించవచ్చు.',
      );
      expect(
        en.describeError(
          'rate_limited',
          details: {'retry_after_seconds': '30'},
        ),
        '${en.errorRateLimited} Try again in 30 seconds.',
      );
    });

    test('ignores unknown details and wrong types', () {
      expect(
        en.describeError(
          'validation_failed',
          details: {
            'fields': {'phone': 'invalid'},
          },
        ),
        en.errorValidationFailed,
      );
      expect(
        en.describeError('otp_invalid', details: {'attempts_left': 'many'}),
        en.errorOtpInvalid,
      );
    });

    test('covers the backend codes the farmer and auth surfaces return', () {
      const backend = {
        'otp_invalid', 'otp_expired', 'rate_limited', 'device_revoked', //
        'unauthorized', 'session_revoked', 'refresh_reused', 'forbidden',
        'not_found', 'validation_failed', 'invalid_request', 'unavailable',
        'invalid_cursor', 'payload_too_large', 'internal',
        'profile_already_complete', 'profile_incomplete',
        'active_season_exists', 'season_exists', 'season_not_active',
        'no_fa_assigned', 'callback_closed', 'password_change_required',
        'temp_password_expired', 'version_mismatch',
      };
      expect(knownErrorCodes, containsAll(backend));
      expect(knownErrorCodes, containsAll({'unknown', 'network'}));
    });
  });

  group('enum labels', () {
    late OrbitLocalizations en;
    late OrbitLocalizations te;

    setUpAll(() async {
      en = await OrbitLocalizations.delegate.load(const Locale('en'));
      te = await OrbitLocalizations.delegate.load(const Locale('te'));
    });

    test('typed helpers take API strings', () {
      expect(en.labelSeverity('high'), 'High');
      expect(te.labelSeverity('moderate'), 'మధ్యస్థం');
      expect(en.labelVisitStatus('missed'), 'Missed');
      expect(en.labelCoverageLevel('mandal'), 'Mandal');
      expect(te.labelConsentState('never_asked'), 'ఇంకా అడగలేదు');
      expect(en.labelNoticeSender('civ'), 'CIV');
      expect(te.labelLanguage('te'), 'తెలుగు');
      expect(en.labelLanguage('te'), 'తెలుగు');
    });

    test('unknown values fall back', () {
      expect(en.labelSeverity('critical'), en.commonUnknown);
      expect(en.enumLabel('severity', 'critical'), isNull);
      expect(en.enumLabel('no_such_schema', 'x'), isNull);
    });

    test('every schema value has a label in both locales', () {
      expect(
        enumSchemas.keys,
        containsAll(<String>[
          'severity', 'planned_slot', 'visit_status', 'consent_purpose', //
          'season_status', 'coverage_level', 'farmer_plan', 'farmer_status',
          'area_source', 'area_unit', 'notice_sender',
        ]),
      );
      for (final MapEntry(key: schema, value: values) in enumSchemas.entries) {
        for (final value in values) {
          expect(en.enumLabel(schema, value), isNotNull, reason: value);
          expect(te.enumLabel(schema, value), isNotNull, reason: value);
        }
      }
    });
  });

  group('voice keys', () {
    test('every voice key has an asset path in orbit_voice', () {
      expect(VoiceKeys.all, isNotEmpty);
      expect(voiceAssetPaths.keys.toSet(), VoiceKeys.all.toSet());
      for (final key in VoiceKeys.all) {
        expect(isVoiceKey(key), isTrue);
        expect(voiceAssetPaths[key], 'assets/voice/te/$key.m4a');
        expect(allMessages.containsKey(key), isTrue, reason: key);
      }
      expect(recordedVoiceKeys.difference(VoiceKeys.all.toSet()), isEmpty);
    });

    test('voiceAsset is null unless the prompt is recorded', () {
      expect(isVoiceKey('farmer.login.send_otp'), isFalse);
      expect(voiceAsset('farmer.login.send_otp'), isNull);
      for (final key in VoiceKeys.all) {
        expect(
          voiceAsset(key),
          recordedVoiceKeys.contains(key)
              ? 'packages/orbit_voice/assets/voice/te/$key.m4a'
              : isNull,
        );
      }
    });
  });
}
