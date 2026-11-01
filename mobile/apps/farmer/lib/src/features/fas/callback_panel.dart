import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/farmer_text.dart';
import 'fas_providers.dart';

/// The bottom of F3: "Ask your FA to call you back", or, once asked, the
/// "Request sent · Suresh will call you today" banner with Undo.
class CallbackPanel extends ConsumerStatefulWidget {
  /// Creates the panel. [myFa] (from Home) and [options] (the FA list) give
  /// the name of the FA who will call.
  const CallbackPanel({super.key, required this.myFa, required this.options});

  /// The farmer's assigned FA, when Home has loaded.
  final FarmerFaCard? myFa;

  /// The FAs on screen.
  final List<FaOption> options;

  @override
  ConsumerState<CallbackPanel> createState() => _CallbackPanelState();
}

class _CallbackPanelState extends ConsumerState<CallbackPanel> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() => _run(() async {
    try {
      await ref.read(openCallbackProvider.notifier).request();
    } on ApiError catch (error) {
      if (!mounted) return;
      // The request is safe to repeat, so offer Try again right away
      // (except when there is no FA to call back: asking again won't help).
      final retry = error.code != ApiErrorCode.noFaAssigned;
      _snack(
        errorText(context, error),
        action: retry
            ? SnackBarAction(
                label: context.l10n.commonRetry,
                onPressed: _request,
              )
            : null,
      );
    }
  });

  Future<void> _undo() => _run(() async {
    final l10n = context.l10n;
    try {
      await ref.read(openCallbackProvider.notifier).cancel();
      if (mounted) _snack(l10n.farmerFasCallbackCancelled);
    } on ApiError catch (error) {
      // callback_closed: the FA already called; the banner goes away.
      if (mounted) _snack(errorText(context, error));
    }
  });

  void _snack(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  /// The name of the FA [callback] went to, in the screen's language.
  String? _faName(Callback callback) {
    final language = contentLanguage(context);
    final mine = widget.myFa;
    if (mine != null && mine.id == callback.faId) {
      return mine.displayName(language);
    }
    for (final o in widget.options) {
      if (o.fa.id == callback.faId) return o.fa.displayName(language);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final callback = ref.watch(openCallbackProvider).fresh;
    // A failed load counts as "none open": asking again is safe.
    final open = callback.value;
    final name = open == null ? null : _faName(open);

    return Material(
      color: theme.colorScheme.surface,
      shape: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: open != null
            ? OrbitBanner(
                kind: OrbitBannerKind.success,
                title: l10n.farmerFasCallbackSent,
                message: name == null
                    ? null
                    : l10n.farmerFasCallbackSentBody(name: name),
                action: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OrbitButton(
                    label: l10n.commonUndo,
                    icon: OrbitIcons.close,
                    variant: OrbitButtonVariant.secondary,
                    size: OrbitButtonSize.medium,
                    fullWidth: false,
                    loading: _busy,
                    onPressed: _undo,
                  ),
                ),
              )
            : OrbitButton(
                label: l10n.farmerFasCallback,
                icon: OrbitIcons.phoneCall,
                loading: _busy || (callback.isLoading && !callback.hasValue),
                onPressed: _request,
              ),
      ),
    );
  }
}
