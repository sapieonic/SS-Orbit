// The local effect of each command on the territory: what the FA sees before
// (and until) the server's snapshot carries the change. Pure Dart.
//
// Every effect is an upsert keyed by entity ID and reads its time from the
// entry (`client_created_at`), never from the clock, so applying an entry
// twice gives the same tables as applying it once, and replaying the outbox
// over a fresh snapshot is always safe.

import 'dart:math' as math;

import 'package:orbit_core/orbit_core.dart';

import '../data/models/models.dart';
import 'commands.dart';
import 'geo.dart';
import 'local_store.dart';
import 'outbox.dart';

/// Applies outbox entries to territory tables (a [Snapshot] shape).
final class Projector {
  /// Creates the projector.
  const Projector();

  /// True when [entry]'s effect belongs on top of a snapshot at
  /// [snapshotTerritoryVersion]: every queued or sending entry, and applied /
  /// merged entries the snapshot does not carry yet (their
  /// `batch_territory_version` is newer). Conflicts, rejections, dropped and
  /// resolved entries are never replayed.
  static bool replays(OutboxEntry entry, int? snapshotTerritoryVersion) =>
      switch (entry.state) {
        OutboxState.queued || OutboxState.sending => true,
        OutboxState.applied || OutboxState.merged =>
          entry.batchTerritoryVersion == null ||
              snapshotTerritoryVersion == null ||
              entry.batchTerritoryVersion! > snapshotTerritoryVersion,
        _ => false,
      };

  /// [base] with [entries] applied in order. Entries whose payload cannot be
  /// read are skipped (they will be rejected by the server or the app).
  ///
  /// [aliases] (`SyncMeta.idAliases`) are applied to every payload first: a
  /// queued command written with a farmer ID the server merged away still
  /// lands on the one farmer.
  Snapshot replay(
    Snapshot base,
    Iterable<OutboxEntry> entries, {
    Map<String, String> aliases = const {},
  }) {
    final t = _Tables(base);
    for (final e in entries) {
      final CommandPayload command;
      try {
        command = resolveAliases(e.command, aliases);
      } on FormatException {
        continue;
      }
      _apply(t, command, e.clientCreatedAt);
    }
    return t.build();
  }

  /// [tables] with one more [entry] applied.
  Snapshot apply(
    Snapshot tables,
    OutboxEntry entry, {
    Map<String, String> aliases = const {},
  }) => replay(tables, [entry], aliases: aliases);

  /// [command] with every ID in [aliases] replaced by what it stands for.
  static CommandPayload resolveAliases(
    CommandPayload command,
    Map<String, String> aliases,
  ) {
    if (aliases.isEmpty) return command;
    var out = command;
    final ids = _strings(command.toJson()).toSet();
    for (final a in aliases.entries) {
      if (ids.contains(a.key)) out = out.replaceId(a.key, a.value);
    }
    return out;
  }

  static Iterable<String> _strings(Object? value) sync* {
    switch (value) {
      case final String s:
        yield s;
      case final List<Object?> list:
        for (final v in list) {
          yield* _strings(v);
        }
      case final Map<String, Object?> map:
        for (final v in map.values) {
          yield* _strings(v);
        }
    }
  }

  void _apply(_Tables t, CommandPayload c, DateTime at) {
    switch (c) {
      case final EnrolFarmerPayload p:
        _enrol(t, p, at);
      case final RecordConsentPayload p:
        _consent(t, p, at);
      case final SavePlotPayload p:
        _savePlot(t, p, at);
      case final StartSeasonPayload p:
        _startSeason(t, p, at);
      case final UpdateFarmerPayload p:
        _updateFarmer(t, p, at);
      case final PlanVisitPayload p:
        _planVisit(t, p);
      case final LogVisitPayload p:
        _logVisit(t, p);
      case final CancelVisitPayload p:
        _cancelVisit(t, p);
      case final CloseCallbackPayload p:
        _closeCallback(t, p);
      case final AckAlertPayload p:
        _ackAlert(t, p, at);
    }
  }

