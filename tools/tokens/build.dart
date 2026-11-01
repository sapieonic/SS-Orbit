// Orbit design-token generator.
//
// Reads the W3C DTCG token files in design/tokens/ and writes the generated
// code for each client. Plain Dart, no packages, deterministic output.
//
//   dart run tools/tokens/build.dart            # from the repo root
//   dart run ../tools/tokens/build.dart         # from mobile/ (melos gen:tokens)
//   dart run tools/tokens/build.dart --check    # exit 1 if any output is stale
//
// Exit codes: 0 ok, 1 stale output (--check), 2 invalid tokens or usage.
//
// To add an output (for example CSS custom properties for web/), implement
// [TokenFormat] and add it to [formats]. See tools/tokens/README.md.

import 'dart:convert';
import 'dart:io';

/// Token files, relative to design/tokens/, in load order. Files under apps/
/// are namespaced by their basename: `primary.base` in apps/farmer.json is the
/// token `farmer.primary.base`.
const List<String> sources = [
  'base.json',
  'semantic.json',
  'apps/farmer.json',
  'apps/fa.json',
];

/// Every output this generator writes.
const List<TokenFormat> formats = [DartFormat()];

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final unknown = args.where((a) => a != '--check').toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown arguments: ${unknown.join(' ')}');
    stderr.writeln('Usage: dart run tools/tokens/build.dart [--check]');
    exit(2);
  }

  final root = findRepoRoot();
  final TokenSet tokens;
  try {
    tokens = TokenSet.load(Directory('${root.path}/design/tokens'), sources);
  } on TokenError catch (e) {
    stderr.writeln('design/tokens: $e');
    exit(2);
  }

  var stale = false;
  for (final format in formats) {
    final String output;
    try {
      output = format.render(tokens);
    } on TokenError catch (e) {
      stderr.writeln('${format.outputPath}: $e');
      exit(2);
    }
    final file = File('${root.path}/${format.outputPath}');
    final current = file.existsSync() ? file.readAsStringSync() : null;
    if (current == output) {
      stdout.writeln('up to date  ${format.outputPath}');
    } else if (check) {
      stale = true;
      stderr.writeln('STALE       ${format.outputPath}');
    } else {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(output);
      stdout.writeln('wrote       ${format.outputPath}');
    }
  }
  if (stale) {
    stderr.writeln(
      'Generated token code is out of date. Run `melos run gen:tokens` '
      '(or `dart run tools/tokens/build.dart` from the repo root) and commit.',
    );
    exit(1);
  }
}

/// The repo root: two levels above this script (tools/tokens/build.dart).
Directory findRepoRoot() {
  final script = File.fromUri(Platform.script);
  final root = script.parent.parent.parent;
  if (!Directory('${root.path}/design/tokens').existsSync()) {
    stderr.writeln('Cannot find design/tokens/ above ${script.path}');
    exit(2);
  }
  return root;
}

/// A problem in the token files or in an output mapping.
class TokenError implements Exception {
  TokenError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One resolved token.
class Token {
  Token({
    required this.path,
    required this.type,
    required this.value,
    required this.description,
    required this.alias,
  });

  /// Dot path, e.g. `color.green.base` or `farmer.primary.base`.
  final String path;

  /// DTCG `$type`: color, dimension, number, fontFamily, fontWeight,
  /// typography or shadow.
  final String type;

  /// Resolved value: a [ColorValue], [num], [String], [TypographyValue] or a
  /// list of [ShadowValue].
  final Object value;

  final String? description;

  /// The reference this token was defined as (`{color.ink}`), if any.
  final String? alias;
}

/// An sRGB colour with alpha.
class ColorValue {
  ColorValue(this.argb);

  /// Parses `#RRGGBB` or `#RRGGBBAA` (CSS order: alpha last).
  factory ColorValue.parse(String hex, String path) {
    final m = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$').firstMatch(hex);
    if (m == null) {
      throw TokenError('$path: colour "$hex" must be #RRGGBB or #RRGGBBAA');
    }
    final rgb = int.parse(m.group(1)!, radix: 16);
    final a = m.group(2) == null ? 0xFF : int.parse(m.group(2)!, radix: 16);
    return ColorValue((a << 24) | rgb);
  }

  final int argb;

  String get dartHex =>
      '0x${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';
}

class TypographyValue {
  TypographyValue({
    required this.fontSize,
    required this.fontWeight,
    required this.lineHeight,
    required this.letterSpacing,
  });
  final num fontSize;
  final int fontWeight;
  final num lineHeight;
  final num letterSpacing;
}

class ShadowValue {
  ShadowValue({
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.blur,
    required this.spread,
  });
  final ColorValue color;
  final num offsetX;
  final num offsetY;
  final num blur;
  final num spread;
}

/// All tokens from all source files, resolved, in source order.
class TokenSet {
  TokenSet._(this.tokens);

