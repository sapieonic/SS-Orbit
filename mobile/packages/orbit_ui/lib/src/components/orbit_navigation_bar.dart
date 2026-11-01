import 'package:flutter/material.dart';

import '../tokens/orbit_tokens.g.dart';

/// One tab of an [OrbitNavigationBar].
@immutable
class OrbitNavigationDestination {
  /// Creates a destination.
  const OrbitNavigationDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge,
  });

  /// Icon when not selected.
  final IconData icon;

  /// Icon when selected; defaults to [icon].
  final IconData? selectedIcon;

  /// Tab label (always shown), already localised, e.g. "హోమ్".
  final String label;

  /// Optional badge text, e.g. an unread count.
  final String? badge;
}

/// The bottom tab bar: icon and label on every tab, themed by `OrbitTheme`.
///
/// A thin wrapper over Material's [NavigationBar] that always shows labels
/// and grows its height with the text scale so Telugu labels are not
/// clipped.
class OrbitNavigationBar extends StatelessWidget {
  /// Creates the bar.
  const OrbitNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  /// The tabs.
  final List<OrbitNavigationDestination> destinations;

  /// Index of the selected tab.
  final int selectedIndex;

  /// Called with the tapped tab's index.
  final ValueChanged<int> onDestinationSelected;

  /// [NavigationBar] clamps label text scaling to this.
  static const double _maxLabelScale = 1.3;

  @override
  Widget build(BuildContext context) {
    assert(destinations.length >= 2, 'need at least two destinations');
    final theme = Theme.of(context);
    final label = theme.textTheme.labelMedium!;
    final labelHeight =
        MediaQuery.textScalerOf(context)
            .clamp(maxScaleFactor: _maxLabelScale)
            .scale(label.fontSize!) *
        label.height!;
    // Paddings and the 32 dp indicator, plus one label line at the
    // clamped text scale.
    final height = OrbitSize.controlXxl + labelHeight;

    Widget icon(IconData data, String? badge) => badge == null
        ? Icon(data)
        : Badge(label: Text(badge), child: Icon(data));

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: NavigationBar(
        height: height,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: icon(d.icon, d.badge),
              selectedIcon: icon(d.selectedIcon ?? d.icon, d.badge),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
