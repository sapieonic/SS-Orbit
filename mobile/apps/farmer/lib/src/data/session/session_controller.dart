import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';

import '../models/models.dart';
import '../providers.dart';
import '../repositories/repositories.dart';
import 'auth_failures.dart';
import 'session_phase.dart';
import 'session_store.dart';

export 'session_phase.dart';

/// The session as the app sees it: routing phase, language, and the sign-in
/// details the current phase needs. Tokens never appear here.
@immutable
class SessionState {
  /// Creates a state.
  const SessionState({
    required this.phase,
    this.language = Language.te,
    this.phone,
    this.otp,
    this.otpSentAt,
    this.farmerId,
    this.village,
  });

  /// The routing phase.
  final SessionPhase phase;

  /// The farmer's language; the app locale follows it (Telugu default).
  final Language language;

  /// E.164 phone being signed in (kept to prefill the phone field).
  final String? phone;

  /// The last OTP request result, in [SessionPhase.otpSent].
  final OtpSent? otp;

  /// When [otp] was sent (UTC), for the resend countdown.
  final DateTime? otpSentAt;

  /// The signed-in farmer, from [SessionPhase.needsConsent] on.
  final String? farmerId;

  /// The village picked during sign-up, in [SessionPhase.needsName].
  final Village? village;

  /// True when a farmer session exists.
  bool get isSignedIn => farmerId != null;

  /// When Resend may be tapped, or null outside [SessionPhase.otpSent].
  DateTime? get resendAvailableAt {
    final sentAt = otpSentAt;
    final sent = otp;
    return sentAt == null || sent == null ? null : sentAt.add(sent.resendAfter);
  }

  SessionState _withLanguage(Language language) => SessionState(
    phase: phase,
    language: language,
    phone: phone,
    otp: otp,
    otpSentAt: otpSentAt,
    farmerId: farmerId,
    village: village,
  );

  SessionState _to(
    SessionPhase phase, {
    String? farmerId,
    Village? village,
    OtpSent? otp,
    DateTime? otpSentAt,
  }) => SessionState(
    phase: phase,
    language: language,
    phone: phone,
    farmerId: farmerId ?? this.farmerId,
    village: village,
    otp: otp,
    otpSentAt: otpSentAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionState &&
      other.phase == phase &&
      other.language == language &&
      other.phone == phone &&
      other.otp == otp &&
      other.otpSentAt == otpSentAt &&
      other.farmerId == farmerId &&
      other.village == village;

  @override
  int get hashCode =>
      Object.hash(phase, language, phone, otp, otpSentAt, farmerId, village);

  @override
  String toString() =>
      'SessionState(${phase.name}, ${language.wire}, farmer: $farmerId)';
}

/// Version of the programme consent notice shown on F1a. Bump it when the
/// notice text changes (open decision: the business owns the text).
const programmeConsentNoticeVersion = 'v1';

/// The session state; the router's source of truth.
final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// The app locale's language (follows [SessionState.language]).
final appLanguageProvider = Provider<Language>(
  (ref) => ref.watch(sessionProvider.select((s) => s.language)),
);

/// Sign-in and sign-up flow. Actions throw `ApiError` for the screen to show
/// (wrong OTP, rate limit, offline); the state only changes on success.
///
/// Any await can outlive the session it started on: the farmer edits the
/// phone while a code is being checked, the server ends the session while a
/// sign-up step saves, the farmer signs out and in again while a re-check
/// runs. So every sign-in, sign-out and return to phone entry starts a new
/// generation, and work started in an older one never writes the state.
class SessionController extends Notifier<SessionState> {
  late SessionStore _store;
  late FarmerRepositories _repos;
  late Clock _clock;
  Future<void>? _restoring;
  ({int generation, Future<void> future})? _rechecking;
  Future<void>? _losing;
  int _generation = 0;
  bool _languagePicked = false;

