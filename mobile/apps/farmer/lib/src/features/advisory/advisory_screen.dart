import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/farmer_data.dart';
import '../../shared/paged_list.dart';
import '../../shared/voice.dart';
import 'advisory_providers.dart';
import 'notice_widgets.dart';

/// My Crop Advisory (F5): notices from Shanmukha, CIV and the FA, pinned
/// first, then newest. Unread ones carry a dot; tapping one opens it.
class AdvisoryScreen extends ConsumerWidget {
  /// Creates the screen.
  const AdvisoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notices = ref.watch(noticesControllerProvider).fresh;
    final unread = ref.watch(unreadNoticesCountProvider).fresh.value;
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: l10n.farmerInboxTitle,
            subtitle: unread == null
                ? null
                : l10n.farmerInboxNewCount(count: unread),
            listen: const ScreenListenButton(
              voiceKey: VoiceKeys.farmerInboxVoiceHelp,
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: notices,
              onRetry: () {
                ref
                  ..invalidate(noticesControllerProvider)
                  ..invalidate(unreadNoticesCountProvider);
              },
              data: (list) => _Inbox(list: list),
            ),
          ),
        ],
      ),
    );
  }
}

class _Inbox extends ConsumerWidget {
  const _Inbox({required this.list});

  final PagedList<Notice> list;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    ref
      ..invalidate(noticesControllerProvider)
      ..invalidate(unreadNoticesCountProvider);
    try {
      await ref.read(noticesControllerProvider.future);
    } on Object catch (error) {
      // The old list stays on screen; say why it did not update.
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final now = ref.watch(clockProvider).now();
    final children = <Widget>[
      if (list.items.isEmpty)
        StateCard(
          icon: OrbitIcons.inbox,
          title: l10n.farmerInboxEmptyTitle,
          subtitle: l10n.farmerInboxEmptyBody,
          listen: const ScreenListenButton(
            voiceKey: VoiceKeys.farmerStateNoAdviceVoice,
          ),
        ),
      for (final notice in list.items)
        NoticeCard(
          key: ValueKey(notice.id),
          source: noticeSource(l10n, notice.sender),
          meta: noticeTime(l10n, notice.createdAt, now),
          title: notice.title(language),
          body: notice.body(language),
          pinned: notice.pinned,
          pinnedLabel: l10n.farmerInboxPinned,
          unread: !notice.isRead,
          unreadLabel: l10n.farmerInboxUnread,
          actions: [
            if (notice.isListened)
              OrbitTag(label: l10n.farmerInboxListened, icon: OrbitIcons.check),
          ],
          onTap: () => context.go(Routes.notice(notice.id)),
        ),
      if (list.hasMore || list.loadMoreError != null)
        LoadMoreFooter(
          key: ValueKey(list.nextCursor),
          loading: list.loadingMore,
          errorText: switch (list.loadMoreError) {
            final error? => errorText(context, error),
            null => null,
          },
          loadingLabel: l10n.commonLoading,
          retryLabel: l10n.commonRetry,
          onLoadMore: () =>
              ref.read(noticesControllerProvider.notifier).loadMore(),
        ),
    ];
    return RefreshIndicator(
      onRefresh: () => _refresh(context, ref),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(OrbitSpace.s16),
        itemCount: children.length,
        itemBuilder: (_, i) => children[i],
        separatorBuilder: (_, _) => const SizedBox(height: OrbitSpace.s12),
      ),
    );
  }
}
