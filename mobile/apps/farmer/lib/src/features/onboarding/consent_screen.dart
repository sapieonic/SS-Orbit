import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/call_buttons.dart';
import '../../shared/sign_in_scaffold.dart';
import '../../shared/voice.dart';

/// F1a: the programme consent, asked once after the first sign-in and
/// before the village picker.
///
/// "OK, I agree" stores it (`purpose: programme`) with `audio_played` true
/// when the farmer played the Listen prompt to the end. There is no decline
/// call: the service needs this consent, so "Not now" explains that and
/// offers the helpline. The soil-partner question waits for the first
/// soil-test booking (plan, F1a row).
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  static const _voiceKey = VoiceKeys.farmerConsentVoiceHelp;

  late final StreamSubscription<String> _completed;
  bool _audioPlayed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _completed = ref.read(voicePlayerProvider).completed.listen((key) {
      if (key == _voiceKey) _audioPlayed = true;
    });
  }

  @override
  void dispose() {
    unawaited(_completed.cancel());
    super.dispose();
  }

  Future<void> _agree() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .giveConsent(audioPlayed: _audioPlayed);
      // No "saved" snack bar: the village picker opening says it, and a
      // snack bar would sit over the next screens' main button.
    } on ApiError catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _notNow() async {
    final agree = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _DeclineSheet(),
    );
    if (agree == true && mounted) await _agree();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SignInScaffold(
      header: ScreenHeader(
        title: l10n.farmerConsentTitle,
        listen: const ScreenListenButton(voiceKey: _voiceKey),
      ),
      content: [
        Text(l10n.farmerConsentPurpose, style: theme.textTheme.bodyLarge),
        const SizedBox(height: OrbitSpace.s16),
        _ConsentPoint(
          icon: OrbitIcons.consent,
          text: l10n.farmerConsentPointSafe,
        ),
        const SizedBox(height: OrbitSpace.s12),
        _ConsentPoint(
          icon: OrbitIcons.people,
          text: l10n.farmerConsentPointPartners,
        ),
        const SizedBox(height: OrbitSpace.s12),
        _ConsentPoint(
          icon: OrbitIcons.settings,
          text: l10n.farmerConsentPointChange,
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrbitButton(
            label: l10n.farmerConsentAgree,
            icon: OrbitIcons.check,
            size: OrbitButtonSize.hero,
            loading: _saving,
            onPressed: _agree,
          ),
          const SizedBox(height: OrbitSpace.s4),
          TextButton(
            onPressed: _saving ? null : _notNow,
            child: Text(l10n.farmerConsentNotNow),
          ),
        ],
      ),
    );
  }
}

/// One of the three wireframe points: icon disc and a line of text.
class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(OrbitSpace.s12),
                child: Icon(
                  icon,
                  size: OrbitSize.iconLg,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: OrbitSpace.s12),
            Expanded(child: Text(text, style: theme.textTheme.titleMedium)),
          ],
        ),
      ),
    );
  }
}

/// "Not now": why the consent is needed, and the helpline as the way to
/// talk it through. Pops `true` when the farmer agrees after all.
class _DeclineSheet extends StatelessWidget {
  const _DeclineSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
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
            Text(l10n.farmerConsentDeclined, style: theme.textTheme.titleLarge),
            const SizedBox(height: OrbitSpace.s12),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: ScreenListenButton(
                voiceKey: VoiceKeys.farmerConsentVoiceHelpDeclined,
              ),
            ),
            const SizedBox(height: OrbitSpace.s20),
            const CallHelplineButton(size: OrbitButtonSize.hero),
            const SizedBox(height: OrbitSpace.s12),
            OrbitButton(
              label: l10n.farmerConsentAgree,
              icon: OrbitIcons.check,
              variant: OrbitButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
