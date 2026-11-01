import 'package:flutter/material.dart';

import '../tokens/orbit_tokens.g.dart';
import 'orbit_colors.dart';
import 'orbit_fonts.dart';

/// Material 3 themes for the Orbit apps, built only from the generated tokens.
///
/// ```dart
/// MaterialApp(theme: OrbitTheme.farmer(), ...)
/// ```
///
/// Light only (sunlight readability beats dark mode for farmers and FAs).
/// Every text style uses Figtree with Noto Sans Telugu as fallback, Telugu
/// line heights (1.5 body, 1.3 headings) and zero letter spacing.
abstract final class OrbitTheme {
  /// Farmer app: saffron-brown primary, 16 px body, nothing below 12 px.
  static ThemeData farmer() => _build(
    primary: OrbitFarmerTokens.primary,
    primaryStrong: OrbitFarmerTokens.primaryStrong,
    primaryTint: OrbitFarmerTokens.primaryTint,
    body: OrbitFarmerTokens.bodyText,
    screenTitle: OrbitFarmerTokens.screenTitle,
  );

  /// Field Assistant app: blue primary, 15 px body.
  static ThemeData fa() => _build(
    primary: OrbitFaTokens.primary,
    primaryStrong: OrbitFaTokens.primaryStrong,
    primaryTint: OrbitFaTokens.primaryTint,
    body: OrbitFaTokens.bodyText,
    screenTitle: OrbitFaTokens.screenTitle,
  );

  static ThemeData _build({
    required Color primary,
    required Color primaryStrong,
    required Color primaryTint,
    required TextStyle body,
    required TextStyle screenTitle,
  }) {
    const onFilled = OrbitSemanticColors.textOnFilled;
    const ink = OrbitSemanticColors.textPrimary;
    const inkSecondary = OrbitSemanticColors.textSecondary;
    const surface = OrbitSemanticColors.surfaceDefault;
    const canvas = OrbitSemanticColors.surfaceCanvas;
    const sunken = OrbitSemanticColors.surfaceSunken;

    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onFilled,
      primaryContainer: primaryTint,
      onPrimaryContainer: primaryStrong,
      secondary: primaryStrong,
      onSecondary: onFilled,
      secondaryContainer: primaryTint,
      onSecondaryContainer: primaryStrong,
      tertiary: OrbitSemanticColors.statusSuccessFg,
      onTertiary: onFilled,
      tertiaryContainer: OrbitSemanticColors.statusSuccessTint,
      onTertiaryContainer: OrbitSemanticColors.statusSuccessStrong,
      error: OrbitSemanticColors.statusDangerFg,
      onError: onFilled,
      errorContainer: OrbitSemanticColors.statusDangerTint,
      onErrorContainer: OrbitSemanticColors.statusDangerStrong,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: inkSecondary,
      surfaceDim: sunken,
      surfaceBright: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: canvas,
      surfaceContainer: canvas,
      surfaceContainerHigh: sunken,
      surfaceContainerHighest: sunken,
      outline: OrbitSemanticColors.borderInput,
      outlineVariant: OrbitSemanticColors.borderSubtle,
      shadow: OrbitPalette.black,
      scrim: OrbitSemanticColors.surfaceScrim,
      inverseSurface: OrbitSemanticColors.surfaceInverse,
      onInverseSurface: onFilled,
      inversePrimary: primaryTint,
      surfaceTint: Colors.transparent,
    );

    final orbitColors = OrbitColors(
      success: const OrbitTone(
        fg: OrbitSemanticColors.statusSuccessFg,
        strong: OrbitSemanticColors.statusSuccessStrong,
        tint: OrbitSemanticColors.statusSuccessTint,
      ),
      warning: const OrbitTone(
        fg: OrbitSemanticColors.statusWarningFg,
        strong: OrbitSemanticColors.statusWarningStrong,
        tint: OrbitSemanticColors.statusWarningTint,
      ),
      danger: const OrbitTone(
        fg: OrbitSemanticColors.statusDangerFg,
        strong: OrbitSemanticColors.statusDangerStrong,
        tint: OrbitSemanticColors.statusDangerTint,
      ),
      info: OrbitTone(fg: primary, strong: primaryStrong, tint: primaryTint),
      severityLow: const OrbitTone(
        fg: OrbitSemanticColors.severityLowFg,
        strong: OrbitSemanticColors.severityLowStrong,
        tint: OrbitSemanticColors.severityLowTint,
      ),
      severityModerate: const OrbitTone(
        fg: OrbitSemanticColors.severityModerateFg,
        strong: OrbitSemanticColors.severityModerateStrong,
        tint: OrbitSemanticColors.severityModerateTint,
      ),
      severityHigh: const OrbitTone(
        fg: OrbitSemanticColors.severityHighFg,
        strong: OrbitSemanticColors.severityHighStrong,
        tint: OrbitSemanticColors.severityHighTint,
      ),
      textMuted: OrbitSemanticColors.textMuted,
      onPrimaryBar: OrbitSemanticColors.onPrimaryBarFg,
      onPrimaryBarFill: OrbitSemanticColors.onPrimaryBarFill,
      onPrimaryBarBorder: OrbitSemanticColors.onPrimaryBarBorder,
      highlight: OrbitSemanticColors.surfaceHighlight,
      onHighlight: OrbitSemanticColors.textOnHighlight,
      accent: OrbitSemanticColors.actionAccent,
    );

