import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../routing/routes.dart';
import '../../shared/farmer_text.dart';
import '../../shared/launch.dart';
import '../../shared/voice.dart';

/// The farmer's FA on Home (FAR-07): the card opens Look for FAs, the big
/// green button opens the dialer.
class HomeFaSection extends ConsumerWidget {
  /// Creates the section for [fa].
  const HomeFaSection({super.key, required this.fa});

  /// The assigned FA.
  final FarmerFaCard fa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = fa.displayName(contentLanguage(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FaCard(
          name: l10n.farmerHomeYourFa(name: name),
          initials: nameInitials(fa.name),
          verified: true,
          subtitle: l10n.farmerHomeFaVerified,
          highlighted: true,
          onTap: () => context.go(Routes.fas),
        ),
        const SizedBox(height: OrbitSpace.s8),
        OrbitButton(
          label: l10n.commonCallName(name: name),
          variant: OrbitButtonVariant.call,
          size: OrbitButtonSize.hero,
          onPressed: () => callPhone(context, ref, fa.phone),
        ),
        const SizedBox(height: OrbitSpace.s8),
        OrbitButton(
          label: l10n.farmerHomeLookForFas,
          icon: OrbitIcons.people,
          variant: OrbitButtonVariant.secondary,
          size: OrbitButtonSize.medium,
          onPressed: () => context.go(Routes.fas),
        ),
      ],
    );
  }
}

/// No FA assigned yet: "Your FA will call you within 2 days" with the
/// helpline.
class HomeNoFaCard extends ConsumerWidget {
  /// Creates the card.
  const HomeNoFaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return StateCard(
      icon: OrbitIcons.people,
      tone: StateCardTone.info,
      title: l10n.farmerStateNoFaTitle,
      action: OrbitButton(
        label: l10n.farmerStateNoFaAction,
        variant: OrbitButtonVariant.call,
        icon: OrbitIcons.helpline,
        onPressed: () => callHelpline(context, ref),
      ),
      listen: const ScreenListenButton(
        voiceKey: VoiceKeys.farmerStateNoFaVoice,
      ),
    );
  }
}

/// "రేపు · గురు, 29 అక్టో" / "Next FA visit · Morning"; opens My visits.
class HomeNextVisitCard extends ConsumerWidget {
  /// Creates the card for [visit].
  const HomeNextVisitCard({super.key, required this.visit});

  /// The next planned visit.
  final PlannedVisit visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = LocalDate.todayIst(ref.watch(clockProvider));
    final day = visit.plannedFor;
    final relative = day == today
        ? l10n.commonToday
        : day == today.addDays(1)
        ? l10n.commonTomorrow
        : null;
    final slot = visit.plannedSlot;
    return _TapCard(
      onTap: () => context.go(Routes.visits),
      child: InfoRow(
        icon: OrbitIcons.visit,
        text: dotJoin(l10n, [
          relative,
          l10n.commonDateWeekday(date: day.toDateTime()),
        ]),
        secondaryText: dotJoin(l10n, [
          l10n.farmerHomeNextVisit,
          if (slot != PlannedSlot.unknown) l10n.labelPlannedSlot(slot.wire),
        ]),
        trailing: const _Chevron(),
      ),
    );
  }
}

/// "2 కొత్త సలహాలు"; opens the advisory inbox.
class HomeUnreadAdviceCard extends StatelessWidget {
  /// Creates the card for [count] unread notices.
  const HomeUnreadAdviceCard({super.key, required this.count});

  /// Unread advisories.
  final int count;

  @override
  Widget build(BuildContext context) => _TapCard(
    onTap: () => context.go(Routes.advisory),
    child: InfoRow(
      icon: OrbitIcons.notice,
      text: context.l10n.farmerHomeUnread(count: count),
      trailing: const _Chevron(),
    ),
  );
}

/// No plot yet: one card pointing to My farm.
class HomeNoPlotCard extends StatelessWidget {
  /// Creates the card.
  const HomeNoPlotCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StateCard(
      icon: OrbitIcons.crop,
      title: l10n.farmerHomeNoPlotTitle,
      subtitle: l10n.farmerHomeNoPlotBody,
      action: OrbitButton(
        label: l10n.farmerNavFarm,
        icon: OrbitIcons.crop,
        variant: OrbitButtonVariant.secondary,
        onPressed: () => context.go(Routes.farm),
      ),
    );
  }
}

class _TapCard extends StatelessWidget {
  const _TapCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Read out as a button, like the cards it sits between.
    return Semantics(
      button: true,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: OrbitSize.controlXl),
            child: Padding(
              padding: const EdgeInsets.all(OrbitSpace.s12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => Icon(
    OrbitIcons.chevronRight,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
