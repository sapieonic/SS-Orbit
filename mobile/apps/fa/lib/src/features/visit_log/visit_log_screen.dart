import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../device/device.dart';
import '../../local/commands.dart' show LogVisitPayload;
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/fa_header.dart';
import '../../shared/formatters.dart';
import '../../shared/navigation.dart';
import '../calendar/calendar_state.dart';
import '../calendar/visit_ui.dart';
import 'visit_log_widgets.dart';

/// A5 visit log: a planned visit ([visitId]) or a new visit for
/// [farmerId], on [plotId] when it is known.
///
/// Five steps: photos (camera, aim 1 to 3, at most 20), the crop stage
/// (preselected from days after sowing), the issue (type, the crop's issue
/// list in both languages, how bad), the salt the masters suggest for it
/// (with the Shanmukha product or "salt name only"; no rule: HO follows up),
/// more issues, and the next visit. The footer shows the GPS fix, the time
/// and whether the farmer was there; "Save & tell farmer" saves it on the
/// phone through `FaActions.logVisit` with the server-corrected time.
///
/// Then the "Visit saved" summary: the SMS to the farmer is only promised
/// once the visit syncs. "Edit this visit" shows while the log is still
/// queued and was never sent (`FaActions.editQueuedVisit`).
///
/// Validation: a stage (when the crop has stages), a severity for each
/// issue; no photos only asks first.
class VisitLogScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const VisitLogScreen({
    super.key,
    required this.farmerId,
    this.visitId,
    this.plotId,
  });

  /// The farmer visited.
  final String farmerId;

  /// The planned visit being logged, or null for a new visit.
  final String? visitId;

  /// The plot visited, when known.
  final String? plotId;

  @override
  ConsumerState<VisitLogScreen> createState() => _VisitLogScreenState();
}

/// A photo taken on this screen; [savedId] once it is in the saved log.
final class _Photo {
  _Photo(this.bytes, this.contentType);

  final Uint8List bytes;
  final PhotoContentType contentType;
  String? savedId;
}

/// One issue being entered.
final class _Issue {
  _Issue(this.type);

  IssueType type;
  String? issueId;
  Severity? severity;
  String? ruleId;

  bool get picked => issueId != null;

  bool get complete => picked && severity != null;

  _Issue copy() => _Issue(type)
    ..issueId = issueId
    ..severity = severity
    ..ruleId = ruleId;
}

/// The form as it was when "Edit this visit" was tapped, to go back to.
final class _Form {
  _Form(_VisitLogScreenState s)
    : stageId = s._stageId,
      stageTouched = s._stageTouched,
      photos = [...s._photos],
      issues = [for (final i in s._issues) i.copy()],
      next = s._next,
      nextOther = s._nextOther,
      present = s._present;

  final String? stageId;
  final bool stageTouched;
  final List<_Photo> photos;
  final List<_Issue> issues;
  final _Next next;
  final LocalDate? nextOther;
  final bool present;

  void restore(_VisitLogScreenState s) {
    s
      .._stageId = stageId
      .._stageTouched = stageTouched
      .._next = next
      .._nextOther = nextOther
      .._present = present;
    s._photos
      ..clear()
      ..addAll(photos);
    s._issues
      ..clear()
      ..addAll(issues);
  }
}

enum _Next { week, stage, other, none }

/// Everything the screen resolved from the territory for this visit.
final class _Target {
  const _Target({
    required this.farmer,
    required this.plot,
    required this.season,
    required this.crop,
    required this.plots,
  });

  final SnapFarmer farmer;
  final SnapPlot plot;
  final SnapSeason season;
  final SnapCrop? crop;

  /// The farmer's plots with a crop (for the plot chips of a new visit).
  final List<PlotSummary> plots;

  List<SnapStage> get stages =>
      [...?crop?.stages]..sort((a, b) => a.seq.compareTo(b.seq));
}