  final List<Token> tokens;

  static final RegExp _ref = RegExp(r'^\{([^{}]+)\}$');

  static TokenSet load(Directory dir, List<String> files) {
    final raw = <String, _RawToken>{};
    for (final name in files) {
      final file = File('${dir.path}/$name');
      if (!file.existsSync()) throw TokenError('missing file $name');
      final Object? json;
      try {
        json = jsonDecode(file.readAsStringSync());
      } on FormatException catch (e) {
        throw TokenError('$name: invalid JSON: ${e.message}');
      }
      if (json is! Map<String, Object?>) {
        throw TokenError('$name: top level must be an object');
      }
      final prefix = name.startsWith('apps/')
          ? [name.substring(5, name.length - 5)]
          : <String>[];
      _walk(json, prefix, null, name, raw);
    }

    final resolved = <String, Token>{};
    Token resolve(String path, List<String> stack) {
      final done = resolved[path];
      if (done != null) return done;
      final rawToken = raw[path];
      if (rawToken == null) {
        throw TokenError(
          '${stack.isEmpty ? path : stack.last}: unknown reference {$path}',
        );
      }
      if (stack.contains(path)) {
        throw TokenError(
          'circular reference: ${[...stack, path].join(' -> ')}',
        );
      }
      final next = [...stack, path];
      Object? deref(Object? v) {
        if (v is String) {
          final m = _ref.firstMatch(v);
          if (m != null) return resolve(m.group(1)!, next).value;
        }
        return v;
      }

      final type = rawToken.type;
      final v = rawToken.value;
      final alias = v is String && _ref.hasMatch(v) ? v : null;
      final Object value;
      if (alias != null) {
        final target = resolve(_ref.firstMatch(alias)!.group(1)!, next);
        if (target.type != type) {
          throw TokenError(
            '$path (\$type $type) references ${target.path} '
            '(\$type ${target.type})',
          );
        }
        value = target.value;
      } else {
        value = _parse(type, v, path, deref);
      }
      return resolved[path] = Token(
        path: path,
        type: type,
        value: value,
        description: rawToken.description,
        alias: alias,
      );
    }

    return TokenSet._([for (final path in raw.keys) resolve(path, const [])]);
  }

  static void _walk(
    Map<String, Object?> node,
    List<String> path,
    String? inheritedType,
    String file,
    Map<String, _RawToken> out,
  ) {
    final type = node[r'$type'] as String? ?? inheritedType;
    if (node.containsKey(r'$value')) {
      final p = path.join('.');
      if (type == null) throw TokenError('$file: $p has no \$type');
      if (out.containsKey(p)) throw TokenError('$file: $p is defined twice');
      out[p] = _RawToken(
        type,
        node[r'$value'],
        node[r'$description'] as String?,
      );
      return;
    }
    for (final entry in node.entries) {
      if (entry.key.startsWith(r'$')) continue;
      final child = entry.value;
      if (child is! Map<String, Object?>) {
        throw TokenError(
          '$file: ${[...path, entry.key].join('.')} '
          'must be a group or a token (object with \$value)',
        );
      }
      _walk(child, [...path, entry.key], type, file, out);
    }
  }

  static Object _parse(
    String type,
    Object? v,
    String path,
    Object? Function(Object?) deref,
  ) {
    num number(Object? x, String what) {
      final d = deref(x);
      if (d is num) return d;
      if (d is String) {
        final m = RegExp(r'^(-?[0-9.]+)px$').firstMatch(d);
        if (m != null) return num.parse(m.group(1)!);
      }
      throw TokenError('$path: $what must be a number, got $d');
    }

    switch (type) {
      case 'color':
        final d = deref(v);
        if (d is ColorValue) return d;
        if (d is String) return ColorValue.parse(d, path);
        throw TokenError('$path: colour must be a hex string');
      case 'dimension':
      case 'number':
        return number(v, 'value');
      case 'fontFamily':
        final d = deref(v);
        if (d is String) return d;
        throw TokenError('$path: fontFamily must be a string');
      case 'fontWeight':
        final w = number(v, 'fontWeight');
        if (w is! int || w < 100 || w > 900 || w % 100 != 0) {
          throw TokenError(
            '$path: fontWeight must be 100..900 in steps of 100',
          );
        }
        return w;
      case 'typography':
        if (v is! Map<String, Object?>) {
          throw TokenError('$path: typography value must be an object');
        }
        final weight = number(v['fontWeight'], 'fontWeight');
        if (weight is! int)
          throw TokenError('$path: fontWeight must be an int');
        return TypographyValue(
          fontSize: number(v['fontSize'], 'fontSize'),
          fontWeight: weight,
          lineHeight: number(v['lineHeight'], 'lineHeight'),
          letterSpacing: number(v['letterSpacing'] ?? 0, 'letterSpacing'),
        );
      case 'shadow':
        final layers = v is List ? v : [v];
        return [
          for (final layer in layers)
            if (layer is Map<String, Object?>)
              ShadowValue(
                color:
                    _parse('color', layer['color'], path, deref) as ColorValue,
                offsetX: number(layer['offsetX'], 'offsetX'),
                offsetY: number(layer['offsetY'], 'offsetY'),
                blur: number(layer['blur'], 'blur'),
                spread: number(layer['spread'] ?? 0, 'spread'),
              )
            else
              throw TokenError('$path: each shadow layer must be an object'),
        ];
      default:
        throw TokenError('$path: unsupported \$type "$type"');
    }
  }
}

class _RawToken {
  _RawToken(this.type, this.value, this.description);
  final String type;
  final Object? value;
  final String? description;
}

/// One generated output. Implement this to add a platform (CSS, TS, ...).
abstract interface class TokenFormat {
  /// Output file, relative to the repo root.
  String get outputPath;

