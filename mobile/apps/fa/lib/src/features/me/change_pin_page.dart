import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/fa_header.dart';
import '../../shared/formatters.dart';
import '../auth/auth_widgets.dart';

enum _Step { current, next, again }

/// Me's Change PIN, a page pushed over Me: the current PIN, then the new one
/// twice (the same weak-PIN rules as A1d).
///
/// The current PIN is checked at the end, by `changePin`, like an unlock: a
/// wrong one costs a try and starts over; the last try moves the session to
/// the password login and the router leaves Me.
class ChangePinPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const ChangePinPage({super.key});

  /// Pushes the page over [context]'s navigator.
  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const ChangePinPage()));

  @override
  ConsumerState<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends ConsumerState<ChangePinPage> {
  _Step _step = _Step.current;
  String _typed = '';
  String? _current;
  String? _next;
  String? _error;
  bool _checking = false;

  int get _length => ref.read(sessionProvider).policy.pinLength;

  void _digit(String d) {
    if (_checking || _typed.length >= _length) return;
    final typed = _typed + d;
    setState(() {
      _typed = typed;
      _error = null;
    });
    if (typed.length == _length) _entered(typed);
  }

  void _delete() {
    if (_checking || _typed.isEmpty) return;
    setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  void _entered(String pin) {
    final l10n = context.l10n;
    switch (_step) {
      case _Step.current:
        setState(() {
          _current = pin;
          _typed = '';
          _step = _Step.next;
        });
      case _Step.next:
        final problem = PinLock.problem(pin, length: _length);
        setState(() {
          _typed = '';
          if (problem == null) {
            _next = pin;
            _step = _Step.again;
          } else {
            _error = problem == PinProblem.year
                ? l10n.faSetupPinYear
                : l10n.faSetupPinWeak;
          }
        });
      case _Step.again:
        if (pin != _next) {
          setState(() {
            _typed = '';
            _next = null;
            _step = _Step.next;
            _error = l10n.faSetupPinMismatch;
          });
          return;
        }
        _save(_current!, pin);
    }
  }

  Future<void> _save(String current, String next) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(sessionProvider.notifier);
    setState(() => _checking = true);
    bool changed;
    try {
      changed = await session.changePin(current, next);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _typed = '';
        _step = _Step.current;
      });
      showActionError(context, e);
      return;
    }
    if (!mounted) return;
    if (changed) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.faChangePinChanged)));
      navigator.pop();
      return;
    }
    final left = ref.read(sessionProvider).pinAttemptsLeft;
    setState(() {
      _checking = false;
      _typed = '';
      _current = null;
      _next = null;
      _step = _Step.current;
      _error = dotJoin(l10n, [
        l10n.faChangePinWrongOld,
        if (left != null) l10n.faUnlockTriesLeft(count: left),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final policy = ref.watch(sessionProvider.select((s) => s.policy));
    final error = _error;
    final (String label, String? hint) = switch (_step) {
      _Step.current => (l10n.faChangePinOld, null),
      _Step.next => (
        l10n.faChangePinNew,
        l10n.faSetupPinHintFirst(days: policy.offlineGraceDays),
      ),
      _Step.again => (l10n.faChangePinAgain, l10n.faSetupPinHintAgain),
    };
    return Scaffold(
      body: Column(
        children: [
          FaHeader(
            title: l10n.faMeChangePin,
            subtitle: l10n.commonStepOf(step: _step.index + 1, total: 3),
            back: true,
            showSync: false,
          ),
          Expanded(
            child: FillScroll(
              content: [
                PinEntryView(
                  label: label,
                  length: policy.pinLength,
                  filled: _typed.length,
                  error: error != null,
                  hint: error ?? hint,
                  enabled: !_checking,
                  onDigit: _digit,
                  onDelete: _delete,
                ),
              ],
              bottom: [
                Text(
                  l10n.faSetupPinNote(tries: policy.pinMaxAttempts),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall!
                      .copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
