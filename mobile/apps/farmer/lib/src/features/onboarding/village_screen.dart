import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../shared/async_view.dart';
import '../../shared/voice.dart';
import 'onboarding_providers.dart';
import 'widgets/place_tile.dart';
import 'widgets/village_browser.dart';

/// How long typing must pause before the village search runs.
const villageSearchDebounce = Duration(milliseconds: 300);

/// Longest search the API accepts (`q`, 1-100 characters).
const _maxQueryLength = 100;

/// Village picker (self sign-up, after consent): search by Telugu or English
/// name, or browse district > mandal > village. Tapping a village keeps it
/// in the session and the router moves on to the name step.
class VillageScreen extends ConsumerStatefulWidget {
  const VillageScreen({super.key});

  @override
  ConsumerState<VillageScreen> createState() => _VillageScreenState();
}

class _VillageScreenState extends ConsumerState<VillageScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  bool _browsing = false;
  TreeDistrict? _district;
  TreeMandal? _mandal;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(villageSearchDebounce, () {
      if (mounted) setState(() => _query = text.trim());
    });
    // Rebuild now for the clear button.
    setState(() {});
  }

  void _clearQuery() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _query = '');
  }

  void _pick(Village village) {
    FocusScope.of(context).unfocus();
    ref.read(sessionProvider.notifier).pickVillage(village);
  }

  void _startBrowsing() {
    FocusScope.of(context).unfocus();
    setState(() => _browsing = true);
  }

  /// One browse step back; from the first step, back to search.
  void _browseBack() => setState(() {
    if (_mandal != null) {
      _mandal = null;
    } else if (_district != null) {
      _district = null;
    } else {
      _browsing = false;
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    const listen = ScreenListenButton(
      voiceKey: VoiceKeys.farmerVillageVoiceHelp,
    );

    final ScreenHeader header;
    final Widget body;
    if (_browsing) {
      final district = _district;
      final mandal = _mandal;
      header = ScreenHeader(
        title: mandal != null
            ? l10n.farmerVillageChooseVillage
            : district != null
            ? l10n.farmerVillageChooseMandal
            : l10n.farmerVillageChooseDistrict,
        subtitle:
            [
              if (district != null)
                pickText(language, te: district.nameTe, en: district.name),
              if (mandal != null)
                pickText(language, te: mandal.nameTe, en: mandal.name),
            ].fold<String?>(
              null,
              (a, b) => a == null ? b : l10n.commonDotJoin(first: a, second: b),
            ),
        onBack: _browseBack,
        listen: listen,
      );
      body = VillageBrowser(
        district: district,
        mandal: mandal,
        onDistrict: (d) => setState(() => _district = d),
        onMandal: (m) => setState(() => _mandal = m),
        onVillage: _pick,
      );
    } else {
      header = ScreenHeader(
        title: l10n.farmerVillageTitle,
        subtitle: l10n.farmerVillageSubtitle,
        listen: listen,
      );
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OrbitSpace.s16,
              OrbitSpace.s8,
              OrbitSpace.s16,
              0,
            ),
            child: _SearchField(
              controller: _search,
              onChanged: _onQueryChanged,
              onClear: _clearQuery,
            ),
          ),
          Expanded(
            child: _SearchResults(
              query: _query,
              language: language,
              onPick: _pick,
              onBrowse: _startBrowsing,
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: !_browsing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _browsing) _browseBack();
      },
      child: Scaffold(
        body: Column(
          children: [
            header,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      inputFormatters: [LengthLimitingTextInputFormatter(_maxQueryLength)],
      style: Theme.of(context).textTheme.titleMedium,
      decoration: InputDecoration(
        hintText: l10n.farmerVillageSearchHint,
        prefixIcon: const Icon(OrbitIcons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.commonClose,
                icon: const Icon(OrbitIcons.close),
                onPressed: onClear,
              ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.language,
    required this.onPick,
    required this.onBrowse,
  });

  final String query;
  final Language language;
  final ValueChanged<Village> onPick;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final browse = OrbitButton(
      label: l10n.farmerVillageBrowse,
      icon: OrbitIcons.location,
      variant: OrbitButtonVariant.secondary,
      onPressed: onBrowse,
    );
    const padding = EdgeInsets.all(OrbitSpace.s16);

    if (query.isEmpty) {
      return ListView(padding: padding, children: [browse]);
    }
    final provider = villageSearchProvider(query);
    return AsyncValueView(
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      data: (villages) => villages.isEmpty
          ? ListView(
              padding: padding,
              children: [
                StateCard(
                  icon: OrbitIcons.search,
                  title: l10n.farmerVillageNoResults(query: query),
                  action: browse,
                ),
              ],
            )
          : ListView.separated(
              padding: padding,
              itemCount: villages.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: OrbitSpace.s8),
              itemBuilder: (_, i) => i == villages.length
                  ? Padding(
                      padding: const EdgeInsets.only(top: OrbitSpace.s8),
                      child: browse,
                    )
                  : VillageTile(
                      village: villages[i],
                      language: language,
                      onTap: onPick,
                    ),
            ),
    );
  }
}
