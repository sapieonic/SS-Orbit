/// A small ICU MessageFormat reader: just enough to list a message's arguments,
/// check its syntax and estimate its longest rendered length.
///
/// Supported syntax is what Flutter gen-l10n's parser accepts
/// (flutter_tools/lib/src/localizations/message_parser.dart), so a message that
/// passes here does not fail later in `flutter gen-l10n`:
/// `{name}`, `{name, date, ::skeleton}`, `{name, time, ::skeleton}`,
/// `{name, plural, =0{...} one{...} other{...}}` (cases zero, one, two, few,
/// many, other, =0, =1 or =2) and `{name, select, a{...} other{...}}`.
/// `{name, number}`, styles such as `{name, date, short}`, `selectordinal`,
/// `offset:`, other `=N` cases and `#` inside a plural are rejected: gen-l10n
/// does not support them (it would print `#` as is). Format numbers
/// and dates through the placeholder's `format` in meta.json instead. Quotes
/// are literal text (gen-l10n `use-escaping: false`, the default).
library;

/// One argument used in a message.
class IcuArg {
  IcuArg(this.name, this.kind);

  /// Placeholder name, e.g. `count`.
  final String name;

  /// `simple` for `{name}`, otherwise the ICU type (`plural`, `select`, ...).
  final String kind;

  bool get isChoice => kind == 'plural' || kind == 'select';
}

/// The result of reading one message.
class IcuMessage {
  IcuMessage(this.args, this.maxLength);

  /// Every argument, in order of first use (an argument may appear twice).
  final List<IcuArg> args;

  /// Longest rendered length in Unicode code points, counting each argument
  /// with the length given by the `argLength` callback.
  final int maxLength;

  Set<String> get names => {for (final a in args) a.name};
}

/// Thrown when a message is not valid ICU.
class IcuSyntaxError implements Exception {
  IcuSyntaxError(this.message, this.offset);
  final String message;
  final int offset;

  @override
  String toString() => '$message (at character $offset)';
}

const _choiceTypes = {'plural', 'select'};
const _dateTypes = {'date', 'time'};
const _pluralCases = {'zero', 'one', 'two', 'few', 'many', 'other'};
// gen-l10n's lexer reads digits as a number before a word, so names can't
// start with a digit; after the opening brace any word is a name.
final _namePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final _numberPattern = RegExp(r'^[0-9]+$');
// gen_l10n.dart only maps these exact plural cases.
const _exactCases = {'=0', '=1', '=2'};
// Lexed as keywords anywhere but right after "{", so not usable as cases.
const _keywords = {'plural', 'select', 'date', 'time'};
// flutter_tools/lib/src/localizations/gen_l10n_types.dart validDateFormats.
const _dateSkeletons = {
  'd', 'E', 'EEEE', 'LLL', 'LLLL', 'M', 'Md', 'MEd', 'MMM', 'MMMd', 'MMMEd', //
  'MMMM', 'MMMMd', 'MMMMEEEEd', 'QQQ', 'QQQQ', 'y', 'yM', 'yMd', 'yMEd', //
  'yMMM', 'yMMMd', 'yMMMEd', 'yMMMM', 'yMMMMd', 'yMMMMEEEEd', 'yQQQ', //
  'yQQQQ', 'H', 'Hm', 'Hms', 'j', 'jm', 'jms', 'jmv', 'jmz', 'jv', 'jz', 'm', //
  'ms', 's',
};

/// Reads [source]. [argLength] gives the rendered length used for an argument
/// when estimating [IcuMessage.maxLength].
IcuMessage parseIcu(String source, {int Function(String name)? argLength}) {
  final p = _Parser(source, argLength ?? (_) => 4);
  final length = p.message(nested: false, inPlural: false);
  if (p.pos != source.length) {
    throw IcuSyntaxError('unexpected "}"', p.pos);
  }
  return IcuMessage(p.args, length);
}

class _Parser {
  _Parser(this.s, this.argLength);

  final String s;
  final int Function(String) argLength;
  final List<IcuArg> args = [];
  int pos = 0;

  bool get atEnd => pos >= s.length;
  String get ch => s[pos];

  /// Reads text and arguments up to the end, or up to the closing `}` of a
  /// choice case when [nested]. Returns the rendered length.
  int message({required bool nested, required bool inPlural}) {
    var length = 0;
    while (!atEnd) {
      final c = ch;
      if (c == '{') {
        length += argument();
      } else if (c == '}') {
        if (nested) return length;
        throw IcuSyntaxError('unexpected "}"', pos);
      } else if (inPlural && c == '#') {
        throw IcuSyntaxError(
          '"#" in a plural case is printed as is by flutter gen-l10n; '
          'use the argument, e.g. {count}',
          pos,
        );
      } else {
        length += 1;
        // Count code points, not UTF-16 units.
        final unit = s.codeUnitAt(pos);
        pos += (unit >= 0xD800 && unit <= 0xDBFF) ? 2 : 1;
      }
    }
    if (nested) throw IcuSyntaxError('missing "}"', pos);
    return length;
  }