  // -------------------------------------------------------------------------
  // Farmers module

  /// A new farmer, or (same ID already there: a replay, or a merge rewrote
  /// the ID to an existing farmer) the server's merge rule: fill what the
  /// farmer has not set, finish a pending self sign-up, add the consent.
  /// Either way the farmer's `new_farmer` alert has done its job and closes.
  void _enrol(_Tables t, EnrolFarmerPayload p, DateTime at) {
    t.closeAlerts(AlertKind.newFarmer, (a) => a.farmerId == p.farmerId);
    final granted = p.consent.hasProof
        ? p.consent.purposes
        : const <ConsentPurpose>[];
    final existing = t.farmers[p.farmerId];
    if (existing == null) {
      t.farmers[p.farmerId] = SnapFarmer(
        id: p.farmerId,
        phone: normalizeIndianMobile(p.phone) ?? p.phone,
        name: p.name.trim(),
        nameTe: _trimmed(p.nameTe),
        language: p.language,
        villageId: p.villageId,
        source: FarmerSource.fa,
        photoKey: p.photoKey,
        plan: Plan.free,
        status: FarmerStatus.active,
        consentsGranted: [...granted],
        consentPending: !granted.contains(ConsentPurpose.programme),
        profileCompletedAt: at,
        version: 1,
        createdAt: at,
        updatedAt: at,
      );
      return;
    }
    final pending = existing.status == FarmerStatus.pendingProfile;
    final consents = _union(existing.consentsGranted, granted);
    t.farmers[p.farmerId] = _farmer(
      existing,
      name: existing.name ?? p.name.trim(),
      nameTe: existing.nameTe ?? _trimmed(p.nameTe),
      language: pending ? p.language : existing.language,
      villageId: existing.villageId ?? p.villageId,
      photoKey: existing.photoKey ?? p.photoKey,
      status: pending ? FarmerStatus.active : existing.status,
      consentsGranted: consents,
      consentPending: !consents.contains(ConsentPurpose.programme),
      profileCompletedAt: existing.profileCompletedAt ?? at,
      updatedAt: _later(existing.updatedAt, at),
    );
  }

  void _consent(_Tables t, RecordConsentPayload p, DateTime at) {
    final f = t.farmers[p.farmerId];
    if (f == null) return;
    final consents = _union(f.consentsGranted, p.purposes);
    t.farmers[p.farmerId] = _farmer(
      f,
      consentsGranted: consents,
      consentPending: !consents.contains(ConsentPurpose.programme),
      updatedAt: _later(f.updatedAt, at),
    );
  }

  void _savePlot(_Tables t, SavePlotPayload p, DateTime at) {
    final existing = t.plots[p.plotId];
    final version = p.isUpdate
        ? math.max(existing?.version ?? 0, p.expectedVersion! + 1)
        : (existing?.version ?? 1);
    t.plots[p.plotId] = SnapPlot(
      id: p.plotId,
      farmerId: p.farmerId,
      label: p.label.trim(),
      villageId: existing?.villageId ?? t.farmers[p.farmerId]?.villageId,
      boundaryGeoJson: p.boundaryGeoJson,
      pin: p.pin ?? boundaryCentre(p.boundaryGeoJson),
      areaAcres: p.areaAcres,
      areaSource: p.areaSource,
      gpsAccuracyM: p.gpsAccuracyM,
      status: existing?.status ?? PlotStatus.active,
      version: version,
      updatedAt: at,
    );
  }

  void _startSeason(_Tables t, StartSeasonPayload p, DateTime at) {
    final existing = t.seasons[p.seasonId];
    t.seasons[p.seasonId] = SnapSeason(
      id: p.seasonId,
      farmerId: p.farmerId,
      plotId: p.plotId,
      seasonCode: p.seasonCode,
      cropId: p.cropId,
      sowingDate: p.sowingDate,
      previousCropId: p.previousCropId,
      status: existing?.status ?? SeasonStatus.active,
      version: existing?.version ?? 1,
      updatedAt: at,
    );
  }

