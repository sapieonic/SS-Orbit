import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/shared/farmer_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('profileName (sign-up)', () {
    test('a Telugu name is both name and name_te', () {
      expect(profileName('  రాము   కె '), (name: 'రాము కె', nameTe: 'రాము కె'));
    });

    test('a Latin name is name only', () {
      expect(profileName('Ramu K'), (name: 'Ramu K', nameTe: null));
    });

    test('one Telugu letter in a mixed name makes it Telugu', () {
      expect(profileName('Ramu కె'), (name: 'Ramu కె', nameTe: 'Ramu కె'));
    });

    test('blank stays blank', () {
      expect(profileName(' \n '), (name: '', nameTe: null));
    });
  });

  group('renamedProfile (Change name)', () {
    test('a Telugu name is both name and name_te, in either language', () {
      for (final language in Language.values) {
        expect(renamedProfile('రాము  కె', language: language, nameTe: 'రాము'), (
          name: 'రాము కె',
          nameTe: 'రాము కె',
        ));
      }
    });

    test('a Latin name over the Telugu spelling replaces it too', () {
      expect(
        renamedProfile(' Ravi Kumar ', language: Language.te, nameTe: 'రవి కె'),
        (name: 'Ravi Kumar', nameTe: 'Ravi Kumar'),
      );
    });

    test('a Latin name is name only without a Telugu spelling, or when the '
        'field showed the English name', () {
      expect(
        renamedProfile('Ravi Kumar', language: Language.te, nameTe: null),
        (name: 'Ravi Kumar', nameTe: null),
      );
      expect(
        renamedProfile('Ravi Kumar', language: Language.en, nameTe: 'రవి కె'),
        (name: 'Ravi Kumar', nameTe: null),
      );
    });
  });

  test('hasTelugu: the Telugu block only', () {
    expect(hasTelugu('రవి'), isTrue);
    expect(hasTelugu('Ravi 12'), isFalse);
    expect(hasTelugu('रवि'), isFalse, reason: 'Devanagari');
  });
}
