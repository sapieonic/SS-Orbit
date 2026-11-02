/// All mock server data and every `Mock*Repository` of the FA app, in one
/// file.
///
/// [MockBackend] is a stand-in for the real server: it keeps its own
/// server-side state (FA logins, sessions and refresh tokens, devices,
/// farmers, plots, seasons, visits with issues, call-backs, alerts, masters,
/// villages, stored command results) and answers every FA endpoint the way
/// the backend does: same error codes, same idempotency, same command rules
/// (`backend/internal/farmers/commands*.go`, `visits/commands.go`,
/// `visits/service_log.go`, CONVENTIONS section 6). It never shares objects
/// with the app's offline store: every snapshot is built fresh from server
/// state.
///
/// IDs of rows the dev seed also has (`backend/cmd/seed`: villages, FA
/// Suresh and FA-CVL-002, crops, stages, salts, SKUs, rules, Ravi K and
/// Venkatesh M with their plots and seasons) are the seed's UUIDv5 values, so
/// mock and dev data line up; mock-only rows use `mock:` names.
///
/// Dev only: `providers.dart` builds this only when `OrbitEnv.usesMock`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:orbit_core/orbit_core.dart';

import '../../local/commands.dart';
import '../helpline.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../session/auth_failures.dart';
import '../session/session_store.dart';

/// What the mock should pretend, so offline, error and blocked states can be
/// shown and tested. Switch it at runtime with `MockBackend.scenario` (or the
/// `mockScenarioProvider` in `providers.dart`).
enum MockScenario {
  /// Seeded data, everything works.
  normal('Normal', 'Seeded data, everything works'),

  /// Every call throws `ApiError.network()` (no internet).
  offline('Offline', 'Every call fails with a network error'),

  /// Every call takes `MockBackend.slowLatency` (default 4 s).
  slowNetwork('Slow network', 'Every call is slow'),

  /// Every call throws 503 `unavailable`.
  serverError('Server error', 'Every call fails with 503'),

  /// HO removed the phones signed in so far: their heartbeat answers
  /// `wipe: true` and every other call (refresh and login with that install
  /// ID too) fails with 401 `device_revoked`. A new install ID signs in
  /// normally. Selected before any sign-in, it removes the first device that
  /// signs in.
  deviceRemoved('Phone removed', 'Heartbeat says wipe; calls get 401'),

  /// The heartbeat and app config say this version is too old
  /// (`min_version` 1.0.5).
  updateRequired('Update required', 'Heartbeat and app config force update'),

  /// The next SavePlot or UpdateFarmer for Padma S (her Plot 2) comes back
  /// `conflict`: HO changed the same record meanwhile (Plot 2 becomes
  /// 2 ac 0 gunta).
  syncConflict('Sync conflict', "Next edit of Padma S's Plot 2 conflicts"),

  /// The next command batch stops half way with `retry_from`, as after a
  /// server-side failure.
  partialFailure('Partial failure', 'Next command batch stops half way'),

  /// The sessions signed in so far ended on the server: refresh and every
  /// signed-in call fail with 401 `unauthorized`. The PIN still opens local
  /// data; syncing needs the password (a new login works). Selected before
  /// any sign-in, it ends the first session that signs in.
  sessionExpired('Session expired', 'Refresh fails; sync needs password');

  const MockScenario(this.label, this.description);

  /// Short English label for the dev switch.
  final String label;

  /// One line saying what changes.
  final String description;
}

/// In-memory server behind the mock FA repositories.
///
/// ```dart
/// final backend = MockBackend(latency: Duration.zero); // tests
/// final repos = backend.repositories(InMemorySessionStore());
/// backend.scenario = MockScenario.offline; // takes effect on the next call
/// ```
class MockBackend {
  /// Creates a backend with the seeded mock world.
  ///
  /// [latency] is added to every call (zero in tests); [slowLatency] replaces
  /// it in [MockScenario.slowNetwork]. [random] makes generated IDs and
  /// tokens repeatable in tests. Seed dates are relative to [clock]'s today.
  MockBackend({
    this.clock = const SystemClock(),
    this.latency = const Duration(milliseconds: 350),
    this.slowLatency = const Duration(seconds: 4),
    MockScenario scenario = MockScenario.normal,
    math.Random? random,
  }) : _random = random ?? math.Random.secure() {
    _seed();
    this.scenario = scenario;
  }

  // ---------------------------------------------------------------------------
  // Mock world: logins, phones and IDs other code and tests can rely on.

  /// The fixed OTP for consent codes, like the dev backend's
  /// `DEV_FIXED_OTP`.
  static const fixedOtp = '123456';

  /// Consent notice version used by the seed.
  static const consentNoticeVersion = 'v1';

  /// Host of every URL the mock hands out (uploads). It never resolves; the
  /// mock [PhotoUploader] accepts PUTs to it.
  static const mockHost = 'mock.orbit.invalid';

  /// FA Suresh Kumar: Kondapur and Gachibowli (Serilingampally).
  static const sureshCode = 'FA-KDP-014';

  /// Suresh's password in the mock (the dev seed uses `fa-dev-pass`).
  static const sureshPassword = 'orbit2026';

  /// Signs in with a temporary password: must change it first.
  static const tempPasswordCode = 'FA-KDP-099';

  /// The temporary password of [tempPasswordCode].
  static const tempPassword = 'temp1234';

  /// A temporary password older than 72 hours: 401 `temp_password_expired`.
  static const expiredPasswordCode = 'FA-KDP-077';

  /// The expired temporary password of [expiredPasswordCode].
  static const expiredPassword = 'temp5678';

  /// Another FA (Lakshmi P, Chevella mandal). Their farmers are `other_fa`.
  static const otherFaCode = 'FA-CVL-002';

  /// [otherFaCode]'s password in the mock.
  static const otherFaPassword = 'chevella2026';

  /// HO helpline shown on blocked and help screens (the app's one number).
  static const hoHelpline = hoHelplineNumber;

  /// Ravi K, Kondapur, cotton (as in the farmer app mock): lookup `mine`.
  static const raviPhone = '+919000000101';

  /// Venkatesh M, Gachibowli, paddy (as in the farmer app mock).
  static const venkateshPhone = '+919000000102';

  /// Venkat R, Kondapur, cotton, visit due in 2 days.
  static const venkatPhone = '+919000000103';

  /// Padma S, Gachibowli, paddy, premium; Plot 2 is the conflict case.
  static const padmaPhone = '+919000000104';

  /// Lakshmi N, Kondapur, maize, joined yesterday.
  static const lakshmiPhone = '+919000000105';

  /// Raju P signed up himself today in Kondapur, no FA yet: lookup
  /// `unassigned_in_my_area`; EnrolFarmer comes back `merged`.
  static const rajuPhone = '+919123456780';

  /// FA-CVL-002's farmer (Narsimha G, Chevella): lookup `other_fa`;
  /// EnrolFarmer is rejected `registered_with_another_fa`.
  static const otherFaFarmerPhone = '+919000000201';

  /// Srinivas D, Madhapur, no FA: lookup `outside_my_area`; EnrolFarmer is
  /// rejected `not_in_your_area`.
  static const outsideAreaPhone = '+919000000301';

  /// Mallesh T, deactivated by HO: lookup `deactivated`.
  static const deactivatedPhone = '+919000000302';

  /// Suresh's FA ID.
  static final sureshId = sid('fa:suresh');

  /// FA-CVL-002's FA ID.
  static final otherFaId = sid('fa:lakshmi');

  /// Kondapur village.
  static final kondapurId = sid('village:kondapur');

  /// Gachibowli village.
  static final gachibowliId = sid('village:gachibowli');

  /// Madhapur village (Serilingampally, outside Suresh's area).
  static final madhapurId = sid('village:madhapur');

  /// Chevella village (FA-CVL-002's area).
  static final chevellaId = sid('village:chevella');

  /// Ravi K.
  static final raviId = sid('farmer:ravi');

  /// Ravi K's Plot 1.
  static final raviPlotId = sid('plot:ravi:1');

  /// Ravi K's cotton season.
  static final raviSeasonId = sid('season:ravi:1:kharif-2026');

  /// Ravi K's open call-back request.
  static final raviCallbackId = sid('mock:callback:ravi');

  /// Venkatesh M.
  static final venkateshId = sid('farmer:venkatesh');

  /// Venkat R.
  static final venkatId = sid('mock:farmer:venkat');

  /// Padma S.
  static final padmaId = sid('mock:farmer:padma');

  /// Padma S's Plot 2 (the conflict case).
  static final padmaPlot2Id = sid('mock:plot:padma:2');

  /// Lakshmi N.
  static final lakshmiId = sid('mock:farmer:lakshmi');

  /// Raju P (not Suresh's until enrolled).
  static final rajuId = sid('mock:farmer:raju');

  /// The cotton crop.
  static final cottonId = sid('crop:cotton');

  /// The paddy crop.
  static final paddyId = sid('crop:paddy');

  /// The chilli crop.
  static final chilliId = sid('crop:chilli');

  /// The maize crop.
  static final maizeId = sid('mock:crop:maize');

  /// The red gram crop.
  static final redGramId = sid('mock:crop:redgram');

  /// Cotton pink bollworm.
  static final pinkBollwormId = sid('issue:cotton:pink-bollworm');

  /// The approved rule for pink bollworm (Emamectin + Sample 5 SG).
  static final pinkBollwormRuleId = sid('rule:pbw:v1');

  /// The approved rule for cotton leaf spot (Mancozeb, salt only).
  static final leafSpotRuleId = sid('mock:rule:leafspot:v1');

