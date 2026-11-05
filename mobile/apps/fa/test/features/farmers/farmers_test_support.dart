/// Shared bits of the Farmers and Farmer 360 widget tests: a tile provider
/// that makes no network calls, and lookups into the mock world.
library;

import 'dart:convert';

import 'package:fa/src/features/farmers/farmers_map.dart';
import 'package:fa/src/local/local.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// A 1x1 transparent PNG.
final transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// Tiles from memory: counts what the map asked for, never touches the
/// network.
class MemoryTileProvider extends TileProvider {
  /// Tiles asked for, over every instance.
  static int requested = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requested++;
    return MemoryImage(transparentPng);
  }
}

/// Overrides every Farmers test needs: no network tiles.
List<Override> farmersOverrides() => [
  mapTileProviderProvider.overrideWithValue(MemoryTileProvider.new),
];

/// The list row of the farmer with English name [name].
FarmerRow rowNamed(Territory t, String name) =>
    t.farmerRows().firstWhere((r) => r.farmer.name == name);
