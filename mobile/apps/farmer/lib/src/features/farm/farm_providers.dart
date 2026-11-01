import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data.dart';
import '../../shared/farmer_data.dart';

/// The farmer's consents (`GET /v1/farmer/me/consents`), one per purpose,
/// with the grant / withdraw action for the Consents screen. Refetched when
/// another farmer signs in.
final farmConsentsProvider =
    AsyncNotifierProvider<FarmConsentsController, List<CurrentConsent>>(
      FarmConsentsController.new,
    );

/// Loads the consents and records the farmer's changes.
class FarmConsentsController extends AsyncNotifier<List<CurrentConsent>> {
  @override
  Future<List<CurrentConsent>> build() => loadFarmerData(
    ref,
    'consents',
    () => ref.watch(farmerProfileRepositoryProvider).listConsents(),
  );

  /// Grants or withdraws [purpose] (`POST /v1/farmer/me/consents`, method
  /// app, the bundled notice version). The returned list replaces the state,
  /// unless another farmer signed in meanwhile. Throws `ApiError` for the
  /// screen to show; the state is unchanged then.
  Future<void> setConsent(
    ConsentPurpose purpose, {
    required bool granted,
  }) async {
    final scope = ref.read(farmerDataScopeProvider);
    final current = await ref
        .read(farmerProfileRepositoryProvider)
        .setConsent(
          purpose: purpose,
          granted: granted,
          noticeVersion: programmeConsentNoticeVersion,
          audioPlayed: false,
        );
    if (isCurrentScope(ref, scope)) state = AsyncData(current);
  }
}

/// Where to pin a new plot while the app has no GPS (`geolocator` is not
/// wired yet): the farmer's village centroid, else the pin of one of their
/// other plots, else null (the Add plot screen then asks for the FA's help).
///
/// `GET /v1/farmer/me` has no village coordinates, so this looks the village
/// up with `GET /v1/farmer/villages` (by name, within the mandal). Refreshes
/// with Home, keeping the pin meanwhile.
// TODO(gps): replace with the phone's location from `geolocator` (permission
// prompt, accuracy shown with farmer.plot_add.accuracy, weak-GPS retry), and
// keep the village centroid only as the fallback.
final plotPinProvider = FutureProvider.autoDispose<LatLng?>(
  (ref) => loadFarmerData(ref, 'plotPin', () => _plotPin(ref)),
);

Future<LatLng?> _plotPin(Ref ref) async {
  final geo = ref.watch(geoRepositoryProvider);
  final home = await followFarmerData(ref, farmerHomeProvider.future);
  final village = home.village;
  if (village != null) {
    final matches = await geo.searchVillages(
      query: village.name,
      mandalId: village.mandalId,
      limit: 50,
    );
    final match = matches.where((v) => v.id == village.id).firstOrNull;
    final lat = match?.lat;
    final lng = match?.lng;
    if (lat != null && lng != null) return LatLng(lat, lng);
  }
  for (final p in home.plots) {
    if (p.plot.pin case final pin?) return pin;
  }
  return null;
}
