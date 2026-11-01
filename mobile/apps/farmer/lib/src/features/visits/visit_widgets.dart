import 'package:flutter/material.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import 'issue_row.dart';

/// "FA మళ్ళీ వచ్చే రోజు": the next planned visit, or "Not planned yet".
class NextVisitCard extends StatelessWidget {
  /// Creates the card.
  const NextVisitCard({
    super.key,
    required this.nextVisit,
    required this.today,
    required this.language,
  });

  /// The next visit; null shows "Not planned yet".
  final NextVisit? nextVisit;

  /// Today in IST, for "Today" / "Tomorrow".
  final LocalDate today;

  /// The farmer's language, for the FA's name.
  final Language language;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final next = nextVisit;
    final String dateLine;
    final List<String> details = [];
    if (next == null) {
      dateLine = l10n.farmerHomeNoNextVisit;
    } else {
      final date = l10n.commonDateWeekday(date: next.plannedFor.toDateTime());
      final days = today.daysUntil(next.plannedFor);
      dateLine = switch (days) {
        0 => l10n.commonDotJoin(first: l10n.commonToday, second: date),
        1 => l10n.commonDotJoin(first: l10n.commonTomorrow, second: date),
        _ => date,
      };
      if (next.plannedSlot != PlannedSlot.unknown) {
        details.add(l10n.labelPlannedSlot(next.plannedSlot.wire));
      }
      if (next.fa case final fa?) {
        details.add(
          l10n.farmerVisitsCallBefore(name: fa.displayName(language)),
        );
      }
    }
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              OrbitIcons.visit,
              size: OrbitSize.iconXl,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: OrbitSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.farmerVisitsNextVisit,
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: OrbitSpace.s4),
                  Text(
                    dateLine,
                    style: theme.textTheme.titleLarge!.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  for (final line in details)
                    Text(
                      line,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One logged visit: "12 అక్టో · సురేష్", the crop stage, and a tappable row
/// per issue with its advice.
class VisitCard extends StatelessWidget {
  /// Creates the card.
  const VisitCard({
    super.key,
    required this.visit,
    required this.language,
    required this.onOpenIssue,
  });

  /// The visit.
  final FarmerVisit visit;

  /// The farmer's language for data text.
  final Language language;

  /// Opens the advice for issue number `index`.
  final ValueChanged<int> onOpenIssue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final date = toIstWallClock(visit.visitedAt);
    final fa = visit.fa;
    final heading = fa == null
        ? l10n.commonDateShort(date: date)
        : l10n.farmerVisitsByFa(date: date, name: fa.displayName(language));
    final stage = pickText(
      language,
      te: visit.stageNameTe,
      en: visit.stageName,
    );
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OrbitSpace.s16,
              OrbitSpace.s12,
              OrbitSpace.s16,
              OrbitSpace.s8,
            ),
            child: BilingualText(
              heading,
              secondary: stage.isEmpty
                  ? null
                  : l10n.farmerVisitsStage(stage: stage),
              primaryStyle: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          if (visit.issues.isEmpty)
            Padding(
              padding: const EdgeInsets.all(OrbitSpace.s16),
              child: InfoRow(
                icon: OrbitIcons.success,
                text: l10n.farmerVisitsNoIssues,
              ),
            )
          else
            for (final (index, issue) in visit.issues.indexed) ...[
              if (index > 0) const Divider(height: 1),
              IssueRow(
                advice: issue,
                language: language,
                onTap: () => onOpenIssue(index),
              ),
            ],
        ],
      ),
    );
  }
}
