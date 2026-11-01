import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import 'advice_text.dart';

/// One issue on a visit: severity, name and the one-line advice. Tapping it
/// opens the advice screen.
class IssueRow extends StatelessWidget {
  /// Creates the row.
  const IssueRow({
    super.key,
    required this.advice,
    required this.language,
    required this.onTap,
  });

  /// The issue and its advice.
  final FarmerAdvice advice;

  /// The farmer's language for data text.
  final Language language;

  /// Opens the advice.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (name, otherName) = issueNames(l10n, language, advice);
    final severity = orbitSeverity(advice.severity);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: OrbitSize.controlXl),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                OrbitSpace.s16,
                OrbitSpace.s12,
                OrbitSpace.s8,
                OrbitSpace.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (severity != null) ...[
                          SeverityPill(
                            severity: severity,
                            label: l10n.labelSeverity(advice.severity.wire),
                          ),
                          const SizedBox(height: OrbitSpace.s6),
                        ],
                        BilingualText(
                          name,
                          secondary: otherName,
                          primaryStyle: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: OrbitSpace.s6),
                        _AdviceLine(advice: advice, language: language),
                      ],
                    ),
                  ),
                  const SizedBox(width: OrbitSpace.s8),
                  ExcludeSemantics(
                    child: Icon(
                      OrbitIcons.chevronRight,
                      size: OrbitSize.iconLg,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "మందు: Sample 5 SG" + dose, "No Shanmukha product, ask the shop", or
/// "Your FA will follow up".
class _AdviceLine extends StatelessWidget {
  const _AdviceLine({required this.advice, required this.language});

  final FarmerAdvice advice;
  final Language language;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final (
      IconData icon,
      Color color,
      String text,
      String? detail,
    ) = switch (adviceTypeOf(advice)) {
      AdviceType.product => (
        OrbitIcons.productFound,
        orbit.success.strong,
        l10n.farmerVisitsMedicine(
          name: pickText(
            language,
            te: advice.productNameTe,
            en: advice.productName,
          ),
        ),
        doseText(language, advice),
      ),
      AdviceType.saltOnly => (
        OrbitIcons.shop,
        theme.colorScheme.onSurfaceVariant,
        l10n.farmerVisitsSaltOnly,
        null,
      ),
      AdviceType.pending => (
        OrbitIcons.pending,
        orbit.warning.strong,
        l10n.farmerVisitsAdvicePending,
        null,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: OrbitSpace.s2),
          child: Icon(icon, size: OrbitSize.iconMd, color: color),
        ),
        const SizedBox(width: OrbitSpace.s8),
        Expanded(
          child: BilingualText(
            text,
            secondary: detail,
            primaryStyle: theme.textTheme.bodyLarge!.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
