// The FA's territory as screens read it: the snapshot with the outbox's
// local effect applied (projected tables), plus what is not synced yet, and
// the queries the screens need. Immutable; a new one is built after every
// snapshot write and every action. Pure Dart.

import 'package:orbit_core/orbit_core.dart';

import '../data/models/models.dart';
import 'commands.dart';
import 'geo.dart';
import 'local_store.dart';
import 'outbox.dart';

/// The chips of "Farmers near me".
enum FarmerFilter {
  /// Everyone.
  all,

  /// Joined in the last [TerritoryRules.newDays] days, or a self sign-up
  /// that still needs enrolment.
  isNew,

  /// A planned visit in the next [TerritoryRules.dueAheadDays] days (or
  /// overdue), or a farmer with a crop not visited for
  /// [TerritoryRules.dueAfterDays] days.
  visitDue,

  /// No done visit for [TerritoryRules.staleDays] days or more.
  notVisited30,

  /// Consent pending, profile not finished, no plot or no season.
  finishEnrolment,
}

/// The day counts behind [FarmerFilter].
abstract final class TerritoryRules {
  /// "New": joined today or yesterday.
  static const newDays = 2;

  /// "Visit due": a planned visit up to this many days ahead.
  static const dueAheadDays = 7;

  /// "Visit due": a farmer with a crop not visited for this many days.
  static const dueAfterDays = 14;

  /// "30+ days since the last done visit".
  static const staleDays = 30;
}

/// What is missing for a farmer to be fully enrolled ("Finish enrolment").
enum EnrolmentGap {
  /// The self sign-up's profile (name, village) is not finished.
  profile,

  /// No programme consent yet (Record consent).
  consent,

  /// No active plot.
  plot,

  /// Plots, but no active season on any of them.
  season,
}

/// A plot with its active season, crop and crop stage.
final class PlotSummary {
  /// Creates a summary.
  const PlotSummary({
    required this.plot,
    required this.season,
    required this.crop,
    required this.stage,
    required this.daysAfterSowing,
    required this.pendingSync,
  });

  /// The plot.
  final SnapPlot plot;

  /// Its active season, or null.
  final SnapSeason? season;

  /// The season's crop, or null.
  final SnapCrop? crop;

  /// The stage the crop is in today, or null (no sowing date).
  final SnapStage? stage;

  /// Days after sowing today (`day 137`), or null.
  final int? daysAfterSowing;

  /// The plot or its season is not synced yet.
  final bool pendingSync;
}

/// A visit with what it refers to.
final class VisitRow {
  /// Creates a row.
  const VisitRow({
    required this.visit,
    required this.farmer,
    required this.plot,
    required this.season,
    required this.crop,
    required this.slot,
    required this.pendingSync,
  });

  /// The visit.
  final SnapVisit visit;

  /// The farmer, or null when not in the territory.
  final SnapFarmer? farmer;

  /// The plot, or null.
  final SnapPlot? plot;

  /// The season, or null.
  final SnapSeason? season;

  /// The season's crop, or null.
  final SnapCrop? crop;

  /// Morning, afternoon or any (a done visit without a planned slot gets the
  /// half of the day it was logged in, IST).
  final VisitSlot slot;

  /// Planned or logged on this phone and not synced yet.
  final bool pendingSync;

  /// Logged.
  bool get isDone => visit.status == VisitStatus.done;

  /// Still to do.
  bool get isPlanned => visit.status == VisitStatus.planned;
}

/// One farmer in "Farmers near me".
final class FarmerRow {
  /// Creates a row.
  const FarmerRow({
    required this.farmer,
    required this.village,
    required this.location,
    required this.distanceKm,
    required this.plots,
    required this.lastDoneVisit,
    required this.daysSinceLastVisit,
    required this.nextPlannedVisit,
    required this.enrolmentGaps,
    required this.isNew,
    required this.isVisitDue,
    required this.isNotVisited30,
    required this.pendingSync,
  });

  /// The farmer.
  final SnapFarmer farmer;

  /// The farmer's village, or null.
  final SnapVillage? village;

  /// Where the farmer is on the map: a plot pin or boundary centre, else the
  /// village; null when neither is known.
  final LatLng? location;

  /// Km from the point asked for (nearest plot, else the village), or null.
  final double? distanceKm;

  /// Active plots with their seasons.
  final List<PlotSummary> plots;

  /// The latest done visit, or null.
  final SnapVisit? lastDoneVisit;

  /// Days since [lastDoneVisit] (IST), or null.
  final int? daysSinceLastVisit;

