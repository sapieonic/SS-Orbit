import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../routing/router.dart' show devMenuEnabled;
import '../../shared/async_view.dart';
import '../../shared/formatters.dart';
import '../../shared/helpline.dart';
import 'auth_support.dart';
import 'auth_widgets.dart';

/// A1 issued login: the login ID and password HO gave, also when the
/// password is needed again ([SessionPhase.passwordNeeded]).
///
/// The design's "Remember this device" checkbox is shown as an information
/// line instead: every FA sets a PIN right after the first login (A1d), so
/// there is nothing to choose. On success the session phase moves on (A1c,
/// A1d or the app) and the router follows; errors stay on this screen.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _id;
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Password needed again: the same FA, so the login ID is known.
    _id = TextEditingController(text: ref.read(sessionProvider).fa?.code);
  }

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _ready => _id.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _logIn({bool replaceOtherFa = false}) async {
    if (!_ready || _busy) return;
    FocusScope.of(context).unfocus();
    final session = ref.read(sessionProvider.notifier);
    final handoff = ref.read(authHandoffProvider.notifier);
    final password = _password.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    // A temporary password goes straight on to A1c, which then need not ask
    // for it again. Forgotten as soon as the phase is not A1c.
    handoff.heldPassword(password);
    try {
      await session.login(_id.text, password, replaceOtherFa: replaceOtherFa);
    } on OtherFaOnPhone catch (e) {
      handoff.clear();
      if (!mounted) return;
      setState(() => _busy = false);
      if (await _confirmOtherFa(e)) await _logIn(replaceOtherFa: true);
      return;
    } on Object catch (e) {
      handoff.clear();
      if (mounted) setState(() => _error = e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _confirmOtherFa(OtherFaOnPhone other) async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.faLoginOtherFaTitle),
        content: Text(
          l10n.faLoginOtherFaBody(
            count: other.unsynced,
            code: other.previousCode,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.faLoginOtherFaConfirm),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  String _errorMessage(OrbitLocalizations l10n, Object error, bool signedIn) =>
      switch (error) {
        ApiError(isNetwork: true) =>
          signedIn
              ? l10n.faLoginErrorOfflineAgain
              : l10n.faLoginErrorOfflineFirst,
        ApiError(code: ApiErrorCode.unauthorized) => l10n.faLoginErrorWrong,
        _ => errorText(context, error),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final showDev = devMenuEnabled(ref.watch(orbitEnvProvider));
    final error = _error;

    final needed = session.phase == SessionPhase.passwordNeeded;
    final usePin = needed && session.canUsePin
        ? OrbitButton(
            label: l10n.faLoginUsePin,
            icon: OrbitIcons.lock,
            variant: OrbitButtonVariant.secondary,
            size: OrbitButtonSize.medium,
            onPressed: _busy
                ? null
                : () => ref.read(sessionProvider.notifier).usePin(),
          )
        : null;
    final banner = needed ? _reasonBanner(l10n, session, usePin) : null;

    return PlainPage(
      child: FillScroll(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        content: [
          Stack(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 10),
                child: Center(child: BrandMark()),
              ),
              if (showDev)
                const PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: DevMenuButton(),
                ),
            ],
          ),
          ?banner,
          LabelledField(
            label: l10n.faLoginLoginId,
            child: TextField(
              controller: _id,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
          ),
          PasswordField(
            controller: _password,
            focusNode: _passwordFocus,
            label: l10n.faLoginPassword,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _logIn(),
          ),
          InfoRow(
            icon: OrbitIcons.lock,
            text: l10n.faLoginPinNote(length: session.policy.pinLength),
          ),
          if (error != null)
            InlineError(_errorMessage(l10n, error, session.isSignedIn)),
          OrbitButton(
            label: l10n.faLoginLogIn,
            loading: _busy,
            onPressed: _ready && !_busy ? _logIn : null,
          ),
          // With a banner, "Unlock with PIN instead" sits in it.
          if (banner == null) ?usePin,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: OrbitSpace.s8,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, OrbitSize.controlLg),
                  textStyle: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: OrbitFont.weightBold,
                  ),
                ),
                onPressed: () => callHo(context, ref),
                child: Text(l10n.faLoginForgot),
              ),
              StatusPill(
                label: l10n.faLoginWorksOffline,
                tone: OrbitStatusTone.info,
                icon: OrbitIcons.cloudOff,
              ),
            ],
          ),
        ],
        bottom: [
          NoteCard(text: l10n.faLoginHoNote, icon: OrbitIcons.info),
          const SizedBox(height: OrbitSpace.s4),
          const _Footer(),
        ],
      ),
    );
  }

  Widget? _reasonBanner(
    OrbitLocalizations l10n,
    SessionState session,
    Widget? usePin,
  ) => switch (session.passwordNeededReason) {
    PasswordNeededReason.expired => NoteCard(
      tone: NoteTone.warning,
      icon: OrbitIcons.cloudOff,
      title: l10n.faLoginExpiredTitle,
      text: l10n.faLoginExpiredBody(days: session.policy.offlineGraceDays),
      actions: usePin,
    ),
    PasswordNeededReason.lockedOut => NoteCard(
      tone: NoteTone.danger,
      icon: OrbitIcons.lock,
      title: l10n.faLoginLockedTitle,
      text: l10n.faLoginLockedBody,
      actions: usePin,
    ),
    PasswordNeededReason.sessionEnded => NoteCard(
      icon: OrbitIcons.sync,
      title: l10n.faLoginEndedTitle,
      text: l10n.faLoginEndedBody,
      actions: usePin,
    ),
    PasswordNeededReason.tempPasswordExpired => NoteCard(
      tone: NoteTone.danger,
      title: l10n.faLoginTempExpiredTitle,
      text: l10n.errorTempPasswordExpired,
      actions: usePin,
    ),
    _ => null,
  };
}

/// "Version 0.1.0 · last synced Today 10:42 AM · HO 1800 123 4567".
class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lastPull = ref.watch(syncStateProvider.select((s) => s.lastPullAt));
    final clock = ref.watch(clockProvider);
    final text = dotJoin(l10n, [
      l10n.faLoginFooterVersion(version: ref.watch(appVersionProvider)),
      if (lastPull != null)
        l10n.faLoginFooterSynced(
          day: formatDaysAgo(
            l10n,
            LocalDate.istOf(lastPull),
            today: LocalDate.todayIst(clock),
          ),
          time: formatTime(l10n, lastPull),
        ),
      l10n.faLoginFooterHo(
        phone: formatHelpline(ref.watch(hoHelplineProvider)),
      ),
    ]);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall!
          .copyWith(fontSize: 13, color: OrbitColors.of(context).textMuted),
    );
  }
}
