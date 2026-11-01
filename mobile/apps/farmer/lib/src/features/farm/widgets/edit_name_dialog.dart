import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';
import '../../../shared/async_view.dart';
import '../../../shared/farmer_data.dart';
import '../../../shared/farmer_text.dart';
import '../../../shared/voice.dart';

/// Asks for a new name and saves it (`PATCH /v1/farmer/me`). One field: the
/// name as the farmer sees it now. It is saved as [renamedProfile] says:
/// always as `name`, and also as `name_te` when typed in Telugu, or when it
/// replaces the Telugu spelling shown in Telugu. Back and taps outside are
/// ignored while saving.
///
/// Returns true when the name was saved (Home and My farm are refreshed,
/// also if the dialog was gone by then).
Future<bool> showEditNameDialog(
  BuildContext context, {
  required Farmer farmer,
  required Language language,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _EditNameDialog(farmer: farmer, language: language),
  );
  return saved ?? false;
}

class _EditNameDialog extends ConsumerStatefulWidget {
  const _EditNameDialog({required this.farmer, required this.language});

  final Farmer farmer;
  final Language language;

  /// The name the field starts with: the one the farmer sees.
  String get initial => farmer.displayName(language);

  @override
  ConsumerState<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends ConsumerState<_EditNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = profileName(_controller.text).name;
    if (name.isEmpty) {
      setState(() => _error = l10n.farmerNameRequired);
      return;
    }
    // The field caps letters as the farmer sees them; the API counts code
    // points, and one Telugu letter can be several.
    if (name.runes.length > farmerNameMaxLength) {
      setState(
        () => _error = l10n.describeError(ApiErrorCode.validationFailed),
      );
      return;
    }
    if (name == profileName(widget.initial).name) {
      Navigator.of(context).pop(false);
      return;
    }
    final edits = ref.read(farmerEditsProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await edits.updateName(
        name,
        farmer: widget.farmer,
        language: widget.language,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorText(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.farmerFarmChangeName),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                LengthLimitingTextInputFormatter(farmerNameMaxLength),
              ],
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l10n.farmerNameTitle,
                hintText: l10n.farmerNameHint,
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: OrbitSpace.s12),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: ScreenListenButton(
                voiceKey: VoiceKeys.farmerFarmChangeNameVoice,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          OrbitButton(
            label: l10n.commonSave,
            fullWidth: false,
            size: OrbitButtonSize.medium,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
