import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../device/device.dart';
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/fa_header.dart';
import '../../shared/formatters.dart';
import '../../shared/navigation.dart';
import 'boundary_sketch.dart';
import 'enrol_support.dart';

/// A4 enrolment step 2: the farm of [farmerId].
///
/// Walk the boundary (only while the GPS is within
/// [boundaryAccuracyLimitM]; otherwise the "GPS is ±28 m" card offers Type
/// area or Try again): Start point, corners from the GPS as the FA walks,
/// Undo last corner, Close boundary, the area worked out on the phone, Walk
/// again. Or type the area in acres and guntas with a pin where the FA
/// stands. The village comes from the GPS and can be changed (the server
/// puts the plot in the farmer's village, so a change updates the farmer).
///
/// Save & next queues SavePlot and opens step 3. Works offline.
class EnrolPlotScreen extends StatelessWidget {
  /// Creates the screen.
  const EnrolPlotScreen({super.key, required this.farmerId});

  /// The farmer being enrolled.
  final String farmerId;

  // The router reuses this page when Finish enrolment opens another
  // farmer's step 2: the key starts the walk and the village over.
  @override
  Widget build(BuildContext context) =>
      _EnrolPlotPage(key: ValueKey(farmerId), farmerId: farmerId);
}

class _EnrolPlotPage extends ConsumerStatefulWidget {
  const _EnrolPlotPage({super.key, required this.farmerId});

  final String farmerId;

  @override
  ConsumerState<_EnrolPlotPage> createState() => _EnrolPlotScreenState();
}

enum _Mode { walk, typed }

enum _Walk { ready, recording, paused, closed }

/// Corners closer than this to the previous one are GPS jitter.
const _cornerStepM = 2.0;

class _EnrolPlotScreenState extends ConsumerState<_EnrolPlotPage> {
  StreamSubscription<LocationFix>? _gps;
  LocationFix? _fix;
  LocationProblem? _problem;
  bool _checking = true;

  _Mode _mode = _Mode.walk;
  _Walk _walk = _Walk.ready;
  List<LatLng> _corners = const [];
  double _worstAccuracyM = 0;

  final _acres = TextEditingController();
  final _guntas = TextEditingController();

  String? _villageId;

