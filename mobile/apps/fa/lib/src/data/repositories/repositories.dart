/// Repository interfaces of the FA app: one method per endpoint, domain
/// models in and out, `ApiError` on failure. Screens and controllers depend on
/// these only, never on the mock or API implementations. Most screens do not
/// use them at all: they read the territory and write through `FaActions`
/// (`local/`), and the sync engine talks to [SyncRepository].
library;

import 'alerts_repository.dart';
import 'enrolment_repository.dart';
import 'fa_auth_repository.dart';
import 'photo_uploader.dart';
import 'sync_repository.dart';
import 'visit_photos_repository.dart';

export 'alerts_repository.dart';
export 'enrolment_repository.dart';
export 'fa_auth_repository.dart';
export 'photo_uploader.dart';
export 'sync_repository.dart';
export 'visit_photos_repository.dart';

/// One full set of repositories from the same source (mock or API), so they
/// share one backend state and one session store.
final class FaRepositories {
  /// Groups a set of repositories.
  const FaRepositories({
    required this.auth,
    required this.sync,
    required this.enrolment,
    required this.visitPhotos,
    required this.photoUploader,
    required this.alerts,
  });

  /// Sign-in, tokens, password, heartbeat.
  final FaAuthRepository auth;

  /// Snapshot, status, command push.
  final SyncRepository sync;

  /// Phone lookup, consent OTP, farmer photo URL.
  final EnrolmentRepository enrolment;

  /// Visit photo upload URL and confirm.
  final VisitPhotosRepository visitPhotos;

  /// PUT to presigned URLs.
  final PhotoUploader photoUploader;

  /// Online alerts list.
  final AlertsRepository alerts;
}
