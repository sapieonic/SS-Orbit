import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/formatters.dart';
import '../../shared/pending_sync_tag.dart';
import 'alerts_data.dart';

/// What the FA can do on an alert card. The screen runs them (dialer,
/// navigation, `FaActions`).
final class AlertCardActions {
  /// Creates the actions.
  const AlertCardActions({
    required this.onFinishEnrolment,
    required this.onOpenFarmer,
    required this.onCallAndPlan,
    required this.onCall,
    required this.onCloseCallback,
    required this.onAck,
  });

  /// New farmer: open enrolment with the phone filled in.
  final void Function(AlertItem item) onFinishEnrolment;

  /// New farmer already enrolled: open Farmer 360.
  final void Function(AlertItem item) onOpenFarmer;

  /// New farmer: call, then plan a visit.
  final void Function(AlertItem item) onCallAndPlan;

  /// Call-back: call the farmer.
  final void Function(AlertItem item) onCall;

  /// Call-back: close the request after the call.
  final void Function(AlertItem item) onCloseCallback;

  /// HO note: "Got it".
  final void Function(AlertItem item) onAck;
}

/// One alert on A6: the kind pill and how long ago, the title and body in
/// the UI language, and the actions for its kind.
class AlertCard extends StatelessWidget {
  /// Creates the card.
  const AlertCard({
    super.key,
    required this.item,
    required this.now,
    required this.actions,
    this.called = false,
    this.busy = false,
  });

  /// The alert.
  final AlertItem item;

  /// Now (UTC), for "10 min ago".
  final DateTime now;

  /// What the buttons do.
  final AlertCardActions actions;

  /// The FA called this farmer back from this card: offer Close call-back.
  final bool called;

  /// An action on this card is being saved.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final language = contentLanguage(context);
    final a = item.alert;

    final (
      String kindLabel,
      OrbitStatusTone tone,
      IconData icon,
      Color edge,
    ) = switch (a.kind) {
      AlertKind.newFarmer => (
        l10n.faAlertsKindNewFarmer,
        OrbitStatusTone.success,
        OrbitIcons.person,
        orbit.success.fg,
      ),
      AlertKind.callback => (
        l10n.faAlertsKindCallback,
        OrbitStatusTone.warning,
        OrbitIcons.phone,
        orbit.warning.fg,
      ),
      AlertKind.hoNote => (
        l10n.faAlertsKindHoNote,
        OrbitStatusTone.info,
        OrbitIcons.notice,
        orbit.info.fg,
      ),
      _ => (
        l10n.faAlertsKindOther,
        OrbitStatusTone.neutral,
        OrbitIcons.bell,
        scheme.outlineVariant,
      ),
    };

