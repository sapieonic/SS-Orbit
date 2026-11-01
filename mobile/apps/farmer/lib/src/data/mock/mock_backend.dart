/// All mock data and every `Mock*Repository`, in one file.
///
/// One [MockBackend] holds the in-memory state, so a call-back requested on
/// one screen shows on another, a granted consent sticks, and a completed
/// sign-up gets its FA. Behaviour follows the OpenAPI contract: same error
/// codes, same idempotency, same paging. The data mirrors the dev seed
/// (`backend/cmd/seed/main.go`, same UUIDs) and the farmer wireframes.
///
/// Dev only: `providers.dart` builds this only when `OrbitEnv.usesMock`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:orbit_core/orbit_core.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../session/auth_failures.dart';
import '../session/session_store.dart';

/// What the mock should pretend, so empty, offline and error states can be
/// shown and tested. Switch it at runtime with `MockBackend.scenario` (or the
/// `mockScenarioProvider` in `providers.dart`).
enum MockScenario {
  /// Seeded data, everything works.
  normal('Normal', 'Seeded data, everything works'),

  /// The farmer has no FA (`assigned_fa_id` and Home's FA card are null):
  /// Home shows "Your FA will call within 2 days", Look for FAs is empty,
  /// call-back gives `no_fa_assigned`.
  noFaAssigned('No FA assigned', 'Home without an FA, call-back refused'),

  /// No logged or planned visits: My visits shows "No visits yet".
  noVisits('No visits', 'My visits empty, no next visit'),

  /// Known phones sign in as `inactive` ("Account paused").
  accountPaused('Account paused', 'Seeded farmers are deactivated'),

  /// Every call throws `ApiError.network()` (no internet).
  offline('Offline', 'Every call fails with a network error'),

  /// Every call takes `MockBackend.slowLatency` (default 4 s).
  slowNetwork('Slow network', 'Every call is slow'),

  /// Every call throws 503 `unavailable`.
  serverError('Server error', 'Every call fails with 503'),

  /// The server ended the farmer's session (signed out elsewhere, or the
  /// session family revoked after a refresh token was reused): every
  /// signed-in call, refresh included, fails with 401 `unauthorized`, as the
  /// API client reports it once its refresh failed. Sign-in itself works.
  /// The app goes back to phone entry and keeps the install ID (unlike
  /// `device_revoked`, which HO sends for a revoked phone).
  sessionRevoked('Session revoked', 'Signed-in calls fail with 401');

  const MockScenario(this.label, this.description);

  /// Short English label for the dev switch.
  final String label;

  /// One line saying what changes.
  final String description;
}

/// In-memory backend behind the mock repositories.
///
/// ```dart
/// final backend = MockBackend(latency: Duration.zero); // tests
/// final repos = backend.repositories(InMemorySessionStore());
/// backend.scenario = MockScenario.offline; // takes effect on the next call
/// ```
class MockBackend {
  /// Creates a backend with the seeded data.
  ///
  /// [latency] is added to every call (zero in tests); [slowLatency] replaces
  /// it in [MockScenario.slowNetwork]. [random] makes generated IDs and tokens
  /// repeatable in tests.
  MockBackend({
    this.clock = const SystemClock(),
    this.latency = const Duration(milliseconds: 350),
    this.slowLatency = const Duration(seconds: 4),
    this.scenario = MockScenario.normal,
    math.Random? random,
  }) : _random = random ?? math.Random.secure() {
    _seed();
  }

  /// The fixed OTP, like the dev backend's `DEV_FIXED_OTP`.
  static const fixedOtp = '123456';

  /// Ravi K, Kondapur, cotton, FA Suresh (seeded, active).
  static const raviPhone = '+919000000101';

  /// Venkatesh M, Gachibowli, paddy, FA Suresh (seeded, active).
  static const venkateshPhone = '+919000000102';

  /// Consent notice version used by the seed.
  static const consentNoticeVersion = 'v1';

  /// Host of every URL the mock hands out (photos, uploads, audio). It never
  /// resolves: an upload helper or audio cache should skip URLs on this host
  /// in mock mode.
  static const mockHost = 'mock.orbit.invalid';

  /// Time source for OTP expiry, rate limits and relative seed dates.
  final Clock clock;
  final math.Random _random;

  /// Added to every call.
  Duration latency;

  /// Used instead of [latency] in [MockScenario.slowNetwork].
  Duration slowLatency;

  /// The current scenario; read on every call.
  MockScenario scenario;

  /// Builds the repositories over this backend. They read and write the
  /// session in [store], and report failed calls to [authFailures], like the
  /// API implementations will.
  FarmerRepositories repositories(
    SessionStore store, {
    AuthFailureHook? authFailures,
  }) => FarmerRepositories(
    auth: MockAuthRepository(this, store, authFailures),
    profile: MockFarmerProfileRepository(this, store, authFailures),
    fieldAssistants: MockFieldAssistantRepository(this, store, authFailures),
    visits: MockVisitsRepository(this, store, authFailures),
    notices: MockNoticesRepository(this, store, authFailures),
    geo: MockGeoRepository(this, store, authFailures),
    masters: MockMastersRepository(this, store, authFailures),
  );

  /// Drops every change and loads the seed again (keeps [scenario]).
  void reset() {
    _farmers.clear();
    _plots.clear();
    _seasons.clear();
    _consents.clear();
    _callbacks.clear();
    _visits.clear();
    _planned.clear();
    _notices.clear();
    _otps.clear();
    _otpSends.clear();
    _access.clear();
    _refresh.clear();
    _rotated.clear();
    _devices.clear();
    _photoUploads.clear();
    _seed();
  }

  /// Simulates the FA closing a call-back from the FA app (`CloseCallback`),
  /// so `callback_closed` can be shown.
  void simulateFaClosesCallback(String callbackId) {
    final c = _callbacks[callbackId];
    if (c == null || !c.isOpen) return;
    _callbacks[callbackId] = c.copyWith(
      status: CallbackStatus.closed,
      closedAt: clock.now(),
    );
  }

  /// The language of the last OTP SMS sent to [phone] (any common format), or
  /// null when no code is waiting: what the farmer would get the SMS in.
  Language? otpLanguage(String phone) {
    final e164 = normalizeIndianMobile(phone);
    return e164 == null ? null : _otps[e164]?.language;
  }

  // ---------------------------------------------------------------------------
  // State.

