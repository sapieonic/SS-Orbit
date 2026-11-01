import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';
import 'package:orbit_voice/orbit_voice.dart';

import '../../data/data.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/voice.dart';
import 'advisory_providers.dart';
import 'notice_widgets.dart';

/// One crop advisory notice in full. Opening it marks it read; its voice
/// note (when it has one) plays from the Listen button in the header, and
/// playing it to the end marks it listened (FAR-03).
class NoticeScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [noticeId].
  const NoticeScreen({super.key, required this.noticeId});

  /// The notice.
  final String noticeId;

  @override
  ConsumerState<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends ConsumerState<NoticeScreen> {
  late final VoicePlayer _player;
  bool _readSent = false;

  @override
  void initState() {
    super.initState();
    _player = ref.read(voicePlayerProvider);
    ref.listenManual<AsyncValue<Notice?>>(
      noticeByIdProvider(widget.noticeId),
      (_, next) => _markReadOnce(next.fresh.value),
      fireImmediately: true,
    );
  }

  /// Marks the notice read the first time it is shown unread. A failure
  /// (offline) leaves it unread; the next open tries again.
  void _markReadOnce(Notice? notice) {
    if (_readSent || notice == null || notice.isRead) return;
    _readSent = true;
    unawaited(
      ref
          .read(noticesControllerProvider.notifier)
          .markRead(notice.id)
          .catchError((Object error) => debugPrint('markRead failed: $error')),
    );
  }

  @override
  void dispose() {
    // Leaving the notice stops its voice note (one task per screen).
    if (_player.state.value.key == widget.noticeId) unawaited(_player.stop());
    super.dispose();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(Routes.advisory);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notice = ref.watch(noticeByIdProvider(widget.noticeId)).fresh;
    final loaded = notice.value;
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: l10n.farmerInboxTitle,
            subtitle: loaded == null ? null : noticeSource(l10n, loaded.sender),
            onBack: _back,
            listen: switch (loaded) {
              null => const ScreenListenButton(
                voiceKey: VoiceKeys.farmerInboxVoiceHelp,
              ),
              final notice when notice.audioUrl != null => NoticeAudioButton(
                notice: notice,
              ),
              // No voice note: say so, and to read it or ask the FA.
              _ => const ScreenListenButton(
                voiceKey: VoiceKeys.farmerInboxNoAudioVoice,
              ),
            },
          ),
          Expanded(
            // Loaded but no such notice: AsyncValueView only knows non-null
            // data, so not-found is decided here.
            child: notice.hasValue && loaded == null
                ? NotFoundCard(onBack: _back)
                : AsyncValueView(
                    value: notice,
                    onRetry: () {
                      ref
                        ..invalidate(noticesControllerProvider)
                        ..invalidate(noticeByIdProvider(widget.noticeId));
                    },
                    data: (notice) => _NoticeBody(notice: notice!),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBody extends ConsumerWidget {
  const _NoticeBody({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final language = ref.watch(appLanguageProvider);
    final now = ref.watch(clockProvider).now();
    return ListView(
      padding: const EdgeInsets.all(OrbitSpace.s16),
      children: [
        Wrap(
          spacing: OrbitSpace.s8,
          runSpacing: OrbitSpace.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OrbitTag(label: noticeSource(l10n, notice.sender)),
            Text(
              noticeTime(l10n, notice.createdAt, now),
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (notice.pinned)
              OrbitTag(
                label: l10n.farmerInboxPinned,
                tone: OrbitTagTone.primary,
                icon: OrbitIcons.pin,
              ),
            if (notice.isListened)
              OrbitTag(label: l10n.farmerInboxListened, icon: OrbitIcons.check),
          ],
        ),
        const SizedBox(height: OrbitSpace.s12),
        Text(notice.title(language), style: theme.textTheme.headlineSmall),
        const SizedBox(height: OrbitSpace.s8),
        Text(notice.body(language), style: theme.textTheme.bodyLarge),
        if (notice.audioUrl == null) ...[
          const SizedBox(height: OrbitSpace.s16),
          InfoRow(
            icon: OrbitIcons.listenUnavailable,
            text: l10n.farmerInboxNoAudio,
          ),
        ],
      ],
    );
  }
}
