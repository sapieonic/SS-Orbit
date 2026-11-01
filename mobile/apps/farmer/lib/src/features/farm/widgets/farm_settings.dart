import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';
import '../../../shared/async_view.dart';
import '../../../shared/voice.dart';

/// Language: తెలుగు / English. The app switches at once; the choice is also
/// saved to the profile (SMS language), see `SessionController.setLanguage`.
/// Taps wait until the last choice is saved, so two saves never race.
class LanguageCard extends ConsumerStatefulWidget {
  /// Creates the language card showing [language] as chosen.
  const LanguageCard({super.key, required this.language});

  /// The language the app is in.
  final Language language;

  @override
  ConsumerState<LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends ConsumerState<LanguageCard> {
  bool _saving = false;

  Future<void> _choose(Language next) async {
    if (_saving || next == widget.language) return;
    final messenger = ScaffoldMessenger.of(context);
    // The screen rebuilds in the new language; word the snack bar in it too.
    final l10n = lookupOrbitLocalizations(Locale(next.wire));
    setState(() => _saving = true);
    String message;
    try {
      await ref.read(sessionProvider.notifier).setLanguage(next);
      message = l10n.farmerFarmLanguageChanged;
    } on Object catch (e) {
      // The app language changed; only saving it (profile, or this phone)
      // failed.
      message = errorTextIn(l10n, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const options = Language.values;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(icon: OrbitIcons.language, text: l10n.farmerFarmLanguage),
            const SizedBox(height: OrbitSpace.s12),
            SegmentedTabs(
              labels: [for (final o in options) l10n.labelLanguage(o.wire)],
              selectedIndex: options.indexOf(widget.language),
              onChanged: (i) => _choose(options[i]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sign out, after a confirmation. The router then shows the login screen.
class SignOutButton extends ConsumerStatefulWidget {
  /// Creates the sign-out button.
  const SignOutButton({super.key});

  @override
  ConsumerState<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<SignOutButton> {
  bool _busy = false;

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.farmerFarmSignOutTitle),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.farmerFarmSignOutBody),
            const SizedBox(height: OrbitSpace.s12),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: ScreenListenButton(
                voiceKey: VoiceKeys.farmerFarmSignOutVoice,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          OrbitButton(
            label: l10n.commonSignOut,
            variant: OrbitButtonVariant.danger,
            size: OrbitButtonSize.medium,
            fullWidth: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).signOut();
    } on Object catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OrbitButton(
    label: context.l10n.commonSignOut,
    icon: OrbitIcons.logOut,
    variant: OrbitButtonVariant.secondary,
    size: OrbitButtonSize.medium,
    loading: _busy,
    onPressed: _signOut,
  );
}