  @override
  SessionState build() {
    _store = ref.watch(sessionStoreProvider);
    _repos = ref.watch(farmerRepositoriesProvider);
    _clock = ref.watch(clockProvider);
    _generation++;
    _rechecking = null;
    _losing = null;
    _languagePicked = false;
    ref.onDispose(ref.watch(authFailureHookProvider).listen(_onApiFailure));
    listenSelf((previous, next) {
      if (next.phase == previous?.phase || !next.isSignedIn) return;
      if (next.phase.saved case final saved?) {
        unawaited(
          _store.writePhase(saved).catchError((Object e) {
            debugPrint('SessionStore.writePhase failed: $e');
          }),
        );
      }
    });
    _restoring = _restore();
    return const SessionState(phase: SessionPhase.restoring);
  }

  /// Completes when the saved session has been read and routed.
  Future<void> get restored => _restoring ?? Future<void>.value();

  /// True while work started in [generation] may still write the state.
  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  /// Moves to [next] as a new generation (a sign-in, or back to phone
  /// entry): work started before can no longer write the state.
  void _reset(SessionState next) {
    _generation++;
    state = next;
  }

  Future<void> _restore() async {
    final generation = _generation;
    // A language picked on the splash wins over the saved one.
    Language language(Language? saved) =>
        _languagePicked ? state.language : saved ?? Language.te;

    Language? savedLanguage;
    StoredSession? saved;
    SessionPhase? savedPhase;
    try {
      savedLanguage = await _store.readLanguage();
      saved = await _store.readSession();
      if (saved != null) savedPhase = await _store.readPhase();
    } on Object catch (e) {
      // An unreadable store (e.g. a keystore lost after a backup restore)
      // must never leave the app on the splash: forget the session and sign
      // in again. The install ID stays: a read that failed once must not
      // register the phone as a new device. If the install ID cannot be read
      // either, the next sign-in replaces it (_deviceKey). A language read
      // before the failure is still the farmer's choice.
      debugPrint('SessionStore read at start failed: $e');
      await _store.clearSession().catchError((Object _) {});
      if (_isCurrent(generation)) {
        _reset(
          SessionState(
            phase: SessionPhase.signedOut,
            language: language(savedLanguage),
          ),
        );
      }
      return;
    }
    if (!_isCurrent(generation)) return;
    if (saved == null) {
      _reset(
        SessionState(
          phase: SessionPhase.signedOut,
          language: language(savedLanguage),
        ),
      );
      return;
    }
    final signedIn = SessionState(
      phase: SessionPhase.active,
      farmerId: saved.farmerId,
    );
    SessionState next;
    try {
      next = await _route(signedIn, null);
    } on ApiError catch (e) {
      if (AuthFailureHook.endsSession(e)) {
        await _store
            .clearSession(wipe: e.isDeviceRevoked)
            .catchError((Object _) {});
        next = const SessionState(phase: SessionPhase.signedOut);
      } else {
        // Offline or server trouble: open where the farmer last was (an
        // unfinished sign-up resumes at its step, otherwise Home with its
        // offline card). Home re-checks the status once it loads.
        next = signedIn._to(savedPhase?.saved ?? SessionPhase.active);
      }
    }
    if (_isCurrent(generation)) {
      _reset(next._withLanguage(language(savedLanguage)));
    }
  }

  /// Decides the phase for a signed-in farmer from [status], asking the
  /// server when needed.
  Future<SessionState> _route(SessionState s, FarmerStatus? status) async {
    switch (status) {
      case FarmerStatus.active:
        return s._to(SessionPhase.active);
      case FarmerStatus.inactive:
        return s._to(SessionPhase.inactive);
      case FarmerStatus.pendingProfile:
        final consents = await _repos.profile.listConsents();
        final programme = consents
            .where((c) => c.purpose == ConsentPurpose.programme)
            .firstOrNull;
        return s._to(
          programme?.granted == true
              ? SessionPhase.needsVillage
              : SessionPhase.needsConsent,
        );
      case FarmerStatus.unknown || null:
        final home = await _repos.profile.getHome();
        final known = home.farmer.status;
        return known == FarmerStatus.unknown
            ? s._to(SessionPhase.active)
            : _route(s, known);
    }
  }

  void _expect(Set<SessionPhase> phases, String action) {
    if (!phases.contains(state.phase)) {
      throw StateError('$action is not allowed in ${state.phase.name}');
    }
  }

