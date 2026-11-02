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
import '../../shared/fa_header.dart';
import '../../shared/farmer_avatar.dart';
import '../../shared/formatters.dart';
import '../../shared/navigation.dart';
import '../../shared/pending_sync_tag.dart';
import 'calendar_state.dart';
import 'visit_ui.dart';

/// Plan a visit, for [farmerId] when it is known.
///
/// Without a farmer it first lists the territory's farmers, nearest first,
/// with a search; farmers with no crop can't be picked. Then: the plot (its
/// active crop), the day (today to 13 days ahead: chips for the coming week
/// and a date picker), the time (morning, afternoon, any) and the purpose
/// (chips saved as their English text, or the FA's own words). Save plans it
/// through `FaActions.planVisit` and goes back to the calendar on that day
/// with a notice.
///
/// Opened by "Move to another day" ([rescheduleRequestProvider]) it starts
/// from that visit, keeps its plot and saves through
/// `FaActions.replanVisit` (the same visit, a new day, time or purpose).
class PlanVisitScreen extends StatelessWidget {
  /// Creates the screen.
  const PlanVisitScreen({super.key, this.farmerId});

  /// The farmer to plan for, or null to pick one.
  final String? farmerId;

  /// How many days ahead a visit can be planned (today included).
  static const daysAhead = 14;

  /// Most characters of a purpose the FA types.
  static const purposeMaxLength = 80;

  // The router reuses this page when a link plans for another farmer: the
  // key starts the form over for that farmer instead of keeping the last one.
  @override
  Widget build(BuildContext context) =>
      _PlanVisitPage(key: ValueKey(farmerId), farmerId: farmerId);
}

class _PlanVisitPage extends ConsumerStatefulWidget {
  const _PlanVisitPage({super.key, this.farmerId});

  final String? farmerId;

  @override
  ConsumerState<_PlanVisitPage> createState() => _PlanVisitPageState();
}