  /// The full file contents. Must be deterministic.
  String render(TokenSet tokens);
}

/// A Dart class that holds the tokens under some top-level groups.
class DartClass {
  const DartClass(this.name, this.groups, this.doc, {this.stripGroup = true});

  final String name;

  /// Top-level token groups (first path segment) that go in this class.
  final List<String> groups;

  final String doc;

  /// Drop the group name from member names (`color.ink` -> `ink`). Only
  /// valid with a single group.
  final bool stripGroup;
}

/// Writes mobile/packages/orbit_ui/lib/src/tokens/orbit_tokens.g.dart.
class DartFormat implements TokenFormat {
  const DartFormat();

  @override
  String get outputPath =>
      'mobile/packages/orbit_ui/lib/src/tokens/orbit_tokens.g.dart';

  static const List<DartClass> classes = [
    DartClass(
      'OrbitPalette',
      ['color'],
      'Raw palette (design/tokens/base.json `color`). '
          'Widgets read colours from the theme, not from here.',
    ),
    DartClass('OrbitFont', [
      'font',
    ], 'Font families, weights and line heights.'),
    DartClass('OrbitTypeScale', [
      'type',
    ], 'Type scale. Family and colour are added by the theme.'),
    DartClass('OrbitSpace', ['space'], 'Spacing scale in logical pixels.'),
    DartClass('OrbitRadius', ['radius'], 'Corner radii in logical pixels.'),
    DartClass('OrbitSize', [
      'size',
    ], 'Control, icon, avatar and frame sizes in logical pixels.'),
    DartClass('OrbitElevation', ['elevation'], 'Shadows.'),
    DartClass(
      'OrbitSemanticColors',
      [
        'text',
        'surface',
        'border',
        'status',
        'severity',
        'action',
        'on-primary-bar',
      ],
      'Semantic colours (design/tokens/semantic.json), the same in every app.',
      stripGroup: false,
    ),
    DartClass('OrbitFarmerTokens', [
      'farmer',
    ], 'Farmer app overrides (design/tokens/apps/farmer.json).'),
    DartClass('OrbitFaTokens', [
      'fa',
    ], 'FA app overrides (design/tokens/apps/fa.json).'),
  ];

  @override
  String render(TokenSet tokens) {
    final byGroup = <String, List<Token>>{};
    for (final t in tokens.tokens) {
      byGroup.putIfAbsent(t.path.split('.').first, () => []).add(t);
    }
    final mapped = {for (final c in classes) ...c.groups};
    final unmapped = byGroup.keys.where((g) => !mapped.contains(g)).toList();
    if (unmapped.isNotEmpty) {
      throw TokenError(
        'no Dart class for token groups: ${unmapped.join(', ')}. '
        'Add them to DartFormat.classes in tools/tokens/build.dart.',
      );
    }

    final out = StringBuffer()
      ..writeln('// GENERATED by tools/tokens/build.dart from design/tokens/.')
      ..writeln(
        '// Do not edit. Change the JSON and run `melos run gen:tokens`.',
      )
      ..writeln()
      ..writeln("import 'package:flutter/painting.dart';");

    for (final c in classes) {
      if (c.stripGroup && c.groups.length != 1) {
        throw TokenError('${c.name}: stripGroup needs exactly one group');
      }
      out
        ..writeln()
        ..writeln('/// ${c.doc}')
        ..writeln('abstract final class ${c.name} {');
      final names = <String>{};
      var first = true;
      for (final group in c.groups) {
        for (final t in byGroup[group] ?? const <Token>[]) {
          final segments = t.path.split('.');
          final name = _memberName(c.stripGroup ? segments.skip(1) : segments);
          if (!names.add(name)) {
            throw TokenError('${c.name}.$name is produced by two tokens');
          }
          if (!first) out.writeln();
          first = false;
          _writeDoc(out, t);
          out.write(_declaration(name, t));
        }
      }
      out.writeln('}');
    }
    return out.toString();
  }