class _VisitLogScreenState extends ConsumerState<VisitLogScreen> {
  String? _plotId;
  String? _stageId;
  bool _stageTouched = false;
  final _photos = <_Photo>[];
  final _issues = <_Issue>[];
  _Next _next = _Next.week;
  LocalDate? _nextOther;
  bool _present = true;

  LocationFix? _fix;
  bool _locating = true;
  bool _taking = false;
  bool _saving = false;
  bool _showErrors = false;

  /// The saved log, once saved.
  LoggedVisit? _saved;
  DateTime? _visitedAt;
  bool _editing = false;
  _Form? _beforeEdit;

  @override
  void initState() {
    super.initState();
    _plotId = widget.plotId;
    _locate(first: true);
  }

  Future<void> _locate({bool first = false}) async {
    if (!first) setState(() => _locating = true);
    LocationFix? fix;
    try {
      fix = await ref.read(locationServiceProvider).currentFix();
    } on LocationUnavailable {
      fix = null;
    }
    if (!mounted) return;
    setState(() {
      _fix = fix;
      _locating = false;
    });
  }

  bool get _showingSummary => _saved != null && !_editing;

  bool get _dirty =>
      _editing ||
      _photos.isNotEmpty ||
      _stageTouched ||
      _issues.any((i) => i.picked) ||
      _next != _Next.week ||
      !_present;