    final open = a.status == AlertStatus.open;
    final body = a.displayBody(language);
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: orbit.textMuted,
      fontSize: 14,
    );

    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill(label: kindLabel, tone: tone, icon: icon),
            ),
          ),
          const SizedBox(width: OrbitSpace.s8),
          Text(formatTimeAgo(l10n, a.createdAt, now: now), style: muted),
        ],
      ),
      const SizedBox(height: OrbitSpace.s8),
      Text(
        a.displayTitle(language),
        style: theme.textTheme.bodyLarge!.copyWith(
          fontWeight: OrbitFont.weightBold,
        ),
      ),
      if (body != null) ...[
        const SizedBox(height: OrbitSpace.s2),
        Text(body, style: muted),
      ],
      ..._actions(context, open),
    ];

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(OrbitSpace.s16)),
        side: BorderSide(
          color: open ? edge : scheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, bool open) {
    final l10n = context.l10n;
    final language = contentLanguage(context);
    final a = item.alert;
    final name = item.name(language);
    final hasPhone = item.phone != null;

    Widget status(String text, {bool pending = false}) =>
        _StatusLine(text: text, pending: pending);

    switch (a.kind) {
      case AlertKind.newFarmer:
        final row = item.farmerRow;
        final enrolled = row != null && !row.needsEnrolment;
        if (a.status == AlertStatus.closed && !enrolled) {
          return [status(l10n.faAlertsStatusClosed)];
        }
        final first = enrolled
            ? OrbitButton(
                label: l10n.faAlertsOpenFarmer,
                size: OrbitButtonSize.medium,
                onPressed: busy ? null : () => actions.onOpenFarmer(item),
              )
            : OrbitButton(
                label: l10n.faAlertsFinishEnrolment,
                size: OrbitButtonSize.medium,
                onPressed: busy ? null : () => actions.onFinishEnrolment(item),
              );
        final OrbitButton? second;
        if (!hasPhone) {
          second = null;
        } else if (item.canPlanVisit) {
          second = OrbitButton(
            label: l10n.faAlertsCallPlanVisit,
            size: OrbitButtonSize.medium,
            variant: OrbitButtonVariant.secondary,
            onPressed: busy ? null : () => actions.onCallAndPlan(item),
          );
        } else {
          // Not in the territory yet, or no crop to visit: a visit can be
          // planned once the enrolment is finished.
          second = OrbitButton(
            label: name == null
                ? l10n.faAlertsCallFarmer
                : l10n.commonCallName(name: name),
            size: OrbitButtonSize.medium,
            variant: OrbitButtonVariant.secondary,
            onPressed: busy ? null : () => actions.onCall(item),
          );
        }
        return [
          const SizedBox(height: OrbitSpace.s10),
          _ButtonPair(first: first, second: second),
        ];
      case AlertKind.callback:
        if (!item.callbackOpen) {
          return [
            status(l10n.faAlertsCallbackClosed, pending: item.pendingSync),
          ];
        }
        final callLabel = name == null
            ? l10n.faAlertsCallFarmer
            : l10n.commonCallName(name: name);
        return [
          const SizedBox(height: OrbitSpace.s2),
          Text(
            called ? l10n.faAlertsCloseCallbackHint : l10n.faAlertsCallbackHint,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: OrbitColors.of(context).textMuted,
              fontSize: 14,
            ),
          ),
          if (hasPhone) ...[
            const SizedBox(height: OrbitSpace.s10),
            OrbitButton(
              label: callLabel,
              icon: OrbitIcons.phone,
              size: OrbitButtonSize.medium,
              variant: called
                  ? OrbitButtonVariant.secondary
                  : OrbitButtonVariant.primary,
              onPressed: busy ? null : () => actions.onCall(item),
            ),
          ],
          if (called || !hasPhone) ...[
            const SizedBox(height: OrbitSpace.s8),
            OrbitButton(
              label: l10n.faAlertsCloseCallback,
              icon: OrbitIcons.check,
              size: OrbitButtonSize.medium,
              loading: busy,
              onPressed: busy ? null : () => actions.onCloseCallback(item),
            ),
          ],
        ];
      case AlertKind.hoNote:
        if (open) {
          return [
            const SizedBox(height: OrbitSpace.s10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OrbitButton(
                label: l10n.faAlertsGotIt,
                icon: OrbitIcons.check,
                size: OrbitButtonSize.medium,
                variant: OrbitButtonVariant.secondary,
                fullWidth: false,
                loading: busy,
                onPressed: busy ? null : () => actions.onAck(item),
              ),
            ),
          ];
        }
        return [
          status(
            a.status == AlertStatus.closed
                ? l10n.faAlertsStatusClosed
                : l10n.faAlertsAcknowledged,
            pending: item.pendingSync,
          ),
        ];
      case AlertKind.invoiceCheck || AlertKind.unknown:
        return const [];
    }
  }
}

/// Two buttons side by side (one fills the row when the other is missing).
class _ButtonPair extends StatelessWidget {
  const _ButtonPair({required this.first, this.second});

  final Widget first;
  final Widget? second;

  @override
  Widget build(BuildContext context) {
    final second = this.second;
    if (second == null) return first;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          const SizedBox(width: OrbitSpace.s8),
          Expanded(child: second),
        ],
      ),
    );
  }
}

/// A green tick and a line ("Acknowledged · HO can see you read it"), with
/// "Not synced yet" while the change waits to go up.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text, this.pending = false});

  final String text;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: OrbitSpace.s8),
      child: Wrap(
        spacing: OrbitSpace.s8,
        runSpacing: OrbitSpace.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  OrbitIcons.check,
                  size: OrbitSize.iconSm,
                  color: orbit.success.strong,
                ),
                const SizedBox(width: OrbitSpace.s6),
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: orbit.success.strong,
                      fontSize: 14,
                      fontWeight: OrbitFont.weightBold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (pending) const PendingSyncTag(),
        ],
      ),
    );
  }
}
