// i18n generator: i18n/{te,en,meta}.json -> orbit_l10n ARB files, voice key
// map, error/enum lookups, and bundled voice prompts for orbit_voice.
//
//   dart run tools/i18n/build.dart           # check, then write outputs
//   dart run tools/i18n/build.dart --check   # check; exit 1 if outputs are stale
//
// Plain Dart, no packages. Paths resolve from this script's location, so it
// works from any directory (melos runs it from mobile/). See README.md.

import 'dart:convert';
import 'dart:io';

import 'src/emit.dart';
import 'src/model.dart';

const _usage = '''
Usage: dart run tools/i18n/build.dart [--check] [--root <repo>]

  --check        Run the checks and exit 1 if any generated file is stale.
                 Writes nothing.
  --root <dir>   Repository root (default: two levels above this script).
''';

/// Generated file paths, relative to the repo root.
const _l10nDir = 'mobile/packages/orbit_l10n/lib';
const _l10nTestDir = 'mobile/packages/orbit_l10n/test';
const _voiceSrcDir = 'i18n/voice/te';
const _voiceOutDir = 'mobile/packages/orbit_voice/assets/voice/te';

Future<void> main(List<String> args) async {
  exitCode = await run(args);
}

Future<int> run(List<String> args) async {
  var checkOnly = false;
  String? rootArg;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--check':
        checkOnly = true;
      case '--root' when i + 1 < args.length:
        rootArg = args[++i];
      case '-h' || '--help':
        stdout.write(_usage);
        return 0;
      default:
        stderr.write('Unknown argument: ${args[i]}\n$_usage');
        return 2;
    }
  }

  final root = Directory(
    rootArg ?? File.fromUri(Platform.script).parent.parent.parent.path,
  ).absolute;
  if (!File(_p(root, 'i18n/te.json')).existsSync()) {
    stderr.writeln('i18n/te.json not found under ${root.path}; pass --root.');
    return 2;
  }

  final report = Report();
  final sourceFiles = <String, Object?>{};
  for (final name in ['te.json', 'en.json', 'meta.json']) {
    final file = File(_p(root, 'i18n/$name'));
    try {
      sourceFiles[name] = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      report.errors.add('i18n/$name: not valid JSON: ${e.message}');
    } on FileSystemException catch (e) {
      report.errors.add('i18n/$name: ${e.message}');
    }
  }
  if (report.errors.isNotEmpty) return _finish(report, const []);

  final te = readStrings('te.json', sourceFiles['te.json'], report);
  final en = readStrings('en.json', sourceFiles['en.json'], report);
  final metaJson = sourceFiles['meta.json'];
  final meta = readMeta(metaJson, report);
  final metaKeys = metaJson is Map<String, Object?>
      ? metaJson.keys.toSet()
      : <String>{};

  final denyFile = File(_p(root, 'i18n/deny-list.txt'));
  final denyList = denyFile.existsSync()
      ? readDenyList(denyFile.readAsStringSync())
      : <String>[];
  if (!denyFile.existsSync()) {
    report.warnings.add('i18n/deny-list.txt not found; brand check skipped');
  }

  final voiceSrc = Directory(_p(root, _voiceSrcDir));
  final recordings = <String, File>{};
  if (voiceSrc.existsSync()) {
    for (final f in voiceSrc.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.m4a')) {
        recordings[name.substring(0, name.length - 4)] = f;
      }
    }
  }

  final sortedKeys = te.keys.toList()..sort();
  final src = I18nSource(
    te: {for (final k in sortedKeys) k: te[k]!},
    en: en,
    meta: meta,
    denyList: denyList,
    recordings: recordings.keys.toSet(),
  );
  check(src, metaKeys, report);
  if (report.errors.isNotEmpty) return _finish(report, const []);

  // Everything the generator owns: path -> bytes.
  final outputs = <String, List<int>>{
    // Source files are rewritten sorted and canonically formatted.
    'i18n/te.json': utf8.encode(canonicalJson(sourceFiles['te.json'])),
    'i18n/en.json': utf8.encode(canonicalJson(sourceFiles['en.json'])),
    'i18n/meta.json': utf8.encode(canonicalJson(sourceFiles['meta.json'])),
    '$_l10nDir/l10n/app_te.arb': utf8.encode(arb(src, 'te')),
    '$_l10nDir/l10n/app_en.arb': utf8.encode(arb(src, 'en')),
    '$_l10nDir/src/voice_keys.g.dart': await _formatDart(voiceKeysDart(src)),
    '$_l10nDir/src/lookups.g.dart': await _formatDart(lookupsDart(src)),
    '$_l10nTestDir/all_messages.g.dart': await _formatDart(
      allMessagesTestDart(src),
    ),
    '$_voiceOutDir/.gitkeep': const <int>[],
    for (final k in src.recordedVoiceKeys)
      '$_voiceOutDir/$k.m4a': recordings[k]!.readAsBytesSync(),
  };
  // Bundled prompts that no longer have a source recording.
  final outDir = Directory(_p(root, _voiceOutDir));
  final stale = <String>[
    if (outDir.existsSync())
      for (final f in outDir.listSync().whereType<File>())
        if (f.uri.pathSegments.last.endsWith('.m4a') &&
            !outputs.containsKey('$_voiceOutDir/${f.uri.pathSegments.last}'))
          '$_voiceOutDir/${f.uri.pathSegments.last}',
  ];

  final changed = <String>[
    for (final MapEntry(key: path, value: bytes) in outputs.entries)
      if (!_sameBytes(File(_p(root, path)), bytes)) path,
  ];

  if (checkOnly) {
    for (final path in changed) {
      report.errors.add('$path is stale; run `melos run gen:l10n`');
    }
    for (final path in stale) {
      report.errors.add(
        '$path has no source recording; run '
        '`melos run gen:l10n`',
      );
    }
    return _finish(report, const []);
  }

  for (final path in changed) {
    final file = File(_p(root, path));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(outputs[path]!);
  }
  for (final path in stale) {
    File(_p(root, path)).deleteSync();
  }
  return _finish(report, [
    '${src.te.length} keys, ${src.voiceKeys.length} voice prompts '
        '(${src.recordedVoiceKeys.length} recorded), '
        '${meta.values.where((m) => m.reviewPending).length} Telugu strings '
        'pending review.',
    if (changed.isEmpty && stale.isEmpty) 'Generated files are up to date.',
    for (final path in changed) 'wrote $path',
    for (final path in stale) 'removed $path',
  ]);
}

