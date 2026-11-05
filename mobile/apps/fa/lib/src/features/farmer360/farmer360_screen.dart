import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/conflict_mine.dart';
import '../../shared/contact.dart';
import '../../shared/fa_header.dart';
import '../../shared/farmer_avatar.dart';
import '../../shared/formatters.dart';
import '../../shared/navigation.dart';
import '../../shared/pending_sync_tag.dart';
import '../enrol/consent_panel.dart';
import '../farmers/farmer_presenter.dart';
import 'edit_profile_sheet.dart';

/// A8 Farmer 360 for [farmerId].
///
/// Call, WhatsApp, Directions (the plot pin) and Start visit; then the
/// plots with crop, stage and day, the last visit with its issues and
/// advice, an open call-back (Close call-back once the FA has called), the
/// plan, consent, and the next planned visit (Plan a visit). Edit profile
/// saves name, Telugu name and language through `FaActions.updateFarmer`;
/// a clash with an HO edit shows here with Keep mine / Keep HO's.
///
/// A farmer ID the server merged into another still opens (the territory
/// follows the alias); an unknown one shows [NotFoundCard]. Wallet,
/// invoices, KYC, advisories listened and "Help on farmer's phone" are
/// later phases and not shown.
class Farmer360Screen extends StatelessWidget {
  /// Creates the screen.
  const Farmer360Screen({super.key, required this.farmerId});

  /// The farmer to show.
  final String farmerId;

  // The router reuses this page when a link opens another farmer: the key
  // starts that farmer's page fresh (no "called" or busy flag carried over).
  @override
  Widget build(BuildContext context) =>
      _Farmer360Page(key: ValueKey(farmerId), farmerId: farmerId);
}

class _Farmer360Page extends ConsumerStatefulWidget {
  const _Farmer360Page({super.key, required this.farmerId});

  final String farmerId;

  @override
  ConsumerState<_Farmer360Page> createState() => _Farmer360PageState();
}

class _Farmer360PageState extends ConsumerState<_Farmer360Page> {
  /// The FA called the farmer from here: offer Close call-back.
  bool _called = false;
  bool _busy = false;

  Future<void> _call(String phone) async {
    if (await callFarmer(context, ref, phone) && mounted) {
      setState(() => _called = true);
    }
  }

