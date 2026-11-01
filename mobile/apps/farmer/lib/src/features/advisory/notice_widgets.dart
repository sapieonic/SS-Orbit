import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';
import 'package:orbit_voice/orbit_voice.dart';

import '../../data/data.dart';
import '../../shared/voice.dart';
import 'advisory_providers.dart';

/// When a notice was sent, as the inbox says it: "10 min ago", "2 h ago",
/// "Yesterday", "4 days ago", then the date ("12 అక్టో"). Days are IST.
String noticeTime(OrbitLocalizations l10n, DateTime sentAt, DateTime now) {
  final age = now.difference(sentAt);
  final days = LocalDate.istOf(sentAt).daysUntil(LocalDate.istOf(now));
  if (days <= 0) {
    if (age.inMinutes < Duration.minutesPerHour) {
      return l10n.commonMinutesAgo(
        count: age.inMinutes < 1 ? 1 : age.inMinutes,
      );
    }
    return l10n.commonHoursAgo(count: age.inHours);
  }
  if (days == 1) return l10n.commonYesterday;
  if (days < DateTime.daysPerWeek) return l10n.commonDaysAgo(count: days);
  return l10n.commonDateShort(date: toIstWallClock(sentAt));
}

/// The source tag text for [sender] ("షణ్ముఖ", "CIV", "మీ FA").
String noticeSource(OrbitLocalizations l10n, NoticeSender sender) =>
    l10n.labelNoticeSender(sender.wire);

/// Listen button for a notice's voice note (FAR-03): downloads and plays it,
/// stops on a second tap, and shows "Couldn't play the audio" when the
/// download or playback fails (tap again to retry). Playing it to the end
/// marks the notice listened.
class NoticeAudioButton extends ConsumerWidget {
  /// Creates the button for [notice].
  const NoticeAudioButton({super.key, required this.notice});

  /// The notice; its ID is the audio cache key.
  final Notice notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final player = ref.watch(voicePlayerProvider);
    final audio = ref.watch(noticeAudioProvider);
    if (NoticeAudio.audioUri(notice) == null) {
      return ListenButton(
        label: l10n.commonAudioUnavailable,
        state: ListenState.unavailable,
        onPressed: null,
      );
    }
    return ValueListenableBuilder<VoicePlayerState>(
      valueListenable: player.state,
      builder: (context, state, _) {
        final listen = listenStateFor(state, notice.id);
        final label = switch (listen) {
          ListenState.loading => l10n.commonAudioLoading,
          ListenState.playing => l10n.commonStop,
          ListenState.unavailable when state is VoiceError =>
            l10n.commonAudioError,
          ListenState.unavailable => l10n.commonAudioUnavailable,
          ListenState.idle => l10n.commonListen,
        };
        return ListenButton(
          label: label,
          state: listen,
          onPressed: () => switch (listen) {
            ListenState.playing || ListenState.loading => audio.stop(),
            _ => audio.play(notice),
          },
        );
      },
    );
  }
}
