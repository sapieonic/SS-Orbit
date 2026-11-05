import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../shared/async_view.dart';
import '../../shared/fa_header.dart';
import '../../shared/formatters.dart';
import 'auth_support.dart';
import 'auth_widgets.dart';

enum _Step { language, pin, done }

enum _Download { running, done, failed }

/// A1d language and PIN after the first login (and after a password login
/// with no PIN, e.g. after a lock-out).
///
/// 1. Language: Telugu or English, applied at once (`setLanguage`).
/// 2. PIN twice on the pad; weak PINs ([PinLock.problem]) and a mismatch
///    start over.
/// 3. "You're set up": the territory downloads while the FA reads the
///    summary (farmers, plots). The PIN is saved only when the FA taps
///    "Open my farmers": saving it makes the session active, and the router
///    would leave this screen at once, so the summary comes first. A failed
///    download (offline) does not block: the engine pulls once there is
///    network.
class SetupScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  _Step _step = _Step.language;
  String _typed = '';
  String? _first;
  String? _error;
  _Download _download = _Download.running;
  bool _opening = false;

  int get _length => ref.read(sessionProvider).policy.pinLength;

  Future<void> _setLanguage(Language language) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionProvider.notifier).setLanguage(language);
    } on Object catch (e) {
      // The language changed; only saving it on the phone failed. Worded in
      // the new language, which the screen now shows.
      if (!mounted) return;
      final l10n = lookupOrbitLocalizations(Locale(language.wire));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorTextIn(l10n, e))));
    }
  }

  void _toLanguage() => setState(() {
    _step = _Step.language;
    _typed = '';
    _first = null;
    _error = null;
  });

  void _digit(String d) {
    if (_typed.length >= _length) return;
    final typed = _typed + d;
    setState(() {
      _typed = typed;
      _error = null;
    });
    if (typed.length == _length) _entered(typed);
  }

  void _delete() {
    if (_typed.isEmpty) return;
    setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  void _entered(String pin) {
    final l10n = context.l10n;
    final first = _first;
    if (first == null) {
      final problem = PinLock.problem(pin, length: _length);
      setState(() {
        _typed = '';
        if (problem == null) {
          _first = pin;
        } else {
          _error = problem == PinProblem.year
              ? l10n.faSetupPinYear
              : l10n.faSetupPinWeak;
        }
      });
      return;
    }
    if (pin != first) {
      setState(() {
        _typed = '';
        _first = null;
        _error = l10n.faSetupPinMismatch;
      });
      return;
    }
    setState(() => _step = _Step.done);
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() => _download = _Download.running);
    final engine = ref.read(syncEngineProvider);
    final territory = ref.read(territoryProvider.notifier);
    var ok = false;
    try {
      final result = await engine.syncNow();
      await territory.reload();
      ok = result.error == null && result.skipped != SyncSkip.offline;
    } on Object {
      ok = false;
    }
    if (!mounted) return;
    final hasData = ref.read(territoryProvider).value?.hasData ?? false;
    setState(
      () => _download = ok && hasData ? _Download.done : _Download.failed,
    );
  }

  Future<void> _open() async {
    final pin = _first;
    if (pin == null || _opening) return;
    setState(() => _opening = true);
    try {
      // Moves the session to active; the router opens Farmers.
      await ref.read(sessionProvider.notifier).setPin(pin);
    } on Object catch (e) {
      if (!mounted) return;
      showActionError(context, e);
      _toLanguage();
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider);
    final handoff = ref.watch(authHandoffProvider);
    final fa = session.fa;
    // "Step 2 of 2" only after A1c (a temporary password). The profile's
    // flag covers a restart between A1c and A1d; a later setup always
    // follows a password login, whose profile no longer has the flag.
    final firstLogin =
        handoff.passwordSaved || (fa?.mustChangePassword ?? false);
    final title = switch (_step) {
      _Step.language => l10n.faSetupTitleLanguage,
      _Step.pin => l10n.faSetupTitlePin(length: session.policy.pinLength),
      _Step.done => l10n.faSetupTitleDone,
    };
    return PopScope(
      canPop: _step == _Step.language,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == _Step.pin) _toLanguage();
      },
      child: Scaffold(
        body: Column(
          children: [
            FaHeader(
              title: title,
              subtitle: firstLogin
                  ? l10n.faSetupStepFirst
                  : l10n.faSetupStepAgain,
              showSync: false,
            ),
            Expanded(
              child: switch (_step) {
                _Step.language => _languageStep(l10n, session, handoff),
                _Step.pin => _pinStep(l10n, session),
                _Step.done => _doneStep(l10n, session),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageStep(
    OrbitLocalizations l10n,
    SessionState session,
    AuthHandoff handoff,
  ) {
    final theme = Theme.of(context);
    final code = session.fa?.code;
    return FillScroll(
      gap: 12,
      content: [
        if (handoff.passwordSaved && code != null)
          NoteCard(
            tone: NoteTone.success,
            text: l10n.faSetupPasswordSaved(code: code),
          ),
        Text(
          l10n.faSetupQuestion,
          style: theme.textTheme.titleMedium!.copyWith(
            fontWeight: OrbitFont.weightBold,
          ),
        ),
        Semantics(
          container: true,
          label: l10n.faSetupTitleLanguage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChoiceTile(
                label: l10n.labelLanguage(Language.te.wire),
                secondaryLabel: l10n.faSetupTeSub,
                selected: session.language == Language.te,
                onTap: () => _setLanguage(Language.te),
              ),
              const SizedBox(height: OrbitSpace.s10),
              ChoiceTile(
                label: l10n.labelLanguage(Language.en.wire),
                selected: session.language == Language.en,
                onTap: () => _setLanguage(Language.en),
              ),
            ],
          ),
        ),
        Text(
          l10n.faSetupLanguageNote,
          style: theme.textTheme.bodyMedium!.copyWith(
            fontSize: 14,
            color: OrbitColors.of(context).textMuted,
          ),
        ),
      ],
      bottom: [
        OrbitButton(
          label: l10n.faSetupToPin,
          onPressed: () => setState(() => _step = _Step.pin),
        ),
      ],
    );
  }

  Widget _pinStep(OrbitLocalizations l10n, SessionState session) {
    final confirming = _first != null;
    final error = _error;
    return FillScroll(
      content: [
        PinEntryView(
          label: confirming ? l10n.faSetupPinAgain : l10n.faSetupPinPick,
          length: session.policy.pinLength,
          filled: _typed.length,
          error: error != null,
          hint:
              error ??
              (confirming
                  ? l10n.faSetupPinHintAgain
                  : l10n.faSetupPinHintFirst(
                      days: session.policy.offlineGraceDays,
                    )),
          onDigit: _digit,
          onDelete: _delete,
          leading: PinPadKey.text(
            label: l10n.commonBack,
            semanticLabel: l10n.faSetupPinBackLabel,
            height: 60,
            onPressed: _toLanguage,
          ),
        ),
      ],
      bottom: [
        Text(
          l10n.faSetupPinNote(tries: session.policy.pinMaxAttempts),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall!
              .copyWith(fontSize: 13, color: OrbitColors.of(context).textMuted),
        ),
      ],
    );
  }

  Widget _doneStep(OrbitLocalizations l10n, SessionState session) {
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final fa = session.fa;
    final territory = ref.watch(territoryProvider).value;
    final language = contentLanguage(context);
    final name = fa == null ? '' : firstName(fa.displayName(language));
    final area = areaLabel(territory, language);
    final download = _download;
    final status = switch (download) {
      _Download.running => l10n.faSetupDownloading,
      _Download.done => l10n.commonDone,
      _Download.failed => null,
    };
    return FillScroll(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      content: [
        Center(
          child: RoundBadge(
            icon: OrbitIcons.check,
            background: orbit.success.fg,
            foreground: theme.colorScheme.onPrimary,
          ),
        ),
        Semantics(
          liveRegion: true,
          child: Column(
            children: [
              Text(
                l10n.faSetupDoneTitle(name: name),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall!.copyWith(
                  fontWeight: OrbitFont.weightExtrabold,
                ),
              ),
              if (fa != null)
                Text(
                  dotJoin(l10n, [fa.code, area]),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: orbit.textMuted,
                  ),
                ),
            ],
          ),
        ),
        Semantics(
          container: true,
          label: l10n.faSetupDownloadTitle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(OrbitSpace.s16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: OrbitSpace.s8,
                    children: [
                      Text(
                        l10n.faSetupDownloadTitle,
                        style: theme.textTheme.titleSmall!.copyWith(
                          fontWeight: OrbitFont.weightBold,
                        ),
                      ),
                      if (status != null)
                        Text(
                          status,
                          style: theme.textTheme.titleSmall!.copyWith(
                            color: download == _Download.done
                                ? orbit.success.strong
                                : orbit.textMuted,
                            fontWeight: OrbitFont.weightBold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: OrbitSpace.s8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: switch (download) {
                        _Download.running => null,
                        _Download.done => 1,
                        _Download.failed => 0,
                      },
                      color: orbit.success.fg,
                      backgroundColor: orbit.success.tint,
                      semanticsLabel: l10n.faSetupDownloadProgress,
                    ),
                  ),
                  const SizedBox(height: OrbitSpace.s8),
                  if (download == _Download.failed) ...[
                    Text(
                      l10n.faSetupDownloadFailed,
                      style: theme.textTheme.bodyMedium!.copyWith(fontSize: 14),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _startDownload,
                        icon: const Icon(OrbitIcons.refresh),
                        label: Text(l10n.commonRetry),
                      ),
                    ),
                  ] else if (territory != null && territory.hasData)
                    Text(
                      dotJoin(l10n, [
                        l10n.faAuthFarmersCount(count: territory.farmerCount),
                        l10n.faAuthPlotsCount(count: territory.plotCount),
                        l10n.faSetupDownloadLists,
                      ]),
                      style: theme.textTheme.bodyMedium!.copyWith(
                        fontSize: 14,
                        color: orbit.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      bottom: [
        OrbitButton(
          label: l10n.faSetupOpenFarmers,
          loading: _opening,
          onPressed: _opening ? null : _open,
        ),
      ],
    );
  }
}
