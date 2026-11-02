import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';
import '../../local/local.dart';
import '../../routing/routes.dart';
import '../../shared/contact.dart';
import '../../shared/formatters.dart';
import 'farmer_presenter.dart';
import 'farmer_widgets.dart';

/// OpenStreetMap's tile server.
const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// The app ID sent in the tiles' User-Agent, as OSM's tile policy asks.
const tileUserAgentPackage = 'com.shanmukhaagritec.orbit.fa';

/// Makes the map's tile provider. A new one per map: the tile layer disposes
/// it. Widget tests override it with one that makes no network calls.
final mapTileProviderProvider = Provider<TileProvider Function()>(
  (ref) => NetworkTileProvider.new,
);

/// Plot boundaries are drawn from this zoom in (closer than ~1 km across).
const boundaryMinZoom = 15.0;

/// A2m Farmers near me, map: the FA's position, one pin per farmer (coloured
/// New / 30+ days / others, as the legend says), plot boundaries when zoomed
/// in, and the selected farmer's card at the bottom.
///
/// Tiles come from OpenStreetMap while online. Offline the pins stay on a
/// plain background with "Map needs internet for now" (offline tiles come
/// with `orbit_maps`).
class FarmersMap extends ConsumerStatefulWidget {
  /// Creates the map of [rows], centred on [origin] ([isGps]: it is the FA's
  /// GPS position, so it gets the "you" marker).
  const FarmersMap({
    super.key,
    required this.rows,
    required this.origin,
    required this.isGps,
    required this.today,
    required this.online,
  });

  /// Farmers to pin, nearest first.
  final List<FarmerRow> rows;

  /// Where the map starts.
  final LatLng? origin;

  /// [origin] is the FA's position.
  final bool isGps;

  /// Today (IST).
  final LocalDate today;

  /// Load tiles.
  final bool online;

  @override
  ConsumerState<FarmersMap> createState() => _FarmersMapState();
}

class _FarmersMapState extends ConsumerState<FarmersMap> {
  String? _selectedId;
  bool _closeIn = false;

  static ll.LatLng _ll(LatLng p) => ll.LatLng(p.lat, p.lng);

  List<FarmerRow> get _pinned => [
    for (final r in widget.rows)
      if (r.location != null) r,
  ];

  FarmerRow? get _selected {
    final pinned = _pinned;
    if (pinned.isEmpty) return null;
    for (final r in pinned) {
      if (r.farmer.id == _selectedId) return r;
    }
    return pinned.first;
  }

  Color _pinColor(BuildContext context, FarmerRow row) {
    final orbit = OrbitColors.of(context);
    if (row.isNew) return orbit.success.fg;
    if (row.isNotVisited30) return orbit.danger.fg;
    return OrbitFarmerTokens.primary;
  }

