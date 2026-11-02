import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/fa_header.dart';
import 'auth_support.dart';
import 'auth_widgets.dart';

/// A1c set your own password after a temporary one (step 1 of 2 of the
/// first login).
///
/// The temporary password typed on the login is reused, so the FA types only
/// the new one twice; after a restart (or a wrong one) the screen asks for
/// it. Saving needs network. On success the session moves to setup at once
/// and the router follows; A1d's first step then says "Password saved" (the
/// design's success state), since this screen is gone by then. Back logs out
/// after asking: nothing else is allowed until the password is changed.
class ChangePasswordScreen extends ConsumerWidget {
  /// Creates the screen.
  const ChangePasswordScreen({super.key});

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.faNewPasswordLeaveTitle),
        content: Text(l10n.faNewPasswordLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.faCommonLogOut),
          ),
        ],
      ),
    );
    if (yes ?? false) await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context, ref);
      },
      child: Scaffold(
        body: Column(
          children: [
            FaHeader(
              title: l10n.faNewPasswordTitle,
              subtitle: l10n.faNewPasswordStep,
              onBack: () => _leave(context, ref),
              backLabel: l10n.faNewPasswordBackLabel,
              showSync: false,
            ),
            const Expanded(child: ChangePasswordForm(firstLogin: true)),
          ],
        ),
      ),
    );
  }
}

/// The new-password form of A1c, also Me's Change password: the current
/// password (when needed), the new one twice with Show / Hide, the live
/// rule checklist ([PasswordCheck]) and Save.
///
/// [firstLogin]: the temporary-password change of A1c (the 72-hours note;
/// the temporary password from the login is reused when the app still has
/// it). Otherwise the FA types the current password. [onSaved] runs after a
/// successful save.
class ChangePasswordForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const ChangePasswordForm({super.key, this.firstLogin = false, this.onSaved});

  /// The first-login change of a temporary password.
  final bool firstLogin;

  /// Called once the new password is saved.
  final VoidCallback? onSaved;

  @override
  ConsumerState<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<ChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  bool _currentWrong = false;
  Object? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  /// The temporary password from the login, while it is still usable here.
  String? get _held => widget.firstLogin && !_currentWrong
      ? ref.read(authHandoffProvider).tempPassword
      : null;

  String get _currentPassword => _held ?? _current.text;

  /// The server's answer to a wrong current password: 400 with
  /// `fields.current_password`. A 401 means the session ended (the session
  /// moves on by itself), not a wrong password.
  bool _isWrongCurrent(ApiError e) {
    final fields = e.details['fields'];
    return e.code == ApiErrorCode.validationFailed &&
        fields is Map &&
        fields.containsKey('current_password');
  }

  Future<void> _save(bool ok) async {
    if (!ok || _busy) return;
    FocusScope.of(context).unfocus();
    final session = ref.read(sessionProvider.notifier);
    final handoff = ref.read(authHandoffProvider.notifier);
    final firstLogin = widget.firstLogin;
    final onSaved = widget.onSaved;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.changePassword(_currentPassword, _next.text);
      if (firstLogin) handoff.passwordSaved();
      onSaved?.call();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        if (_isWrongCurrent(e)) {
          _currentWrong = true;
          _current.clear();
        } else {
          _error = e;
        }
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final loginId = ref.watch(sessionProvider.select((s) => s.fa?.code));
    // Watched so a restart's empty hand-off shows the field.
    ref.watch(authHandoffProvider);
    final askCurrent = _held == null;
    final current = _currentPassword;
    final check = PasswordCheck(
      _next.text,
      current: current.isEmpty ? null : current,
      loginId: loginId,
    );
    final match = _next.text.isNotEmpty && _next.text == _again.text;
    final ok = check.ok && match && current.isNotEmpty;
    final rules = [
      (l10n.faNewPasswordRuleLength, check.longEnough),
      (
        l10n.faNewPasswordRuleLetterDigit,
        _next.text.isNotEmpty && check.hasLetterAndDigit,
      ),
      (
        l10n.faNewPasswordRuleLoginId,
        _next.text.isNotEmpty && check.notLoginId,
      ),
      (
        l10n.faNewPasswordRuleCurrent,
        _next.text.isNotEmpty && current.isNotEmpty && check.notCurrent,
      ),
      (l10n.faNewPasswordRuleMatch, match),
    ];
    final error = _error;
    final wrongCurrent = _currentWrong
        ? (widget.firstLogin
              ? l10n.faNewPasswordWrongTemp
              : l10n.faNewPasswordWrongCurrent)
        : null;

    return FillScroll(
      content: [
        if (widget.firstLogin)
          NoteCard(
            tone: NoteTone.warning,
            icon: OrbitIcons.pending,
            text: l10n.faNewPasswordNote,
          ),
        if (askCurrent)
          PasswordField(
            controller: _current,
            label: widget.firstLogin
                ? l10n.faNewPasswordCurrentTemp
                : l10n.faNewPasswordCurrent,
            enabled: !_busy,
            errorText: wrongCurrent,
            onChanged: (_) => setState(() {}),
          ),
        PasswordField(
          controller: _next,
          label: l10n.faNewPasswordNew,
          enabled: !_busy,
          autofillHints: const [AutofillHints.newPassword],
          obscured: _hidden,
          onToggle: () => setState(() => _hidden = !_hidden),
          onChanged: (_) => setState(() {}),
        ),
        PasswordField(
          controller: _again,
          label: l10n.faNewPasswordAgain,
          enabled: !_busy,
          autofillHints: const [AutofillHints.newPassword],
          obscured: _hidden,
          showToggle: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(ok),
        ),
        Semantics(
          container: true,
          label: l10n.faNewPasswordRules,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(OrbitSpace.s16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (label, done) in rules)
                    _RuleRow(label: label, done: done),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          InlineError(
            error is ApiError && error.isNetwork
                ? l10n.faNewPasswordOffline
                : errorText(context, error),
          ),
      ],
      bottom: [
        OrbitButton(
          label: l10n.faNewPasswordSave,
          loading: _busy,
          onPressed: ok && !_busy ? () => _save(ok) : null,
        ),
        Text(
          widget.firstLogin
              ? l10n.faNewPasswordNeedsNetworkFirst
              : l10n.faNewPasswordNeedsNetwork,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall!.copyWith(
            fontSize: 13,
            color: OrbitColors.of(context).textMuted,
          ),
        ),
      ],
    );
  }
}

/// One rule of the checklist: a green tick when it holds, an empty ring
/// otherwise. Reads as "At least 8 characters, done".
class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    return Semantics(
      label:
          '$label, ${done ? l10n.faNewPasswordRuleDone : l10n.faNewPasswordRuleNotYet}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? orbit.success.fg : null,
                border: done
                    ? null
                    : Border.all(color: theme.colorScheme.outline, width: 2),
              ),
              child: done
                  ? Icon(
                      OrbitIcons.check,
                      size: 14,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: OrbitSpace.s10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: done ? orbit.success.strong : orbit.textMuted,
                  fontWeight: done ? OrbitFont.weightBold : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
