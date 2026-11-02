import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../shared/async_view.dart';

/// Opens Edit profile for [farmer] (name, Telugu name, language). Resolves
/// to true when a change was saved on the phone (UpdateFarmer queued).
Future<bool> showEditProfileSheet(BuildContext context, SnapFarmer farmer) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => EditProfileSheet(farmer: farmer),
    ).then((saved) => saved ?? false);

/// The Edit profile sheet of Farmer 360. Saves through
/// `FaActions.updateFarmer`, which leaves out unchanged fields; HO gets it at
/// the next sync (a clash with an HO edit shows on Farmer 360).
class EditProfileSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [farmer].
  const EditProfileSheet({super.key, required this.farmer});

  /// The farmer as the phone has it now.
  final SnapFarmer farmer;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final _name = TextEditingController(text: widget.farmer.name ?? '');
  late final _nameTe = TextEditingController(text: widget.farmer.nameTe ?? '');
  late Language _language = widget.farmer.language;
  bool _saving = false;
  String? _nameError;
  String? _nameTeError;
  String? _note;

  @override
  void dispose() {
    _name.dispose();
    _nameTe.dispose();
    super.dispose();
  }

  String _fieldError(OrbitLocalizations l10n, String code) =>
      code == FaActionError.tooLong
      ? l10n.faFarmer360EditTooLong
      : l10n.faFarmer360EditRequired;

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? l10n.faFarmer360EditRequired : null;
      _nameTeError = null;
      _note = null;
    });
    if (_nameError != null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(faActionsProvider)
          .updateFarmer(
            farmerId: widget.farmer.id,
            name: name,
            nameTe: _nameTe.text,
            language: _language,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on FaActionError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        switch ((e.code, e.field)) {
          case (FaActionError.nothingToChange, _):
            _note = l10n.faFarmer360EditNothingChanged;
          case (FaActionError.required || FaActionError.tooLong, 'name'):
            _nameError = _fieldError(l10n, e.code);
          case (FaActionError.required || FaActionError.tooLong, 'name_te'):
            _nameTeError = _fieldError(l10n, e.code);
          case (FaActionError.cannotClear, _):
            // HO keeps the Telugu name once set: say so on the field.
            _nameTeError = l10n.faActionErrorCannotClear;
          default:
            _note = faActionErrorText(l10n, e);
        }
      });
    } on Object catch (e) {
      // Storage failed: say so and let the FA try again.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _note = faActionErrorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OrbitSpace.s16,
          0,
          OrbitSpace.s16,
          OrbitSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.faFarmer360EditProfile,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: OrbitSpace.s16),
            TextField(
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: l10n.faFarmer360EditName,
                errorText: _nameError,
                counterText: '',
              ),
            ),
            const SizedBox(height: OrbitSpace.s12),
            TextField(
              controller: _nameTe,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: l10n.faFarmer360EditNameTe,
                errorText: _nameTeError,
                counterText: '',
              ),
            ),
            const SizedBox(height: OrbitSpace.s16),
            Text(
              l10n.faFarmer360EditLanguage,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: OrbitSpace.s8),
            SegmentedTabs(
              labels: [l10n.enumLanguageTe, l10n.enumLanguageEn],
              selectedIndex: _language == Language.te ? 0 : 1,
              onChanged: _saving
                  ? null
                  : (i) => setState(
                      () => _language = i == 0 ? Language.te : Language.en,
                    ),
            ),
            if (_note case final note?) ...[
              const SizedBox(height: OrbitSpace.s12),
              InlineError(note),
            ],
            const SizedBox(height: OrbitSpace.s20),
            OrbitButton(
              label: l10n.commonSave,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