  /// Sets the app language (F1 language chip, F10 Language). Saved locally at
  /// once (also while the saved session is still being read); when the
  /// farmer is active it is also saved to the profile (`PATCH
  /// /v1/farmer/me`), and a failure there is rethrown while the local choice
  /// stays.
  Future<void> setLanguage(Language language) async {
    _languagePicked = true;
    state = state._withLanguage(language);
    await _store.writeLanguage(language);
    if (ref.mounted && state.phase == SessionPhase.active) {
      await _repos.profile.updateProfile(language: language);
    }
  }

  /// Sends the OTP to [phone] (any common Indian format) in the current
  /// language: [SessionPhase.signedOut] -> [SessionPhase.otpSent].
  ///
  /// Throws `ApiError` `validation_failed` (checked locally first, no call),
  /// `rate_limited` (`retryAfter`), `network`.
  Future<void> requestOtp(String phone) async {
    _expect({SessionPhase.signedOut, SessionPhase.otpSent}, 'requestOtp');
    final e164 = normalizeIndianMobile(phone);
    if (e164 == null) {
      throw const ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'must be a 10-digit Indian mobile number',
        status: 400,
        details: {
          'fields': {'phone': 'must be a 10-digit Indian mobile number'},
        },
      );
    }
    final generation = _generation;
    final sent = await _repos.auth.requestOtp(
      phone: e164,
      language: state.language,
    );
    // E.g. a resend that returns after the code was verified.
    if (!_isCurrent(generation)) return;
    state = SessionState(
      phase: SessionPhase.otpSent,
      language: state.language,
      phone: e164,
      otp: sent,
      otpSentAt: _clock.now(),
    );
  }

  /// Sends a new code to the same phone (after [SessionState.resendAvailableAt]).
  Future<void> resendOtp() {
    _expect({SessionPhase.otpSent}, 'resendOtp');
    return requestOtp(state.phone!);
  }

  /// Back from the OTP screen to phone entry; the phone stays prefilled. A
  /// code still being checked no longer signs in.
  void editPhone() {
    _expect({SessionPhase.otpSent}, 'editPhone');
    _reset(
      SessionState(
        phase: SessionPhase.signedOut,
        language: state.language,
        phone: state.phone,
      ),
    );
  }

  /// Checks [code] and signs in. Routes on the farmer's status: active ->
  /// [SessionPhase.active]; inactive -> [SessionPhase.inactive]; a self
  /// sign-up -> [SessionPhase.needsConsent] (or [SessionPhase.needsVillage]
  /// when consent was already given on an earlier try).
  ///
  /// When the farmer went back to phone entry meanwhile, the sign-in is
  /// undone instead. Throws `ApiError` `otp_invalid` (`attemptsLeft`),
  /// `otp_expired`, `device_revoked`, `rate_limited`, `network`.
  Future<void> verifyOtp(String code) async {
    _expect({SessionPhase.otpSent}, 'verifyOtp');
    final generation = _generation;
    final phone = state.phone!;
    final deviceKey = await _deviceKey();
    if (!_isCurrent(generation)) return;
    final session = await _repos.auth.verifyOtp(
      phone: phone,
      code: code.trim(),
      device: DeviceInfo(deviceKey: deviceKey),
    );
    if (!ref.mounted) return;
    if (generation != _generation) return _dropStaleSignIn(session);
    final signedIn = state._to(SessionPhase.active, farmerId: session.farmerId);
    SessionState next;
    try {
      next = await _route(signedIn, session.farmerStatus);
    } on ApiError {
      // Signed in, but the follow-up read failed (e.g. the network dropped).
      // The code is used up, so never stay on the OTP screen: route on the
      // hint alone; consent is safe to give again.
      next = signedIn._to(switch (session.farmerStatus) {
        FarmerStatus.pendingProfile => SessionPhase.needsConsent,
        FarmerStatus.inactive => SessionPhase.inactive,
        _ => SessionPhase.active,
      });
    }
    if (!ref.mounted) return;
    if (generation != _generation) return _dropStaleSignIn(session);
    _reset(next);
  }