  /// The next planned visit (overdue ones included), or null.
  final SnapVisit? nextPlannedVisit;

  /// What is missing for enrolment (empty when complete).
  final Set<EnrolmentGap> enrolmentGaps;

  /// [FarmerFilter.isNew].
  final bool isNew;

  /// [FarmerFilter.visitDue].
  final bool isVisitDue;

  /// [FarmerFilter.notVisited30].
  final bool isNotVisited30;

  /// Something about this farmer is not synced yet.
  final bool pendingSync;

  /// The first active plot's summary, or null (list subtitle: crop, stage).
  PlotSummary? get mainPlot => plots.isEmpty ? null : plots.first;

  /// [FarmerFilter.finishEnrolment].
  bool get needsEnrolment => enrolmentGaps.isNotEmpty;

  /// True when this row belongs under [filter].
  bool matches(FarmerFilter filter) => switch (filter) {
    FarmerFilter.all => true,
    FarmerFilter.isNew => isNew,
    FarmerFilter.visitDue => isVisitDue,
    FarmerFilter.notVisited30 => isNotVisited30,
    FarmerFilter.finishEnrolment => needsEnrolment,
  };
}

/// Everything Farmer 360 shows.
final class Farmer360 {
  /// Creates the view.
  const Farmer360({
    required this.row,
    required this.doneVisits,
    required this.plannedVisits,
    required this.openCallback,
  });

  /// The list row (farmer, village, plots, flags).
  final FarmerRow row;

  /// Done visits, newest first (the snapshot keeps the 3 latest).
  final List<VisitRow> doneVisits;

  /// Planned visits, soonest first.
  final List<VisitRow> plannedVisits;

  /// The open call-back request, or null.
  final SnapCallback? openCallback;

  /// The farmer.
  SnapFarmer get farmer => row.farmer;

  /// Active plots with season, crop, stage and day after sowing.
  List<PlotSummary> get plots => row.plots;

  /// The last done visit with its issues and advice, or null.
  VisitRow? get lastDoneVisit => doneVisits.isEmpty ? null : doneVisits.first;

  /// No programme consent yet: show "Record consent".
  bool get consentPending => row.farmer.consentPending;

  /// Purposes the farmer consented to.
  List<ConsentPurpose> get consentsGranted => row.farmer.consentsGranted;

  /// Something about this farmer is not synced yet.
  bool get pendingSync => row.pendingSync;
}

/// A day of the calendar, split by slot.
final class DayPlan {
  /// Creates the plan.
  const DayPlan({
    required this.day,
    required this.morning,
    required this.afternoon,
    required this.anytime,
  });

  /// The day (IST).
  final LocalDate day;

  /// Morning visits.
  final List<VisitRow> morning;

  /// Afternoon visits.
  final List<VisitRow> afternoon;

  /// Visits planned for "any" time.
  final List<VisitRow> anytime;

  /// Every visit of the day.
  List<VisitRow> get all => [...morning, ...afternoon, ...anytime];

  /// Number of visits.
  int get count => morning.length + afternoon.length + anytime.length;

  /// Number of done visits.
  int get doneCount => all.where((v) => v.isDone).length;

  /// No visits.
  bool get isEmpty => count == 0;
}

/// Visit counts of one day, for the week strip.
final class DayCount {
  /// Creates the counts.
  const DayCount({
    required this.day,
    required this.planned,
    required this.done,
  });

  /// The day (IST).
  final LocalDate day;

  /// Still planned.
  final int planned;

  /// Done that day.
  final int done;

  /// All visits.
  int get total => planned + done;

  @override
  bool operator ==(Object other) =>
      other is DayCount &&
      other.day == day &&
      other.planned == planned &&
      other.done == done;

  @override
  int get hashCode => Object.hash(day, planned, done);

  @override
  String toString() => 'DayCount($day, $planned planned, $done done)';
}

/// One salt the masters suggest for an issue (visit log step 4).
final class AdviceOption {
  /// Creates an option.
  const AdviceOption({
    required this.rule,
    required this.salt,
    required this.sku,
  });

  /// The rule (`LogVisitIssue.advisory_rule_id` = `rule.id`).
  final SnapRule rule;

  /// The salt, or null when the masters lack it.
  final SnapSalt? salt;

  /// The Shanmukha product, or null ("No Shanmukha product, farmer sees the
  /// salt name only").
  final SnapSku? sku;

  /// True when a Shanmukha product goes with it.
  bool get hasProduct => sku != null;

  /// The salt name in [language].
  String saltName(Language language) => salt?.displayName(language) ?? '';