  final _farmers = <String, Farmer>{};
  final _plots = <String, Plot>{};
  final _seasons = <String, Season>{};
  final _consents = <String, Map<ConsentPurpose, CurrentConsent>>{};
  final _callbacks = <String, Callback>{};
  final _visits = <String, List<FarmerVisit>>{};
  final _planned = <String, PlannedVisit>{};
  final _notices = <String, List<Notice>>{};
  final _otps = <String, _OtpChallenge>{}; // phone -> live code
  final _otpSends = <String, List<DateTime>>{}; // phone -> send times
  final _access = <String, _MockToken>{};
  final _refresh = <String, String>{}; // live refresh token -> access token
  final _rotated = <String, _Rotation>{}; // used refresh token -> successor
  final _devices = <String, String>{}; // device key -> device ID
  final _photoUploads = <String, List<DateTime>>{}; // farmer -> request times

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
          MockScenario.noFaAssigned ||
          MockScenario.noVisits ||
          MockScenario.accountPaused ||
          MockScenario.slowNetwork ||
          MockScenario.sessionRevoked:
        return body();
    }
  }

  /// What a farmer gets once the server ended the session (signed out
  /// elsewhere, family revoked): the refresh fails, so the client reports
  /// this 401.
  static const _sessionEnded = ApiError(
    code: ApiErrorCode.unauthorized,
    message: 'session has ended; sign in again',
    status: 401,
  );

  /// The farmer whose access token the request sent ([session], read from the
  /// store when the request started, as an HTTP client does), or 401.
  Farmer _signedIn(StoredSession? session) {
    if (scenario == MockScenario.sessionRevoked) throw _sessionEnded;
    final token = session == null ? null : _access[session.tokens.accessToken];
    final farmer = token == null ? null : _farmers[token.farmerId];
    if (farmer == null) {
      throw const ApiError(
        code: ApiErrorCode.unauthorized,
        message: 'missing or invalid token',
        status: 401,
      );
    }
    return _view(farmer);
  }

  /// [_signedIn] plus the farmer-app write rule: deactivated farmers cannot
  /// change anything, pending sign-ups must complete their profile first.
  Farmer _signedInForWrite(StoredSession? session) {
    final f = _signedIn(session);
    switch (f.status) {
      case FarmerStatus.inactive:
        throw _forbidden('this farmer account is deactivated');
      case FarmerStatus.pendingProfile:
        throw const ApiError(
          code: ApiErrorCode.profileIncomplete,
          message: 'complete your profile first',
          status: 409,
        );
      case FarmerStatus.active || FarmerStatus.unknown:
        return f;
    }
  }

  /// The farmer as the current scenario shows them: deactivated in
  /// [MockScenario.accountPaused] (seeded farmers only), without an FA in
  /// [MockScenario.noFaAssigned]. Every response goes through this, so Home,
  /// Look for FAs and the call-back agree.
  Farmer _view(Farmer f) {
    final paused =
        scenario == MockScenario.accountPaused &&
        f.status == FarmerStatus.active &&
        f.source != FarmerSource.self;
    final noFa = scenario == MockScenario.noFaAssigned;
    if (!paused && !noFa) return f;
    return Farmer(
      id: f.id,
      phone: f.phone,
      name: f.name,
      nameTe: f.nameTe,
      language: f.language,
      villageId: f.villageId,
      mandalId: f.mandalId,
      districtId: f.districtId,
      assignedFaId: noFa ? null : f.assignedFaId,
      source: f.source,
      enrolledByFaId: f.enrolledByFaId,
      photoKey: f.photoKey,
      plan: f.plan,
      status: paused ? FarmerStatus.inactive : f.status,
      profileCompletedAt: f.profileCompletedAt,
      version: f.version,
      createdAt: f.createdAt,
      updatedAt: f.updatedAt,
    );
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

  static ApiError _conflict(
    String code,
    String message, [
    Map<String, Object?> details = const {},
  ]) => ApiError(code: code, message: message, status: 409, details: details);

  static ApiError _rateLimited(Duration retryAfter) => ApiError(
    code: ApiErrorCode.rateLimited,
    message: 'too many requests, try again later',
    status: 429,
    retryAfter: Duration(
      seconds: math.max(1, (retryAfter.inMilliseconds / 1000).ceil()),
    ),
  );

  static void _checkLimit(int? limit, int max) {
    if (limit != null && (limit < 1 || limit > max)) {
      throw _validation({'limit': 'must be between 1 and $max'});
    }
  }

  /// Keyset paging like the server (`backend/internal/platform/paging`):
  /// newest first on ([at], [id]), the cursor is base64url of
  /// `<unix-nanos>:<uuid>` (unpadded, Go's `RawURLEncoding`) after the last
  /// row returned; an empty cursor is the first page. A cursor that parses
  /// but matches no row (data changed, e.g. a scenario switch) still pages
  /// from its position, often to an empty last page; only a malformed one is
  /// `invalid_cursor`.
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

  /// Unpadded base64url, as Go's `base64.RawURLEncoding` takes it: no `=`,
  /// no `+` or `/`, and no length that leaves a lone 6-bit group.
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
      // Dart's decoder wants the padding the server's cursors leave out.
      raw = utf8.decode(base64Url.decode(base64Url.normalize(cursor)));
    } on FormatException {
      throw invalid;
    }
    final colon = raw.indexOf(':');
    final nanos = colon < 0 ? null : int.tryParse(raw.substring(0, colon));
    final id = colon < 0 ? '' : raw.substring(colon + 1).toLowerCase();
    const maxMicros = 8640000000000000; // DateTime's range
    if (nanos == null || (nanos ~/ 1000).abs() > maxMicros) throw invalid;
    if (!_uuid.hasMatch(id)) throw invalid;
    return (
      DateTime.fromMicrosecondsSinceEpoch(nanos ~/ 1000, isUtc: true),
      id,
    );
  }

  // ---------------------------------------------------------------------------
  // Auth.

  Future<OtpSent> _requestOtp(String phone, Language language) async {
    final e164 = normalizeIndianMobile(phone);
    if (e164 == null) {
      throw _validation({'phone': 'must be a 10-digit Indian mobile number'});
    }
    final now = _now;
    // The send limits count every SMS to the phone, whether or not a code
    // was used since: a sign-in does not reset them.
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
    _otps[e164] = _OtpChallenge(
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

  Future<FarmerSession> _verifyOtp(
    SessionStore store,
    String phone,
    String code,
    DeviceInfo device,
  ) async {
    final e164 = normalizeIndianMobile(phone);
    final fields = <String, String>{
      if (e164 == null) 'phone': 'must be a 10-digit Indian mobile number',
      if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) 'code': 'must be 6 digits',
      if (!RegExp(r'^[A-Za-z0-9._:-]{8,128}$').hasMatch(device.deviceKey))
        'device.device_key': 'invalid',
    };
    if (fields.isNotEmpty) throw _validation(fields);
    final challenge = _otps[e164!];
    if (challenge == null ||
        !_now.isBefore(challenge.expiresAt) ||
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
    _otps.remove(e164);

    var farmer = _farmers.values.where((f) => f.phone == e164).firstOrNull;
    final isNew = farmer == null;
    if (farmer == null) {
      farmer = Farmer(
        id: _newId(),
        phone: e164,
        name: null,
        nameTe: null,
        language: Language.te,
        villageId: null,
        mandalId: null,
        districtId: null,
        assignedFaId: null,
        source: FarmerSource.self,
        enrolledByFaId: null,
        photoKey: null,
        plan: Plan.free,
        status: FarmerStatus.pendingProfile,
        profileCompletedAt: null,
        version: 1,
        createdAt: _now,
        updatedAt: _now,
      );
      _farmers[farmer.id] = farmer;
    }
    final deviceId = _devices.putIfAbsent(device.deviceKey, _newId);
    final tokens = _issueTokens(farmer.id, deviceId, family: _newId());
    await store.writeSession(
      StoredSession(tokens: tokens, farmerId: farmer.id, deviceId: deviceId),
    );
    return FarmerSession(
      tokens: tokens,
      farmerId: farmer.id,
      deviceId: deviceId,
      isNew: isNew,
      farmerStatus: _view(farmer).status,
    );
  }

  TokenPair _issueTokens(
    String farmerId,
    String deviceId, {
    required String family,
  }) {
    final access = 'mock-access-${_newId()}';
    final refresh = 'mock-refresh-${_newId()}';
    _access[access] = _MockToken(farmerId, deviceId, refresh, family);
    _refresh[refresh] = access;
    final now = _now;
    return TokenPair(
      accessToken: access,
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      refreshToken: refresh,
      refreshExpiresAt: now.add(const Duration(days: 90)),
    );
  }

  /// Rotation like the server (`identity/service_sessions.go`): each refresh
  /// token works once; a retry with the used token within [_refreshGrace]
  /// gets the same successor; any later reuse ends the whole session
  /// (`refresh_reused`). [session] is what the request sent.
  Future<TokenPair> _refreshSession(
    SessionStore store,
    StoredSession? session,
  ) async {
    if (scenario == MockScenario.sessionRevoked) throw _sessionEnded;
    final used = session?.tokens.refreshToken;
    final access = used == null ? null : _refresh[used];
    final token = access == null ? null : _access[access];
    final TokenPair tokens;
    if (token != null) {
      // The old access token keeps working until the session ends, like the
      // server's JWTs, so a call already on the wire is not refused.
      _refresh.remove(used);
      tokens = _issueTokens(
        token.farmerId,
        token.deviceId,
        family: token.family,
      );
      _rotated[used!] = _Rotation(tokens, _now, token.family);
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
    await store.writeSession(session!.withTokens(tokens));
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

  /// Ends a session family: its tokens stop working and a used refresh token
  /// of it is then just invalid (401 `unauthorized`).
  void _revokeFamily(String family) {
    _access.removeWhere((access, t) {
      if (t.family != family) return false;
      _refresh.remove(t.refreshToken);
      return true;
    });
    _rotated.removeWhere((_, r) => r.family == family);
  }

  // ---------------------------------------------------------------------------
  // Farmer.

  FarmerHome _home(Farmer f) {
    final village = f.villageId == null ? null : _villages[f.villageId];
    final faId = f.assignedFaId;
    final plots =
        _plots.values
            .where((p) => p.farmerId == f.id && p.status == PlotStatus.active)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final planned = _planned[f.id];
    final showPlanned =
        planned != null &&
        scenario != MockScenario.noVisits &&
        !planned.plannedFor.isBefore(_today);
    return FarmerHome(
      farmer: f,
      photoUrl: f.photoKey == null
          ? null
          : 'https://$mockHost/files/${f.photoKey}',
      village: village == null
          ? null
          : FarmerVillage(
              id: village.id,
              name: village.name,
              nameTe: village.nameTe,
              mandalId: village.mandalId,
              mandalName: village.mandalName,
              mandalNameTe: village.mandalNameTe,
              districtId: village.districtId,
              districtName: village.districtName,
              districtNameTe: village.districtNameTe,
            ),
      plots: List.unmodifiable(plots.map(_homePlot)),
      fa: faId == null ? null : _faCards[faId],
      nextVisit: showPlanned ? planned : null,
    );
  }

  HomePlot _homePlot(Plot p) {
    final season = _activeSeason(p.id);
    final sown = season?.sowingDate;
    final das = sown?.daysUntil(_today);
    final crop = season == null ? null : _crops[season.cropId];
    return HomePlot(
      plot: p,
      activeSeason: season,
      daysAfterSowing: das, // negative before a future sowing date
      currentStage: das == null || crop == null ? null : _stageOn(crop, das),
    );
  }

  /// The stage the server shows for day [das] of [crop] (masters
  /// `pickStage`): none before sowing; from sowing on the first stage until
  /// a later one starts, so past the last stage it stays on the last one.
  static Stage? _stageOn(FarmerCrop crop, int das) {
    if (das < 0 || crop.stages.isEmpty) return null;
    var stage = crop.stages.first;
    for (final s in crop.stages.skip(1)) {
      if (s.startDay <= das) stage = s;
    }
    return stage;
  }

  Season? _activeSeason(String plotId) => _seasons.values
      .where((s) => s.plotId == plotId && s.status == SeasonStatus.active)
      .firstOrNull;

  static Map<String, String> _profileErrors({
    String? name,
    String? nameTe,
    bool nameRequired = false,
  }) => {
    if ((name == null && nameRequired) ||
        (name != null && (name.trim().isEmpty || name.trim().length > 100)))
      'name': nameRequired && name == null
          ? 'required'
          : 'must be 1-100 characters',
    if (nameTe != null && (nameTe.trim().isEmpty || nameTe.trim().length > 100))
      'name_te': 'must be 1-100 characters',
  };

  Farmer _save(Farmer f) {
    final saved = f.copyWith(version: f.version + 1, updatedAt: _now);
    _farmers[f.id] = saved;
    return _view(saved);
  }

  List<CurrentConsent> _consentList(String farmerId) {
    final given = _consents[farmerId] ?? const {};
    return List.unmodifiable([
      for (final p in ConsentPurpose.values)
        if (p != ConsentPurpose.unknown)
          given[p] ??
              CurrentConsent(
                purpose: p,
                granted: null,
                method: null,
                noticeVersion: null,
                updatedAt: null,
              ),
    ]);
  }

  /// FAs covering [villageId]: village level first, then mandal, then
  /// district; leads first within a level; inactive FAs left out.
  List<_Coverage> _coverage(String villageId) {
    final v = _villages[villageId];
    if (v == null) return const [];
    final out = <_Coverage>[];
    for (final level in [
      AreaLevel.village,
      AreaLevel.mandal,
      AreaLevel.district,
    ]) {
      final areaId = switch (level) {
        AreaLevel.village => v.id,
        AreaLevel.mandal => v.mandalId,
        _ => v.districtId,
      };
      final here = _allocations
          .where((a) => a.level == level && a.areaId == areaId)
          .where((a) => _faCards[a.faId]?.status != FaStatus.inactive)
          .where((a) => !out.any((c) => c.faId == a.faId))
          .toList();
      // Leads first, otherwise in seed order (List.sort is not stable).
      for (final lead in [true, false]) {
        out.addAll([
          for (final a in here)
            if (a.isLead == lead) _Coverage(a.faId, level, a.isLead),
        ]);
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Seed data. IDs are the dev seed's UUIDv5 values (sid("village:kondapur")
  // etc.), so mock and dev data line up; "mock:" names are mock-only extras.

  static const _otpTtl = Duration(minutes: 5);
  static const _otpResendAfter = Duration(seconds: 30);
  static const _otpSendsPerHour = 5;
  static const _refreshGrace = Duration(seconds: 60);

  static const _districtRangareddy = '2ff4788d-4196-5722-aebd-bb4de84ec508';
  static const _mandalSerilingampally = 'ddceffa2-9f9e-57ee-aa01-f590d68ec90a';
  static const _mandalChevella = '44412dfe-1e08-53e9-b33e-3134de5109f9';
  static const _villageKondapur = '7ffb9494-9f19-5bbf-89c8-85c80065689f';
  static const _villageGachibowli = 'd1b8347f-1108-5cc1-9e0a-f86f954b53d2';
  static const _villageMadhapur = '27a6b4a8-1cc2-56bb-acc4-0c24f5d15531';
  static const _villageChevella = '534c5855-92a2-5c60-9c77-87481fe0391a';
  static const _villageMudimyal = 'c6f9388f-99b5-5f63-944b-89c10dfb2d6e';
  static const _faSuresh = 'cd061e24-7768-5040-a5b7-41fdb8b75a4d';
  static const _faLakshmi = '832d37d5-3333-5eb5-8a5d-400bcd8103f8';
  static const _faRamesh = '09503fad-4933-54ee-8628-38c310c6c21d';
  static const _faAnitha = '326426dd-d879-5956-8710-94c11975a2f6';
  static const _cropCotton = '1106d3cf-9699-5763-b4c9-9835673912f7';
  static const _cropPaddy = '4ae32698-2805-5dfd-9988-90bbb99f09fa';
  static const _cropChilli = '5c2df495-548c-580f-a3c8-5cd568a3584c';
  static const _skuEb250 = '760085b0-26c8-5a99-aa9c-3da6cd517b21';
  static const _skuIm100 = 'c92cfc9a-6900-50be-a5a6-37c511416a5a';
  static const _skuFl60 = 'ab451b02-dc75-55fe-98d8-be157e8dca90';
  static const _farmerRavi = '0eeadea4-ce8c-518b-8d28-24b80819d868';
  static const _farmerVenkatesh = 'ee0b43e6-4bc5-599c-bdd7-ab52d9f74450';
  static const _plotRavi = '99d707d8-1d63-59ea-bf0e-ada3da7dd10d';
  static const _plotVenkatesh = 'c015307b-682a-5887-9e48-0a2b8497535d';
  static const _seasonRavi = '832fd852-3826-5dbe-b65a-de1ef9fbcc28';
  static const _seasonVenkatesh = '33bfb67a-fb9d-586c-88db-d22d9a4f2e64';
  static const _plannedRavi = '9f0d0808-f2a6-5954-a83d-b9ece9408d00';

  static final _seededAt = DateTime.utc(2026, 6, 15, 4, 30);

  // Master data is shared by every MockBackend and survives reset(), so it is
  // deeply unmodifiable.

  static final Map<String, Village> _villages = Map.unmodifiable(
    <String, Village>{
      for (final v in [
        _village(
          _villageKondapur,
          'Kondapur',
          'కొండాపూర్',
          17.4600,
          78.3570,
          serilingampally: true,
        ),
        _village(
          _villageGachibowli,
          'Gachibowli',
          'గచ్చిబౌలి',
          17.4401,
          78.3489,
          serilingampally: true,
        ),
        _village(
          _villageMadhapur,
          'Madhapur',
          'మాదాపూర్',
          17.4483,
          78.3915,
          serilingampally: true,
        ),
        _village(
          _villageChevella,
          'Chevella',
          'చేవెళ్ల',
          17.3067,
          78.1353,
          serilingampally: false,
        ),
        _village(
          _villageMudimyal,
          'Mudimyal',
          'ముడిమ్యాల్',
          17.3300,
          78.1000,
          serilingampally: false,
        ),
      ])
        v.id: v,
    },
  );

  static Village _village(
    String id,
    String name,
    String nameTe,
    double lat,
    double lng, {
    required bool serilingampally,
  }) => Village(
    id: id,
    name: name,
    nameTe: nameTe,
    lgdCode: null,
    lat: lat,
    lng: lng,
    mandalId: serilingampally ? _mandalSerilingampally : _mandalChevella,
    mandalName: serilingampally ? 'Serilingampally' : 'Chevella',
    mandalNameTe: serilingampally ? 'శేరిలింగంపల్లి' : 'చేవెళ్ల',
    districtId: _districtRangareddy,
    districtName: 'Rangareddy',
    districtNameTe: 'రంగారెడ్డి',
    createdAt: _seededAt,
  );

  static const _faCards = <String, FarmerFaCard>{
    _faSuresh: FarmerFaCard(
      id: _faSuresh,
      code: 'FA-KDP-014',
      name: 'Suresh K',
      nameTe: 'సురేష్ కె',
      phone: '+919000000014',
      level: AreaLevel.village,
      languages: ['te', 'en'],
      workingHours: 'Mon-Sat 8am-5pm',
      photoKey: null,
      status: FaStatus.active,
    ),
    _faLakshmi: FarmerFaCard(
      id: _faLakshmi,
      code: 'FA-CVL-002',
      name: 'Lakshmi P',
      nameTe: 'లక్ష్మి పి',
      phone: '+919000000002',
      level: AreaLevel.mandal,
      languages: ['te'],
      workingHours: 'Mon-Sat 7am-4pm',
      photoKey: null,
      status: FaStatus.active,
    ),
    // Mock-only, so the mandal and district tabs of Look for FAs have rows.
    _faRamesh: FarmerFaCard(
      id: _faRamesh,
      code: 'FA-SLP-003',
      name: 'Ramesh B',
      nameTe: 'రమేష్ బి',
      phone: '+919000000003',
      level: AreaLevel.mandal,
      languages: ['te'],
      workingHours: 'Mon-Fri 9am-5pm',
      photoKey: null,
      status: FaStatus.active,
    ),
    _faAnitha: FarmerFaCard(
      id: _faAnitha,
      code: 'FA-RR-001',
      name: 'Anitha R',
      nameTe: 'అనిత ఆర్',
      phone: '+919000000004',
      level: AreaLevel.district,
      languages: ['te', 'en'],
      workingHours: 'Mon-Sat 9am-6pm',
      photoKey: null,
      status: FaStatus.active,
    ),
  };

  static const _allocations = [
    _Allocation(_faSuresh, AreaLevel.village, _villageKondapur, isLead: true),
    _Allocation(_faSuresh, AreaLevel.village, _villageGachibowli, isLead: true),
    _Allocation(_faLakshmi, AreaLevel.mandal, _mandalChevella, isLead: true),
    _Allocation(
      _faRamesh,
      AreaLevel.mandal,
      _mandalSerilingampally,
      isLead: false,
    ),
    _Allocation(
      _faAnitha,
      AreaLevel.district,
      _districtRangareddy,
      isLead: false,
    ),
  ];

  static Stage _stage(
    String crop,
    int seq,
    String code,
    String name,
    String nameTe,
    int start,
    int end,
  ) => Stage(
    id: _stageIds['$crop:$code']!,
    code: code,
    name: name,
    nameTe: nameTe,
    seq: seq,
    startDay: start,
    endDay: end,
  );

  static const _stageIds = {
    'cotton:seedling': '353c2f57-47a8-5eba-91cb-28731ca0678c',
    'cotton:square': 'cd04cdc6-a8ff-50f2-b193-00b0646c7bcc',
    'cotton:flowering': '5323a9b3-1d88-553f-af4c-d7885255125b',
    'cotton:boll': 'fae00074-b4ec-57af-be25-67f7183b7373',
    'cotton:picking': '7e582614-fd07-5760-97cc-d4a9e39faf33',
    'paddy:nursery': '05f2f897-9e22-5807-b734-d1d381f3f6b1',
    'paddy:tillering': 'ca2e5a30-b786-5004-ade4-76b962ef4fdd',
    'paddy:panicle': 'd011a66c-5a24-546a-8769-e8d34cd0a3ab',
    'paddy:maturity': '1549f917-5039-50cd-9d96-1eed3f047896',
    'chilli:seedling': '96de64e1-9e57-53b5-bfd3-a8329865456c',
    'chilli:vegetative': '891ddffd-d76a-5f40-bd34-b26cc133944b',
    'chilli:flowering': 'ff85281f-814e-526e-b11f-b95c5ee3e414',
    'chilli:fruiting': '3bf02160-a04f-52ee-854c-17ea16f550fc',
  };

  static final Map<String, FarmerCrop> _crops = Map.unmodifiable(
    <String, FarmerCrop>{
      _cropCotton: FarmerCrop(
        id: _cropCotton,
        code: 'cotton',
        nameTe: 'పత్తి',
        name: 'Cotton',
        durationDays: 160,
        stages: List.unmodifiable([
          _stage('cotton', 1, 'seedling', 'Seedling', 'మొలక దశ', 0, 20),
          _stage('cotton', 2, 'square', 'Square formation', 'మొగ్గ దశ', 21, 50),
          _stage('cotton', 3, 'flowering', 'Flowering', 'పూత దశ', 51, 80),
          _stage('cotton', 4, 'boll', 'Boll development', 'కాయ దశ', 81, 120),
          _stage('cotton', 5, 'picking', 'Picking', 'తీత దశ', 121, 160),
        ]),
      ),
      _cropPaddy: FarmerCrop(
        id: _cropPaddy,
        code: 'paddy',
        nameTe: 'వరి',
        name: 'Paddy',
        durationDays: 120,
        stages: List.unmodifiable([
          _stage('paddy', 1, 'nursery', 'Nursery', 'నారుమడి', 0, 25),
          _stage('paddy', 2, 'tillering', 'Tillering', 'పిలకల దశ', 26, 55),
          _stage(
            'paddy',
            3,
            'panicle',
            'Panicle initiation',
            'పొట్ట దశ',
            56,
            85,
          ),
          _stage(
            'paddy',
            4,
            'maturity',
            'Grain filling and maturity',
            'గింజ దశ',
            86,
            120,
          ),
        ]),
      ),
      _cropChilli: FarmerCrop(
        id: _cropChilli,
        code: 'chilli',
        nameTe: 'మిరప',
        name: 'Chilli',
        durationDays: 150,
        stages: List.unmodifiable([
          _stage('chilli', 1, 'seedling', 'Seedling', 'మొలక దశ', 0, 30),
          _stage('chilli', 2, 'vegetative', 'Vegetative', 'ఎదుగుదల దశ', 31, 60),
          _stage('chilli', 3, 'flowering', 'Flowering', 'పూత దశ', 61, 90),
          _stage(
            'chilli',
            4,
            'fruiting',
            'Fruiting and picking',
            'కాయ దశ',
            91,
            150,
          ),
        ]),
      ),
    },
  );

  static const _dealers = [
    _Dealer(
      NearbyDealer(
        id: '24fdcf83-c503-5e2f-84a5-4d9a2618739c',
        nameTe: 'శ్రీ సాయి ఆగ్రో ట్రేడర్స్',
        name: 'Sri Sai Agro Traders',
        phone: '+919000000501',
        location: LatLng(17.4621, 78.3591),
        distanceM: 0,
      ),
      {_skuEb250, _skuIm100},
    ),
    _Dealer(
      NearbyDealer(
        id: 'f99a4e40-f917-50cd-9fa2-82da8738c908',
        nameTe: 'రైతు మిత్ర ట్రేడర్స్',
        name: 'Raithu Mitra Traders',
        phone: '+919000000502',
        location: LatLng(17.4870, 78.3720),
        distanceM: 0,
      ),
      {_skuEb250, _skuFl60},
    ),
  ];

  static const _suresh = FaName(
    id: _faSuresh,
    name: 'Suresh K',
    nameTe: 'సురేష్ కె',
  );

  static const _pinkBollworm = FarmerAdvice(
    issueName: 'Pink bollworm',
    issueNameTe: 'గులాబీ రంగు పురుగు',
    severity: Severity.moderate,
    advicePending: false,
    saltName: 'Emamectin benzoate 5% SG',
    saltNameTe: 'ఎమామెక్టిన్ బెంజోయేట్ 5% SG',
    skuId: _skuEb250,
    productName: 'Sample 5 SG',
    productNameTe: 'శాంపిల్ 5 SG',
    dose: '80 g in 200 L water per acre',
    doseTe: 'ఎకరానికి 200 లీ. నీటిలో 80 గ్రా.',
    saltOnly: false,
  );

  static const _suckingPests = FarmerAdvice(
    issueName: 'Sucking pests',
    issueNameTe: 'రసం పీల్చే పురుగులు',
    severity: Severity.low,
    advicePending: false,
    saltName: 'Flonicamid 50% WG',
    saltNameTe: 'ఫ్లోనికామిడ్ 50% WG',
    skuId: _skuFl60,
    productName: 'Sample 50 WG',
    productNameTe: 'శాంపిల్ 50 WG',
    dose: '60 g in 200 L water per acre',
    doseTe: 'ఎకరానికి 200 లీ. నీటిలో 60 గ్రా.',
    saltOnly: false,
  );

  static const _leafSpot = FarmerAdvice(
    issueName: 'Leaf spot',
    issueNameTe: 'ఆకు మచ్చ తెగులు',
    severity: Severity.moderate,
    advicePending: false,
    saltName: 'Mancozeb 75% WP',
    saltNameTe: 'మాంకోజెబ్ 75% WP',
    skuId: null,
    productName: null,
    productNameTe: null,
    dose: '600 g in 200 L water per acre',
    doseTe: 'ఎకరానికి 200 లీ. నీటిలో 600 గ్రా.',
    saltOnly: true,
  );

  static const _whiteflyPending = FarmerAdvice(
    issueName: 'Whitefly',
    issueNameTe: 'తెల్ల దోమ',
    severity: Severity.low,
    advicePending: true,
    saltName: null,
    saltNameTe: null,
    skuId: null,
    productName: null,
    productNameTe: null,
    dose: null,
    doseTe: null,
    saltOnly: false,
  );

  void _seed() {
    final now = _now;
    _farmers
      ..[_farmerRavi] = Farmer(
        id: _farmerRavi,
        phone: raviPhone,
        name: 'Ravi K',
        nameTe: 'రవి కె',
        language: Language.te,
        villageId: _villageKondapur,
        mandalId: _mandalSerilingampally,
        districtId: _districtRangareddy,
        assignedFaId: _faSuresh,
        source: FarmerSource.fa,
        enrolledByFaId: _faSuresh,
        photoKey: null,
        plan: Plan.free,
        status: FarmerStatus.active,
        profileCompletedAt: _seededAt,
        version: 1,
        createdAt: _seededAt,
        updatedAt: _seededAt,
      )
      ..[_farmerVenkatesh] = Farmer(
        id: _farmerVenkatesh,
        phone: venkateshPhone,
        name: 'Venkatesh M',
        nameTe: 'వెంకటేష్ ఎం',
        language: Language.te,
        villageId: _villageGachibowli,
        mandalId: _mandalSerilingampally,
        districtId: _districtRangareddy,
        assignedFaId: _faSuresh,
        source: FarmerSource.fa,
        enrolledByFaId: _faSuresh,
        photoKey: null,
        plan: Plan.free,
        status: FarmerStatus.active,
        profileCompletedAt: _seededAt,
        version: 1,
        createdAt: _seededAt,
        updatedAt: _seededAt,
      );
    for (final id in [_farmerRavi, _farmerVenkatesh]) {
      _consents[id] = {
        ConsentPurpose.programme: CurrentConsent(
          purpose: ConsentPurpose.programme,
          granted: true,
          method: ConsentMethod.faOtp,
          noticeVersion: consentNoticeVersion,
          updatedAt: _seededAt,
        ),
      };
    }
    _plots
      ..[_plotRavi] = Plot(
        id: _plotRavi,
        farmerId: _farmerRavi,
        label: 'Plot 1',
        villageId: _villageKondapur,
        boundary: null,
        pin: const LatLng(17.4612, 78.3555),
        areaAcres: 2.5,
        areaSource: AreaSource.typed,
        gpsAccuracyM: null,
        status: PlotStatus.active,
        version: 1,
        createdAt: _seededAt,
        updatedAt: _seededAt,
      )
      ..[_plotVenkatesh] = Plot(
        id: _plotVenkatesh,
        farmerId: _farmerVenkatesh,
        label: 'Plot 1',
        villageId: _villageGachibowli,
        boundary: null,
        pin: const LatLng(17.4390, 78.3470),
        areaAcres: 1.75,
        areaSource: AreaSource.typed,
        gpsAccuracyM: null,
        status: PlotStatus.active,
        version: 1,
        createdAt: _seededAt,
        updatedAt: _seededAt,
      );
    _seasons
      ..[_seasonRavi] = Season(
        id: _seasonRavi,
        farmerId: _farmerRavi,
        plotId: _plotRavi,
        seasonCode: 'kharif-2026',
        cropId: _cropCotton,
        sowingDate: LocalDate(2026, 7, 1),
        previousCropId: null,
        status: SeasonStatus.active,
        version: 1,
        createdAt: _seededAt,
        updatedAt: _seededAt,
      )
      ..[_seasonVenkatesh] = Season(
        id: _seasonVenkatesh,
        farmerId: _farmerVenkatesh,
        plotId: _plotVenkatesh,
        seasonCode: 'rabi-2026-27',
        cropId: _cropPaddy,
        sowingDate: LocalDate(2026, 10, 10),
        previousCropId: null,
        status: SeasonStatus.active,
        version: 1,
        createdAt: _seededAt,
        updatedAt: _seededAt,
      );
    _planned[_farmerRavi] = PlannedVisit(
      visitId: _plannedRavi,
      faId: _faSuresh,
      plotId: _plotRavi,
      seasonId: _seasonRavi,
      plannedFor: _today.addDays(1),
      plannedSlot: PlannedSlot.morning,
      purpose: 'Check bollworm traps',
    );

    FarmerVisit visit(
      String id,
      DateTime at,
      String stage,
      String stageTe,
      List<FarmerAdvice> issues,
    ) => FarmerVisit(
      id: id,
      plotId: _plotRavi,
      visitedAt: at,
      fa: _suresh,
      stageName: stage,
      stageNameTe: stageTe,
      issues: issues,
    );
    // Stage names follow the cotton calendar from sowing on 1 Jul 2026 (the
    // day count is in each comment), as the server stamps them at the visit.
    _visits[_farmerRavi] = [
      visit(
        '4ab75e76-0167-5a52-8020-cdc3c833f2dc',
        DateTime.utc(2026, 10, 12, 5), // day 103
        'Boll development',
        'కాయ దశ',
        const [_pinkBollworm],
      ),
      visit(
        'c3d8bfe4-ee36-5044-a42c-fd0277e26d8a',
        DateTime.utc(2026, 9, 28, 4, 30), // day 89
        'Boll development',
        'కాయ దశ',
        const [_suckingPests],
      ),
      visit(
        '1673bc71-79d0-59fe-96e9-7934c6df81e6',
        DateTime.utc(2026, 9, 9, 6), // day 70
        'Flowering',
        'పూత దశ',
        const [_leafSpot],
      ),
      visit(
        '2b836a40-793f-58d9-ad69-760ea0bd46af',
        DateTime.utc(2026, 8, 20, 5, 15), // day 50
        'Square formation',
        'మొగ్గ దశ',
        const [_whiteflyPending],
      ),
      visit(
        '695f04d4-01d2-51eb-a2ce-24a6b6ce27da',
        DateTime.utc(2026, 7, 25, 4), // day 24
        'Square formation',
        'మొగ్గ దశ',
        const [],
      ),
    ];

    Notice notice({
      required String id,
      required NoticeKind kind,
      required NoticeSender sender,
      required String titleTe,
      required String bodyTe,
      required String titleEn,
      required String bodyEn,
      required Duration age,
      bool audio = false,
      bool pinned = false,
      bool read = false,
      bool listened = false,
      String? refType,
      String? refId,
    }) {
      final at = now.subtract(age);
      return Notice(
        id: id,
        kind: kind,
        sender: sender,
        titleTe: titleTe,
        bodyTe: bodyTe,
        titleEn: titleEn,
        bodyEn: bodyEn,
        audioUrl: audio ? 'https://$mockHost/audio/$id.m4a' : null,
        refType: refType,
        refId: refId,
        pinned: pinned,
        readAt: read || listened ? at.add(const Duration(hours: 3)) : null,
        listenedAt: listened ? at.add(const Duration(hours: 3)) : null,
        createdAt: at,
      );
    }

    _notices[_farmerRavi] = [
      notice(
        id: 'b6251894-3842-53dc-aafe-406269497f57',
        kind: NoticeKind.advisory,
        sender: NoticeSender.ho,
        titleTe: 'గులాబీ రంగు పురుగు జాగ్రత్త',
        bodyTe: 'ఈ వారం లింగాకర్షక బుట్టలు పెట్టండి',
        titleEn: 'Pink bollworm watch',
        bodyEn: 'Set pheromone traps this week.',
        age: const Duration(hours: 2),
        audio: true,
      ),
      notice(
        id: '7d6932d5-c1df-565f-9a5b-822c3f085304',
        kind: NoticeKind.advisory,
        sender: NoticeSender.civ,
        titleTe: 'గురువారం వర్షం',
        bodyTe: 'వర్షం తర్వాత 2 రోజులు పిచికారీ చేయవద్దు',
        titleEn: 'Rain on Thursday',
        bodyEn: 'Do not spray for 2 days after the rain.',
        age: const Duration(days: 1),
        audio: true,
      ),
      notice(
        id: '73d9ad83-f57e-5b12-adc8-6a11bf1aac41',
        kind: NoticeKind.visitAdvice,
        sender: NoticeSender.fa,
        titleTe: 'మీ పత్తి కాయ దశలో ఉంది',
        bodyTe: 'FA చెప్పినట్లు పొటాష్ వేయండి',
        titleEn: 'Your cotton is at the boll stage',
        bodyEn: 'Apply potash as your FA advised.',
        age: const Duration(days: 4),
        pinned: true,
        refType: 'visit',
        refId: '4ab75e76-0167-5a52-8020-cdc3c833f2dc',
      ),
      notice(
        id: '0413afad-c331-5861-abed-16c4aa152900',
        kind: NoticeKind.visitAdvice,
        sender: NoticeSender.fa,
        titleTe: 'ఆకు మచ్చ తెగులు',
        bodyTe: 'దుకాణంలో మాంకోజెబ్ 75% WP అడగండి. ఎకరానికి 600 గ్రా.',
        titleEn: 'Leaf spot',
        bodyEn: 'Ask the shop for Mancozeb 75% WP. 600 g per acre.',
        age: const Duration(days: 20),
        read: true,
        refType: 'visit',
        refId: '1673bc71-79d0-59fe-96e9-7934c6df81e6',
      ),
      notice(
        id: 'ad63c1a0-19e7-5584-a834-11eaeecd9ca1',
        kind: NoticeKind.advisory,
        sender: NoticeSender.ho,
        titleTe: 'విత్తే ముందు విత్తన శుద్ధి',
        bodyTe: 'పత్తి విత్తనాలను విత్తే ముందు శుద్ధి చేయండి',
        titleEn: 'Treat seed before sowing',
        bodyEn: 'Treat cotton seed before you sow it.',
        age: const Duration(days: 60),
        audio: true,
        listened: true,
      ),
      notice(
        id: 'dbd46002-0e31-55d7-a367-fb01c2dcefd3',
        kind: NoticeKind.system,
        sender: NoticeSender.system,
        titleTe: 'మీ FA: సురేష్ కె',
        bodyTe: 'సురేష్ మీ గ్రామానికి ఫీల్డ్ అసిస్టెంట్. ఏ సందేహం ఉన్నా కాల్ చేయండి.',
        titleEn: 'Your FA is Suresh K',
        bodyEn: 'Suresh is the field assistant for your village. Call him with any question.',
        age: const Duration(days: 120),
        read: true,
        refType: 'fa_assignment',
        refId: _faSuresh,
      ),
    ];
    _notices[_farmerVenkatesh] = [
      notice(
        id: 'fba30ea0-b187-576b-b58f-d3320bc298d5',
        kind: NoticeKind.system,
        sender: NoticeSender.system,
        titleTe: 'మీ FA: సురేష్ కె',
        bodyTe: 'సురేష్ మీ గ్రామానికి ఫీల్డ్ అసిస్టెంట్.',
        titleEn: 'Your FA is Suresh K',
        bodyEn: 'Suresh is the field assistant for your village.',
        age: const Duration(days: 20),
        refType: 'fa_assignment',
        refId: _faSuresh,
      ),
    ];
  }

  static double _distanceM(LatLng a, LatLng b) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.lat)) *
            math.cos(rad(b.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
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

final class _MockToken {
  const _MockToken(
    this.farmerId,
    this.deviceId,
    this.refreshToken,
    this.family,
  );

  final String farmerId;
  final String deviceId;
  final String refreshToken;

  /// The sign-in this token pair descends from (rotations keep it).
  final String family;
}

/// A refresh token that was used: what it was swapped for, and when.
final class _Rotation {
  const _Rotation(this.successor, this.at, this.family);

  final TokenPair successor;
  final DateTime at;
  final String family;
}

final class _Allocation {
  const _Allocation(this.faId, this.level, this.areaId, {required this.isLead});

  final String faId;
  final AreaLevel level;
  final String areaId;
  final bool isLead;
}

final class _Coverage {
  const _Coverage(this.faId, this.level, this.isLead);

  final String faId;
  final AreaLevel level;
  final bool isLead;
}

final class _Dealer {
  const _Dealer(this.view, this.skuIds);

  final NearbyDealer view;
  final Set<String> skuIds;
}

// -----------------------------------------------------------------------------
// Repositories.

/// What every mock repository shares: the backend, the session store, and
/// reporting failed calls to the [AuthFailureHook] (the API client's
/// interceptor does the same).
abstract base class _MockRepository {
  _MockRepository(this._backend, this._store, [this._authFailures]);

  final MockBackend _backend;
  final SessionStore _store;
  final AuthFailureHook? _authFailures;

  /// [MockBackend._call] with the session read when the request starts (as
  /// an HTTP client reads the token it sends), reporting an [ApiError] with
  /// the farmer whose session the call was made with.
  Future<T> _call<T>(FutureOr<T> Function(StoredSession? session) body) async {
    StoredSession? session;
    try {
      session = await _store.readSession();
    } on Object {
      session = null;
    }
    try {
      return await _backend._call(() => body(session));
    } on ApiError catch (e) {
      _authFailures?.report(e, farmerId: session?.farmerId);
      rethrow;
    }
  }
}

/// Mock [AuthRepository]: OTP `123456`, resend limits, token rotation.
final class MockAuthRepository extends _MockRepository
    implements AuthRepository {
  /// Creates the repository over a backend and session store, reporting
  /// failed calls to the optional auth-failure hook.
  MockAuthRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<AppConfig> getAppConfig() => _call(
    (_) => const AppConfig(
      app: 'farmer',
      minVersion: '0.0.0',
      latestVersion: '0.1.0',
      storeUrl: null,
      flags: {'push': false, 'weather': false},
    ),
  );

  @override
  Future<OtpSent> requestOtp({
    required String phone,
    required Language language,
  }) => _call((_) => _backend._requestOtp(phone, language));

  @override
  Future<FarmerSession> verifyOtp({
    required String phone,
    required String code,
    required DeviceInfo device,
  }) => _call((_) => _backend._verifyOtp(_store, phone, code, device));

  @override
  Future<TokenPair> refreshSession() =>
      _call((session) => _backend._refreshSession(_store, session));

  @override
  Future<void> logout() async {
    final session = await _store.readSession();
    await _store.clearSession();
    try {
      await _call((_) => _backend._revoke(session));
    } on ApiError {
      // Best effort, like the real call: the local session is gone already.
    }
  }

  @override
  Future<DeviceStatus> heartbeat({
    String? model,
    String? osVersion,
    String? appVersion,
    String? pushToken,
  }) => _call((session) {
    _backend._signedIn(session);
    return DeviceStatus(
      deviceId: session!.deviceId,
      wipe: false,
      serverTime: _backend._now,
      minVersion: '0.0.0',
      updateRequired: false,
    );
  });
}

/// Mock [FarmerProfileRepository].
final class MockFarmerProfileRepository extends _MockRepository
    implements FarmerProfileRepository {
  /// Creates the repository over a backend and session store, reporting
  /// failed calls to the optional auth-failure hook.
  MockFarmerProfileRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<FarmerHome> getHome() =>
      _call((session) => _backend._home(_backend._signedIn(session)));

  @override
  Future<Farmer> updateProfile({
    String? name,
    String? nameTe,
    Language? language,
    String? photoKey,
  }) => _call((session) async {
    final b = _backend;
    final f = b._signedInForWrite(session);
    final errors = MockBackend._profileErrors(name: name, nameTe: nameTe);
    if (photoKey != null && !photoKey.startsWith('farmers/${f.id}/')) {
      errors['photo_key'] =
          'must be a key from POST /v1/farmer/me/photo/upload-url';
    }
    if (errors.isNotEmpty) throw MockBackend._validation(errors);
    return b._save(
      b._farmers[f.id]!.copyWith(
        name: name?.trim(),
        nameTe: nameTe?.trim(),
        language: language,
        photoKey: photoKey,
      ),
    );
  });

  @override
  Future<Farmer> completeProfile({
    required String name,
    String? nameTe,
    required Language language,
    required String villageId,
  }) => _call((session) async {
    final b = _backend;
    final f = b._signedIn(session);
    final errors = MockBackend._profileErrors(
      name: name,
      nameTe: nameTe,
      nameRequired: true,
    );
    if (errors.isNotEmpty) throw MockBackend._validation(errors);
    final village = MockBackend._villages[villageId];
    if (village == null) throw MockBackend._notFound('village');
    if (f.status != FarmerStatus.pendingProfile) {
      throw MockBackend._conflict(
        ApiErrorCode.profileAlreadyComplete,
        'the profile is already complete',
        {'status': f.status.wire},
      );
    }
    final stored = b._farmers[f.id]!;
    final lead = b._coverage(village.id).where((c) => c.isLead).firstOrNull;
    final saved = b._save(
      stored.copyWith(
        name: name.trim(),
        nameTe: nameTe?.trim(),
        language: language,
        villageId: village.id,
        mandalId: village.mandalId,
        districtId: village.districtId,
        assignedFaId: stored.assignedFaId ?? lead?.faId,
        status: FarmerStatus.active,
        profileCompletedAt: b._now,
      ),
    );
    final fa = lead == null ? null : MockBackend._faCards[lead.faId];
    if (fa != null) {
      b._notices
          .putIfAbsent(f.id, () => [])
          .insert(
            0,
            Notice(
              id: b._newId(),
              kind: NoticeKind.system,
              sender: NoticeSender.system,
              titleTe: 'మీ FA: ${fa.nameTe ?? fa.name}',
              bodyTe: '${fa.nameTe ?? fa.name} 2 రోజుల్లో మీకు కాల్ చేస్తారు.',
              titleEn: 'Your FA is ${fa.name}',
              bodyEn: '${fa.name} will call you within 2 days.',
              audioUrl: null,
              refType: 'fa_assignment',
              refId: fa.id,
              pinned: false,
              readAt: null,
              listenedAt: null,
              createdAt: b._now,
            ),
          );
    }
    return saved;
  });

  @override
  Future<List<CurrentConsent>> listConsents() => _call((session) async {
    final f = _backend._signedIn(session);
    return _backend._consentList(f.id);
  });

  @override
  Future<List<CurrentConsent>> setConsent({
    required ConsentPurpose purpose,
    required bool granted,
    required String noticeVersion,
    bool? audioPlayed,
  }) => _call((session) async {
    final b = _backend;
    final f = b._signedIn(session);
    if (f.status == FarmerStatus.inactive) {
      throw MockBackend._forbidden('this farmer account is deactivated');
    }
    final v = noticeVersion.trim();
    final errors = {
      if (purpose == ConsentPurpose.unknown) 'purpose': 'unknown purpose',
      if (v.isEmpty || v.length > 40) 'notice_version': 'required',
    };
    if (errors.isNotEmpty) throw MockBackend._validation(errors);
    b._consents.putIfAbsent(f.id, () => {})[purpose] = CurrentConsent(
      purpose: purpose,
      granted: granted,
      method: ConsentMethod.app,
      noticeVersion: v,
      updatedAt: b._now,
    );
    return b._consentList(f.id);
  });

  @override
  Future<FarmerPhotoUpload> createPhotoUpload({
    required PhotoContentType contentType,
    required int bytes,
  }) => _call((session) async {
    final b = _backend;
    final f = b._signedInForWrite(session);
    if (bytes < 1 || bytes > 5 * 1024 * 1024) {
      throw MockBackend._validation({'bytes': 'must be 1 byte to 5 MB'});
    }
    final now = b._now;
    final recent = b._photoUploads.putIfAbsent(f.id, () => [])
      ..removeWhere((t) => now.difference(t) >= const Duration(hours: 1));
    if (recent.length >= 20) {
      throw MockBackend._rateLimited(
        const Duration(hours: 1) - now.difference(recent.first),
      );
    }
    recent.add(now);
    final ext = contentType.wire.split('/').last;
    final key = 'farmers/${f.id}/photo-${b._newId()}.$ext';
    return FarmerPhotoUpload(
      storageKey: key,
      url: 'https://${MockBackend.mockHost}/upload/$key',
      method: 'PUT',
      headers: {'Content-Type': contentType.wire},
      expiresAt: now.add(const Duration(minutes: 15)),
    );
  });

  @override
  Future<Plot> addPlot({
    String? label,
    required LatLng pin,
    required double areaAcres,
  }) => _call((session) async {
    final b = _backend;
    final f = b._signedInForWrite(session);
    final trimmed = label?.trim();
    final errors = {
      if (trimmed != null && (trimmed.isEmpty || trimmed.length > 60))
        'label': 'must not be blank',
      if (pin.lat.abs() > 90 || pin.lng.abs() > 180) 'pin': 'out of range',
      if (areaAcres <= 0 || areaAcres > 10000)
        'area_acres': 'must be above 0 and at most 10000',
    };
    if (errors.isNotEmpty) throw MockBackend._validation(errors);
    final count = b._plots.values.where((p) => p.farmerId == f.id).length;
    final now = b._now;
    final plot = Plot(
      id: b._newId(),
      farmerId: f.id,
      label: trimmed ?? 'Plot ${count + 1}',
      villageId: f.villageId,
      boundary: null,
      pin: pin,
      areaAcres: areaAcres,
      areaSource: AreaSource.typed,
      gpsAccuracyM: null,
      status: PlotStatus.active,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );
    b._plots[plot.id] = plot;
    return plot;
  });

  @override
  Future<Season> startSeason({
    required String plotId,
    required String seasonCode,
    required String cropId,
    LocalDate? sowingDate,
    String? previousCropId,
  }) => _call((session) async {
    final b = _backend;
    final f = b._signedInForWrite(session);
    // In the server's order (farmers/service_me.go StartMySeason, then
    // service_plots.go startSeason): the plot, the code, the one active
    // season, then the crops (foreign keys, checked on insert). A plot may
    // have several seasons with the same code once the earlier one is closed.
    final plot = b._plots[plotId];
    if (plot == null ||
        plot.farmerId != f.id ||
        plot.status != PlotStatus.active) {
      throw MockBackend._notFound('plot');
    }
    if (!SeasonCode.isValid(seasonCode)) {
      throw MockBackend._validation({
        'season_code': 'must look like rabi-2026-27 or kharif-2027',
      });
    }
    final active = b._activeSeason(plotId);
    if (active != null) {
      throw MockBackend._conflict(
        ApiErrorCode.activeSeasonExists,
        'this plot already has an active season',
        {'season_id': active.id},
      );
    }
    if (!MockBackend._crops.containsKey(cropId)) {
      throw MockBackend._validation({'crop_id': 'unknown crop'});
    }
    if (previousCropId != null &&
        !MockBackend._crops.containsKey(previousCropId)) {
      throw MockBackend._validation({'previous_crop_id': 'unknown crop'});
    }
    final now = b._now;
    final season = Season(
      id: b._newId(),
      farmerId: f.id,
      plotId: plotId,
      seasonCode: seasonCode,
      cropId: cropId,
      sowingDate: sowingDate,
      previousCropId: previousCropId,
      status: SeasonStatus.active,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );
    b._seasons[season.id] = season;
    return season;
  });

  @override
  Future<Season> closeSeason({
    required String seasonId,
    required SeasonOutcome outcome,
  }) => _call((session) async {
    final b = _backend;
    final f = b._signedInForWrite(session);
    final season = b._seasons[seasonId];
    if (season == null || season.farmerId != f.id) {
      throw MockBackend._notFound('season');
    }
    if (season.status != SeasonStatus.active) {
      throw MockBackend._conflict(
        ApiErrorCode.seasonNotActive,
        'this season is not active',
        {'status': season.status.wire},
      );
    }
    final closed = season.copyWith(
      status: SeasonStatus.fromWire(outcome.wire),
      version: season.version + 1,
      updatedAt: b._now,
    );
    b._seasons[seasonId] = closed;
    return closed;
  });
}

/// Mock [FieldAssistantRepository].
final class MockFieldAssistantRepository extends _MockRepository
    implements FieldAssistantRepository {
  /// Creates the repository over a backend and session store, reporting
  /// failed calls to the optional auth-failure hook.
  MockFieldAssistantRepository(
    super.backend,
    super.store, [
    super.authFailures,
  ]);

  @override
  Future<List<FaOption>> listFas({AreaLevel? level}) => _call((session) async {
    final b = _backend;
    final f = b._signedIn(session);
    if (level == AreaLevel.unknown) {
      throw MockBackend._validation({
        'level': 'must be village, mandal or district',
      });
    }
    final villageId = f.villageId;
    if (villageId == null || b.scenario == MockScenario.noFaAssigned) {
      return const <FaOption>[];
    }
    final mine = f.assignedFaId;
    return List<FaOption>.unmodifiable([
      for (final c in b._coverage(villageId))
        if (level == null || c.level == level)
          FaOption(
            fa: MockBackend._faCards[c.faId]!,
            coverageLevel: c.level,
            isLead: c.isLead,
            isMyFa: c.faId == mine,
          ),
    ]);
  });

  @override
  Future<Callback> requestCallback() => _call((session) async {
    final b = _backend;
    final f = b._signedIn(session);
    final faId = f.assignedFaId;
    if (faId == null) {
      throw MockBackend._conflict(
        ApiErrorCode.noFaAssigned,
        "you don't have a field assistant yet; one will call you within 2 days",
      );
    }
    final open = b._callbacks.values
        .where((c) => c.farmerId == f.id && c.isOpen)
        .firstOrNull;
    if (open != null) return open;
    final c = Callback(
      id: b._newId(),
      farmerId: f.id,
      faId: faId,
      status: CallbackStatus.open,
      requestedAt: b._now,
      closedAt: null,
    );
    b._callbacks[c.id] = c;
    return c;
  });

  @override
  Future<Callback?> getOpenCallback() => _call((session) async {
    final f = _backend._signedIn(session);
    return _backend._callbacks.values
        .where((c) => c.farmerId == f.id && c.isOpen)
        .firstOrNull;
  });

  @override
  Future<Callback> cancelCallback(String callbackId) => _call((session) async {
    final b = _backend;
    final f = b._signedIn(session);
    final c = b._callbacks[callbackId];
    if (c == null || c.farmerId != f.id) {
      throw MockBackend._notFound('call-back request');
    }
    switch (c.status) {
      case CallbackStatus.cancelled:
        return c;
      case CallbackStatus.closed:
        throw MockBackend._conflict(
          ApiErrorCode.callbackClosed,
          'your field assistant has already closed this request',
        );
      case CallbackStatus.open || CallbackStatus.unknown:
        final cancelled = c.copyWith(
          status: CallbackStatus.cancelled,
          closedAt: b._now,
        );
        b._callbacks[callbackId] = cancelled;
        return cancelled;
    }
  });
}

/// Mock [VisitsRepository].
final class MockVisitsRepository extends _MockRepository
    implements VisitsRepository {
  /// Creates the repository over a backend and session store, reporting
  /// failed calls to the optional auth-failure hook.
  MockVisitsRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<CursorPage<FarmerVisit>> listVisits({int? limit, String? cursor}) =>
      _call((session) async {
        final f = _backend._signedIn(session);
        MockBackend._checkLimit(limit, 50);
        final all = _backend.scenario == MockScenario.noVisits
            ? const <FarmerVisit>[]
            : _backend._visits[f.id] ?? const <FarmerVisit>[];
        return MockBackend._page(
          all,
          limit,
          cursor,
          20,
          at: (v) => v.visitedAt,
          id: (v) => v.id,
        );
      });

  @override
  Future<NextVisit?> getNextVisit() => _call((session) async {
    final f = _backend._signedIn(session);
    final p = _backend._home(f).nextVisit;
    if (p == null) return null;
    final fa = MockBackend._faCards[p.faId];
    return NextVisit(
      visitId: p.visitId,
      plotId: p.plotId,
      plannedFor: p.plannedFor,
      plannedSlot: p.plannedSlot,
      purpose: p.purpose,
      fa: fa == null
          ? null
          : FaName(id: fa.id, name: fa.name, nameTe: fa.nameTe),
    );
  });
}

/// Mock [NoticesRepository].
final class MockNoticesRepository extends _MockRepository
    implements NoticesRepository {
  /// Creates the repository over a backend and session store, reporting
  /// failed calls to the optional auth-failure hook.
  MockNoticesRepository(super.backend, super.store, [super.authFailures]);

  List<Notice> _mine(StoredSession? session) {
    final f = _backend._signedIn(session);
    return _backend._notices.putIfAbsent(f.id, () => []);
  }

  @override
  Future<CursorPage<Notice>> listNotices({int? limit, String? cursor}) =>
      _call((session) async {
        final mine = _mine(session);
        MockBackend._checkLimit(limit, 100);
        return MockBackend._page(
          mine,
          limit,
          cursor,
          30,
          at: (n) => n.createdAt,
          id: (n) => n.id,
        );
      });

  @override
  Future<int> getUnreadCount() =>
      _call((session) => _mine(session).where((n) => !n.isRead).length);

  @override
  Future<void> markRead(String noticeId) => _call((session) async {
    final list = _mine(session);
    final i = list.indexWhere((n) => n.id == noticeId);
    if (i < 0) throw MockBackend._notFound('notice');
    if (!list[i].isRead) list[i] = list[i].copyWith(readAt: _backend._now);
  });

  @override
  Future<void> markListened(String noticeId) => _call((session) async {
    final list = _mine(session);
    final i = list.indexWhere((n) => n.id == noticeId);
    if (i < 0) throw MockBackend._notFound('notice');
    final now = _backend._now;
    final n = list[i];
    list[i] = n.copyWith(
      readAt: n.readAt ?? now,
      listenedAt: n.listenedAt ?? now,
    );
  });
}

/// Mock [GeoRepository].
final class MockGeoRepository extends _MockRepository implements GeoRepository {
  /// Creates the repository over a backend and session store, reporting
  /// failed calls to the optional auth-failure hook.
  MockGeoRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<List<Village>> searchVillages({
    String? query,
    String? mandalId,
    String? districtId,
    int? limit,
  }) => _call((session) async {
    _backend._signedIn(session);
    MockBackend._checkLimit(limit, 50);
    final q = query?.trim().toLowerCase();
    if (query != null && (q!.isEmpty || query.length > 100)) {
      throw MockBackend._validation({'q': 'must be 1-100 characters'});
    }
    final inArea =
        MockBackend._villages.values
            .where((v) => mandalId == null || v.mandalId == mandalId)
            .where((v) => districtId == null || v.districtId == districtId)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final List<Village> hits;
    if (q == null) {
      hits = inArea;
    } else {
      bool starts(Village v) =>
          v.name.toLowerCase().startsWith(q) ||
          (v.nameTe?.startsWith(q) ?? false);
      bool contains(Village v) =>
          v.name.toLowerCase().contains(q) || (v.nameTe?.contains(q) ?? false);
      hits = [
        ...inArea.where(starts),
        ...inArea.where((v) => !starts(v) && contains(v)),
      ];
    }
    return List.unmodifiable(hits.take(limit ?? 20));
  });

  @override
  Future<GeoTree> getGeoTree() => _call((session) async {
    _backend._signedIn(session);
    final villages = MockBackend._villages.values;
    final byDistrict = <String, List<Village>>{};
    for (final v in villages) {
      byDistrict.putIfAbsent(v.districtId, () => []).add(v);
    }
    return GeoTree(
      districts: [
        for (final entry in byDistrict.entries)
          TreeDistrict(
            id: entry.key,
            name: entry.value.first.districtName,
            nameTe: entry.value.first.districtNameTe,
            lgdCode: null,
            villageCount: entry.value.length,
            mandals: [
              for (final mandalId in {for (final v in entry.value) v.mandalId})
                TreeMandal(
                  id: mandalId,
                  name: entry.value
                      .firstWhere((v) => v.mandalId == mandalId)
                      .mandalName,
                  nameTe: entry.value
                      .firstWhere((v) => v.mandalId == mandalId)
                      .mandalNameTe,
                  lgdCode: null,
                  villageCount: entry.value
                      .where((v) => v.mandalId == mandalId)
                      .length,
                ),
            ]..sort((a, b) => a.name.compareTo(b.name)),
          ),
      ],
    );
  });
}

/// Mock [MastersRepository].
final class MockMastersRepository extends _MockRepository
    implements MastersRepository {
  /// Creates the repository over a backend and session store, reporting
  /// failed calls to the optional auth-failure hook.
  MockMastersRepository(super.backend, super.store, [super.authFailures]);

  @override
  Future<FarmerCropList> listCrops() => _call((session) async {
    _backend._signedIn(session);
    return FarmerCropList(
      version: 1,
      items: List.unmodifiable(MockBackend._crops.values),
      seasonCodes: SeasonCodes.fromSet(seasonCodesOn(_backend._today)),
    );
  });

  @override
  Future<List<NearbyDealer>> listNearbyDealers({
    required LatLng near,
    double? radiusKm,
    String? skuId,
    int? limit,
  }) => _call((session) async {
    _backend._signedIn(session);
    MockBackend._checkLimit(limit, 50);
    final errors = {
      if (near.lat.abs() > 90) 'lat': 'out of range',
      if (near.lng.abs() > 180) 'lng': 'out of range',
      if (radiusKm != null && (radiusKm < 0.1 || radiusKm > 100))
        'radius_km': 'must be 0.1-100',
    };
    if (errors.isNotEmpty) throw MockBackend._validation(errors);
    final maxM = (radiusKm ?? 25) * 1000;
    final out = <NearbyDealer>[
      for (final d in MockBackend._dealers)
        if (skuId == null || d.skuIds.contains(skuId))
          NearbyDealer(
            id: d.view.id,
            nameTe: d.view.nameTe,
            name: d.view.name,
            phone: d.view.phone,
            location: d.view.location,
            distanceM: MockBackend._distanceM(near, d.view.location).round(),
          ),
    ]..removeWhere((d) => d.distanceM > maxM);
    out.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return List.unmodifiable(out.take(limit ?? 20));
  });
}