/// Runs `dart format` (the SDK running this script, pinned by FVM) so the
/// generated Dart matches what `dart format .` would leave in the repo.
Future<List<int>> _formatDart(String source) async {
  final process = await Process.start(Platform.resolvedExecutable, [
    'format',
    '--stdin-name=generated.dart',
    '--output=show',
  ]);
  process.stdin.add(utf8.encode(source));
  await process.stdin.close();
  final out = process.stdout.fold<List<int>>([], (a, b) => a..addAll(b));
  final err = process.stderr.transform(utf8.decoder).join();
  if (await process.exitCode != 0) {
    throw StateError('dart format failed on generated code:\n${await err}');
  }
  return out;
}

String _p(Directory root, String relative) =>
    '${root.path}${Platform.pathSeparator}'
    '${relative.replaceAll('/', Platform.pathSeparator)}';

bool _sameBytes(File file, List<int> bytes) {
  if (!file.existsSync()) return false;
  final current = file.readAsBytesSync();
  if (current.length != bytes.length) return false;
  for (var i = 0; i < bytes.length; i++) {
    if (current[i] != bytes[i]) return false;
  }
  return true;
}

int _finish(Report report, List<String> info) {
  if (report.warnings.isNotEmpty) {
    stdout.writeln('i18n: ${report.warnings.length} warning(s):');
    for (final w in report.warnings) {
      stdout.writeln('  warning: $w');
    }
  }
  for (final line in info) {
    stdout.writeln('i18n: $line');
  }
  if (report.errors.isNotEmpty) {
    stderr.writeln('i18n: ${report.errors.length} error(s):');
    for (final e in report.errors) {
      stderr.writeln('  error: $e');
    }
    return 1;
  }
  return 0;
}