  /// The dose per acre in [language].
  String dose(Language language) => rule.displayDose(language);
}

/// The FA's territory read model.
final class Territory {
  /// Builds the read model from projected [tables] (null before the first
  /// pull), the [outbox] and [meta], as of [asOf] (UTC). [mergedIds] maps
  /// farmer IDs the phone minted to the farmers they were merged into (from
  /// the sync log).
  Territory({
    required this._tables,
    required List<OutboxEntry> outbox,
    this.meta = const SyncMeta(),
    required DateTime asOf,
    this._mergedIds = const {},
  }) : outbox = List.unmodifiable(outbox),
       asOf = asOf.toUtc();

  /// A territory with no data yet.
  factory Territory.empty({required DateTime asOf}) =>
      Territory(tables: null, outbox: const [], asOf: asOf);

  /// Reads the current territory from [store].
  static Future<Territory> load(
    LocalTables store, {
    required DateTime asOf,
  }) async {
    final tables = await store.territoryTables();
    final outbox = await store.outbox();
    final meta = await store.syncMeta();
    final log = await store.syncLog();
    return Territory(
      tables: tables,
      outbox: outbox,
      meta: meta,
      asOf: asOf,
      mergedIds: {
        for (final l in log)
          if (l.kind == SyncLogKind.merged &&
              l.entityId != null &&
              l.message != null)
            l.entityId!: l.message!,
      },
    );
  }

  final Snapshot? _tables;
  final Map<String, String> _mergedIds;

  /// Every outbox row, in seq order.
  final List<OutboxEntry> outbox;

  /// Sync metadata (last pull, versions).
  final SyncMeta meta;

  /// When this read model was built (UTC); "today" for the queries.
  final DateTime asOf;

  /// Today in IST.
  LocalDate get today => LocalDate.istOf(asOf);

  /// True once a snapshot has been stored.
  bool get hasData => _tables != null;

  static final _noMasters = SnapMasters(
    version: 0,
    seasonCodes: SnapSeasonCodes(
      current: '',
      next: '',
      allOpen: const [],
      validUntil: LocalDate(1970, 1, 1),
    ),
    crops: const [],
    issues: const [],
    salts: const [],
    skus: const [],
    rules: const [],
  );

  /// Farmers the FA may act on.
  List<SnapFarmer> get farmers => _tables?.farmers ?? const [];

  /// Villages in the FA's area.
  List<SnapVillage> get villages => _tables?.villages ?? const [];

  /// Crops, issues, salts, SKUs, rules, season codes.
  SnapMasters get masters => _tables?.masters ?? _noMasters;

  /// Season codes to offer for StartSeason. Past `valid_until` (IST) the old
  /// `next` is offered as current until a fresh pull (plan, Enrol step 3).
  SnapSeasonCodes get seasonCodes {
    final codes = masters.seasonCodes;
    if (!today.isAfter(codes.validUntil) || codes.next.isEmpty) return codes;
    return SnapSeasonCodes(
      current: codes.next,
      next: codes.next,
      allOpen: [
        for (final c in codes.allOpen)
          if (c != codes.current) c,
      ],
      validUntil: codes.validUntil,
    );
  }

  // -------------------------------------------------------------------------
  // Indexes

  late final Map<String, SnapFarmer> _farmers = {
    for (final f in farmers) f.id: f,
  };
  late final Map<String, SnapPlot> _plots = {
    for (final p in _tables?.plots ?? const <SnapPlot>[]) p.id: p,
  };
  late final Map<String, SnapSeason> _seasons = {
    for (final s in _tables?.seasons ?? const <SnapSeason>[]) s.id: s,
  };
  late final Map<String, SnapVisit> _visits = {
    for (final v in _tables?.visits ?? const <SnapVisit>[]) v.id: v,
  };
  late final Map<String, SnapVillage> _villages = {
    for (final v in villages) v.id: v,
  };
  late final Map<String, List<SnapPlot>> _plotsByFarmer = _group(
    _plots.values,
    (p) => p.farmerId,
  );
  late final Map<String, List<SnapSeason>> _seasonsByPlot = _group(
    _seasons.values,
    (s) => s.plotId,
  );
  late final Map<String, List<SnapVisit>> _visitsByFarmer = _group(
    _visits.values,
    (v) => v.farmerId,
  );

  /// Farmer IDs the phone minted that a merge replaced (`merged_from` ->
  /// `merged_into`), so a screen opened with the old ID still finds the
  /// farmer.
  late final Map<String, String> aliases = {
    ..._mergedIds,
    ...meta.idAliases,
    for (final e in outbox)
      if (e.state == OutboxState.merged &&
          e.meta[OutboxMeta.mergedFrom] is String &&
          e.result?.mergedInto != null)
        e.meta[OutboxMeta.mergedFrom]! as String: e.result!.mergedInto!,
  };