  /// The farmer went back to phone entry while [session]'s sign-in was in
  /// flight, and the repository saved it anyway: sign it out again (unless a
  /// newer sign-in replaced it), so a restart cannot open a farmer the app
  /// never showed.
  Future<void> _dropStaleSignIn(FarmerSession session) async {
    try {
      final saved = await _store.readSession();
      if (saved?.tokens == session.tokens) await _repos.auth.logout();
    } on Object catch (e) {
      debugPrint('Dropping a stale sign-in failed: $e');
    }
  }

  /// Records the programme consent from F1a (`purpose: programme`,
  /// granted): [SessionPhase.needsConsent] -> [SessionPhase.needsVillage].
  /// [audioPlayed] is true when the Listen button played to the end.
  Future<void> giveConsent({bool audioPlayed = false}) async {
    _expect({SessionPhase.needsConsent}, 'giveConsent');
    final generation = _generation;
    await _repos.profile.setConsent(
      purpose: ConsentPurpose.programme,
      granted: true,
      noticeVersion: programmeConsentNoticeVersion,
      audioPlayed: audioPlayed,
    );
    if (_isCurrent(generation)) state = state._to(SessionPhase.needsVillage);
  }

  /// Keeps the village picked in the picker (no call yet):
  /// [SessionPhase.needsVillage] -> [SessionPhase.needsName].
  void pickVillage(Village village) {
    _expect({SessionPhase.needsVillage, SessionPhase.needsName}, 'pickVillage');
    state = state._to(SessionPhase.needsName, village: village);
  }

  /// Back from name entry to the village picker.
  void changeVillage() {
    _expect({SessionPhase.needsName}, 'changeVillage');
    state = state._to(SessionPhase.needsVillage);
  }

  /// Finishes the self sign-up with [name] (and [nameTe]), the picked village
  /// and the current language: [SessionPhase.needsName] ->
  /// [SessionPhase.active]. The server assigns the village's lead FA.
  ///
  /// `profile_already_complete` is treated as success. Throws `ApiError`
  /// `validation_failed`, `not_found` (village), `network`.
  Future<void> completeProfile({required String name, String? nameTe}) async {
    _expect({SessionPhase.needsName}, 'completeProfile');
    final generation = _generation;
    try {
      await _repos.profile.completeProfile(
        name: name,
        nameTe: nameTe,
        language: state.language,
        villageId: state.village!.id,
      );
    } on ApiError catch (e) {
      if (e.code != ApiErrorCode.profileAlreadyComplete) rethrow;
    }
    if (!_isCurrent(generation)) return;
    SessionState next;
    try {
      next = await _route(state, null);
    } on ApiError {
      // Completed; Home shows offline. Unless the read ended the session
      // (a 401 signs out through the hook, a new generation).
      if (!_isCurrent(generation)) return;
      next = state._to(SessionPhase.active);
    }
    if (_isCurrent(generation)) state = next;
  }

  /// Asks the server for the farmer's status again and re-routes (e.g. the
  /// "Account paused" screen's Try again, or after a write was refused as
  /// `forbidden` / `profile_incomplete`). Concurrent calls for the same
  /// session share one request. Throws `ApiError` (e.g. `network`); the
  /// phase is unchanged then.
  Future<void> recheck() {
    if (!state.isSignedIn) return Future<void>.value();
    final running = _rechecking;
    if (running != null && running.generation == _generation) {
      return running.future;
    }
    late final Future<void> future;
    future = _recheck(_generation).whenComplete(() {
      if (identical(_rechecking?.future, future)) _rechecking = null;
    });
    _rechecking = (generation: _generation, future: future);
    return future;
  }

  Future<void> _recheck(int generation) async {
    final next = await _route(state, null);
    if (_isCurrent(generation)) state = next;
  }

  /// Re-routes on the farmer's [status] as a fresh server payload states it
  /// (Home's `GET /v1/farmer/me`): a farmer paused by HO goes to "Account
  /// paused", a reactivated one back to Home, and an incomplete sign-up back
  /// to its step. Only acts while the farmer is [SessionPhase.active] or
  /// [SessionPhase.inactive] and the status says something else; a failure
  /// to read the consents keeps the phase.
  Future<void> applyStatus(FarmerStatus status) async {
    final phase = state.phase;
    if (phase != SessionPhase.active && phase != SessionPhase.inactive) return;
    final wanted = switch (status) {
      FarmerStatus.active => SessionPhase.active,
      FarmerStatus.inactive => SessionPhase.inactive,
      FarmerStatus.pendingProfile => null, // a sign-up step, asked below
      FarmerStatus.unknown => phase,
    };
    if (wanted == phase) return;
    final generation = _generation;
    try {
      final next = await _route(state, status);
      if (_isCurrent(generation)) state = next;
    } on ApiError catch (e) {
      debugPrint('applyStatus($status) failed: $e');
    }
  }

