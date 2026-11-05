import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../shared/formatters.dart';
import 'sync_view.dart';

/// The banner at the top of Sync: one tone, one icon, a title and a line.
class SyncStatusBanner extends StatelessWidget {
  /// Creates the banner.
  const SyncStatusBanner({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.text,
  });

  /// Colours.
  final OrbitTone tone;

  /// The square icon.
  final IconData icon;

  /// "All synced".
  final String title;

  /// "HO has everything as of 10:58 AM".
  final String? text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.tint,
          borderRadius: const BorderRadius.all(Radius.circular(OrbitSpace.s16)),
          border: Border.all(color: tone.fg, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(OrbitSpace.s12),
          child: Row(
            children: [
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tone.fg,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(OrbitRadius.md),
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 36,
                    child: Icon(
                      icon,
                      size: OrbitSize.iconMd,
                      color: scheme.surface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: OrbitSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge!.copyWith(
                        color: tone.strong,
                        fontWeight: OrbitFont.weightBold,
                      ),
                    ),
                    if (text case final text?)
                      Text(
                        text,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: tone.strong,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "3.1 MB" / "420 KB" for [bytes].
String formatBytes(OrbitLocalizations l10n, int bytes) {
  if (bytes >= 1000 * 1000) {
    final mb = NumberFormat('0.0', l10n.localeName).format(bytes / 1e6);
    return l10n.faSyncSizeMb(size: mb);
  }
  final kb = NumberFormat(
    '0',
    l10n.localeName,
  ).format((bytes / 1000).ceil().clamp(1, 999));
  return l10n.faSyncSizeKb(size: kb);
}

/// The record type's name ("Visit log").
String recordTypeLabel(OrbitLocalizations l10n, CommandType type) =>
    switch (type) {
      CommandType.enrolFarmer => l10n.faSyncTypeEnrol,
      CommandType.recordConsent => l10n.faSyncTypeConsent,
      CommandType.savePlot => l10n.faSyncTypePlot,
      CommandType.startSeason => l10n.faSyncTypeSeason,
      CommandType.updateFarmer => l10n.faSyncTypeFarmer,
      CommandType.planVisit => l10n.faSyncTypePlan,
      CommandType.logVisit => l10n.faSyncTypeVisit,
      CommandType.cancelVisit => l10n.faSyncTypeCancel,
      CommandType.closeCallback => l10n.faSyncTypeCallback,
      CommandType.ackAlert => l10n.faSyncTypeAlert,
    };

/// The record type's icon.
IconData recordTypeIcon(CommandType type) => switch (type) {
  CommandType.enrolFarmer => OrbitIcons.enrol,
  CommandType.recordConsent => OrbitIcons.consent,
  CommandType.savePlot => OrbitIcons.map,
  CommandType.startSeason => OrbitIcons.crop,
  CommandType.updateFarmer => OrbitIcons.person,
  CommandType.planVisit || CommandType.cancelVisit => OrbitIcons.calendar,
  CommandType.logVisit => OrbitIcons.visit,
  CommandType.closeCallback => OrbitIcons.phoneCall,
  CommandType.ackAlert => OrbitIcons.bell,
};

/// "Visit log · Ravi K" (the type alone when the name is not known).
String recordTitle(OrbitLocalizations l10n, SyncRecord r) =>
    dotJoin(l10n, [recordTypeLabel(l10n, r.entry.type), r.name]);

/// "Saved 11:05 AM · 3 photos · 3.1 MB" (with the day when not today).
String recordMeta(OrbitLocalizations l10n, SyncRecord r, DateTime now) {
  final at = r.entry.clientCreatedAt;
  final day = LocalDate.istOf(at);
  final photos = r.photos;
  return dotJoin(l10n, [
    if (day != LocalDate.istOf(now)) formatDateShort(l10n, day),
    l10n.commonSavedAt(time: toIstWallClock(at)),
    if (photos != null && photos.count > 0) ...[
      l10n.faSyncPhotosCount(count: photos.count),
      formatBytes(l10n, photos.bytes),
    ],
  ]);
}

/// The pill for [progress].
StatusPill progressPill(OrbitLocalizations l10n, RecordProgress progress) =>
    switch (progress) {
      RecordProgress.waiting => StatusPill(
        label: l10n.faSyncPillWaiting,
        tone: OrbitStatusTone.warning,
        icon: OrbitIcons.pending,
      ),
      RecordProgress.uploading => StatusPill(
        label: l10n.faSyncPillUploading,
        tone: OrbitStatusTone.info,
        icon: OrbitIcons.upload,
      ),
      RecordProgress.synced => StatusPill(
        label: l10n.faSyncPillSynced,
        tone: OrbitStatusTone.success,
        icon: OrbitIcons.success,
      ),
    };

/// [value] of conflict [field] as the FA reads it: an area as acres and
/// guntas, a village by name, a boundary as walked or not.
String conflictValue(
  OrbitLocalizations l10n,
  Territory territory,
  Language language,
  String field,
  Object? value,
) {
  if (value == null) {
    return field == 'photo_key'
        ? l10n.faSyncValueNoPhoto
        : l10n.faSyncValueEmpty;
  }
  switch (field) {
    case 'area_acres' when value is num:
      return formatArea(l10n, value.toDouble());
    case 'boundary' when value is bool:
      return value
          ? l10n.faSyncValueBoundaryWalked
          : l10n.faSyncValueNoBoundary;
    case 'version' when value is num:
      return l10n.faSyncValueVersion(version: value.toInt());
    case 'photo_key':
      return value is String && value.isNotEmpty
          ? l10n.faSyncValuePhoto
          : l10n.faSyncValueNoPhoto;
    case 'language':
      return switch (Language.fromWire('$value')) {
        Language.en => l10n.enumLanguageEn,
        _ => l10n.enumLanguageTe,
      };
    case 'village_id':
      return territory.village('$value')?.displayName(language) ?? '$value';
  }
  if (value is String) {
    return value.trim().isEmpty ? l10n.faSyncValueEmpty : value;
  }
  if (value is num) {
    return NumberFormat.decimalPattern(l10n.localeName).format(value);
  }
  return '$value';
}

/// The round-cornered row frame every Sync row uses.
class SyncRowFrame extends StatelessWidget {
  /// Creates the frame.
  const SyncRowFrame({super.key, required this.child, this.edge});

  /// The content.
  final Widget child;

  /// Border colour (the outline colour when null).
  final Color? edge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(OrbitSpace.s16)),
        side: BorderSide(color: edge ?? scheme.outlineVariant, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s12),
        child: child,
      ),
    );
  }
}

/// The icon square, title, sub-line and pill at the top of a row.
class SyncRowTop extends StatelessWidget {
  /// Creates the row top.
  const SyncRowTop({
    super.key,
    required this.icon,
    required this.title,
    this.meta,
    this.pill,
    this.iconTone,
  });

  /// The record type's icon.
  final IconData icon;

  /// "Visit log · Ravi K".
  final String title;

  /// "Saved 11:42 AM · 3 photos · 3.1 MB".
  final String? meta;

  /// Waiting / Uploading / Synced / Not saved.
  final Widget? pill;

  /// Tints the icon square (danger for refused rows).
  final OrbitTone? iconTone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: iconTone?.tint ?? scheme.primaryContainer,
              borderRadius: const BorderRadius.all(
                Radius.circular(OrbitRadius.md),
              ),
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Icon(
                icon,
                size: OrbitSize.iconMd,
                color: iconTone?.fg ?? scheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: OrbitSpace.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: OrbitFont.weightBold,
                ),
              ),
              if (meta case final meta?)
                Text(
                  meta,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: orbit.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (pill case final pill?) ...[
          const SizedBox(width: OrbitSpace.s8),
          pill,
        ],
      ],
    );
  }
}
