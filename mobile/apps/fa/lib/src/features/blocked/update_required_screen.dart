import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../device/device.dart';
import '../../local/local.dart';
import '../auth/auth_widgets.dart';

enum _Send { idle, sending, sent, failed }

/// A12 the app must be updated to continue (below the server's
/// `min_version`).
///
/// Records still waiting on the phone are sent first ("Send records, then
/// update", through the session's `LocalDataGuard`, which pushes with the
/// sync engine), then Play Store opens at `AppConfig.storeUrl`. The session
/// already tried one push before blocking, so usually nothing waits. If the
/// push fails (offline) the FA may still update: an app update keeps the
/// phone's data, and the records go up after it.
class UpdateRequiredScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const UpdateRequiredScreen({super.key});

  @override
  ConsumerState<UpdateRequiredScreen> createState() =>
      _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends ConsumerState<UpdateRequiredScreen> {
  _Send _send = _Send.idle;
  int _sentCount = 0;

  int _pending(SyncState s) => s.queuedCount + s.photosWaiting;

  Future<void> _sendRecords(int count) async {
    setState(() => _send = _Send.sending);
    final ok = await ref.read(localDataGuardProvider).pushPending();
    if (!mounted) return;
    setState(() {
      _sentCount = count;
      _send = ok ? _Send.sent : _Send.failed;
    });
  }

  Future<void> _openStore() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(sessionProvider.notifier);
    var url = ref.read(sessionProvider).appConfig?.storeUrl;
    if (url == null) {
      try {
        await session.refreshAppConfig();
      } on Object {
        // Offline: no link to open.
      }
      if (!mounted) return;
      url = ref.read(sessionProvider).appConfig?.storeUrl;
    }
    final opened =
        url != null && await ref.read(launcherProvider).openStore(url);
    if (opened) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.faBlockedStoreFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final version = ref.watch(appVersionProvider);
    final min = ref
        .watch(sessionProvider.select((s) => s.appConfig))
        ?.minVersion;
    final pending = _pending(ref.watch(syncStateProvider));
    final send = _send == _Send.idle && pending == 0 ? _Send.sent : _send;
    final step1 = switch (send) {
      _Send.idle || _Send.failed => l10n.faBlockedStepSend(count: pending),
      _Send.sending => l10n.faBlockedStepSending(count: pending),
      _Send.sent when _sentCount > 0 => l10n.faBlockedStepSent(
        count: _sentCount,
      ),
      _Send.sent => l10n.faBlockedStepNothing,
    };
    final (Color step1Colour, bool step1Done) = switch (send) {
      _Send.sent => (orbit.success.fg, true),
      _Send.sending => (theme.colorScheme.primary, false),
      _ => (orbit.warning.fg, false),
    };
    final grey = theme.colorScheme.outline;

    return PlainPage(
      child: FillScroll(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
        content: [
          Center(
            child: RoundBadge(
              icon: OrbitIcons.upload,
              square: true,
              background: theme.colorScheme.primaryContainer,
              foreground: theme.colorScheme.primary,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              l10n.commonUpdateRequiredTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall!.copyWith(
                fontWeight: OrbitFont.weightExtrabold,
              ),
            ),
          ),
          Text(
            min != null && compareVersions(version, min) < 0
                ? l10n.faBlockedUpdateBody(version: version, min: min)
                : l10n.faBlockedUpdateBodyPlain(version: version),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: orbit.textMuted,
              height: 1.45,
            ),
          ),
          Semantics(
            container: true,
            label: l10n.faBlockedBefore,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StepRow(
                      number: 1,
                      text: step1,
                      colour: step1Colour,
                      done: step1Done,
                      bold: true,
                    ),
                    _StepRow(
                      number: 2,
                      text: l10n.faBlockedStepStore,
                      colour: grey,
                    ),
                    _StepRow(
                      number: 3,
                      text: l10n.faBlockedStepUnlock,
                      colour: grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (send == _Send.failed)
            NoteCard(tone: NoteTone.warning, text: l10n.faBlockedSendFailed)
          else
            Text(
              l10n.faBlockedNothingLost,
              style: theme.textTheme.bodyMedium!.copyWith(
                fontSize: 14,
                color: orbit.textMuted,
              ),
            ),
        ],
        bottom: [
          switch (send) {
            _Send.sent => OrbitButton(
              label: l10n.faBlockedOpenStore,
              icon: OrbitIcons.upload,
              onPressed: _openStore,
            ),
            _Send.sending => OrbitButton(
              label: l10n.faBlockedSending,
              loading: true,
              onPressed: null,
            ),
            _Send.idle => OrbitButton(
              label: l10n.faBlockedSendThenUpdate,
              icon: OrbitIcons.send,
              onPressed: () => _sendRecords(pending),
            ),
            _Send.failed => OrbitButton(
              label: l10n.commonRetry,
              icon: OrbitIcons.refresh,
              onPressed: () => _sendRecords(pending),
            ),
          },
          if (send == _Send.failed)
            OrbitButton(
              label: l10n.faBlockedUpdateAnyway,
              variant: OrbitButtonVariant.secondary,
              onPressed: _openStore,
            ),
        ],
      ),
    );
  }
}

/// One numbered step: a coloured disc with the number (a tick when [done])
/// and the text.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
    required this.colour,
    this.done = false,
    this.bold = false,
  });

  final int number;
  final String text;
  final Color colour;
  final bool done;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
              child: done
                  ? Icon(
                      OrbitIcons.check,
                      size: 14,
                      color: theme.colorScheme.onPrimary,
                    )
                  : Text(
                      '$number',
                      textScaler: TextScaler.noScaling,
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: OrbitFont.weightBold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: OrbitSpace.s10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium!.copyWith(
                fontWeight: bold ? OrbitFont.weightBold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
