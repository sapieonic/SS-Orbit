import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';

/// The OTP step's Resend button: "Resend OTP in 0:24" (disabled) until
/// [availableAt], then "Resend OTP".
///
/// Time comes from [clockProvider], so tests move it with a `FixedClock`.
/// The widget only rebuilds when the shown second changes, and stops ticking
/// once Resend is available.
class ResendCountdown extends ConsumerStatefulWidget {
  /// Creates the button.
  const ResendCountdown({
    super.key,
    required this.availableAt,
    required this.onResend,
    this.loading = false,
    this.highlighted = false,
  });

  /// When Resend may be tapped (UTC); null means now.
  final DateTime? availableAt;

  /// Sends a new code; null disables the button.
  final VoidCallback? onResend;

  /// Shows a spinner while the new code is being sent.
  final bool loading;

  /// Draws Resend as the screen's main action (the old code is dead).
  final bool highlighted;

  @override
  ConsumerState<ResendCountdown> createState() => _ResendCountdownState();
}

class _ResendCountdownState extends ConsumerState<ResendCountdown> {
  static const _tick = Duration(seconds: 1);

  Timer? _timer;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ResendCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableAt != widget.availableAt) _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _secondsLeft() {
    final at = widget.availableAt;
    if (at == null) return 0;
    final left = at.difference(ref.read(clockProvider).now());
    if (left <= Duration.zero) return 0;
    return (left.inMilliseconds / Duration.millisecondsPerSecond).ceil();
  }

  void _sync() {
    _timer?.cancel();
    _shown = _secondsLeft();
    if (_shown == 0) return;
    _timer = Timer.periodic(_tick, (_) {
      final left = _secondsLeft();
      if (left != _shown) setState(() => _shown = left);
      if (left == 0) _timer?.cancel();
    });
  }

  static String _minutesSeconds(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_shown > 0) {
      return OrbitButton(
        label: l10n.farmerLoginResendIn(time: _minutesSeconds(_shown)),
        icon: OrbitIcons.pending,
        variant: OrbitButtonVariant.secondary,
        onPressed: null,
      );
    }
    return OrbitButton(
      label: l10n.farmerLoginResend,
      icon: OrbitIcons.refresh,
      variant: widget.highlighted
          ? OrbitButtonVariant.primary
          : OrbitButtonVariant.secondary,
      loading: widget.loading,
      onPressed: widget.onResend,
    );
  }
}
