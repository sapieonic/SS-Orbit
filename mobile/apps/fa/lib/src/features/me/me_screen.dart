import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../routing/router.dart' show devMenuEnabled;
import '../../routing/routes.dart';
import '../../shared/async_view.dart';
import '../../shared/fa_header.dart';
import '../../shared/formatters.dart';
import '../../shared/helpline.dart';
import '../../shared/navigation.dart';
import '../auth/auth_support.dart';
import '../auth/auth_widgets.dart';
import 'change_password_page.dart';
import 'change_pin_page.dart';
import 'me_stats.dart';

/// A11 Me: profile and settings.
///
/// The profile from the session's FA, this month's counts from the
/// territory, the app language, photos on Wi-Fi only (the engine's local
/// setting), Sync, Change PIN and Change password (pages pushed over Me),
/// Call HO, the dev menu in dev builds, and Log out, which warns first when
/// records are not synced yet (they stay on the phone).
class MeScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  /// Unsynced records found when Log out was tapped (shows the warning).
  int? _unsynced;
  bool _loggingOut = false;

  Future<void> _setLanguage(Language language) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionProvider.notifier).setLanguage(language);
    } on Object catch (e) {
      if (!mounted) return;
      final l10n = lookupOrbitLocalizations(Locale(language.wire));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorTextIn(l10n, e))));
    }
  }

  Future<void> _setWifiOnly(bool value) async {
    try {
      await ref.read(faActionsProvider).setPhotosOnWifiOnly(value);
    } on Object catch (e) {
      if (mounted) showActionError(context, e);
    }
  }

  Future<void> _askLogout() async {
    final session = ref.read(sessionProvider.notifier);
    setState(() => _loggingOut = true);
    final int unsynced;
    try {
      unsynced = await session.unsyncedCount();
    } on Object catch (e) {
      // Not counted: never log out as if nothing were waiting.
      if (!mounted) return;
      setState(() => _loggingOut = false);
      showActionError(context, e);
      return;
    }
    if (!mounted) return;
    setState(() => _loggingOut = false);
    if (unsynced > 0) {
      setState(() => _unsynced = unsynced);
      return;
    }
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.faMeLogoutTitle),
        content: Text(l10n.faMeLogoutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.faCommonLogOut),
          ),
        ],
      ),
    );
    if (yes ?? false) await _logout();
  }

  /// Logs out; unsynced records stay on the phone ("they go up when you log
  /// in again").
  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await ref.read(sessionProvider.notifier).logout();
    if (mounted) setState(() => _loggingOut = false);
  }

  void _syncFirst() {
    setState(() => _unsynced = null);
    openPage(context, AppRoutes.sync);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider);
    final showDev = devMenuEnabled(ref.watch(orbitEnvProvider));
    final unsynced = _unsynced;
    return Scaffold(
      body: Column(
        children: [
          FaHeader(
            title: l10n.faShellTitleMe,
            subtitle: l10n.faMeSubtitle,
            back: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                const _ProfileCard(),
                const SizedBox(height: OrbitSpace.s12),
                const _MonthCounts(),
                const SizedBox(height: OrbitSpace.s12),
                if (session.syncNeedsPassword) ...[
                  NoteCard(
                    tone: NoteTone.warning,
                    icon: OrbitIcons.sync,
                    title: l10n.faMeNeedsPasswordTitle,
                    text: l10n.faMeNeedsPasswordBody,
                    actions: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OrbitButton(
                        label: l10n.faMeLogInNow,
                        size: OrbitButtonSize.medium,
                        fullWidth: false,
                        onPressed: () =>
                            ref.read(sessionProvider.notifier).lock(),
                      ),
                    ),
                  ),
                  const SizedBox(height: OrbitSpace.s12),
                ],
                _Group(
                  children: [
                    _LanguageRow(
                      language: session.language,
                      onChanged: _setLanguage,
                    ),
                    _WifiRow(onChanged: _setWifiOnly),
                    const _SyncRow(),
                  ],
                ),
                const SizedBox(height: OrbitSpace.s12),
                _Group(
                  children: [
                    _Row(
                      title: l10n.faMeChangePin,
                      subtitle: _graceLine(l10n, session),
                      onTap: () => ChangePinPage.open(context),
                    ),
                    _Row(
                      title: l10n.faMeChangePassword,
                      subtitle: l10n.faNewPasswordNeedsNetwork,
                      onTap: () => ChangePasswordPage.open(context),
                    ),
                    _Row(
                      title: l10n.faMeCallHo,
                      subtitle: l10n.faMeCallHoSub(
                        phone: formatHelpline(ref.watch(hoHelplineProvider)),
                      ),
                      trailing: OrbitIcons.phone,
                      onTap: () => callHo(context, ref),
                    ),
                    if (showDev)
                      _Row(
                        title: l10n.faShellTitleDev,
                        trailing: OrbitIcons.settings,
                        onTap: () => openPage(context, AppRoutes.dev),
                      ),
                  ],
                ),
                const SizedBox(height: OrbitSpace.s12),
                if (unsynced != null)
                  NoteCard(
                    tone: NoteTone.danger,
                    title: l10n.faMeLogoutUnsynced(count: unsynced),
                    text: l10n.faMeLogoutUnsyncedBody,
                    actions: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: OrbitButton(
                            label: l10n.faMeSyncNow,
                            size: OrbitButtonSize.medium,
                            onPressed: _loggingOut ? null : _syncFirst,
                          ),
                        ),
                        const SizedBox(width: OrbitSpace.s8),
                        Expanded(
                          child: OrbitButton(
                            label: l10n.faMeLogoutAnyway,
                            size: OrbitButtonSize.medium,
                            variant: OrbitButtonVariant.danger,
                            loading: _loggingOut,
                            onPressed: _loggingOut ? null : _logout,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  OrbitButton(
                    label: l10n.faCommonLogOut,
                    icon: OrbitIcons.logOut,
                    variant: OrbitButtonVariant.danger,
                    loading: _loggingOut,
                    onPressed: _loggingOut ? null : _askLogout,
                  ),
                const SizedBox(height: OrbitSpace.s12),
                const _Footer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Works offline 7 days · 6 days left".
  String? _graceLine(OrbitLocalizations l10n, SessionState session) {
    final ends = session.graceEndsAt;
    if (ends == null) return null;
    final now = ref.watch(clockProvider).now();
    final hours = ends.difference(now).inHours;
    final left = hours <= 0 ? 0 : (hours / 24).ceil();
    return l10n.faMeChangePinSub(
      days: session.policy.offlineGraceDays,
      left: left,
    );
  }
}

/// Avatar, name, login ID, phone and area.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final fa = ref.watch(sessionProvider.select((s) => s.fa));
    final language = contentLanguage(context);
    final area = areaLabel(ref.watch(territoryProvider).value, language);
    final initials = nameInitials(fa?.name);
    final muted = theme.textTheme.bodyMedium!.copyWith(
      fontSize: 14,
      color: orbit.textMuted,
    );
    return Semantics(
      container: true,
      label: l10n.faMeProfile,
      child: _Card(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: OrbitSize.avatarLg,
                height: OrbitSize.avatarLg,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: initials == null
                    ? Icon(OrbitIcons.person, color: scheme.onPrimary)
                    : Text(
                        initials,
                        textScaler: TextScaler.noScaling,
                        style: theme.textTheme.titleLarge!.copyWith(
                          color: scheme.onPrimary,
                          fontSize: 20,
                          fontWeight: OrbitFont.weightExtrabold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: OrbitSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fa != null) ...[
                    Text(
                      fa.displayName(language),
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: OrbitFont.weightBold,
                      ),
                    ),
                    Text(
                      dotJoin(l10n, [fa.code, formatIndianMobile(fa.phone)]),
                      style: muted,
                    ),
                  ],
                  if (area != null)
                    Text(l10n.faMeArea(area: area), style: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Farmers, visits and enrolments this month.
class _MonthCounts extends ConsumerWidget {
  const _MonthCounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(meStatsProvider);
    if (stats == null) return const SizedBox.shrink();
    final today = LocalDate.todayIst(ref.watch(clockProvider));
    final month = DateFormat.MMM(l10n.localeName).format(today.toDateTime());
    final items = [
      (stats.farmers, l10n.faMeStatFarmers(count: stats.farmers)),
      (stats.visits, l10n.faMeStatVisits(month: month)),
      (stats.enrolled, l10n.faMeStatEnrolled(month: month)),
    ];
    return Semantics(
      container: true,
      label: l10n.faMeThisMonth,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: OrbitSpace.s8),
              Expanded(
                child: _Count(value: items[i].$1, label: items[i].$2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: _Card(
        radius: OrbitRadius.lg,
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(
              '$value',
              style: theme.textTheme.titleLarge!.copyWith(
                fontWeight: OrbitFont.weightExtrabold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall!.copyWith(
                fontSize: 12.5,
                color: OrbitColors.of(context).textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App language: title and the Telugu / English switch under it.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.language, required this.onChanged});

  final Language language;
  final ValueChanged<Language> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RowText(title: l10n.faMeLanguage, subtitle: l10n.faMeLanguageSub),
          const SizedBox(height: OrbitSpace.s8),
          SegmentedTabs(
            labels: [
              l10n.labelLanguage(Language.te.wire),
              l10n.labelLanguage(Language.en.wire),
            ],
            selectedIndex: language == Language.en ? 1 : 0,
            onChanged: (i) => onChanged(i == 1 ? Language.en : Language.te),
          ),
        ],
      ),
    );
  }
}

/// "Upload photos on Wi-Fi only" (the engine's local setting).
class _WifiRow extends ConsumerWidget {
  const _WifiRow({required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(syncStateProvider.select((s) => s.photosOnWifiOnly));
    return SwitchRow(
      title: l10n.faMeWifi,
      subtitle: on ? l10n.faMeWifiOn : l10n.faMeWifiOff,
      value: on,
      onChanged: onChanged,
    );
  }
}

/// Sync: last sync and records waiting; opens Sync.
class _SyncRow extends ConsumerWidget {
  const _SyncRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lastPull = ref.watch(syncStateProvider.select((s) => s.lastPullAt));
    final queued = ref.watch(syncStateProvider.select((s) => s.queuedCount));
    final clock = ref.watch(clockProvider);
    final subtitle = dotJoin(l10n, [
      if (lastPull == null)
        l10n.faMeSyncNever
      else
        l10n.faMeSyncLast(
          day: formatDaysAgo(
            l10n,
            LocalDate.istOf(lastPull),
            today: LocalDate.todayIst(clock),
          ),
          time: formatTime(l10n, lastPull),
        ),
      if (queued > 0) l10n.faMeSyncWaiting(count: queued),
    ]);
    return _Row(
      title: l10n.faShellTitleSync,
      subtitle: subtitle,
      onTap: () => openPage(context, AppRoutes.sync),
    );
  }
}

/// A tappable settings row: title, sub-line and a chevron (or [trailing]).
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing = OrbitIcons.chevronRight,
  });

  final String title;
  final String? subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _RowText(title: title, subtitle: subtitle),
                ),
                const SizedBox(width: OrbitSpace.s8),
                Icon(
                  trailing,
                  size: OrbitSize.iconMd,
                  color: OrbitColors.of(context).textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall!.copyWith(
            fontWeight: OrbitFont.weightBold,
          ),
        ),
        if (subtitle case final subtitle?)
          Text(
            subtitle,
            style: theme.textTheme.bodySmall!.copyWith(
              fontSize: 13.5,
              color: OrbitColors.of(context).textMuted,
            ),
          ),
      ],
    );
  }
}

/// Rows in one card, split by thin lines.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return _Card(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) divider,
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A white card with the Orbit border.
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = OrbitSpace.s16,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: scheme.outlineVariant, width: 1.5),
    );
    return Material(
      color: scheme.surface,
      shape: shape,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// "Version 0.1.0 · phone ID 7F3A".
class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(phoneIdProvider).value;
    final version = ref.watch(appVersionProvider);
    return Text(
      id == null
          ? context.l10n.faLoginFooterVersion(version: version)
          : context.l10n.faMeFooter(version: version, id: id),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall!
          .copyWith(fontSize: 13, color: OrbitColors.of(context).textMuted),
    );
  }
}