  void _updateFarmer(_Tables t, UpdateFarmerPayload p, DateTime at) {
    final f = t.farmers[p.farmerId];
    if (f == null) return;
    final fl = p.fields;
    t.farmers[p.farmerId] = _farmer(
      f,
      name: fl.name == null ? f.name : fl.name!.trim(),
      nameTe: fl.nameTe == null ? f.nameTe : _trimmed(fl.nameTe),
      language: fl.language ?? f.language,
      villageId: fl.villageId ?? f.villageId,
      photoKey: fl.photoKey ?? f.photoKey,
      version: math.max(f.version, p.expectedVersion + 1),
      updatedAt: _later(f.updatedAt, at),
    );
  }

  // -------------------------------------------------------------------------
  // Visits module

  void _planVisit(_Tables t, PlanVisitPayload p) {
    final existing = t.visits[p.visitId];
    if (existing != null &&
        (existing.status == VisitStatus.done ||
            existing.status == VisitStatus.cancelled)) {
      // Logged (or cancelled) later in the queue: keep that, only note the
      // plan. A planned or missed visit is re-planned (`visits.replanned`).
      t.visits[p.visitId] = _visit(
        existing,
        plannedFor: p.plannedFor,
        plannedSlot: p.plannedSlot,
        purpose: p.purpose,
      );
      return;
    }
    t.visits[p.visitId] = SnapVisit(
      id: p.visitId,
      farmerId: p.farmerId,
      plotId: p.plotId,
      seasonId: p.seasonId,
      faId: existing?.faId ?? t.faId,
      status: VisitStatus.planned,
      plannedFor: p.plannedFor,
      plannedSlot: p.plannedSlot,
      purpose: p.purpose,
      visitedAt: null,
      farmerPresent: null,
      stageId: null,
      stageName: null,
      stageNameTe: null,
      notes: null,
      photoCount: 0,
      issues: const [],
    );
  }

  void _logVisit(_Tables t, LogVisitPayload p) {
    final existing = t.visits[p.visitId];
    final stage = p.stageId == null ? null : t.stage(p.stageId!);
    t.visits[p.visitId] = SnapVisit(
      id: p.visitId,
      farmerId: p.farmerId,
      plotId: p.plotId,
      seasonId: p.seasonId,
      faId: existing?.faId ?? t.faId,
      status: VisitStatus.done,
      plannedFor: existing?.plannedFor,
      plannedSlot: existing?.plannedSlot,
      purpose: existing?.purpose,
      visitedAt: p.visitedAt,
      farmerPresent: p.farmerPresent,
      stageId: p.stageId,
      stageName: stage?.name,
      stageNameTe: stage?.nameTe,
      notes: _trimmed(p.notes),
      photoCount: p.photos.length,
      issues: [for (final i in p.issues) _issue(t.masters, i)],
    );
    final next = p.nextVisit;
    if (next != null) {
      final planned = t.visits[next.visitId];
      if (planned == null || planned.status == VisitStatus.planned) {
        t.visits[next.visitId] = SnapVisit(
          id: next.visitId,
          farmerId: p.farmerId,
          plotId: p.plotId,
          seasonId: p.seasonId,
          faId: planned?.faId ?? t.faId,
          status: VisitStatus.planned,
          plannedFor: next.plannedFor,
          plannedSlot: next.plannedSlot,
          purpose: planned?.purpose,
          visitedAt: null,
          farmerPresent: null,
          stageId: null,
          stageName: null,
          stageNameTe: null,
          notes: null,
          photoCount: 0,
          issues: const [],
        );
      }
    }
    // LogVisit also closes the farmer's open call-back.
    final closed = [
      for (final c in t.callbacks.values)
        if (c.farmerId == p.farmerId) c.id,
    ];
    for (final id in closed) {
      t.callbacks.remove(id);
    }
    t.closeAlerts(
      AlertKind.callback,
      (a) => closed.contains(a.refId) || a.farmerId == p.farmerId,
    );
  }