    final text = _textTheme(body: body, screenTitle: screenTitle, color: ink);
    final labelLarge = text.labelLarge!;
    const controlRadius = BorderRadius.all(Radius.circular(OrbitRadius.lg));
    const controlShape = RoundedRectangleBorder(borderRadius: controlRadius);
    const minControl = Size(OrbitSize.controlLg, OrbitSize.controlLg);
    const buttonPadding = EdgeInsets.symmetric(horizontal: OrbitSpace.s16);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: OrbitFonts.latin,
      fontFamilyFallback: OrbitFonts.fallback,
      package: OrbitFonts.package,
      textTheme: text,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: [orbitColors],
      iconTheme: const IconThemeData(color: ink, size: OrbitSize.iconLg),
      appBarTheme: AppBarThemeData(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minControl,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minControl,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: labelLarge,
          foregroundColor: primaryStrong,
          side: const BorderSide(color: OrbitSemanticColors.borderInput),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minControl,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: labelLarge,
          foregroundColor: primaryStrong,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: minControl),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: OrbitSpace.s16,
          vertical: OrbitSpace.s16,
        ),
        border: inputBorder(OrbitSemanticColors.borderInput),
        enabledBorder: inputBorder(OrbitSemanticColors.borderInput),
        focusedBorder: inputBorder(primary, 2),
        errorBorder: inputBorder(OrbitSemanticColors.statusDangerFg),
        focusedErrorBorder: inputBorder(OrbitSemanticColors.statusDangerFg, 2),
        disabledBorder: inputBorder(OrbitSemanticColors.borderSubtle),
        labelStyle: text.bodyLarge!.copyWith(color: inkSecondary),
        floatingLabelStyle: text.bodyLarge!.copyWith(color: primaryStrong),
        hintStyle: text.bodyLarge!.copyWith(
          color: OrbitSemanticColors.textMuted,
        ),
        helperStyle: text.bodySmall!.copyWith(color: inkSecondary),
        errorStyle: text.bodySmall!.copyWith(
          color: OrbitSemanticColors.statusDangerStrong,
        ),
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: controlRadius,
          side: BorderSide(color: OrbitSemanticColors.borderSubtle),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: OrbitSemanticColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: primaryTint,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: OrbitSize.iconLg,
            color: states.contains(WidgetState.selected)
                ? primaryStrong
                : inkSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelMedium!.copyWith(
                  color: primaryStrong,
                  fontWeight: OrbitFont.weightBold,
                )
              : text.labelMedium!.copyWith(color: inkSecondary),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: OrbitSemanticColors.surfaceInverse,
        contentTextStyle: text.bodyMedium!.copyWith(color: onFilled),
        actionTextColor: primaryTint,
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBarrierColor: OrbitSemanticColors.surfaceScrim,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(OrbitRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        barrierColor: OrbitSemanticColors.surfaceScrim,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(OrbitRadius.xl)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: sunken,
        circularTrackColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primaryTint,
        selectionHandleColor: primary,
      ),
    );
  }

  /// Text roles. The type scale has fewer steps than Material's 15 roles, so
  /// some roles share a step. Body roles follow the app's body size, so the
  /// default [Text] style is 16 px in the farmer app.
  static TextTheme _textTheme({
    required TextStyle body,
    required TextStyle screenTitle,
    required Color color,
  }) {
    final base = TextStyle(
      fontFamily: OrbitFonts.latin,
      fontFamilyFallback: OrbitFonts.fallback,
      package: OrbitFonts.package,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
    TextStyle s(TextStyle step) => base.merge(step);
    return TextTheme(
      displayLarge: s(OrbitTypeScale.display),
      displayMedium: s(OrbitTypeScale.display),
      displaySmall: s(OrbitTypeScale.h1),
      headlineLarge: s(OrbitTypeScale.h1),
      headlineMedium: s(screenTitle),
      headlineSmall: s(OrbitTypeScale.h2),
      titleLarge: s(OrbitTypeScale.h2),
      titleMedium: s(OrbitTypeScale.h3),
      titleSmall: s(OrbitTypeScale.labelLg),
      bodyLarge: s(OrbitTypeScale.bodyLg),
      bodyMedium: s(body),
      bodySmall: s(OrbitTypeScale.caption),
      labelLarge: s(OrbitTypeScale.labelLg),
      labelMedium: s(
        OrbitTypeScale.caption.copyWith(fontWeight: OrbitFont.weightSemibold),
      ),
      labelSmall: s(OrbitTypeScale.micro),
    );
  }
}