  void _onMove(MapCamera camera, bool hasGesture) {
    final closeIn = camera.zoom >= boundaryMinZoom;
    if (closeIn != _closeIn) setState(() => _closeIn = closeIn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = contentLanguage(context);
    final pinned = _pinned;
    final selected = _selected;
    final centre =
        widget.origin ??
        (pinned.isEmpty ? null : pinned.first.location) ??
        const LatLng(17.4600, 78.3600);

    final pins = [
      for (final r in pinned)
        Marker(
          key: ValueKey('pin-${r.farmer.id}'),
          point: _ll(r.location!),
          width: OrbitSize.controlLg,
          height: OrbitSize.controlLg,
          child: _Pin(
            color: _pinColor(context, r),
            selected: r.farmer.id == selected?.farmer.id,
            label: dotJoin(l10n, [
              farmerName(r.farmer, language),
              farmerMeta(l10n, r, today: widget.today, language: language).text,
            ]),
            onTap: () => setState(() => _selectedId = r.farmer.id),
          ),
        ),
    ];
    final boundaries = !_closeIn
        ? const <Polygon>[]
        : [
            for (final r in pinned)
              for (final p in r.plots)
                for (final ring in p.plot.boundaryRings)
                  if (ring.length >= 3)
                    Polygon(
                      points: [for (final pt in ring) _ll(pt)],
                      color: _pinColor(context, r).withValues(alpha: 0.15),
                      borderColor: _pinColor(context, r),
                      borderStrokeWidth: 2,
                    ),
          ];

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _ll(centre),
              initialZoom: 13.5,
              minZoom: 9,
              maxZoom: 18,
              backgroundColor: scheme.surfaceContainerHigh,
              onPositionChanged: _onMove,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              if (widget.online)
                TileLayer(
                  urlTemplate: osmTileUrl,
                  userAgentPackageName: tileUserAgentPackage,
                  tileProvider: ref.read(mapTileProviderProvider)(),
                ),
              if (boundaries.isNotEmpty) PolygonLayer(polygons: boundaries),
              MarkerLayer(
                markers: [
                  if (widget.isGps && widget.origin != null)
                    Marker(
                      point: _ll(widget.origin!),
                      width: 40,
                      height: 40,
                      child: const _YouMarker(),
                    ),
                  ...pins,
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: OrbitSpace.s12,
          left: OrbitSpace.s12,
          right: OrbitSpace.s12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.online) ...[
                StatusPill(
                  label: l10n.faFarmersMapOffline,
                  tone: OrbitStatusTone.info,
                  icon: OrbitIcons.offline,
                ),
                const SizedBox(height: OrbitSpace.s8),
              ],
              _Legend(
                items: [
                  (OrbitColors.of(context).success.fg, l10n.faFarmersFilterNew),
                  (
                    OrbitColors.of(context).danger.fg,
                    l10n.faFarmersFilter30Days,
                  ),
                  (OrbitFarmerTokens.primary, l10n.faFarmersMapLegendOthers),
                ],
              ),
              if (widget.online) ...[
                const SizedBox(height: OrbitSpace.s4),
                _Attribution(text: l10n.faFarmersMapAttribution),
              ],
            ],
          ),
        ),
        if (selected != null)
          Positioned(
            left: OrbitSpace.s12,
            right: OrbitSpace.s12,
            bottom: OrbitSpace.s12,
            child: _SelectedCard(row: selected, today: widget.today),
          ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = selected ? 32.0 : 24.0;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 3),
              boxShadow: [
                if (selected)
                  BoxShadow(color: scheme.onSurface, spreadRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YouMarker extends StatelessWidget {
  const _YouMarker();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: context.l10n.faFarmersMapYou,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: 3),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.md)),
        boxShadow: OrbitElevation.e1,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OrbitSpace.s10,
          vertical: OrbitSpace.s6,
        ),
        child: Wrap(
          spacing: OrbitSpace.s12,
          runSpacing: OrbitSpace.s4,
          children: [
            for (final (color, label) in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: OrbitSpace.s6),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium!.copyWith(
                      fontWeight: OrbitFont.weightBold,
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

class _Attribution extends StatelessWidget {
  const _Attribution({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.xs)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OrbitSpace.s6,
          vertical: OrbitSpace.s2,
        ),
        child: Text(text, style: theme.textTheme.labelSmall),
      ),
    );
  }
}

class _SelectedCard extends ConsumerWidget {
  const _SelectedCard({required this.row, required this.today});

  final FarmerRow row;
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final orbit = OrbitColors.of(context);
    final farmer = row.farmer;
    final finish = finishEnrolmentRoute(row);
    final open = AppRoutes.farmer(farmer.id);
    final location = row.location;
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.faFarmersMapSelected,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(OrbitRadius.xl)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(OrbitSpace.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => openFrom(context, finish ?? open),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: OrbitSize.controlLg,
                  ),
                  child: FarmerSummaryLine(row: row, today: today),
                ),
              ),
              const SizedBox(height: OrbitSpace.s10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: FarmerActionButton(
                        label: finish != null
                            ? l10n.faFarmersActionFinishEnrolment
                            : l10n.faFarmersActionOpenFarmer,
                        color: finish != null
                            ? orbit.success.fg
                            : theme.colorScheme.primary,
                        filled: true,
                        onPressed: () => openFrom(context, finish ?? open),
                      ),
                    ),
                    const SizedBox(width: OrbitSpace.s8),
                    Expanded(
                      flex: 2,
                      child: FarmerActionButton(
                        label: l10n.commonCall,
                        icon: OrbitIcons.phone,
                        onPressed: () => callFarmer(context, ref, farmer.phone),
                      ),
                    ),
                    const SizedBox(width: OrbitSpace.s8),
                    FarmerActionButton(
                      icon: OrbitIcons.directions,
                      semanticLabel: l10n.faFarmersActionDirections,
                      onPressed: location == null
                          ? null
                          : () => directionsTo(context, ref, location),
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