  /// A failed call reported through [AuthFailureHook]. Calls made with
  /// another farmer's session (still in flight across a sign-out) are
  /// ignored.
  void _onApiFailure(ApiError error, {String? farmerId}) {
    if (farmerId != null && farmerId != state.farmerId) {
      // Not this session's call, but a revoked device is the phone's.
      if (error.isDeviceRevoked && !state.isSignedIn) {
        unawaited(_store.clearSession(wipe: true).catchError((Object _) {}));
      }
      return;
    }
    if (AuthFailureHook.endsSession(error)) {
      unawaited(sessionLost(error));
    } else if (state.phase == SessionPhase.active) {
      unawaited(
        recheck().catchError((Object e) {
          debugPrint('recheck after ${error.code} failed: $e');
        }),
      );
    }
  }

  /// Signs out to phone entry: revokes the session on the server (best
  /// effort) and always forgets it on the phone, also offline or when the
  /// server call fails. The language and install ID stay.
  Future<void> signOut() async {
    final generation = ++_generation;
    try {
      await _repos.auth.logout();
    } on Object catch (e) {
      debugPrint('logout failed, signing out anyway: $e');
    }
    try {
      await _store.clearSession();
    } on Object catch (e) {
      debugPrint('SessionStore.clearSession failed: $e');
    }
    if (_isCurrent(generation)) {
      state = SessionState(
        phase: SessionPhase.signedOut,
        language: state.language,
      );
    }
  }

  /// An API call failed with a 401 that a refresh cannot fix (`unauthorized`
  /// for an ended or expired session, `refresh_reused`) or with
  /// `device_revoked` ([ApiError.isDeviceRevoked]: also forgets the install
  /// ID): forget the session and go to phone entry.
  ///
  /// Called by the [AuthFailureHook] listener; screens never need to. Many
  /// calls failing together sign out once. With nobody signed in it changes
  /// nothing, except that a revoked device (e.g. on verify) wipes the
  /// install ID. Never throws: a store that fails to clear is logged.
  Future<void> sessionLost(ApiError error) {
    if (!state.isSignedIn) {
      if (!error.isDeviceRevoked) return Future<void>.value();
      return _store.clearSession(wipe: true).catchError((Object e) {
        debugPrint('SessionStore.clearSession failed: $e');
      });
    }
    return _losing ??= _loseSession(error);
  }

  Future<void> _loseSession(ApiError error) async {
    // A new generation at once: a sign-up step or re-check still in flight
    // must not route the farmer back in.
    final generation = ++_generation;
    try {
      await _store.clearSession(wipe: error.isDeviceRevoked);
    } on Object catch (e) {
      // Signing out must not depend on the store: the tokens are dead anyway.
      debugPrint('SessionStore.clearSession failed: $e');
    }
    _losing = null;
    if (_isCurrent(generation)) {
      state = SessionState(
        phase: SessionPhase.signedOut,
        language: state.language,
      );
    }
  }

  /// The install ID (`device_key`), made on first use.
  Future<String> _deviceKey() async {
    try {
      final saved = await _store.readDeviceKey();
      if (saved != null) return saved;
    } on Object catch (e) {
      // It cannot be read (e.g. a keystore lost after a backup restore):
      // start over with a new one. The server sees a new device, which is
      // what this install now is.
      debugPrint('SessionStore.readDeviceKey failed, new install ID: $e');
      await _store.clearSession(wipe: true).catchError((Object _) {});
    }
    final rnd = math.Random.secure();
    final key = List.generate(
      32,
      (_) => rnd.nextInt(16).toRadixString(16),
    ).join();
    await _store.writeDeviceKey(key);
    return key;
  }
}
