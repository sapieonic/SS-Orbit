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
import '../../shared/formatters.dart';
import '../../shared/navigation.dart';
import 'enrol_support.dart';

/// A4c enrolment step 3: the crop on [plotId].
///
/// Crop (masters, with Telugu names) for a season (`all_open`, the current
/// one first picked), sowing date (today, yesterday, a date picked, or not
/// sown yet; never in the future), the previous crop, then a summary card.
/// Finish enrolment queues StartSeason and shows "`<name>` is enrolled" with
/// Plan first visit and Back to farmers. Works offline.
class EnrolCropScreen extends StatelessWidget {
  /// Creates the screen.
  const EnrolCropScreen({
    super.key,
    required this.farmerId,
    required this.plotId,
  });

  /// The farmer being enrolled.
  final String farmerId;

  /// The plot the season starts on.
  final String plotId;

  // The router reuses this page when Finish enrolment opens another
  // farmer's step 3: the key starts it fresh, so the last farmer's picks and
  // "is enrolled" state never show for this one.
  @override
  Widget build(BuildContext context) => _EnrolCropPage(
    key: ValueKey((farmerId, plotId)),
    farmerId: farmerId,
    plotId: plotId,
  );
}

class _EnrolCropPage extends ConsumerStatefulWidget {
  const _EnrolCropPage({
    super.key,
    required this.farmerId,
    required this.plotId,
  });

  final String farmerId;
  final String plotId;

  @override
  ConsumerState<_EnrolCropPage> createState() => _EnrolCropScreenState();
}

/// What the sowing-date chips mean.
enum _Sowing { today, yesterday, picked, notSown }

/// The "fallow / don't know" previous-crop chip.
const _noPreviousCrop = '';

class _EnrolCropScreenState extends ConsumerState<_EnrolCropPage> {
  String? _season;
  String? _cropId;
  _Sowing? _sowing;
  LocalDate? _picked;
  String? _previous;
  bool _saving = false;
  bool _showErrors = false;
  String? _seasonId;

  LocalDate? _sowingDate(LocalDate today) => switch (_sowing) {
    _Sowing.today => today,
    _Sowing.yesterday => today.addDays(-1),
    _Sowing.picked => _picked,
    _ => null,
  };