  /// A stable UUID for a seed row: UUIDv5 of [name] in the dev seed's
  /// namespace, the same as `sid()` in `backend/cmd/seed/main.go`.
  static String sid(String name) {
    final digest = sha1.convert([..._seedNamespace, ...utf8.encode(name)]);
    final b = digest.bytes.sublist(0, 16);
    b[6] = (b[6] & 0x0f) | 0x50;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  static final List<int> _seedNamespace = [
    for (var i = 0; i < 32; i += 2)
      int.parse(
        '5b0f1a526f0e4c1d9a510b17c0de5eed'.substring(i, i + 2),
        radix: 16,
      ),
  ];

  /// The snapshot carries alerts created in the last this many days
  /// (messaging `snapshotAlertDays`).
  static const snapshotAlertDays = 30;

  /// At most this many alerts in the snapshot (messaging
  /// `snapshotAlertLimit`).
  static const snapshotAlertLimit = 200;

  /// Missed visits planned for the last this many days are in the snapshot
  /// (status `missed`), so the app can show them as overdue and re-plan or
  /// log them. **Proposed contract:** the real snapshot sends planned and
  /// done visits only; see "Not done yet" in `mobile/README.md`.
  static const snapshotMissedDays = 14;

  // ---------------------------------------------------------------------------
  // Configuration.

  /// Time source for "today", OTP and proof expiry, rate limits and seed
  /// dates.
  final Clock clock;
  final math.Random _random;

  /// Added to every call.
  Duration latency;

  /// Used instead of [latency] in [MockScenario.slowNetwork].
  Duration slowLatency;

  MockScenario _scenario = MockScenario.normal;

  /// The current scenario; read on every call.
  MockScenario get scenario => _scenario;

  /// Switches the scenario. Entering [MockScenario.deviceRemoved] or
  /// [MockScenario.sessionExpired] affects the devices and sessions that
  /// exist now (or the next one, when there are none); entering
  /// [MockScenario.syncConflict] or [MockScenario.partialFailure] arms it
  /// for the next matching command or batch.
  set scenario(MockScenario value) {
    _revokedDevices.clear();
    _revokeNextDevice = false;
    _expiredFamilies.clear();
    _expireNextFamily = false;
    _conflictArmed = false;
    _partialArmed = false;
    _scenario = value;
    switch (value) {
      case MockScenario.deviceRemoved:
        _revokedDevices.addAll(_devices.values.map((d) => d.id));
        _revokeNextDevice = _devices.isEmpty;
      case MockScenario.sessionExpired:
        _expiredFamilies.addAll(_access.values.map((t) => t.family));
        _expireNextFamily = _access.isEmpty;
      case MockScenario.syncConflict:
        _conflictArmed = true;
      case MockScenario.partialFailure:
        _partialArmed = true;
      case MockScenario.normal ||
          MockScenario.offline ||
          MockScenario.slowNetwork ||
          MockScenario.serverError ||
          MockScenario.updateRequired:
        break;
    }
  }

  /// Builds the repositories over this backend. They read and write the
  /// session in [store], and report every failed signed-in call to
  /// [authFailures], like the API implementations will.
  FaRepositories repositories(
    SessionStore store, {
    AuthFailureHook? authFailures,
  }) => FaRepositories(
    auth: MockFaAuthRepository(this, store, authFailures),
    sync: MockSyncRepository(this, store, authFailures),
    enrolment: MockEnrolmentRepository(this, store, authFailures),
    visitPhotos: MockVisitPhotosRepository(this, store, authFailures),
    photoUploader: MockPhotoUploader(this),
    alerts: MockAlertsRepository(this, store, authFailures),
  );

  /// Drops every change (enrolments, visits, tokens, devices, stored
  /// commands) and loads the seed again, relative to today. Keeps the
  /// scenario (re-armed).
  void reset() {
    _accounts.clear();
    _farmers.clear();
    _plots.clear();
    _seasons.clear();
    _visits.clear();
    _callbacks.clear();
    _alerts.clear();
    _aliases.clear();
    _commands.clear();
    _territoryVersions.clear();
    _otps.clear();
    _otpSends.clear();
    _proofs.clear();
    _lookups.clear();
    _photoUrlRequests.clear();
    _loginAttempts.clear();
    _passwordChanges.clear();
    _access.clear();
    _refresh.clear();
    _rotated.clear();
    _devices.clear();
    _presigned.clear();
    _objects.clear();
    _seed();
    scenario = _scenario;
  }

  // ---------------------------------------------------------------------------
  // Dev and test helpers (HO actions, read access to server state).

  /// Simulates HO editing a plot on the portal: changes [areaAcres] and/or
  /// [label], bumps the plot version and the owner FA's territory version.
  /// A queued SavePlot with the old `expected_version` then conflicts.
  SnapPlot hoEditPlot(String plotId, {double? areaAcres, String? label}) {
    final p = _plots[plotId];
    if (p == null) throw ArgumentError.value(plotId, 'plotId', 'no such plot');
    if (areaAcres != null) {
      p
        ..areaAcres = areaAcres
        ..areaSource = AreaSource.typed;
    }
    if (label != null) p.label = label;
    p
      ..version += 1
      ..updatedAt = _now
      ..lastCommandId = null;
    _bump([_farmers[p.farmerId]?.assignedFaId]);
    return p.snap();
  }

  /// Adds an alert for an FA (Suresh by default), as HO or the server would:
  /// an HO note, a new-farmer or call-back alert. Bumps that FA's territory
  /// version, so the next sync pulls it.
  SnapAlert addAlert({
    AlertKind kind = AlertKind.hoNote,
    required String title,
    String? body,
    String? titleTe,
    String? bodyTe,
    String? farmerId,
    String? refId,
    String? faId,
  }) {
    final a = _Alert(
      id: _newId(),
      faId: faId ?? sureshId,
      kind: kind,
      farmerId: farmerId,
      refId: refId,
      title: title,
      body: body,
      titleTe: titleTe,
      bodyTe: bodyTe,
      status: AlertStatus.open,
      createdAt: _now,
    );
    _alerts[a.id] = a;
    _bump([a.faId]);
    return a.snap();
  }

  /// Simulates [farmerId] asking their FA to call back from the farmer app:
  /// an open call-back plus a `callback` alert for the farmer's FA. Returns
  /// the open call-back (the existing one if there is one already).
  SnapCallback addCallback(String farmerId) {
    final f = _farmers[farmerId];
    final faId = f?.assignedFaId;
    if (f == null || faId == null) {
      throw ArgumentError.value(farmerId, 'farmerId', 'farmer without an FA');
    }
    final open = _callbacks.values
        .where((c) => c.farmerId == farmerId && c.isOpen)
        .firstOrNull;
    if (open != null) return open.snap();
    final c = _Callback(
      id: _newId(),
      farmerId: farmerId,
      faId: faId,
      requestedAt: _now,
    );
    _callbacks[c.id] = c;
    addAlert(
      kind: AlertKind.callback,
      title: '${f.name ?? f.phone} asked you to call',
      titleTe: '${f.nameTe ?? f.name ?? f.phone} మీకు కాల్ చేయమని అడిగారు',
      farmerId: farmerId,
      refId: c.id,
      faId: faId,
    );
    return c.snap();
  }

  /// Every farmer on the server (all FAs, all statuses).
  List<SnapFarmer> get serverFarmers => [
    for (final f in _farmers.values) f.snap(),
  ];

  /// Every plot on the server.
  List<SnapPlot> get serverPlots => [for (final p in _plots.values) p.snap()];

  /// Every season on the server.
  List<SnapSeason> get serverSeasons => [
    for (final s in _seasons.values) s.snap(),
  ];

  /// Every visit on the server (planned, done, cancelled), any age.
  List<SnapVisit> get serverVisits => [
    for (final v in _visits.values) v.snap(),
  ];

  /// Every call-back request, open or closed.
  List<SnapCallback> get serverCallbacks => [
    for (final c in _callbacks.values) c.snap(),
  ];

  /// The call-back requests still open.
  List<SnapCallback> get openCallbacks => [
    for (final c in _callbacks.values)
      if (c.isOpen) c.snap(),
  ];

  /// Every alert, any status.
  List<SnapAlert> get serverAlerts => [
    for (final a in _alerts.values) a.snap(),
  ];

  /// The farmer with [phone] (any common format), or null.
  SnapFarmer? farmerByPhone(String phone) {
    final e164 = normalizeIndianMobile(phone);
    return _farmers.values.where((f) => f.phone == e164).firstOrNull?.snap();
  }

  /// The FA assigned to [farmerId] (after merge aliases), or null.
  String? assignedFaOf(String farmerId) =>
      _farmers[_resolveAlias(farmerId)]?.assignedFaId;

  /// The territory version of [faId] (Suresh by default).
  int territoryVersion([String? faId]) =>
      _territoryVersions[faId ?? sureshId] ?? 1;

  /// The masters version.
  int get mastersVersion => _mastersVersion;

  /// The stored result of command [commandId], or null.
  CommandResult? storedResult(String commandId) => _commands[commandId]?.result;

  /// Objects PUT through the mock [PhotoUploader]: storage key -> bytes.
  Map<String, int> get uploadedObjects => Map.unmodifiable(_objects);

  // ---------------------------------------------------------------------------
  // State.

  static const _mastersVersion = 3;

  final _accounts = <String, _Account>{}; // FA ID ->
  final _farmers = <String, _Farmer>{};
  final _plots = <String, _Plot>{};
  final _seasons = <String, _Season>{};
  final _visits = <String, _Visit>{};
  final _callbacks = <String, _Callback>{};
  final _alerts = <String, _Alert>{};
  final _aliases = <String, String>{}; // phone farmer_id -> farmer ID
  final _commands = <String, _StoredCommand>{}; // command ID ->
  final _territoryVersions = <String, int>{}; // FA ID ->
  final _otps = <String, _OtpChallenge>{}; // "fa|phone" -> live code
  final _otpSends = <String, List<DateTime>>{}; // phone -> send times
  final _proofs = <String, _Proof>{}; // otp_proof ->
  final _lookups = <String, List<DateTime>>{}; // FA ID -> lookup times
  final _photoUrlRequests = <String, List<DateTime>>{}; // FA ID ->
  final _loginAttempts = <String, List<DateTime>>{}; // code ->
  final _passwordChanges = <String, List<DateTime>>{}; // FA ID ->
  final _access = <String, _MockToken>{};
  final _refresh = <String, String>{}; // live refresh token -> access token
  final _rotated = <String, _Rotation>{}; // used refresh token -> successor
  final _devices = <String, _Device>{}; // device key ->
  final _presigned = <String, _Presigned>{}; // upload URL ->
  final _objects = <String, int>{}; // storage key -> bytes

  final _revokedDevices = <String>{};
  bool _revokeNextDevice = false;
  final _expiredFamilies = <String>{};
  bool _expireNextFamily = false;
  bool _conflictArmed = false;
  bool _partialArmed = false;

  // ---------------------------------------------------------------------------
  // Call plumbing.

  /// Runs [body] the way a network call would: latency, then the scenario's
  /// failure, then the result. Errors are always [ApiError].
  Future<T> _call<T>(FutureOr<T> Function() body) async {
    final s = scenario;
    final delay = s == MockScenario.slowNetwork ? slowLatency : latency;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    switch (s) {
      case MockScenario.offline:
        throw const ApiError.network();
      case MockScenario.serverError:
        throw const ApiError(
          code: ApiErrorCode.unavailable,
          message: 'service unavailable (mock)',
          status: 503,
        );
      case MockScenario.normal ||
          MockScenario.slowNetwork ||
          MockScenario.deviceRemoved ||
          MockScenario.updateRequired ||
          MockScenario.syncConflict ||
          MockScenario.partialFailure ||
          MockScenario.sessionExpired:
        _markMissed();
        return body();
    }
  }

  /// The backend's hourly `visits.mark_missed` job, run before every call:
  /// a planned visit dated before today (IST) becomes `missed`, and its FA's
  /// territory version moves.
  void _markMissed() {
    final today = _today;
    final fas = <String>[];
    for (final v in _visits.values) {
      final day = v.plannedFor;
      if (v.status == VisitStatus.planned &&
          day != null &&
          day.isBefore(today)) {
        v.status = VisitStatus.missed;
        fas.add(v.faId);
      }
    }
    _bump(fas);
  }

  DateTime get _now => clock.now();

  LocalDate get _today => LocalDate.todayIst(clock);

  String _newId() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  static ApiError _validation(Map<String, String> fields) => ApiError(
    code: ApiErrorCode.validationFailed,
    message: 'validation failed',
    status: 400,
    details: {'fields': fields},
  );

  static ApiError _notFound(String entity) => ApiError(
    code: ApiErrorCode.notFound,
    message: '$entity not found',
    status: 404,
  );

  static ApiError _forbidden(String message) =>
      ApiError(code: ApiErrorCode.forbidden, message: message, status: 403);

  static ApiError _rateLimited(Duration retryAfter) => ApiError(
    code: ApiErrorCode.rateLimited,
    message: 'too many requests, try again later',
    status: 429,
    retryAfter: Duration(
      seconds: math.max(1, (retryAfter.inMilliseconds / 1000).ceil()),
    ),
  );

  static const _unauthorized = ApiError(
    code: ApiErrorCode.unauthorized,
    message: 'missing or invalid token',
    status: 401,
  );

  static const _sessionEnded = ApiError(
    code: ApiErrorCode.unauthorized,
    message: 'session has ended; sign in again',
    status: 401,
  );

  static const _deviceRevoked = ApiError(
    code: ApiErrorCode.deviceRevoked,
    message: 'this device was removed by HO',
    status: 401,
  );

  static const _badLogin = ApiError(
    code: ApiErrorCode.unauthorized,
    message: 'login ID or password is not correct',
    status: 401,
  );

  static const _tempExpired = ApiError(
    code: ApiErrorCode.tempPasswordExpired,
    message: 'your temporary password has expired; call HO for a new one',
    status: 401,
  );

  /// Counts a call in a sliding window; throws `rate_limited` when [max]
  /// calls already happened within [window].
  void _limit(
    Map<String, List<DateTime>> log,
    String key,
    int max,
    Duration window,
  ) {
    final now = _now;
    final times = log.putIfAbsent(key, () => [])
      ..removeWhere((t) => now.difference(t) >= window);
    if (times.length >= max) {
      throw _rateLimited(window - now.difference(times.first));
    }
    times.add(now);
  }

  static void _checkLimit(int? limit, int max) {
    if (limit != null && (limit < 1 || limit > max)) {
      throw _validation({'limit': 'must be between 1 and $max'});
    }
  }

  /// Keyset paging like the server (`backend/internal/platform/paging`):
  /// newest first on ([at], [id]), the cursor is base64url of
  /// `<unix-nanos>:<uuid>` (unpadded) after the last row returned. Only a
  /// malformed cursor is `invalid_cursor`.
  static CursorPage<T> _page<T>(
    Iterable<T> rows,
    int? limit,
    String? cursor,
    int defaultLimit, {
    required DateTime Function(T row) at,
    required String Function(T row) id,
  }) {
    int newestFirst(T a, T b) {
      final byTime = at(b).compareTo(at(a));
      return byTime != 0 ? byTime : id(b).compareTo(id(a));
    }

    final after = cursor == null || cursor.isEmpty
        ? null
        : _decodeCursor(cursor);
    final all = rows.toList()..sort(newestFirst);
    final from = after == null
        ? all
        : all.where((r) {
            final t = at(r);
            return t.isBefore(after.$1) ||
                (t.isAtSameMomentAs(after.$1) && id(r).compareTo(after.$2) < 0);
          }).toList();
    final size = limit ?? defaultLimit;
    final items = from.take(size).toList();
    return CursorPage(
      items: List.unmodifiable(items),
      nextCursor: from.length > size
          ? _encodeCursor(at(items.last), id(items.last))
          : null,
    );
  }

  static String _encodeCursor(DateTime at, String id) => base64Url
      .encode(utf8.encode('${at.microsecondsSinceEpoch * 1000}:$id'))
      .replaceAll('=', '');

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static final _rawBase64Url = RegExp(r'^[A-Za-z0-9_-]*$');

  static (DateTime, String) _decodeCursor(String cursor) {
    const invalid = ApiError(
      code: ApiErrorCode.invalidCursor,
      message: 'cursor is not valid',
      status: 400,
    );
    if (!_rawBase64Url.hasMatch(cursor) || cursor.length % 4 == 1) {
      throw invalid;
    }
    final String raw;
    try {
      raw = utf8.decode(base64Url.decode(base64Url.normalize(cursor)));
    } on FormatException {
      throw invalid;
    }
    final colon = raw.indexOf(':');
    final nanos = colon < 0 ? null : int.tryParse(raw.substring(0, colon));
    final id = colon < 0 ? '' : raw.substring(colon + 1).toLowerCase();
    const maxMicros = 8640000000000000;
    if (nanos == null || (nanos ~/ 1000).abs() > maxMicros) throw invalid;
    if (!_uuid.hasMatch(id)) throw invalid;
    return (
      DateTime.fromMicrosecondsSinceEpoch(nanos ~/ 1000, isUtc: true),
      id,
    );
  }

  /// Bumps the territory version of every FA in [faIds] (nulls ignored),
  /// like `territory.Bump`.
  void _bump(Iterable<String?> faIds) {
    for (final id in {...faIds.whereType<String>()}) {
      _territoryVersions[id] = (_territoryVersions[id] ?? 1) + 1;
    }
  }

  String _resolveAlias(String farmerId) => _aliases[farmerId] ?? farmerId;

  // ---------------------------------------------------------------------------
  // Auth.

  static final _deviceKeyPattern = RegExp(r'^[A-Za-z0-9._:-]{8,128}$');

  /// The FA whose access token the request sent ([session], read from the
  /// store when the request started), or the 401/403 the server gives.
  ///
  /// [allowMustChange] is set for the password change (a must-change token
  /// works only there); [heartbeat] lets a revoked device through so the
  /// heartbeat can answer `wipe: true`.
  _Principal _signedIn(
    StoredSession? session, {
    bool allowMustChange = false,
    bool heartbeat = false,
  }) {
    final token = session == null ? null : _access[session.tokens.accessToken];
    final account = token == null ? null : _accounts[token.faId];
    if (token == null || account == null) throw _unauthorized;
    final revoked = _revokedDevices.contains(token.deviceId);
    if (revoked && !heartbeat) throw _deviceRevoked;
    if (_expiredFamilies.contains(token.family)) throw _sessionEnded;
    if (token.mustChangePassword && !allowMustChange) {
      throw const ApiError(
        code: ApiErrorCode.passwordChangeRequired,
        message: 'set your own password first',
        status: 403,
      );
    }
    if (account.status == FaStatus.inactive) throw _sessionEnded;
    return _Principal(account, token, revoked: revoked);
  }

  Future<FaSession> _login(
    SessionStore store,
    String code,
    String password,
    DeviceInfo device,
  ) async {
    final login = code.trim().toUpperCase();
    final fields = <String, String>{
      if (login.isEmpty) 'code': 'required',
      if (password.isEmpty) 'password': 'required',
      if (!_deviceKeyPattern.hasMatch(device.deviceKey))
        'device.device_key': 'invalid',
    };
    if (fields.isNotEmpty) throw _validation(fields);
    _limit(_loginAttempts, login, 10, const Duration(minutes: 15));
    final account = _accounts.values.where((a) => a.code == login).firstOrNull;
    if (account == null ||
        account.password != password ||
        account.status == FaStatus.inactive) {
      throw _badLogin;
    }
    final now = _now;
    if (account.mustChangePassword &&
        account.tempPasswordExpiresAt != null &&
        !now.isBefore(account.tempPasswordExpiresAt!)) {
      throw _tempExpired;
    }
    final existing = _devices[device.deviceKey];
    if (existing != null && _revokedDevices.contains(existing.id)) {
      throw _deviceRevoked;
    }
    final d = existing ?? _Device(id: _newId(), key: device.deviceKey);
    _devices[device.deviceKey] = d;
    d
      ..faId = account.id
      ..model = device.model ?? d.model
      ..osVersion = device.osVersion ?? d.osVersion
      ..appVersion = device.appVersion ?? d.appVersion
      ..pushToken = device.pushToken ?? d.pushToken
      ..lastSeenAt = now;
    if (_revokeNextDevice) {
      _revokeNextDevice = false;
      _revokedDevices.add(d.id);
    }
    final previousLogin = account.lastLoginAt;
    account.lastLoginAt = now;
    final family = _newId();
    if (_expireNextFamily) {
      _expireNextFamily = false;
      _expiredFamilies.add(family);
    }
    final tokens = _issueTokens(account, d.id, family: family);
    final session = FaSession(
      tokens: tokens,
      deviceId: d.id,
      fieldAssistant: account.view(lastLoginAt: previousLogin),
      mustChangePassword: account.mustChangePassword,
      offlinePolicy: OfflinePolicy.standard,
    );
    await store.writeSession(StoredSession.fromLogin(session));
    await store.writeLastOnlineAt(now);
    return session;
  }

  TokenPair _issueTokens(
    _Account account,
    String deviceId, {
    required String family,
  }) {
    final access = 'mock-access-${_newId()}';
    final refresh = 'mock-refresh-${_newId()}';
    _access[access] = _MockToken(
      faId: account.id,
      deviceId: deviceId,
      refreshToken: refresh,
      family: family,
      mustChangePassword: account.mustChangePassword,
    );
    _refresh[refresh] = access;
    final now = _now;
    return TokenPair(
      accessToken: access,
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      refreshToken: refresh,
      refreshExpiresAt: now.add(const Duration(days: 30)),
    );
  }

  /// Rotation like the server (`identity/service_sessions.go`): each refresh
  /// token works once; a retry with the used token within [_refreshGrace]
  /// gets the same successor; any later reuse ends the whole session
  /// (`refresh_reused`). The new token carries the FA's current must-change
  /// flag, so a refresh after the password change gives a clean one.
  Future<TokenPair> _refreshSession(
    SessionStore store,
    StoredSession? session,
  ) async {
    final used = session?.tokens.refreshToken;
    final access = used == null ? null : _refresh[used];
    final token = access == null ? null : _access[access];
    final family = token?.family ?? _rotated[used]?.family;
    final deviceId = token?.deviceId ?? _rotated[used]?.deviceId;
    if (deviceId != null && _revokedDevices.contains(deviceId)) {
      throw _deviceRevoked;
    }
    if (family != null && _expiredFamilies.contains(family)) {
      throw _sessionEnded;
    }
    final TokenPair tokens;
    if (token != null) {
      final account = _accounts[token.faId];
      if (account == null || account.status == FaStatus.inactive) {
        throw _sessionEnded;
      }
      _refresh.remove(used);
      tokens = _issueTokens(account, token.deviceId, family: token.family);
      _rotated[used!] = _Rotation(tokens, _now, token.family, token.deviceId);
    } else if (_rotated[used] case final rotation?) {
      final replay =
          _refresh.containsKey(rotation.successor.refreshToken) &&
          _now.difference(rotation.at) <= _refreshGrace;
      if (!replay) {
        _revokeFamily(rotation.family);
        throw const ApiError(
          code: ApiErrorCode.refreshReused,
          message: 'this sign-in was used elsewhere; sign in again',
          status: 401,
        );
      }
      tokens = rotation.successor;
    } else {
      throw const ApiError(
        code: ApiErrorCode.unauthorized,
        message: 'invalid refresh token',
        status: 401,
      );
    }
    final mustChange =
        _access[tokens.accessToken]?.mustChangePassword ??
        session!.mustChangePassword;
    await store.writeSession(
      session!.withTokens(tokens, mustChangePassword: mustChange),
    );
    await store.writeLastOnlineAt(_now);
    return tokens;
  }

  /// Logout: ends the session's whole family, like the server.
  void _revoke(StoredSession? session) {
    if (session == null) return;
    final token = _access[session.tokens.accessToken];
    final family =
        token?.family ?? _rotated[session.tokens.refreshToken]?.family;
    if (family != null) _revokeFamily(family);
  }

  void _revokeFamily(String family) {
    _access.removeWhere((access, t) {
      if (t.family != family) return false;
      _refresh.remove(t.refreshToken);
      return true;
    });
    _rotated.removeWhere((_, r) => r.family == family);
  }

  void _changePassword(StoredSession? session, String current, String next) {
    final p = _signedIn(session, allowMustChange: true);
    final a = p.account;
    _limit(_passwordChanges, a.id, 5, const Duration(minutes: 15));
    if (current != a.password) {
      throw _validation({'current_password': 'is not correct'});
    }
    if (a.mustChangePassword &&
        a.tempPasswordExpiresAt != null &&
        !_now.isBefore(a.tempPasswordExpiresAt!)) {
      throw _tempExpired;
    }
    final String? why;
    if (next.length < 8 ||
        !RegExp('[A-Za-z]').hasMatch(next) ||
        !RegExp('[0-9]').hasMatch(next)) {
      why = 'must be at least 8 characters with a letter and a digit';
    } else if (next == current) {
      why = 'must be different from the current password';
    } else if (next.toLowerCase().contains(a.code.toLowerCase())) {
      why = 'must not contain your login ID or email';
    } else {
      why = null;
    }
    if (why != null) throw _validation({'new_password': why});
    a
      ..password = next
      ..mustChangePassword = false
      ..tempPasswordExpiresAt = null
      ..updatedAt = _now;
    // Signs out the FA's other sessions; this one keeps its flag until the
    // app refreshes.
    final others = {
      for (final t in _access.values)
        if (t.faId == a.id && t.family != p.token.family) t.family,
    };
    others.forEach(_revokeFamily);
  }

  DeviceStatus _heartbeat(
    StoredSession? session, {
    String? model,
    String? osVersion,
    String? appVersion,
    String? pushToken,
  }) {
    final p = _signedIn(session, heartbeat: true);
    final d = _devices.values
        .where((d) => d.id == p.token.deviceId)
        .firstOrNull;
    if (d == null) throw _notFound('device');
    d
      ..model = model ?? d.model
      ..osVersion = osVersion ?? d.osVersion
      ..appVersion = appVersion ?? d.appVersion
      ..pushToken = pushToken ?? d.pushToken
      ..lastSeenAt = _now;
    final min = _minVersion;
    return DeviceStatus(
      deviceId: d.id,
      wipe: p.revoked,
      serverTime: _now,
      minVersion: min,
      updateRequired: d.appVersion == null
          ? scenario == MockScenario.updateRequired
          : _versionBelow(d.appVersion!, min),
    );
  }

  String get _minVersion =>
      scenario == MockScenario.updateRequired ? '1.0.5' : '0.0.0';

  AppConfig get _appConfig {
    final update = scenario == MockScenario.updateRequired;
    return AppConfig(
      app: 'fa',
      minVersion: _minVersion,
      latestVersion: update ? '1.0.5' : '0.1.0',
      storeUrl: 'https://play.google.com/store/apps/details?id=com.shanmukhaagritec.orbit.fa',
      flags: const {'push': false, 'assisted_mode': false},
    );
  }

  /// True when dotted version [a] is below [b] (`0.9.0` < `0.10.0`).
  static bool _versionBelow(String a, String b) {
    List<int> parts(String v) => v
        .split(RegExp('[.+-]'))
        .take(3)
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final x = parts(a);
    final y = parts(b);
    for (var i = 0; i < math.max(x.length, y.length); i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d < 0;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Sync: snapshot and status.

  /// Farmers [faId] may act on: assigned to them, not deactivated.
  Iterable<_Farmer> _scopeFarmers(String faId) => _farmers.values.where(
    (f) => f.assignedFaId == faId && f.status != FarmerStatus.inactive,
  );

  Snapshot _snapshot(_Account fa) {
    final farmers = _scopeFarmers(fa.id).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final ids = {for (final f in farmers) f.id};
    final visits = <SnapVisit>[];
    final missedSince = _today.addDays(-snapshotMissedDays);
    for (final f in farmers) {
      final mine = _visits.values.where((v) => v.farmerId == f.id).toList();
      visits.addAll([
        for (final v in mine)
          if (v.status == VisitStatus.planned ||
              (v.status == VisitStatus.missed &&
                  v.plannedFor != null &&
                  !v.plannedFor!.isBefore(missedSince)))
            v.snap(),
      ]);
      final done = mine.where((v) => v.status == VisitStatus.done).toList()
        ..sort((a, b) => b.visitedAt!.compareTo(a.visitedAt!));
      visits.addAll(done.take(3).map((v) => v.snap()));
    }
    return Snapshot(
      territoryVersion: territoryVersion(fa.id),
      mastersVersion: _mastersVersion,
      generatedAt: _now,
      farmers: [for (final f in farmers) f.snap()],
      plots: [
        for (final p in _plots.values)
          if (ids.contains(p.farmerId)) p.snap(),
      ],
      seasons: [
        for (final s in _seasons.values)
          if (ids.contains(s.farmerId)) s.snap(),
      ],
      visits: visits,
      callbacks: [
        for (final c in _callbacks.values)
          if (c.isOpen && c.faId == fa.id && ids.contains(c.farmerId)) c.snap(),
      ],
      // messaging `ListSnapshotFAAlerts`: not closed, created in the last
      // 30 days, newest first, at most 200.
      alerts:
          ([
                for (final a in _alerts.values)
                  if (a.faId == fa.id &&
                      a.status != AlertStatus.closed &&
                      !a.createdAt.isBefore(
                        _now.subtract(const Duration(days: snapshotAlertDays)),
                      ))
                    a.snap(),
              ]..sort((a, b) {
                final c = b.createdAt.compareTo(a.createdAt);
                return c != 0 ? c : b.id.compareTo(a.id);
              }))
              .take(snapshotAlertLimit)
              .toList(),
      masters: _masters(),
      villages: [
        for (final v in _villages)
          if (fa.villageIds.contains(v.id)) v,
      ],
    );
  }

  SnapMasters _masters() => SnapMasters(
    version: _mastersVersion,
    seasonCodes: SnapSeasonCodes.fromSet(seasonCodesOn(_today)),
    crops: _crops,
    issues: _issues,
    salts: _salts,
    skus: _skus,
    rules: _rules,
  );

  SyncStatus _status(_Account fa) {
    final t = territoryVersion(fa.id);
    return SyncStatus(
      territoryVersion: t,
      mastersVersion: _mastersVersion,
      etag: Snapshot.snapshotEtag(t, _mastersVersion),
    );
  }

  // ---------------------------------------------------------------------------
  // Sync: commands (CONVENTIONS section 6).

  static const _maxBatch = 200;

  CommandBatchResult _submit(_Account fa, List<CommandIn> commands) {
    if (commands.isEmpty || commands.length > _maxBatch) {
      throw _validation({'commands': 'must have 1 to $_maxBatch items'});
    }
    int? stopAt;
    if (_partialArmed) {
      _partialArmed = false;
      stopAt = commands.length ~/ 2;
    }
    final results = <CommandResult>[];
    int? retryFrom;
    for (var i = 0; i < commands.length; i++) {
      if (i == stopAt) {
        retryFrom = i;
        break;
      }
      results.add(_runOne(fa, commands[i]));
    }
    if (retryFrom == null) fa.lastSyncAt = _now;
    return CommandBatchResult(
      results: results,
      retryFrom: retryFrom,
      territoryVersion: territoryVersion(fa.id),
      mastersVersion: _mastersVersion,
    );
  }

  /// The stored result for a known command ID, or the handler's result,
  /// stored. An applied or merged result bumps the FA's territory (the
  /// handler bumps any other FA it touched).
  CommandResult _runOne(_Account fa, CommandIn cmd) {
    final stored = _commands[cmd.id];
    if (stored != null) {
      if (stored.faId != fa.id) {
        return _rejected(
          cmd.id,
          null,
          'this command ID was already used by another field assistant',
        );
      }
      return stored.result;
    }
    final result = _dispatch(fa, cmd);
    _commands[cmd.id] = _StoredCommand(fa.id, result);
    if (result.status == CommandStatus.applied ||
        result.status == CommandStatus.merged) {
      _bump([fa.id]);
    }
    return result;
  }

  static CommandResult _applied(String commandId, String entityId) =>
      CommandResult(
        id: commandId,
        status: CommandStatus.applied,
        entityId: entityId,
      );

  static CommandResult _rejected(
    String commandId,
    String? entityId,
    String reason,
  ) => CommandResult(
    id: commandId,
    status: CommandStatus.rejected,
    entityId: entityId,
    error: reason,
  );

  static CommandResult _conflicted(
    String commandId,
    String entityId,
    Conflict conflict,
  ) => CommandResult(
    id: commandId,
    status: CommandStatus.conflict,
    entityId: entityId,
    conflict: conflict,
  );

  CommandResult _dispatch(_Account fa, CommandIn cmd) {
    final type = CommandType.fromWire(cmd.type);
    if (type == null) {
      return _rejected(cmd.id, null, 'unknown command type "${cmd.type}"');
    }
    final CommandPayload payload;
    try {
      payload = CommandPayload.decode(type, cmd.payload);
    } on FormatException catch (e) {
      return _rejected(cmd.id, null, 'invalid payload: ${e.message}');
    } on ArgumentError catch (e) {
      return _rejected(cmd.id, null, 'invalid payload: ${e.message}');
    }
    final c = _Cmd(cmd.id, fa);
    try {
      return switch (payload) {
        final EnrolFarmerPayload p => _enrolFarmer(c, p),
        final RecordConsentPayload p => _recordConsent(c, p),
        final SavePlotPayload p => _savePlot(c, p),
        final StartSeasonPayload p => _startSeason(c, p),
        final UpdateFarmerPayload p => _updateFarmer(c, p),
        final PlanVisitPayload p => _planVisit(c, p),
        final LogVisitPayload p => _logVisit(c, p),
        final CancelVisitPayload p => _cancelVisit(c, p),
        final CloseCallbackPayload p => _closeCallback(c, p),
        final AckAlertPayload p => _ackAlert(c, p),
      };
    } on _Rejection catch (r) {
      return _rejected(cmd.id, payload.entityId, r.reason);
    }
  }

  /// The farmer [id] (after merge aliases) if [fa] may act on them
  /// (`lockFarmerForFA` / `faMayActOn`).
  _Farmer _farmerForFa(_Account fa, String id) {
    final f = _farmers[_resolveAlias(id)];
    if (f == null) throw const _Rejection('farmer not found');
    if (f.status == FarmerStatus.inactive) {
      throw const _Rejection('this farmer was deactivated by HO');
    }
    if (f.assignedFaId != fa.id) {
      throw const _Rejection('this farmer is not assigned to you');
    }
    return f;
  }

  SnapVillage? _village(String id) =>
      _villages.where((v) => v.id == id).firstOrNull;

  /// A verified consent proof for [fa] and [phone], or null.
  _Proof? _validProof(_Account fa, String phone, String? token) {
    if (token == null || token.trim().isEmpty) return null;
    final p = _proofs[token];
    if (p == null || p.faId != fa.id || p.phone != phone) return null;
    if (!_now.isBefore(p.expiresAt)) return null;
    return p;
  }

  static final _photoKeyPattern = RegExp(
    r'^farmers/([0-9a-f-]{36})/photo-[0-9a-f-]{36}\.(jpg|png|webp)$',
  );

  static bool _photoKeyFor(String key, Iterable<String> farmerIds) {
    final m = _photoKeyPattern.firstMatch(key);
    return m != null && farmerIds.contains(m.group(1));
  }

  static String _fieldErrors(Map<String, String> fields) =>
      (fields.entries.map((e) => '${e.key}: ${e.value}').toList()..sort()).join(
        '; ',
      );

  CommandResult _enrolFarmer(_Cmd c, EnrolFarmerPayload p) {
    final fields = <String, String>{};
    final phone = normalizeIndianMobile(p.phone);
    if (phone == null) fields['phone'] = 'not a valid Indian mobile number';
    final name = p.name.trim();
    if (name.isEmpty || _bytes(name) > 100) {
      fields['name'] = 'must be 1-100 characters';
    }
    final proofToken = p.consent.hasProof ? p.consent.otpProof : null;
    if (proofToken != null) {
      if (!p.consent.purposes.contains(ConsentPurpose.programme)) {
        fields['consent.purposes'] = 'programme consent is required';
      }
      if (p.consent.noticeVersion.trim().isEmpty) {
        fields['consent.notice_version'] = 'required';
      }
    }
    if (fields.isNotEmpty) throw _Rejection(_fieldErrors(fields));
    final village = _village(p.villageId);
    if (village == null) throw const _Rejection('village_id: unknown village');
    final fa = c.fa;
    final proof = _validProof(fa, phone!, proofToken);
    // A photo key outside this farmer's prefix is dropped, not fatal.
    final photoKey =
        p.photoKey != null && _photoKeyFor(p.photoKey!, [p.farmerId])
        ? p.photoKey
        : null;
    final now = _now;

    final existing = _farmers.values.where((f) => f.phone == phone).firstOrNull;
    if (existing == null) {
      if (_farmers.containsKey(p.farmerId) ||
          _aliases.containsKey(p.farmerId)) {
        throw const _Rejection(
          'farmer_id: already used for another phone number',
        );
      }
      // Stricter than the backend today (which only checks the area when
      // merging into an unassigned farmer): a new farmer must live in the
      // FA's area too.
      if (!fa.villageIds.contains(village.id)) {
        return _rejected(c.id, p.farmerId, ApiErrorCode.notInYourArea);
      }
      final f = _Farmer(
        id: p.farmerId,
        phone: phone,
        name: name,
        nameTe: _trimmed(p.nameTe),
        language: p.language,
        villageId: village.id,
        assignedFaId: fa.id,
        source: FarmerSource.fa,
        photoKey: photoKey,
        plan: Plan.free,
        status: FarmerStatus.active,
        profileCompletedAt: now,
        createdAt: now,
      )..lastCommandId = c.id;
      _farmers[f.id] = f;
      if (proof != null) f.grant(p.consent.purposes);
      return _applied(c.id, f.id);
    }

    // The phone is known: merge if this FA may claim the farmer.
    if (existing.status == FarmerStatus.inactive) {
      throw const _Rejection(
        'phone: this farmer was deactivated by HO; ask HO to reactivate',
      );
    }
    final assigned = existing.assignedFaId;
    if (assigned != null && assigned != fa.id) {
      return _rejected(c.id, p.farmerId, ApiErrorCode.registeredWithAnotherFa);
    }
    if (assigned == null &&
        !fa.villageIds.contains(existing.villageId ?? village.id)) {
      return _rejected(c.id, p.farmerId, ApiErrorCode.notInYourArea);
    }
    final f = existing
      ..name ??= name
      ..nameTe ??= _trimmed(p.nameTe)
      ..villageId ??= village.id
      ..photoKey ??= photoKey
      ..assignedFaId ??= fa.id;
    if (f.status == FarmerStatus.pendingProfile) {
      f
        ..language = p.language
        ..status = FarmerStatus.active
        ..profileCompletedAt = now;
    }
    f
      ..version += 1
      ..updatedAt = now
      ..lastCommandId = c.id;
    if (p.farmerId != f.id) _aliases[p.farmerId] = f.id;
    if (proof != null) f.grant(p.consent.purposes);
    // The new-farmer alert has done its job.
    for (final a in _alerts.values) {
      if (a.farmerId == f.id &&
          a.kind == AlertKind.newFarmer &&
          a.status != AlertStatus.closed) {
        a.status = AlertStatus.closed;
      }
    }
    if (p.farmerId == f.id) return _applied(c.id, f.id);
    return CommandResult(
      id: c.id,
      status: CommandStatus.merged,
      entityId: p.farmerId,
      mergedInto: f.id,
    );
  }

  CommandResult _recordConsent(_Cmd c, RecordConsentPayload p) {
    final fields = <String, String>{
      if (p.purposes.isEmpty) 'purposes': 'required',
      if (p.noticeVersion.trim().isEmpty) 'notice_version': 'required',
      if (p.otpProof.trim().isEmpty) 'otp_proof': 'required',
    };
    if (fields.isNotEmpty) throw _Rejection(_fieldErrors(fields));
    final proof = _proofs[p.otpProof];
    if (proof == null || !_now.isBefore(proof.expiresAt)) {
      throw const _Rejection(
        'otp_proof: the consent proof is not valid or has expired',
      );
    }
    if (proof.faId != c.fa.id) {
      throw const _Rejection(
        'otp_proof: the consent OTP was verified by another FA',
      );
    }
    final f = _farmerForFa(c.fa, p.farmerId);
    if (proof.phone != f.phone) {
      throw const _Rejection(
        'otp_proof: the consent OTP was sent to another phone number',
      );
    }
    f
      ..grant(p.purposes)
      ..updatedAt = _now;
    return _applied(c.id, f.id);
  }

  CommandResult _savePlot(_Cmd c, SavePlotPayload p) {
    final label = p.label.trim();
    if (label.isEmpty || _bytes(label) > 60) {
      throw const _Rejection('label: must be 1-60 characters');
    }
    final pin = p.pin;
    if (pin != null &&
        (pin.lat < -90 || pin.lat > 90 || pin.lng < -180 || pin.lng > 180)) {
      throw const _Rejection('pin: lat must be within ±90 and lng within ±180');
    }
    final boundary = p.boundaryGeoJson;
    if (boundary == null && pin == null) {
      throw const _Rejection('pin: a boundary or a pin is required');
    }
    final gps = p.gpsAccuracyM;
    if (gps != null && (gps < 0 || gps > 9999)) {
      throw const _Rejection('gps_accuracy_m: must be between 0 and 9999');
    }
    var area = p.areaAcres;
    if (boundary != null) {
      // The backend's MeasureBoundary: GeoJSON parse, Polygon, ST_IsValid,
      // then the area.
      final ring = _polygonRing(boundary);
      if (ring == null) {
        throw const _Rejection('boundary_geojson: not a valid GeoJSON polygon');
      }
      if (ring.isEmpty) {
        throw const _Rejection('boundary_geojson: must be a Polygon');
      }
      if (!_isSimpleRing(ring)) {
        throw const _Rejection(
          'boundary_geojson: boundary crosses itself; walk it again',
        );
      }
      final measured = _polygonAcres(boundary);
      if (measured == null) {
        throw const _Rejection('boundary_geojson: must be a Polygon');
      }
      if (p.areaSource == AreaSource.boundary) {
        area = (measured * 1000).round() / 1000;
      }
    } else if (p.areaSource == AreaSource.boundary) {
      throw const _Rejection(
        'area_source: boundary needs a boundary_geojson; use typed with a pin',
      );
    }
    if (area <= 0 || area > 10000) {
      throw const _Rejection(
        'area_acres: must be more than 0 and at most 10000',
      );
    }
    final f = _farmerForFa(c.fa, p.farmerId);
    final now = _now;
    final existing = _plots[p.plotId];
    if (existing == null) {
      _plots[p.plotId] = _Plot(
        id: p.plotId,
        farmerId: f.id,
        label: label,
        villageId: f.villageId,
        boundaryGeoJson: boundary,
        pin: pin,
        areaAcres: area,
        areaSource: p.areaSource,
        gpsAccuracyM: gps,
        updatedAt: now,
      )..lastCommandId = c.id;
      return _applied(c.id, p.plotId);
    }
    if (existing.farmerId != f.id) {
      throw const _Rejection('plot_id: belongs to another farmer');
    }
    if (existing.lastCommandId == c.id) return _applied(c.id, p.plotId);
    if (_conflictArmed && existing.id == padmaPlot2Id) {
      _conflictArmed = false;
      hoEditPlot(existing.id, areaAcres: 2);
    }
    final expected = p.expectedVersion ?? 1;
    if (expected != existing.version) {
      final Conflict conflict;
      if (area != existing.areaAcres) {
        conflict = Conflict(
          field: 'area_acres',
          yours: area,
          theirs: existing.areaAcres,
        );
      } else if (label != existing.label) {
        conflict = Conflict(
          field: 'label',
          yours: label,
          theirs: existing.label,
        );
      } else if ((boundary != null) != (existing.boundaryGeoJson != null)) {
        conflict = Conflict(
          field: 'boundary',
          yours: boundary != null,
          theirs: existing.boundaryGeoJson != null,
        );
      } else {
        conflict = Conflict(
          field: 'version',
          yours: expected,
          theirs: existing.version,
        );
      }
      return _conflicted(c.id, p.plotId, conflict);
    }
    existing
      ..label = label
      ..boundaryGeoJson = boundary
      ..pin = pin
      ..areaAcres = area
      ..areaSource = p.areaSource
      ..gpsAccuracyM = gps
      ..version += 1
      ..updatedAt = now
      ..lastCommandId = c.id;
    return _applied(c.id, p.plotId);
  }

  CommandResult _startSeason(_Cmd c, StartSeasonPayload p) {
    if (!SeasonCode.isValid(p.seasonCode)) {
      throw const _Rejection('season_code: must look like kharif-2026');
    }
    if (!_crops.any((cr) => cr.id == p.cropId)) {
      throw const _Rejection('crop_id: unknown crop');
    }
    final f = _farmerForFa(c.fa, p.farmerId);
    final existing = _seasons[p.seasonId];
    if (existing != null) {
      if (existing.lastCommandId == c.id ||
          (existing.plotId == p.plotId && existing.farmerId == f.id)) {
        return _applied(c.id, p.seasonId);
      }
      throw const _Rejection('season_id: already used for another plot');
    }
    final plot = _plots[p.plotId];
    if (plot == null || plot.farmerId != f.id) {
      throw const _Rejection('plot not found');
    }
    final active = _seasons.values
        .where((s) => s.plotId == p.plotId && s.status == SeasonStatus.active)
        .firstOrNull;
    if (active != null) {
      return _conflicted(
        c.id,
        p.seasonId,
        Conflict(
          field: 'active_season',
          yours: {'season_code': p.seasonCode, 'crop_id': p.cropId},
          theirs: {
            'season_id': active.id,
            'season_code': active.seasonCode,
            'crop_id': active.cropId,
          },
        ),
      );
    }
    _seasons[p.seasonId] = _Season(
      id: p.seasonId,
      farmerId: f.id,
      plotId: p.plotId,
      seasonCode: p.seasonCode,
      cropId: p.cropId,
      sowingDate: p.sowingDate,
      previousCropId: p.previousCropId,
      status: SeasonStatus.active,
      updatedAt: _now,
    )..lastCommandId = c.id;
    return _applied(c.id, p.seasonId);
  }

  CommandResult _updateFarmer(_Cmd c, UpdateFarmerPayload p) {
    final fl = p.fields;
    if (fl.isEmpty) throw const _Rejection('fields: nothing to change');
    final fields = <String, String>{
      // `validateProfile`: Go len() counts UTF-8 bytes, so 100 bytes is about
      // 33 Telugu letters.
      if (fl.name != null &&
          (fl.name!.trim().isEmpty || _bytes(fl.name!) > 100))
        'name': 'must be 1-100 characters',
      if (fl.nameTe != null &&
          (fl.nameTe!.trim().isEmpty || _bytes(fl.nameTe!) > 300))
        'name_te': 'must not be blank',
    };
    if (fields.isNotEmpty) throw _Rejection(_fieldErrors(fields));
    if (fl.villageId != null && _village(fl.villageId!) == null) {
      throw const _Rejection('village_id: unknown village');
    }
    final f = _farmerForFa(c.fa, p.farmerId);
    if (f.lastCommandId == c.id) return _applied(c.id, f.id);
    if (fl.photoKey != null &&
        !_photoKeyFor(fl.photoKey!, {p.farmerId, f.id})) {
      throw const _Rejection(
        "photo_key: must be a key from this farmer's photo upload URL",
      );
    }
    if (_conflictArmed && f.id == padmaId) {
      _conflictArmed = false;
      _hoEditFarmer(f, fl);
    }
    if (f.version != p.expectedVersion) {
      final conflict = _farmerConflict(f, fl);
      if (conflict == null) return _applied(c.id, f.id);
      return _conflicted(c.id, f.id, conflict);
    }
    if (fl.name != null) f.name = fl.name!.trim();
    if (fl.nameTe != null) f.nameTe = _trimmed(fl.nameTe);
    if (fl.language != null) f.language = fl.language!;
    if (fl.villageId != null) f.villageId = fl.villageId;
    if (fl.photoKey != null) f.photoKey = fl.photoKey;
    f
      ..version += 1
      ..updatedAt = _now
      ..lastCommandId = c.id;
    return _applied(c.id, f.id);
  }

  /// HO changes the first field [fl] touches to another value (the
  /// [MockScenario.syncConflict] case for Padma S).
  void _hoEditFarmer(_Farmer f, UpdateFarmerFields fl) {
    if (fl.name != null) {
      f.name = '${fl.name!.trim()} (HO)';
    } else if (fl.nameTe != null) {
      f.nameTe = '${fl.nameTe!.trim()} (HO)';
    } else if (fl.language != null) {
      f.language = fl.language == Language.te ? Language.en : Language.te;
    } else if (fl.villageId != null) {
      f.villageId = fl.villageId == kondapurId ? gachibowliId : kondapurId;
    } else {
      f.photoKey = null;
    }
    f
      ..version += 1
      ..updatedAt = _now
      ..lastCommandId = null;
    _bump([f.assignedFaId]);
  }

  /// The first changed field whose server value differs from the FA's, or
  /// null when the server already has every value (`farmerConflict`).
  static Conflict? _farmerConflict(_Farmer f, UpdateFarmerFields fl) {
    if (fl.name != null && fl.name!.trim() != (f.name ?? '')) {
      return Conflict(field: 'name', yours: fl.name!.trim(), theirs: f.name);
    }
    if (fl.nameTe != null && fl.nameTe!.trim() != (f.nameTe ?? '')) {
      return Conflict(
        field: 'name_te',
        yours: fl.nameTe!.trim(),
        theirs: f.nameTe,
      );
    }
    if (fl.language != null && fl.language != f.language) {
      return Conflict(
        field: 'language',
        yours: fl.language!.wire,
        theirs: f.language.wire,
      );
    }
    if (fl.villageId != null && fl.villageId != f.villageId) {
      return Conflict(
        field: 'village_id',
        yours: fl.villageId,
        theirs: f.villageId,
      );
    }
    if (fl.photoKey != null && fl.photoKey != f.photoKey) {
      return Conflict(
        field: 'photo_key',
        yours: fl.photoKey,
        theirs: f.photoKey,
      );
    }
    return null;
  }

  /// The season [seasonId] if it belongs to [farmerId] and [plotId].
  void _checkSeason(String farmerId, String plotId, String seasonId) {
    final s = _seasons[seasonId];
    if (s == null || s.farmerId != farmerId || s.plotId != plotId) {
      throw const _Rejection(
        'season does not exist or does not belong to this farmer and plot',
      );
    }
  }

  CommandResult _planVisit(_Cmd c, PlanVisitPayload p) {
    final f = _farmerForFa(c.fa, p.farmerId);
    _checkSeason(f.id, p.plotId, p.seasonId);
    final cur = _visits[p.visitId];
    if (cur != null) {
      if (cur.faId != c.fa.id) {
        throw const _Rejection('visit belongs to another field assistant');
      }
      if (cur.farmerId != f.id ||
          cur.plotId != p.plotId ||
          cur.seasonId != p.seasonId) {
        throw const _Rejection(
          'visit_id is already used for a different farmer, plot or season',
        );
      }
      switch (cur.status) {
        case VisitStatus.done:
          throw const _Rejection('visit is already logged');
        case VisitStatus.cancelled:
          throw const _Rejection('visit was cancelled; plan a new one');
        case VisitStatus.planned || VisitStatus.missed || VisitStatus.unknown:
          break;
      }
      cur
        ..status = VisitStatus.planned
        ..plannedFor = p.plannedFor
        ..plannedSlot = p.plannedSlot
        ..purpose = p.purpose;
      return _applied(c.id, p.visitId);
    }
    _visits[p.visitId] = _Visit(
      id: p.visitId,
      farmerId: f.id,
      plotId: p.plotId,
      seasonId: p.seasonId,
      faId: c.fa.id,
      status: VisitStatus.planned,
      plannedFor: p.plannedFor,
      plannedSlot: p.plannedSlot,
      purpose: p.purpose,
    );
    return _applied(c.id, p.visitId);
  }

  CommandResult _logVisit(_Cmd c, LogVisitPayload p) {
    final now = _now;
    if (p.visitedAt.isAfter(now.add(const Duration(minutes: 15)))) {
      throw const _Rejection('visited_at is in the future');
    }
    final loc = p.location;
    if (loc != null &&
        (loc.lat < -90 || loc.lat > 90 || loc.lng < -180 || loc.lng > 180)) {
      throw const _Rejection('location is out of range');
    }
    if (p.issues.length > LogVisitPayload.maxIssues ||
        p.photos.length > LogVisitPayload.maxPhotos) {
      throw const _Rejection('at most 20 issues and 20 photos per visit');
    }
    final seen = <String>{};
    for (final i in p.issues) {
      if (!seen.add(i.issueVisitId)) {
        throw _Rejection('duplicate issue_visit_id ${i.issueVisitId}');
      }
    }
    for (final ph in p.photos) {
      if (!seen.add(ph.photoId)) {
        throw _Rejection('duplicate photo_id ${ph.photoId}');
      }
    }
    final next = p.nextVisit;
    if (next != null && next.visitId == p.visitId) {
      throw const _Rejection('next_visit.visit_id must be a new visit ID');
    }
    final cur = _visits[p.visitId];
    if (cur != null &&
        cur.status == VisitStatus.done &&
        cur.faId == c.fa.id &&
        cur.plotId == p.plotId &&
        cur.seasonId == p.seasonId) {
      return _applied(c.id, p.visitId);
    }
    final f = _farmerForFa(c.fa, p.farmerId);
    _checkSeason(f.id, p.plotId, p.seasonId);
    if (cur != null) {
      if (cur.faId != c.fa.id && cur.status == VisitStatus.done) {
        throw const _Rejection('visit was logged by another field assistant');
      }
      if (cur.farmerId != f.id ||
          cur.plotId != p.plotId ||
          cur.seasonId != p.seasonId) {
        throw const _Rejection(
          'visit_id is already used for a different farmer, plot or season',
        );
      }
    }
    final SnapStage? stage;
    if (p.stageId == null) {
      stage = null;
    } else {
      stage = _stageById(p.stageId!);
      if (stage == null) throw const _Rejection('unknown crop stage');
    }
    for (final i in p.issues) {
      if (!_issues.any((m) => m.id == i.issueId)) {
        throw const _Rejection('unknown issue');
      }
      if (_visits.values.any(
        (v) => v.id != p.visitId && v.issues.any((x) => x.id == i.issueVisitId),
      )) {
        throw const _Rejection(
          'issue_visit_id is already used by another visit; send a new ID',
        );
      }
    }
    if (next != null) {
      final nv = _visits[next.visitId];
      if (nv != null && nv.farmerId != f.id) {
        throw const _Rejection(
          'next_visit.visit_id is already used for a different farmer',
        );
      }
    }
    final v =
        cur ??
        _Visit(
          id: p.visitId,
          farmerId: f.id,
          plotId: p.plotId,
          seasonId: p.seasonId,
          faId: c.fa.id,
          status: VisitStatus.done,
        );
    v
      ..faId = c.fa.id
      ..status = VisitStatus.done
      ..visitedAt = p.visitedAt.toUtc()
      ..location = loc
      ..farmerPresent = p.farmerPresent
      ..stageId = stage?.id
      ..stageName = stage?.name
      ..stageNameTe = stage?.nameTe
      ..notes = p.notes
      ..issues = [
        for (final i in p.issues)
          _visitIssue(
            i.issueVisitId,
            i.issueId,
            i.severity,
            ruleId: i.advisoryRuleId,
          ),
      ];
    for (final ph in p.photos) {
      v.photos[ph.photoId] = _VisitPhoto(
        ph.contentType,
        _visitPhotoKey(v.id, ph.photoId, ph.contentType),
      );
    }
    _visits[v.id] = v;
    if (next != null && !_visits.containsKey(next.visitId)) {
      _visits[next.visitId] = _Visit(
        id: next.visitId,
        farmerId: f.id,
        plotId: p.plotId,
        seasonId: p.seasonId,
        faId: c.fa.id,
        status: VisitStatus.planned,
        plannedFor: next.plannedFor,
        plannedSlot: next.plannedSlot,
      );
    }
    // A logged visit closes the farmer's open call-back.
    for (final cb in _callbacks.values) {
      if (cb.farmerId == f.id && cb.isOpen) {
        _closeCallbackRow(cb, 'closed by visit ${v.id}');
        _bump([cb.faId]);
      }
    }
    return _applied(c.id, v.id);
  }

  static String _visitPhotoKey(
    String visitId,
    String photoId,
    PhotoContentType type,
  ) => 'visits/$visitId/$photoId.${_ext(type)}';

  static String _ext(PhotoContentType type) => switch (type) {
    PhotoContentType.png => 'png',
    PhotoContentType.webp => 'webp',
    PhotoContentType.jpeg || PhotoContentType.unknown => 'jpg',
  };

  CommandResult _cancelVisit(_Cmd c, CancelVisitPayload p) {
    final cur = _visits[p.visitId];
    if (cur == null) throw const _Rejection('visit not found');
    if (cur.faId != c.fa.id) {
      throw const _Rejection('visit belongs to another field assistant');
    }
    switch (cur.status) {
      case VisitStatus.cancelled:
        return _applied(c.id, cur.id);
      case VisitStatus.done:
        throw const _Rejection(
          'visit is already logged and cannot be cancelled',
        );
      case VisitStatus.planned || VisitStatus.missed || VisitStatus.unknown:
        cur.status = VisitStatus.cancelled;
        return _applied(c.id, cur.id);
    }
  }

  CommandResult _closeCallback(_Cmd c, CloseCallbackPayload p) {
    final cb = _callbacks[p.callbackId];
    if (cb == null) throw const _Rejection('call-back request not found');
    if (cb.faId != c.fa.id) {
      throw const _Rejection(
        'call-back request is assigned to another field assistant',
      );
    }
    if (cb.isOpen) _closeCallbackRow(cb, p.note);
    return _applied(c.id, cb.id);
  }

  void _closeCallbackRow(_Callback cb, String? note) {
    cb
      ..isOpen = false
      ..closedAt = _now
      ..note = note;
    for (final a in _alerts.values) {
      if (a.kind == AlertKind.callback &&
          a.refId == cb.id &&
          a.status != AlertStatus.closed) {
        a.status = AlertStatus.closed;
      }
    }
  }

  CommandResult _ackAlert(_Cmd c, AckAlertPayload p) {
    final a = _alerts[p.alertId];
    if (a == null || a.faId != c.fa.id) {
      throw const _Rejection('alert not found');
    }
    if (a.status == AlertStatus.open) {
      a
        ..status = AlertStatus.acknowledged
        ..acknowledgedAt = _now;
    }
    return _applied(c.id, a.id);
  }

  // ---------------------------------------------------------------------------
  // Enrolment: lookup, consent OTP, farmer photo.

  PhoneLookup _lookup(_Account fa, String phone) {
    final e164 = normalizeIndianMobile(phone);
    if (e164 == null) {
      throw _validation({'phone': 'not a valid Indian mobile number'});
    }
    _limit(_lookups, fa.id, 60, const Duration(hours: 1));
    final f = _farmers.values.where((f) => f.phone == e164).firstOrNull;
    if (f == null) {
      return const PhoneLookup(status: PhoneLookupStatus.newFarmer);
    }
    if (f.status == FarmerStatus.inactive) {
      return const PhoneLookup(status: PhoneLookupStatus.deactivated);
    }
    if (f.assignedFaId == fa.id) {
      return PhoneLookup(status: PhoneLookupStatus.mine, farmerId: f.id);
    }
    if (f.assignedFaId != null) {
      return const PhoneLookup(status: PhoneLookupStatus.otherFa);
    }
    final inArea = f.villageId == null || fa.villageIds.contains(f.villageId);
    return inArea
        ? PhoneLookup(
            status: PhoneLookupStatus.unassignedInMyArea,
            farmerId: f.id,
          )
        : const PhoneLookup(status: PhoneLookupStatus.outsideMyArea);
  }

  static const _otpTtl = Duration(minutes: 10);
  static const _otpResendAfter = Duration(seconds: 30);
  static const _otpSendsPerHour = 5;
  static const _proofTtl = Duration(days: 7);
  static const _refreshGrace = Duration(seconds: 60);

  OtpSent _requestConsentOtp(_Account fa, String phone, Language language) {
    final e164 = normalizeIndianMobile(phone);
    if (e164 == null) {
      throw _validation({'phone': 'not a valid Indian mobile number'});
    }
    final now = _now;
    final sends = _otpSends.putIfAbsent(e164, () => [])
      ..removeWhere((t) => now.difference(t) >= const Duration(hours: 1));
    if (sends.isNotEmpty) {
      final gap = now.difference(sends.last);
      if (gap < _otpResendAfter) throw _rateLimited(_otpResendAfter - gap);
    }
    if (sends.length >= _otpSendsPerHour) {
      throw _rateLimited(
        const Duration(hours: 1) - now.difference(sends.first),
      );
    }
    sends.add(now);
    _otps['${fa.id}|$e164'] = _OtpChallenge(
      code: fixedOtp,
      language: language,
      expiresAt: now.add(_otpTtl),
    );
    return OtpSent(
      phoneMasked: maskPhone(e164),
      expiresIn: _otpTtl,
      resendAfter: _otpResendAfter,
    );
  }

  ConsentProof _verifyConsentOtp(_Account fa, String phone, String code) {
    final e164 = normalizeIndianMobile(phone);
    final fields = <String, String>{
      if (e164 == null) 'phone': 'not a valid Indian mobile number',
      if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) 'code': 'must be 6 digits',
    };
    if (fields.isNotEmpty) throw _validation(fields);
    final key = '${fa.id}|$e164';
    final challenge = _otps[key];
    final now = _now;
    if (challenge == null ||
        !now.isBefore(challenge.expiresAt) ||
        challenge.attemptsLeft <= 0) {
      throw const ApiError(
        code: ApiErrorCode.otpExpired,
        message: 'this code has expired; ask for a new one',
        status: 400,
      );
    }
    if (code != challenge.code) {
      challenge.attemptsLeft--;
      throw ApiError(
        code: ApiErrorCode.otpInvalid,
        message: 'the code is wrong',
        status: 400,
        details: {'attempts_left': challenge.attemptsLeft},
      );
    }
    _otps.remove(key);
    final token = 'mock-consent-proof-${_newId()}';
    final proof = _Proof(
      faId: fa.id,
      phone: e164!,
      verifiedAt: now,
      expiresAt: now.add(_proofTtl),
    );
    _proofs[token] = proof;
    return ConsentProof(
      phone: e164,
      otpProof: token,
      verifiedAt: now,
      expiresAt: proof.expiresAt,
    );
  }

  _Presigned _presign(String key, PhotoContentType type, int bytes) {
    final now = _now;
    final p = _Presigned(
      url: 'https://$mockHost/upload/$key?sig=${_newId()}',
      storageKey: key,
      contentType: type,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    _presigned[p.url] = p;
    return p;
  }

  FarmerPhotoUpload _farmerPhotoUpload(
    _Account fa,
    String farmerId,
    PhotoContentType type,
    int bytes,
  ) {
    final fields = <String, String>{
      if (type == PhotoContentType.unknown)
        'content_type': 'must be image/jpeg, image/png or image/webp',
      if (bytes < 1 || bytes > 5 * 1024 * 1024)
        'bytes': 'must be between 1 byte and 5 MB',
    };
    if (fields.isNotEmpty) throw _validation(fields);
    final f = _farmers[_resolveAlias(farmerId)];
    // An unassigned self sign-up is about to be enrolled by this FA: their
    // photo goes up before the EnrolFarmer command lands.
    if (f != null && f.assignedFaId != null && f.assignedFaId != fa.id) {
      throw _forbidden('this farmer is not assigned to you');
    }
    _limit(_photoUrlRequests, fa.id, 120, const Duration(hours: 1));
    final key = 'farmers/$farmerId/photo-${_newId()}.${_ext(type)}';
    final p = _presign(key, type, bytes);
    return FarmerPhotoUpload(
      storageKey: key,
      url: p.url,
      method: 'PUT',
      headers: {'Content-Type': type.wire},
      expiresAt: p.expiresAt,
    );
  }

  (_Visit, _VisitPhoto) _visitPhoto(
    _Account fa,
    String visitId,
    String photoId,
  ) {
    // visits `photoForFA`: the visit, then its FA, then the photo row that
    // LogVisit stored (any other photo ID is 404 until the log syncs).
    final v = _visits[visitId];
    if (v == null) throw _notFound('visit');
    if (v.faId != fa.id) {
      throw _forbidden(
        'only the field assistant who logged this visit can upload its photos',
      );
    }
    final ph = v.photos[photoId];
    if (ph == null) {
      throw const ApiError(
        code: ApiErrorCode.notFound,
        message: 'photo not found; sync the visit log first',
        status: 404,
      );
    }
    return (v, ph);
  }

  VisitPhotoUpload _visitPhotoUpload(
    _Account fa,
    String visitId,
    String photoId,
    PhotoContentType type,
    int bytes,
  ) {
    final (_, ph) = _visitPhoto(fa, visitId, photoId);
    final fields = <String, String>{
      if (type != ph.contentType)
        'content_type':
            'must match the LogVisit photo (${ph.contentType.wire})',
      if (bytes < 1 || bytes > 10 * 1024 * 1024)
        'bytes': 'must be between 1 byte and 10 MB',
    };
    if (fields.isNotEmpty) throw _validation(fields);
    if (ph.uploadedAt != null) {
      throw const ApiError(
        code: ApiErrorCode.photoAlreadyUploaded,
        message: 'this photo is already uploaded',
        status: 409,
      );
    }
    final p = _presign(ph.storageKey, type, bytes);
    return VisitPhotoUpload(
      photoId: photoId,
      storageKey: ph.storageKey,
      url: p.url,
      method: 'PUT',
      headers: {'Content-Type': type.wire},
      expiresAt: p.expiresAt,
    );
  }

  VisitPhoto _confirmVisitPhoto(
    _Account fa,
    String visitId,
    String photoId,
    String? sha256,
  ) {
    if (sha256 != null && !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw _validation({'sha256': 'must be 64 lowercase hex digits'});
    }
    final (v, ph) = _visitPhoto(fa, visitId, photoId);
    if (ph.uploadedAt == null) {
      final bytes = _objects[ph.storageKey];
      if (bytes == null) {
        throw const ApiError(
          code: ApiErrorCode.uploadMissing,
          message: 'the photo is not in storage; upload it again',
          status: 409,
        );
      }
      ph
        ..uploadedAt = _now
        ..bytes = bytes
        ..sha256 = sha256;
    }
    return VisitPhoto(
      id: photoId,
      visitId: v.id,
      contentType: ph.contentType,
      bytes: ph.bytes,
      uploadedAt: ph.uploadedAt,
      url: null,
    );
  }

  void _put(PresignedUpload target, Uint8List bytes) {
    final p = _presigned[target.url];
    if (p == null || target.method != 'PUT') {
      throw _forbidden('signature rejected');
    }
    if (!_now.isBefore(p.expiresAt)) throw _forbidden('upload URL expired');
    if (bytes.isEmpty) throw _forbidden('empty upload rejected');
    _objects[p.storageKey] = bytes.length;
  }

  // ---------------------------------------------------------------------------
  // Alerts.

  CursorPage<FaAlert> _listAlerts(
    _Account fa,
    AlertStatus? status,
    int? limit,
    String? cursor,
  ) {
    _checkLimit(limit, 200);
    if (status == AlertStatus.unknown) {
      throw _validation({'status': 'must be open, acknowledged or closed'});
    }
    final rows = _alerts.values.where(
      (a) => a.faId == fa.id && (status == null || a.status == status),
    );
    return _page(
      rows,
      limit,
      cursor,
      50,
      at: (a) => a.createdAt,
      id: (a) => a.id,
    ).map((a) {
      final f = a.farmerId == null ? null : _farmers[a.farmerId];
      return FaAlert(
        alert: a.snap(),
        farmerName: f?.name,
        farmerPhone: f?.phone,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Masters (shared by every MockBackend; immutable).

  static final _seededAt = DateTime.utc(2026, 6, 15, 4, 30);

  static SnapVillage _villageRow(
    String code,
    String name,
    String nameTe,
    double lat,
    double lng, {
    required bool serilingampally,
  }) => SnapVillage(
    id: sid('village:$code'),
    name: name,
    nameTe: nameTe,
    lgdCode: null,
    location: LatLng(lat, lng),
    mandalId: serilingampally
        ? sid('mandal:serilingampally')
        : sid('mandal:chevella'),
    mandalName: serilingampally ? 'Serilingampally' : 'Chevella',
    mandalNameTe: serilingampally ? 'శేరిలింగంపల్లి' : 'చేవెళ్ల',
    districtId: sid('district:rangareddy'),
    districtName: 'Rangareddy',
    districtNameTe: 'రంగారెడ్డి',
    createdAt: _seededAt,
  );

  static final List<SnapVillage> _villages = List.unmodifiable([
    _villageRow(
      'kondapur',
      'Kondapur',
      'కొండాపూర్',
      17.4600,
      78.3570,
      serilingampally: true,
    ),
    _villageRow(
      'gachibowli',
      'Gachibowli',
      'గచ్చిబౌలి',
      17.4401,
      78.3489,
      serilingampally: true,
    ),
    _villageRow(
      'madhapur',
      'Madhapur',
      'మాదాపూర్',
      17.4483,
      78.3915,
      serilingampally: true,
    ),
    _villageRow(
      'chevella',
      'Chevella',
      'చేవెళ్ల',
      17.3067,
      78.1353,
      serilingampally: false,
    ),
    _villageRow(
      'mudimyal',
      'Mudimyal',
      'ముడిమ్యాల్',
      17.3300,
      78.1000,
      serilingampally: false,
    ),
  ]);

  static SnapCrop _crop(
    String code,
    String name,
    String nameTe,
    int days,
    List<(String, String, String, int, int)> stages, {
    bool devSeed = true,
  }) {
    final prefix = devSeed ? '' : 'mock:';
    return SnapCrop(
      id: sid('${prefix}crop:$code'),
      code: code,
      name: name,
      nameTe: nameTe,
      durationDays: days,
      stages: List.unmodifiable([
        for (final (i, s) in stages.indexed)
          SnapStage(
            id: sid('${prefix}stage:$code:${s.$1}'),
            code: s.$1,
            name: s.$2,
            nameTe: s.$3,
            seq: i + 1,
            startDay: s.$4,
            endDay: s.$5,
          ),
      ]),
    );
  }

  static final List<SnapCrop> _crops = List.unmodifiable([
    _crop('cotton', 'Cotton', 'పత్తి', 160, [
      ('seedling', 'Seedling', 'మొలక దశ', 0, 20),
      ('square', 'Square formation', 'మొగ్గ దశ', 21, 50),
      ('flowering', 'Flowering', 'పూత దశ', 51, 80),
      ('boll', 'Boll development', 'కాయ దశ', 81, 120),
      ('picking', 'Picking', 'తీత దశ', 121, 160),
    ]),
    _crop('paddy', 'Paddy', 'వరి', 120, [
      ('nursery', 'Nursery', 'నారుమడి', 0, 25),
      ('tillering', 'Tillering', 'పిలకల దశ', 26, 55),
      ('panicle', 'Panicle initiation', 'పొట్ట దశ', 56, 85),
      ('maturity', 'Grain filling and maturity', 'గింజ దశ', 86, 120),
    ]),
    _crop('chilli', 'Chilli', 'మిరప', 150, [
      ('seedling', 'Seedling', 'మొలక దశ', 0, 30),
      ('vegetative', 'Vegetative', 'ఎదుగుదల దశ', 31, 60),
      ('flowering', 'Flowering', 'పూత దశ', 61, 90),
      ('fruiting', 'Fruiting and picking', 'కాయ దశ', 91, 150),
    ]),
    _crop('maize', 'Maize', 'మొక్కజొన్న', 110, devSeed: false, [
      ('seedling', 'Seedling', 'మొలక దశ', 0, 20),
      ('vegetative', 'Vegetative', 'ఎదుగుదల దశ', 21, 50),
      ('tasselling', 'Tasselling and silking', 'పీచు దశ', 51, 75),
      ('grain', 'Grain filling', 'గింజ దశ', 76, 110),
    ]),
    _crop('redgram', 'Red gram', 'కంది', 170, devSeed: false, [
      ('seedling', 'Seedling', 'మొలక దశ', 0, 30),
      ('vegetative', 'Vegetative', 'ఎదుగుదల దశ', 31, 80),
      ('flowering', 'Flowering', 'పూత దశ', 81, 115),
      ('pod', 'Pod formation', 'కాయ దశ', 116, 170),
    ]),
  ]);

  static SnapStage? _stageById(String id) {
    for (final c in _crops) {
      for (final s in c.stages) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  static SnapCrop _cropById(String id) => _crops.firstWhere((c) => c.id == id);

  /// The stage of [cropId] on day [das] after sowing (`pickStage`): the
  /// first stage from sowing on, then each later one once it starts.
  static SnapStage? _stageOn(String cropId, int das) {
    final crop = _cropById(cropId);
    if (das < 0 || crop.stages.isEmpty) return null;
    var stage = crop.stages.first;
    for (final s in crop.stages.skip(1)) {
      if (s.startDay <= das) stage = s;
    }
    return stage;
  }

  static SnapIssue _issue(
    String key,
    String cropId,
    IssueType type,
    String name,
    String nameTe, {
    bool devSeed = false,
  }) => SnapIssue(
    id: sid('${devSeed ? '' : 'mock:'}issue:$key'),
    cropId: cropId,
    type: type,
    name: name,
    nameTe: nameTe,
  );

  static final List<SnapIssue> _issues = List.unmodifiable([
    _issue(
      'cotton:pink-bollworm',
      cottonId,
      IssueType.pest,
      'Pink bollworm',
      'గులాబీ రంగు పురుగు',
      devSeed: true,
    ),
    _issue(
      'cotton:whitefly',
      cottonId,
      IssueType.pest,
      'Whitefly',
      'తెల్ల దోమ',
      devSeed: true,
    ),
    _issue(
      'cotton:sucking-pests',
      cottonId,
      IssueType.pest,
      'Sucking pests',
      'రసం పీల్చే పురుగులు',
    ),
    _issue(
      'cotton:leaf-spot',
      cottonId,
      IssueType.disease,
      'Leaf spot',
      'ఆకు మచ్చ తెగులు',
    ),
    _issue(
      'cotton:potash',
      cottonId,
      IssueType.deficiency,
      'Potash deficiency',
      'పొటాష్ లోపం',
    ),
    _issue(
      'cotton:leaf-reddening',
      cottonId,
      IssueType.deficiency,
      'Leaf reddening',
      'ఆకు ఎర్రబారడం',
    ),
    _issue(
      'paddy:blast',
      paddyId,
      IssueType.disease,
      'Blast',
      'అగ్గి తెగులు',
      devSeed: true,
    ),
    _issue(
      'paddy:bph',
      paddyId,
      IssueType.pest,
      'Brown plant hopper',
      'దోమ పోటు',
    ),
    _issue(
      'paddy:zinc',
      paddyId,
      IssueType.deficiency,
      'Zinc deficiency',
      'జింక్ లోపం',
    ),
    _issue('chilli:thrips', chilliId, IssueType.pest, 'Thrips', 'తామర పురుగు'),
    _issue(
      'chilli:fruit-rot',
      chilliId,
      IssueType.disease,
      'Fruit rot',
      'కాయ కుళ్ళు తెగులు',
    ),
    _issue(
      'maize:fall-armyworm',
      maizeId,
      IssueType.pest,
      'Fall armyworm',
      'కత్తెర పురుగు',
    ),
    _issue(
      'redgram:pod-borer',
      redGramId,
      IssueType.pest,
      'Pod borer',
      'కాయ తొలుచు పురుగు',
    ),
    _issue('redgram:wilt', redGramId, IssueType.disease, 'Wilt', 'ఎండు తెగులు'),
  ]);

  static String _issueId(String key) => _issues
      .where((i) => i.id == sid('issue:$key') || i.id == sid('mock:issue:$key'))
      .first
      .id;

  static SnapSalt _salt(
    String key,
    String name,
    String nameTe, {
    bool dev = false,
  }) => SnapSalt(
    id: sid('${dev ? '' : 'mock:'}salt:$key'),
    name: name,
    nameTe: nameTe,
  );

  static final List<SnapSalt> _salts = List.unmodifiable([
    _salt(
      'emamectin',
      'Emamectin benzoate 5% SG',
      'ఎమామెక్టిన్ బెంజోయేట్ 5% SG',
      dev: true,
    ),
    _salt(
      'imidacloprid',
      'Imidacloprid 17.8% SL',
      'ఇమిడాక్లోప్రిడ్ 17.8% SL',
      dev: true,
    ),
    _salt(
      'tricyclazole',
      'Tricyclazole 75% WP',
      'ట్రైసైక్లాజోల్ 75% WP',
      dev: true,
    ),
    _salt('flonicamid', 'Flonicamid 50% WG', 'ఫ్లోనికామిడ్ 50% WG'),
    _salt('mancozeb', 'Mancozeb 75% WP', 'మాంకోజెబ్ 75% WP'),
    _salt('potassium-nitrate', 'Potassium nitrate', 'పొటాషియం నైట్రేట్'),
    _salt('magnesium-sulphate', 'Magnesium sulphate', 'మెగ్నీషియం సల్ఫేట్'),
    _salt('zinc-sulphate', 'Zinc sulphate', 'జింక్ సల్ఫేట్'),
    _salt('fipronil', 'Fipronil 5% SC', 'ఫిప్రోనిల్ 5% SC'),
  ]);

  static String _saltId(String key) => _salts
      .where((s) => s.id == sid('salt:$key') || s.id == sid('mock:salt:$key'))
      .first
      .id;

  static final List<SnapSku> _skus = List.unmodifiable([
    SnapSku(
      id: sid('sku:SH-EB-250'),
      code: 'SH-EB-250',
      productName: 'Sample 5 SG',
      productNameTe: 'శాంపిల్ 5 SG',
      saltId: _saltId('emamectin'),
      packSize: '250 g',
      mrpPaise: 45000,
      cashbackEligible: true,
    ),
    SnapSku(
      id: sid('sku:SH-IM-100'),
      code: 'SH-IM-100',
      productName: 'Sample Guard 17.8',
      productNameTe: 'శాంపిల్ గార్డ్ 17.8',
      saltId: _saltId('imidacloprid'),
      packSize: '100 ml',
      mrpPaise: 32000,
      cashbackEligible: true,
    ),
    SnapSku(
      id: sid('mock:sku:SH-FL-60'),
      code: 'SH-FL-60',
      productName: 'Sample 50 WG',
      productNameTe: 'శాంపిల్ 50 WG',
      saltId: _saltId('flonicamid'),
      packSize: '60 g',
      mrpPaise: 38000,
      cashbackEligible: true,
    ),
    SnapSku(
      id: sid('mock:sku:SH-NK-1K'),
      code: 'SH-NK-1K',
      productName: 'Sample Nutri K',
      productNameTe: 'శాంపిల్ న్యూట్రి K',
      saltId: _saltId('potassium-nitrate'),
      packSize: '1 kg',
      mrpPaise: 28000,
      cashbackEligible: false,
    ),
  ]);

  static String _skuId(String code) =>
      _skus.firstWhere((s) => s.code == code).id;

  static SnapRule _rule(
    String key,
    String issueKey,
    String saltKey,
    String? skuCode,
    String dose,
    String doseTe, {
    bool dev = false,
  }) {
    final prefix = dev ? '' : 'mock:';
    return SnapRule(
      id: sid('${prefix}rule:$key:v1'),
      ruleKey: sid('${prefix}rulekey:$key'),
      version: 1,
      issueId: _issueId(issueKey),
      saltId: _saltId(saltKey),
      skuId: skuCode == null ? null : _skuId(skuCode),
      dosePerAcre: dose,
      dosePerAcreTe: doseTe,
    );
  }

  static final List<SnapRule> _rules = List.unmodifiable([
    _rule(
      'pbw',
      'cotton:pink-bollworm',
      'emamectin',
      'SH-EB-250',
      '80 g in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 80 గ్రా.',
      dev: true,
    ),
    _rule(
      'wf',
      'cotton:whitefly',
      'imidacloprid',
      'SH-IM-100',
      '50 ml in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 50 మి.లీ.',
      dev: true,
    ),
    _rule(
      'blast',
      'paddy:blast',
      'tricyclazole',
      null,
      '120 g in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 120 గ్రా.',
      dev: true,
    ),
    _rule(
      'sucking',
      'cotton:sucking-pests',
      'flonicamid',
      'SH-FL-60',
      '60 g in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 60 గ్రా.',
    ),
    _rule(
      'leafspot',
      'cotton:leaf-spot',
      'mancozeb',
      null,
      '600 g in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 600 గ్రా.',
    ),
    _rule(
      'potash',
      'cotton:potash',
      'potassium-nitrate',
      'SH-NK-1K',
      '2 kg in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 2 కిలోలు',
    ),
    _rule(
      'reddening',
      'cotton:leaf-reddening',
      'magnesium-sulphate',
      null,
      '1 kg in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 1 కిలో',
    ),
    _rule(
      'bph',
      'paddy:bph',
      'imidacloprid',
      'SH-IM-100',
      '50 ml in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 50 మి.లీ.',
    ),
    _rule(
      'zinc',
      'paddy:zinc',
      'zinc-sulphate',
      null,
      '10 kg per acre in the soil',
      'ఎకరానికి 10 కిలోలు నేలలో',
    ),
    _rule(
      'thrips',
      'chilli:thrips',
      'fipronil',
      null,
      '400 ml in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 400 మి.లీ.',
    ),
    _rule(
      'fruitrot',
      'chilli:fruit-rot',
      'mancozeb',
      null,
      '600 g in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 600 గ్రా.',
    ),
    _rule(
      'faw',
      'maize:fall-armyworm',
      'emamectin',
      'SH-EB-250',
      '80 g in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 80 గ్రా.',
    ),
    _rule(
      'podborer',
      'redgram:pod-borer',
      'emamectin',
      'SH-EB-250',
      '90 g in 200 L water per acre',
      'ఎకరానికి 200 లీ. నీటిలో 90 గ్రా.',
    ),
    // Red gram wilt has no approved rule: the visit log leaves it unresolved.
  ]);

  /// A visit issue as the server stores it: with the rule's salt, SKU and
  /// dose when [ruleId] is an approved rule for [issueId], else unresolved
  /// (every advice field null).
  static SnapVisitIssue _visitIssue(
    String id,
    String issueId,
    Severity severity, {
    String? ruleId,
  }) {
    final issue = _issues.where((i) => i.id == issueId).firstOrNull;
    final rule = ruleId == null
        ? null
        : _rules
              .where((r) => r.id == ruleId && r.issueId == issueId)
              .firstOrNull;
    final salt = rule == null
        ? null
        : _salts.firstWhere((s) => s.id == rule.saltId);
    final sku = rule?.skuId == null
        ? null
        : _skus.firstWhere((s) => s.id == rule!.skuId);
    return SnapVisitIssue(
      id: id,
      issueId: issueId,
      issueName: issue?.name,
      issueNameTe: issue?.nameTe,
      severity: severity,
      adviceStatus: rule == null ? AdviceStatus.unresolved : AdviceStatus.given,
      ruleId: rule?.id,
      saltId: salt?.id,
      saltName: salt?.name,
      saltNameTe: salt?.nameTe,
      skuId: sku?.id,
      productName: sku?.productName,
      productNameTe: sku?.productNameTe,
      dose: rule?.dosePerAcre,
      doseTe: rule?.dosePerAcreTe,
    );
  }

  // ---------------------------------------------------------------------------
  // Geometry.

  static const _sqmPerAcre = 4046.8564224;

  /// The area of a GeoJSON Polygon's outer ring in acres (planar, on a local
  /// equirectangular projection; fine at plot size), or null when [geoJson]
  /// is not a Polygon with at least 3 corners.
  static double? _polygonAcres(String geoJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(geoJson);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?> || decoded['type'] != 'Polygon') {
      return null;
    }
    final rings = geoJsonOuterRings(geoJson);
    if (rings.isEmpty || rings.first.length < 4) return null;
    final ring = rings.first;
    final lat0 = ring.map((p) => p.lat).reduce((a, b) => a + b) / ring.length;
    const mLat = 111320.0;
    final mLng = 111320.0 * math.cos(lat0 * math.pi / 180);
    var sum = 0.0;
    for (var i = 0; i < ring.length - 1; i++) {
      final a = ring[i];
      final b = ring[i + 1];
      sum += (a.lng * mLng) * (b.lat * mLat) - (b.lng * mLng) * (a.lat * mLat);
    }
    final acres = sum.abs() / 2 / _sqmPerAcre;
    return acres > 0 ? acres : null;
  }

  /// Text length as the backend measures it: Go `len()` counts UTF-8 bytes
  /// (a Telugu letter is 3), not characters.
  static int _bytes(String s) => utf8.encode(s).length;

  /// The outer ring of a GeoJSON Polygon, as PostGIS `ST_GeomFromGeoJSON`
  /// reads it: null when it would not parse (bad JSON, no ring, an open ring
  /// or fewer than 4 positions), empty for another geometry type.
  static List<LatLng>? _polygonRing(String geoJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(geoJson);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?> || decoded['type'] is! String) {
      return null;
    }
    if (decoded['type'] != 'Polygon') return const [];
    final rings = geoJsonOuterRings(geoJson);
    if (rings.isEmpty) return null;
    final ring = rings.first;
    if (ring.length < 4 || ring.first != ring.last) return null;
    return ring;
  }

  /// True when the closed [ring] is simple, as `ST_IsValid` demands of a
  /// polygon's shell: at least 3 distinct corners, no two edges crossing or
  /// touching except neighbours at their shared corner, and no edge folding
  /// back over its neighbour (a spike or a zero-area ring). Repeated
  /// consecutive points are allowed, as in PostGIS.
  static bool _isSimpleRing(List<LatLng> ring) {
    final pts = <LatLng>[];
    for (final p in ring) {
      if (pts.isEmpty || pts.last != p) pts.add(p);
    }
    if (pts.length > 1 && pts.first == pts.last) pts.removeLast();
    final n = pts.length;
    if (n < 3) return false;
    // Planar metres around the ring (fine at plot size).
    final lat0 = pts.map((p) => p.lat).reduce((a, b) => a + b) / n;
    final k = math.cos(lat0 * math.pi / 180);
    final xy = [for (final p in pts) (p.lng * k * 111320.0, p.lat * 111320.0)];
    double cross((double, double) o, (double, double) a, (double, double) b) =>
        (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
    bool onSegment(
      (double, double) a,
      (double, double) b,
      (double, double) p,
    ) =>
        cross(a, b, p) == 0 &&
        math.min(a.$1, b.$1) <= p.$1 &&
        p.$1 <= math.max(a.$1, b.$1) &&
        math.min(a.$2, b.$2) <= p.$2 &&
        p.$2 <= math.max(a.$2, b.$2);
    bool touch(
      (double, double) a,
      (double, double) b,
      (double, double) c,
      (double, double) d,
    ) {
      final d1 = cross(c, d, a);
      final d2 = cross(c, d, b);
      final d3 = cross(a, b, c);
      final d4 = cross(a, b, d);
      if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
          ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
        return true;
      }
      return onSegment(c, d, a) ||
          onSegment(c, d, b) ||
          onSegment(a, b, c) ||
          onSegment(a, b, d);
    }

    for (var i = 0; i < n; i++) {
      final a = xy[i];
      final b = xy[(i + 1) % n];
      for (var j = i + 1; j < n; j++) {
        final c = xy[j];
        final d = xy[(j + 1) % n];
        if (j == i + 1) {
          // Neighbours share b (= c): the far ends must not lie on the
          // other edge (the ring folding back on itself).
          if (onSegment(a, b, d) || onSegment(c, d, a)) return false;
        } else if (i == 0 && j == n - 1) {
          // The closing edge shares a (= d).
          if (onSegment(a, b, c) || onSegment(c, d, b)) return false;
        } else if (touch(a, b, c, d)) {
          return false;
        }
      }
    }
    return true;
  }

  /// A square boundary of about [acres] centred on [c].
  static String _square(LatLng c, double acres) {
    final half = math.sqrt(acres * _sqmPerAcre) / 2;
    final dLat = half / 111320;
    final dLng = half / (111320 * math.cos(c.lat * math.pi / 180));
    return polygonGeoJson([
      LatLng(c.lat - dLat, c.lng - dLng),
      LatLng(c.lat - dLat, c.lng + dLng),
      LatLng(c.lat + dLat, c.lng + dLng),
      LatLng(c.lat + dLat, c.lng - dLng),
    ]);
  }

  /// A point [metres] from [c] at [degrees] (0 = north).
  static LatLng _offset(LatLng c, double metres, double degrees) {
    final r = degrees * math.pi / 180;
    final dLat = metres * math.cos(r) / 111320;
    final dLng =
        metres * math.sin(r) / (111320 * math.cos(c.lat * math.pi / 180));
    final lat = double.parse((c.lat + dLat).toStringAsFixed(6));
    final lng = double.parse((c.lng + dLng).toStringAsFixed(6));
    return LatLng(lat, lng);
  }

  static String? _trimmed(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  // ---------------------------------------------------------------------------
  // Seed: the mock world (see the README for what each name is for).

  void _seed() {
    final now = _now;
    final today = _today;

    // FA logins.
    _accounts[sureshId] = _Account(
      id: sureshId,
      code: sureshCode,
      name: 'Suresh Kumar',
      nameTe: 'సురేష్ కుమార్',
      phone: '+919848012345',
      password: sureshPassword,
      level: AreaLevel.village,
      languages: const ['te', 'en'],
      workingHours: 'Mon-Sat 8 am - 5 pm',
      villageIds: {kondapurId, gachibowliId},
      createdAt: _seededAt,
    )..lastLoginAt = now.subtract(const Duration(days: 1, hours: 2));
    final temp = sid('mock:fa:kdp-099');
    _accounts[temp] =
        _Account(
            id: temp,
            code: tempPasswordCode,
            name: 'Mahesh B',
            nameTe: 'మహేష్ బి',
            phone: '+919848012399',
            password: tempPassword,
            level: AreaLevel.village,
            languages: const ['te'],
            workingHours: 'Mon-Sat 8 am - 5 pm',
            villageIds: {madhapurId},
            createdAt: now.subtract(const Duration(hours: 5)),
          )
          ..mustChangePassword = true
          ..tempPasswordExpiresAt = now.add(const Duration(hours: 67));
    final expired = sid('mock:fa:kdp-077');
    _accounts[expired] =
        _Account(
            id: expired,
            code: expiredPasswordCode,
            name: 'Ramya T',
            nameTe: 'రమ్య టి',
            phone: '+919848012377',
            password: expiredPassword,
            level: AreaLevel.village,
            languages: const ['te'],
            workingHours: null,
            villageIds: {madhapurId},
            createdAt: now.subtract(const Duration(days: 4)),
          )
          ..mustChangePassword = true
          ..tempPasswordExpiresAt = now.subtract(const Duration(hours: 24));
    _accounts[otherFaId] = _Account(
      id: otherFaId,
      code: otherFaCode,
      name: 'Lakshmi P',
      nameTe: 'లక్ష్మి పి',
      phone: '+919000000002',
      password: otherFaPassword,
      level: AreaLevel.mandal,
      languages: const ['te'],
      workingHours: 'Mon-Sat 7 am - 4 pm',
      villageIds: {chevellaId, sid('village:mudimyal')},
      createdAt: _seededAt,
    );
    _territoryVersions[sureshId] = 12;

    final kondapur = _village(kondapurId)!.location!;
    final gachibowli = _village(gachibowliId)!.location!;
    var visitSeq = 0;

    _Farmer farmer(
      String id,
      String phone,
      String name,
      String nameTe, {
      required String? villageId,
      String? faId,
      FarmerSource source = FarmerSource.fa,
      Plan plan = Plan.free,
      FarmerStatus status = FarmerStatus.active,
      bool consent = true,
      int joinedDaysAgo = 120,
      Duration? joinedAgo,
    }) {
      final created = joinedAgo != null
          ? now.subtract(joinedAgo)
          : now.subtract(Duration(days: joinedDaysAgo));
      final f = _Farmer(
        id: id,
        phone: phone,
        name: name,
        nameTe: nameTe,
        language: Language.te,
        villageId: villageId,
        assignedFaId: faId,
        source: source,
        photoKey: null,
        plan: plan,
        status: status,
        profileCompletedAt: status == FarmerStatus.pendingProfile
            ? null
            : created,
        createdAt: created,
      );
      if (consent) f.grant(const [ConsentPurpose.programme]);
      _farmers[id] = f;
      return f;
    }

    _Plot plot(
      _Farmer f,
      String id,
      String label,
      double acres,
      LatLng pin, {
      bool boundary = false,
    }) {
      final geo = boundary ? _square(pin, acres) : null;
      final p = _Plot(
        id: id,
        farmerId: f.id,
        label: label,
        villageId: f.villageId,
        boundaryGeoJson: geo,
        pin: pin,
        areaAcres: geo == null
            ? acres
            : ((_polygonAcres(geo)! * 1000).round() / 1000),
        areaSource: geo == null ? AreaSource.typed : AreaSource.boundary,
        gpsAccuracyM: geo == null ? null : 4,
        updatedAt: f.createdAt,
      );
      _plots[id] = p;
      return p;
    }

    _Season season(
      _Plot p,
      String id,
      String cropId,
      int sownDaysAgo, {
      SeasonStatus status = SeasonStatus.active,
      String? previousCropId,
    }) {
      final sown = today.addDays(-sownDaysAgo);
      final s = _Season(
        id: id,
        farmerId: p.farmerId,
        plotId: p.id,
        seasonCode: seasonCodesOn(sown).current,
        cropId: cropId,
        sowingDate: sown,
        previousCropId: previousCropId,
        status: status,
        updatedAt: p.updatedAt,
      );
      _seasons[id] = s;
      return s;
    }

    void planned(
      _Season s,
      int inDays,
      VisitSlot slot,
      String purpose, {
      String? id,
    }) {
      final vid = id ?? sid('mock:visit:planned:${visitSeq++}');
      _visits[vid] = _Visit(
        id: vid,
        farmerId: s.farmerId,
        plotId: s.plotId,
        seasonId: s.id,
        faId: sureshId,
        status: VisitStatus.planned,
        plannedFor: today.addDays(inDays),
        plannedSlot: slot,
        purpose: purpose,
      );
    }

    // A done visit [daysAgo] days ago at 10:30 IST (today: 2 hours ago, but
    // not before midnight IST), stage stamped from the crop calendar.
    void done(
      _Season s,
      int daysAgo,
      List<(String, Severity, String?)> issues, {
      String? notes,
      int photos = 0,
      String? id,
      VisitSlot slot = VisitSlot.morning,
      String? purpose,
    }) {
      final vid = id ?? sid('mock:visit:done:${visitSeq++}');
      final day = today.addDays(-daysAgo);
      final istMidnight = day.toDateTime().subtract(istOffset);
      var at = istMidnight.add(
        slot == VisitSlot.afternoon
            ? const Duration(hours: 15)
            : const Duration(hours: 10, minutes: 30),
      );
      if (daysAgo == 0 && at.isAfter(now)) {
        final earlier = now.subtract(const Duration(hours: 2));
        at = earlier.isBefore(istMidnight)
            ? istMidnight.add(const Duration(minutes: 1))
            : earlier;
      }
      final das = s.sowingDate!.daysUntil(day);
      final stage = _stageOn(s.cropId, das);
      final v =
          _Visit(
              id: vid,
              farmerId: s.farmerId,
              plotId: s.plotId,
              seasonId: s.id,
              faId: sureshId,
              status: VisitStatus.done,
              plannedFor: day,
              plannedSlot: slot,
              purpose: purpose,
            )
            ..visitedAt = at
            ..farmerPresent = true
            ..stageId = stage?.id
            ..stageName = stage?.name
            ..stageNameTe = stage?.nameTe
            ..notes = notes
            ..location = _plots[s.plotId]?.pin
            ..issues = [
              for (final (i, (issueId, severity, ruleId)) in issues.indexed)
                _visitIssue(
                  sid('mock:visit-issue:$vid:$i'),
                  issueId,
                  severity,
                  ruleId: ruleId,
                ),
            ];
      for (var i = 0; i < photos; i++) {
        final pid = sid('mock:visit-photo:$vid:$i');
        final key = _visitPhotoKey(vid, pid, PhotoContentType.jpeg);
        v.photos[pid] = _VisitPhoto(PhotoContentType.jpeg, key)
          ..uploadedAt = at.add(const Duration(hours: 1))
          ..bytes = 412000;
        _objects[key] = 412000;
      }
      _visits[vid] = v;
    }

    // --- The farmers named in the designs (Suresh's).

    final ravi = farmer(
      raviId,
      raviPhone,
      'Ravi K',
      'రవి కె',
      villageId: kondapurId,
      faId: sureshId,
      joinedDaysAgo: 140,
    );
    final raviPlot = plot(
      ravi,
      raviPlotId,
      'Plot 1',
      guntasToAcres(84), // 2 ac 4 gunta
      const LatLng(17.4612, 78.3555),
    );
    final raviSeason = season(
      raviPlot,
      raviSeasonId,
      cottonId,
      65, // flowering
      previousCropId: paddyId,
    );
    done(
      raviSeason,
      12,
      [
        (
          _issueId('cotton:pink-bollworm'),
          Severity.moderate,
          sid('rule:pbw:v1'),
        ),
      ],
      notes: 'Pink bollworm in a few bolls; pheromone traps advised.',
      photos: 3,
      id: sid('mock:visit:ravi:1'),
      purpose: 'Pest follow-up',
    );
    done(
      raviSeason,
      26,
      [
        (
          _issueId('cotton:sucking-pests'),
          Severity.low,
          sid('mock:rule:sucking:v1'),
        ),
      ],
      id: sid('mock:visit:ravi:2'),
      purpose: 'Stage check',
    );
    done(
      raviSeason,
      40,
      [
        (
          _issueId('cotton:leaf-spot'),
          Severity.moderate,
          sid('mock:rule:leafspot:v1'),
        ),
      ],
      id: sid('mock:visit:ravi:3'),
      purpose: 'Stage check',
    );
    done(raviSeason, 55, const [], id: sid('mock:visit:ravi:4'));
    planned(
      raviSeason,
      0,
      VisitSlot.morning,
      'Pest follow-up',
      id: sid('mock:visit:ravi:today'),
    );
    planned(
      raviSeason,
      1,
      VisitSlot.morning,
      'Check bollworm traps',
      id: sid('visit:ravi:planned-1'),
    );
    _callbacks[raviCallbackId] = _Callback(
      id: raviCallbackId,
      farmerId: raviId,
      faId: sureshId,
      requestedAt: now.subtract(const Duration(minutes: 25)),
    );

    final venkatesh = farmer(
      venkateshId,
      venkateshPhone,
      'Venkatesh M',
      'వెంకటేష్ ఎం',
      villageId: gachibowliId,
      faId: sureshId,
      joinedDaysAgo: 140,
    );
    final venkateshSeason = season(
      plot(
        venkatesh,
        sid('plot:venkatesh:1'),
        'Plot 1',
        1.75,
        const LatLng(17.4390, 78.3470),
      ),
      sid('season:venkatesh:1:rabi-2026-27'),
      paddyId,
      23,
    );
    done(venkateshSeason, 15, [
      (_issueId('paddy:blast'), Severity.low, sid('rule:blast:v1')),
    ], purpose: 'Stage check');
    planned(venkateshSeason, 0, VisitSlot.afternoon, 'Stage check');

    final venkat = farmer(
      venkatId,
      venkatPhone,
      'Venkat R',
      'వెంకట్ ఆర్',
      villageId: kondapurId,
      faId: sureshId,
      joinedDaysAgo: 100,
    );
    final venkatSeason = season(
      plot(
        venkat,
        sid('mock:plot:venkat:1'),
        'Plot 1',
        1.5,
        _offset(kondapur, 1900, 250),
        boundary: true,
      ),
      sid('mock:season:venkat:1'),
      cottonId,
      95,
    );
    done(venkatSeason, 9, [
      (_issueId('cotton:whitefly'), Severity.moderate, sid('rule:wf:v1')),
    ], purpose: 'Stage check');
    planned(venkatSeason, 2, VisitSlot.morning, 'Pest follow-up');

    final padma = farmer(
      padmaId,
      padmaPhone,
      'Padma S',
      'పద్మ ఎస్',
      villageId: gachibowliId,
      faId: sureshId,
      plan: Plan.premium,
      joinedDaysAgo: 200,
    );
    final padmaSeason1 = season(
      plot(
        padma,
        sid('mock:plot:padma:1'),
        'Plot 1',
        2.25,
        _offset(gachibowli, 2400, 135),
      ),
      sid('mock:season:padma:1'),
      paddyId,
      70,
    );
    final padmaSeason2 = season(
      plot(
        padma,
        padmaPlot2Id,
        'Plot 2',
        guntasToAcres(60), // 1 ac 20 gunta
        _offset(gachibowli, 2600, 150),
      ),
      sid('mock:season:padma:2'),
      paddyId,
      68,
    );
    done(padmaSeason2, 34, [
      (_issueId('paddy:zinc'), Severity.low, sid('mock:rule:zinc:v1')),
    ], purpose: 'Stage check');
    planned(padmaSeason1, 3, VisitSlot.morning, 'Soil test pickup');
    _callbacks[sid('mock:callback:padma')] = _Callback(
      id: sid('mock:callback:padma'),
      farmerId: padmaId,
      faId: sureshId,
      requestedAt: now.subtract(const Duration(days: 2, hours: 3)),
    );

    final lakshmi = farmer(
      lakshmiId,
      lakshmiPhone,
      'Lakshmi N',
      'లక్ష్మి ఎన్',
      villageId: kondapurId,
      faId: sureshId,
      source: FarmerSource.self,
      joinedAgo: const Duration(days: 1, hours: 3),
    );
    final lakshmiSeason = season(
      plot(
        lakshmi,
        sid('mock:plot:lakshmi:1'),
        'Plot 1',
        guntasToAcres(50), // 1 ac 10 gunta
        _offset(kondapur, 3100, 200),
        boundary: true,
      ),
      sid('mock:season:lakshmi:1'),
      maizeId,
      12,
      previousCropId: cottonId,
    );
    done(lakshmiSeason, 1, const [], purpose: 'Stage check');
    planned(lakshmiSeason, 2, VisitSlot.afternoon, 'Soil sample');

    final gopi = farmer(
      sid('mock:farmer:gopi'),
      '+919000000106',
      'Gopi M',
      'గోపి ఎం',
      villageId: kondapurId,
      faId: sureshId,
      joinedDaysAgo: 300,
    );
    final gopiPlot1 = plot(
      gopi,
      sid('mock:plot:gopi:1'),
      'Plot 1',
      1,
      _offset(kondapur, 1400, 20),
    );
    season(
      gopiPlot1,
      sid('mock:season:gopi:1'),
      paddyId,
      150,
      status: SeasonStatus.harvested,
    );
    final gopiSeason = season(
      plot(
        gopi,
        sid('mock:plot:gopi:2'),
        'Plot 2',
        2,
        _offset(kondapur, 1500, 35),
      ),
      sid('mock:season:gopi:2'),
      cottonId,
      80,
    );
    done(
      gopiSeason,
      1,
      [(_issueId('cotton:whitefly'), Severity.high, sid('rule:wf:v1'))],
      slot: VisitSlot.afternoon,
      purpose: 'Pest follow-up',
    );
    done(gopiSeason, 22, [
      (
        _issueId('cotton:potash'),
        Severity.moderate,
        sid('mock:rule:potash:v1'),
      ),
    ], purpose: 'Stage check');
    planned(gopiSeason, 3, VisitSlot.afternoon, 'Advice follow-up');

    final anil = farmer(
      sid('mock:farmer:anil'),
      '+919000000107',
      'Anil G',
      'అనిల్ జి',
      villageId: gachibowliId,
      faId: sureshId,
      joinedDaysAgo: 90,
    );
    final anilSeason = season(
      plot(
        anil,
        sid('mock:plot:anil:1'),
        'Plot 1',
        3,
        _offset(gachibowli, 900, 300),
      ),
      sid('mock:season:anil:1'),
      redGramId,
      85,
    );
    done(anilSeason, 18, [
      (_issueId('redgram:wilt'), Severity.moderate, null),
    ], purpose: 'Stage check');
    planned(anilSeason, 1, VisitSlot.morning, 'Stage check');

    final sita = farmer(
      sid('mock:farmer:sita'),
      '+919000000108',
      'Sita R',
      'సీత ఆర్',
      villageId: kondapurId,
      faId: sureshId,
      joinedDaysAgo: 110,
    );
    final sitaSeason = season(
      plot(
        sita,
        sid('mock:plot:sita:1'),
        'Plot 1',
        1.25,
        _offset(kondapur, 700, 90),
      ),
      sid('mock:season:sita:1'),
      chilliId,
      70,
    );
    done(
      sitaSeason,
      0,
      [
        (
          _issueId('chilli:thrips'),
          Severity.moderate,
          sid('mock:rule:thrips:v1'),
        ),
      ],
      photos: 2,
      purpose: 'Stage check',
    );
    planned(sitaSeason, 2, VisitSlot.morning, 'Flowering check');

    final kumar = farmer(
      sid('mock:farmer:kumar'),
      '+919000000109',
      'Kumar B',
      'కుమార్ బి',
      villageId: gachibowliId,
      faId: sureshId,
      consent: false, // enrolled offline without the OTP: RecordConsent case
      joinedDaysAgo: 6,
    );
    for (final n in [1, 2]) {
      season(
        plot(
          kumar,
          sid('mock:plot:kumar:$n'),
          'Plot $n',
          1.5,
          _offset(gachibowli, 1200 + 80.0 * n, 60),
        ),
        sid('mock:season:kumar:$n'),
        paddyId,
        40,
      );
    }
    final kumarSeason3 = season(
      plot(
        kumar,
        sid('mock:plot:kumar:3'),
        'Plot 3',
        0.75,
        _offset(gachibowli, 1450, 70),
      ),
      sid('mock:season:kumar:3'),
      paddyId,
      5,
    );
    planned(kumarSeason3, 2, VisitSlot.afternoon, 'First visit');

    // --- Other phones for the lookup statuses.

    farmer(
      rajuId,
      rajuPhone,
      'Raju P',
      'రాజు పి',
      villageId: kondapurId,
      source: FarmerSource.self,
      status: FarmerStatus.pendingProfile,
      joinedAgo: const Duration(minutes: 10),
    );
    farmer(
      sid('mock:farmer:srinivas'),
      outsideAreaPhone,
      'Srinivas D',
      'శ్రీనివాస్ డి',
      villageId: madhapurId,
      source: FarmerSource.self,
      joinedDaysAgo: 30,
    );
    farmer(
      sid('mock:farmer:mallesh'),
      deactivatedPhone,
      'Mallesh T',
      'మల్లేష్ టి',
      villageId: kondapurId,
      faId: sureshId,
      status: FarmerStatus.inactive,
      joinedDaysAgo: 400,
    );
    final narsimha = farmer(
      sid('mock:farmer:narsimha'),
      otherFaFarmerPhone,
      'Narsimha G',
      'నర్సింహ జి',
      villageId: chevellaId,
      faId: otherFaId,
      joinedDaysAgo: 150,
    );
    season(
      plot(
        narsimha,
        sid('mock:plot:narsimha:1'),
        'Plot 1',
        4,
        const LatLng(17.3080, 78.1370),
      ),
      sid('mock:season:narsimha:1'),
      cottonId,
      90,
    );
    farmer(
      sid('mock:farmer:yadamma'),
      '+919000000202',
      'Yadamma K',
      'యాదమ్మ కె',
      villageId: sid('village:mudimyal'),
      faId: otherFaId,
      joinedDaysAgo: 150,
    );

    // --- 37 more of Suresh's farmers, so the list has 46.

    final crops = [cottonId, paddyId, chilliId, maizeId, redGramId];
    for (final (i, (en, te)) in _moreNames.indexed) {
      final (ini, iniTe) = _initials[i % _initials.length];
      final inKondapur = i.isEven;
      final centre = inKondapur ? kondapur : gachibowli;
      final f = farmer(
        sid('mock:farmer:more:$i'),
        '+9190000004${i.toString().padLeft(2, '0')}',
        '$en $ini',
        '$te $iniTe',
        villageId: inKondapur ? kondapurId : gachibowliId,
        faId: sureshId,
        source: i % 7 == 3 ? FarmerSource.self : FarmerSource.fa,
        plan: i % 5 == 2 ? Plan.premium : Plan.free,
        consent: i % 11 != 5,
        joinedDaysAgo: 20 + (i * 13) % 300,
      );
      final plots = i % 3 == 1 && i < 34 ? 2 : 1; // 61 plots in all
      for (var n = 1; n <= plots; n++) {
        final pin = _offset(
          centre,
          300 + ((i * 97 + n * 211) % 2600).toDouble(),
          (i * 137.5 + n * 40) % 360,
        );
        final p = plot(
          f,
          sid('mock:plot:more:$i:$n'),
          'Plot $n',
          guntasToAcres(20 + (i * 7 + n * 11) % 100),
          pin,
          boundary: (i + n) % 3 == 0,
        );
        final cropId = crops[(i + n) % crops.length];
        final s = season(
          p,
          sid('mock:season:more:$i:$n'),
          cropId,
          15 + (i * 11 + n * 5) % 110,
        );
        if (n == 1) {
          final issues = _issues.where((m) => m.cropId == cropId).toList();
          final issue = issues[i % issues.length];
          final rule = _rules.where((r) => r.issueId == issue.id).firstOrNull;
          done(
            s,
            2 + (i * 7) % 44,
            i % 3 == 2
                ? const []
                : [(issue.id, Severity.values[i % 3], rule?.id)],
            purpose: 'Stage check',
          );
        }
      }
    }

    // --- Alerts for Suresh.

    void alert(
      String key,
      AlertKind kind,
      Duration age,
      String title, {
      String? titleTe,
      String? body,
      String? bodyTe,
      String? farmerId,
      String? refId,
      AlertStatus status = AlertStatus.open,
    }) {
      final id = sid('mock:alert:$key');
      final at = now.subtract(age);
      _alerts[id] =
          _Alert(
              id: id,
              faId: sureshId,
              kind: kind,
              farmerId: farmerId,
              refId: refId,
              title: title,
              body: body,
              titleTe: titleTe,
              bodyTe: bodyTe,
              status: status,
              createdAt: at,
            )
            ..acknowledgedAt = status == AlertStatus.acknowledged
                ? at.add(const Duration(hours: 1))
                : null;
    }

    alert(
      'raju-new',
      AlertKind.newFarmer,
      const Duration(minutes: 10),
      'Raju P joined · Kondapur',
      titleTe: 'రాజు పి చేరారు · కొండాపూర్',
      body:
          'Signed up himself in the farmer app. No FA yet: finish his '
          'enrolment.',
      bodyTe: 'రైతు యాప్‌లో స్వయంగా చేరారు. ఇంకా FA లేరు: నమోదు పూర్తి చేయండి.',
      farmerId: rajuId,
      refId: rajuId,
    );
    alert(
      'ravi-callback',
      AlertKind.callback,
      const Duration(minutes: 25),
      'Ravi K asked you to call',
      titleTe: 'రవి కె మీకు కాల్ చేయమని అడిగారు',
      farmerId: raviId,
      refId: raviCallbackId,
    );
    alert(
      'ravi-invoice',
      AlertKind.invoiceCheck,
      const Duration(hours: 1),
      'Invoice to check · Ravi K',
      titleTe: 'బిల్లు తనిఖీ · రవి కె',
      body: '₹3,600 · Sri Sai Agro · bill 1182 · Sample 5 SG × 2',
      farmerId: raviId,
      refId: sid('mock:invoice:1182'),
    );
    alert(
      'padma-invoice',
      AlertKind.invoiceCheck,
      const Duration(hours: 3),
      'Invoice to check · Padma S',
      titleTe: 'బిల్లు తనిఖీ · పద్మ ఎస్',
      body: '₹1,980 · Rythu Mitra · bill 0417 · Sample 50 WG',
      farmerId: padmaId,
      refId: sid('mock:invoice:0417'),
    );
    alert(
      'ho-note-kondapur',
      AlertKind.hoNote,
      const Duration(days: 1, hours: 2),
      'Pending enrolments',
      body: 'Please finish pending enrolments in Kondapur by Friday.',
    );
    alert(
      'padma-callback',
      AlertKind.callback,
      const Duration(days: 2, hours: 3),
      'Padma S asked you to call',
      titleTe: 'పద్మ ఎస్ మీకు కాల్ చేయమని అడిగారు',
      farmerId: padmaId,
      refId: sid('mock:callback:padma'),
      status: AlertStatus.acknowledged,
    );
    alert(
      'ho-note-meeting',
      AlertKind.hoNote,
      const Duration(days: 5),
      'Review meeting',
      titleTe: 'సమీక్ష సమావేశం',
      body: 'Monthly review at the Serilingampally office on Saturday, 10 am.',
      bodyTe:
          'శనివారం ఉదయం 10 గంటలకు శేరిలింగంపల్లి కార్యాలయంలో నెలవారీ '
          'సమీక్ష.',
      status: AlertStatus.acknowledged,
    );
    alert(
      'lakshmi-new',
      AlertKind.newFarmer,
      const Duration(days: 1, hours: 3),
      'Lakshmi N joined · Kondapur',
      titleTe: 'లక్ష్మి ఎన్ చేరారు · కొండాపూర్',
      farmerId: lakshmiId,
      refId: lakshmiId,
      status: AlertStatus.closed,
    );
    for (var i = 0; i < 6; i++) {
      alert(
        'old-$i',
        AlertKind.hoNote,
        Duration(days: 8 + i * 3),
        'Weekly plan $i',
        body: 'Plan your visits for the week.',
        status: AlertStatus.closed,
      );
    }
  }

  static const _moreNames = [
    ('Srinu', 'శ్రీను'),
    ('Ramesh', 'రమేష్'),
    ('Naveen', 'నవీన్'),
    ('Mahesh', 'మహేష్'),
    ('Prasad', 'ప్రసాద్'),
    ('Krishna', 'కృష్ణ'),
    ('Bhaskar', 'భాస్కర్'),
    ('Raghu', 'రఘు'),
    ('Satyam', 'సత్యం'),
    ('Yadagiri', 'యాదగిరి'),
    ('Mallaiah', 'మల్లయ్య'),
    ('Narayana', 'నారాయణ'),
    ('Chandra', 'చంద్ర'),
    ('Ramulu', 'రాములు'),
    ('Balaraju', 'బాలరాజు'),
    ('Sudhakar', 'సుధాకర్'),
    ('Anjaiah', 'అంజయ్య'),
    ('Kistaiah', 'కిష్టయ్య'),
    ('Laxmaiah', 'లక్ష్మయ్య'),
    ('Pochaiah', 'పోచయ్య'),
    ('Swamy', 'స్వామి'),
    ('Srisailam', 'శ్రీశైలం'),
    ('Jangaiah', 'జంగయ్య'),
    ('Venu', 'వేణు'),
    ('Kavitha', 'కవిత'),
    ('Sujatha', 'సుజాత'),
    ('Renuka', 'రేణుక'),
    ('Saroja', 'సరోజ'),
    ('Anitha', 'అనిత'),
    ('Bhagya', 'భాగ్య'),
    ('Manjula', 'మంజుల'),
    ('Radha', 'రాధ'),
    ('Lalitha', 'లలిత'),
    ('Jyothi', 'జ్యోతి'),
    ('Sunitha', 'సునీత'),
    ('Vani', 'వాణి'),
    ('Padmavathi', 'పద్మావతి'),
  ];

  static const _initials = [
    ('K', 'కె'),
    ('R', 'ఆర్'),
    ('M', 'ఎం'),
    ('S', 'ఎస్'),
    ('B', 'బి'),
    ('G', 'జి'),
    ('N', 'ఎన్'),
    ('P', 'పి'),
    ('T', 'టి'),
    ('V', 'వి'),
    ('Y', 'వై'),
    ('D', 'డి'),
  ];
}

// -----------------------------------------------------------------------------
// Server rows (mutable, private; the API sees them only through snap()).

final class _Account {
  _Account({
    required this.id,
    required this.code,
    required this.name,
    required this.nameTe,
    required this.phone,
    required this.password,
    required this.level,
    required this.languages,
    required this.workingHours,
    required this.villageIds,
    required this.createdAt,
  }) : updatedAt = createdAt;

  final String id;
  final String code;
  final String name;
  final String? nameTe;
  final String phone;
  String password;
  final AreaLevel level;
  final List<String> languages;
  final String? workingHours;
  final Set<String> villageIds;
  final DateTime createdAt;
  DateTime updatedAt;
  FaStatus status = FaStatus.active;
  bool mustChangePassword = false;
  DateTime? tempPasswordExpiresAt;
  DateTime? lastLoginAt;
  DateTime? lastSyncAt;

  FieldAssistant view({required DateTime? lastLoginAt}) => FieldAssistant(
    id: id,
    code: code,
    name: name,
    nameTe: nameTe,
    phone: phone,
    level: level,
    languages: List.unmodifiable(languages),
    workingHours: workingHours,
    photoKey: null,
    status: status,
    mustChangePassword: mustChangePassword,
    lastLoginAt: lastLoginAt,
    lastSyncAt: lastSyncAt,
    appVersion: null,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

final class _Device {
  _Device({required this.id, required this.key});

  final String id;
  final String key;
  String? faId;
  String? model;
  String? osVersion;
  String? appVersion;
  String? pushToken;
  DateTime? lastSeenAt;
}

final class _Farmer {
  _Farmer({
    required this.id,
    required this.phone,
    required this.name,
    required this.nameTe,
    required this.language,
    required this.villageId,
    required this.assignedFaId,
    required this.source,
    required this.photoKey,
    required this.plan,
    required this.status,
    required this.profileCompletedAt,
    required this.createdAt,
  }) : updatedAt = createdAt;

  final String id;
  final String phone;
  String? name;
  String? nameTe;
  Language language;
  String? villageId;
  String? assignedFaId;
  final FarmerSource source;
  String? photoKey;
  final Plan plan;
  FarmerStatus status;
  final Set<ConsentPurpose> consents = {};
  DateTime? profileCompletedAt;
  int version = 1;
  final DateTime createdAt;
  DateTime updatedAt;
  String? lastCommandId;

  void grant(Iterable<ConsentPurpose> purposes) => consents.addAll(purposes);

  SnapFarmer snap() => SnapFarmer(
    id: id,
    phone: phone,
    name: name,
    nameTe: nameTe,
    language: language,
    villageId: villageId,
    source: source,
    photoKey: photoKey,
    plan: plan,
    status: status,
    consentsGranted: [
      for (final p in ConsentPurpose.values)
        if (consents.contains(p)) p,
    ],
    consentPending: !consents.contains(ConsentPurpose.programme),
    profileCompletedAt: profileCompletedAt,
    version: version,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

final class _Plot {
  _Plot({
    required this.id,
    required this.farmerId,
    required this.label,
    required this.villageId,
    required this.boundaryGeoJson,
    required this.pin,
    required this.areaAcres,
    required this.areaSource,
    required this.gpsAccuracyM,
    required this.updatedAt,
  });

  final String id;
  final String farmerId;
  String label;
  final String? villageId;
  String? boundaryGeoJson;
  LatLng? pin;
  double areaAcres;
  AreaSource areaSource;
  double? gpsAccuracyM;
  PlotStatus status = PlotStatus.active;
  int version = 1;
  DateTime updatedAt;
  String? lastCommandId;

  SnapPlot snap() => SnapPlot(
    id: id,
    farmerId: farmerId,
    label: label,
    villageId: villageId,
    boundaryGeoJson: boundaryGeoJson,
    pin: pin,
    areaAcres: areaAcres,
    areaSource: areaSource,
    gpsAccuracyM: gpsAccuracyM,
    status: status,
    version: version,
    updatedAt: updatedAt,
  );
}

final class _Season {
  _Season({
    required this.id,
    required this.farmerId,
    required this.plotId,
    required this.seasonCode,
    required this.cropId,
    required this.sowingDate,
    required this.previousCropId,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String farmerId;
  final String plotId;
  final String seasonCode;
  final String cropId;
  final LocalDate? sowingDate;
  final String? previousCropId;
  SeasonStatus status;
  int version = 1;
  DateTime updatedAt;
  String? lastCommandId;

  SnapSeason snap() => SnapSeason(
    id: id,
    farmerId: farmerId,
    plotId: plotId,
    seasonCode: seasonCode,
    cropId: cropId,
    sowingDate: sowingDate,
    previousCropId: previousCropId,
    status: status,
    version: version,
    updatedAt: updatedAt,
  );
}

final class _VisitPhoto {
  _VisitPhoto(this.contentType, this.storageKey);

  final PhotoContentType contentType;
  final String storageKey;
  DateTime? uploadedAt;
  int? bytes;
  String? sha256;
}

final class _Visit {
  _Visit({
    required this.id,
    required this.farmerId,
    required this.plotId,
    required this.seasonId,
    required this.faId,
    required this.status,
    this.plannedFor,
    this.plannedSlot,
    this.purpose,
  });

  final String id;
  final String farmerId;
  final String plotId;
  final String seasonId;
  String faId;
  VisitStatus status;
  LocalDate? plannedFor;
  VisitSlot? plannedSlot;
  String? purpose;
  DateTime? visitedAt;
  LatLng? location;
  bool? farmerPresent;
  String? stageId;
  String? stageName;
  String? stageNameTe;
  String? notes;
  List<SnapVisitIssue> issues = const [];
  final Map<String, _VisitPhoto> photos = {};

  SnapVisit snap() => SnapVisit(
    id: id,
    farmerId: farmerId,
    plotId: plotId,
    seasonId: seasonId,
    faId: faId,
    status: status,
    plannedFor: plannedFor,
    plannedSlot: plannedSlot,
    purpose: purpose,
    visitedAt: visitedAt,
    farmerPresent: farmerPresent,
    stageId: stageId,
    stageName: stageName,
    stageNameTe: stageNameTe,
    notes: notes,
    photoCount: photos.length,
    issues: List.unmodifiable(issues),
  );
}

final class _Callback {
  _Callback({
    required this.id,
    required this.farmerId,
    required this.faId,
    required this.requestedAt,
  });

  final String id;
  final String farmerId;
  final String faId;
  final DateTime requestedAt;
  bool isOpen = true;
  DateTime? closedAt;
  String? note;

  SnapCallback snap() =>
      SnapCallback(id: id, farmerId: farmerId, requestedAt: requestedAt);
}

final class _Alert {
  _Alert({
    required this.id,
    required this.faId,
    required this.kind,
    required this.farmerId,
    required this.refId,
    required this.title,
    required this.body,
    required this.titleTe,
    required this.bodyTe,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String faId;
  final AlertKind kind;
  final String? farmerId;
  final String? refId;
  final String title;
  final String? body;
  final String? titleTe;
  final String? bodyTe;
  AlertStatus status;
  final DateTime createdAt;
  DateTime? acknowledgedAt;

  SnapAlert snap() => SnapAlert(
    id: id,
    faId: faId,
    kind: kind,
    farmerId: farmerId,
    refId: refId,
    title: title,
    body: body,
    titleTe: titleTe,
    bodyTe: bodyTe,
    status: status,
    createdAt: createdAt,
    acknowledgedAt: acknowledgedAt,
  );
}

final class _StoredCommand {
  const _StoredCommand(this.faId, this.result);

  final String faId;
  final CommandResult result;
}

final class _OtpChallenge {
  _OtpChallenge({
    required this.code,
    required this.language,
    required this.expiresAt,
  });

  final String code;

  /// The SMS language asked for.
  final Language language;
  final DateTime expiresAt;
  int attemptsLeft = 5;
}

final class _Proof {
  const _Proof({
    required this.faId,
    required this.phone,
    required this.verifiedAt,
    required this.expiresAt,
  });

  final String faId;
  final String phone;
  final DateTime verifiedAt;
  final DateTime expiresAt;
}

final class _Presigned {
  const _Presigned({
    required this.url,
    required this.storageKey,
    required this.contentType,
    required this.expiresAt,
  });

  final String url;
  final String storageKey;
  final PhotoContentType contentType;
  final DateTime expiresAt;
}

final class _MockToken {
  const _MockToken({
    required this.faId,
    required this.deviceId,
    required this.refreshToken,
    required this.family,
    required this.mustChangePassword,
  });

  final String faId;
  final String deviceId;
  final String refreshToken;

  /// The sign-in this token pair descends from (rotations keep it).
  final String family;

  /// The FA had a temporary password when this token was issued.
  final bool mustChangePassword;
}

/// A refresh token that was used: what it was swapped for, and when.
final class _Rotation {
  const _Rotation(this.successor, this.at, this.family, this.deviceId);

  final TokenPair successor;
  final DateTime at;
  final String family;
  final String deviceId;
}

final class _Principal {
  const _Principal(this.account, this.token, {required this.revoked});

  final _Account account;
  final _MockToken token;

  /// The device was removed by HO (only the heartbeat gets this far).
  final bool revoked;
}

/// One command being handled: its ID and the FA who sent it.
final class _Cmd {
  const _Cmd(this.id, this.fa);

  final String id;
  final _Account fa;
}

/// A business rule said no: the command is stored `rejected` with [reason].
final class _Rejection implements Exception {
  const _Rejection(this.reason);

  final String reason;
}

// -----------------------------------------------------------------------------
// Repositories.

/// What every mock repository shares: the backend, the session store, and
/// reporting failed signed-in calls to the [AuthFailureHook] from one place
/// (the API client's interceptor will do the same).
abstract base class _MockRepository {
  _MockRepository(this._backend, this._store, [this._authFailures]);

  final MockBackend _backend;
  final SessionStore _store;
  final AuthFailureHook? _authFailures;

  /// A signed-in call: [MockBackend._call] with the session read when the
  /// request starts (as an HTTP client reads the token it sends), reporting
  /// any [ApiError] with the FA whose session the call was made with.
  Future<T> _signedIn<T>(
    FutureOr<T> Function(StoredSession? session) body,
  ) async {
    StoredSession? session;
    try {
      session = await _store.readSession();
    } on Object {
      session = null;
    }
    try {
      return await _backend._call(() => body(session));
    } on ApiError catch (e) {
      _authFailures?.report(
        e,
        faId: session?.faId,
        sessionKey: session?.signInKey,
      );
      rethrow;
    }
  }

  /// A signed-in call that needs a normal FA token.
  Future<T> _asFa<T>(FutureOr<T> Function(_Account fa) body) =>
      _signedIn((session) => body(_backend._signedIn(session).account));
}

/// Mock [FaAuthRepository]: the mock logins, token rotation, password
/// change, heartbeat.
final class MockFaAuthRepository extends _MockRepository
    implements FaAuthRepository {
  /// Creates the repository over a backend and session store, reporting
  /// failed signed-in calls to the optional auth-failure hook.
  MockFaAuthRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<AppConfig> getAppConfig() => _backend._call(() => _backend._appConfig);

  @override
  Future<FaSession> login({
    required String code,
    required String password,
    required DeviceInfo device,
  }) => _backend._call(() => _backend._login(_store, code, password, device));

  @override
  Future<TokenPair> refreshSession() =>
      _signedIn((session) => _backend._refreshSession(_store, session));

  @override
  Future<void> logout() async {
    StoredSession? session;
    try {
      session = await _store.readSession();
      await _store.clear();
    } on Object {
      // The store is best effort here too.
    }
    try {
      await _backend._call(() => _backend._revoke(session));
    } on ApiError {
      // Best effort, like the real call: the local session is gone already.
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _signedIn(
    (session) =>
        _backend._changePassword(session, currentPassword, newPassword),
  );

  @override
  Future<DeviceStatus> heartbeat({
    String? model,
    String? osVersion,
    String? appVersion,
    String? pushToken,
  }) => _signedIn(
    (session) => _backend._heartbeat(
      session,
      model: model,
      osVersion: osVersion,
      appVersion: appVersion,
      pushToken: pushToken,
    ),
  );
}

/// Mock [SyncRepository]: snapshot with ETag, status, command push.
final class MockSyncRepository extends _MockRepository
    implements SyncRepository {
  /// Creates the repository.
  MockSyncRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<SnapshotResult> getSnapshot({String? ifNoneMatch}) => _asFa((fa) {
    final status = _backend._status(fa);
    if (ifNoneMatch != null && ifNoneMatch == status.etag) {
      return SnapshotNotModified(etag: status.etag);
    }
    final snapshot = _backend._snapshot(fa);
    return SnapshotFetched(snapshot: snapshot, etag: snapshot.etag);
  });

  @override
  Future<SyncStatus> getStatus() => _asFa(_backend._status);

  @override
  Future<CommandBatchResult> submitCommands(List<CommandIn> commands) =>
      _asFa((fa) => _backend._submit(fa, List.of(commands)));
}

/// Mock [EnrolmentRepository]: lookup, consent OTP `123456`, farmer photo
/// URL.
final class MockEnrolmentRepository extends _MockRepository
    implements EnrolmentRepository {
  /// Creates the repository.
  MockEnrolmentRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<PhoneLookup> lookupPhone(String phone) =>
      _asFa((fa) => _backend._lookup(fa, phone));

  @override
  Future<OtpSent> requestConsentOtp({
    required String phone,
    required Language language,
  }) => _asFa((fa) => _backend._requestConsentOtp(fa, phone, language));

  @override
  Future<ConsentProof> verifyConsentOtp({
    required String phone,
    required String code,
  }) => _asFa((fa) => _backend._verifyConsentOtp(fa, phone, code));

  @override
  Future<FarmerPhotoUpload> createFarmerPhotoUpload({
    required String farmerId,
    required PhotoContentType contentType,
    required int bytes,
  }) => _asFa(
    (fa) => _backend._farmerPhotoUpload(fa, farmerId, contentType, bytes),
  );
}

/// Mock [VisitPhotosRepository]: upload URL and confirm for photos of a
/// logged visit.
final class MockVisitPhotosRepository extends _MockRepository
    implements VisitPhotosRepository {
  /// Creates the repository.
  MockVisitPhotosRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<VisitPhotoUpload> createUploadUrl({
    required String visitId,
    required String photoId,
    required PhotoContentType contentType,
    required int bytes,
  }) => _asFa(
    (fa) =>
        _backend._visitPhotoUpload(fa, visitId, photoId, contentType, bytes),
  );

  @override
  Future<VisitPhoto> confirmUpload({
    required String visitId,
    required String photoId,
    String? sha256,
  }) =>
      _asFa((fa) => _backend._confirmVisitPhoto(fa, visitId, photoId, sha256));
}

/// Mock [AlertsRepository]: the FA's alerts, newest first, with the
/// farmer's name and phone.
final class MockAlertsRepository extends _MockRepository
    implements AlertsRepository {
  /// Creates the repository.
  MockAlertsRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<CursorPage<FaAlert>> listAlerts({
    AlertStatus? status,
    int? limit,
    String? cursor,
  }) => _asFa((fa) => _backend._listAlerts(fa, status, limit, cursor));
}

/// Mock [PhotoUploader]: accepts a PUT to a URL the mock handed out (and
/// not yet expired) and records the object, so `confirmUpload` finds it.
/// No auth header, no session: like the real presigned PUT.
final class MockPhotoUploader implements PhotoUploader {
  /// Creates the uploader over [backend].
  MockPhotoUploader(this._backend);

  final MockBackend _backend;

  @override
  Future<void> upload(PresignedUpload target, Uint8List bytes) =>
      _backend._call(() => _backend._put(target, bytes));
}
