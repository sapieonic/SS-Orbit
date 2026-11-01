import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/farmer_data.dart';
import '../../shared/farmer_text.dart';
import '../../shared/launch.dart';
import '../../shared/voice.dart';
import 'callback_panel.dart';
import 'fas_providers.dart';

/// F3 Look for FAs: the Field Assistants covering the farmer's village,
/// mandal and district, each one tap from a call or a WhatsApp chat, and
/// "Ask your FA to call you back" at the bottom.
class FasScreen extends ConsumerStatefulWidget {
  const FasScreen({super.key});

  @override
  ConsumerState<FasScreen> createState() => _FasScreenState();
}

class _FasScreenState extends ConsumerState<FasScreen> {
  AreaLevel _level = fasLevels.first;

  Future<void> _refresh() async {
    ref.invalidate(openCallbackProvider);
    try {
      ref.invalidate(fasProvider(_level));
      await ref.read(fasProvider(_level).future);
    } on Object catch (error) {
      // The FAs already on screen stay; say why they didn't refresh.
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fas = ref.watch(fasProvider(_level)).fresh;
    // Home knows whether an FA is assigned; until it loads, assume one is
    // and let the server answer the call-back request.
    final home = ref.watch(farmerHomeProvider).fresh.value;
    final noFa = home != null && home.fa == null;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: l10n.farmerFasTitle,
            onBack: _back,
            listen: const ScreenListenButton(
              voiceKey: VoiceKeys.farmerFasVoiceHelp,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OrbitSpace.s16,
              0,
              OrbitSpace.s16,
              OrbitSpace.s12,
            ),
            child: SegmentedTabs(
              labels: [
                for (final level in fasLevels)
                  l10n.labelCoverageLevel(level.wire),
              ],
              selectedIndex: fasLevels.indexOf(_level),
              onChanged: (i) => setState(() => _level = fasLevels[i]),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: fas,
              onRetry: () => ref.invalidate(fasProvider(_level)),
              data: (options) => RefreshIndicator(
                onRefresh: _refresh,
                child: _FaList(options: options, noFa: noFa),
              ),
            ),
          ),
          if (fas.hasValue && !noFa)
            CallbackPanel(myFa: home?.fa, options: fas.value ?? const []),
        ],
      ),
    );
  }
}

/// The count line and one card per FA, or the no-FA card.
class _FaList extends ConsumerWidget {
  const _FaList({required this.options, required this.noFa});

  final List<FaOption> options;
  final bool noFa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        OrbitSpace.s16,
        0,
        OrbitSpace.s16,
        OrbitSpace.s16,
      ),
      children: [
        if (noFa && options.isEmpty)
          StateCard(
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
          )
        else if (options.isEmpty)
          // No FA covers the whole mandal or district (yet): say so, rather
          // than a bare count over an empty list.
          StateCard(
            icon: OrbitIcons.people,
            tone: StateCardTone.info,
            title: l10n.farmerFasCount(count: 0),
          )
        else ...[
          Text(
            l10n.farmerFasCount(count: options.length),
            style: theme.textTheme.titleSmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: OrbitSpace.s4),
          InfoRow(icon: OrbitIcons.phoneCall, text: l10n.farmerFasCallHint),
          for (final option in options) ...[
            const SizedBox(height: OrbitSpace.s12),
            _FaOptionCard(option: option),
          ],
        ],
      ],
    );
  }
}

class _FaOptionCard extends ConsumerWidget {
  const _FaOptionCard({required this.option});

  final FaOption option;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = contentLanguage(context);
    final fa = option.fa;
    final greeting = _whatsAppGreeting(
      l10n,
      language,
      ref.watch(farmerHomeProvider).fresh.value,
    );
    return FaCard(
      name: fa.displayName(language),
      initials: nameInitials(fa.name),
      tag: option.isMyFa ? l10n.farmerFasYourFa : null,
      highlighted: option.isMyFa,
      verified: true,
      subtitle: l10n.farmerHomeFaVerified,
      detail: _detail(l10n, option),
      callLabel: l10n.commonCall,
      onCall: () => callPhone(context, ref, fa.phone),
      whatsAppLabel: l10n.commonWhatsapp,
      onWhatsApp: () => openWhatsApp(context, ref, fa.phone, text: greeting),
    );
  }
}

/// Under the name, one line each: "Lead FA · Village", the languages the FA
/// speaks, their working hours. Lines the FA has no data for are left out.
String _detail(OrbitLocalizations l10n, FaOption option) {
  final fa = option.fa;
  final languages = [
    for (final code in fa.languages) ?l10n.enumLabel('language', code),
  ];
  final hours = fa.workingHours?.trim() ?? '';
  return [
    dotJoin(l10n, [
      if (option.isLead) l10n.farmerFasLead,
      l10n.labelCoverageLevel(option.coverageLevel.wire),
    ]),
    if (languages.isNotEmpty)
      l10n.farmerFasLanguages(languages: languages.join(', ')),
    if (hours.isNotEmpty) l10n.farmerFasWorkingHours(hours: hours),
  ].join('\n');
}

/// "నమస్కారం, నేను రవి, కొండాపూర్ రైతును.", typed into the WhatsApp chat so
/// the FA knows who is writing. Null while Home (name, village) is unknown.
String? _whatsAppGreeting(
  OrbitLocalizations l10n,
  Language language,
  FarmerHome? home,
) {
  final village = home?.village;
  if (home == null || village == null) return null;
  final name = home.farmer.displayName(language);
  if (name.isEmpty) return null;
  return l10n.farmerFasWhatsappMessage(
    name: name,
    village: pickText(language, te: village.nameTe, en: village.name),
  );
}