  Future<void> _pickDate(LocalDate today) async {
    final initial = (_picked ?? today.addDays(-7)).toDateTime();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: context.l10n.faEnrolCropSowingLabel,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _picked = LocalDate(picked.year, picked.month, picked.day);
      _sowing = _Sowing.picked;
    });
  }

  Future<void> _finish(Territory t, String code) async {
    if (_saving) return;
    final cropId = _cropId;
    if (cropId == null || _sowing == null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(faActionsProvider)
          .startSeason(
            farmerId: t.resolveFarmerId(widget.farmerId),
            plotId: widget.plotId,
            seasonCode: code,
            cropId: cropId,
            sowingDate: _sowingDate(t.today),
            previousCropId: _previous == _noPreviousCrop ? null : _previous,
          );
      if (!mounted) return;
      setState(() {
        _seasonId = id;
        _saving = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final territory = watchTerritory(ref);
    final t = territory.value;
    final f = t?.farmer(widget.farmerId);
    final plot = t?.plot(widget.plotId);
    final name = f?.displayName(contentLanguage(context));
    return Scaffold(
      body: Column(
        children: [
          FaHeader(
            title: name == null || name.isEmpty
                ? l10n.faEnrolTitle
                : l10n.faEnrolTitleName(name: name),
            subtitle: dotJoin(l10n, [enrolStepLine(l10n, 3), plot?.label]),
            back: _seasonId == null,
          ),
          Expanded(
            child: AsyncValueView(
              value: territory,
              onRetry: () => ref.invalidate(territoryProvider),
              data: (t) {
                final f = t.farmer(widget.farmerId);
                final plot = t.plot(widget.plotId);
                if (f == null ||
                    plot == null ||
                    t.resolveFarmerId(plot.farmerId) != f.id) {
                  return NotFoundCard(onBack: () => goBack(context));
                }
                if (_seasonId case final seasonId?) {
                  return _done(t, f, plot, seasonId);
                }
                final active = t.activeSeason(plot.id);
                if (active != null) return _hasCrop(t, f, active);
                return _form(t, f, plot);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(Territory t, SnapFarmer f, SnapPlot plot) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final language = contentLanguage(context);
    final other = language == Language.te ? Language.en : Language.te;
    final codes = t.seasonCodes;
    final seasons = codes.allOpen.isEmpty ? [codes.current] : codes.allOpen;
    final season = _season != null && seasons.contains(_season)
        ? _season!
        : codes.current;
    final today = t.today;
    final crops = t.masters.crops;
    final crop = t.crop(_cropId);
    final sown = _sowingDate(today);

    String? sowNote;
    if (sown != null) {
      final day = sown.daysUntil(today);
      final stage = crop?.stageAt(day);
      sowNote = stage == null
          ? l10n.faEnrolCropSowDay(day: day)
          : l10n.faEnrolCropSowDayStage(
              day: day,
              stage: stage.displayName(language),
            );
    } else if (_sowing == _Sowing.notSown) {
      sowNote = l10n.faEnrolCropNotSownNote;
    }

    String? secondName(String en, String te) {
      final second = pickText(other, te: te, en: en);
      final first = pickText(language, te: te, en: en);
      return second == first ? null : second;
    }

    final previous = _previous;
    final previousName = previous == null
        ? null
        : previous == _noPreviousCrop
        ? l10n.faEnrolCropFallow
        : t.crop(previous)?.displayName(language);

    return EnrolScroll(
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        OrbitSpace.s16,
        OrbitSpace.s16,
        OrbitSpace.s24,
      ),
      children: [
        const EnrolSteps(current: 2),
        const SizedBox(height: OrbitSpace.s16),
        _heading(l10n.faEnrolCropSeasonHeading),
        EnrolChoiceChips<String>(
          semanticLabel: l10n.faEnrolCropSeasonHeading,
          selected: season,
          onSelected: _saving ? null : (c) => setState(() => _season = c),
          choices: [
            for (final c in seasons)
              EnrolChoice(
                c,
                seasonLabel(l10n, c),
                secondaryLabel: c == codes.current
                    ? l10n.faEnrolCropThisSeason
                    : null,
              ),
          ],
        ),
        const SizedBox(height: OrbitSpace.s16),
        _heading(
          l10n.faEnrolCropCropHeading(season: seasonLabel(l10n, season)),
        ),
        EnrolChoiceChips<String>(
          semanticLabel: l10n.faEnrolCropCropHeading(
            season: seasonLabel(l10n, season),
          ),
          selected: _cropId,
          onSelected: _saving ? null : (id) => setState(() => _cropId = id),
          choices: [
            for (final c in crops)
              EnrolChoice(
                c.id,
                c.displayName(language),
                secondaryLabel: secondName(c.name, c.nameTe),
              ),
          ],
        ),
        if (_showErrors && _cropId == null) ...[
          const SizedBox(height: OrbitSpace.s8),
          InlineError(l10n.faEnrolCropErrorCrop),
        ],
        const SizedBox(height: OrbitSpace.s16),
        _heading(l10n.faEnrolCropSowingLabel),
        EnrolChoiceChips<_Sowing>(
          semanticLabel: l10n.faEnrolCropSowingLabel,
          selected: _sowing,
          onSelected: _saving
              ? null
              : (s) {
                  if (s == _Sowing.picked) {
                    _pickDate(today);
                  } else {
                    setState(() => _sowing = s);
                  }
                },
          choices: [
            EnrolChoice(
              _Sowing.today,
              l10n.faEnrolCropSowToday(date: formatDateShort(l10n, today)),
            ),
            EnrolChoice(
              _Sowing.yesterday,
              l10n.faEnrolCropSowYesterday(
                date: formatDateShort(l10n, today.addDays(-1)),
              ),
            ),
            EnrolChoice(
              _Sowing.picked,
              _picked == null
                  ? l10n.faEnrolCropSowPick
                  : formatDateFull(l10n, _picked!),
            ),
            EnrolChoice(_Sowing.notSown, l10n.faEnrolCropNotSown),
          ],
        ),
        if (sowNote != null) ...[
          const SizedBox(height: OrbitSpace.s6),
          Text(sowNote, style: theme.textTheme.bodyMedium),
        ],
        if (_showErrors && _sowing == null) ...[
          const SizedBox(height: OrbitSpace.s8),
          InlineError(l10n.faEnrolCropErrorSowing),
        ],
        const SizedBox(height: OrbitSpace.s16),
        _heading(l10n.faEnrolCropPreviousLabel),
        EnrolChoiceChips<String>(
          semanticLabel: l10n.faEnrolCropPreviousLabel,
          selected: _previous,
          onSelected: _saving ? null : (id) => setState(() => _previous = id),
          choices: [
            for (final c in crops) EnrolChoice(c.id, c.displayName(language)),
            EnrolChoice(_noPreviousCrop, l10n.faEnrolCropFallow),
          ],
        ),
        const SizedBox(height: OrbitSpace.s20),
        _summary(
          t,
          f,
          plot,
          crop: crop == null
              ? null
              : dotJoin(l10n, [
                  crop.displayName(language),
                  if (sown != null)
                    l10n.faEnrolCropSummarySown(
                      date: formatDateShort(l10n, sown),
                    ),
                  if (previousName != null)
                    l10n.faEnrolCropSummaryAfter(crop: previousName),
                ]),
        ),
        const SizedBox(height: OrbitSpace.s20),
        OrbitButton(
          label: l10n.faEnrolCropFinish,
          icon: OrbitIcons.check,
          loading: _saving,
          onPressed: _saving ? null : () => _finish(t, season),
        ),
        if (_enrolQueued(t, f.id)) ...[
          const SizedBox(height: OrbitSpace.s8),
          InfoRow(
            icon: OrbitIcons.message,
            text: l10n.faEnrolCropSmsNote(
              name: f.displayName(language),
              language:
                  l10n.enumLabel('language', f.language.wire) ??
                  f.language.wire,
            ),
          ),
        ],
      ],
    );
  }

  /// The farmer's EnrolFarmer is still on this phone (the welcome SMS goes
  /// when it lands).
  static bool _enrolQueued(Territory t, String farmerId) => t.outbox.any(
    (e) =>
        e.type == CommandType.enrolFarmer &&
        e.state.isPending &&
        t.resolveFarmerId(e.entityId) == farmerId,
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: OrbitSpace.s8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium!
            .copyWith(fontWeight: OrbitFont.weightBold),
      ),
    ),
  );

  Widget _summary(Territory t, SnapFarmer f, SnapPlot plot, {String? crop}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final language = contentLanguage(context);
    final village = t.village(plot.villageId ?? f.villageId);
    return Semantics(
      container: true,
      label: l10n.faEnrolCropSummary,
      child: EnrolCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyValueRow(
              label: l10n.faEnrolCropSummaryFarmer,
              value: dotJoin(l10n, [
                f.displayName(language),
                formatIndianMobile(f.phone),
                l10n.enumLabel('language', f.language.wire),
              ]),
            ),
            KeyValueRow(
              label: plot.label,
              value: dotJoin(l10n, [
                formatArea(l10n, plot.areaAcres),
                village?.displayName(language),
              ]),
            ),
            KeyValueRow(
              label: l10n.faEnrolCropSummaryCrop,
              value: crop ?? l10n.faEnrolCropSummaryNoCrop,
            ),
            KeyValueRow(
              label: l10n.faEnrolCropSummaryConsent,
              value: f.consentPending
                  ? l10n.faEnrolCropConsentPending
                  : l10n.faEnrolCropConsentDone,
            ),
            if (t.isPending(f.id) || t.isPending(plot.id)) ...[
              const SizedBox(height: OrbitSpace.s4),
              Text(l10n.faCommonNotSynced, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hasCrop(Territory t, SnapFarmer f, SnapSeason season) {
    final l10n = context.l10n;
    final orbit = OrbitColors.of(context);
    final crop = t.crop(season.cropId)?.displayName(contentLanguage(context));
    return EnrolScroll(
      padding: const EdgeInsets.all(OrbitSpace.s16),
      children: [
        EnrolNotice(
          icon: OrbitIcons.crop,
          tone: orbit.info,
          title: l10n.errorActiveSeasonExists,
          body: crop,
          actions: [
            OrbitButton(
              label: l10n.faEnrolOpenFarmer,
              icon: OrbitIcons.person,
              onPressed: () => context.go(AppRoutes.farmer(f.id)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _done(Territory t, SnapFarmer f, SnapPlot plot, String seasonId) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final language = contentLanguage(context);
    final season = t.season(seasonId);
    final crop = t.crop(season?.cropId)?.displayName(language);
    final pending = t.isPending(seasonId) || t.isPending(f.id);
    return EnrolScroll(
      padding: const EdgeInsets.all(OrbitSpace.s16),
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: EnrolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  OrbitIcons.success,
                  color: orbit.success.fg,
                  size: OrbitSize.iconXxl,
                ),
                const SizedBox(height: OrbitSpace.s8),
                Text(
                  l10n.faEnrolCropEnrolled(name: f.displayName(language)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: OrbitFont.weightExtrabold,
                  ),
                ),
                const SizedBox(height: OrbitSpace.s4),
                Text(
                  dotJoin(l10n, [crop, formatArea(l10n, plot.areaAcres)]),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (pending) ...[
                  const SizedBox(height: OrbitSpace.s12),
                  InfoRow(
                    icon: OrbitIcons.offline,
                    text: l10n.faEnrolCropSavedOnPhone,
                  ),
                ],
                const SizedBox(height: OrbitSpace.s16),
                OrbitButton(
                  label: l10n.faEnrolCropPlanVisit,
                  icon: OrbitIcons.calendar,
                  onPressed: () =>
                      context.go(AppRoutes.planVisit(farmerId: f.id)),
                ),
                const SizedBox(height: OrbitSpace.s8),
                OrbitButton(
                  label: l10n.faEnrolCropBackToFarmers,
                  icon: OrbitIcons.people,
                  variant: OrbitButtonVariant.secondary,
                  onPressed: () => context.go(AppRoutes.farmers),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
