/// The i18n source (te.json, en.json, meta.json, deny list, recordings) and
/// every check from i18n/implementation-plan.md.
library;

import 'icu.dart';

/// Placeholder types that gen-l10n understands.
const placeholderTypes = {'String', 'int', 'double', 'num', 'DateTime'};

const _metaFields = {
  'description',
  'screen',
  'max_len',
  'voice',
  'placeholders',
  'review',
  'farmer_only',
};
const _placeholderFields = {
  'type',
  'format',
  'example',
  'isCustomDateFormat',
  'optionalParameters',
};

final _keyPattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$');

/// First key segments that would clash with orbit_l10n's own extension
/// methods on OrbitLocalizations.
const _reservedSurfaces = {'label', 'describe'};

/// One placeholder declared in meta.json.
class Placeholder {
  Placeholder(this.name, this.type, this.raw);

  final String name;
  final String type;

  /// The meta.json object, copied to the ARB `@key.placeholders` entry.
  final Map<String, Object?> raw;

  /// Checked to be a string (or absent) by [readMeta].
  String? get example => raw['example'] as String?;
}

/// meta.json entry for one key.
class KeyMeta {
  KeyMeta({
    required this.description,
    required this.screen,
    required this.voice,
    required this.placeholders,
    this.maxLen,
    this.reviewPending = false,
    this.farmerOnly = false,
  });

  final String description;
  final String screen;
  final bool voice;
  final int? maxLen;
  final Map<String, Placeholder> placeholders;
  final bool reviewPending;

  /// English may be missing; the app falls back to Telugu.
  final bool farmerOnly;
}

/// Everything the generator reads.
class I18nSource {
  I18nSource({
    required this.te,
    required this.en,
    required this.meta,
    required this.denyList,
    required this.recordings,
  });

  /// Sorted i18n key -> Telugu text.
  final Map<String, String> te;

  /// i18n key -> English text.
  final Map<String, String> en;

  /// i18n key -> meta (only entries that parsed).
  final Map<String, KeyMeta> meta;

  /// Lower-cased deny-list terms.
  final List<String> denyList;

  /// Keys that have `i18n/voice/te/<key>.m4a`.
  final Set<String> recordings;

  /// Keys with `voice: true`, sorted.
  List<String> get voiceKeys => [
    for (final k in te.keys)
      if (meta[k]?.voice ?? false) k,
  ];

  /// Recorded keys that are voice keys, sorted.
  List<String> get recordedVoiceKeys => [
    for (final k in voiceKeys)
      if (recordings.contains(k)) k,
  ];
}

/// Errors fail the build; warnings are listed only.
class Report {
  final List<String> errors = [];
  final List<String> warnings = [];
}

/// Maps `farmer.home.call_fa` to `farmerHomeCallFa`.
String arbName(String key) {
  final parts = key.split(RegExp('[._]')).where((p) => p.isNotEmpty).toList();
  final b = StringBuffer(parts.first);
  for (final p in parts.skip(1)) {
    b
      ..write(p[0].toUpperCase())
      ..write(p.substring(1));
  }
  return b.toString();
}

/// Reads a string map (te.json / en.json); problems go to [report].
Map<String, String> readStrings(String file, Object? json, Report report) {
  final out = <String, String>{};
  if (json is! Map<String, Object?>) {
    report.errors.add('$file: must be a JSON object of key -> string');
    return out;
  }
  for (final e in json.entries) {
    final v = e.value;
    if (v is! String) {
      report.errors.add('$file: ${e.key}: value must be a string');
      continue;
    }
    out[e.key] = v;
  }
  return out;
}

