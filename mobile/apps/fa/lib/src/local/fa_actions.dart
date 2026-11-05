// Every write the FA app's screens make. Each action checks its input
// against the territory, mints UUIDv7 IDs, works out what the command
// depends on, and writes the outbox entry with its local effect in one
// transaction; then it nudges the sync engine. Pure Dart.
//
// Screens never build commands or IDs themselves: they call these.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:orbit_core/orbit_core.dart';
import 'package:uuid/uuid.dart';

import '../data/models/models.dart';
import 'commands.dart';
import 'geo.dart';
import 'local_store.dart';
import 'outbox.dart';
import 'projector.dart';
import 'territory.dart';

/// Why an action refused its input. [code] is one of the constants below;
/// the UI maps it to a message (`fa.<screen>.error_<code>`).
final class FaActionError implements Exception {
  /// Creates an error.
  const FaActionError(this.code, {this.field, this.farmerId});

  /// No snapshot yet (first sign-in before the first pull).
  static const noData = 'no_data';

  /// Not a 10-digit Indian mobile number.
  static const invalidPhone = 'invalid_phone';

  /// A required text is empty.
  static const required = 'required';

  /// A text is too long (the server counts UTF-8 bytes: a Telugu letter is
  /// 3 of them).
  static const tooLong = 'too_long';

  /// The text cannot be cleared once set (the server refuses a blank
  /// Telugu name); [field] says which.
  static const cannotClear = 'cannot_clear';

  /// The walked boundary has (almost) no area: its corners are in a line.
  /// Walk it again or type the area.
  static const areaTooSmall = 'area_too_small';

  /// The walked boundary crosses or touches itself; walk it again.
  static const boundaryCrossesItself = 'boundary_crosses_itself';

  /// The plot already has an active season (one per plot).
  static const seasonActive = 'season_active';

  /// A number is out of range (area, GPS accuracy).
  static const outOfRange = 'out_of_range';

  /// This phone is already one of the FA's farmers ([farmerId]): open Farmer
  /// 360 instead.
  static const alreadyEnrolled = 'already_enrolled';

  /// The farmer, plot, season, visit, village, crop, stage, issue, rule,
  /// call-back or alert is not in the territory ([field] says which).
  static const notFound = 'not_found';

  /// A plot needs a boundary or a pin.
  static const locationRequired = 'location_required';

  /// No active plot / season to plan or log a visit on.
  static const noSeason = 'no_season';

  /// The season code is not open.
  static const invalidSeasonCode = 'invalid_season_code';

  /// A date before today (plan, next visit) or a visit time in the future.
  static const invalidDate = 'invalid_date';

  /// More than 20 issues or 20 photos.
  static const tooMany = 'too_many';

  /// The consent proof has expired or is for another phone: verify the OTP
  /// again.
  static const proofInvalid = 'proof_invalid';

  /// Nothing would change.
  static const nothingToChange = 'nothing_to_change';

  /// The visit is not planned (already done or cancelled).
  static const notPlanned = 'not_planned';

  /// The queued visit was already sent: it can no longer be edited.
  static const notEditable = 'not_editable';

  /// The outbox row is not in a state that allows this (not a conflict, not
  /// dismissable, Keep mine not possible).
  static const wrongState = 'wrong_state';

  /// One of the constants above.
  final String code;

  /// The input or entity concerned, or null.
  final String? field;

  /// For [alreadyEnrolled], the existing farmer.
  final String? farmerId;

  @override
  String toString() =>
      'FaActionError($code${field == null ? '' : ' $field'}'
      '${farmerId == null ? '' : ' farmer $farmerId'})';
}

/// One issue found on a visit (visit log steps 3 and 4).
final class VisitIssueInput {
  /// Creates an issue.
  const VisitIssueInput({
    required this.issueId,
    required this.severity,
    this.ruleId,
  });

  /// The master issue.
  final String issueId;

  /// How bad.
  final Severity severity;

  /// The salt rule picked (`AdviceOption.rule.id`), or null (no rule: HO
  /// follows up).
  final String? ruleId;
}

/// A photo of a visit: a new capture ([bytes]) or, when editing a queued
/// visit, one already taken ([photoId]).
final class VisitPhotoInput {
  /// A new photo.
  const VisitPhotoInput({
    required Uint8List this.bytes,
    required this.contentType,
  }) : photoId = null;

  /// A photo already in the visit (keep it).
  const VisitPhotoInput.kept(String this.photoId, {required this.contentType})
    : bytes = null;

  /// The photo to keep, or null for a new one.
  final String? photoId;

  /// The new image, or null when kept.
  final Uint8List? bytes;

  /// Image type.
  final PhotoContentType contentType;
}

/// The follow-up visit set in the visit log (step 5).
final class NextVisitInput {
  /// Creates a next visit.
  const NextVisitInput({required this.plannedFor, required this.slot});

  /// Day (IST).
  final LocalDate plannedFor;

  /// Slot.
  final VisitSlot slot;
}

/// What the visit log saves.
final class VisitLogInput {
  /// Creates the input. [plotId] and [seasonId] default to the farmer's
  /// first plot with an active season; [visitedAt] to now.
  const VisitLogInput({
    required this.farmerId,
    this.plotId,
    this.seasonId,
    this.visitId,
    this.visitedAt,
    this.location,
    this.farmerPresent = true,
    this.stageId,
    this.notes,
    this.issues = const [],
    this.photos = const [],
    this.nextVisit,
  });

