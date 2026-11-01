import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'support/harness.dart';

double _width(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadOrbitFonts);

  test('declared font files and licences exist and stay small', () {
    var total = 0;
    for (final files in bundledFonts.values) {
      for (final path in files) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        total += file.lengthSync();
      }
    }
    expect(File('fonts/OFL-Figtree.txt').existsSync(), isTrue);
    expect(File('fonts/OFL-NotoSansTelugu.txt').existsSync(), isTrue);
    // Keep the farmer APK under its 20 MB target: fonts stay under 1.2 MB.
    expect(total, lessThan(1200 * 1024));
  });

  test('Telugu renders with the bundled Noto Sans Telugu via fallback', () {
    const telugu = 'నమస్కారం, రవి';
    final style = OrbitTheme.farmer().textTheme.bodyMedium!;
    final real = _width(telugu, style);
    final testFont = _width(
      telugu,
      const TextStyle(fontFamily: 'not-loaded', fontSize: 16),
    );
    // The test font draws every code point as a 1 em box; real shaping
    // merges conjuncts and vowel signs, so the widths differ.
    expect(real, isNot(closeTo(testFont, 0.5)));
    expect(real, greaterThan(0));
  });

  for (final family in bundledFonts.keys) {
    test('$family: 400, 500, 700 and 800 are distinct; 600 uses 700', () {
      final sample = family.endsWith('Telugu')
          ? 'సురేష్‌కు కాల్ చేయండి'
          : 'Call Suresh 0123456789';
      double w(FontWeight weight) => _width(
        sample,
        TextStyle(fontFamily: family, fontSize: 40, fontWeight: weight),
      );
      final widths = [
        w(FontWeight.w400),
        w(FontWeight.w500),
        w(FontWeight.w700),
        w(FontWeight.w800),
      ];
      expect(widths.toSet(), hasLength(4), reason: '$widths');
      expect(w(FontWeight.w600), widths[2]);
    });
  }

  // design/fonts/ holds the source files; orbit_ui/fonts/ ships copies. Any
  // change must land in both, byte for byte. Skipped when this package is
  // used outside the Orbit repo (no design/ next to mobile/).
  final designFonts = Directory('../../../design/fonts');
  test('every file in fonts/ matches its source in design/fonts/', () {
    const familyDirs = {
      'Figtree': 'figtree',
      'NotoSansTelugu': 'noto-sans-telugu',
    };
    final shipped = Directory('fonts').listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(shipped, isNotEmpty);
    for (final file in shipped) {
      final name = file.uri.pathSegments.last;
      // OFL-Figtree.txt <- figtree/OFL.txt; Figtree-Bold.ttf <- figtree/.
      final licence = name.startsWith('OFL-') && name.endsWith('.txt');
      final family = licence
          ? name.substring('OFL-'.length, name.length - '.txt'.length)
          : name.split('-').first;
      final dir = familyDirs[family];
      expect(dir, isNotNull, reason: 'no design/fonts/ folder for $name');
      final source = File(
        '${designFonts.path}/$dir/${licence ? 'OFL.txt' : name}',
      );
      expect(source.existsSync(), isTrue, reason: '${source.path} missing');
      expect(
        listEquals(file.readAsBytesSync(), source.readAsBytesSync()),
        isTrue,
        reason: 'fonts/$name differs from ${source.path}: copy it again',
      );
    }
  }, skip: designFonts.existsSync() ? false : 'design/fonts/ not found');

  testWidgets('registerLicenses adds both OFL texts', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List()));
        const prefix = 'packages/orbit_ui/';
        if (!key.startsWith(prefix)) return null;
        final bytes = File(key.substring(prefix.length)).readAsBytesSync();
        return ByteData.sublistView(bytes);
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );
    OrbitFonts.registerLicenses();
    final entries = await tester.runAsync(
      () => LicenseRegistry.licenses.toList(),
    );
    final packages = entries!.expand((e) => e.packages).toSet();
    expect(packages, containsAll(['Figtree', 'Noto Sans Telugu']));
  });
}
