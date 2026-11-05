/// The farmer's programme consent through the FA (FAR-04): the notice in the
/// farmer's language with its Listen control, "Send consent OTP", the code
/// the farmer reads out, Confirm, and "Consent recorded".
///
/// Used by Enrol step 1 ([ConsentPanel] inside the form) and, for a farmer
/// enrolled consent pending, by Farmer 360's "Record consent"
/// ([showRecordConsentSheet]). Both need network: offline the panel says
/// consent is recorded later.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../shared/async_view.dart';
import '../../shared/formatters.dart';
import 'enrol_support.dart';

/// The version of the consent notice the panel shows
/// (`notice_version` in EnrolFarmer and RecordConsent). Bump it with the
/// `fa.consent.notice` text.
const faConsentNoticeVersion = 'fa-v1';

/// What the consent flow ended with: the server's proof that the farmer read
/// out the code, whether the notice was played, and the notice version.
@immutable
final class ConsentOutcome {
  /// Creates an outcome.
  const ConsentOutcome({
    required this.proof,
    required this.audioPlayed,
    this.noticeVersion = faConsentNoticeVersion,
  });

  /// Put in `EnrolFarmer.consent.otp_proof` or `RecordConsent.otp_proof`.
  final ConsentProof proof;

  /// The FA played the notice to the farmer.
  final bool audioPlayed;

  /// The notice shown.
  final String noticeVersion;

  @override
  bool operator ==(Object other) =>
      other is ConsentOutcome &&
      other.proof == proof &&
      other.audioPlayed == audioPlayed &&
      other.noticeVersion == noticeVersion;

  @override
  int get hashCode => Object.hash(proof, audioPlayed, noticeVersion);
}

enum _Stage { idle, sending, sent, verifying, done }

/// The consent box: notice, Listen, Send consent OTP, OTP entry, Confirm,
/// "Consent recorded · 11:02".
///
/// [phone] is the farmer's number in any common format; while it is not a
/// valid mobile number, Send is disabled. A new [phone] starts over (and
/// reports null). [language] picks the notice text and the SMS language.
/// [onChanged] gets the [ConsentOutcome] once the code is confirmed, and
/// null when it no longer holds.
class ConsentPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const ConsentPanel({
    super.key,
    required this.phone,
    required this.language,
    required this.onChanged,
    this.enabled = true,
    this.offline = false,
  });

  /// The farmer's phone.
  final String phone;

  /// The farmer's language.
  final Language language;

  /// Called with the outcome, or null when reset.
  final ValueChanged<ConsentOutcome?> onChanged;

  /// False while the rest of the form is busy (saving).
  final bool enabled;

  /// The screen already knows there is no network (a lookup failed so).
  /// The panel also follows the connectivity and its own failed calls.
  final bool offline;

  @override
  ConsumerState<ConsentPanel> createState() => _ConsentPanelState();
}

class _ConsentPanelState extends ConsumerState<ConsentPanel> {
  final _code = TextEditingController();
  _Stage _stage = _Stage.idle;

  /// The FA tapped Listen. There is no recording of the notice yet, so this
  /// only changes the button to "Audio not available yet": `audio_played`
  /// stays false until a real recording has played to the end.
  bool _listenTapped = false;
  bool _networkFailed = false;
  OtpSent? _sent;
  ConsentOutcome? _outcome;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  String? get _e164 => normalizeIndianMobile(widget.phone);

