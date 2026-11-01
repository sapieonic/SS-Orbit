import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/call_buttons.dart';
import '../../shared/voice.dart';

/// Shown while HO has paused the farmer's account (`farmer_status:
/// inactive`): one card, "Account paused, call helpline", with a call
/// action. Try again (or pull down) checks again after the helpline has
/// re-activated the account; "Sign out" lets someone else sign in on this
/// phone.
class PausedScreen extends ConsumerStatefulWidget {
  const PausedScreen({super.key});

  @override
  ConsumerState<PausedScreen> createState() => _PausedScreenState();
}

class _PausedScreenState extends ConsumerState<PausedScreen> {
  bool _rechecking = false;
  bool _signingOut = false;

  /// Asks the server again; an active account then leaves this screen.
  Future<void> _recheck() async {
    setState(() => _rechecking = true);
    try {
      await ref.read(sessionProvider.notifier).recheck();
    } on Object catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _rechecking = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await ref.read(sessionProvider.notifier).signOut();
    } on Object catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const listen = ScreenListenButton(
      voiceKey: VoiceKeys.farmerLoginVoiceHelpPaused,
    );
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(title: l10n.commonAppName, listen: listen),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _recheck,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(OrbitSpace.s16),
                children: [
                  StateCard(
                    icon: OrbitIcons.lock,
                    tone: StateCardTone.warning,
                    title: l10n.farmerLoginPausedTitle,
                    subtitle: l10n.farmerLoginAccountPaused,
                    action: const CallHelplineButton(
                      size: OrbitButtonSize.hero,
                    ),
                  ),
                  const SizedBox(height: OrbitSpace.s16),
                  OrbitButton(
                    label: l10n.commonRetry,
                    icon: OrbitIcons.refresh,
                    variant: OrbitButtonVariant.secondary,
                    loading: _rechecking,
                    onPressed: _rechecking || _signingOut ? null : _recheck,
                  ),
                  const SizedBox(height: OrbitSpace.s8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _signingOut || _rechecking ? null : _signOut,
                      icon: const Icon(OrbitIcons.logOut),
                      label: Text(l10n.commonSignOut),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
