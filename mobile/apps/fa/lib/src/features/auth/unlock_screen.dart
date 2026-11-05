import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../shared/formatters.dart';
import 'auth_support.dart';
import 'auth_widgets.dart';

/// A1b PIN unlock, offline within the grace.
///
/// The PIN is checked as soon as the last digit is typed. Right: the session
/// is active and the router returns to where the FA was (so the design's
/// "Unlocked" card never shows). Wrong: the dots turn red with the tries
/// left; the last wrong try, or a grace that ended, moves the session to the
/// password login by itself. No fingerprint key: there is no biometric
/// service yet.
class UnlockScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  String _typed = '';
  bool _checking = false;
  bool _wrong = false;

  void _digit(String d) {
    final length = ref.read(sessionProvider).policy.pinLength;
    if (_checking || _typed.length >= length) return;
    setState(() {
      _typed += d;
      _wrong = false;
    });
    if (_typed.length == length) _check(_typed);
  }

  void _delete() {
    if (_checking || _typed.isEmpty) return;
    setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  Future<void> _check(String pin) async {
    setState(() => _checking = true);
    var unlocked = false;
    try {
      unlocked = await ref.read(sessionProvider.notifier).unlock(pin);
    } on StateError {
      // The phase moved on meanwhile (e.g. a wipe); the router follows it.
    } on Object catch (e) {
      // Never leave the pad disabled; the try was counted anyway.
      debugPrint('PIN check failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (!unlocked) {
        _typed = '';
        _wrong = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final session = ref.watch(sessionProvider);
    final policy = session.policy;
    final online = ref.watch(phoneOnlineProvider);
    final language = contentLanguage(context);
    final area = areaLabel(ref.watch(territoryProvider).value, language);
    final fa = session.fa;
    final left = session.pinAttemptsLeft;
    final triesLeft = left != null && left < policy.pinMaxAttempts
        ? l10n.faUnlockTriesLeft(count: left)
        : null;
    final hint = _wrong
        ? dotJoin(l10n, [l10n.faUnlockWrongPin, triesLeft])
        : triesLeft;

    return PlainPage(
      child: FillScroll(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        content: [
          Center(child: _Avatar(name: fa?.name)),
          Column(
            children: [
              if (fa != null)
                Semantics(
                  header: true,
                  child: Text(
                    l10n.faUnlockWelcome(
                      name: firstName(fa.displayName(language)),
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall!.copyWith(
                      fontWeight: OrbitFont.weightExtrabold,
                    ),
                  ),
                ),
              if (fa != null)
                Text(
                  dotJoin(l10n, [fa.code, area]),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: orbit.textMuted,
                  ),
                ),
              const SizedBox(height: OrbitSpace.s10),
              online
                  ? StatusPill(
                      label: l10n.faAuthOnline,
                      tone: OrbitStatusTone.success,
                      icon: OrbitIcons.synced,
                    )
                  : StatusPill(
                      label: l10n.faAuthOfflineSaved,
                      tone: OrbitStatusTone.warning,
                      icon: OrbitIcons.offline,
                    ),
            ],
          ),
          PinEntryView(
            label: l10n.faUnlockEnterPin(length: policy.pinLength),
            length: policy.pinLength,
            filled: _typed.length,
            error: _wrong,
            hint: hint,
            enabled: !_checking,
            onDigit: _digit,
            onDelete: _delete,
          ),
        ],
        bottom: [
          Text(
            l10n.faUnlockGraceNote(days: policy.offlineGraceDays),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall!.copyWith(
              fontSize: 14,
              color: orbit.textMuted,
            ),
          ),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, OrbitSize.controlLg),
              ),
              onPressed: _checking
                  ? null
                  : () => ref.read(sessionProvider.notifier).usePassword(),
              child: Text(l10n.faUnlockUsePassword),
            ),
          ),
        ],
      ),
    );
  }
}

/// The FA's initials in a blue disc with a small green tick.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final initials = nameInitials(name);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 66,
        child: Stack(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: initials == null
                  ? Icon(OrbitIcons.person, color: scheme.onPrimary, size: 30)
                  : Text(
                      initials,
                      textScaler: TextScaler.noScaling,
                      style: theme.textTheme.titleLarge!.copyWith(
                        color: scheme.onPrimary,
                        fontSize: 22,
                        fontWeight: OrbitFont.weightExtrabold,
                      ),
                    ),
            ),
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: orbit.success.fg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 3,
                  ),
                ),
                child: Icon(
                  OrbitIcons.check,
                  size: 12,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