  /// A visit issue as the snapshot would show it: names from the masters,
  /// advice from the rule when it is a rule for this issue, else unresolved.
  SnapVisitIssue _issue(SnapMasters m, LogVisitIssue i) {
    final master = m.issueById(i.issueId);
    final found = i.advisoryRuleId == null
        ? null
        : m.ruleById(i.advisoryRuleId!);
    final rule = found != null && found.issueId == i.issueId ? found : null;
    final salt = rule == null ? null : m.saltById(rule.saltId);
    final sku = rule?.skuId == null ? null : m.skuById(rule!.skuId!);
    return SnapVisitIssue(
      id: i.issueVisitId,
      issueId: i.issueId,
      issueName: master?.name,
      issueNameTe: master?.nameTe,
      severity: i.severity,
      adviceStatus: rule == null ? AdviceStatus.unresolved : AdviceStatus.given,
      ruleId: rule?.id,
      saltId: salt?.id ?? rule?.saltId,
      saltName: salt?.name,
      saltNameTe: salt?.nameTe,
      skuId: sku?.id,
      productName: sku?.productName,
      productNameTe: sku?.productNameTe,
      dose: rule?.dosePerAcre,
      doseTe: rule?.dosePerAcreTe,
    );
  }

  void _cancelVisit(_Tables t, CancelVisitPayload p) {
    final v = t.visits[p.visitId];
    if (v == null ||
        (v.status != VisitStatus.planned && v.status != VisitStatus.missed)) {
      return;
    }
    t.visits[p.visitId] = _visit(v, status: VisitStatus.cancelled);
  }

  void _closeCallback(_Tables t, CloseCallbackPayload p) {
    t.callbacks.remove(p.callbackId);
    t.closeAlerts(AlertKind.callback, (a) => a.refId == p.callbackId);
  }

  // -------------------------------------------------------------------------
  // Messaging module

  void _ackAlert(_Tables t, AckAlertPayload p, DateTime at) {
    final a = t.alerts[p.alertId];
    if (a == null || a.status != AlertStatus.open) return;
    t.alerts[p.alertId] = _alert(
      a,
      status: AlertStatus.acknowledged,
      acknowledgedAt: at,
    );
  }
}

/// Rebuilds the territory tables from the base snapshot and every entry
/// that [Projector.replays], inside [tx]. Returns the new tables, or null
/// when there is no snapshot yet.
///
/// Use it whenever an effect has to be taken back or changed (rejected,
/// dropped, Keep HO's, an edited queued visit, a merged farmer ID).
Future<Snapshot?> rebuildTerritory(
  LocalTables tx, {
  Projector projector = const Projector(),
}) async {
  final base = await tx.baseSnapshot();
  if (base == null) return null;
  final entries = await tx.outbox();
  final meta = await tx.syncMeta();
  final tables = projector.replay(base, [
    for (final e in entries)
      if (Projector.replays(e, base.territoryVersion)) e,
  ], aliases: meta.idAliases);
  await tx.putTerritoryTables(tables);
  return tables;
}

// ---------------------------------------------------------------------------
// Mutable working copy of the tables (insertion order kept).

final class _Tables {
  _Tables(this.source)
    : farmers = {for (final f in source.farmers) f.id: f},
      plots = {for (final p in source.plots) p.id: p},
      seasons = {for (final s in source.seasons) s.id: s},
      visits = {for (final v in source.visits) v.id: v},
      callbacks = {for (final c in source.callbacks) c.id: c},
      alerts = {for (final a in source.alerts) a.id: a},
      // Every visit and alert in an FA's snapshot is that FA's.
      faId = (source.visits.isNotEmpty
          ? source.visits.first.faId
          : (source.alerts.isNotEmpty ? source.alerts.first.faId : '')),
      _stages = {
        for (final c in source.masters.crops)
          for (final s in c.stages) s.id: s,
      };