  @override
  void didUpdateWidget(ConsentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (normalizeIndianMobile(oldWidget.phone) != _e164) {
      _reset(duringBuild: true);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  /// Starts over. From [didUpdateWidget] ([duringBuild]) the parent is
  /// building, so the fields change without `setState` (a build follows) and
  /// the parent hears of it after the frame.
  void _reset({bool duringBuild = false}) {
    final had = _outcome != null;
    _resendTimer?.cancel();
    _code.clear();
    void clear() {
      _stage = _Stage.idle;
      _sent = null;
      _outcome = null;
      _error = null;
      _resendIn = 0;
    }

    if (duringBuild) {
      clear();
    } else {
      setState(clear);
    }
    if (!had) return;
    if (duringBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _outcome == null) widget.onChanged(null);
      });
    } else {
      widget.onChanged(null);
    }
  }

  void _startResendTimer(Duration after) {
    _resendTimer?.cancel();
    _resendIn = after.inSeconds;
    if (_resendIn <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _play() {
    // No recording of the notice exists yet: nothing plays, so nothing is
    // recorded as played. The FA reads the notice out; the snack bar says
    // the audio is not there yet.
    setState(() => _listenTapped = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.commonAudioUnavailable)),
      );
  }

  Future<void> _send() async {
    final phone = _e164;
    if (phone == null || _stage == _Stage.sending) return;
    setState(() {
      _stage = _Stage.sending;
      _error = null;
    });
    try {
      final sent = await ref
          .read(enrolmentRepositoryProvider)
          .requestConsentOtp(phone: phone, language: widget.language);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _sent = sent;
        _stage = _Stage.sent;
        _networkFailed = false;
      });
      _startResendTimer(sent.resendAfter);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _sent == null ? _Stage.idle : _Stage.sent;
        if (e.isNetwork) {
          _networkFailed = true;
        } else {
          _error = errorText(context, e);
          if (e.retryAfter case final wait?) _startResendTimer(wait);
        }
      });
    }
  }

  Future<void> _confirm() async {
    final phone = _e164;
    final code = _code.text;
    if (phone == null || code.length != 6 || _stage == _Stage.verifying) {
      return;
    }
    setState(() {
      _stage = _Stage.verifying;
      _error = null;
    });
    try {
      final proof = await ref
          .read(enrolmentRepositoryProvider)
          .verifyConsentOtp(phone: phone, code: code);
      if (!mounted) return;
      _resendTimer?.cancel();
      // No recording played (there is none yet): see [_listenTapped].
      final outcome = ConsentOutcome(proof: proof, audioPlayed: false);
      setState(() {
        _outcome = outcome;
        _stage = _Stage.done;
      });
      widget.onChanged(outcome);
    } on ApiError catch (e) {
      if (!mounted) return;
      final noTriesLeft =
          e.code == ApiErrorCode.otpExpired ||
          (e.code == ApiErrorCode.otpInvalid && e.attemptsLeft == 0);
      setState(() {
        if (e.isNetwork) {
          _networkFailed = true;
          _stage = _Stage.sent;
          return;
        }
        _error = errorText(context, e);
        _code.clear();
        // A dead code: ask for a new one.
        _stage = noTriesLeft ? _Stage.idle : _Stage.sent;
        if (noTriesLeft) {
          _sent = null;
          _resendTimer?.cancel();
          _resendIn = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final online = ref.watch(phoneOnlineProvider);
    final offline = widget.offline || !online || _networkFailed;
    final notice = lookupOrbitLocalizations(Locale(widget.language.wire));
    final enabled = widget.enabled;
    final validPhone = _e164 != null;

    final String lead = switch (_stage) {
      _Stage.done => l10n.faConsentAgreed,
      _Stage.sent || _Stage.verifying => l10n.faConsentSent(
        phone: formatIndianMobile(widget.phone),
      ),
      _ => l10n.faConsentHow,
    };

    final List<Widget> body;
    if (_stage == _Stage.done) {
      final outcome = _outcome!;
      final time = formatTime(l10n, outcome.proof.verifiedAt);
      body = [
        Semantics(
          liveRegion: true,
          child: InfoRow(
            icon: OrbitIcons.success,
            text: outcome.audioPlayed
                ? l10n.faConsentRecordedPlayed(
                    time: time,
                    language:
                        l10n.enumLabel('language', widget.language.wire) ??
                        widget.language.wire,
                  )
                : l10n.faConsentRecorded(time: time),
          ),
        ),
      ];
    } else if (offline && _stage != _Stage.sent && _stage != _Stage.verifying) {
      body = [
        EnrolNotice(
          icon: OrbitIcons.offline,
          tone: orbit.warning,
          title: l10n.faConsentOfflineTitle,
          body: l10n.faConsentOfflineBody,
          actions: [
            if (_networkFailed)
              OrbitButton(
                label: l10n.commonRetry,
                icon: OrbitIcons.refresh,
                variant: OrbitButtonVariant.secondary,
                onPressed: enabled
                    ? () => setState(() => _networkFailed = false)
                    : null,
              ),
          ],
        ),
      ];
    } else if (_stage == _Stage.idle || _stage == _Stage.sending) {
      body = [
        OrbitButton(
          label: l10n.faConsentSendOtp,
          icon: OrbitIcons.send,
          variant: OrbitButtonVariant.secondary,
          loading: _stage == _Stage.sending,
          onPressed: enabled && validPhone && _resendIn <= 0 ? _send : null,
        ),
        if (!validPhone) ...[
          const SizedBox(height: OrbitSpace.s6),
          Text(l10n.faConsentNeedsPhone, style: theme.textTheme.bodySmall),
        ] else if (_resendIn > 0) ...[
          const SizedBox(height: OrbitSpace.s6),
          Text(
            l10n.faConsentResendIn(seconds: _resendIn),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ];
    } else {
      body = [
        EnrolFieldLabel(l10n.faConsentOtpLabel),
        OtpInput(
          controller: _code,
          enabled: enabled && _stage == _Stage.sent,
          semanticLabel: l10n.faConsentOtpLabel,
          onChanged: (_) => setState(() => _error = null),
          onCompleted: (_) => setState(() {}),
        ),
        const SizedBox(height: OrbitSpace.s8),
        OrbitButton(
          label: l10n.faConsentConfirm,
          icon: OrbitIcons.check,
          loading: _stage == _Stage.verifying,
          onPressed: enabled && _code.text.length == 6 ? _confirm : null,
        ),
        if (_networkFailed) ...[
          const SizedBox(height: OrbitSpace.s6),
          InlineError(l10n.errorNetwork),
        ],
        TextButton(
          onPressed: enabled && _resendIn <= 0 && _stage == _Stage.sent
              ? _send
              : null,
          child: Text(
            _resendIn > 0
                ? l10n.faConsentResendIn(seconds: _resendIn)
                : l10n.faConsentResend,
          ),
        ),
      ];
    }

    return EnrolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                OrbitIcons.consent,
                color: theme.colorScheme.primary,
                size: OrbitSize.iconLg,
              ),
              const SizedBox(width: OrbitSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.faConsentTitle,
                      style: theme.textTheme.titleSmall!.copyWith(
                        fontWeight: OrbitFont.weightExtrabold,
                      ),
                    ),
                    const SizedBox(height: OrbitSpace.s2),
                    Text(lead, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OrbitSpace.s12),
          // The notice itself, in the farmer's language.
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.all(
                Radius.circular(OrbitRadius.md),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(OrbitSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.faConsentNotice,
                    locale: Locale(widget.language.wire),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: OrbitSpace.s8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ListenButton(
                      label: _listenTapped
                          ? l10n.commonAudioUnavailable
                          : l10n.faConsentPlay,
                      state: ListenState.unavailable,
                      onPressed: enabled ? _play : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: OrbitSpace.s8),
            InlineError(error),
          ],
          const SizedBox(height: OrbitSpace.s12),
          ...body,
        ],
      ),
    );
  }
}

/// Farmer 360's "Record consent" for a farmer enrolled consent pending: the
/// [ConsentPanel] in a bottom sheet over [farmerId]'s phone and language,
/// then Save, which queues RecordConsent (`FaActions.recordConsent`).
///
/// Completes with true when consent was saved (the sheet has said so).
///
/// ```dart
/// if (farmer360.consentPending)
///   OrbitButton(
///     label: l10n.faFarmer360RecordConsent,
///     onPressed: () => showRecordConsentSheet(context, farmerId: id),
///   );
/// ```
Future<bool> showRecordConsentSheet(
  BuildContext context, {
  required String farmerId,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => RecordConsentSheet(farmerId: farmerId),
  );
  return saved ?? false;
}

/// The content of [showRecordConsentSheet]; pops true once saved.
class RecordConsentSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const RecordConsentSheet({super.key, required this.farmerId});

  /// The farmer.
  final String farmerId;

  @override
  ConsumerState<RecordConsentSheet> createState() => _RecordConsentSheetState();
}

class _RecordConsentSheetState extends ConsumerState<RecordConsentSheet> {
  ConsentOutcome? _outcome;
  bool _saving = false;

  Future<void> _save() async {
    final outcome = _outcome;
    if (outcome == null || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final savedText = context.l10n.faConsentSaved;
    try {
      await ref
          .read(faActionsProvider)
          .recordConsent(
            farmerId: widget.farmerId,
            proof: outcome.proof,
            audioPlayed: outcome.audioPlayed,
            noticeVersion: outcome.noticeVersion,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(savedText)));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final territory = ref.watch(territoryProvider).value;
    final farmer = territory?.farmer(widget.farmerId);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OrbitSpace.s16,
          0,
          OrbitSpace.s16,
          OrbitSpace.s16,
        ),
        child: farmer == null
            ? Text(l10n.errorNotFound, style: theme.textTheme.bodyLarge)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.faConsentSheetTitle(
                        name: farmer.displayName(contentLanguage(context)),
                      ),
                      style: theme.textTheme.titleLarge!.copyWith(
                        fontWeight: OrbitFont.weightExtrabold,
                      ),
                    ),
                  ),
                  const SizedBox(height: OrbitSpace.s12),
                  ConsentPanel(
                    phone: farmer.phone,
                    language: farmer.language,
                    enabled: !_saving,
                    onChanged: (o) => setState(() => _outcome = o),
                  ),
                  const SizedBox(height: OrbitSpace.s16),
                  OrbitButton(
                    label: l10n.faConsentSave,
                    icon: OrbitIcons.check,
                    loading: _saving,
                    onPressed: _outcome != null && !_saving ? _save : null,
                  ),
                ],
              ),
      ),
    );
  }
}
