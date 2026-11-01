import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'support/harness.dart';
import 'support/wireframe_text.dart' as w;

void main() {
  group('OrbitButton', () {
    layoutTest(
      'every variant and size',
      () => Column(
        children: [
          for (final variant in OrbitButtonVariant.values)
            for (final size in OrbitButtonSize.values)
              Padding(
                padding: const EdgeInsets.only(bottom: OrbitSpace.s8),
                child: OrbitButton(
                  label: w.callSuresh,
                  secondaryLabel: w.callSureshEn,
                  variant: variant,
                  size: size,
                  icon: OrbitIcons.phone,
                  onPressed: () {},
                ),
              ),
          const OrbitButton(label: w.consentOk, onPressed: null),
          OrbitButton(label: w.consentOk, loading: true, onPressed: () {}),
          Row(
            children: [
              OrbitButton(label: w.call, fullWidth: false, onPressed: () {}),
            ],
          ),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: OrbitButton(label: w.call, onPressed: () {}),
                ),
                Expanded(
                  child: OrbitButton(label: w.consentOk, onPressed: () {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    testWidgets('meets its minimum height per size', (tester) async {
      await pumpOrbit(
        tester,
        Column(
          children: [
            for (final size in OrbitButtonSize.values)
              OrbitButton(
                key: ValueKey(size),
                label: w.call,
                size: size,
                onPressed: () {},
              ),
          ],
        ),
      );
      for (final size in OrbitButtonSize.values) {
        final height = tester.getSize(find.byKey(ValueKey(size))).height;
        expect(height, greaterThanOrEqualTo(size.minHeight));
      }
      expect(OrbitButtonSize.medium.minHeight, 48);
      expect(OrbitButtonSize.large.minHeight, 56);
      expect(OrbitButtonSize.hero.minHeight, 64);
    });

    testWidgets('calls onPressed, ignores taps while loading', (tester) async {
      var taps = 0;
      await pumpOrbit(
        tester,
        OrbitButton(label: w.consentOk, onPressed: () => taps++),
      );
      await tester.tap(find.byType(OrbitButton));
      expect(taps, 1);

      await pumpOrbit(
        tester,
        OrbitButton(label: w.consentOk, loading: true, onPressed: () => taps++),
      );
      await tester.tap(find.byType(OrbitButton));
      await tester.pump();
      expect(taps, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('call variant adds a phone icon and uses success colour', (
      tester,
    ) async {
      await pumpOrbit(
        tester,
        OrbitButton(
          label: w.call,
          variant: OrbitButtonVariant.call,
          onPressed: () {},
        ),
      );
      expect(find.byIcon(OrbitIcons.phone), findsOneWidget);
      final context = tester.element(find.byType(OrbitButton));
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.style!.backgroundColor!.resolve({}),
        OrbitColors.of(context).success.fg,
      );
    });

    testWidgets('secondary variant is outlined', (tester) async {
      await pumpOrbit(
        tester,
        OrbitButton(
          label: w.call,
          variant: OrbitButtonVariant.secondary,
          onPressed: () {},
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('is disabled without onPressed', (tester) async {
      await pumpOrbit(
        tester,
        const OrbitButton(label: w.consentOk, onPressed: null),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('ListenButton', () {
    layoutTest(
      'inline and floating in every state',
      () => Wrap(
        spacing: OrbitSpace.s8,
        runSpacing: OrbitSpace.s8,
        children: [
          for (final state in ListenState.values) ...[
            ListenButton(label: w.listen, state: state, onPressed: () {}),
            ListenButton.floating(
              label: w.listen,
              secondaryLabel: w.listenEn,
              state: state,
              onPressed: () {},
            ),
          ],
        ],
      ),
    );

    testWidgets('shows an icon per state', (tester) async {
      Future<void> pumpState(ListenState state) => pumpOrbit(
        tester,
        ListenButton(label: w.listen, state: state, onPressed: () {}),
      );
      await pumpState(ListenState.idle);
      expect(find.byIcon(OrbitIcons.listen), findsOneWidget);
      await pumpState(ListenState.playing);
      expect(find.byIcon(OrbitIcons.stop), findsOneWidget);
      await pumpState(ListenState.unavailable);
      expect(find.byIcon(OrbitIcons.listenUnavailable), findsOneWidget);
      await pumpState(ListenState.loading);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('is a 48 dp button announced with its label', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpOrbit(
        tester,
        Row(
          children: [ListenButton(label: w.listen, onPressed: () => taps++)],
        ),
      );
      final size = tester.getSize(find.byType(ListenButton));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.byType(ListenButton)),
        matchesSemantics(
          label: w.listen,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.byType(ListenButton));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('floating variant is at least 56 dp tall', (tester) async {
      await pumpOrbit(
        tester,
        Row(
          children: [ListenButton.floating(label: w.listen, onPressed: () {})],
        ),
      );
      expect(
        tester.getSize(find.byType(ListenButton)).height,
        greaterThanOrEqualTo(56),
      );
    });
  });
}