  /// `['green', 'base']` -> `green`, `['ink-2']` -> `ink2`,
  /// `['line-height', 'body']` -> `lineHeightBody`, `['16']` -> `s16`.
  static String _memberName(Iterable<String> segments) {
    final words = <String>[
      for (final s in segments)
        if (s != 'base') ...s.split('-').where((w) => w.isNotEmpty),
    ];
    final buf = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      buf.write(i == 0 ? w : w[0].toUpperCase() + w.substring(1));
    }
    final name = buf.toString();
    return RegExp('^[0-9]').hasMatch(name) ? 's$name' : name;
  }

  static void _writeDoc(StringBuffer out, Token t) {
    final description = t.description;
    if (description != null) {
      // One `///` line per source line, so a newline cannot end the comment.
      for (final line in description.split(RegExp(r'\r?\n'))) {
        out.writeln(
          line.trim().isEmpty ? '  ///' : '  /// ${line.trimRight()}',
        );
      }
      out.writeln('  ///');
    }
    final alias = t.alias == null ? '' : ' = `${t.alias}`';
    out.writeln('  /// Token `${t.path}`$alias.');
  }

  /// A single-quoted Dart string literal (same escaping as tools/i18n, plus
  /// control characters).
  static String _dartString(String s) {
    final escaped = s
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return "'$escaped'";
  }

  static String _num(num n) =>
      n == n.roundToDouble() ? n.round().toString() : n.toString();

  static String _declaration(String name, Token t) {
    final v = t.value;
    switch (t.type) {
      case 'color':
        return _fit(
          '  static const Color $name = ',
          'Color(${(v as ColorValue).dartHex});',
        );
      case 'dimension':
      case 'number':
        return _fit('  static const double $name = ', '${_num(v as num)};');
      case 'fontFamily':
        return _fit(
          '  static const String $name = ',
          '${_dartString(v as String)};',
        );
      case 'fontWeight':
        return _fit('  static const FontWeight $name = ', 'FontWeight.w$v;');
      case 'typography':
        final s = v as TypographyValue;
        return _call('  static const TextStyle $name = ', 'TextStyle', [
          'fontSize: ${_num(s.fontSize)}',
          'fontWeight: FontWeight.w${s.fontWeight}',
          'height: ${_num(s.lineHeight)}',
          'letterSpacing: ${_num(s.letterSpacing)}',
        ]);
      case 'shadow':
        final layers = [
          for (final s in v as List<ShadowValue>)
            [
              'color: Color(${s.color.dartHex})',
              'offset: Offset(${_num(s.offsetX)}, ${_num(s.offsetY)})',
              'blurRadius: ${_num(s.blur)}',
              if (s.spread != 0) 'spreadRadius: ${_num(s.spread)}',
            ],
        ];
        final head = '  static const List<BoxShadow> $name = ';
        final flat = [for (final l in layers) 'BoxShadow(${l.join(', ')})'];
        final oneLine = '$head[${flat.join(', ')}];';
        if (oneLine.length <= 80) return '$oneLine\n';
        final body = StringBuffer();
        for (var i = 0; i < layers.length; i++) {
          if ('    ${flat[i]},'.length <= 80) {
            body.writeln('    ${flat[i]},');
          } else {
            body
              ..writeln('    BoxShadow(')
              ..writeAll(layers[i].map((a) => '      $a,\n'))
              ..writeln('    ),');
          }
        }
        return '$head[\n$body  ];\n';
      default:
        throw TokenError('${t.path}: no Dart mapping for \$type ${t.type}');
    }
  }

  /// One line if it fits in 80 columns, else break after `=` (dart format).
  static String _fit(String head, String value) {
    final line = '$head$value';
    if (line.length <= 80) return '$line\n';
    return '${head.trimRight()}\n      $value\n';
  }

  /// A constructor call, one line if it fits, else one argument per line.
  static String _call(String head, String ctor, List<String> args) {
    final line = '$head$ctor(${args.join(', ')});';
    if (line.length <= 80) return '$line\n';
    return '$head$ctor(\n${args.map((a) => '    $a,\n').join()}  );\n';
  }
}
