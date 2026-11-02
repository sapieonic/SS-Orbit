import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../shared/async_view.dart';
import '../../shared/conflict_mine.dart';
import '../../shared/fa_header.dart';
import '../../shared/formatters.dart';
import '../../shared/helpline.dart';
import 'sync_rows.dart';
import 'sync_view.dart';

/// Whether a refused record also shows the server's own reason under the
/// localised one. That text is English and for developers: dev builds only.
final showServerReasonsProvider = Provider<bool>(
  (ref) => ref.watch(orbitEnvProvider).flavor == Flavor.dev,
);

/// A7 Sync: what is waiting, conflicts, photos.
///
/// Everything here comes from the engine ([syncStateProvider]): the banner,
/// one row per outbox record (waiting, uploading, synced), conflicts with
/// Keep mine / Keep HO's, refused records with their reason and what was
/// dropped with them, the Wi-Fi-only switch and Sync now.
class SyncScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  /// Outbox rows with a choice or dismiss being saved.
  final _busy = <String>{};

  OrbitLocalizations get _l10n => context.l10n;

  Future<void> _syncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = _l10n;
    final result = await ref.read(syncEngineProvider).syncNow(force: true);
    final text = switch (result.skipped) {
      SyncSkip.offline => l10n.errorNetwork,
      SyncSkip.busy => l10n.faSyncBusy,
      null => null,
    };
    if (text == null || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Iterable<String> ids, Future<void> Function() write) async {
    final keys = ids.toList();
    setState(() => _busy.addAll(keys));
    try {
      await write();
    } on Object catch (e) {
      if (mounted) showActionError(context, e);
    } finally {
      if (mounted) setState(() => _busy.removeAll(keys));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final state = ref.watch(syncStateProvider);
    final territory = ref.watch(territoryProvider);
    final now = ref.watch(clockProvider).now();

    final waiting = state.queuedCount;
    return Scaffold(
      body: Column(
        children: [
          FaHeader(
            title: l10n.faShellTitleSync,
            subtitle: _lastSynced(state, now),
            back: true,
            showSync: false,
            actions: [_WaitingCount(count: waiting)],
          ),
          Expanded(
            child: AsyncValueView<Territory>(
              value: territory,
              onRetry: () => ref.invalidate(territoryProvider),
              data: (t) => _body(
                state,
                SyncView.build(
                  state,
                  t,
                  language: contentLanguage(context),
                  now: now,
                ),
                t,
                now,
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                OrbitSpace.s16,
                OrbitSpace.s8,
                OrbitSpace.s16,
                OrbitSpace.s12,
              ),
              child: OrbitButton(
                label: state.running
                    ? l10n.faSyncSyncingTitle
                    : l10n.faSyncSyncNow,
                icon: OrbitIcons.sync,
                loading: state.running,
                onPressed: state.running ? null : _syncNow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _lastSynced(SyncState s, DateTime now) {
    final l10n = _l10n;
    final at = s.lastPullAt ?? s.lastPushAt;
    if (at == null) return l10n.faSyncNeverSynced;
    if (now.difference(at) < const Duration(minutes: 1)) {
      return l10n.faSyncLastSyncedJustNow;
    }
    final time = formatTime(l10n, at);
    final day = LocalDate.istOf(at);
    if (day == LocalDate.istOf(now)) {
      return l10n.faSyncLastSyncedToday(time: time);
    }
    return l10n.faSyncLastSyncedOn(
      date: formatDateShort(l10n, day),
      time: time,
    );
  }

  Widget _body(SyncState state, SyncView view, Territory t, DateTime now) {
    final l10n = _l10n;
    final orbit = OrbitColors.of(context);
    final language = contentLanguage(context);
    final actions = ref.read(faActionsProvider);
    const gap = SizedBox(height: OrbitSpace.s10);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        OrbitSpace.s12,
        OrbitSpace.s16,
        OrbitSpace.s8,
      ),
      children: [
        _banner(state, now),
        if (state.running) ...[
          const SizedBox(height: OrbitSpace.s8),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              value: state.runProgress,
              minHeight: 8,
              semanticsLabel: l10n.faSyncProgressLabel,
            ),
          ),
        ],
        for (final r in view.records) ...[
          gap,
          SyncRowFrame(
            child: SyncRowTop(
              icon: recordTypeIcon(r.entry.type),
              title: recordTitle(l10n, r),
              meta: recordMeta(l10n, r, now),
              pill: progressPill(l10n, r.progress),
            ),
          ),
        ],
        for (final r in view.conflicts) ...[gap, _conflict(r, t, language)],
        for (final r in view.resolved) ...[
          gap,
          _resolved(r, t, language, actions),
        ],
        for (final g in view.rejected) ...[gap, _rejected(g, actions)],
        gap,
        SwitchRow(
          bordered: true,
          title: l10n.faSyncWifiTitle,
          subtitle: state.photosOnWifiOnly
              ? l10n.faSyncWifiOn
              : l10n.faSyncWifiOff,
          value: state.photosOnWifiOnly,
          onChanged: (v) =>
              unawaited(_run(const [], () => actions.setPhotosOnWifiOnly(v))),
        ),
        gap,
        Row(
          children: [
            Icon(
              OrbitIcons.success,
              size: OrbitSize.iconSm,
              color: orbit.success.strong,
            ),
            const SizedBox(width: OrbitSpace.s6),
            Expanded(
              child: Text(
                l10n.faSyncSyncedToday(count: state.syncedToday),
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: orbit.success.strong,
                  fontSize: 14,
                  fontWeight: OrbitFont.weightSemibold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _banner(SyncState s, DateTime now) {
    final l10n = _l10n;
    final orbit = OrbitColors.of(context);
    final needsYou = s.conflicts.length + s.rejected.length;
    final size = s.photosWaiting > 0
        ? formatBytes(l10n, s.photosWaitingBytes)
        : null;

    if (s.running) {
      return SyncStatusBanner(
        tone: orbit.info,
        icon: OrbitIcons.upload,
        title: l10n.faSyncSyncingTitle,
        text: size == null
            ? l10n.faSyncSyncingBody
            : l10n.faSyncSyncingBodyPhotos(size: size),
      );
    }
    if (!s.online) {
      return SyncStatusBanner(
        tone: orbit.warning,
        icon: OrbitIcons.offline,
        title: l10n.faSyncOfflineTitle,
        text: l10n.faSyncOfflineBody(count: s.queuedCount),
      );
    }
    if (!s.hasSnapshot) {
      return SyncStatusBanner(
        tone: orbit.info,
        icon: OrbitIcons.sync,
        title: l10n.faSyncNeverSynced,
        text: l10n.faSyncFirstSyncBody,
      );
    }
    if (needsYou > 0) {
      return SyncStatusBanner(
        tone: orbit.danger,
        icon: OrbitIcons.alert,
        title: l10n.faSyncNeedsYouTitle(count: needsYou, synced: s.syncedToday),
        text: l10n.faSyncNeedsYouBody,
      );
    }
    final retry = s.nextRetryAt;
    if (retry != null && s.queuedCount > 0 && retry.isAfter(now)) {
      return SyncStatusBanner(
        tone: orbit.warning,
        icon: OrbitIcons.pending,
        title: l10n.faSyncRetryTitle,
        text: l10n.faSyncRetryBody(time: formatTime(l10n, retry)),
      );
    }
    final error = s.lastError;
    if (error != null) {
      return SyncStatusBanner(
        tone: orbit.danger,
        icon: OrbitIcons.error,
        title: l10n.faSyncErrorTitle,
        text: errorText(context, error),
      );
    }
    if (s.queuedCount > 0 || s.photosWaiting > 0) {
      final String text;
      if (s.queuedCount == 0 && s.photosHeldForWifi) {
        text = l10n.faSyncPhotosHeld(size: size!);
      } else if (size != null) {
        text = l10n.faSyncWaitingRecordsPhotos(
          count: s.queuedCount,
          size: size,
        );
      } else {
        text = l10n.faSyncWaitingRecords(count: s.queuedCount);
      }
      return SyncStatusBanner(
        tone: orbit.warning,
        icon: OrbitIcons.pending,
        title: s.onWifi ? l10n.faSyncWaitingTitle : l10n.faSyncMobileDataTitle,
        text: text,
      );
    }
    final at = s.lastPushAt ?? s.lastPullAt;
    return SyncStatusBanner(
      tone: orbit.success,
      icon: OrbitIcons.check,
      title: l10n.faSyncAllSyncedTitle,
      text: at == null
          ? null
          : l10n.faSyncAllSyncedBody(time: formatTime(l10n, at)),
    );
  }

  String _conflictMeta(SyncRecord r) => switch (r.entry.type) {
    CommandType.savePlot => _l10n.faSyncConflictMetaPlot(
      plot: r.plotLabel ?? _l10n.faSyncTypePlot,
    ),
    CommandType.updateFarmer => _l10n.faSyncConflictMetaFarmer,
    _ => _l10n.faSyncConflictMetaOther,
  };

  Widget _conflict(SyncRecord r, Territory t, Language language) {
    final l10n = _l10n;
    final c = r.entry.conflict;
    final field = c?.field ?? '';
    final yours = conflictMine(r.entry);
    final mine = conflictValue(l10n, t, language, field, yours.value);
    final theirs = conflictValue(l10n, t, language, field, c?.theirs);
    final id = r.entry.id;
    final busy = _busy.contains(id);
    final actions = ref.read(faActionsProvider);
    final canKeepMine = r.entry.canKeepMine;
    return ConflictCard(
      title: recordTitle(l10n, r),
      meta: dotJoin(l10n, [
        _conflictMeta(r),
        if (!canKeepMine) l10n.faSyncConflictOnlyTheirs,
        if (yours.laterEdit) l10n.faSyncConflictWaiting,
      ]),
      statusLabel: l10n.faSyncPillConflict,
      mineLabel: l10n.faSyncYours,
      mineValue: mine,
      theirsLabel: l10n.faSyncTheirs,
      theirsValue: theirs,
      keepMineLabel: canKeepMine ? l10n.faSyncKeepMine : null,
      keepTheirsLabel: l10n.faSyncKeepTheirs,
      onKeepMine: canKeepMine
          ? () => unawaited(_run([id], () => actions.keepMine(id)))
          : null,
      onKeepTheirs: () => unawaited(_run([id], () => actions.keepTheirs(id))),
      resolving: busy,
    );
  }

  Widget _resolved(
    ResolvedRecord r,
    Territory t,
    Language language,
    FaActions actions,
  ) {
    final l10n = _l10n;
    final c = r.record.entry.conflict;
    final value = conflictValue(
      l10n,
      t,
      language,
      c?.field ?? '',
      r.keptMine ? conflictMine(r.record.entry).value : c?.theirs,
    );
    final id = r.record.entry.id;
    return SyncRowFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SyncRowTop(
            icon: recordTypeIcon(r.record.entry.type),
            title: recordTitle(l10n, r.record),
            meta: dotJoin(l10n, [
              r.keptMine
                  ? l10n.faSyncResolvedMine(value: value)
                  : l10n.faSyncResolvedTheirs(value: value),
              if (r.progress != RecordProgress.synced) l10n.faSyncResolvedReady,
            ]),
            pill: progressPill(l10n, r.progress),
          ),
          if (r.progress == RecordProgress.synced) ...[
            const SizedBox(height: OrbitSpace.s8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _DismissButton(
                busy: _busy.contains(id),
                onPressed: () =>
                    unawaited(_run([id], () => actions.dismiss(id))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _reason(Rejection? rejection) {
    final l10n = _l10n;
    return switch (rejection?.code) {
      RejectionCode.registeredWithAnotherFa => l10n.faSyncReasonOtherFa,
      RejectionCode.notInYourArea => l10n.faSyncReasonNotInArea,
      RejectionCode.serverCouldNotApply => l10n.faSyncReasonServer,
      RejectionCode.clientInvalid => l10n.faSyncReasonClient,
      RejectionCode.parentRejected => l10n.faSyncReasonParent,
      RejectionCode.consentProofExpired => l10n.faSyncReasonConsentExpired,
      RejectionCode.other || null => l10n.faSyncReasonOther,
    };
  }

  Widget _rejected(RejectedGroup g, FaActions actions) {
    final l10n = _l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final now = ref.read(clockProvider).now();
    final entry = g.record.entry;
    final rejection = entry.rejection;
    final detail =
        ref.read(showServerReasonsProvider) &&
            rejection?.code == RejectionCode.other
        ? rejection!.message.trim()
        : '';
    final ids = [for (final e in g.entries) e.id];
    final busy = ids.any(_busy.contains);
    final muted = theme.textTheme.bodySmall!.copyWith(color: orbit.textMuted);

    Future<void> dismissAll() async {
      for (final id in ids) {
        await actions.dismiss(id);
      }
    }

    return SyncRowFrame(
      edge: orbit.danger.fg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SyncRowTop(
            icon: recordTypeIcon(entry.type),
            iconTone: orbit.danger,
            title: recordTitle(l10n, g.record),
            meta: recordMeta(l10n, g.record, now),
            pill: StatusPill(
              label: l10n.faSyncPillNotSaved,
              tone: OrbitStatusTone.danger,
            ),
          ),
          const SizedBox(height: OrbitSpace.s8),
          Text(
            _reason(rejection),
            style: theme.textTheme.bodyMedium!.copyWith(
              color: orbit.danger.strong,
              fontWeight: OrbitFont.weightBold,
            ),
          ),
          if (detail.isNotEmpty) Text(detail, style: muted),
          if (g.dropped.isNotEmpty) ...[
            const SizedBox(height: OrbitSpace.s6),
            Text(l10n.faSyncDroppedHeading, style: muted),
            for (final d in g.dropped)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: OrbitSpace.s8),
                child: Text('• ${recordTitle(l10n, d)}', style: muted),
              ),
          ],
          const SizedBox(height: OrbitSpace.s8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: OrbitSpace.s8,
            runSpacing: OrbitSpace.s8,
            children: [
              if (rejection?.code == RejectionCode.registeredWithAnotherFa)
                OrbitButton(
                  label: l10n.faSyncCallHo,
                  icon: OrbitIcons.phone,
                  size: OrbitButtonSize.medium,
                  fullWidth: false,
                  onPressed: () => unawaited(callHo(context, ref)),
                ),
              _DismissButton(
                busy: busy,
                onPressed: () => unawaited(_run(ids, dismissAll)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OrbitButton(
    label: context.l10n.faSyncDismiss,
    icon: OrbitIcons.close,
    size: OrbitButtonSize.medium,
    variant: OrbitButtonVariant.secondary,
    fullWidth: false,
    loading: busy,
    onPressed: busy ? null : onPressed,
  );
}

/// The header's cloud and count of records waiting (not a button on Sync).
class _WaitingCount extends StatelessWidget {
  const _WaitingCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    return Semantics(
      label: count == 0
          ? l10n.faShellSyncAllSynced
          : l10n.faShellSyncWaiting(count: count),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: orbit.onPrimaryBarFill,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                count == 0 ? OrbitIcons.synced : OrbitIcons.sync,
                size: OrbitSize.iconMd,
                color: orbit.onPrimaryBar,
              ),
              const SizedBox(width: OrbitSpace.s6),
              Text(
                '$count',
                style: theme.textTheme.labelLarge!.copyWith(
                  color: orbit.onPrimaryBar,
                  fontSize: 15,
                  fontWeight: OrbitFont.weightExtrabold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