class _PlanVisitPageState extends ConsumerState<_PlanVisitPage> {
  final _search = TextEditingController();
  final _otherText = TextEditingController();
  String? _farmerId;
  String? _moving;
  bool _prefilled = false;
  String? _plotId;
  LocalDate? _day;
  VisitSlot _slot = VisitSlot.any;
  VisitPurpose? _purpose;
  bool _other = false;
  bool _saving = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _farmerId = widget.farmerId;
    _moving = ref.read(rescheduleRequestProvider);
    if (_moving != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(rescheduleRequestProvider.notifier).take();
      });
    }
    _search.addListener(() => setState(() {}));
    _otherText.addListener(() {
      if (_showErrors) setState(() {});
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _otherText.dispose();
    super.dispose();
  }

  /// Fills the form from the visit being moved, once.
  void _prefill(Territory t) {
    if (_prefilled) return;
    _prefilled = true;
    final v = _moving == null ? null : t.visit(_moving!);
    if (v == null ||
        !Territory.isOpenPlan(v) ||
        (_farmerId != null && t.resolveFarmerId(_farmerId!) != v.farmerId)) {
      _moving = null;
      return;
    }
    _farmerId = v.farmerId;
    _plotId = v.plotId;
    _slot = v.plannedSlot == null || v.plannedSlot == VisitSlot.unknown
        ? VisitSlot.any
        : v.plannedSlot!;
    final known = VisitPurpose.match(v.purpose);
    if (known != null) {
      _purpose = known;
    } else if (v.purpose?.trim().isNotEmpty ?? false) {
      _other = true;
      _otherText.text = v.purpose!.trim();
    }
  }

  bool get _pickedHere => widget.farmerId == null && _farmerId != null;

  void _back() {
    if (_pickedHere && _moving == null) {
      setState(() {
        _farmerId = null;
        _plotId = null;
        _showErrors = false;
      });
      return;
    }
    goBack(context, fallback: AppRoutes.calendar);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final territory = ref.watch(territoryProvider);
    final t = territory.value;
    if (t != null) _prefill(t);
    final farmer = t == null || _farmerId == null ? null : t.farmer(_farmerId!);
    return PopScope(
      canPop: !_pickedHere || _moving != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Column(
          children: [
            FaHeader(
              title: _moving != null
                  ? l10n.faPlanVisitRescheduleTitle
                  : l10n.faShellTitlePlanVisit,
              subtitle: farmer == null
                  ? null
                  : farmerName(farmer, contentLanguage(context)),
              onBack: _back,
            ),
            Expanded(
              child: AsyncValueView(
                value: territory,
                onRetry: () => ref.invalidate(territoryProvider),
                data: (t) {
                  if (_farmerId == null) return _picker(t);
                  final f = t.farmer(_farmerId!);
                  if (f == null) return NotFoundCard(onBack: _back);
                  return _form(t, f);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Farmer picker

  Widget _picker(Territory t) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final language = contentLanguage(context);
    final from = currentPoint(ref.watch(currentFixProvider));
    final rows = t.farmerRows(from: from, query: _search.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OrbitSpace.s16,
            OrbitSpace.s12,
            OrbitSpace.s16,
            OrbitSpace.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepHeading(
                l10n.faPlanVisitPickFarmer,
                detail: from == null ? null : l10n.faPlanVisitNearestFirst,
              ),
              const SizedBox(height: OrbitSpace.s8),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.faPlanVisitSearchHint,
                  hintMaxLines: 2,
                  prefixIcon: const Icon(OrbitIcons.search),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(OrbitSpace.s16),
                    child: StateCard(
                      icon: OrbitIcons.search,
                      title: l10n.faPlanVisitNoMatch,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OrbitSpace.s16,
                    vertical: OrbitSpace.s8,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: OrbitSpace.s6),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final crop = r.plots
                        .where((p) => p.season != null)
                        .firstOrNull;
                    final canPlan = crop != null;
                    final detail = dotJoin(l10n, [
                      r.village?.displayName(language),
                      if (canPlan)
                        crop.crop?.displayName(language)
                      else
                        l10n.faPlanVisitNoCrop,
                      if (r.distanceKm case final km?)
                        formatDistance(l10n, km * 1000),
                    ]);
                    return Material(
                      color: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(OrbitRadius.lg),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(OrbitRadius.lg),
                        ),
                        onTap: canPlan
                            ? () => setState(() {
                                _farmerId = r.farmer.id;
                                _plotId = null;
                              })
                            : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: OrbitSpace.s12,
                              vertical: OrbitSpace.s8,
                            ),
                            child: Row(
                              children: [
                                FarmerAvatar.of(r.farmer, size: 40),
                                const SizedBox(width: OrbitSpace.s10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        farmerName(r.farmer, language),
                                        style: theme.textTheme.titleSmall!
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: canPlan
                                                  ? null
                                                  : orbit.textMuted,
                                            ),
                                      ),
                                      Text(
                                        detail,
                                        style: theme.textTheme.bodySmall!
                                            .copyWith(color: orbit.textMuted),
                                      ),
                                      if (r.pendingSync) ...[
                                        const SizedBox(height: OrbitSpace.s4),
                                        const PendingSyncTag(),
                                      ],
                                    ],
                                  ),
                                ),
                                if (canPlan)
                                  Icon(
                                    OrbitIcons.chevronRight,
                                    color: orbit.textMuted,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // The plan

  Widget _form(Territory t, SnapFarmer f) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final language = contentLanguage(context);
    final today = t.today;
    final moving = _moving == null ? null : t.visit(_moving!);
    final movingPlot = moving == null ? null : t.plot(moving.plotId);
    // A re-plan keeps the visit's plot (the server refuses another one).
    final plots = movingPlot != null
        ? [t.plotSummary(movingPlot)]
        : [
            for (final p in t.plotsOf(f.id))
              if (t.activeSeason(p.id) != null) t.plotSummary(p),
          ];
    if (plots.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OrbitSpace.s16),
          child: StateCard(
            icon: OrbitIcons.crop,
            title: l10n.faPlanVisitNoCropTitle,
            subtitle: l10n.faPlanVisitNoCropBody(name: farmerName(f, language)),
            action: OrbitButton(
              label: l10n.commonBack,
              icon: OrbitIcons.back,
              variant: OrbitButtonVariant.secondary,
              onPressed: _back,
            ),
          ),
        ),
      );
    }
    final plot =
        plots.where((p) => p.plot.id == _plotId).firstOrNull ?? plots.first;
    final day = _day ?? today;
    final purpose =
        _purpose ??
        (_other
            ? null
            : t.lastDoneVisit(f.id) == null
            ? VisitPurpose.firstVisit
            : VisitPurpose.stageCheck);
    final otherMissing = _other && _otherText.text.trim().isEmpty;
    final quickDays = [for (var i = 0; i < 7; i++) today.addDays(i)];
    final pickedLater = !quickDays.contains(day);

    String dayLabel(LocalDate d) {
      final n = today.daysUntil(d);
      if (n == 0) return l10n.commonToday;
      if (n == 1) return l10n.commonTomorrow;
      return formatDateWeekday(l10n, d);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              OrbitSpace.s16,
              OrbitSpace.s12,
              OrbitSpace.s16,
              OrbitSpace.s16,
            ),
            children: [
              if (_pickedHere && _moving == null) ...[
                Row(
                  children: [
                    FarmerAvatar.of(f, size: 40),
                    const SizedBox(width: OrbitSpace.s10),
                    Expanded(
                      child: Text(
                        farmerName(f, language),
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: OrbitFont.weightExtrabold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _back,
                      child: Text(l10n.faPlanVisitChangeFarmer),
                    ),
                  ],
                ),
                const SizedBox(height: OrbitSpace.s12),
              ],
              if (moving?.plannedFor case final from?) ...[
                Text(
                  l10n.faPlanVisitMovingFrom(
                    date: formatDateWeekday(l10n, from),
                  ),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: orbit.textMuted,
                  ),
                ),
                const SizedBox(height: OrbitSpace.s12),
              ],
              StepHeading(l10n.faPlanVisitPlot),
              const SizedBox(height: OrbitSpace.s8),
              OptionChipWrap(
                label: l10n.faPlanVisitPlot,
                children: [
                  for (final p in plots)
                    OptionChip(
                      label: dotJoin(l10n, [
                        p.plot.label,
                        p.crop?.displayName(language),
                      ]),
                      selected: p.plot.id == plot.plot.id,
                      onTap: () => setState(() => _plotId = p.plot.id),
                    ),
                ],
              ),
              const SizedBox(height: OrbitSpace.s16),
              StepHeading(l10n.faPlanVisitDay),
              const SizedBox(height: OrbitSpace.s8),
              OptionChipWrap(
                label: l10n.faPlanVisitDay,
                children: [
                  for (final d in quickDays)
                    OptionChip(
                      label: dayLabel(d),
                      selected: d == day,
                      onTap: () => setState(() => _day = d),
                    ),
                  OptionChip(
                    label: pickedLater
                        ? formatDateWeekday(l10n, day)
                        : l10n.faPlanVisitOtherDate,
                    icon: OrbitIcons.calendar,
                    selected: pickedLater,
                    onTap: () => _pickDate(today, day),
                  ),
                ],
              ),
              const SizedBox(height: OrbitSpace.s16),
              StepHeading(l10n.faPlanVisitSlot),
              const SizedBox(height: OrbitSpace.s8),
              SegmentedTabs(
                labels: [for (final s in _slots) slotLabel(l10n, s)],
                selectedIndex: _slots.indexOf(_slot),
                onChanged: (i) => setState(() => _slot = _slots[i]),
              ),
              const SizedBox(height: OrbitSpace.s16),
              StepHeading(l10n.faPlanVisitPurpose),
              const SizedBox(height: OrbitSpace.s8),
              OptionChipWrap(
                label: l10n.faPlanVisitPurpose,
                children: [
                  for (final p in VisitPurpose.values)
                    OptionChip(
                      label: p.label(l10n),
                      selected: !_other && p == purpose,
                      onTap: () => setState(() {
                        _purpose = p;
                        _other = false;
                      }),
                    ),
                  OptionChip(
                    label: l10n.faPlanVisitPurposeOther,
                    selected: _other,
                    onTap: () => setState(() => _other = true),
                  ),
                ],
              ),
              if (_other) ...[
                const SizedBox(height: OrbitSpace.s8),
                TextField(
                  controller: _otherText,
                  maxLength: PlanVisitScreen.purposeMaxLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.faPlanVisitPurposeHint,
                    hintMaxLines: 2,
                    errorText: _showErrors && otherMissing
                        ? l10n.faPlanVisitPurposeRequired
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
        _Footer(
          label: _moving != null ? l10n.faPlanVisitMove : l10n.faPlanVisitSave,
          note: l10n.faPlanVisitSavedOffline,
          saving: _saving,
          onPressed: () => _save(
            f,
            plot,
            day,
            _other ? _otherText.text : purpose?.wire,
            today,
          ),
        ),
      ],
    );
  }

  static const _slots = [VisitSlot.morning, VisitSlot.afternoon, VisitSlot.any];

  Future<void> _pickDate(LocalDate today, LocalDate current) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: today.toDateTime(),
      lastDate: today.addDays(PlanVisitScreen.daysAhead - 1).toDateTime(),
      initialDate: current.toDateTime(),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = LocalDate(picked.year, picked.month, picked.day));
  }

  Future<void> _save(
    SnapFarmer f,
    PlotSummary plot,
    LocalDate day,
    String? purpose,
    LocalDate today,
  ) async {
    if (_saving) return;
    if (_other && (purpose == null || purpose.trim().isEmpty)) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final actions = ref.read(faActionsProvider);
    try {
      final moving = _moving;
      final String id;
      if (moving != null) {
        await actions.replanVisit(
          moving,
          plannedFor: day,
          slot: _slot,
          purpose: purpose ?? '',
        );
        id = moving;
      } else {
        id = await actions.planVisit(
          farmerId: f.id,
          plotId: plot.plot.id,
          seasonId: plot.season?.id,
          plannedFor: day,
          slot: _slot,
          purpose: purpose,
        );
      }
      ref.read(calendarDayProvider.notifier).show(day == today ? null : day);
      ref
          .read(visitNoticeProvider.notifier)
          .show(
            VisitNotice(
              kind: moving != null
                  ? VisitNoticeKind.moved
                  : VisitNoticeKind.planned,
              farmerId: f.id,
              visitId: id,
              day: day,
            ),
          );
      if (mounted) context.go(AppRoutes.calendar);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showActionError(context, e);
    }
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.label,
    required this.note,
    required this.saving,
    required this.onPressed,
  });

  final String label;
  final String note;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OrbitSpace.s16,
            OrbitSpace.s10,
            OrbitSpace.s16,
            OrbitSpace.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: OrbitColors.of(context).textMuted,
                ),
              ),
              const SizedBox(height: OrbitSpace.s8),
              OrbitButton(label: label, loading: saving, onPressed: onPressed),
            ],
          ),
        ),
      ),
    );
  }
}