  static Map<String, List<T>> _group<T>(
    Iterable<T> items,
    String Function(T) key,
  ) {
    final out = <String, List<T>>{};
    for (final item in items) {
      (out[key(item)] ??= []).add(item);
    }
    return out;
  }

  // -------------------------------------------------------------------------
  // Lookups

  /// [id], or the farmer it was merged into.
  String resolveFarmerId(String id) => aliases[id] ?? id;

  /// A farmer by ID (merged IDs resolve), or null.
  SnapFarmer? farmer(String id) => _farmers[resolveFarmerId(id)];

  /// A plot by ID, or null.
  SnapPlot? plot(String id) => _plots[id];

  /// A season by ID (a season that clashed with the plot's active one
  /// resolves to it), or null.
  SnapSeason? season(String id) => _seasons[id] ?? _seasons[aliases[id]];

  /// A visit by ID, or null.
  SnapVisit? visit(String id) => _visits[id];

  /// A village by ID, or null.
  SnapVillage? village(String? id) => id == null ? null : _villages[id];

  /// A crop by ID, or null.
  SnapCrop? crop(String? id) => id == null ? null : masters.cropById(id);

  /// An alert by ID, or null.
  SnapAlert? alert(String id) {
    for (final a in _tables?.alerts ?? const <SnapAlert>[]) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// An open call-back by ID, or null.
  SnapCallback? callback(String id) {
    for (final c in _tables?.callbacks ?? const <SnapCallback>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// True while the visit's LogVisit is still queued and was never sent, so
  /// "Edit this visit" may replace it (`FaActions.editQueuedVisit`).
  bool isVisitEditable(String visitId) {
    for (final e in outbox.reversed) {
      if (e.type != CommandType.logVisit || e.entityId != visitId) continue;
      return e.state == OutboxState.queued && e.attempts == 0;
    }
    return false;
  }

  /// A farmer by phone (any way it is typed), or null.
  SnapFarmer? farmerByPhone(String phone) {
    final norm = normalizeIndianMobile(phone);
    if (norm == null) return null;
    for (final f in farmers) {
      if ((normalizeIndianMobile(f.phone) ?? f.phone) == norm) return f;
    }
    return null;
  }

  /// A farmer's active plots, in snapshot order.
  List<SnapPlot> plotsOf(String farmerId) => [
    for (final p
        in _plotsByFarmer[resolveFarmerId(farmerId)] ?? const <SnapPlot>[])
      if (p.status == PlotStatus.active) p,
  ];

  /// A plot's active season (the latest when there are several), or null.
  SnapSeason? activeSeason(String plotId) {
    SnapSeason? best;
    for (final s in _seasonsByPlot[plotId] ?? const <SnapSeason>[]) {
      if (s.status != SeasonStatus.active) continue;
      if (best == null || !s.updatedAt.isBefore(best.updatedAt)) best = s;
    }
    return best;
  }

  /// A farmer's visits that are not cancelled (planned, missed or done).
  List<SnapVisit> visitsOf(String farmerId) => [
    for (final v
        in _visitsByFarmer[resolveFarmerId(farmerId)] ?? const <SnapVisit>[])
      if (isOpenPlan(v) || v.status == VisitStatus.done) v,
  ];

  /// A visit still to be done: planned, or `missed` (the server's hourly job
  /// marks a planned visit whose day passed). Both can be logged or moved.
  static bool isOpenPlan(SnapVisit v) =>
      v.status == VisitStatus.planned || v.status == VisitStatus.missed;

  /// The latest done visit of a farmer, or null.
  SnapVisit? lastDoneVisit(String farmerId) {
    SnapVisit? best;
    for (final v in visitsOf(farmerId)) {
      if (v.status != VisitStatus.done || v.visitedAt == null) continue;
      if (best == null || v.visitedAt!.isAfter(best.visitedAt!)) best = v;
    }
    return best;
  }

  /// The soonest planned visit of a farmer (overdue and missed ones
  /// first), or null.
  SnapVisit? nextPlannedVisit(String farmerId) {
    final planned = [
      for (final v in visitsOf(farmerId))
        if (isOpenPlan(v) && v.plannedFor != null) v,
    ]..sort((a, b) => a.plannedFor!.compareTo(b.plannedFor!));
    return planned.isEmpty ? null : planned.first;
  }

  /// The visit "Start visit" should log for [farmerId] on [day] (default
  /// today): the earliest planned or missed visit planned for [day] or
  /// before, optionally only on [plotId]. Null means an unplanned visit.
  /// Logging it (LogVisit with its `visit_id`) turns that plan done instead
  /// of leaving it overdue next to a second, unplanned visit.
  SnapVisit? startableVisitFor(
    String farmerId, {
    LocalDate? day,
    String? plotId,
  }) {
    final d = day ?? today;
    SnapVisit? best;
    for (final v in visitsOf(farmerId)) {
      final at = v.plannedFor;
      if (!isOpenPlan(v) || at == null || at.isAfter(d)) continue;
      if (plotId != null && v.plotId != plotId) continue;
      if (best == null || at.isBefore(best.plannedFor!)) best = v;
    }
    return best;
  }

  /// The open call-back of a farmer, or null.
  SnapCallback? openCallback(String farmerId) {
    final id = resolveFarmerId(farmerId);
    for (final c in _tables?.callbacks ?? const <SnapCallback>[]) {
      if (c.farmerId == id) return c;
    }
    return null;
  }

  /// The stage of [season]'s crop on [day] (default today), or null without
  /// a sowing date. Before the first stage gives the first, after the last
  /// gives the last.
  SnapStage? stageOf(SnapSeason season, {LocalDate? day}) {
    final das = season.daysAfterSowing(day ?? today);
    final c = crop(season.cropId);
    if (das == null || c == null || c.stages.isEmpty) return null;
    final at = c.stageAt(das);
    if (at != null) return at;
    final stages = [...c.stages]..sort((a, b) => a.seq.compareTo(b.seq));
    return das < stages.first.startDay ? stages.first : stages.last;
  }

  /// A plot with its active season, crop and stage.
  PlotSummary plotSummary(SnapPlot plot, {LocalDate? day}) {
    final s = activeSeason(plot.id);
    return PlotSummary(
      plot: plot,
      season: s,
      crop: crop(s?.cropId),
      stage: s == null ? null : stageOf(s, day: day),
      daysAfterSowing: s?.daysAfterSowing(day ?? today),
      pendingSync: isPending(plot.id) || (s != null && isPending(s.id)),
    );
  }

  /// Where a farmer is: the plot nearest [from] (or the first plot), else the
  /// village. Null when neither has a location.
  LatLng? farmerLocation(String farmerId, {LatLng? from}) {
    LatLng? best;
    double? bestKm;
    for (final p in plotsOf(farmerId)) {
      final at = plotLocation(p);
      if (at == null) continue;
      if (from == null) return at;
      final km = distanceKm(from, at);
      if (bestKm == null || km < bestKm) {
        best = at;
        bestKm = km;
      }
    }
    return best ?? village(farmer(farmerId)?.villageId)?.location;
  }

  // -------------------------------------------------------------------------
  // Farmers near me

  /// The list row of one farmer, or null when unknown.
  FarmerRow? farmerRow(String farmerId, {LatLng? from, LocalDate? day}) {
    final f = farmer(farmerId);
    return f == null ? null : _row(f, from, day ?? today);
  }

  FarmerRow _row(SnapFarmer f, LatLng? from, LocalDate day) {
    final plots = [for (final p in plotsOf(f.id)) plotSummary(p, day: day)];
    final last = lastDoneVisit(f.id);
    final since = last == null
        ? null
        : LocalDate.istOf(last.visitedAt!).daysUntil(day);
    final next = nextPlannedVisit(f.id);
    final age = LocalDate.istOf(f.createdAt).daysUntil(day);
    final gaps = <EnrolmentGap>{
      if (f.status == FarmerStatus.pendingProfile ||
          f.name == null ||
          f.villageId == null)
        EnrolmentGap.profile,
      if (f.consentPending) EnrolmentGap.consent,
      if (plots.isEmpty) EnrolmentGap.plot,
      if (plots.isNotEmpty && plots.every((p) => p.season == null))
        EnrolmentGap.season,
    };
    final hasCrop = plots.any((p) => p.season != null);
    final enrolled = f.status != FarmerStatus.pendingProfile;
    final location = farmerLocation(f.id, from: from);
    return FarmerRow(
      farmer: f,
      village: village(f.villageId),
      location: location,
      distanceKm: from == null || location == null
          ? null
          : distanceKm(from, location),
      plots: plots,
      lastDoneVisit: last,
      daysSinceLastVisit: since,
      nextPlannedVisit: next,
      enrolmentGaps: gaps,
      isNew:
          f.status == FarmerStatus.pendingProfile ||
          age < TerritoryRules.newDays,
      isVisitDue:
          (next != null &&
              !next.plannedFor!.isAfter(
                day.addDays(TerritoryRules.dueAheadDays),
              )) ||
          (enrolled &&
              hasCrop &&
              (since ?? age) >= TerritoryRules.dueAfterDays),
      isNotVisited30: enrolled && (since ?? age) >= TerritoryRules.staleDays,
      pendingSync: isPending(f.id),
    );
  }

  /// "Farmers near me": farmers matching [filter] and [query] (name or
  /// phone), nearest to [from] first (farmers without a location last), then
  /// by name. Without [from] the order is by name.
  List<FarmerRow> farmerRows({
    LatLng? from,
    FarmerFilter filter = FarmerFilter.all,
    String? query,
    LocalDate? day,
  }) {
    final d = day ?? today;
    final rows = [
      for (final f in farmers)
        if (_matchesQuery(f, query)) _row(f, from, d),
    ].where((r) => r.matches(filter)).toList();
    rows.sort((a, b) {
      final da = a.distanceKm;
      final db = b.distanceKm;
      if (da != null && db != null && da != db) return da.compareTo(db);
      if (da != null && db == null) return -1;
      if (da == null && db != null) return 1;
      return (a.farmer.name ?? a.farmer.phone).toLowerCase().compareTo(
        (b.farmer.name ?? b.farmer.phone).toLowerCase(),
      );
    });
    return rows;
  }

  /// How many farmers each chip would show.
  Map<FarmerFilter, int> filterCounts({String? query, LocalDate? day}) {
    final d = day ?? today;
    final rows = [
      for (final f in farmers)
        if (_matchesQuery(f, query)) _row(f, null, d),
    ];
    return {
      for (final filter in FarmerFilter.values)
        filter: rows.where((r) => r.matches(filter)).length,
    };
  }

  /// Farmers whose name (English or Telugu) or phone matches [query].
  List<SnapFarmer> search(String query) => [
    for (final f in farmers)
      if (_matchesQuery(f, query)) f,
  ];

  static bool _matchesQuery(SnapFarmer f, String? query) {
    final q = query?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return true;
    final compact = q.replaceAll(RegExp(r'[\s\-()]'), '');
    final numeric = compact.replaceFirst(RegExp(r'^\+'), '');
    if (numeric.length >= 3 && RegExp(r'^[0-9]+$').hasMatch(numeric)) {
      final phone = f.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final local = phone.length > 10
          ? phone.substring(phone.length - 10)
          : phone;
      return phoneQueryDigits(compact).any(local.contains);
    }
    return (f.name?.toLowerCase().contains(q) ?? false) ||
        (f.nameTe?.toLowerCase().contains(q) ?? false);
  }

  /// The local digits a typed phone query can stand for: "+91 98480" and
  /// "098480" mean "98480". A query starting "91" without "+" may be the
  /// country code or the start of a number, so both are tried.
  static List<String> phoneQueryDigits(String typed) {
    var t = typed.replaceAll(RegExp(r'[\s\-()]'), '');
    final plus = t.startsWith('+');
    t = t.replaceAll(RegExp(r'[^0-9]'), '');
    if (plus && t.startsWith('91')) return [t.substring(2)];
    if (t.startsWith('0')) return [t.replaceFirst(RegExp(r'^0+'), '')];
    if (t.startsWith('91')) {
      return t.length > 10 ? [t.substring(2)] : [t, t.substring(2)];
    }
    if (t.length > 10) return [t.substring(t.length - 10)];
    return [t];
  }

  /// Farmer 360 for [farmerId] (merged IDs resolve), or null when unknown.
  Farmer360? farmer360(String farmerId, {LatLng? from, LocalDate? day}) {
    final row = farmerRow(farmerId, from: from, day: day);
    if (row == null) return null;
    final visits = visitsOf(row.farmer.id);
    final done = [
      for (final v in visits)
        if (v.status == VisitStatus.done && v.visitedAt != null) visitRow(v),
    ]..sort((a, b) => b.visit.visitedAt!.compareTo(a.visit.visitedAt!));
    final planned = [
      for (final v in visits)
        if (isOpenPlan(v) && v.plannedFor != null) visitRow(v),
    ]..sort((a, b) => a.visit.plannedFor!.compareTo(b.visit.plannedFor!));
    return Farmer360(
      row: row,
      doneVisits: done,
      plannedVisits: planned,
      openCallback: openCallback(row.farmer.id),
    );
  }

  /// The village nearest [point] (for "village from GPS"), or null.
  SnapVillage? nearestVillage(LatLng point) {
    SnapVillage? best;
    double? bestKm;
    for (final v in villages) {
      final at = v.location;
      if (at == null) continue;
      final km = distanceKm(point, at);
      if (bestKm == null || km < bestKm) {
        best = v;
        bestKm = km;
      }
    }
    return best;
  }

  // -------------------------------------------------------------------------
  // Calendar

  /// A visit with its farmer, plot, season, crop and slot.
  VisitRow visitRow(SnapVisit v) {
    final s = season(v.seasonId);
    return VisitRow(
      visit: v,
      farmer: farmer(v.farmerId),
      plot: plot(v.plotId),
      season: s,
      crop: crop(s?.cropId),
      slot: _slotOf(v),
      pendingSync: isPending(v.id),
    );
  }

  static VisitSlot _slotOf(SnapVisit v) {
    final planned = v.plannedSlot;
    if (planned == VisitSlot.morning || planned == VisitSlot.afternoon) {
      return planned!;
    }
    if (v.status == VisitStatus.done && v.visitedAt != null) {
      final ist = v.visitedAt!.toUtc().add(
        const Duration(hours: 5, minutes: 30),
      );
      return ist.hour < 12 ? VisitSlot.morning : VisitSlot.afternoon;
    }
    return VisitSlot.any;
  }

  /// The day a visit belongs to: when it was done (IST), else when planned
  /// (a missed visit too; [overdueVisits] lists it again under today).
  static LocalDate? visitDay(SnapVisit v) => switch (v.status) {
    VisitStatus.done when v.visitedAt != null => LocalDate.istOf(v.visitedAt!),
    VisitStatus.planned || VisitStatus.missed => v.plannedFor,
    _ => null,
  };

  /// Planned or missed visits whose day is before [day] (default today),
  /// oldest first, then by farmer name: the calendar shows them under today
  /// ("Overdue") so they can still be started or moved.
  List<VisitRow> overdueVisits({LocalDate? day}) {
    final d = day ?? today;
    final rows = [
      for (final v in _visits.values)
        if (isOpenPlan(v) && v.plannedFor != null && v.plannedFor!.isBefore(d))
          visitRow(v),
    ];
    rows.sort((a, b) {
      final c = a.visit.plannedFor!.compareTo(b.visit.plannedFor!);
      if (c != 0) return c;
      return (a.farmer?.name ?? '').toLowerCase().compareTo(
        (b.farmer?.name ?? '').toLowerCase(),
      );
    });
    return rows;
  }

  /// The visits of [day] (planned for it, or done on it), by slot. Within a
  /// slot: planned before done, then by farmer name.
  DayPlan visitsOn(LocalDate day) {
    final rows = [
      for (final v in _visits.values)
        if (visitDay(v) == day) visitRow(v),
    ];
    rows.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return (a.farmer?.name ?? '').toLowerCase().compareTo(
        (b.farmer?.name ?? '').toLowerCase(),
      );
    });
    return DayPlan(
      day: day,
      morning: [
        for (final r in rows)
          if (r.slot == VisitSlot.morning) r,
      ],
      afternoon: [
        for (final r in rows)
          if (r.slot == VisitSlot.afternoon) r,
      ],
      anytime: [
        for (final r in rows)
          if (r.slot != VisitSlot.morning && r.slot != VisitSlot.afternoon) r,
      ],
    );
  }

  /// Visit counts for [days] days from [start] (the week strip).
  List<DayCount> weekCounts(LocalDate start, {int days = 7}) {
    final planned = <LocalDate, int>{};
    final done = <LocalDate, int>{};
    for (final v in _visits.values) {
      final d = visitDay(v);
      if (d == null) continue;
      final map = v.status == VisitStatus.done ? done : planned;
      map[d] = (map[d] ?? 0) + 1;
    }
    return [
      for (var i = 0; i < days; i++)
        DayCount(
          day: start.addDays(i),
          planned: planned[start.addDays(i)] ?? 0,
          done: done[start.addDays(i)] ?? 0,
        ),
    ];
  }

  // -------------------------------------------------------------------------
  // Alerts

  /// Alerts to show (not closed; `invoice_check` is Phase 2 and hidden),
  /// newest first.
  List<SnapAlert> get alerts => [
    for (final a in _tables?.alerts ?? const <SnapAlert>[])
      if (a.status != AlertStatus.closed && a.kind != AlertKind.invoiceCheck) a,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Every alert on the phone, closed ones included (`invoice_check` is
  /// still hidden), newest first: for history and counts.
  List<SnapAlert> get allAlerts => [
    for (final a in _tables?.alerts ?? const <SnapAlert>[])
      if (a.kind != AlertKind.invoiceCheck) a,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Open alerts (the tab badge).
  int get openAlertCount =>
      alerts.where((a) => a.status == AlertStatus.open).length;

  // -------------------------------------------------------------------------
  // Masters for the visit log

  /// The stage to preselect for [seasonId] today (from days after sowing), or
  /// null.
  SnapStage? suggestedStage(String seasonId, {LocalDate? day}) {
    final s = season(seasonId);
    return s == null ? null : stageOf(s, day: day);
  }

  /// Issues of [cropId], optionally only of [type].
  List<SnapIssue> issuesFor(String cropId, {IssueType? type}) => [
    for (final i in masters.issuesForCrop(cropId))
      if (type == null || i.type == type) i,
  ];

  /// The issue types [cropId] has issues of, in [IssueType] order.
  List<IssueType> issueTypesFor(String cropId) {
    final types = {for (final i in masters.issuesForCrop(cropId)) i.type};
    return [
      for (final t in IssueType.values)
        if (types.contains(t)) t,
    ];
  }

  /// Salts the masters suggest for [issueId], with dose and product. Empty
  /// when there is no rule (log the issue with `advisory_rule_id: null`).
  List<AdviceOption> adviceFor(String issueId) => [
    for (final r in masters.rulesForIssue(issueId))
      AdviceOption(
        rule: r,
        salt: masters.saltById(r.saltId),
        sku: r.skuId == null ? null : masters.skuById(r.skuId!),
      ),
  ];

  // -------------------------------------------------------------------------
  // Not synced yet

  /// IDs of every entity with a change on this phone the server has not
  /// answered (queued, sending, conflict): entities, the IDs they create and
  /// their farmers.
  late final Set<String> pendingEntityIds = _pendingIds();

  Set<String> _pendingIds() {
    final ids = <String>{};
    for (final e in outbox) {
      if (!e.state.isPending && e.state != OutboxState.conflict) continue;
      ids.add(e.entityId);
      try {
        final c = e.command;
        ids.addAll(c.createdIds);
        final farmerId =
            c.farmerId ??
            visit(e.entityId)?.farmerId ??
            alert(e.entityId)?.farmerId;
        if (farmerId != null) ids.add(resolveFarmerId(farmerId));
        for (final id in [...ids]) {
          final into = aliases[id];
          if (into != null) ids.add(into);
        }
      } on FormatException {
        // An unreadable payload still marks its entity.
      }
    }
    return ids;
  }

  /// True when [id] (a farmer, plot, season, visit, ...) has a change that
  /// is not synced yet.
  bool isPending(String id) => pendingEntityIds.contains(id);

  /// Records waiting to go up (queued or sending).
  int get unsyncedCount => outbox.where((e) => e.state.isPending).length;

  /// Rows that need the FA on the Sync screen (conflict, rejected, dropped).
  int get needsAttentionCount =>
      outbox.where((e) => e.state.needsAttention).length;

  /// Number of farmers (the PIN screen's "46 farmers and 3 unsynced
  /// records").
  int get farmerCount => farmers.length;

  /// Active plots of the farmers on the phone.
  int get plotCount => farmers.fold(0, (n, f) => n + plotsOf(f.id).length);

  /// Visits done in the IST month of [month] (any day of it) by farmers on
  /// the phone.
  ///
  /// The snapshot keeps every planned visit but only the three latest done
  /// visits per farmer, so this counts what the phone knows (exact for an
  /// FA who visits a farmer at most three times a month).
  int doneVisitsInMonth(LocalDate month) {
    var n = 0;
    for (final f in farmers) {
      for (final v in visitsOf(f.id)) {
        if (v.status == VisitStatus.done && _inMonth(v.visitedAt, month)) n++;
      }
    }
    return n;
  }

  /// Farmers enrolled in the IST month of [month]: those an FA enrolled, by
  /// when they were created, and self sign-ups, by when their enrolment was
  /// finished (`profile_completed_at`).
  int enrolledInMonth(LocalDate month) => farmers
      .where(
        (f) => _inMonth(switch (f.source) {
          FarmerSource.fa => f.createdAt,
          FarmerSource.self => f.profileCompletedAt,
          _ => null,
        }, month),
      )
      .length;

  static bool _inMonth(DateTime? at, LocalDate month) {
    if (at == null) return false;
    final d = LocalDate.istOf(at);
    return d.year == month.year && d.month == month.month;
  }
}