/// Reads meta.json; problems go to [report].
Map<String, KeyMeta> readMeta(Object? json, Report report) {
  final out = <String, KeyMeta>{};
  if (json is! Map<String, Object?>) {
    report.errors.add('meta.json: must be a JSON object of key -> entry');
    return out;
  }
  for (final e in json.entries) {
    final key = e.key;
    final m = e.value;
    void bad(String msg) => report.errors.add('meta.json: $key: $msg');
    if (m is! Map<String, Object?>) {
      bad('entry must be an object');
      continue;
    }
    final unknown = m.keys.where((f) => !_metaFields.contains(f)).toList();
    if (unknown.isNotEmpty) bad('unknown field(s) ${unknown.join(', ')}');

    final description = m['description'];
    final screen = m['screen'];
    final voice = m['voice'];
    final maxLen = m['max_len'];
    final review = m['review'];
    final farmerOnly = m['farmer_only'] ?? false;
    final rawPlaceholders = m['placeholders'];
    var ok = true;
    if (description is! String || description.trim().isEmpty) {
      bad('"description" must be a non-empty string');
      ok = false;
    }
    if (screen is! String || screen.trim().isEmpty) {
      bad('"screen" must be a non-empty string');
      ok = false;
    }
    if (voice is! bool) {
      bad('"voice" must be true or false');
      ok = false;
    }
    if (maxLen != null && (maxLen is! int || maxLen <= 0)) {
      bad('"max_len" must be a positive integer');
      ok = false;
    }
    if (review != null && review != 'pending') {
      bad('"review" must be "pending" or absent');
      ok = false;
    }
    if (farmerOnly is! bool) {
      bad('"farmer_only" must be true or false');
      ok = false;
    }
    final placeholders = <String, Placeholder>{};
    if (rawPlaceholders is! Map<String, Object?>) {
      bad('"placeholders" must be an object (use {} for none)');
      ok = false;
    } else {
      for (final p in rawPlaceholders.entries) {
        final spec = p.value;
        if (spec is! Map<String, Object?>) {
          bad('placeholder ${p.key} must be an object with "type"');
          ok = false;
          continue;
        }
        final extra = spec.keys
            .where((f) => !_placeholderFields.contains(f))
            .toList();
        if (extra.isNotEmpty) {
          bad('placeholder ${p.key}: unknown field(s) ${extra.join(', ')}');
          ok = false;
        }
        final type = spec['type'];
        if (type is! String || !placeholderTypes.contains(type)) {
          bad(
            'placeholder ${p.key}: "type" must be one of '
            '${placeholderTypes.join(', ')}',
          );
          ok = false;
          continue;
        }
        final example = spec['example'];
        if (example != null && example is! String) {
          bad(
            'placeholder ${p.key}: "example" must be a string '
            '(write numbers as text, e.g. "12")',
          );
          ok = false;
          continue;
        }
        if (type == 'DateTime' && spec['format'] is! String) {
          bad('placeholder ${p.key}: DateTime needs a "format" (e.g. MMMEd)');
          ok = false;
        }
        placeholders[p.key] = Placeholder(p.key, type, spec);
      }
    }
    if (!ok) continue;
    out[key] = KeyMeta(
      description: description! as String,
      screen: screen! as String,
      voice: voice! as bool,
      maxLen: maxLen as int?,
      placeholders: placeholders,
      reviewPending: review == 'pending',
      farmerOnly: farmerOnly as bool,
    );
  }
  return out;
}

/// Parses the deny list: one term per line, `#` starts a comment.
List<String> readDenyList(String text) => [
  for (final line in text.split('\n'))
    if (line.split('#').first.trim() case final t when t.isNotEmpty)
      t.toLowerCase(),
];

