import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'support/harness.dart';

// Components added for the FA app: PinPad, PinDots, FilterChipsBar,
// DayStrip, ConflictCard, SwitchRow, StepIndicator. Telugu samples from the
// FA designs.

const _weekdays = ['సోమ', 'మంగళ', 'బుధ', 'గురు', 'శుక్ర', 'శని', 'ఆది'];

List<DayStripDay> _week({int visits = 3}) => [
  for (var i = 0; i < 7; i++)
    DayStripDay(
      weekday: _weekdays[i],
      day: '${26 + i}',
      dots: i == 3 ? 9 : visits,
      isToday: i == 1,
      semanticLabel: '${_weekdays[i]} ${26 + i}, $visits సందర్శనలు',
    ),
];

void main() {
  group('PinPad and PinDots', () {
    layoutTest(
      'the pad with a text key and the dots',
      () => Column(
        children: [
          const PinDots(length: 4, filled: 2, semanticLabel: '4 లో 2'),
          const SizedBox(height: OrbitSpace.s16),
          PinPad(
            onDigit: (_) {},
            onDelete: () {},
            deleteLabel: 'అంకె తొలగించు',
            leading: PinPadKey.text(label: 'వెనుకకు', onPressed: () {}),
          ),
        ],
      ),
      theme: OrbitTheme.fa,
    );

    testWidgets('sends digits, delete and the leading key', (tester) async {
      final typed = <String>[];
      var deleted = 0;
      var finger = 0;
      await pumpOrbit(
        tester,
        PinPad(
          onDigit: typed.add,
          onDelete: () => deleted++,
          deleteLabel: 'Delete digit',
          leading: PinPadKey.icon(
            icon: OrbitIcons.fingerprint,
            semanticLabel: 'Use fingerprint',
            onPressed: () => finger++,
          ),
        ),
        theme: OrbitTheme.fa(),
      );
      for (final d in ['1', '9', '0']) {
        await tester.tap(find.text(d));
      }
      await tester.tap(find.bySemanticsLabel('Delete digit'));
      await tester.tap(find.bySemanticsLabel('Use fingerprint'));
      expect(typed, ['1', '9', '0']);
      expect(deleted, 1);
      expect(finger, 1);
    });

    testWidgets('keys are 64 dp tall and ignore taps when disabled', (
      tester,
    ) async {
      final typed = <String>[];
      await pumpOrbit(
        tester,
        PinPad(
          onDigit: typed.add,
          onDelete: () {},
          deleteLabel: 'Delete digit',
          enabled: false,
        ),
        theme: OrbitTheme.fa(),
      );
      final key = find.ancestor(
        of: find.text('5'),
        matching: find.byType(PinPadKey),
      );
      expect(tester.getSize(key).height, greaterThanOrEqualTo(64));
      await tester.tap(find.text('5'));
      expect(typed, isEmpty);
      expect(
        tester.getSemantics(key),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
    });

    testWidgets('the dots read as one label', (tester) async {
      await pumpOrbit(
        tester,
        const PinDots(length: 4, filled: 3, semanticLabel: '3 of 4 entered'),
        theme: OrbitTheme.fa(),
      );
      expect(find.bySemanticsLabel('3 of 4 entered'), findsOneWidget);
    });
  });

  group('FilterChipsBar', () {
    final items = [
      const FilterChipItem(label: 'అన్నీ', count: 46),
      const FilterChipItem(label: 'కొత్త', count: 2),
      const FilterChipItem(label: 'సందర్శన రావాలి', count: 12),
      const FilterChipItem(label: '30+ రోజులు', count: 5),
      const FilterChipItem(label: 'ప్రీమియం'),
    ];

    layoutTest(
      'a row wider than the screen scrolls',
      () => FilterChipsBar(
        items: items,
        selectedIndex: 0,
        onSelected: (_) {},
        semanticLabel: 'రైతులను వడపోయండి',
      ),
      theme: OrbitTheme.fa,
    );

    testWidgets('shows counts, selects one and is 48 dp tall', (tester) async {
      var selected = 0;
      await pumpOrbit(
        tester,
        StatefulBuilder(
          builder: (context, setState) => FilterChipsBar(
            items: items,
            selectedIndex: selected,
            onSelected: (i) => setState(() => selected = i),
          ),
        ),
        theme: OrbitTheme.fa(),
      );
      expect(find.text('అన్నీ · 46'), findsOneWidget);
      expect(find.text('ప్రీమియం'), findsOneWidget);
      final chip = find.text('కొత్త · 2');
      expect(tester.getSize(chip).height, lessThan(48));
      expect(
        tester.getSize(find.ancestor(of: chip, matching: find.byType(InkWell))),
        isA<Size>().having((s) => s.height, 'height', greaterThanOrEqualTo(48)),
      );
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(
        tester.getSemantics(find.text('కొత్త · 2')),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          label: 'కొత్త · 2',
          hasTapAction: true,
        ),
      );
    });

    testWidgets('a bar without onSelected reads as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpOrbit(
        tester,
        FilterChipsBar(items: items, selectedIndex: 0, onSelected: null),
        theme: OrbitTheme.fa(),
      );
      expect(
        tester.getSemantics(find.text('కొత్త · 2')),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          label: 'కొత్త · 2',
        ),
      );
      handle.dispose();
    });

    testWidgets('selecting a chip off screen scrolls it into view', (
      tester,
    ) async {
      var selected = 0;
      late StateSetter set;
      await pumpOrbit(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return FilterChipsBar(
              items: items,
              selectedIndex: selected,
              onSelected: (_) {},
            );
          },
        ),
        theme: OrbitTheme.fa(),
        scroll: false,
      );
      final last = find.text('ప్రీమియం');
      expect(tester.getRect(last).right, greaterThan(phone.width));
      set(() => selected = 4);
      await tester.pumpAndSettle();
      expect(tester.getRect(last).right, lessThanOrEqualTo(phone.width));
    });
  });

  group('DayStrip', () {
    layoutTest(
      'a week with dots',
      () => DayStrip(
        days: _week(),
        selectedIndex: 1,
        onSelected: (_) {},
        semanticLabel: 'అక్టోబర్ 26 వారం',
      ),
      theme: OrbitTheme.fa,
    );

    testWidgets('each day reads its label and the selected one is marked', (
      tester,
    ) async {
      var picked = -1;
      await pumpOrbit(
        tester,
        DayStrip(
          days: _week(),
          selectedIndex: 2,
          onSelected: (i) => picked = i,
        ),
        theme: OrbitTheme.fa(),
      );
      final wed = find.bySemanticsLabel('బుధ 28, 3 సందర్శనలు');
      expect(wed, findsOneWidget);
      expect(
        tester.getSemantics(wed),
        isSemantics(isButton: true, hasSelectedState: true, isSelected: true),
      );
      await tester.tap(find.text('30'));
      expect(picked, 4);
      // At most four dots under a busy day.
      final dots = find.descendant(
        of: find.ancestor(of: find.text('29'), matching: find.byType(InkWell)),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(dots, findsNWidgets(DayStrip.maxDots));
    });

    for (final width in [336.0, 328.0]) {
      testWidgets('every day is a 48 dp target at ${width.toInt()} dp wide', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpOrbit(
          tester,
          Center(
            child: SizedBox(
              width: width,
              child: DayStrip(
                days: _week(),
                selectedIndex: 1,
                onSelected: (_) {},
              ),
            ),
          ),
          theme: OrbitTheme.fa(),
          scroll: false,
        );
        for (final e
            in find
                .descendant(
                  of: find.byType(DayStrip),
                  matching: find.byType(InkWell),
                )
                .evaluate()) {
          expect(e.size!.width, greaterThanOrEqualTo(DayStrip.minDayWidth));
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('ConflictCard', () {
    Widget card({
      VoidCallback? mine,
      VoidCallback? theirs,
      bool resolving = false,
    }) => ConflictCard(
      title: 'సందర్శన లాగ్ · పద్మ ఎస్',
      meta: 'మీరు ఆఫ్‌లైన్‌లో ఉన్నప్పుడు HO పొలం 2 మార్చింది',
      statusLabel: 'విభేదం',
      mineLabel: 'మీది',
      mineValue: '1 ఎ. 30 గుం.',
      theirsLabel: 'HO ది',
      theirsValue: '2 ఎ. 0 గుం.',
      keepMineLabel: 'నాది ఉంచు',
      keepTheirsLabel: 'HO ది ఉంచు',
      onKeepMine: mine,
      onKeepTheirs: theirs,
      resolving: resolving,
    );

    layoutTest('both values and buttons', card, theme: OrbitTheme.fa);

    testWidgets('each button keeps its version; resolving blocks both', (
      tester,
    ) async {
      final kept = <String>[];
      await pumpOrbit(
        tester,
        card(mine: () => kept.add('mine'), theirs: () => kept.add('ho')),
        theme: OrbitTheme.fa(),
      );
      await tester.tap(find.text('నాది ఉంచు'));
      await tester.tap(find.text('HO ది ఉంచు'));
      expect(kept, ['mine', 'ho']);
      expect(find.text('1 ఎ. 30 గుం.'), findsOneWidget);
      expect(find.byType(StatusPill), findsOneWidget);

      await pumpOrbit(
        tester,
        card(
          mine: () => kept.add('mine'),
          theirs: () => kept.add('ho'),
          resolving: true,
        ),
        theme: OrbitTheme.fa(),
      );
      await tester.tap(find.text('నాది ఉంచు'));
      expect(kept, ['mine', 'ho']);
    });

    Widget acceptOnly({VoidCallback? theirs}) => ConflictCard(
      title: 'Crop season · Padma S',
      meta: 'Only HO\'s version can be kept',
      statusLabel: 'Conflict',
      mineLabel: 'Yours',
      mineValue: 'Cotton',
      theirsLabel: 'HO\'s',
      theirsValue: 'Paddy',
      keepTheirsLabel: 'Keep HO\'s',
      onKeepTheirs: theirs,
    );

    layoutTest('without Keep mine', acceptOnly, theme: OrbitTheme.fa);

    testWidgets('no keep-mine label: only Keep HO\'s, full width', (
      tester,
    ) async {
      var kept = 0;
      await pumpOrbit(
        tester,
        acceptOnly(theirs: () => kept++),
        theme: OrbitTheme.fa(),
      );
      expect(find.byType(OutlinedButton), findsNothing);
      final button = find.widgetWithText(FilledButton, 'Keep HO\'s');
      expect(button, findsOneWidget);
      final card = tester.getSize(find.byType(ConflictCard));
      expect(tester.getSize(button).width, greaterThan(card.width * 0.8));
      await tester.tap(button);
      expect(kept, 1);
    });
  });

  group('SwitchRow', () {
    layoutTest(
      'with a sub-line, bordered',
      () => SwitchRow(
        title: 'Wi-Fi లో మాత్రమే ఫోటోలు అప్‌లోడ్ చేయండి',
        subtitle: 'ఆన్ · రికార్డులు మొబైల్ డేటాలో కూడా సింక్ అవుతాయి',
        value: true,
        onChanged: (_) {},
        bordered: true,
      ),
      theme: OrbitTheme.fa,
    );

    testWidgets('the whole row toggles and reads as one switch', (
      tester,
    ) async {
      var on = false;
      await pumpOrbit(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SwitchRow(
            title: 'Photos on Wi-Fi only',
            subtitle: 'Off',
            value: on,
            onChanged: (v) => setState(() => on = v),
          ),
        ),
        theme: OrbitTheme.fa(),
      );
      expect(
        tester.getSize(find.byType(SwitchRow)).height,
        greaterThanOrEqualTo(SwitchRow.minHeight),
      );
      await tester.tap(find.text('Photos on Wi-Fi only'));
      await tester.pump();
      expect(on, isTrue);
      final node = tester.getSemantics(find.byType(Switch));
      expect(node.label, contains('Photos on Wi-Fi only'));
      expect(node.label, contains('Off'));
      expect(
        tester.getSemantics(find.byType(Switch)),
        isSemantics(hasToggledState: true, isToggled: true),
      );
    });
  });

  group('StepIndicator', () {
    layoutTest(
      'three steps, the second current',
      () =>
          const StepIndicator(labels: ['రైతు', 'పొలం', 'పంట'], currentIndex: 1),
      theme: OrbitTheme.fa,
    );

    testWidgets('done steps tick, the current one is announced', (
      tester,
    ) async {
      await pumpOrbit(
        tester,
        const StepIndicator(
          labels: ['Farmer', 'Farm', 'Crop'],
          currentIndex: 2,
          doneLabel: 'done',
          currentLabel: 'current step',
        ),
        theme: OrbitTheme.fa(),
      );
      expect(find.byIcon(OrbitIcons.check), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
      expect(find.bySemanticsLabel('Farmer, done'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Crop, current step')),
        isSemantics(hasSelectedState: true, isSelected: true),
      );
    });
  });
}