  /// The farmer.
  final String farmerId;

  /// The plot, or null for the default.
  final String? plotId;

  /// The season, or null for the default.
  final String? seasonId;

  /// The planned visit being logged (from the calendar), or null for an
  /// unplanned visit.
  final String? visitId;

  /// UTC time of the visit, or null for now.
  final DateTime? visitedAt;

  /// Where the FA was, or null.
  final LatLng? location;

  /// Whether the farmer was there.
  final bool farmerPresent;

  /// Crop stage seen, or null.
  final String? stageId;

  /// Notes, or null.
  final String? notes;

  /// Issues (at most 20).
  final List<VisitIssueInput> issues;

  /// Photos (at most 20).
  final List<VisitPhotoInput> photos;

  /// The follow-up visit, or null.
  final NextVisitInput? nextVisit;
}

/// IDs of a saved visit log.
final class LoggedVisit {
  /// Creates the result.
  const LoggedVisit({
    required this.visitId,
    required this.commandId,
    required this.nextVisitId,
    required this.photoIds,
  });

  /// The visit.
  final String visitId;

  /// The LogVisit outbox entry.
  final String commandId;

  /// The follow-up visit, or null.
  final String? nextVisitId;

  /// The visit's photos, in order.
  final List<String> photoIds;
}

/// The FA app's write API.
final class FaActions {
  /// Creates the actions. [onWrite] runs after every committed write (the
  /// engine's debounced `nudge`); [newId] mints IDs (UUIDv7 by default).
  FaActions({
    required this.store,
    this.clock = const SystemClock(),
    this.projector = const Projector(),
    String Function()? newId,
    this.onWrite,
  }) : _newId = newId ?? const Uuid().v7;

  /// The local database.
  final LocalStore store;

  /// Time source.
  final Clock clock;

  /// The local effect of commands.
  final Projector projector;

  /// Called after each committed write.
  final void Function()? onWrite;

  final String Function() _newId;

  /// The server's limits, in UTF-8 bytes (backend `validateEnrol`,
  /// `validateProfile`, `SavePlot`).
  static const maxNameBytes = 100;

  /// See [maxNameBytes].
  static const maxNameTeBytes = 300;

  /// See [maxNameBytes].
  static const maxLabelBytes = 60;

  /// A new UUIDv7.
  String newId() => _newId();

  /// The farmer ID to enrol [phone] under: the self sign-up already in the
  /// territory with that phone, else a new ID. Ask for it before uploading
  /// the farmer photo (the upload URL needs it).
  Future<String> farmerIdForPhone(String phone) async {
    final t = await _territory(store);
    final existing = t.farmerByPhone(phone);
    return existing != null && existing.status == FarmerStatus.pendingProfile
        ? existing.id
        : newId();
  }