  int argument() {
    final start = pos;
    pos++; // {
    _ws();
    final name = _identifier('argument name');
    if (!_namePattern.hasMatch(name)) {
      throw IcuSyntaxError(
        'argument name "$name" must start with a letter or _',
        start,
      );
    }
    _ws();
    if (atEnd) throw IcuSyntaxError('missing "}" for {$name', start);
    if (ch == '}') {
      pos++;
      args.add(IcuArg(name, 'simple'));
      return argLength(name);
    }
    _expect(',');
    _ws();
    final type = _identifier('argument type');
    _ws();
    if (_choiceTypes.contains(type)) {
      _expect(',');
      args.add(IcuArg(name, type));
      return _cases(name, type, start);
    }
    if (type == 'number') {
      throw IcuSyntaxError(
        '{$name, number} is not supported by flutter gen-l10n; use {$name} '
        'and set the placeholder\'s "format" in meta.json',
        start,
      );
    }
    if (type == 'selectordinal') {
      throw IcuSyntaxError(
        '{$name, selectordinal} is not supported by flutter gen-l10n; '
        'use {$name, plural, ...} or {$name, select, ...}',
        start,
      );
    }
    if (!_dateTypes.contains(type)) {
      throw IcuSyntaxError('unknown argument type "$type"', start);
    }
    // gen-l10n only takes a skeleton: `{when, date, ::yMMMd}`.
    if (atEnd || ch != ',') {
      throw IcuSyntaxError(
        '{$name, $type} needs a skeleton, e.g. {$name, $type, ::yMMMd}, '
        'or use {$name} with a DateTime "format" in meta.json',
        start,
      );
    }
    pos++;
    _ws();
    if (!s.startsWith('::', pos)) {
      throw IcuSyntaxError(
        '{$name, $type, ...}: gen-l10n only accepts a skeleton such as '
        '::yMMMd (no styles like short or medium)',
        pos,
      );
    }
    pos += 2;
    final skeletonStart = pos;
    final skeleton = _identifier('date/time skeleton');
    if (!_dateSkeletons.contains(skeleton)) {
      throw IcuSyntaxError(
        'date/time skeleton "::$skeleton" is not one gen-l10n knows '
        '(e.g. ::yMMMd, ::MMMd, ::jm)',
        skeletonStart,
      );
    }
    _ws();
    _expect('}');
    args.add(IcuArg(name, type));
    return argLength(name);
  }

  int _cases(String name, String type, int start) {
    final selectors = <String>{};
    var longest = 0;
    while (true) {
      _ws();
      if (atEnd) throw IcuSyntaxError('missing "}" for {$name', start);
      if (ch == '}') {
        pos++;
        break;
      }
      final selectorStart = pos;
      while (!atEnd && !' \t\n{}'.contains(ch)) {
        pos++;
      }
      final selector = s.substring(selectorStart, pos);
      if (selector.isEmpty) {
        throw IcuSyntaxError('missing case selector in {$name}', pos);
      }
      _checkSelector(name, type, selector, selectorStart);
      if (!selectors.add(selector)) {
        throw IcuSyntaxError('case "$selector" repeated in {$name}', pos);
      }
      _ws();
      _expect('{');
      final len = message(nested: true, inPlural: type != 'select');
      _expect('}');
      if (len > longest) longest = len;
    }
    if (!selectors.contains('other')) {
      throw IcuSyntaxError('{$name, $type} has no "other" case', start);
    }
    return longest;
  }

  /// The case names gen-l10n accepts: plural takes zero, one, two, few,
  /// many, other, =0, =1 or =2; select takes a word (not a keyword such as
  /// date) or a number.
  void _checkSelector(String name, String type, String selector, int at) {
    if (type == 'plural') {
      if (_pluralCases.contains(selector) || _exactCases.contains(selector)) {
        return;
      }
      throw IcuSyntaxError(
        selector.startsWith('offset:')
            ? '{$name, plural}: offset: is not supported by flutter gen-l10n'
            : 'case "$selector" in {$name, plural} must be zero, one, two, '
                  'few, many, other, =0, =1 or =2',
        at,
      );
    }
    final word = _namePattern.hasMatch(selector);
    if ((word && !_keywords.contains(selector)) ||
        _numberPattern.hasMatch(selector)) {
      return;
    }
    throw IcuSyntaxError(
      'case "$selector" in {$name, select} must be a word starting with a '
      'letter or _ (not plural, select, date or time) or a number',
      at,
    );
  }

  String _identifier(String what) {
    final start = pos;
    while (!atEnd && RegExp(r'[A-Za-z0-9_]').hasMatch(ch)) {
      pos++;
    }
    if (start == pos) throw IcuSyntaxError('missing $what', pos);
    return s.substring(start, pos);
  }

  void _ws() {
    while (!atEnd && ' \t\n'.contains(ch)) {
      pos++;
    }
  }

  void _expect(String c) {
    if (atEnd || ch != c) throw IcuSyntaxError('expected "$c"', pos);
    pos++;
  }
}
