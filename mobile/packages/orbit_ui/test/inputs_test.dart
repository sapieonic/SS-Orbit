import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'support/harness.dart';
import 'support/wireframe_text.dart' as w;

void main() {
  group('PhoneField', () {
    layoutTest(
      'with label, helper and error',
      () => const Column(
        children: [
          PhoneField(label: w.phoneLabel, helperText: w.noFaSub),
          SizedBox(height: OrbitSpace.s16),
          PhoneField(label: w.phoneLabel, errorText: w.otpWrong),
        ],
      ),
    );

    testWidgets('uses the phone keypad and phone autofill', (tester) async {
      await pumpOrbit(tester, const PhoneField(label: w.phoneLabel));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.phone);
      expect(field.autofillHints, [AutofillHints.telephoneNumber]);
      expect(find.text('+91'), findsOneWidget);
    });

    testWidgets('strips a pasted country code and refuses an 11th digit', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpOrbit(tester, PhoneField(controller: controller));
      await tester.enterText(find.byType(TextField), '+91 98765 43210');
      expect(controller.text, '9876543210');
      // Typing one more digit at the end leaves the number as it was.
      await tester.enterText(find.byType(TextField), '98765432101');
      expect(controller.text, '9876543210');
      await tester.enterText(find.byType(TextField), '98a76');
      expect(controller.text, '9876');
    });

    group('IndianMobileNumberFormatter', () {
      const formatter = IndianMobileNumberFormatter();

      TextEditingValue value(String text, [int? offset]) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset ?? text.length),
      );

      String format(String before, String after) =>
          formatter.formatEditUpdate(value(before), value(after)).text;

      test('typing an 11th digit is refused, wherever the cursor is', () {
        const full = '9876543210';
        // At the end: keeping the last 10 would give 8765432101, someone
        // else's number.
        expect(format(full, '${full}1'), full);
        // At the start and in the middle.
        expect(format(full, '1$full'), full);
        expect(format(full, '98765143210'), full);
        // A leading 0 or 91 typed by hand is not taken for a prefix either.
        expect(format('0987654321', '09876543215'), '0987654321');
        expect(format('9198765432', '91987654321'), '9198765432');
        // The refused edit keeps the old selection too.
        final old = value(full, 4);
        expect(formatter.formatEditUpdate(old, value('98761543210', 5)), old);
      });

      test('a pasted or autofilled number loses a recognised prefix', () {
        for (final pasted in [
          '+91 98765 43210',
          '+919876543210',
          '919876543210',
          '09876543210',
          '0091 98765 43210',
          '00919876543210',
          '+91-98765-43210',
        ]) {
          expect(format('', pasted), '9876543210', reason: pasted);
          // Also over a full field (select all, paste).
          expect(format('1234567890', pasted), '9876543210', reason: pasted);
        }
      });

      test('pasted text too long for any prefix is refused', () {
        for (final pasted in [
          '98765432101', // 11 digits, no leading 0
          '929876543210', // 12 digits, not 91
          '0919876543210', // 13 digits
          '+44 7911 123456 7',
        ]) {
          expect(format('98', pasted), '98', reason: pasted);
        }
        // A paste that makes a full field too long.
        expect(format('9876543210', '98765432109876543210'), '9876543210');
      });

      test('short pastes and clean input pass through', () {
        expect(format('', '98765 43210'), '9876543210');
        expect(format('98', '98 765'), '98765');
        expect(format('', '0987'), '0987');
      });
    });

    test('formatter leaves clean input untouched', () {
      const formatter = IndianMobileNumberFormatter();
      const value = TextEditingValue(
        text: '98765',
        selection: TextSelection.collapsed(offset: 5),
      );
      expect(formatter.formatEditUpdate(TextEditingValue.empty, value), value);
    });
  });

  group('OtpInput', () {
    layoutTest(
      'empty, partial and error',
      () => Column(
        children: [
          const OtpInput(semanticLabel: 'OTP'),
          const SizedBox(height: OrbitSpace.s16),
          OtpInput(
            controller: TextEditingController(text: '1234'),
            errorText: w.otpWrong,
          ),
        ],
      ),
    );

    testWidgets('has 6 boxes, one-time-code autofill and a number keypad', (
      tester,
    ) async {
      await pumpOrbit(tester, const OtpInput());
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofillHints, [AutofillHints.oneTimeCode]);
      expect(field.keyboardType, TextInputType.number);
      final row = tester.widget<Row>(
        find.descendant(of: find.byType(OtpInput), matching: find.byType(Row)),
      );
      expect(row.children.whereType<Expanded>(), hasLength(6));
    });

    testWidgets('fires onCompleted once with the code, also on paste', (
      tester,
    ) async {
      final completed = <String>[];
      await pumpOrbit(tester, OtpInput(onCompleted: completed.add));
      await tester.enterText(find.byType(TextField), '123');
      expect(completed, isEmpty);
      // Pasted SMS text: non-digits dropped, cut to 6 digits.
      await tester.enterText(find.byType(TextField), 'OTP 654321 valid 10 min');
      await tester.pump();
      expect(completed, ['654321']);
      for (var i = 0; i < 6; i++) {
        expect(find.text('654321'[i]), findsOneWidget);
      }
    });

    testWidgets('only the active box shows focus, never the whole row', (
      tester,
    ) async {
      final controller = TextEditingController(text: '12');
      addTearDown(controller.dispose);
      await pumpOrbit(tester, OtpInput(controller: controller));
      await tester.tap(find.byType(OtpInput));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      // The hidden field draws nothing of its own (the theme's focused
      // outline used to frame all six boxes).
      expect(
        find.descendant(
          of: find.byType(OtpInput),
          matching: find.byType(InputDecorator),
        ),
        findsNothing,
      );

      final primary = Theme.of(tester.element(find.byType(OtpInput)))
          .colorScheme
          .primary;
      final borders = [
        for (final box in tester.widgetList<Container>(
          find.descendant(
            of: find.byType(OtpInput),
            matching: find.byType(Container),
          ),
        ))
          (box.decoration! as BoxDecoration).border! as Border,
      ];
      expect(borders, hasLength(6));
      final active = [
        for (final (i, border) in borders.indexed)
          if (border.top.color == primary) i,
      ];
      expect(active, [2], reason: 'the box for the third digit is next');
    });

    testWidgets('shows the error text and red borders', (tester) async {
      await pumpOrbit(tester, const OtpInput(errorText: w.otpWrong));
      expect(find.text(w.otpWrong), findsOneWidget);
      final context = tester.element(find.byType(OtpInput));
      final error = Theme.of(context).colorScheme.error;
      final boxes = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(OtpInput),
          matching: find.byType(Container),
        ),
      );
      expect(boxes, hasLength(6));
      for (final box in boxes) {
        final border = (box.decoration! as BoxDecoration).border! as Border;
        expect(border.top.color, error);
      }
    });
  });

  group('SegmentedTabs', () {
    layoutTest(
      'village / mandal / district',
      () => SegmentedTabs(
        labels: const [w.village, w.mandal, w.district],
        selectedIndex: 1,
        onChanged: (_) {},
      ),
    );

    testWidgets('reports taps and marks the selected segment', (tester) async {
      final semantics = tester.ensureSemantics();
      int? tapped;
      await pumpOrbit(
        tester,
        SegmentedTabs(
          labels: const [w.village, w.mandal, w.district],
          selectedIndex: 0,
          onChanged: (i) => tapped = i,
        ),
      );
      await tester.tap(find.text(w.district));
      expect(tapped, 2);
      final node = tester.getSemantics(find.bySemanticsLabel(w.village));
      expect(
        node,
        isSemantics(
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          isButton: true,
        ),
      );
      expect(
        tester.getSize(find.text(w.village)).height,
        lessThanOrEqualTo(tester.getSize(find.byType(SegmentedTabs)).height),
      );
      semantics.dispose();
    });
  });

  group('ChoiceTile', () {
    layoutTest(
      'selected, with tag, and plain',
      () => Column(
        children: [
          ChoiceTile(
            label: w.cotton,
            secondaryLabel: w.cottonEn,
            icon: OrbitIcons.crop,
            tag: const OrbitTag(label: w.thisSeason),
            selected: true,
            onTap: () {},
          ),
          const SizedBox(height: OrbitSpace.s8),
          ChoiceTile(
            label: w.paddy,
            secondaryLabel: w.paddyEn,
            selected: false,
            onTap: () {},
          ),
        ],
      ),
    );

    testWidgets('is a 56 dp option that reports taps and its selection', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpOrbit(
        tester,
        ChoiceTile(
          label: w.cotton,
          secondaryLabel: w.cottonEn,
          selected: true,
          onTap: () => taps++,
        ),
      );
      expect(
        tester.getSize(find.byType(ChoiceTile)).height,
        greaterThanOrEqualTo(OrbitSize.controlXl),
      );
      // Selection is a tick plus the colour, not colour alone.
      expect(find.byIcon(OrbitIcons.success), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ChoiceTile)),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      await tester.tap(find.text(w.cotton));
      expect(taps, 1);
      semantics.dispose();
    });
  });

  group('InlineError', () {
    layoutTest(
      'a long Telugu message wraps',
      () => const InlineError(w.noInternetError),
    );

    testWidgets('shows an icon with the words and is a live region', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpOrbit(tester, const InlineError(w.otpWrong));
      expect(find.byIcon(OrbitIcons.alert), findsOneWidget);
      expect(
        tester.getSemantics(find.text(w.otpWrong)),
        isSemantics(label: w.otpWrong, isLiveRegion: true),
      );
      semantics.dispose();
    });
  });
}
