import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/call_buttons.dart';
import '../../shared/sign_in_scaffold.dart';
import '../../shared/voice.dart';
import 'widgets/no_otp_sheet.dart';
import 'widgets/resend_countdown.dart';

/// Digits in the farmer OTP.
const otpLength = 6;

/// F1, code step: the 6 OTP boxes for the number in [SessionState.phone].
///
/// The code is checked as soon as the last digit is in. A wrong code clears
/// the boxes and says how many tries are left; an expired code (or no tries
/// left) points at Resend. Resend waits for [SessionState.resendAvailableAt]
/// and for any `Retry-After` the server sends. Back goes to the phone step.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _verifying = false;
  bool _resending = false;
  ApiError? _codeError;
  ApiError? _resendError;

  /// A new code was sent: say so in place (a snack bar would cover the
  /// Verify button).
  bool _resent = false;

  /// Set from `Retry-After` on `rate_limited`; Resend waits for it too.
  DateTime? _retryAfterUntil;

  // TODO(M7): plug SMS autofill in here. Add `smart_auth`, start the SMS
  // Retriever (User Consent API when the server has no app hash) in
  // initState, write the received code into [_code] and call [_verify];
  // stop listening in dispose. Until then the OS keyboard suggestion
  // (`AutofillHints.oneTimeCode` on OtpInput) is the only autofill.

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  SessionController get _session => ref.read(sessionProvider.notifier);

  /// True when the current code can no longer work: ask for a new one.
  bool get _needsNewCode => switch (_codeError) {
    ApiError(code: ApiErrorCode.otpExpired) => true,
    ApiError(attemptsLeft: 0) => true,
    _ => false,
  };

  void _rememberRetryAfter(ApiError e) {
    final wait = e.retryAfter;
    if (e.code == ApiErrorCode.rateLimited && wait != null) {
      _retryAfterUntil = ref.read(clockProvider).now().add(wait);
    }
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (code.length != otpLength || _verifying || _needsNewCode) return;
    setState(() {
      _verifying = true;
      _codeError = null;
      _resendError = null;
      _resent = false;
    });
    try {
      await _session.verifyOtp(code);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _codeError = e;
        _rememberRetryAfter(e);
        // A wrong or dead code is cleared so the next one starts fresh; on a
        // network error the code stays for another try.
        if (!e.isNetwork) _code.clear();
      });
      if (!_needsNewCode) _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _resendError = null;
      _resent = false;
    });
    try {
      await _session.resendOtp();
      if (!mounted) return;
      setState(() {
        _codeError = null;
        _retryAfterUntil = null;
        _resent = true;
        _code.clear();
      });
      _focus.requestFocus();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _resendError = e;
        _rememberRetryAfter(e);
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _editPhone() {
    if (ref.read(sessionProvider).phase == SessionPhase.otpSent) {
      _session.editPhone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final otp = session.otp;
    final busy = _verifying || _resending;

    final resendAt = _later(session.resendAvailableAt, _retryAfterUntil);

    return PopScope(
      canPop: false,
      // Back goes to the phone step, but not while a code is being checked
      // or sent (the header's back is disabled then too).
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) _editPhone();
      },
      child: SignInScaffold(
        header: ScreenHeader(
          title: l10n.farmerLoginOtpTitle,
          onBack: busy ? null : _editPhone,
          listen: const ScreenListenButton(
            voiceKey: VoiceKeys.farmerLoginVoiceHelpOtp,
          ),
        ),
        content: [
          if (otp != null)
            Text(
              l10n.farmerLoginOtpSentTo(phone: otp.phoneMasked),
              style: theme.textTheme.bodyLarge,
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: busy ? null : _editPhone,
              icon: const Icon(OrbitIcons.phone, size: OrbitSize.iconMd),
              label: Text(l10n.farmerLoginChangeNumber),
            ),
          ),
          const SizedBox(height: OrbitSpace.s8),
          OtpInput(
            controller: _code,
            focusNode: _focus,
            autofocus: true,
            enabled: !busy && !_needsNewCode,
            semanticLabel: l10n.farmerLoginOtpTitle,
            errorText: _codeError == null
                ? null
                : errorText(context, _codeError!),
            onChanged: (_) => setState(() {}),
            onCompleted: (_) => _verify(),
          ),
          const SizedBox(height: OrbitSpace.s8),
          Text(
            l10n.farmerLoginOtpHint,
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: OrbitSpace.s16),
          ResendCountdown(
            availableAt: resendAt,
            loading: _resending,
            highlighted: _needsNewCode,
            onResend: _verifying ? null : _resend,
          ),
          if (_resent) ...[
            const SizedBox(height: OrbitSpace.s8),
            Semantics(
              liveRegion: true,
              child: InfoRow(
                icon: OrbitIcons.success,
                text: l10n.farmerLoginOtpSent,
              ),
            ),
          ],
          if (_resendError case final error?) ...[
            const SizedBox(height: OrbitSpace.s8),
            InlineError(errorText(context, error)),
          ],
          const SizedBox(height: OrbitSpace.s8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => showNoOtpSheet(context),
              icon: const Icon(OrbitIcons.help, size: OrbitSize.iconMd),
              label: Text(l10n.farmerLoginNoOtp),
            ),
          ),
        ],
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrbitButton(
              label: l10n.farmerLoginVerify,
              icon: OrbitIcons.check,
              size: OrbitButtonSize.hero,
              loading: _verifying,
              onPressed: _code.text.length == otpLength && !_needsNewCode
                  ? _verify
                  : null,
            ),
            const SizedBox(height: OrbitSpace.s4),
            const HelplineLink(),
          ],
        ),
      ),
    );
  }
}

/// The later of [a] and [b]; null only when both are.
DateTime? _later(DateTime? a, DateTime? b) =>
    a == null || (b != null && b.isAfter(a)) ? b : a;
