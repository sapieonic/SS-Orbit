@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Finds the Dart SDK that ships with the Flutter running this test.
String _dart() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = [
    if (flutterRoot != null) '$flutterRoot/bin/cache/dart-sdk/bin/dart',
  ];
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    candidates.add('${dir.path}/dart-sdk/bin/dart');
    dir = dir.parent;
  }
  return candidates.firstWhere(
    (path) => File(path).existsSync(),
    orElse: () => 'dart',
  );
}

void main() {
  test('generated tokens are up to date (tools/tokens/build.dart --check)', () {
    // flutter test runs from mobile/packages/orbit_ui.
    final repoRoot = Directory('../../..').absolute.path;
    final result = Process.runSync(_dart(), [
      'run',
      'tools/tokens/build.dart',
      '--check',
    ], workingDirectory: repoRoot);
    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
