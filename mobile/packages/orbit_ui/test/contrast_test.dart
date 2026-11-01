import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

typedef S = OrbitSemanticColors;

const double textAA = 4.5;
const double uiAA = 3;

void expectContrast(String name, Color fg, Color bg, double min) {
  final ratio = contrast(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(min),
    reason: '$name is ${ratio.toStringAsFixed(2)}:1, needs $min:1',
  );
}

void main() {
  test('contrast() matches known WCAG values from the design plan', () {
    expect(
      contrast(OrbitPalette.white, OrbitPalette.saffron),
      closeTo(5.22, 0.02),
    );
    expect(
      contrast(OrbitPalette.ink, OrbitPalette.white),
      closeTo(15.91, 0.02),
    );
    expect(
      contrast(OrbitPalette.lineInput, OrbitPalette.white),
      closeTo(3.17, 0.02),
    );
    expect(
      contrast(OrbitPalette.white, OrbitPalette.amber),
      closeTo(3.76, 0.02),
    );
  });

  group('token text pairs reach AA (4.5:1)', () {
    final pairs = <String, (Color, Color)>{
      'ink on surface': (S.textPrimary, S.surfaceDefault),
      'ink on canvas': (S.textPrimary, S.surfaceCanvas),
      'ink on sunken': (S.textPrimary, S.surfaceSunken),
      'ink-2 on surface': (S.textSecondary, S.surfaceDefault),
      'ink-2 on canvas': (S.textSecondary, S.surfaceCanvas),
      'ink-2 on sunken': (S.textSecondary, S.surfaceSunken),
      'muted on surface': (S.textMuted, S.surfaceDefault),
      'muted on canvas': (S.textMuted, S.surfaceCanvas),
      'white on farmer primary': (S.textOnFilled, OrbitFarmerTokens.primary),
      'white on FA primary': (S.textOnFilled, OrbitFaTokens.primary),
      'white on call green': (S.textOnFilled, S.actionCall),
      'white on danger red': (S.textOnFilled, S.actionDanger),
      'white on ink bar': (S.textOnFilled, S.surfaceInverse),
      'bar text on farmer primary': (
        S.onPrimaryBarFg,
        OrbitFarmerTokens.primary,
      ),
      'bar text on FA primary': (S.onPrimaryBarFg, OrbitFaTokens.primary),
      'farmer strong on tint': (
        OrbitFarmerTokens.primaryStrong,
        OrbitFarmerTokens.primaryTint,
      ),
      'farmer strong on surface': (
        OrbitFarmerTokens.primaryStrong,
        S.surfaceDefault,
      ),
      'farmer primary on surface': (
        OrbitFarmerTokens.primary,
        S.surfaceDefault,
      ),
      'FA strong on tint': (
        OrbitFaTokens.primaryStrong,
        OrbitFaTokens.primaryTint,
      ),
      'FA primary on surface': (OrbitFaTokens.primary, S.surfaceDefault),
      'success strong on tint': (S.statusSuccessStrong, S.statusSuccessTint),
      'warning strong on tint': (S.statusWarningStrong, S.statusWarningTint),
      'danger strong on tint': (S.statusDangerStrong, S.statusDangerTint),
      'low strong on tint': (S.severityLowStrong, S.severityLowTint),
      'moderate strong on tint': (
        S.severityModerateStrong,
        S.severityModerateTint,
      ),
      'high strong on tint': (S.severityHighStrong, S.severityHighTint),
      'ink on highlight': (S.textOnHighlight, S.surfaceHighlight),
    };
    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      test(name, () => expectContrast(name, fg, bg, textAA));
    }
  });

  group('token UI pairs reach 3:1', () {
    final pairs = <String, (Color, Color)>{
      'input border on surface': (S.borderInput, S.surfaceDefault),
      'input border on canvas': (S.borderInput, S.surfaceCanvas),
      'success icon on surface': (S.statusSuccessFg, S.surfaceDefault),
      'warning icon on surface': (S.statusWarningFg, S.surfaceDefault),
      'danger icon on surface': (S.statusDangerFg, S.surfaceDefault),
    };
    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      test(name, () => expectContrast(name, fg, bg, uiAA));
    }
  });

  for (final (name, theme) in [
    ('farmer', OrbitTheme.farmer()),
    ('fa', OrbitTheme.fa()),
  ]) {
    test('$name theme: every colour pair components draw text with', () {
      final c = theme.colorScheme;
      final o = theme.extension<OrbitColors>()!;
      final pairs = <String, (Color, Color)>{
        'onPrimary/primary': (c.onPrimary, c.primary),
        'onPrimaryContainer/primaryContainer': (
          c.onPrimaryContainer,
          c.primaryContainer,
        ),
        'secondary/surface (outlined button)': (c.secondary, c.surface),
        'onError/error': (c.onError, c.error),
        'onErrorContainer/errorContainer': (
          c.onErrorContainer,
          c.errorContainer,
        ),
        'onSurface/surface': (c.onSurface, c.surface),
        'onSurfaceVariant/surface': (c.onSurfaceVariant, c.surface),
        'onSurfaceVariant/surfaceContainerHighest': (
          c.onSurfaceVariant,
          c.surfaceContainerHighest,
        ),
        'onInverseSurface/inverseSurface': (
          c.onInverseSurface,
          c.inverseSurface,
        ),
        'onPrimary/success.fg (call button)': (c.onPrimary, o.success.fg),
        'onPrimaryBar/primary': (o.onPrimaryBar, c.primary),
        'onPrimaryBar/inverseSurface': (o.onPrimaryBar, c.inverseSurface),
        'onHighlight/highlight': (o.onHighlight, o.highlight),
        'textMuted/surface': (o.textMuted, c.surface),
        for (final (tone, t) in [
          ('success', o.success),
          ('warning', o.warning),
          ('danger', o.danger),
          ('info', o.info),
          ('severityLow', o.severityLow),
          ('severityModerate', o.severityModerate),
          ('severityHigh', o.severityHigh),
        ]) ...{
          '$tone strong/tint': (t.strong, t.tint),
          '$tone strong/surface': (t.strong, c.surface),
        },
      };
      for (final MapEntry(key: pair, value: (fg, bg)) in pairs.entries) {
        expectContrast(pair, fg, bg, textAA);
      }
      expectContrast('outline/surface', c.outline, c.surface, uiAA);
    });
  }
}