  Future<void> _run(
    Future<void> Function(FaActions a) action, {
    String? done,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action(ref.read(faActionsProvider));
      if (done != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(done)));
      }
    } on Object catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(faActionErrorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(SnapFarmer farmer) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (await showEditProfileSheet(context, farmer)) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.faFarmer360EditSaved)));
    }
  }

  /// Record consent uses Enrol's consent OTP flow (the same panel as Enrol
  /// step 1) in a sheet; it queues RecordConsent and says so itself.
  Future<void> _recordConsent(String farmerId) =>
      showRecordConsentSheet(context, farmerId: farmerId);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final territory = ref.watch(territoryProvider);
    final t = territory.value;
    final view = t?.farmer360(widget.farmerId);
    final language = contentLanguage(context);

    final Widget header;
    if (view == null) {
      header = FaHeader(title: l10n.faShellTitleFarmer, back: true);
    } else {
      final f = view.farmer;
      header = FaHeader(
        title: farmerName(f, language),
        subtitle: dotJoin(l10n, [
          formatIndianMobile(f.phone),
          view.row.village?.displayName(language),
        ]),
        back: true,
        leading: FarmerAvatar.of(f, outlined: true),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(
            child: AsyncValueView<Territory>(
              value: territory,
              onRetry: () => ref.invalidate(territoryProvider),
              data: (t) => view == null
                  ? NotFoundCard(onBack: () => goBack(context))
                  : _body(context, t, view),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, Territory t, Farmer360 v) {
    final l10n = context.l10n;
    final f = v.farmer;
    final conflicts = [
      for (final e in t.outbox)
        if (e.state == OutboxState.conflict &&
            e.type == CommandType.updateFarmer &&
            e.conflict != null &&
            t.resolveFarmerId(e.entityId) == f.id)
          e,
    ];
    final finish = finishEnrolmentRoute(v.row);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        OrbitSpace.s12,
        OrbitSpace.s16,
        OrbitSpace.s24,
      ),
      children: [
        for (final e in conflicts) ...[
          _conflictCard(context, t, f, e),
          const SizedBox(height: OrbitSpace.s12),
        ],
        if (v.pendingSync) ...[
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: PendingSyncTag(),
          ),
          const SizedBox(height: OrbitSpace.s12),
        ],
        _quickActions(context, t, v),
        const SizedBox(height: OrbitSpace.s12),
        _summary(context, t, v),
        if (finish != null && finish != AppRoutes.farmer(f.id)) ...[
          const SizedBox(height: OrbitSpace.s12),
          OrbitButton(
            label: l10n.faFarmersActionFinishEnrolment,
            icon: OrbitIcons.enrol,
            onPressed: () => openFrom(context, finish),
          ),
        ],
        const SizedBox(height: OrbitSpace.s12),
        OrbitButton(
          label: l10n.faFarmer360EditProfile,
          icon: OrbitIcons.edit,
          variant: OrbitButtonVariant.secondary,
          onPressed: _busy ? null : () => _edit(f),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Quick actions

  Widget _quickActions(BuildContext context, Territory t, Farmer360 v) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final orbit = OrbitColors.of(context);
    final f = v.farmer;
    final location = v.row.location;
    // Today's plan, or one left over from an earlier day: logging it makes
    // that plan done instead of leaving it overdue next to a new visit.
    final todays = t.startableVisitFor(f.id);
    String? plotId = todays?.plotId;
    if (plotId == null) {
      for (final p in v.plots) {
        if (p.season != null) {
          plotId = p.plot.id;
          break;
        }
      }
    }
    final canVisit = plotId != null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickAction(
              icon: OrbitIcons.phone,
              label: l10n.commonCall,
              color: scheme.primary,
              filled: true,
              onTap: () => _call(f.phone),
            ),
          ),
          const SizedBox(width: OrbitSpace.s8),
          Expanded(
            child: _QuickAction(
              icon: OrbitIcons.whatsApp,
              label: l10n.commonWhatsapp,
              color: orbit.success.fg,
              onTap: () => whatsAppFarmer(context, ref, f.phone),
            ),
          ),
          const SizedBox(width: OrbitSpace.s8),
          Expanded(
            child: _QuickAction(
              icon: OrbitIcons.directions,
              label: l10n.faFarmersActionDirections,
              onTap: location == null
                  ? null
                  : () => directionsTo(context, ref, location),
            ),
          ),
          const SizedBox(width: OrbitSpace.s8),
          Expanded(
            child: _QuickAction(
              icon: OrbitIcons.visit,
              label: l10n.faFarmer360StartVisit,
              color: scheme.primary,
              onTap: !canVisit
                  ? null
                  : () => openFrom(
                      context,
                      AppRoutes.visit(
                        farmerId: f.id,
                        visitId: todays?.id,
                        plotId: plotId,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary

  Widget _summary(BuildContext context, Territory t, Farmer360 v) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final language = contentLanguage(context);
    final f = v.farmer;
    final rows = <Widget>[
      if (v.plots.isEmpty)
        _SummaryRow(
          label: l10n.faFarmer360RowPlot,
          value: l10n.faFarmer360NoPlot,
        ),
      for (final p in v.plots) _plotRow(l10n, p, language),
      _lastVisitRow(l10n, v.lastDoneVisit, language),
      if (v.openCallback case final cb?)
        _SummaryRow(
          label: l10n.faFarmer360RowCallback,
          value: l10n.faFarmer360CallbackAsked(
            when: formatTimeAgo(l10n, cb.requestedAt, now: t.asOf),
          ),
          actions: [
            OrbitButton(
              label: l10n.commonCall,
              icon: OrbitIcons.phone,
              size: OrbitButtonSize.medium,
              variant: OrbitButtonVariant.secondary,
              onPressed: () => _call(f.phone),
            ),
            if (_called)
              OrbitButton(
                label: l10n.faFarmer360CallbackClose,
                icon: OrbitIcons.check,
                size: OrbitButtonSize.medium,
                loading: _busy,
                onPressed: _busy
                    ? null
                    : () => _run(
                        (a) => a.closeCallback(cb.id),
                        done: l10n.faFarmer360CallbackClosed,
                      ),
              ),
          ],
        ),
      _SummaryRow(
        label: l10n.faFarmer360RowPlan,
        value: f.plan == Plan.premium
            ? l10n.enumFarmerPlanPremium
            : l10n.enumFarmerPlanFree,
      ),
      _consentRow(l10n, v),
      _nextVisitRow(l10n, v, f, t.today),
    ];
    return Semantics(
      container: true,
      label: l10n.faFarmer360SummaryLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OrbitSpace.s16,
            vertical: OrbitSpace.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1.5,
                    thickness: 1.5,
                    color: scheme.surfaceContainerHighest,
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _plotRow(OrbitLocalizations l10n, PlotSummary p, Language language) {
    final day = p.daysAfterSowing;
    final String detail;
    if (p.season == null) {
      detail = l10n.faFarmer360PlotNoCrop;
    } else if (p.stage != null && day != null) {
      detail = l10n.faFarmer360PlotStageDay(
        stage: p.stage!.displayName(language),
        day: day,
      );
    } else if (day != null) {
      detail = l10n.faFarmer360PlotDay(day: day);
    } else {
      detail = '';
    }
    return _SummaryRow(
      label: l10n.faFarmer360RowPlot,
      value: dotJoin(l10n, [
        p.plot.label,
        p.crop?.displayName(language),
        formatArea(l10n, p.plot.areaAcres),
      ]),
      detail: detail.isEmpty ? null : detail,
      tag: p.pendingSync ? const PendingSyncTag() : null,
    );
  }

  Widget _lastVisitRow(
    OrbitLocalizations l10n,
    VisitRow? last,
    Language language,
  ) {
    if (last == null) {
      return _SummaryRow(
        label: l10n.faFarmer360RowLastVisit,
        value: l10n.faFarmer360NoVisit,
      );
    }
    final visit = last.visit;
    final issues = [
      for (final i in visit.issues)
        pickText(language, te: i.issueNameTe, en: i.issueName),
    ].where((s) => s.isNotEmpty);
    final advice = <String>[];
    var pending = false;
    for (final i in visit.issues) {
      if (i.adviceStatus != AdviceStatus.given) {
        pending = true;
        continue;
      }
      final product = pickText(
        language,
        te: i.productNameTe,
        en: i.productName,
      );
      final salt = pickText(language, te: i.saltNameTe, en: i.saltName);
      final text = product.isNotEmpty ? product : salt;
      if (text.isNotEmpty && !advice.contains(text)) advice.add(text);
    }
    final String detail;
    if (visit.issues.isEmpty) {
      detail = l10n.faFarmer360NoIssues;
    } else {
      detail = dotJoin(l10n, [
        if (advice.isNotEmpty)
          l10n.faFarmer360Advised(advice: advice.join(', ')),
        if (pending) l10n.enumAdviceStatusUnresolved,
      ]);
    }
    return _SummaryRow(
      label: l10n.faFarmer360RowLastVisit,
      value: dotJoin(l10n, [
        formatDateShort(l10n, LocalDate.istOf(visit.visitedAt!)),
        issues.join(', '),
      ]),
      detail: detail.isEmpty ? null : detail,
      tag: last.pendingSync ? const PendingSyncTag() : null,
    );
  }

  Widget _consentRow(OrbitLocalizations l10n, Farmer360 v) {
    if (v.consentPending) {
      return _SummaryRow(
        label: l10n.faFarmer360RowConsent,
        tag: StatusPill(
          label: l10n.faFarmer360ConsentPending,
          tone: OrbitStatusTone.warning,
          icon: OrbitIcons.warning,
        ),
        actions: [
          OrbitButton(
            label: l10n.faFarmer360RecordConsent,
            icon: OrbitIcons.consent,
            size: OrbitButtonSize.medium,
            variant: OrbitButtonVariant.secondary,
            onPressed: () => _recordConsent(v.farmer.id),
          ),
        ],
      );
    }
    final purposes = [
      for (final p in ConsentPurpose.values)
        if (p != ConsentPurpose.unknown) p,
    ];
    final granted = [
      for (final p in purposes)
        if (v.consentsGranted.contains(p)) _purposeLabel(l10n, p),
    ];
    return _SummaryRow(
      label: l10n.faFarmer360RowConsent,
      value: l10n.faFarmer360ConsentCount(
        count: granted.length,
        total: purposes.length,
      ),
      detail: granted.isEmpty ? null : granted.join(', '),
    );
  }

  static String _purposeLabel(OrbitLocalizations l10n, ConsentPurpose p) =>
      switch (p) {
        ConsentPurpose.programme => l10n.enumConsentPurposeProgramme,
        ConsentPurpose.soilPartner => l10n.enumConsentPurposeSoilPartner,
        ConsentPurpose.schemesFinance => l10n.enumConsentPurposeSchemesFinance,
        ConsentPurpose.loyalty => l10n.enumConsentPurposeLoyalty,
        ConsentPurpose.unknown => l10n.commonUnknown,
      };

  Widget _nextVisitRow(
    OrbitLocalizations l10n,
    Farmer360 v,
    SnapFarmer f,
    LocalDate today,
  ) {
    final next = v.plannedVisits.isEmpty ? null : v.plannedVisits.first;
    final visit = next?.visit;
    final overdue =
        visit != null &&
        (visit.status == VisitStatus.missed ||
            (visit.plannedFor?.isBefore(today) ?? false));
    final slot = switch (visit?.plannedSlot) {
      VisitSlot.morning => l10n.enumPlannedSlotMorning,
      VisitSlot.afternoon => l10n.enumPlannedSlotAfternoon,
      null => null,
      _ => l10n.enumPlannedSlotAny,
    };
    return _SummaryRow(
      label: l10n.faFarmer360RowNextVisit,
      value: visit == null
          ? l10n.faFarmer360NextVisitNone
          : dotJoin(l10n, [formatDateWeekday(l10n, visit.plannedFor!), slot]),
      detail: visit?.purpose,
      tag: overdue || (next?.pendingSync ?? false)
          ? Wrap(
              spacing: OrbitSpace.s6,
              runSpacing: OrbitSpace.s4,
              children: [
                if (overdue)
                  StatusPill(
                    label: l10n.faCalendarStatusOverdue,
                    tone: OrbitStatusTone.danger,
                    icon: OrbitIcons.warning,
                  ),
                if (next?.pendingSync ?? false) const PendingSyncTag(),
              ],
            )
          : null,
      actions: [
        OrbitButton(
          label: l10n.faFarmer360PlanVisit,
          icon: OrbitIcons.calendar,
          size: OrbitButtonSize.medium,
          variant: OrbitButtonVariant.secondary,
          onPressed: () =>
              openFrom(context, AppRoutes.planVisit(farmerId: f.id)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Conflict

  Widget _conflictCard(
    BuildContext context,
    Territory t,
    SnapFarmer f,
    OutboxEntry e,
  ) {
    final l10n = context.l10n;
    final c = e.conflict!;
    final yours = conflictMine(e);
    String show(Object? value) {
      if (value == null || value == '') return l10n.commonUnknown;
      return switch (c.field) {
        'language' =>
          Language.fromWire('$value') == Language.te
              ? l10n.enumLanguageTe
              : l10n.enumLanguageEn,
        'village_id' =>
          t.village('$value')?.displayName(contentLanguage(context)) ??
              l10n.commonUnknown,
        _ => '$value',
      };
    }

    return ConflictCard(
      title: l10n.faFarmer360ConflictTitle(
        name: farmerName(f, contentLanguage(context)),
      ),
      meta: yours.laterEdit
          ? dotJoin(l10n, [
              l10n.faFarmer360ConflictMeta,
              l10n.faSyncConflictWaiting,
            ])
          : l10n.faFarmer360ConflictMeta,
      statusLabel: l10n.faFarmer360ConflictStatus,
      mineLabel: l10n.faFarmer360ConflictMine,
      mineValue: show(yours.value),
      theirsLabel: l10n.faFarmer360ConflictTheirs,
      theirsValue: show(c.theirs),
      keepMineLabel: l10n.faFarmer360ConflictKeepMine,
      keepTheirsLabel: l10n.faFarmer360ConflictKeepTheirs,
      resolving: _busy,
      onKeepMine: e.canKeepMine ? () => _run((a) => a.keepMine(e.id)) : null,
      onKeepTheirs: () => _run((a) => a.keepTheirs(e.id)),
    );
  }
}

/// One row of the summary card: a muted label on the left, the value (and a
/// smaller detail line, a tag, buttons) on the right.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    this.value,
    this.detail,
    this.tag,
    this.actions = const [],
  });

  final String label;
  final String? value;
  final String? detail;
  final Widget? tag;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: OrbitSize.controlLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OrbitSpace.s10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontSize: 14,
                  color: orbit.textMuted,
                  fontWeight: OrbitFont.weightSemibold,
                ),
              ),
            ),
            const SizedBox(width: OrbitSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value case final value?)
                    Text(
                      value,
                      style: theme.textTheme.bodyLarge!.copyWith(
                        fontSize: 15,
                        fontWeight: OrbitFont.weightBold,
                        height: 1.3,
                      ),
                    ),
                  if (detail case final detail?)
                    Text(
                      detail,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        fontSize: 14,
                        color: orbit.textMuted,
                        fontWeight: OrbitFont.weightSemibold,
                      ),
                    ),
                  if (tag case final tag?) ...[
                    const SizedBox(height: OrbitSpace.s4),
                    tag,
                  ],
                  for (final a in actions) ...[
                    const SizedBox(height: OrbitSpace.s8),
                    a,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // Rows with buttons keep them as separate nodes.
    return actions.isEmpty ? MergeSemantics(child: row) : row;
  }
}

/// A Farmer 360 quick action: icon over a label, 64 dp tall.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final base = color ?? scheme.onSurface;
    final fg = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : filled
        ? scheme.onPrimary
        : base;
    final border = !enabled
        ? scheme.outlineVariant
        : filled
        ? base
        : (color ?? scheme.outline);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: filled && enabled ? base : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
          side: BorderSide(color: border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: OrbitSize.controlXxl),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OrbitSpace.s4,
                vertical: OrbitSpace.s8,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: OrbitSize.iconLg),
                  const SizedBox(height: OrbitSpace.s4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: fg,
                      fontSize: 13,
                      fontWeight: OrbitFont.weightBold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
