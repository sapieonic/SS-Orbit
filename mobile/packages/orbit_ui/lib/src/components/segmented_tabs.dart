import 'package:flutter/material.dart';

import '../tokens/orbit_tokens.g.dart';

/// A row of mutually exclusive options on a sunken track, e.g. village /
/// mandal / district (F3).
///
/// Labels wrap instead of shrinking; all segments take the height of the
/// tallest one.
class SegmentedTabs extends StatelessWidget {
  /// Creates the tabs.
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  /// Segment labels, already localised.
  final List<String> labels;

  /// Index of the selected segment.
  final int selectedIndex;

  /// Called with the tapped segment's index. Null disables the control.
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    assert(labels.length > 1, 'need at least two segments');
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const inner = BorderRadius.all(Radius.circular(OrbitRadius.md));

    Widget segment(int i) {
      final selected = i == selectedIndex;
      return MergeSemantics(
        child: Semantics(
          button: true,
          selected: selected,
          inMutuallyExclusiveGroup: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: inner,
              boxShadow: selected ? OrbitElevation.e1 : null,
            ),
            child: Material(
              color: selected ? scheme.surface : Colors.transparent,
              borderRadius: inner,
              child: InkWell(
                borderRadius: inner,
                onTap: onChanged == null ? null : () => onChanged!(i),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: OrbitSize.controlLg,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OrbitSpace.s8,
                      vertical: OrbitSpace.s4,
                    ),
                    child: Center(
                      child: Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: OrbitSpace.s4),
                Expanded(child: segment(i)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