/// Runs every check. [metaKeys] is every key in meta.json (including entries
/// that failed to parse, so they are not reported as missing).
void check(I18nSource src, Set<String> metaKeys, Report report) {
  final te = src.te;
  final en = src.en;

  // Key names and ARB name collisions.
  final arbNames = <String, String>{};
  for (final key in {...te.keys, ...en.keys, ...metaKeys}) {
    if (!_keyPattern.hasMatch(key)) {
      report.errors.add(
        '$key: key must be dotted snake_case '
        '(<surface>.<screen>.<element>)',
      );
      continue;
    }
    if (_reservedSurfaces.contains(key.split('.').first)) {
      report.errors.add(
        '$key: "${key.split('.').first}" is reserved for '
        'generated helpers (labelSeverity, describeError)',
      );
    }
    final name = arbName(key);
    final other = arbNames[name];
    if (other != null) {
      report.errors.add('$key: maps to "$name", same as $other');
    }
    arbNames[name] = key;
  }

  // Same key sets.
  for (final key in te.keys) {
    if (!metaKeys.contains(key)) {
      report.errors.add('$key: in te.json but missing from meta.json');
    }
    if (!en.containsKey(key) && !(src.meta[key]?.farmerOnly ?? false)) {
      report.errors.add(
        '$key: missing from en.json '
        '(set "farmer_only": true in meta to fall back to Telugu)',
      );
    }
  }
  for (final key in en.keys) {
    if (!te.containsKey(key)) {
      report.errors.add('$key: in en.json but missing from te.json');
    }
  }
  for (final key in metaKeys) {
    if (!te.containsKey(key)) {
      report.errors.add('$key: in meta.json but missing from te.json');
    }
  }

  for (final key in te.keys) {
    final meta = src.meta[key];
    if (meta == null) continue;
    final declared = meta.placeholders.keys.toSet();
    final values = {'te': te[key]!, if (en.containsKey(key)) 'en': en[key]!};

    if (te[key]!.trim().isEmpty) {
      report.errors.add('$key: Telugu text is empty');
    }
    if (en.containsKey(key) && en[key]!.trim().isEmpty) {
      report.errors.add('$key: English text is empty');
    }

    for (final MapEntry(key: lang, value: text) in values.entries) {
      final IcuMessage msg;
      try {
        msg = parseIcu(text, argLength: (name) => _argLength(meta, name));
      } on IcuSyntaxError catch (e) {
        report.errors.add('$key ($lang): ICU syntax: $e');
        continue;
      }
      final used = msg.names;
      if (used.length != declared.length || !used.containsAll(declared)) {
        report.errors.add(
          '$key ($lang): placeholders {${used.join(', ')}} '
          'do not match meta {${declared.join(', ')}}',
        );
      }
      for (final arg in msg.args) {
        final type = meta.placeholders[arg.name]?.type;
        // The same type rules as flutter gen-l10n.
        final wanted = switch (arg.kind) {
          'plural' => const {'int', 'num'},
          'select' => const {'String'},
          'date' || 'time' => const {'DateTime'},
          _ => null,
        };
        if (type != null && wanted != null && !wanted.contains(type)) {
          report.errors.add(
            '$key: {${arg.name}} is a ${arg.kind}, so its type '
            'must be ${wanted.join(' or ')}',
          );
        }
      }
      final max = meta.maxLen;
      if (max != null && msg.maxLength > max) {
        report.errors.add(
          '$key ($lang): ${msg.maxLength} characters, '
          'max_len is $max',
        );
      }
      _checkDenyList(key, lang, text, src.denyList, report);
    }

    if (meta.voice && declared.isNotEmpty) {
      report.errors.add(
        '$key: voice prompts are recorded once, so they '
        'cannot have placeholders',
      );
    }
    _checkSurfaceRules(key, meta, report);
  }

  // Recordings.
  for (final key in src.voiceKeys) {
    if (!src.recordings.contains(key)) {
      report.warnings.add(
        '$key: voice prompt not recorded yet '
        '(i18n/voice/te/$key.m4a)',
      );
    }
  }
  for (final key in src.recordings) {
    if (!(src.meta[key]?.voice ?? false)) {
      report.warnings.add(
        'i18n/voice/te/$key.m4a: not a voice key, '
        'not bundled',
      );
    }
  }
}

int _argLength(KeyMeta meta, String name) {
  final p = meta.placeholders[name];
  final example = p?.example;
  if (example != null) return example.runes.length;
  return switch (p?.type) {
    'DateTime' => 12,
    'int' || 'num' || 'double' => 3,
    _ => 8,
  };
}

void _checkSurfaceRules(String key, KeyMeta meta, Report report) {
  final parts = key.split('.');
  if (parts.first == 'enum') {
    if (parts.length != 3) {
      report.errors.add('$key: enum keys are enum.<schema>.<value>');
    }
    if (meta.placeholders.isNotEmpty) {
      report.errors.add('$key: enum labels cannot have placeholders');
    }
  } else if (parts.first == 'error') {
    if (parts.length == 3 && parts[1] == 'detail') {
      final types = meta.placeholders.values.map((p) => p.type).toList();
      if (types.length != 1 || !{'int', 'num', 'String'}.contains(types[0])) {
        report.errors.add(
          '$key: error.detail.* needs exactly one int, num '
          'or String placeholder (the details value)',
        );
      }
    } else if (parts.length != 2) {
      report.errors.add(
        '$key: error keys are error.<code> or '
        'error.detail.<details_field>',
      );
    } else if (meta.placeholders.isNotEmpty) {
      report.errors.add(
        '$key: error.<code> cannot have placeholders; '
        'add an error.detail.<field> key instead',
      );
    }
  }
}

final _latinTerm = RegExp(r'^[\x00-\x7F]+$');

void _checkDenyList(
  String key,
  String lang,
  String text,
  List<String> terms,
  Report report,
) {
  final lower = text.toLowerCase();
  for (final term in terms) {
    final hit = _latinTerm.hasMatch(term)
        ? RegExp('(^|[^a-z0-9])${RegExp.escape(term)}(\$|[^a-z0-9])')
              .hasMatch(lower)
        : lower.contains(term);
    if (hit) {
      report.errors.add('$key ($lang): contains deny-listed term "$term"');
    }
  }
}
