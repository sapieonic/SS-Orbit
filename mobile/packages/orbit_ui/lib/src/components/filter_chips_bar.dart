import 'package:flutter/material.dart';

import '../tokens/orbit_tokens.g.dart';

/// One chip of a [FilterChipsBar].
@immutable
class FilterChipItem {
  /// Creates a chip.
  const FilterChipItem({required this.label, this.count});

  /// The filter's name, already localised ("Visit due").
  final String label;

  /// How many items the filter shows, after the label ("Visit due · 12").
  /// Hidden when null.
  final int? count;
}

/// A row of pick-one filter chips that scrolls sideways when it is wider than
/// the screen (Farmers: All, New, Visit due, 30+ days; Alerts: All, New
/// farmer, Callback, HO note).
///
/// The selected chip is filled with the primary colour. Chips are at least
/// 48 dp tall and never wrap or shrink their label; each reads as a button
/// in a group where one is selected. The selected chip scrolls into view
/// when it changes.
class FilterChipsBar extends StatelessWidget {
  /// Creates the bar.
  const FilterChipsBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.semanticLabel,
    this.padding = EdgeInsets.zero,
  });

  /// The chips, in order.
  final List<FilterChipItem> items;

  /// Index of the selected chip.
  final int selectedIndex;

  /// Called with the tapped chip's index. Null disables the bar.
  final ValueChanged<int>? onSelected;

  /// What the group is, for screen readers ("Filter farmers").
  final String? semanticLabel;

  /// Padding inside the scroll view, e.g. the screen's side margins so the
  /// chips scroll edge to edge.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    assert(items.isNotEmpty, 'need at least one chip');
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: OrbitSpace.s8),
              _Chip(
                item: items[i],
                selected: i == selectedIndex,
                onTap: onSelected == null ? null : () => onSelected!(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({required this.item, required this.selected, this.onTap});

  final FilterChipItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  @override
  void didUpdateWidget(_Chip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: const Duration(milliseconds: 150),
        );
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          duration: const Duration(milliseconds: 150),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = widget.selected;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final style = theme.textTheme.labelLarge!.copyWith(color: fg, fontSize: 14);
    final count = widget.item.count;
    const shape = StadiumBorder();
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        shape: shape.copyWith(
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: 1.5,
          ),
        ),
        child: InkWell(
          customBorder: shape,
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: OrbitSize.controlLg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  count == null
                      ? widget.item.label
                      : '${widget.item.label} · $count',
                  style: style,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
