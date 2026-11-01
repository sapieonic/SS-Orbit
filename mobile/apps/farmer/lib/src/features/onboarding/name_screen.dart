import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/farmer_text.dart';
import '../../shared/sign_in_scaffold.dart';
import '../../shared/voice.dart';
import 'widgets/place_tile.dart';

/// Last sign-up step: the picked village (with "Change") and the farmer's
/// name, then "Finish" calls complete-profile. The router opens Home when
/// the session turns active; `profile_already_complete` counts as done.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _fieldError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    final l10n = context.l10n;
    final (:name, :nameTe) = profileName(_name.text);
    if (name.isEmpty) {
      setState(() => _fieldError = l10n.farmerNameRequired);
      return;
    }
    // The field caps letters as the farmer sees them; the API counts code
    // points, and one Telugu letter can be several.
    if (name.runes.length > farmerNameMaxLength) {
      setState(
        () => _fieldError = l10n.describeError(ApiErrorCode.validationFailed),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final done = l10n.farmerNameDone;
    setState(() {
      _saving = true;
      _fieldError = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .completeProfile(name: name, nameTe: nameTe);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == ApiErrorCode.validationFailed) {
        setState(() => _fieldError = errorText(context, e));
      } else {
        showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changeVillage() {
    if (_saving) return;
    if (ref.read(sessionProvider).phase == SessionPhase.needsName) {
      ref.read(sessionProvider.notifier).changeVillage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final village = ref.watch(sessionProvider.select((s) => s.village));
    final language = ref.watch(appLanguageProvider);

    return PopScope(
      // Back goes to the village picker, like "Change".
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _changeVillage();
      },
      child: SignInScaffold(
        header: ScreenHeader(
          title: l10n.farmerNameTitle,
          subtitle: l10n.farmerNameSubtitle,
          onBack: _saving ? null : _changeVillage,
          listen: const ScreenListenButton(
            voiceKey: VoiceKeys.farmerNameVoiceHelp,
          ),
        ),
        content: [
          if (village != null)
            _PickedVillage(
              village: village,
              language: language,
              onChange: _saving ? null : _changeVillage,
            ),
          const SizedBox(height: OrbitSpace.s20),
          TextField(
            controller: _name,
            enabled: !_saving,
            autofocus: true,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            inputFormatters: [
              LengthLimitingTextInputFormatter(farmerNameMaxLength),
            ],
            style: theme.textTheme.titleLarge,
            onChanged: (_) {
              if (_fieldError != null) setState(() => _fieldError = null);
            },
            onSubmitted: (_) => _finish(),
            decoration: InputDecoration(
              labelText: l10n.farmerNameTitle,
              hintText: l10n.farmerNameHint,
              errorText: _fieldError,
              prefixIcon: const Icon(OrbitIcons.person),
            ),
          ),
        ],
        bottom: OrbitButton(
          label: l10n.farmerNameFinish,
          icon: OrbitIcons.check,
          size: OrbitButtonSize.hero,
          loading: _saving,
          onPressed: _finish,
        ),
      ),
    );
  }
}

class _PickedVillage extends StatelessWidget {
  const _PickedVillage({
    required this.village,
    required this.language,
    required this.onChange,
  });

  final Village village;
  final Language language;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final name = bilingualName(language, te: village.nameTe, en: village.name);
    final area = villageArea(context, village, language);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OrbitSpace.s12,
          OrbitSpace.s12,
          OrbitSpace.s4,
          OrbitSpace.s12,
        ),
        child: InfoRow(
          icon: OrbitIcons.location,
          text: name.secondary == null
              ? name.primary
              : context.l10n.commonDotJoin(
                  first: name.primary,
                  second: name.secondary!,
                ),
          secondaryText: area,
          trailing: TextButton(
            onPressed: onChange,
            child: Text(context.l10n.commonEdit),
          ),
        ),
      ),
    );
  }
}