  /// The command a new [command] waits for (`depends_on_id`): the latest
  /// entry in [outbox] (still in use) whose created IDs meet its
  /// `dependsOnIds`.
  static String? dependsOnFor(
    CommandPayload command,
    List<OutboxEntry> outbox,
  ) {
    final needs = command.dependsOnIds;
    if (needs.isEmpty) return null;
    for (final e in outbox.reversed) {
      if (e.state.isDiscarded) continue;
      final Set<String> created;
      try {
        created = e.command.createdIds;
      } on FormatException {
        continue;
      }
      if (created.any(needs.contains)) return e.id;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Farmers module

  /// Enrols a farmer (Enrol steps 1-3, EnrolFarmer). Returns the farmer ID.
  ///
  /// A self sign-up with the same phone in the territory is enrolled under
  /// its own ID (the server merges); an active farmer with that phone throws
  /// [FaActionError.alreadyEnrolled]. Without a valid [proof] (offline) the
  /// farmer is enrolled consent pending. A [photoKey] not under
  /// `farmers/<farmer_id>/` is left out (the server would drop it).
  Future<String> enrolFarmer({
    String? farmerId,
    required String phone,
    required String name,
    String? nameTe,
    required Language language,
    required String villageId,
    String? photoKey,
    List<ConsentPurpose> purposes = const [ConsentPurpose.programme],
    ConsentProof? proof,
    bool audioPlayed = false,
    String noticeVersion = '',
  }) => _write((tx, t) async {
    final norm = normalizeIndianMobile(phone);
    if (norm == null) throw const FaActionError(FaActionError.invalidPhone);
    _text(name, 'name', maxNameBytes);
    _optText(nameTe, 'name_te', maxNameTeBytes);
    if (t.village(villageId) == null) _notFound('village_id');
    final existing = t.farmerByPhone(norm);
    if (existing != null && existing.status != FarmerStatus.pendingProfile) {
      throw FaActionError(FaActionError.alreadyEnrolled, farmerId: existing.id);
    }
    final id = existing?.id ?? farmerId ?? newId();
    final now = clock.now();
    final proofOk =
        proof != null && proof.isValidAt(now) && proof.phone == norm;
    final consent = EnrolConsent(
      purposes: purposes.isEmpty ? const [ConsentPurpose.programme] : purposes,
      otpProof: proofOk ? proof.otpProof : null,
      audioPlayed: audioPlayed,
      noticeVersion: noticeVersion,
    );
    final command = EnrolFarmerPayload(
      farmerId: id,
      phone: norm,
      name: name.trim(),
      nameTe: _trimmed(nameTe),
      language: language,
      villageId: villageId,
      photoKey: photoKey != null && photoKey.startsWith('farmers/$id/')
          ? photoKey
          : null,
      consent: consent,
    );
    await _append(
      tx,
      command,
      meta: {
        if (proofOk) OutboxMeta.consentProofExpiresAt: utcIso(proof.expiresAt),
      },
    );
    return id;
  });

  /// Records consent for a farmer enrolled without it (Farmer 360 "Record
  /// consent", RecordConsent).
  Future<void> recordConsent({
    required String farmerId,
    List<ConsentPurpose> purposes = const [ConsentPurpose.programme],
    required ConsentProof proof,
    bool audioPlayed = false,
    required String noticeVersion,
  }) => _write((tx, t) async {
    final f = t.farmer(farmerId) ?? _notFound('farmer_id');
    if (!proof.isValidAt(clock.now()) ||
        proof.phone != (normalizeIndianMobile(f.phone) ?? f.phone)) {
      throw const FaActionError(FaActionError.proofInvalid);
    }
    if (purposes.isEmpty) {
      throw const FaActionError(FaActionError.required, field: 'purposes');
    }
    _text(noticeVersion, 'notice_version', 100);
    await _append(
      tx,
      RecordConsentPayload(
        farmerId: f.id,
        purposes: purposes,
        otpProof: proof.otpProof,
        audioPlayed: audioPlayed,
        noticeVersion: noticeVersion,
      ),
      meta: {OutboxMeta.consentProofExpiresAt: utcIso(proof.expiresAt)},
    );
  });

  /// Saves a new plot ([plotId] null) or an edit of one (SavePlot). Returns
  /// the plot ID. An edit carries the version the FA sees.
  ///
  /// One live edit per plot: an edit of a plot whose earlier SavePlot is
  /// still queued and never sent replaces that command's payload (same
  /// command, same `expected_version`); one whose earlier edit came back as a
  /// conflict is folded into the conflict (Keep mine sends the latest
  /// values). See [_saveEdit].
  Future<String> savePlot({
    required String farmerId,
    String? plotId,
    required String label,
    String? boundaryGeoJson,
    LatLng? pin,
    required double areaAcres,
    required AreaSource areaSource,
    double? gpsAccuracyM,
  }) => _write((tx, t) async {
    final f = t.farmer(farmerId) ?? _notFound('farmer_id');
    _text(label, 'label', maxLabelBytes);
    if (boundaryGeoJson == null && pin == null) {
      throw const FaActionError(FaActionError.locationRequired);
    }
    if (areaSource == AreaSource.boundary && boundaryGeoJson == null) {
      throw const FaActionError(
        FaActionError.locationRequired,
        field: 'boundary',
      );
    }
    if (areaSource == AreaSource.unknown) _notFound('area_source');
    if (boundaryGeoJson != null) {
      final rings = geoJsonOuterRings(boundaryGeoJson);
      // Corners in a line (or a walk too short) enclose nothing: the server
      // measures a boundary to 0.001 acre and refuses 0. A flat ring also
      // fails the crossing test; it gets the more useful "too small".
      if (rings.isEmpty ||
          ringIsFlat(rings.first) ||
          (ringIsSimple(rings.first) &&
              (ringAreaAcres(rings.first) < 0.0005 ||
                  (areaSource == AreaSource.boundary && !(areaAcres > 0))))) {
        throw const FaActionError(
          FaActionError.areaTooSmall,
          field: 'boundary',
        );
      }
      if (!ringIsSimple(rings.first)) {
        throw const FaActionError(
          FaActionError.boundaryCrossesItself,
          field: 'boundary',
        );
      }
    }
    if (!(areaAcres > 0 && areaAcres <= 10000)) {
      throw const FaActionError(FaActionError.outOfRange, field: 'area_acres');
    }
    if (gpsAccuracyM != null && !(gpsAccuracyM >= 0 && gpsAccuracyM <= 9999)) {
      throw const FaActionError(
        FaActionError.outOfRange,
        field: 'gps_accuracy_m',
      );
    }
    int? expected;
    if (plotId != null) {
      final p = t.plot(plotId);
      if (p == null || p.farmerId != f.id) _notFound('plot_id');
      expected = p.version;
    }
    final id = plotId ?? newId();
    SavePlotPayload build(int? version) => SavePlotPayload(
      plotId: id,
      farmerId: f.id,
      label: label.trim(),
      boundaryGeoJson: boundaryGeoJson,
      pin: pin,
      areaAcres: areaAcres,
      areaSource: areaSource,
      gpsAccuracyM: gpsAccuracyM,
      expectedVersion: version,
    );
    if (plotId == null) {
      await _append(tx, build(null));
    } else {
      await _saveEdit(
        tx,
        build(expected),
        merge: (earlier) => build((earlier as SavePlotPayload).expectedVersion),
      );
    }
    return id;
  });

  /// Starts a crop season on a plot (StartSeason). [seasonCode] defaults to
  /// the current one. Returns the season ID. A plot has one active season:
  /// starting another throws [FaActionError.seasonActive] (the server would
  /// answer a conflict and refuse every visit planned or logged on it).
  Future<String> startSeason({
    required String farmerId,
    required String plotId,
    String? seasonCode,
    required String cropId,
    LocalDate? sowingDate,
    String? previousCropId,
  }) => _write((tx, t) async {
    final f = t.farmer(farmerId) ?? _notFound('farmer_id');
    final p = t.plot(plotId);
    if (p == null || p.farmerId != f.id) _notFound('plot_id');
    if (t.activeSeason(plotId) != null) {
      throw const FaActionError(FaActionError.seasonActive, field: 'plot_id');
    }
    if (t.crop(cropId) == null) _notFound('crop_id');
    if (previousCropId != null && t.crop(previousCropId) == null) {
      _notFound('previous_crop_id');
    }
    final codes = t.seasonCodes;
    final code = seasonCode ?? codes.current;
    if (!SeasonCode.isValid(code) ||
        (codes.allOpen.isNotEmpty &&
            !codes.allOpen.contains(code) &&
            code != codes.current)) {
      throw const FaActionError(FaActionError.invalidSeasonCode);
    }
    final id = newId();
    await _append(
      tx,
      StartSeasonPayload(
        seasonId: id,
        farmerId: f.id,
        plotId: plotId,
        seasonCode: code,
        cropId: cropId,
        sowingDate: sowingDate,
        previousCropId: previousCropId,
      ),
    );
    return id;
  });

  /// Changes a farmer's profile (Farmer 360 edit, new photo; UpdateFarmer).
  /// Fields equal to the current value are left out. A Telugu name cannot be
  /// cleared once set (the server refuses a blank one): an empty [nameTe]
  /// then throws [FaActionError.cannotClear]. One live edit per farmer, as
  /// for [savePlot].
  Future<void> updateFarmer({
    required String farmerId,
    String? name,
    String? nameTe,
    Language? language,
    String? villageId,
    String? photoKey,
  }) => _write((tx, t) async {
    final f = t.farmer(farmerId) ?? _notFound('farmer_id');
    if (name != null) _text(name, 'name', maxNameBytes);
    _optText(nameTe, 'name_te', maxNameTeBytes);
    if (nameTe != null && nameTe.trim().isEmpty && f.nameTe != null) {
      throw const FaActionError(FaActionError.cannotClear, field: 'name_te');
    }
    if (villageId != null && t.village(villageId) == null) {
      _notFound('village_id');
    }
    if (photoKey != null && !photoKey.startsWith('farmers/${f.id}/')) {
      throw const FaActionError(FaActionError.notFound, field: 'photo_key');
    }
    String? changed(String? value, String? current) {
      final v = _trimmed(value);
      return v == null || v == current ? null : v;
    }

    final fields = UpdateFarmerFields(
      name: changed(name, f.name),
      nameTe: changed(nameTe, f.nameTe),
      language: language == f.language ? null : language,
      villageId: villageId == f.villageId ? null : villageId,
      photoKey: photoKey == f.photoKey ? null : photoKey,
    );
    if (fields.isEmpty) {
      throw const FaActionError(FaActionError.nothingToChange);
    }
    await _saveEdit(
      tx,
      UpdateFarmerPayload(
        farmerId: f.id,
        expectedVersion: f.version,
        fields: fields,
      ),
      merge: (earlier) {
        final e = earlier as UpdateFarmerPayload;
        return UpdateFarmerPayload(
          farmerId: e.farmerId,
          expectedVersion: e.expectedVersion,
          fields: mergeFarmerFields(e.fields, fields),
        );
      },
    );
  });

  /// [later] on top of [earlier]: a field set in [later] wins.
  static UpdateFarmerFields mergeFarmerFields(
    UpdateFarmerFields earlier,
    UpdateFarmerFields later,
  ) => UpdateFarmerFields(
    name: later.name ?? earlier.name,
    nameTe: later.nameTe ?? earlier.nameTe,
    language: later.language ?? earlier.language,
    villageId: later.villageId ?? earlier.villageId,
    photoKey: later.photoKey ?? earlier.photoKey,
  );

  /// The latest outbox entry (not discarded, not yet carried by a snapshot)
  /// that edits the same plot / farmer as [command] (a SavePlot of the plot,
  /// an UpdateFarmer of the farmer), or null. Farmer IDs compare through the
  /// merge aliases.
  static OutboxEntry? latestEditOf(
    CommandPayload command,
    List<OutboxEntry> outbox,
    Map<String, String> aliases,
  ) {
    String key(String id) => aliases[id] ?? id;
    for (final e in outbox.reversed) {
      if (e.type != command.type || e.state.isDiscarded) continue;
      final CommandPayload c;
      try {
        c = e.command;
      } on FormatException {
        continue;
      }
      if (key(c.entityId) == key(command.entityId)) return e;
    }
    return null;
  }

  /// Queues an edit (a SavePlot update or an UpdateFarmer) so that one plot
  /// or farmer never has two edits racing on the server:
  /// * the latest edit of it is still queued and never sent: that entry gets
  ///   [merge]'s payload in place (same ID: the server never saw it);
  /// * it came back as a conflict: the new values are folded into the
  ///   conflict (it stays a conflict; Keep mine sends them, Keep HO's drops
  ///   them), so Keep mine can never land after a later edit;
  /// * it is on its way (sent, no answer yet): [command] is queued with
  ///   `version_parent` = that entry. The engine never sends the two in one
  ///   batch, and folds this one into the earlier if that one conflicts.
  /// * otherwise (none, or already applied): [command] is queued as is.
  Future<void> _saveEdit(
    LocalTables tx,
    CommandPayload command, {
    required CommandPayload Function(CommandPayload earlier) merge,
  }) async {
    final outbox = await tx.outbox();
    final meta = await tx.syncMeta();
    final earlier = latestEditOf(command, outbox, meta.idAliases);
    if (earlier != null &&
        ((earlier.state == OutboxState.queued && earlier.attempts == 0) ||
            earlier.state == OutboxState.conflict)) {
      final merged = merge(earlier.command);
      await tx.updateOutbox(earlier.copyWith(payload: merged.toJson()));
      await rebuildTerritory(tx, projector: projector);
      return;
    }
    final inFlight =
        earlier != null &&
        (earlier.state == OutboxState.sending ||
            earlier.state == OutboxState.queued);
    await _append(
      tx,
      command,
      meta: {if (inFlight) OutboxMeta.versionParent: earlier.id},
    );
  }

  // -------------------------------------------------------------------------
  // Visits module

  /// Plans a visit (PlanVisit). [plotId] / [seasonId] default to the
  /// farmer's first plot with an active season. Returns the visit ID.
  Future<String> planVisit({
    required String farmerId,
    String? plotId,
    String? seasonId,
    required LocalDate plannedFor,
    VisitSlot slot = VisitSlot.any,
    String? purpose,
  }) => _write((tx, t) async {
    final f = t.farmer(farmerId) ?? _notFound('farmer_id');
    final (plot, season) = _plotAndSeason(t, f.id, plotId, seasonId);
    if (plannedFor.isBefore(t.today)) {
      throw const FaActionError(
        FaActionError.invalidDate,
        field: 'planned_for',
      );
    }
    if (slot == VisitSlot.unknown) _notFound('planned_slot');
    final id = newId();
    await _append(
      tx,
      PlanVisitPayload(
        visitId: id,
        farmerId: f.id,
        plotId: plot,
        seasonId: season,
        plannedFor: plannedFor,
        plannedSlot: slot,
        purpose: _trimmed(purpose),
      ),
    );
    return id;
  });

  /// Moves a planned (or missed) visit to [plannedFor] ("Move to another
  /// day"): a PlanVisit that reuses [visitId], which the server applies as
  /// `visits.replanned`. Farmer, plot and season stay the visit's own (the
  /// server rejects a re-plan that changes them). [slot] and [purpose] keep
  /// the visit's when null; pass an empty [purpose] to clear it. The same
  /// plan again sends nothing.
  Future<void> replanVisit(
    String visitId, {
    required LocalDate plannedFor,
    VisitSlot? slot,
    String? purpose,
  }) => _write((tx, t) async {
    final v = t.visit(visitId) ?? _notFound('visit_id');
    if (!Territory.isOpenPlan(v)) {
      throw const FaActionError(FaActionError.notPlanned);
    }
    if (plannedFor.isBefore(t.today)) {
      throw const FaActionError(
        FaActionError.invalidDate,
        field: 'planned_for',
      );
    }
    if (slot == VisitSlot.unknown) _notFound('planned_slot');
    final newSlot = slot ?? v.plannedSlot ?? VisitSlot.any;
    final newPurpose = purpose == null ? v.purpose : _trimmed(purpose);
    if (v.status == VisitStatus.planned &&
        v.plannedFor == plannedFor &&
        v.plannedSlot == newSlot &&
        v.purpose == newPurpose) {
      return;
    }
    final payload = PlanVisitPayload(
      visitId: v.id,
      farmerId: v.farmerId,
      plotId: v.plotId,
      seasonId: v.seasonId,
      plannedFor: plannedFor,
      plannedSlot: newSlot == VisitSlot.unknown ? VisitSlot.any : newSlot,
      purpose: newPurpose,
    );
    // Waits for the command that created the visit when it is still on the
    // phone (so a refused plan drops its re-plan), else for the farmer's.
    final outbox = await tx.outbox();
    await _append(
      tx,
      payload,
      dependsOnId:
          _latestCreating(outbox, v.id) ?? dependsOnFor(payload, outbox),
    );
  });

  /// The latest entry in [outbox] (still in use) that creates [id], or null.
  static String? _latestCreating(List<OutboxEntry> outbox, String id) {
    for (final e in outbox.reversed) {
      if (e.state.isDiscarded) continue;
      try {
        if (e.command.createdIds.contains(id)) return e.id;
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  /// Saves a visit log ("Save & tell farmer", LogVisit) with its photos in
  /// the photo queue (they upload once the LogVisit is applied).
  Future<LoggedVisit> logVisit(VisitLogInput input) => _write((tx, t) async {
    final built = await _buildLog(tx, t, input, visitId: null);
    final entry = await _append(tx, built.payload);
    await _queuePhotos(tx, built, entry.id);
    return built.result(entry.id);
  });

  /// True while the visit's LogVisit is still queued and was never sent
  /// ("Edit this visit"; after sync, editing is not supported).
  Future<bool> canEditVisit(String visitId) async =>
      await _editableLog(store, visitId) != null;

  /// The queued visit log as input for "Edit this visit", or null when it
  /// cannot be edited.
  Future<VisitLogInput?> queuedVisitInput(String visitId) async {
    final e = await _editableLog(store, visitId);
    if (e == null) return null;
    final p = e.command as LogVisitPayload;
    return VisitLogInput(
      farmerId: p.farmerId,
      plotId: p.plotId,
      seasonId: p.seasonId,
      visitId: p.visitId,
      visitedAt: p.visitedAt,
      location: p.location,
      farmerPresent: p.farmerPresent,
      stageId: p.stageId,
      notes: p.notes,
      issues: [
        for (final i in p.issues)
          VisitIssueInput(
            issueId: i.issueId,
            severity: i.severity,
            ruleId: i.advisoryRuleId,
          ),
      ],
      photos: [
        for (final ph in p.photos)
          VisitPhotoInput.kept(ph.photoId, contentType: ph.contentType),
      ],
      nextVisit: p.nextVisit == null
          ? null
          : NextVisitInput(
              plannedFor: p.nextVisit!.plannedFor,
              slot: p.nextVisit!.plannedSlot,
            ),
    );
  }

  /// Replaces a queued visit log in place (same command, same visit). Only
  /// while it is still queued and was never sent, else
  /// [FaActionError.notEditable]. Photos not in [input] are removed.
  Future<LoggedVisit> editQueuedVisit(String visitId, VisitLogInput input) =>
      _write((tx, t) async {
        final old = await _editableLog(tx, visitId);
        if (old == null) throw const FaActionError(FaActionError.notEditable);
        final before = old.command as LogVisitPayload;
        final built = await _buildLog(
          tx,
          t,
          input,
          visitId: visitId,
          nextVisitId: before.nextVisit?.visitId,
          existingPhotos: {
            for (final p in await tx.photos(commandId: old.id)) p.photoId: p,
          },
        );
        await tx.updateOutbox(
          OutboxEntry(
            seq: old.seq,
            id: old.id,
            type: old.type,
            payload: built.payload.toJson(),
            entityType: old.entityType,
            entityId: old.entityId,
            dependsOnId: dependsOnFor(built.payload, [
              for (final e in await tx.outbox())
                if (e.seq < old.seq) e,
            ]),
            createdAt: old.createdAt,
            clientCreatedAt: old.clientCreatedAt,
            meta: old.meta,
          ),
        );
        final keep = built.photoIds.toSet();
        for (final p in await tx.photos(commandId: old.id)) {
          if (!keep.contains(p.photoId)) await tx.deletePhoto(p.photoId);
        }
        await _queuePhotos(tx, built, old.id);
        await rebuildTerritory(tx, projector: projector);
        return built.result(old.id);
      });

  /// Cancels a planned visit (CancelVisit).
  Future<void> cancelVisit(String visitId, {String? reason}) =>
      _write((tx, t) async {
        final v = t.visit(visitId) ?? _notFound('visit_id');
        if (!Territory.isOpenPlan(v)) {
          throw const FaActionError(FaActionError.notPlanned);
        }
        await _append(
          tx,
          CancelVisitPayload(visitId: visitId, reason: _trimmed(reason)),
        );
      });

  /// Closes a call-back request after the call (CloseCallback).
  Future<void> closeCallback(String callbackId, {String? note}) =>
      _write((tx, t) async {
        if (t.callback(callbackId) == null) _notFound('callback_id');
        await _append(
          tx,
          CloseCallbackPayload(callbackId: callbackId, note: _trimmed(note)),
        );
      });

  // -------------------------------------------------------------------------
  // Messaging module

  /// Acknowledges an alert ("Got it", AckAlert). Already acknowledged: no-op.
  Future<void> ackAlert(String alertId) => _write((tx, t) async {
    final a = t.alert(alertId) ?? _notFound('alert_id');
    if (a.status != AlertStatus.open) return;
    await _append(tx, AckAlertPayload(alertId: alertId));
  });

  // -------------------------------------------------------------------------
  // Sync screen

  /// "Keep mine" on a conflict: the same change goes again as a new command
  /// (new ID: the old one's stored result would come back) carrying the
  /// version the server has now (from the snapshot pulled after the
  /// conflict). The conflict row becomes resolved.
  Future<void> keepMine(String entryId) => _write((tx, t) async {
    final e = await tx.outboxEntry(entryId);
    if (e == null || !e.canKeepMine) {
      throw const FaActionError(FaActionError.wrongState);
    }
    final base = await tx.baseSnapshot();
    final theirs = e.conflict?.field == 'version' && e.conflict?.theirs is int
        ? e.conflict!.theirs! as int
        : null;
    final CommandPayload resend;
    switch (e.command) {
      case final SavePlotPayload p:
        final v =
            base?.plots.where((x) => x.id == p.plotId).firstOrNull?.version ??
            theirs;
        if (v == null) _notFound('plot_id');
        resend = SavePlotPayload(
          plotId: p.plotId,
          farmerId: p.farmerId,
          label: p.label,
          boundaryGeoJson: p.boundaryGeoJson,
          pin: p.pin,
          areaAcres: p.areaAcres,
          areaSource: p.areaSource,
          gpsAccuracyM: p.gpsAccuracyM,
          expectedVersion: v,
        );
      case final UpdateFarmerPayload p:
        final v =
            base?.farmers
                .where((x) => x.id == p.farmerId)
                .firstOrNull
                ?.version ??
            theirs;
        if (v == null) _notFound('farmer_id');
        resend = UpdateFarmerPayload(
          farmerId: p.farmerId,
          expectedVersion: v,
          fields: p.fields,
        );
      default:
        throw const FaActionError(FaActionError.wrongState);
    }
    final now = clock.now();
    final entry = await _append(
      tx,
      resend,
      clientCreatedAt: e.clientCreatedAt,
      meta: {OutboxMeta.replaces: e.id},
      project: false,
    );
    await tx.updateOutbox(
      e.copyWith(
        state: OutboxState.resolved,
        meta: {
          ...e.meta,
          OutboxMeta.resolution: 'mine',
          OutboxMeta.replacedBy: entry.id,
        },
      ),
    );
    await _log(tx, now, SyncLogKind.keptMine, e);
    await rebuildTerritory(tx, projector: projector);
  });

  /// "Keep HO's" on a conflict: nothing is sent; the row becomes resolved and
  /// its local effect is taken back.
  Future<void> keepTheirs(String entryId) => _write((tx, t) async {
    final e = await tx.outboxEntry(entryId);
    if (e == null || e.state != OutboxState.conflict) {
      throw const FaActionError(FaActionError.wrongState);
    }
    await tx.updateOutbox(
      e.copyWith(
        state: OutboxState.resolved,
        meta: {...e.meta, OutboxMeta.resolution: 'theirs'},
      ),
    );
    await _log(tx, clock.now(), SyncLogKind.keptTheirs, e);
    await rebuildTerritory(tx, projector: projector);
  });

  /// Taps a rejected, dropped or resolved row away (Sync screen).
  Future<void> dismiss(String entryId) => _write((tx, t) async {
    final e = await tx.outboxEntry(entryId);
    if (e == null) return;
    if (!e.state.isDiscarded) {
      throw const FaActionError(FaActionError.wrongState);
    }
    await tx.deleteOutbox(e.id);
    for (final p in await tx.photos(commandId: e.id)) {
      await tx.deletePhoto(p.photoId);
    }
    await _log(tx, clock.now(), SyncLogKind.dismissed, e);
  }, requireData: false);

  /// "Upload photos on Wi-Fi only".
  Future<void> setPhotosOnWifiOnly(bool value) => _write((tx, t) async {
    final s = await tx.settings();
    await tx.putSettings(s.copyWith(photosOnWifiOnly: value));
  }, requireData: false);

  // -------------------------------------------------------------------------
  // Helpers

  Future<T> _write<T>(
    Future<T> Function(LocalTables tx, Territory t) action, {
    bool requireData = true,
  }) async {
    final result = await store.transaction((tx) async {
      final t = await _territory(tx);
      if (requireData && !t.hasData) {
        throw const FaActionError(FaActionError.noData);
      }
      return action(tx, t);
    });
    onWrite?.call();
    return result;
  }

  Future<Territory> _territory(LocalTables tx) =>
      Territory.load(tx, asOf: clock.now());

  /// Appends [command] to the outbox and (unless [project] is false) applies
  /// its effect to the territory tables, in the caller's transaction.
  Future<OutboxEntry> _append(
    LocalTables tx,
    CommandPayload command, {
    DateTime? clientCreatedAt,
    Map<String, Object?> meta = const {},
    bool project = true,
    String? dependsOnId,
  }) async {
    final entry = await tx.insertOutbox(
      OutboxEntry.create(
        id: newId(),
        command: command,
        dependsOnId: dependsOnId ?? dependsOnFor(command, await tx.outbox()),
        now: clock.now(),
        clientCreatedAt: clientCreatedAt,
        meta: meta,
      ),
    );
    if (project) {
      final tables = await tx.territoryTables();
      if (tables != null) {
        final aliases = (await tx.syncMeta()).idAliases;
        await tx.putTerritoryTables(
          projector.apply(tables, entry, aliases: aliases),
        );
      }
    }
    return entry;
  }

  Future<void> _log(
    LocalTables tx,
    DateTime now,
    SyncLogKind kind,
    OutboxEntry e,
  ) => tx.addSyncLog(
    SyncLogEntry(
      id: 0,
      at: now,
      kind: kind,
      commandId: e.id,
      commandType: e.type,
      entityId: e.entityId,
      farmerId: e.farmerId,
    ),
  );

  (String, String) _plotAndSeason(
    Territory t,
    String farmerId,
    String? plotId,
    String? seasonId,
  ) {
    if (plotId != null) {
      final p = t.plot(plotId);
      if (p == null || p.farmerId != farmerId) _notFound('plot_id');
      final s = seasonId == null ? t.activeSeason(plotId) : t.season(seasonId);
      if (s == null || s.plotId != plotId) {
        throw const FaActionError(FaActionError.noSeason);
      }
      return (plotId, s.id);
    }
    if (seasonId != null) {
      final s = t.season(seasonId);
      if (s == null || s.farmerId != farmerId) _notFound('season_id');
      return (s.plotId, s.id);
    }
    for (final p in t.plotsOf(farmerId)) {
      final s = t.activeSeason(p.id);
      if (s != null) return (p.id, s.id);
    }
    throw const FaActionError(FaActionError.noSeason);
  }

  Future<_BuiltLog> _buildLog(
    LocalTables tx,
    Territory t,
    VisitLogInput input, {
    required String? visitId,
    String? nextVisitId,
    Map<String, PhotoQueueEntry> existingPhotos = const {},
  }) async {
    final f = t.farmer(input.farmerId) ?? _notFound('farmer_id');
    final now = clock.now();
    final planned = visitId ?? input.visitId;
    var plotId = input.plotId;
    var seasonId = input.seasonId;
    if (visitId == null && input.visitId != null) {
      final v = t.visit(input.visitId!);
      if (v == null || v.farmerId != f.id) _notFound('visit_id');
      // Planned or missed: the server logs both (a missed visit turns done).
      if (!Territory.isOpenPlan(v)) {
        throw const FaActionError(FaActionError.notPlanned);
      }
      plotId ??= v.plotId;
      seasonId ??= v.seasonId;
    }
    final (plot, season) = _plotAndSeason(t, f.id, plotId, seasonId);
    final visitedAt = (input.visitedAt ?? now).toUtc();
    if (visitedAt.isAfter(now.add(const Duration(minutes: 15)))) {
      throw const FaActionError(FaActionError.invalidDate, field: 'visited_at');
    }
    if (input.stageId != null) {
      final crop = t.crop(t.season(season)?.cropId);
      final known = crop?.stages.any((s) => s.id == input.stageId) ?? false;
      if (!known) _notFound('stage_id');
    }
    if (input.issues.length > LogVisitPayload.maxIssues) {
      throw const FaActionError(FaActionError.tooMany, field: 'issues');
    }
    if (input.photos.length > LogVisitPayload.maxPhotos) {
      throw const FaActionError(FaActionError.tooMany, field: 'photos');
    }
    final issues = <LogVisitIssue>[];
    for (final i in input.issues) {
      if (t.masters.issueById(i.issueId) == null) _notFound('issue_id');
      if (i.severity == Severity.unknown) _notFound('severity');
      if (i.ruleId != null) {
        final rule = t.masters.ruleById(i.ruleId!);
        if (rule == null || rule.issueId != i.issueId) _notFound('rule_id');
      }
      issues.add(
        LogVisitIssue(
          issueVisitId: newId(),
          issueId: i.issueId,
          severity: i.severity,
          advisoryRuleId: i.ruleId,
        ),
      );
    }
    final photos = <LogVisitPhoto>[];
    final newPhotos = <String, VisitPhotoInput>{};
    for (final p in input.photos) {
      if (p.contentType == PhotoContentType.unknown) _notFound('content_type');
      if (p.photoId != null) {
        if (!existingPhotos.containsKey(p.photoId)) _notFound('photo_id');
        photos.add(
          LogVisitPhoto(photoId: p.photoId!, contentType: p.contentType),
        );
        continue;
      }
      if (p.bytes == null || p.bytes!.isEmpty) {
        throw const FaActionError(FaActionError.required, field: 'photo');
      }
      final id = newId();
      newPhotos[id] = p;
      photos.add(LogVisitPhoto(photoId: id, contentType: p.contentType));
    }
    final next = input.nextVisit;
    if (next != null) {
      if (next.plannedFor.isBefore(LocalDate.istOf(visitedAt))) {
        throw const FaActionError(
          FaActionError.invalidDate,
          field: 'next_visit',
        );
      }
      if (next.slot == VisitSlot.unknown) _notFound('planned_slot');
    }
    final id = planned ?? newId();
    final payload = LogVisitPayload(
      visitId: id,
      farmerId: f.id,
      plotId: plot,
      seasonId: season,
      visitedAt: visitedAt,
      location: input.location,
      farmerPresent: input.farmerPresent,
      stageId: input.stageId,
      notes: _trimmed(input.notes),
      issues: issues,
      photos: photos,
      nextVisit: next == null
          ? null
          : LogVisitNextVisit(
              visitId: nextVisitId ?? newId(),
              plannedFor: next.plannedFor,
              plannedSlot: next.slot,
            ),
    );
    return _BuiltLog(payload, newPhotos, now);
  }

  Future<void> _queuePhotos(
    LocalTables tx,
    _BuiltLog built,
    String commandId,
  ) async {
    for (final e in built.newPhotos.entries) {
      final bytes = e.value.bytes!;
      await tx.putPhoto(
        PhotoQueueEntry(
          photoId: e.key,
          visitId: built.payload.visitId,
          commandId: commandId,
          contentType: e.value.contentType,
          bytes: bytes,
          byteCount: bytes.length,
          sha256: crypto.sha256.convert(bytes).toString(),
          createdAt: built.now,
        ),
      );
    }
  }

  /// The visit's LogVisit while it is queued and never sent, or null.
  static Future<OutboxEntry?> _editableLog(
    LocalTables tx,
    String visitId,
  ) async {
    for (final e in (await tx.outbox()).reversed) {
      if (e.type != CommandType.logVisit || e.entityId != visitId) continue;
      return e.state == OutboxState.queued && e.attempts == 0 ? e : null;
    }
    return null;
  }

  static Never _notFound(String field) =>
      throw FaActionError(FaActionError.notFound, field: field);

  /// Checks a required text against the server's limit of [maxBytes] UTF-8
  /// bytes (Go's `len`), after trimming.
  static void _text(String value, String field, int maxBytes) {
    final v = value.trim();
    if (v.isEmpty) throw FaActionError(FaActionError.required, field: field);
    if (utf8.encode(v).length > maxBytes) {
      throw FaActionError(FaActionError.tooLong, field: field);
    }
  }

  static void _optText(String? value, String field, int maxBytes) {
    if (value != null && utf8.encode(value.trim()).length > maxBytes) {
      throw FaActionError(FaActionError.tooLong, field: field);
    }
  }

  static String? _trimmed(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}

final class _BuiltLog {
  _BuiltLog(this.payload, this.newPhotos, this.now);

  final LogVisitPayload payload;
  final Map<String, VisitPhotoInput> newPhotos;
  final DateTime now;

  List<String> get photoIds => [for (final p in payload.photos) p.photoId];

  LoggedVisit result(String commandId) => LoggedVisit(
    visitId: payload.visitId,
    commandId: commandId,
    nextVisitId: payload.nextVisit?.visitId,
    photoIds: photoIds,
  );
}
