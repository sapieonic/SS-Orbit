import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'support/harness.dart';

List<TextStyle> _styles(TextTheme t) => [
  t.displayLarge!,
  t.displayMedium!,
  t.displaySmall!,
  t.headlineLarge!,
  t.headlineMedium!,
  t.headlineSmall!,
  t.titleLarge!,
  t.titleMedium!,
  t.titleSmall!,
  t.bodyLarge!,
  t.bodyMedium!,
  t.bodySmall!,
  t.labelLarge!,
  t.labelMedium!,
  t.labelSmall!,
];

void main() {
  final themes = {'farmer': OrbitTheme.farmer(), 'fa': OrbitTheme.fa()};

  test('primary colours come from the app tokens', () {
    final farmer = themes['farmer']!.colorScheme;
    final fa = themes['fa']!.colorScheme;
    expect(farmer.primary, OrbitFarmerTokens.primary);
    expect(farmer.primaryContainer, OrbitFarmerTokens.primaryTint);
    expect(farmer.onPrimaryContainer, OrbitFarmerTokens.primaryStrong);
    expect(fa.primary, OrbitFaTokens.primary);
    expect(fa.primaryContainer, OrbitFaTokens.primaryTint);
    expect(farmer.outline, OrbitSemanticColors.borderInput);
    expect(farmer.error, OrbitSemanticColors.statusDangerFg);
  });

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    group('$name theme', () {
      test('is light Material 3 with OrbitColors', () {
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, Brightness.light);
        expect(theme.extension<OrbitColors>(), isNotNull);
        expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      });

      test('text uses bundled Figtree with Noto Sans Telugu fallback', () {
        for (final style in _styles(theme.textTheme)) {
          expect(style.fontFamily, 'packages/orbit_ui/Figtree');
          expect(style.fontFamilyFallback, [
            'packages/orbit_ui/Noto Sans Telugu',
          ]);
          expect(style.letterSpacing, 0);
          expect(style.leadingDistribution, TextLeadingDistribution.even);
        }
      });

      test('nothing below 12 px; Telugu line heights', () {
        final t = theme.textTheme;
        for (final style in _styles(t)) {
          expect(style.fontSize, greaterThanOrEqualTo(12));
        }
        for (final style in [t.bodyLarge!, t.bodyMedium!, t.bodySmall!]) {
          expect(style.height, 1.5);
        }
        for (final style in [
          t.displayLarge!,
          t.headlineLarge!,
          t.headlineMedium!,
          t.titleLarge!,
          t.titleMedium!,
        ]) {
          expect(style.height, 1.3);
        }
      });

      test('Material buttons are at least 48 dp', () {
        for (final style in [
          theme.filledButtonTheme.style!,
          theme.outlinedButtonTheme.style!,
          theme.textButtonTheme.style!,
          theme.iconButtonTheme.style!,
        ]) {
          expect(style.minimumSize!.resolve({}), const Size(48, 48));
        }
      });
    });
  }

  test('farmer body is 16 px, FA body 15 px', () {
    expect(themes['farmer']!.textTheme.bodyMedium!.fontSize, 16);
    expect(themes['farmer']!.textTheme.bodyLarge!.fontSize, 16);
    expect(themes['fa']!.textTheme.bodyMedium!.fontSize, 15);
    expect(themes['farmer']!.textTheme.headlineMedium!.fontSize, 26);
    expect(themes['fa']!.textTheme.headlineMedium!.fontSize, 22);
  });

  test('apps differ only in primary-derived colours', () {
    final a = themes['farmer']!.extension<OrbitColors>()!;
    final b = themes['fa']!.extension<OrbitColors>()!;
    expect(a.success, b.success);
    expect(a.warning, b.warning);
    expect(a.danger, b.danger);
    expect(a.severityHigh, b.severityHigh);
    expect(a.info, isNot(b.info));
    expect(a.info.fg, OrbitFarmerTokens.primary);
  });

  test('OrbitColors copyWith and lerp', () {
    final a = themes['farmer']!.extension<OrbitColors>()!;
    final b = themes['fa']!.extension<OrbitColors>()!;
    final mid = a.lerp(a, 0.5);
    expect(mid.success, a.success);
    expect(mid.onPrimaryBar, a.onPrimaryBar);
    expect(a.copyWith().info, a.info);
    expect(a.lerp(b, 1).info, b.info);
    expect(a.lerp(null, 0.3), same(a));
    expect(a.copyWith(textMuted: OrbitPalette.ink).textMuted, OrbitPalette.ink);
  });

  testWidgets('sizes survive the Telugu (tall) script localisation', (
    tester,
  ) async {
    late ThemeData seen;
    late TextStyle defaultText;
    await pumpOrbit(
      tester,
      Builder(
        builder: (context) {
          seen = Theme.of(context);
          defaultText = DefaultTextStyle.of(context).style;
          return const SizedBox();
        },
      ),
    );
    expect(
      Localizations.localeOf(tester.element(find.byType(SizedBox))),
      const Locale('te'),
    );
    expect(seen.textTheme.bodyMedium!.fontSize, 16);
    expect(seen.textTheme.bodyMedium!.height, 1.5);
    expect(seen.textTheme.headlineMedium!.fontSize, 26);
    expect(defaultText.fontSize, 16);
    expect(defaultText.fontFamily, 'packages/orbit_ui/Figtree');
  });
}
