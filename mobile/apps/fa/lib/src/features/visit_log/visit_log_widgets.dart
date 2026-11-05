// The visit log's building blocks: the photo strip and photo sheet, the
// big picker buttons, the severity buttons, the issue and salt sheets, an
// added issue's row and the saved summary's rows. They take plain values;
// the screen holds the state.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../shared/formatters.dart';
import '../calendar/visit_ui.dart';

/// Size of a photo thumbnail in the strip.
const double _thumb = 64;

/// The camera button and up to three thumbnails; the third shows "+N" when
/// there are more. Tapping a thumbnail opens all photos.
class PhotoStrip extends StatelessWidget {
  /// Creates the strip.
  const PhotoStrip({
    super.key,
    required this.photos,
    required this.onTake,
    required this.onOpen,
    this.taking = false,
  });

  /// The photos' bytes, in order.
  final List<Uint8List> photos;

  /// Opens the camera; null when no more photos fit.
  final VoidCallback? onTake;

  /// Opens the photo sheet.
  final VoidCallback onOpen;

  /// The camera is open.
  final bool taking;

  /// Thumbnails shown in the strip.
  static const shown = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(OrbitRadius.lg));
    final more = photos.length - shown;
    return Row(
      children: [
        Semantics(
          button: true,
          enabled: onTake != null,
          label: l10n.faVisitLogTakePhoto,
          excludeSemantics: true,
          child: Material(
            color: onTake == null
                ? scheme.surfaceContainerHighest
                : scheme.primary,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: taking ? null : onTake,
              child: SizedBox.square(
                dimension: _thumb,
                child: taking
                    ? Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: scheme.onPrimary,
                          ),
                        ),
                      )
                    : Icon(
                        OrbitIcons.camera,
                        color: onTake == null
                            ? scheme.onSurfaceVariant
                            : scheme.onPrimary,
                      ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < photos.length && i < shown; i++) ...[
          const SizedBox(width: OrbitSpace.s8),
          Semantics(
            button: true,
            label: i == shown - 1 && more > 0
                ? l10n.faVisitLogMorePhotos(count: more)
                : l10n.faVisitLogPhoto(number: i + 1),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: radius,
              onTap: onOpen,
              child: ClipRRect(
                borderRadius: radius,
                child: SizedBox.square(
                  dimension: _thumb,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        photos[i],
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                      if (i == shown - 1 && more > 0)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: Center(
                            child: Text(
                              '+$more',
                              textScaler: TextScaler.noScaling,
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(
                                    color: Colors.white,
                                    fontWeight: OrbitFont.weightExtrabold,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Every photo of the visit, each with a remove button. Calls [onRemove]
/// with the photo's index; closes when the last one is removed.
class PhotoSheet extends StatefulWidget {
  /// Creates the sheet.
  const PhotoSheet({super.key, required this.photos, required this.onRemove});

  /// The photos' bytes (the sheet keeps its own copy).
  final List<Uint8List> photos;

  /// Removes the photo at an index.
  final ValueChanged<int> onRemove;

  @override
  State<PhotoSheet> createState() => _PhotoSheetState();
}

class _PhotoSheetState extends State<PhotoSheet> {
  late final List<Uint8List> _photos = [...widget.photos];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OrbitSpace.s16,
          0,
          OrbitSpace.s16,
          OrbitSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              dotJoin(l10n, [
                l10n.faVisitLogPhotos,
                l10n.faVisitLogPhotoCount(count: _photos.length),
              ]),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: OrbitSpace.s12),
            Wrap(
              spacing: OrbitSpace.s8,
              runSpacing: OrbitSpace.s8,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  SizedBox.square(
                    dimension: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Semantics(
                          image: true,
                          label: l10n.faVisitLogPhoto(number: i + 1),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(OrbitRadius.lg),
                            ),
                            child: Image.memory(_photos[i], fit: BoxFit.cover),
                          ),
                        ),
                        PositionedDirectional(
                          top: 0,
                          end: 0,
                          child: IconButton(
                            onPressed: () {
                              widget.onRemove(i);
                              setState(() => _photos.removeAt(i));
                              if (_photos.isEmpty) Navigator.pop(context);
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.6,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(OrbitIcons.close),
                            tooltip: l10n.faVisitLogRemovePhoto(number: i + 1),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width outlined button with a bold line and a smaller one, and a
/// chevron: opens a picker (the issue, the salt).
class PickerButton extends StatelessWidget {
  /// Creates the button.
  const PickerButton({
    super.key,
    required this.title,
    required this.semanticLabel,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.placeholder = false,
  });

  /// Bold line.
  final String title;

  /// Smaller line.
  final String? subtitle;

  /// Leading icon.
  final IconData? icon;

  /// What screen readers say.
  final String semanticLabel;

  /// Opens the picker; null disables it.
  final VoidCallback? onTap;

  /// Nothing picked yet: [title] in the muted colour.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
      side: BorderSide(color: scheme.outline, width: 1.5),
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: OrbitSize.controlXl),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OrbitSpace.s12,
                vertical: OrbitSpace.s6,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: scheme.primary),
                    const SizedBox(width: OrbitSpace.s10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall!.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: placeholder ? scheme.primary : null,
                          ),
                        ),
                        if (subtitle case final subtitle?)
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: orbit.textMuted,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(OrbitIcons.chevronRight, color: orbit.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Low / moderate / high, each in the UI language with the other language
/// under it (as in the design), filled in its severity colour when picked.
class SeverityPicker extends StatelessWidget {
  /// Creates the picker.
  const SeverityPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// The picked severity, or null.
  final Severity? value;

  /// Picks one.
  final ValueChanged<Severity> onChanged;

  static const _levels = [Severity.low, Severity.moderate, Severity.high];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    final other = lookupOrbitLocalizations(
      Locale(l10n.localeName.startsWith('te') ? 'en' : 'te'),
    );
    return Semantics(
      container: true,
      label: l10n.faVisitLogSeverity,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, s) in _levels.indexed) ...[
              if (i > 0) const SizedBox(width: OrbitSpace.s8),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final selected = s == value;
                    final tone = switch (s) {
                      Severity.low => orbit.severityLow,
                      Severity.high => orbit.severityHigh,
                      _ => orbit.severityModerate,
                    };
                    final shape = RoundedRectangleBorder(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(OrbitRadius.lg),
                      ),
                      side: BorderSide(
                        color: selected ? tone.strong : scheme.outline,
                        width: 1.5,
                      ),
                    );
                    final fg = selected ? scheme.surface : scheme.onSurface;
                    return Semantics(
                      button: true,
                      selected: selected,
                      inMutuallyExclusiveGroup: true,
                      label: severityLabel(l10n, s),
                      excludeSemantics: true,
                      child: Material(
                        color: selected ? tone.strong : scheme.surface,
                        shape: shape,
                        child: InkWell(
                          customBorder: shape,
                          onTap: () => onChanged(s),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 52),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: OrbitSpace.s4,
                                vertical: OrbitSpace.s4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    severityLabel(l10n, s),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleSmall!.copyWith(
                                      color: fg,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    severityLabel(other, s),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall!.copyWith(
                                      color: selected
                                          ? scheme.surface
                                          : orbit.textMuted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An issue already added: "Issue 1 · Pink bollworm", how bad and the
/// advice, and a remove button.
class AddedIssueRow extends StatelessWidget {
  /// Creates the row.
  const AddedIssueRow({
    super.key,
    required this.title,
    required this.detail,
    required this.removeLabel,
    required this.onRemove,
  });

  /// "Issue 1 · Pink bollworm".
  final String title;

  /// "Moderate · Emamectin benzoate 5% SG".
  final String detail;

  /// The remove button's label.
  final String removeLabel;

  /// Removes the issue.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orbit = OrbitColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          OrbitSpace.s12,
          OrbitSpace.s8,
          OrbitSpace.s4,
          OrbitSpace.s8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: orbit.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(OrbitIcons.close),
              color: orbit.danger.strong,
              tooltip: removeLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the issue sheet returns: the picked issue, or none ([id] null).
final class IssuePick {
  /// Creates the result.
  const IssuePick(this.id);

  /// The issue, or null for "No issue found".
  final String? id;
}

/// The searchable list of [issues] with their names in both languages, and
/// "No issue found" on top. Pops with an [IssuePick].
class IssueSheet extends StatefulWidget {
  /// Creates the sheet.
  const IssueSheet({super.key, required this.issues, this.selectedId});

  /// The crop's issues of one type.
  final List<SnapIssue> issues;

  /// The issue picked now, or null.
  final String? selectedId;

  @override
  State<IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends State<IssueSheet> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final language = contentLanguage(context);
    final q = _query.text.trim().toLowerCase();
    final shown = [
      for (final i in widget.issues)
        if (q.isEmpty ||
            i.name.toLowerCase().contains(q) ||
            i.nameTe.toLowerCase().contains(q))
          i,
    ];
    String other(SnapIssue i) => language == Language.te ? i.name : i.nameTe;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrbitSpace.s16),
              child: Text(
                l10n.faVisitLogPickIssue,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: OrbitSpace.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrbitSpace.s16),
              child: TextField(
                controller: _query,
                decoration: InputDecoration(
                  hintText: l10n.faVisitLogSearchIssues,
                  hintMaxLines: 2,
                  prefixIcon: const Icon(OrbitIcons.search),
                ),
              ),
            ),
            const SizedBox(height: OrbitSpace.s8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (q.isEmpty)
                    ListTile(
                      leading: const Icon(OrbitIcons.check),
                      title: Text(l10n.faVisitLogNoIssue),
                      selected: widget.selectedId == null,
                      onTap: () =>
                          Navigator.pop(context, const IssuePick(null)),
                    ),
                  for (final i in shown)
                    ListTile(
                      leading: const Icon(OrbitIcons.pests),
                      title: Text(i.displayName(language)),
                      subtitle: Text(other(i)),
                      selected: i.id == widget.selectedId,
                      onTap: () => Navigator.pop(context, IssuePick(i.id)),
                    ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(OrbitSpace.s16),
                      child: Text(
                        l10n.faVisitLogNoIssueMatch,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: OrbitSpace.s8),
          ],
        ),
      ),
    );
  }
}

/// The salts the masters suggest for an issue; pops with the picked rule's
/// ID.
class SaltSheet extends StatelessWidget {
  /// Creates the sheet.
  const SaltSheet({super.key, required this.options, this.selectedRuleId});

  /// The options.
  final List<AdviceOption> options;

  /// The rule picked now.
  final String? selectedRuleId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final language = contentLanguage(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrbitSpace.s16),
              child: Text(
                l10n.faVisitLogPickSalt,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: OrbitSpace.s8),
            for (final o in options)
              ListTile(
                leading: Icon(
                  o.hasProduct ? OrbitIcons.product : OrbitIcons.leaf,
                ),
                title: Text(o.saltName(language)),
                subtitle: Text(
                  dotJoin(l10n, [
                    o.dose(language),
                    if (o.sku case final sku?)
                      l10n.faVisitLogProduct(name: sku.displayName(language))
                    else
                      l10n.faVisitLogNoProduct,
                  ]),
                ),
                selected: o.rule.id == selectedRuleId,
                onTap: () => Navigator.pop(context, o.rule.id),
              ),
            const SizedBox(height: OrbitSpace.s8),
          ],
        ),
      ),
    );
  }
}

/// One line of the saved summary: a muted label and a bold value.
class SummaryRow extends StatelessWidget {
  /// Creates the row.
  const SummaryRow({super.key, required this.label, required this.value});

  /// "Stage".
  final String label;

  /// "Flowering".
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OrbitSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: OrbitColors.of(context).textMuted,
                ),
              ),
            ),
            const SizedBox(width: OrbitSpace.s12),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