  /// Why the walked boundary was refused on save (it crosses itself, or
  /// encloses almost nothing): offer Walk again.
  String? _walkError;
  bool _saving = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    unawaited(_gps?.cancel());
    _acres.dispose();
    _guntas.dispose();
    super.dispose();
  }

  void _listen() {
    unawaited(_gps?.cancel());
    _gps = ref
        .read(locationServiceProvider)
        .watch()
        .listen(
          _onFix,
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _checking = false;
              _problem = e is LocationUnavailable
                  ? e.problem
                  : LocationProblem.timeout;
            });
          },
        );
  }

  void _onFix(LocationFix fix) {
    if (!mounted) return;
    setState(() {
      _fix = fix;
      _problem = null;
      _checking = false;
      if (_walk == _Walk.recording && fix.goodForBoundary) {
        final last = _corners.isEmpty ? null : _corners.last;
        if (last == null || metresBetween(last, fix.point) >= _cornerStepM) {
          _corners = [..._corners, fix.point];
          if (fix.accuracyM > _worstAccuracyM) _worstAccuracyM = fix.accuracyM;
        }
      }
    });
  }

  Future<void> _tryAgain() async {
    setState(() {
      _checking = true;
      _problem = null;
    });
    try {
      final fix = await ref.read(locationServiceProvider).currentFix();
      _onFix(fix);
    } on LocationUnavailable catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _problem = e.problem;
        });
      }
    }
    // The FA may have left while the GPS looked: `ref` is gone then.
    if (mounted) _listen();
  }

  void _start() {
    final fix = _fix;
    if (fix == null || !fix.goodForBoundary) return;
    setState(() {
      _corners = [fix.point];
      _worstAccuracyM = fix.accuracyM;
      _walk = _Walk.recording;
    });
  }

  void _undo() {
    if (_corners.isEmpty) return;
    setState(() {
      _corners = _corners.sublist(0, _corners.length - 1);
      if (_corners.isEmpty) _walk = _Walk.ready;
    });
  }

  void _close() {
    if (_corners.length < 3) return;
    setState(() => _walk = _Walk.closed);
  }

  void _walkAgain() => setState(() {
    _walkError = null;
    _corners = const [];
    _worstAccuracyM = 0;
    _walk = _Walk.ready;
  });

  // -------------------------------------------------------------------------

  /// The walked area once the boundary is closed, or null (also when the
  /// corners enclose no area, e.g. walked along one line).
  double? get _walkedAcres {
    if (_walk != _Walk.closed) return null;
    final acres = ringAreaAcres(_corners);
    return acres > 0 ? acres : null;
  }

  double? get _typedAcres => typedAreaAcres(_acres.text, _guntas.text);

  double? get _area => _mode == _Mode.walk ? _walkedAcres : _typedAcres;

  String _villageFor(Territory t, SnapFarmer f) {
    if (_villageId case final id? when t.village(id) != null) return id;
    // A farmer enrolled on this phone just now got the village step 1 could
    // find (the first of the area when the GPS had no fix there): at the
    // farm, the GPS knows better. A self sign-up keeps the one he chose, and
    // a farmer HO already has keeps HO's.
    if (_newEnrolment(t, f)) {
      if (_gpsVillage(t)?.id case final id?) return id;
    }
    return f.villageId ?? _gpsVillage(t)?.id ?? t.villages.first.id;
  }

  /// [f] was enrolled by the FA on this phone, the enrolment has not synced
  /// yet, and the farmer has no plot.
  static bool _newEnrolment(Territory t, SnapFarmer f) =>
      f.source == FarmerSource.fa &&
      t.plotsOf(f.id).isEmpty &&
      t.outbox.any(
        (e) =>
            e.type == CommandType.enrolFarmer &&
            e.state.isPending &&
            t.resolveFarmerId(e.entityId) == f.id,
      );

  SnapVillage? _gpsVillage(Territory t) {
    final at = _mode == _Mode.walk && _corners.isNotEmpty
        ? (ringCentre(_corners) ?? _fix?.point)
        : _fix?.point;
    return at == null ? null : t.nearestVillage(at);
  }

  Future<void> _pickVillage(Territory t, String current) async {
    final language = contentLanguage(context);
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OrbitSpace.s16,
          0,
          OrbitSpace.s16,
          OrbitSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.faEnrolPlotPickVillage,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: OrbitSpace.s12),
            for (final v in t.villages) ...[
              ChoiceTile(
                label: v.displayName(language),
                secondaryLabel: v.displayMandal(language),
                icon: OrbitIcons.location,
                selected: v.id == current,
                onTap: () => Navigator.of(context).pop(v.id),
              ),
              const SizedBox(height: OrbitSpace.s8),
            ],
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _villageId = picked);
  }

  Future<void> _save(Territory t, SnapFarmer f) async {
    if (_saving) return;
    final area = _area;
    final fix = _fix;
    final villageId = _villageFor(t, f);
    if (_mode == _Mode.walk && _walk == _Walk.closed) {
      // Closed, but the corners enclose (almost) nothing, or the walk
      // crossed its own path: the server would refuse it.
      final problem = area == null
          ? FaActionError.areaTooSmall
          : !ringIsSimple(_corners)
          ? FaActionError.boundaryCrossesItself
          : null;
      if (problem != null) {
        setState(() => _walkError = problem);
        return;
      }
    }
    if (area == null || area <= 0 || area > 10000) {
      setState(() => _showErrors = true);
      return;
    }
    final LatLng? pin = _mode == _Mode.typed
        ? (fix?.point ?? t.village(villageId)?.location)
        : null;
    if (_mode == _Mode.typed && pin == null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final actions = ref.read(faActionsProvider);
    final number = t.plotsOf(f.id).length + 1;
    try {
      final plotId = await actions.savePlot(
        farmerId: f.id,
        // The label is data, kept in English like the server's own labels.
        label: lookupOrbitLocalizations(const Locale('en'))
            .faEnrolPlotLabel(number: number),
        boundaryGeoJson: _mode == _Mode.walk ? polygonGeoJson(_corners) : null,
        pin: pin,
        areaAcres: double.parse(area.toStringAsFixed(4)),
        areaSource: _mode == _Mode.walk
            ? AreaSource.boundary
            : AreaSource.typed,
        gpsAccuracyM: _mode == _Mode.walk ? _worstAccuracyM : fix?.accuracyM,
      );
      if (villageId != f.villageId) {
        try {
          await actions.updateFarmer(farmerId: f.id, villageId: villageId);
        } on FaActionError catch (e) {
          if (e.code != FaActionError.nothingToChange) rethrow;
        }
      }
      if (!mounted) return;
      // Not stuck in "saving" if the FA comes back to this page.
      setState(() => _saving = false);
      context.go(AppRoutes.enrolCrop(f.id, plotId: plotId));
    } on Object catch (e) {
      if (!mounted) return;
      final walkProblem =
          e is FaActionError &&
          (e.code == FaActionError.boundaryCrossesItself ||
              e.code == FaActionError.areaTooSmall);
      setState(() {
        _saving = false;
        if (walkProblem) _walkError = e.code;
      });
      if (!walkProblem) showActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final territory = watchTerritory(ref);
    final t = territory.value;
    final f = t?.farmer(widget.farmerId);
    final name = f?.displayName(contentLanguage(context));
    return Scaffold(
      body: Column(
        children: [
          FaHeader(
            title: name == null || name.isEmpty
                ? l10n.faEnrolTitle
                : l10n.faEnrolTitleName(name: name),
            subtitle: enrolStepLine(l10n, 2),
            back: true,
          ),
          Expanded(
            child: AsyncValueView(
              value: territory,
              onRetry: () => ref.invalidate(territoryProvider),
              data: (t) {
                final f = t.farmer(widget.farmerId);
                if (f == null || t.villages.isEmpty) {
                  return NotFoundCard(onBack: () => goBack(context));
                }
                return _body(t, f);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Territory t, SnapFarmer f) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final language = contentLanguage(context);
    final villageId = _villageFor(t, f);
    final village = t.village(villageId)!;
    final fromGps = _gpsVillage(t)?.id == villageId;
    final area = _area;

    final String areaValue;
    String? areaSub;
    if (_mode == _Mode.walk && _walk != _Walk.closed) {
      areaValue = _walk == _Walk.ready
          ? l10n.faEnrolPlotAreaNotYet
          : l10n.faEnrolPlotWalking;
      if (_walk != _Walk.ready) {
        areaSub = l10n.faEnrolPlotMetresSoFar(
          metres: pathMetres(_corners).round(),
        );
      }
    } else if (area == null) {
      areaValue = l10n.faEnrolPlotAreaNotYet;
    } else {
      areaValue = formatArea(l10n, area);
      areaSub = l10n.faEnrolPlotAcresDecimal(acres: area.toStringAsFixed(2));
    }

    final areaError = !_showErrors || area != null
        ? null
        : _mode == _Mode.walk
        ? l10n.faEnrolPlotErrorWalk
        : l10n.faEnrolPlotErrorTyped;

    return EnrolScroll(
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        OrbitSpace.s16,
        OrbitSpace.s16,
        OrbitSpace.s24,
      ),
      children: [
        const EnrolSteps(current: 1),
        const SizedBox(height: OrbitSpace.s16),
        SegmentedTabs(
          labels: [l10n.faEnrolPlotModeWalk, l10n.faEnrolPlotModeType],
          selectedIndex: _mode.index,
          onChanged: _saving
              ? null
              : (i) => setState(() {
                  _mode = _Mode.values[i];
                  _showErrors = false;
                  _walkError = null;
                }),
        ),
        const SizedBox(height: OrbitSpace.s12),
        if (_mode == _Mode.walk) ..._walkPart() else ..._typedPart(),
        const SizedBox(height: OrbitSpace.s16),
        EnrolCard(
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.faEnrolPlotArea,
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: OrbitFont.weightBold,
                  ),
                ),
                const SizedBox(width: OrbitSpace.s12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: areaValue,
                          style: const TextStyle(
                            fontWeight: OrbitFont.weightExtrabold,
                          ),
                        ),
                        if (areaSub != null) TextSpan(text: '  $areaSub'),
                      ],
                    ),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (areaError != null) ...[
          const SizedBox(height: OrbitSpace.s8),
          InlineError(areaError),
        ],
        if (_walkError case final code? when _mode == _Mode.walk) ...[
          const SizedBox(height: OrbitSpace.s8),
          EnrolNotice(
            icon: OrbitIcons.warning,
            tone: OrbitColors.of(context).warning,
            title: faActionErrorText(l10n, FaActionError(code)),
            live: true,
            actions: [
              OrbitButton(
                label: l10n.faEnrolPlotWalkAgain,
                icon: OrbitIcons.refresh,
                onPressed: _saving ? null : _walkAgain,
              ),
            ],
          ),
        ],
        const SizedBox(height: OrbitSpace.s16),
        EnrolCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyValueRow(
                label: fromGps
                    ? l10n.faEnrolPlotVillageFromGps
                    : l10n.faEnrolPlotVillage,
                value: village.displayName(language),
              ),
              KeyValueRow(
                label: l10n.faEnrolPlotMandal,
                value: village.displayMandal(language),
              ),
              if (t.villages.length > 1)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _pickVillage(t, villageId),
                    icon: const Icon(OrbitIcons.edit),
                    label: Text(l10n.faEnrolPlotChangeVillage),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: OrbitSpace.s20),
        OrbitButton(
          label: l10n.faEnrolPlotSaveNext,
          icon: OrbitIcons.chevronRight,
          loading: _saving,
          onPressed: _saving ? null : () => _save(t, f),
        ),
        const SizedBox(height: OrbitSpace.s8),
        InfoRow(icon: OrbitIcons.offline, text: l10n.faEnrolPlotSavedNote),
      ],
    );
  }

  String _gpsLine(OrbitLocalizations l10n, LocationFix fix) =>
      fix.goodForBoundary
      ? l10n.faEnrolPlotGpsGood(metres: fix.accuracyM.round())
      : l10n.faEnrolPlotGpsRough(metres: fix.accuracyM.round());

  List<Widget> _walkPart() {
    final l10n = context.l10n;
    final orbit = OrbitColors.of(context);
    final fix = _fix;
    final walking = _walk != _Walk.ready;

    // Before the walk starts the GPS must be good enough.
    if (!walking) {
      if (_checking || (fix == null && _problem == null)) {
        return [
          EnrolNotice(
            icon: OrbitIcons.location,
            tone: orbit.info,
            title: l10n.faEnrolPlotGpsChecking,
            body: l10n.faEnrolPlotGpsCheckingBody,
            live: true,
          ),
        ];
      }
      if (_problem case final problem?) {
        return [
          EnrolNotice(
            icon: OrbitIcons.warning,
            tone: orbit.warning,
            title: switch (problem) {
              LocationProblem.permissionDenied => l10n.faEnrolPlotGpsDenied,
              LocationProblem.serviceOff => l10n.faEnrolPlotGpsOff,
              LocationProblem.timeout => l10n.faEnrolPlotGpsNoFix,
            },
            body: l10n.faEnrolPlotGpsProblemBody,
            live: true,
            actions: _roughActions(),
          ),
        ];
      }
      if (!fix!.goodForBoundary) {
        return [
          EnrolNotice(
            icon: OrbitIcons.warning,
            tone: orbit.warning,
            title: l10n.faEnrolPlotGpsLowTitle(metres: fix.accuracyM.round()),
            body: l10n.faEnrolPlotGpsLowBody,
            live: true,
            actions: _roughActions(),
          ),
        ];
      }
    }

    final String status = switch (_walk) {
      _Walk.ready => l10n.faEnrolPlotReady,
      _Walk.recording => l10n.faEnrolPlotRecording(
        metres: pathMetres(_corners).round(),
      ),
      _Walk.paused => l10n.faEnrolPlotPaused(
        metres: pathMetres(_corners).round(),
      ),
      _Walk.closed => l10n.faEnrolPlotClosed,
    };
    final area = _walkedAcres;
    return [
      BoundarySketch(
        semanticLabel: _walk == _Walk.closed && area != null
            ? l10n.faEnrolPlotSketchClosed(area: formatArea(l10n, area))
            : l10n.faEnrolPlotSketchWalking(corners: _corners.length),
        corners: _corners,
        closed: _walk == _Walk.closed,
        here: _walk == _Walk.closed ? null : fix?.point,
        accuracyM: fix?.accuracyM,
      ),
      const SizedBox(height: OrbitSpace.s8),
      Wrap(
        spacing: OrbitSpace.s8,
        runSpacing: OrbitSpace.s8,
        children: [
          if (fix != null)
            StatusPill(
              label: _gpsLine(l10n, fix),
              tone: fix.goodForBoundary
                  ? OrbitStatusTone.success
                  : OrbitStatusTone.warning,
              icon: OrbitIcons.location,
            ),
          Semantics(
            liveRegion: true,
            child: StatusPill(
              label: status,
              tone: switch (_walk) {
                _Walk.closed => OrbitStatusTone.success,
                _Walk.recording => OrbitStatusTone.danger,
                _ => OrbitStatusTone.neutral,
              },
            ),
          ),
        ],
      ),
      if (walking && fix != null && !fix.goodForBoundary) ...[
        const SizedBox(height: OrbitSpace.s8),
        InlineError(l10n.faEnrolPlotRoughWhileWalking),
      ],
      const SizedBox(height: OrbitSpace.s12),
      ...switch (_walk) {
        _Walk.ready => [
          OrbitButton(
            label: l10n.faEnrolPlotStart,
            icon: OrbitIcons.pin,
            onPressed: _start,
          ),
        ],
        _Walk.recording || _Walk.paused => [
          Row(
            children: [
              Expanded(
                child: OrbitButton(
                  label: _walk == _Walk.recording
                      ? l10n.faEnrolPlotPause
                      : l10n.faEnrolPlotResume,
                  icon: _walk == _Walk.recording
                      ? OrbitIcons.pause
                      : OrbitIcons.location,
                  variant: OrbitButtonVariant.secondary,
                  onPressed: () => setState(
                    () => _walk = _walk == _Walk.recording
                        ? _Walk.paused
                        : _Walk.recording,
                  ),
                ),
              ),
              const SizedBox(width: OrbitSpace.s8),
              Expanded(
                child: OrbitButton(
                  label: l10n.faEnrolPlotUndo,
                  icon: OrbitIcons.back,
                  variant: OrbitButtonVariant.secondary,
                  onPressed: _corners.isEmpty ? null : _undo,
                ),
              ),
            ],
          ),
          const SizedBox(height: OrbitSpace.s8),
          OrbitButton(
            label: l10n.faEnrolPlotClose,
            icon: OrbitIcons.check,
            onPressed: _corners.length >= 3 ? _close : null,
          ),
          if (_corners.length < 3) ...[
            const SizedBox(height: OrbitSpace.s6),
            Text(
              l10n.faEnrolPlotNeedCorners,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
        _Walk.closed => [
          OrbitButton(
            label: l10n.faEnrolPlotWalkAgain,
            icon: OrbitIcons.refresh,
            variant: OrbitButtonVariant.secondary,
            onPressed: _saving ? null : _walkAgain,
          ),
        ],
      },
    ];
  }

  List<Widget> _roughActions() {
    final l10n = context.l10n;
    return [
      OrbitButton(
        label: l10n.faEnrolPlotModeType,
        icon: OrbitIcons.edit,
        onPressed: () => setState(() => _mode = _Mode.typed),
      ),
      OrbitButton(
        label: l10n.commonRetry,
        icon: OrbitIcons.refresh,
        variant: OrbitButtonVariant.secondary,
        onPressed: _tryAgain,
      ),
    ];
  }

  List<Widget> _typedPart() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final fix = _fix;
    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(5),
    ];
    final guntas = int.tryParse(_guntas.text.trim());
    final guntaError = guntas != null && guntas >= guntasPerAcre
        ? l10n.faEnrolPlotGuntasTooMany
        : null;
    return [
      Text(l10n.faEnrolPlotTypedNote, style: theme.textTheme.bodyMedium),
      const SizedBox(height: OrbitSpace.s12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EnrolFieldLabel(l10n.enumAreaUnitAcre),
                TextField(
                  key: const Key('enrol.acres'),
                  controller: _acres,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(width: OrbitSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EnrolFieldLabel(l10n.enumAreaUnitGunta),
                TextField(
                  key: const Key('enrol.guntas'),
                  controller: _guntas,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: InputDecoration(errorText: guntaError),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: OrbitSpace.s6),
      Text(l10n.faEnrolPlotGuntasPerAcre, style: theme.textTheme.bodySmall),
      const SizedBox(height: OrbitSpace.s12),
      BoundarySketch(
        semanticLabel: l10n.faEnrolPlotSketchPin,
        pin: fix?.point,
        height: 140,
      ),
      const SizedBox(height: OrbitSpace.s8),
      InfoRow(
        icon: OrbitIcons.pin,
        text: fix == null
            ? l10n.faEnrolPlotPinVillage
            : l10n.faEnrolPlotPinHere(metres: fix.accuracyM.round()),
      ),
    ];
  }
}