  Future<void> _leave() async {
    if (!_showingSummary && _dirty) {
      final l10n = context.l10n;
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.faVisitLogDiscardTitle),
          content: Text(l10n.faVisitLogDiscardBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.faVisitLogStay),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.faVisitLogDiscard),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    if (_editing) {
      setState(() {
        _beforeEdit?.restore(this);
        _beforeEdit = null;
        _editing = false;
        _showErrors = false;
      });
      return;
    }
    goBack(context, fallback: AppRoutes.calendar);
  }

  /// The farmer, plot, season and crop of this visit, or a widget that says
  /// why there are none.
  (_Target?, Widget?) _resolve(Territory t) {
    final l10n = context.l10n;
    final f = t.farmer(widget.farmerId);
    if (f == null) return (null, NotFoundCard(onBack: _leave));
    final plots = [
      for (final p in t.plotsOf(f.id))
        if (t.activeSeason(p.id) != null) t.plotSummary(p),
    ];
    SnapPlot? plot;
    SnapSeason? season;
    if (widget.visitId case final visitId?) {
      final v = t.visit(visitId);
      if (v == null) return (null, NotFoundCard(onBack: _leave));
      // A missed visit (its day passed) can still be logged.
      if (!Territory.isOpenPlan(v) && _saved == null && !_saving) {
        return (
          null,
          _Card(
            icon: OrbitIcons.success,
            title: l10n.faVisitLogAlreadyLogged,
            onBack: _leave,
          ),
        );
      }
      plot = t.plot(v.plotId);
      season = t.season(v.seasonId);
    } else {
      final pick =
          plots.where((p) => p.plot.id == _plotId).firstOrNull ??
          plots.firstOrNull;
      plot = pick?.plot;
      season = pick?.season;
    }
    if (plot == null || season == null) {
      return (
        null,
        _Card(
          icon: OrbitIcons.crop,
          title: l10n.faVisitLogNoCropTitle,
          body: l10n.faVisitLogNoCropBody(
            name: farmerName(f, contentLanguage(context)),
          ),
          onBack: _leave,
        ),
      );
    }
    return (
      _Target(
        farmer: f,
        plot: plot,
        season: season,
        crop: t.crop(season.cropId),
        plots: plots,
      ),
      null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final territory = ref.watch(territoryProvider);
    final t = territory.value;
    final (target, problem) = t == null ? (null, null) : _resolve(t);
    String? subtitle;
    if (t != null && target != null) {
      final language = contentLanguage(context);
      final das = target.season.daysAfterSowing(t.today);
      subtitle = dotJoin(l10n, [
        farmerName(target.farmer, language),
        target.plot.label,
        target.crop?.displayName(language),
        if (das != null && das >= 0) l10n.faVisitLogDayAfterSowing(count: das),
      ]);
    }
    return PopScope(
      canPop: _showingSummary || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: Column(
          children: [
            FaHeader(
              title: l10n.faShellTitleVisitLog,
              subtitle: subtitle,
              onBack: _leave,
              backLabel: l10n.faVisitLogBackToCalendar,
            ),
            Expanded(
              child: AsyncValueView(
                value: territory,
                onRetry: () => ref.invalidate(territoryProvider),
                data: (t) {
                  if (problem != null) return problem;
                  return _showingSummary
                      ? _summary(t, target!)
                      : _form(t, target!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // The form

  /// The stage picked, else the one the crop calendar suggests.
  String? _stageFor(Territory t, _Target target) =>
      _stageId ??
      (_stageTouched ? null : t.suggestedStage(target.season.id)?.id);

  _Issue _current(List<IssueType> types) {
    if (_issues.isEmpty) {
      _issues.add(_Issue(types.isEmpty ? IssueType.pest : types.first));
    }
    return _issues.last;
  }

  /// The day the visit counts for (IST), from the server-corrected clock.
  LocalDate _visitDay() =>
      LocalDate.istOf(_visitedAt ?? ref.read(serverClockProvider).now());

  /// The start of the crop's next stage, when it is 2 to 60 days away and
  /// not a week from today.
  (LocalDate, SnapStage)? _nextStage(_Target target, LocalDate day) {
    final sowing = target.season.sowingDate;
    final das = target.season.daysAfterSowing(day);
    if (sowing == null || das == null) return null;
    for (final s in target.stages) {
      if (s.startDay <= das) continue;
      final date = sowing.addDays(s.startDay);
      final away = day.daysUntil(date);
      if (away < 2 || away > 60 || away == 7) return null;
      return (date, s);
    }
    return null;
  }

  LocalDate? _nextDate(_Target target, LocalDate day) => switch (_next) {
    _Next.week => day.addDays(7),
    _Next.stage => _nextStage(target, day)?.$1,
    _Next.other => _nextOther,
    _Next.none => null,
  };

  Widget _form(Territory t, _Target target) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final language = contentLanguage(context);
    final crop = target.crop;
    final types = crop == null ? const <IssueType>[] : t.issueTypesFor(crop.id);
    final current = _current(types);
    final added = _issues.sublist(0, _issues.length - 1);
    final stages = target.stages;
    final stageId = _stageFor(t, target);
    final stageMissing = stages.isNotEmpty && stageId == null;
    final severityMissing = current.picked && current.severity == null;
    final issue = current.issueId == null
        ? null
        : t.masters.issueById(current.issueId!);
    final options = issue == null
        ? const <AdviceOption>[]
        : t.adviceFor(issue.id);
    final advice = options
        .where((o) => o.rule.id == current.ruleId)
        .firstOrNull;
    final day = _visitDay();
    final nextStage = _nextStage(target, day);
    final canAdd =
        current.complete && _issues.length < LogVisitPayload.maxIssues;
    final full = _photos.length >= LogVisitPayload.maxPhotos;
    var step = 0;
    String stepTitle(String title) =>
        l10n.faVisitLogStep(number: ++step, title: title);

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
              if (widget.visitId == null && target.plots.length > 1) ...[
                StepHeading(l10n.faVisitLogPlot),
                const SizedBox(height: OrbitSpace.s8),
                OptionChipWrap(
                  label: l10n.faVisitLogPlot,
                  children: [
                    for (final p in target.plots)
                      OptionChip(
                        label: dotJoin(l10n, [
                          p.plot.label,
                          p.crop?.displayName(language),
                        ]),
                        selected: p.plot.id == target.plot.id,
                        onTap: _saved != null
                            ? null
                            : () => setState(() {
                                _plotId = p.plot.id;
                                _stageId = null;
                                _stageTouched = false;
                                _issues.clear();
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: OrbitSpace.s16),
              ],
              // 1 Photos
              StepHeading(
                stepTitle(l10n.faVisitLogPhotos),
                detail: full
                    ? l10n.faVisitLogPhotoMax(max: LogVisitPayload.maxPhotos)
                    : l10n.faVisitLogPhotoCount(count: _photos.length),
              ),
              const SizedBox(height: OrbitSpace.s8),
              PhotoStrip(
                photos: [for (final p in _photos) p.bytes],
                taking: _taking,
                onTake: full ? null : _takePhoto,
                onOpen: _openPhotos,
              ),
              const SizedBox(height: OrbitSpace.s16),
              // 2 Crop stage
              StepHeading(stepTitle(l10n.faVisitLogStage)),
              const SizedBox(height: OrbitSpace.s8),
              OptionChipWrap(
                label: l10n.faVisitLogStage,
                children: [
                  for (final s in stages)
                    OptionChip(
                      label: s.displayName(language),
                      selected: s.id == stageId,
                      onTap: () => setState(() {
                        _stageId = s.id;
                        _stageTouched = true;
                      }),
                    ),
                ],
              ),
              if (_showErrors && stageMissing)
                InlineError(l10n.faVisitLogStageRequired),
              const SizedBox(height: OrbitSpace.s16),
              // 3 Issue
              StepHeading(
                stepTitle(l10n.faVisitLogIssue),
                detail: crop == null
                    ? null
                    : l10n.faVisitLogIssueFrom(
                        crop: crop.displayName(language),
                      ),
              ),
              for (final (i, a) in added.indexed) ...[
                const SizedBox(height: OrbitSpace.s8),
                _addedRow(t, a, i + 1),
              ],
              const SizedBox(height: OrbitSpace.s8),
              if (types.isEmpty)
                Text(
                  l10n.faVisitLogNoIssuesListed,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: orbit.textMuted,
                  ),
                )
              else ...[
                if (types.length > 1) ...[
                  Semantics(
                    container: true,
                    label: l10n.faVisitLogIssueType,
                    child: SegmentedTabs(
                      labels: [
                        for (final ty in types) issueTypeLabel(l10n, ty),
                      ],
                      selectedIndex: types.contains(current.type)
                          ? types.indexOf(current.type)
                          : 0,
                      onChanged: (i) => setState(() {
                        if (current.type == types[i]) return;
                        current
                          ..type = types[i]
                          ..issueId = null
                          ..severity = null
                          ..ruleId = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: OrbitSpace.s8),
                ],
                PickerButton(
                  icon: OrbitIcons.search,
                  placeholder: issue == null,
                  title:
                      issue?.displayName(language) ?? l10n.faVisitLogPickIssue,
                  subtitle: issue == null
                      ? l10n.faVisitLogPickIssueHint
                      : dotJoin(l10n, [
                          issueTypeLabel(l10n, issue.type),
                          language == Language.te ? issue.name : issue.nameTe,
                        ]),
                  semanticLabel: issue == null
                      ? l10n.faVisitLogPickIssue
                      : l10n.faVisitLogIssueLabel(
                          issue: issue.displayName(language),
                        ),
                  onTap: () => _pickIssue(t, crop!, current),
                ),
                if (issue != null) ...[
                  const SizedBox(height: OrbitSpace.s8),
                  SeverityPicker(
                    value: current.severity,
                    onChanged: (s) => setState(() => current.severity = s),
                  ),
                  if (_showErrors && severityMissing)
                    InlineError(l10n.faVisitLogSeverityRequired),
                ],
              ],
              const SizedBox(height: OrbitSpace.s16),
              // 4 Recommend salt
              StepHeading(
                stepTitle(l10n.faVisitLogSalt),
                detail: options.isEmpty ? null : l10n.faVisitLogSuggested,
                detailIsGood: true,
              ),
              const SizedBox(height: OrbitSpace.s8),
              if (issue == null)
                Text(
                  l10n.faVisitLogSaltAfterIssue,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: orbit.textMuted,
                  ),
                )
              else if (options.isEmpty)
                ToneNote(
                  tone: orbit.info,
                  icon: OrbitIcons.info,
                  title: l10n.faVisitLogNoRule,
                  body: l10n.faVisitLogNoRuleNote,
                )
              else ...[
                PickerButton(
                  title: advice?.saltName(language) ?? l10n.faVisitLogPickSalt,
                  placeholder: advice == null,
                  subtitle: advice?.dose(language),
                  semanticLabel: advice == null
                      ? l10n.faVisitLogPickSalt
                      : l10n.faVisitLogSaltLabel(
                          salt: advice.saltName(language),
                        ),
                  onTap: () => _pickSalt(options, current),
                ),
                if (advice != null) ...[
                  const SizedBox(height: OrbitSpace.s8),
                  if (advice.sku case final sku?)
                    ToneNote(
                      tone: orbit.success,
                      icon: OrbitIcons.product,
                      title: l10n.faVisitLogProduct(
                        name: sku.displayName(language),
                      ),
                      body: l10n.faVisitLogProductNote,
                    )
                  else
                    ToneNote(
                      tone: orbit.warning,
                      icon: OrbitIcons.warning,
                      title: l10n.faVisitLogNoProduct,
                      body: l10n.faVisitLogNoProductNote,
                    ),
                ],
              ],
              const SizedBox(height: OrbitSpace.s12),
              OrbitButton(
                label: l10n.faVisitLogAddIssue,
                icon: OrbitIcons.add,
                variant: OrbitButtonVariant.secondary,
                size: OrbitButtonSize.medium,
                onPressed: canAdd
                    ? () => setState(
                        () => _issues.add(
                          _Issue(types.isEmpty ? IssueType.pest : types.first),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: OrbitSpace.s16),
              // 5 Next visit
              StepHeading(stepTitle(l10n.faVisitLogNextVisit)),
              const SizedBox(height: OrbitSpace.s8),
              OptionChipWrap(
                label: l10n.faVisitLogNextVisit,
                children: [
                  OptionChip(
                    label: l10n.faVisitLogNextWeek,
                    semanticLabel: dotJoin(l10n, [
                      l10n.faVisitLogNextWeek,
                      formatDateWeekday(l10n, day.addDays(7)),
                    ]),
                    selected: _next == _Next.week,
                    onTap: () => setState(() => _next = _Next.week),
                  ),
                  if (nextStage case (final date, final stage))
                    OptionChip(
                      label: dotJoin(l10n, [
                        formatDateWeekday(l10n, date),
                        stage.displayName(language),
                      ]),
                      selected: _next == _Next.stage,
                      onTap: () => setState(() => _next = _Next.stage),
                    ),
                  OptionChip(
                    label: _next == _Next.other && _nextOther != null
                        ? formatDateWeekday(l10n, _nextOther!)
                        : l10n.faVisitLogNextOther,
                    icon: OrbitIcons.calendar,
                    selected: _next == _Next.other,
                    onTap: () => _pickNextDate(day),
                  ),
                  OptionChip(
                    label: l10n.faVisitLogNextNone,
                    selected: _next == _Next.none,
                    onTap: () => setState(() => _next = _Next.none),
                  ),
                ],
              ),
              const SizedBox(height: OrbitSpace.s16),
              SwitchRow(
                title: l10n.faVisitLogFarmerPresent,
                subtitle: l10n.faVisitLogFarmerPresentNote,
                value: _present,
                onChanged: (v) => setState(() => _present = v),
              ),
            ],
          ),
        ),
        _footer(t, target),
      ],
    );
  }

  Widget _addedRow(Territory t, _Issue a, int number) {
    final l10n = context.l10n;
    final language = contentLanguage(context);
    final issue = t.masters.issueById(a.issueId!);
    final name = issue?.displayName(language) ?? '';
    final advice = t
        .adviceFor(a.issueId!)
        .where((o) => o.rule.id == a.ruleId)
        .firstOrNull;
    return AddedIssueRow(
      title: l10n.faVisitLogIssueRow(number: number, issue: name),
      detail: dotJoin(l10n, [
        severityLabel(l10n, a.severity!),
        advice?.saltName(language) ?? l10n.faVisitLogAdviceHo,
      ]),
      removeLabel: l10n.faVisitLogRemoveIssue(issue: name),
      onRemove: () => setState(() => _issues.remove(a)),
    );
  }

  Widget _footer(Territory t, _Target target) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final fix = _fix;
    final gps = _locating
        ? l10n.faVisitLogGpsFinding
        : fix == null
        ? l10n.faVisitLogGpsNone
        : l10n.faVisitLogGpsFix(
            lat: fix.lat.toStringAsFixed(2),
            lng: fix.lng.toStringAsFixed(2),
          );
    final now = _visitedAt ?? ref.read(serverClockProvider).now();
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
            OrbitSpace.s4,
            OrbitSpace.s16,
            OrbitSpace.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    OrbitIcons.location,
                    size: OrbitSize.iconSm,
                    color: orbit.textMuted,
                  ),
                  const SizedBox(width: OrbitSpace.s6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: OrbitSpace.s6,
                      ),
                      child: Text(
                        dotJoin(l10n, [
                          gps,
                          formatTime(l10n, now),
                          _present
                              ? l10n.faVisitLogPresentYes
                              : l10n.faVisitLogPresentNo,
                          l10n.faVisitLogWorksOffline,
                        ]),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (!_locating && fix == null)
                    IconButton(
                      onPressed: _locate,
                      icon: const Icon(OrbitIcons.refresh),
                      tooltip: l10n.faVisitLogGpsRetry,
                    ),
                ],
              ),
              const SizedBox(height: OrbitSpace.s4),
              OrbitButton(
                label: _editing
                    ? l10n.faVisitLogSaveChanges
                    : l10n.faVisitLogSave,
                loading: _saving,
                onPressed: () => _save(t, target),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Actions

  Future<void> _takePhoto() async {
    if (_taking || _photos.length >= LogVisitPayload.maxPhotos) return;
    setState(() => _taking = true);
    CapturedPhoto? photo;
    try {
      photo = await ref.read(photoCaptureProvider).take();
    } on CameraUnavailable {
      if (mounted) {
        showVisitSnackBar(context, context.l10n.faVisitLogCameraFailed);
      }
    }
    if (!mounted) return;
    setState(() {
      _taking = false;
      if (photo != null) _photos.add(_Photo(photo.bytes, photo.contentType));
    });
  }

  Future<void> _openPhotos() async {
    if (_photos.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => PhotoSheet(
        photos: [for (final p in _photos) p.bytes],
        onRemove: (i) => setState(() => _photos.removeAt(i)),
      ),
    );
  }

  Future<void> _pickIssue(Territory t, SnapCrop crop, _Issue current) async {
    final pick = await showModalBottomSheet<IssuePick>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: IssueSheet(
          issues: t.issuesFor(crop.id, type: current.type),
          selectedId: current.issueId,
        ),
      ),
    );
    if (pick == null || !mounted || pick.id == current.issueId) return;
    setState(() {
      current
        ..issueId = pick.id
        ..severity = null
        ..ruleId = pick.id == null
            ? null
            : t.adviceFor(pick.id!).firstOrNull?.rule.id;
    });
  }

  Future<void> _pickSalt(List<AdviceOption> options, _Issue current) async {
    final ruleId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          SaltSheet(options: options, selectedRuleId: current.ruleId),
    );
    if (ruleId == null || !mounted) return;
    setState(() => current.ruleId = ruleId);
  }

  Future<void> _pickNextDate(LocalDate day) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: day.addDays(1).toDateTime(),
      lastDate: day.addDays(90).toDateTime(),
      initialDate: (_nextOther ?? day.addDays(14)).toDateTime(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _next = _Next.other;
      _nextOther = LocalDate(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save(Territory t, _Target target) async {
    if (_saving) return;
    final l10n = context.l10n;
    final stageId = _stageFor(t, target);
    final incomplete = _issues.any((i) => i.picked && i.severity == null);
    if ((target.stages.isNotEmpty && stageId == null) || incomplete) {
      setState(() => _showErrors = true);
      showVisitSnackBar(context, l10n.faVisitLogCheckDetails);
      return;
    }
    if (_photos.isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.faVisitLogNoPhotoTitle),
          content: Text(l10n.faVisitLogNoPhotoBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.faVisitLogSaveWithoutPhotos),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.faVisitLogTakePhoto),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (go != true) {
        if (go == false) await _takePhoto();
        return;
      }
    }
    final visitedAt = _visitedAt ?? ref.read(serverClockProvider).now();
    final next = _nextDate(target, LocalDate.istOf(visitedAt));
    final input = VisitLogInput(
      farmerId: target.farmer.id,
      plotId: target.plot.id,
      seasonId: target.season.id,
      visitId: widget.visitId,
      visitedAt: visitedAt,
      location: _fix?.point,
      farmerPresent: _present,
      stageId: stageId,
      issues: [
        for (final i in _issues)
          if (i.picked)
            VisitIssueInput(
              issueId: i.issueId!,
              severity: i.severity!,
              ruleId: i.ruleId,
            ),
      ],
      photos: [
        for (final p in _photos)
          if (p.savedId case final id?)
            VisitPhotoInput.kept(id, contentType: p.contentType)
          else
            VisitPhotoInput(bytes: p.bytes, contentType: p.contentType),
      ],
      nextVisit: next == null
          ? null
          : NextVisitInput(plannedFor: next, slot: VisitSlot.any),
    );
    setState(() => _saving = true);
    final actions = ref.read(faActionsProvider);
    try {
      final saved = _saved;
      final result = saved != null
          ? await actions.editQueuedVisit(saved.visitId, input)
          : await actions.logVisit(input);
      for (final (i, id) in result.photoIds.indexed) {
        if (i < _photos.length) _photos[i].savedId = id;
      }
      ref.read(calendarDayProvider.notifier).show(null);
      ref
          .read(visitNoticeProvider.notifier)
          .show(
            VisitNotice(
              kind: VisitNoticeKind.saved,
              farmerId: target.farmer.id,
              visitId: result.visitId,
              day: LocalDate.istOf(visitedAt),
              hasAdvice: input.issues.any((i) => i.ruleId != null),
            ),
          );
      if (!mounted) return;
      setState(() {
        _saved = result;
        _visitedAt = visitedAt;
        _editing = false;
        _beforeEdit = null;
        _saving = false;
        _showErrors = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e is FaActionError && e.code == FaActionError.notEditable) {
          _beforeEdit?.restore(this);
          _beforeEdit = null;
          _editing = false;
        }
      });
      showActionError(context, e);
    }
  }

  // ---------------------------------------------------------------------
  // Visit saved

  Widget _summary(Territory t, _Target target) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final language = contentLanguage(context);
    final saved = _saved!;
    final pending = t.isPending(saved.visitId);
    final name = farmerName(target.farmer, language);
    final stageId = _stageFor(t, target);
    final stage = target.stages.where((s) => s.id == stageId).firstOrNull;
    final issues = [
      for (final i in _issues)
        if (i.picked) i,
    ];
    final advice = [
      for (final i in issues)
        if (t.adviceFor(i.issueId!).where((o) => o.rule.id == i.ruleId)
            case final o when o.isNotEmpty)
          o.first,
    ];
    String issueText(_Issue i) => l10n.faVisitLogIssueSeverity(
      issue: t.masters.issueById(i.issueId!)?.displayName(language) ?? '',
      severity: severityLabel(l10n, i.severity!).toLowerCase(),
    );
    String adviceText(AdviceOption o) => o.sku == null
        ? l10n.faVisitLogSaltOnly(salt: o.saltName(language))
        : dotJoin(l10n, [o.sku!.displayName(language), o.saltName(language)]);
    String withMore(String first, int more) =>
        more > 0 ? '$first ${l10n.faVisitLogMoreCount(count: more)}' : first;
    final next = _nextDate(target, LocalDate.istOf(_visitedAt!));
    final farmerLanguage = target.farmer.language == Language.en
        ? l10n.faVisitLogLangEn
        : l10n.faVisitLogLangTe;
    final note = advice.isNotEmpty
        ? (pending
              ? l10n.faVisitLogSmsPending(name: name, language: farmerLanguage)
              : l10n.faVisitLogSmsSent(name: name, language: farmerLanguage))
        : issues.isNotEmpty
        ? l10n.faVisitLogSmsNone
        : null;
    final canEdit = t.isVisitEditable(saved.visitId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        OrbitSpace.s24,
        OrbitSpace.s16,
        OrbitSpace.s20,
      ),
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: orbit.success.strong,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 72,
              child: Icon(
                OrbitIcons.check,
                size: OrbitSize.iconXl,
                color: theme.colorScheme.surface,
              ),
            ),
          ),
        ),
        const SizedBox(height: OrbitSpace.s12),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            l10n.faVisitLogSavedTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall!.copyWith(
              fontWeight: OrbitFont.weightExtrabold,
            ),
          ),
        ),
        const SizedBox(height: OrbitSpace.s4),
        Text(
          pending ? l10n.faVisitLogSavedPending : l10n.faVisitLogSavedSynced,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: OrbitSpace.s16),
        Semantics(
          container: true,
          label: l10n.faVisitLogSummary,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1.5,
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(OrbitRadius.xl),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OrbitSpace.s16,
                vertical: OrbitSpace.s10,
              ),
              child: Column(
                children: [
                  SummaryRow(
                    label: l10n.faVisitLogRowStage,
                    value: stage?.displayName(language) ?? l10n.faVisitLogNone,
                  ),
                  SummaryRow(
                    label: l10n.faVisitLogRowIssues,
                    value: issues.isEmpty
                        ? l10n.faVisitLogNone
                        : withMore(issueText(issues.first), issues.length - 1),
                  ),
                  SummaryRow(
                    label: l10n.faVisitLogRowAdvice,
                    value: advice.isNotEmpty
                        ? withMore(adviceText(advice.first), advice.length - 1)
                        : issues.isNotEmpty
                        ? l10n.faVisitLogAdviceHo
                        : l10n.faVisitLogNone,
                  ),
                  SummaryRow(
                    label: l10n.faVisitLogRowPhotos,
                    value: _photos.isEmpty
                        ? l10n.faVisitLogNone
                        : l10n.faVisitLogPhotoCount(count: _photos.length),
                  ),
                  SummaryRow(
                    label: l10n.faVisitLogRowNext,
                    value: next == null
                        ? l10n.faVisitLogNotPlanned
                        : formatDateWeekday(l10n, next),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: OrbitSpace.s12),
          ToneNote(
            tone: pending ? orbit.warning : orbit.success,
            icon: OrbitIcons.message,
            title: note,
          ),
        ],
        const SizedBox(height: OrbitSpace.s20),
        OrbitButton(
          label: l10n.faVisitLogBackToCalendar,
          icon: OrbitIcons.calendar,
          onPressed: () => context.go(AppRoutes.calendar),
        ),
        const SizedBox(height: OrbitSpace.s8),
        OrbitButton(
          label: l10n.faVisitLogOpenFarmer(name: name),
          icon: OrbitIcons.person,
          variant: OrbitButtonVariant.secondary,
          onPressed: () => context.go(AppRoutes.farmer(target.farmer.id)),
        ),
        if (canEdit) ...[
          const SizedBox(height: OrbitSpace.s4),
          TextButton(
            onPressed: () => setState(() {
              _beforeEdit = _Form(this);
              _editing = true;
            }),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(OrbitSize.controlLg),
            ),
            child: Text(l10n.faVisitLogEditVisit),
          ),
        ],
      ],
    );
  }
}

/// A state card with a way back (no crop, already logged).
class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.onBack,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(OrbitSpace.s16),
      child: StateCard(
        icon: icon,
        title: title,
        subtitle: body,
        action: OrbitButton(
          label: context.l10n.commonBack,
          icon: OrbitIcons.back,
          variant: OrbitButtonVariant.secondary,
          onPressed: onBack,
        ),
      ),
    ),
  );
}
