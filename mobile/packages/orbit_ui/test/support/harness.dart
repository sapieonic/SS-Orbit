import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

/// Font files bundled in orbit_ui, by the family name an app sees.
const Map<String, List<String>> bundledFonts = {
  'packages/orbit_ui/Figtree': [
    'fonts/Figtree-Regular.ttf',
    'fonts/Figtree-Medium.ttf',
    'fonts/Figtree-Bold.ttf',
    'fonts/Figtree-ExtraBold.ttf',
  ],
  'packages/orbit_ui/Noto Sans Telugu': [
    'fonts/NotoSansTelugu-Regular.ttf',
    'fonts/NotoSansTelugu-Medium.ttf',
    'fonts/NotoSansTelugu-Bold.ttf',
    'fonts/NotoSansTelugu-ExtraBold.ttf',
  ],
};

bool _fontsLoaded = false;

/// Loads the real bundled fonts under the names the theme uses, so layout
/// tests measure real Telugu shaping instead of the test font's boxes.
Future<void> loadOrbitFonts() async {
  if (_fontsLoaded) return;
  for (final MapEntry(key: family, value: files) in bundledFonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File(file).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

/// Text scales every layout test runs at (Android font scale 100% and 130%).
const List<double> textScales = [1.0, 1.3];

/// The design frame: a 360 x 640 dp phone.
const Size phone = Size(360, 640);

/// Wraps [child] in an Orbit-themed Telugu app at [textScale].
Widget orbitApp(
  Widget child, {
  ThemeData? theme,
  double textScale = 1.0,
  bool scroll = true,
}) {
  return MaterialApp(
    theme: theme ?? OrbitTheme.farmer(),
    themeAnimationDuration: Duration.zero,
    locale: const Locale('te'),
    supportedLocales: const [Locale('te'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: scroll
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(OrbitSpace.s16),
              child: child,
            )
          : child,
    ),
  );
}

/// Pumps [child] on a 360 x 640 surface with real fonts.
Future<void> pumpOrbit(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  double textScale = 1.0,
  bool scroll = true,
}) async {
  await loadOrbitFonts();
  tester.view
    ..physicalSize = phone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    orbitApp(child, theme: theme, textScale: textScale, scroll: scroll),
  );
}

/// Fails if any text was cut (ellipsis or maxLines) anywhere on screen.
void expectNoClippedText(WidgetTester tester) {
  final clipped = tester.allRenderObjects
      .whereType<RenderParagraph>()
      .where((p) => p.didExceedMaxLines)
      .map((p) => p.text.toPlainText())
      .toList();
  expect(clipped, isEmpty, reason: 'text cut off: $clipped');
}

/// Registers one test per text scale that pumps [build] on the 360 x 640
/// frame with Telugu strings and checks there is no overflow (any overflow
/// error fails the test) and no clipped text.
void layoutTest(
  String description,
  Widget Function() build, {
  ThemeData Function()? theme,
}) {
  for (final scale in textScales) {
    testWidgets('$description fits 360x640 at text scale $scale', (
      tester,
    ) async {
      await pumpOrbit(tester, build(), theme: theme?.call(), textScale: scale);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
    });
  }
}
