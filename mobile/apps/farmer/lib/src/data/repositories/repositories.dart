/// Repository interfaces of the farmer app: one method per endpoint, domain
/// models in and out, `ApiError` on failure. Screens and controllers depend on
/// these only, never on the mock or API implementations.
library;

import 'auth_repository.dart';
import 'farmer_profile_repository.dart';
import 'field_assistant_repository.dart';
import 'geo_repository.dart';
import 'masters_repository.dart';
import 'notices_repository.dart';
import 'visits_repository.dart';

export 'auth_repository.dart';
export 'farmer_profile_repository.dart';
export 'field_assistant_repository.dart';
export 'geo_repository.dart';
export 'masters_repository.dart';
export 'notices_repository.dart';
export 'visits_repository.dart';

/// One full set of repositories from the same source (mock or API), so they
/// share one backend state and one session store.
final class FarmerRepositories {
  /// Groups a set of repositories.
  const FarmerRepositories({
    required this.auth,
    required this.profile,
    required this.fieldAssistants,
    required this.visits,
    required this.notices,
    required this.geo,
    required this.masters,
  });

  /// Sign-in, tokens, heartbeat.
  final AuthRepository auth;

  /// Home, profile, consents, plots, seasons.
  final FarmerProfileRepository profile;

  /// FAs and call-backs.
  final FieldAssistantRepository fieldAssistants;

  /// My visits.
  final VisitsRepository visits;

  /// Crop advisory inbox.
  final NoticesRepository notices;

  /// Village picker.
  final GeoRepository geo;

  /// Crops, season codes, dealers.
  final MastersRepository masters;
}