  final Snapshot source;
  final Map<String, SnapFarmer> farmers;
  final Map<String, SnapPlot> plots;
  final Map<String, SnapSeason> seasons;
  final Map<String, SnapVisit> visits;
  final Map<String, SnapCallback> callbacks;
  final Map<String, SnapAlert> alerts;
  final String faId;
  final Map<String, SnapStage> _stages;

  SnapMasters get masters => source.masters;

  SnapStage? stage(String id) => _stages[id];

  /// Closes the alerts of [kind] that pass [test] and are not closed yet.
  void closeAlerts(AlertKind kind, bool Function(SnapAlert a) test) {
    for (final a in [...alerts.values]) {
      if (a.kind == kind && a.status != AlertStatus.closed && test(a)) {
        alerts[a.id] = _alert(a, status: AlertStatus.closed);
      }
    }
  }

  Snapshot build() => Snapshot(
    territoryVersion: source.territoryVersion,
    mastersVersion: source.mastersVersion,
    generatedAt: source.generatedAt,
    farmers: List.unmodifiable(farmers.values),
    plots: List.unmodifiable(plots.values),
    seasons: List.unmodifiable(seasons.values),
    visits: List.unmodifiable(visits.values),
    callbacks: List.unmodifiable(callbacks.values),
    alerts: List.unmodifiable(alerts.values),
    masters: source.masters,
    villages: source.villages,
  );
}

// ---------------------------------------------------------------------------
// Copy helpers (the snapshot models have no copyWith).

String? _trimmed(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

List<ConsentPurpose> _union(List<ConsentPurpose> a, List<ConsentPurpose> b) => [
  ...a,
  for (final p in b)
    if (!a.contains(p)) p,
];

SnapFarmer _farmer(
  SnapFarmer f, {
  String? name,
  String? nameTe,
  Language? language,
  String? villageId,
  String? photoKey,
  FarmerStatus? status,
  List<ConsentPurpose>? consentsGranted,
  bool? consentPending,
  DateTime? profileCompletedAt,
  int? version,
  DateTime? updatedAt,
}) => SnapFarmer(
  id: f.id,
  phone: f.phone,
  name: name ?? f.name,
  nameTe: nameTe ?? f.nameTe,
  language: language ?? f.language,
  villageId: villageId ?? f.villageId,
  source: f.source,
  photoKey: photoKey ?? f.photoKey,
  plan: f.plan,
  status: status ?? f.status,
  consentsGranted: consentsGranted ?? f.consentsGranted,
  consentPending: consentPending ?? f.consentPending,
  profileCompletedAt: profileCompletedAt ?? f.profileCompletedAt,
  version: version ?? f.version,
  createdAt: f.createdAt,
  updatedAt: updatedAt ?? f.updatedAt,
);

SnapVisit _visit(
  SnapVisit v, {
  VisitStatus? status,
  LocalDate? plannedFor,
  VisitSlot? plannedSlot,
  String? purpose,
}) => SnapVisit(
  id: v.id,
  farmerId: v.farmerId,
  plotId: v.plotId,
  seasonId: v.seasonId,
  faId: v.faId,
  status: status ?? v.status,
  plannedFor: plannedFor ?? v.plannedFor,
  plannedSlot: plannedSlot ?? v.plannedSlot,
  purpose: purpose ?? v.purpose,
  visitedAt: v.visitedAt,
  farmerPresent: v.farmerPresent,
  stageId: v.stageId,
  stageName: v.stageName,
  stageNameTe: v.stageNameTe,
  notes: v.notes,
  photoCount: v.photoCount,
  issues: v.issues,
);

SnapAlert _alert(
  SnapAlert a, {
  AlertStatus? status,
  DateTime? acknowledgedAt,
}) => SnapAlert(
  id: a.id,
  faId: a.faId,
  kind: a.kind,
  farmerId: a.farmerId,
  refId: a.refId,
  title: a.title,
  body: a.body,
  titleTe: a.titleTe,
  bodyTe: a.bodyTe,
  status: status ?? a.status,
  createdAt: a.createdAt,
  acknowledgedAt: acknowledgedAt ?? a.acknowledgedAt,
);
