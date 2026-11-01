import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/farmer_data.dart';
import '../../shared/voice.dart';
import 'farm_providers.dart';
import 'widgets/plot_steps.dart';

/// Add a plot (F10), one input per step (NFR-03): (1) an optional name,
/// (2) the location, (3) the area in acres and guntas. Saves with
/// `POST /v1/farmer/me/plots`, refreshes Home and goes back with
/// "Plot added".
///
/// The location is the village's for now; see [plotPinProvider].
class AddPlotScreen extends ConsumerStatefulWidget {
  const AddPlotScreen({super.key});

  @override
  ConsumerState<AddPlotScreen> createState() => _AddPlotScreenState();
}

enum _Step { label, location, area }

class _AddPlotScreenState extends ConsumerState<AddPlotScreen> {
  final _label = TextEditingController();
  final _acres = TextEditingController();
  final _guntas = TextEditingController();
  var _step = _Step.label;
  String? _areaError;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _acres.dispose();
    _guntas.dispose();
    super.dispose();
  }

  void _back() {
    if (_saving) return;
    if (_step == _Step.label) {
      context.pop();
    } else {
      setState(() => _step = _Step.values[_step.index - 1]);
    }
  }

  void _next() {
    FocusScope.of(context).unfocus();
    setState(() => _step = _Step.values[_step.index + 1]);
  }

  /// The typed area, or null after showing why it is not valid.
  AcresGuntas? _validArea() {
    final l10n = context.l10n;
    final acres = int.tryParse(_acres.text.trim()) ?? 0;
    final guntas = int.tryParse(_guntas.text.trim()) ?? 0;
    final String? error;
    if (guntas >= guntasPerAcre) {
      error = l10n.farmerPlotAddGuntasInvalid;
    } else if (acres == 0 && guntas == 0) {
      error = l10n.farmerPlotAddAreaInvalid;
    } else if (acres > maxPlotAcres || (acres == maxPlotAcres && guntas > 0)) {
      error = l10n.farmerPlotAddAreaTooBig(max: maxPlotAcres);
    } else {
      error = null;
    }
    setState(() => _areaError = error);
    return error == null ? AcresGuntas(acres, guntas) : null;
  }

  Future<void> _save(LatLng pin) async {
    final area = _validArea();
    if (area == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final label = _label.text.trim();
    final edits = ref.read(farmerEditsProvider);
    setState(() => _saving = true);
    try {
      // Refreshes Home even if this screen is gone by the time the server
      // answers.
      await edits.addPlot(
        label: label.isEmpty ? null : label,
        pin: pin,
        areaAcres: area.totalAcres,
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.farmerPlotAddSaved)));
      context.pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pin = ref.watch(plotPinProvider).fresh;
    final step = _step.index + 1;
    final (voiceKey, Widget body, Widget? action) = switch (_step) {
      _Step.label => (
        VoiceKeys.farmerPlotAddVoiceHelpLabel,
        PlotLabelStep(controller: _label, onDone: _next),
        OrbitButton(
          label: l10n.commonNext,
          size: OrbitButtonSize.hero,
          onPressed: _next,
        ),
      ),
      _Step.location => (
        VoiceKeys.farmerPlotAddVoiceHelpVillagePin,
        PlotLocationStep(pin: pin),
        pin.value == null
            ? null
            : OrbitButton(
                label: l10n.commonNext,
                size: OrbitButtonSize.hero,
                onPressed: _next,
              ),
      ),
      _Step.area => (
        VoiceKeys.farmerPlotAddVoiceHelpArea,
        PlotAreaStep(
          acres: _acres,
          guntas: _guntas,
          error: _areaError,
          enabled: !_saving,
        ),
        OrbitButton(
          label: l10n.farmerPlotAddSave,
          icon: OrbitIcons.check,
          size: OrbitButtonSize.hero,
          loading: _saving,
          onPressed: switch (pin.value) {
            final p? => () => _save(p),
            null => null,
          },
        ),
      ),
    };
    return PopScope(
      canPop: _step == _Step.label && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: StepLayout(
        title: l10n.farmerPlotAddTitle,
        step: step,
        totalSteps: _Step.values.length,
        stepLabel: l10n.commonStepOf(step: step, total: _Step.values.length),
        listen: ScreenListenButton(voiceKey: voiceKey),
        onBack: _back,
        action: action,
        child: body,
      ),
    );
  }
}
