import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/contact.dart';
import '../../shared/fa_header.dart';
import '../../shared/formatters.dart';
import '../../shared/pending_sync_tag.dart';
import 'calendar_state.dart';
import 'visit_ui.dart';

/// A3 Visit calendar: a week strip, the picked day's visits by slot
/// (Morning, Afternoon, Any time) and what can be done with them.
///
/// * The header shows the day with its visit and done counts; Add opens Plan
///   a visit.
/// * The strip shows the Monday-to-Sunday week of the picked day with a dot
///   per visit; the arrows move a week (plans go 14 days ahead).
/// * A planned visit of today (or one left over from an earlier day) has
///   Start visit (the visit log) and Call. Every planned visit has a menu
///   (also on long-press): Move to another day, Cancel visit.
/// * After a visit is planned, moved, cancelled or logged, a notice shows on
///   its day ([visitNoticeProvider]).
/// * "Plan my route" is Phase 3 and left out.
class CalendarScreen extends ConsumerWidget {
  /// Creates the screen.
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final territory = ref.watch(territoryProvider);
    final t = territory.value;
    String? subtitle;
    if (t != null) {
      final day = ref.watch(calendarDayProvider) ?? t.today;
      final plan = t.visitsOn(day);
      subtitle = dotJoin(l10n, [
        formatDateWeekday(l10n, day),
        l10n.faCalendarVisitCount(count: plan.count),
        if (plan.count > 0) l10n.faCalendarDoneCount(count: plan.doneCount),
      ]);
    }
    return Scaffold(
      body: Column(
        children: [
          FaHeader(
            title: l10n.faCalendarTitle,
            subtitle: subtitle,
            showMe: true,
            actions: [
              HeaderPillButton(
                label: l10n.faCalendarAdd,
                semanticLabel: l10n.faShellTitlePlanVisit,
                icon: OrbitIcons.add,
                onPressed: () => context.push(AppRoutes.planVisit()),
              ),
            ],
          ),
          Expanded(
            child: AsyncValueView(
              value: territory,
              onRetry: () => ref.invalidate(territoryProvider),
              data: (t) => _CalendarBody(territory: t),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({required this.territory});

  final Territory territory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final t = territory;
    final today = t.today;
    final day = ref.watch(calendarDayProvider) ?? today;
    final weekStart = day.addDays(1 - day.weekday);
    final counts = t.weekCounts(weekStart);
    final plan = t.visitsOn(day);
    // Visits whose day passed without a log (planned or missed) show under
    // today too, so they can still be started or moved.
    final overdue = day == today ? t.overdueVisits() : const <VisitRow>[];
    final from = currentPoint(ref.watch(currentFixProvider));
    final notice = ref.watch(visitNoticeProvider);
    final online = ref.watch(phoneOnlineProvider);
    final days = ref.read(calendarDayProvider.notifier);
    final thisWeek = today.addDays(1 - today.weekday) == weekStart;

    void pick(LocalDate d) => days.show(d == today ? null : d);

    List<Widget> section(String title, List<VisitRow> rows) => [
      if (rows.isNotEmpty) ...[
        const SizedBox(height: OrbitSpace.s12),
        Semantics(
          header: true,
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: OrbitFont.weightExtrabold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        for (final r in rows) ...[
          const SizedBox(height: OrbitSpace.s8),
          _VisitCard(
            row: r,
            today: today,
            from: from,
            firstVisit:
                Territory.isOpenPlan(r.visit) &&
                r.farmer != null &&
                t.lastDoneVisit(r.farmer!.id) == null,
            justSaved:
                notice?.kind == VisitNoticeKind.saved &&
                notice?.visitId == r.visit.id,
          ),
        ],
      ],
    ];

    // 12 dp sides leave 336 dp on a 360 dp phone: seven 48 dp days.
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s12,
        OrbitSpace.s8,
        OrbitSpace.s12,
        OrbitSpace.s24,
      ),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => days.show(day.addDays(-7)),
              icon: const Icon(OrbitIcons.chevronLeft),
              tooltip: l10n.faCalendarPreviousWeek,
            ),
            Expanded(
              child: thisWeek
                  ? Text(
                      l10n.faCalendarWeekOf(
                        date: formatDateShort(l10n, weekStart),
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: orbit.textMuted,
                      ),
                    )
                  : Center(
                      child: TextButton(
                        onPressed: () => days.show(null),
                        child: Text(
                          dotJoin(l10n, [
                            l10n.faCalendarWeekOf(
                              date: formatDateShort(l10n, weekStart),
                            ),
                            l10n.faCalendarThisWeek,
                          ]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
            IconButton(
              onPressed: () => days.show(day.addDays(7)),
              icon: const Icon(OrbitIcons.chevronRight),
              tooltip: l10n.faCalendarNextWeek,
            ),
          ],
        ),
        DayStrip(
          semanticLabel: l10n.faCalendarWeekOf(
            date: formatDateShort(l10n, weekStart),
          ),
          selectedIndex: day.weekday - 1,
          onSelected: (i) => pick(weekStart.addDays(i)),
          days: [
            for (final c in counts)
              DayStripDay(
                weekday: formatWeekdayShort(l10n, c.day),
                day: formatDayOfMonth(l10n, c.day),
                dots: c.total,
                isToday: c.day == today,
                semanticLabel: l10n.faCalendarDayLabel(
                  date: formatDateWeekday(l10n, c.day),
                  count: c.total,
                ),
              ),
          ],
        ),
        if (!online) ...[
          const SizedBox(height: OrbitSpace.s12),
          OrbitBanner(
            kind: OrbitBannerKind.offline,
            title: l10n.faCalendarOffline,
          ),
        ],
        if (notice != null && notice.day == day) ...[
          const SizedBox(height: OrbitSpace.s12),
          NoticeStrip(
            message: _noticeText(context, t, notice),
            onClose: () => ref.read(visitNoticeProvider.notifier).clear(),
          ),
        ],
        ...section(l10n.faCalendarStatusOverdue, overdue),
        ...section(l10n.enumPlannedSlotMorning, plan.morning),
        ...section(l10n.enumPlannedSlotAfternoon, plan.afternoon),
        ...section(l10n.enumPlannedSlotAny, plan.anytime),
        if (plan.isEmpty && overdue.isEmpty) ...[
          const SizedBox(height: OrbitSpace.s16),
          StateCard(
            icon: OrbitIcons.calendar,
            title: l10n.faCalendarEmptyTitle,
            subtitle: l10n.faCalendarEmptyBody,
            action: OrbitButton(
              label: l10n.faCalendarFindDue,
              icon: OrbitIcons.people,
              variant: OrbitButtonVariant.secondary,
              size: OrbitButtonSize.medium,
              onPressed: () =>
                  context.go(AppRoutes.farmersFiltered(FarmerFilter.visitDue)),
            ),
          ),
        ],
        const SizedBox(height: OrbitSpace.s16),
        Text(
          l10n.faCalendarFooterNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall!.copyWith(
            color: orbit.textMuted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  static String _noticeText(
    BuildContext context,
    Territory t,
    VisitNotice notice,
  ) {
    final l10n = context.l10n;
    final name = farmerName(
      t.farmer(notice.farmerId),
      contentLanguage(context),
    );
    final date = formatDateWeekday(l10n, notice.day);
    return switch (notice.kind) {
      VisitNoticeKind.saved when !notice.hasAdvice =>
        l10n.faCalendarSavedNoAdvice(name: name),
      VisitNoticeKind.saved =>
        t.isPending(notice.visitId)
            ? l10n.faCalendarSavedPending(name: name)
            : l10n.faCalendarSavedSent(name: name),
      VisitNoticeKind.planned => l10n.faCalendarPlanned(name: name, date: date),
      VisitNoticeKind.moved => l10n.faCalendarMoved(name: name, date: date),
      VisitNoticeKind.cancelled => l10n.faCalendarCancelled(name: name),
    };
  }
}

class _VisitCard extends ConsumerWidget {
  const _VisitCard({
    required this.row,
    required this.today,
    required this.from,
    required this.firstVisit,
    required this.justSaved,
  });

  final VisitRow row;
  final LocalDate today;
  final LatLng? from;
  final bool firstVisit;
  final bool justSaved;

  /// Still to do: planned, or missed (its day passed without a log).
  bool get _planned => Territory.isOpenPlan(row.visit);

  /// Still to do and its day has passed (the server marks such a visit
  /// missed; until the next pull the phone sees the date).
  bool get _overdue {
    final day = row.visit.plannedFor;
    return row.visit.status == VisitStatus.missed ||
        (_planned && day != null && day.isBefore(today));
  }

  /// Today's planned visit, or one left over from an earlier day.
  bool get _canStart {
    final day = row.visit.plannedFor;
    return _planned && day != null && !day.isAfter(today);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final language = contentLanguage(context);
    final name = farmerName(row.farmer, language);
    final plot = row.plot;
    final at = plot == null ? null : plotLocation(plot);
    final distance = _planned && from != null && at != null
        ? formatDistance(l10n, distanceKm(from!, at) * 1000)
        : null;
    final meta = dotJoin(l10n, [
      plot?.label,
      row.crop?.displayName(language),
      purposeText(l10n, row.visit.purpose),
      distance,
    ]);
    final pill = row.isDone
        ? StatusPill(
            label: l10n.faCalendarStatusDone,
            tone: OrbitStatusTone.success,
          )
        : _overdue
        ? StatusPill(
            label: l10n.faCalendarStatusOverdue,
            tone: OrbitStatusTone.danger,
            icon: OrbitIcons.warning,
          )
        : firstVisit
        ? StatusPill(
            label: l10n.faCalendarStatusFirstVisit,
            tone: OrbitStatusTone.warning,
            icon: OrbitIcons.add,
          )
        : StatusPill(
            label: l10n.faCalendarStatusPlanned,
            tone: OrbitStatusTone.neutral,
            icon: OrbitIcons.pending,
          );
    final border = _canStart
        ? scheme.primary
        : justSaved
        ? orbit.success.strong
        : scheme.outlineVariant;
    const radius = BorderRadius.all(Radius.circular(OrbitRadius.xl));

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: border, width: 1.5),
      ),
      child: InkWell(
        borderRadius: radius,
        onLongPress: _planned ? () => _openMenu(context, ref, name) : null,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            OrbitSpace.s12,
            OrbitSpace.s12,
            OrbitSpace.s4,
            OrbitSpace.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: OrbitSpace.s2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium!.copyWith(
                              fontSize: 16,
                              fontWeight: OrbitFont.weightExtrabold,
                            ),
                          ),
                          if (meta.isNotEmpty)
                            Text(
                              meta,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          const SizedBox(height: OrbitSpace.s6),
                          Wrap(
                            spacing: OrbitSpace.s6,
                            runSpacing: OrbitSpace.s4,
                            children: [
                              pill,
                              if (row.pendingSync) const PendingSyncTag(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_planned)
                    IconButton(
                      onPressed: () => _openMenu(context, ref, name),
                      icon: const Icon(OrbitIcons.more),
                      tooltip: l10n.faCalendarVisitOptions(name: name),
                    )
                  else
                    const SizedBox(width: OrbitSpace.s8),
                ],
              ),
              if (_canStart) ...[
                const SizedBox(height: OrbitSpace.s10),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: OrbitSpace.s8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: OrbitButton(
                          label: l10n.faCalendarStartVisit,
                          icon: OrbitIcons.visit,
                          variant: OrbitButtonVariant.secondary,
                          size: OrbitButtonSize.medium,
                          onPressed: () => context.push(
                            AppRoutes.visit(
                              farmerId: row.visit.farmerId,
                              visitId: row.visit.id,
                              plotId: row.visit.plotId,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: OrbitSpace.s8),
                      Expanded(
                        child: OrbitButton(
                          label: l10n.commonCall,
                          icon: OrbitIcons.phone,
                          variant: OrbitButtonVariant.secondary,
                          size: OrbitButtonSize.medium,
                          onPressed: row.farmer == null
                              ? null
                              : () =>
                                    callFarmer(context, ref, row.farmer!.phone),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final l10n = context.l10n;
    final danger = OrbitColors.of(context).danger.strong;
    final choice = await showModalBottomSheet<_MenuChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OrbitSpace.s16,
                0,
                OrbitSpace.s16,
                OrbitSpace.s8,
              ),
              child: Text(name, style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(OrbitIcons.calendar),
              title: Text(l10n.faCalendarReschedule),
              onTap: () => Navigator.pop(context, _MenuChoice.reschedule),
            ),
            ListTile(
              leading: Icon(OrbitIcons.close, color: danger),
              title: Text(
                l10n.faCalendarCancelVisit,
                style: TextStyle(color: danger),
              ),
              onTap: () => Navigator.pop(context, _MenuChoice.cancel),
            ),
            const SizedBox(height: OrbitSpace.s8),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case _MenuChoice.reschedule:
        ref.read(rescheduleRequestProvider.notifier).request(row.visit.id);
        await context.push(AppRoutes.planVisit(farmerId: row.visit.farmerId));
      case _MenuChoice.cancel:
        await _cancel(context, ref, name);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, String name) async {
    final l10n = context.l10n;
    final day = row.visit.plannedFor;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.faCalendarCancelTitle(name: name)),
        content: day == null
            ? null
            : Text(
                l10n.faCalendarCancelBody(date: formatDateWeekday(l10n, day)),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.faCalendarKeepVisit),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: OrbitColors.of(context).danger.strong,
            ),
            child: Text(l10n.faCalendarCancelVisit),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      await ref.read(faActionsProvider).cancelVisit(row.visit.id);
      ref
          .read(visitNoticeProvider.notifier)
          .show(
            VisitNotice(
              kind: VisitNoticeKind.cancelled,
              farmerId: row.visit.farmerId,
              visitId: row.visit.id,
              // An overdue visit is shown under today: say it there.
              day: day == null || day.isBefore(today) ? today : day,
            ),
          );
    } on Object catch (e) {
      if (context.mounted) showActionError(context, e);
    }
  }
}

enum _MenuChoice { reschedule, cancel }
