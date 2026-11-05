/// The Sync screen's rows, built from the engine's [SyncState] (outbox rows
/// and photos per visit log) and the territory (farmer names).
///
/// The engine exposes outbox rows; this adds what a row shows that the row
/// itself doesn't carry (who it is about), and groups refused records with
/// the ones dropped because of them.
library;

import '../../data/data.dart';
import '../../local/commands.dart'
    show CommandPayload, EnrolFarmerPayload, SavePlotPayload;
import '../../local/local.dart';

/// Where a waiting record is, for its pill.
enum RecordProgress {
  /// Not sent yet.
  waiting,

  /// On its way.
  uploading,

  /// HO has it.
  synced,
}

/// One outbox row with what the screen shows about it.
final class SyncRecord {
  /// Creates a record.
  const SyncRecord({
    required this.entry,
    required this.name,
    required this.progress,
    this.photos,
    this.plotLabel,
  });

  /// The outbox row.
  final OutboxEntry entry;

  /// Who or what it is about (farmer name, or the alert's title), or null.
  final String? name;

  /// Its pill.
  final RecordProgress progress;

  /// Photos of a visit log, or null.
  final CommandPhotos? photos;

  /// For a plot: its label ("Plot 2"), or null.
  final String? plotLabel;
}

/// A refused record with the records dropped because of it.
final class RejectedGroup {
  /// Creates a group.
  const RejectedGroup({required this.record, required this.dropped});

  /// The refused (or dropped, when its parent was already tapped away) row.
  final SyncRecord record;

  /// Rows not saved because of [record] (dropped before they were sent, or
  /// refused with it in the same batch), in seq order.
  final List<SyncRecord> dropped;

  /// Every row of the group (tapped away together).
  Iterable<OutboxEntry> get entries => [
    record.entry,
    for (final d in dropped) d.entry,
  ];
}

/// A conflict the FA resolved, until tapped away.
final class ResolvedRecord {
  /// Creates the row.
  const ResolvedRecord({
    required this.record,
    required this.keptMine,
    required this.progress,
  });

  /// The resolved row.
  final SyncRecord record;

  /// Keep mine (else Keep HO's).
  final bool keptMine;

  /// For Keep mine: where the resent change is; Keep HO's: synced.
  final RecordProgress progress;
}

/// Every row of the Sync screen, in the design's order.
final class SyncView {
  /// Creates the view.
  const SyncView({
    required this.records,
    required this.conflicts,
    required this.resolved,
    required this.rejected,
  });

  /// Builds the rows from [state] and [territory], in [language], as of
  /// [now].
  factory SyncView.build(
    SyncState state,
    Territory territory, {
    required Language language,
    required DateTime now,
  }) {
    final byId = {for (final e in state.records) e.id: e};
    // Names the FA typed at enrolment, for records about a farmer the
    // territory no longer has (a refused enrolment is taken back).
    final typedNames = <String, String>{};
    for (final e in state.records) {
      if (e.type != CommandType.enrolFarmer) continue;
      try {
        if (e.command case final EnrolFarmerPayload p) {
          final name = pickText(language, te: p.nameTe, en: p.name);
          if (name.isNotEmpty) typedNames[p.farmerId] = name;
        }
      } on Object {
        // An unreadable payload has no name to offer.
      }
    }

    RecordProgress progressOf(OutboxEntry e) {
      if (e.state.isSynced) return RecordProgress.synced;
      if (e.state == OutboxState.sending) return RecordProgress.uploading;
      final backoff = e.nextAttemptAt;
      final due = backoff == null || !backoff.isAfter(now);
      return state.running && due && e.state == OutboxState.queued
          ? RecordProgress.uploading
          : RecordProgress.waiting;
    }

    SyncRecord record(OutboxEntry e) {
      final CommandPayload command;
      try {
        command = e.command;
      } on Object {
        return SyncRecord(entry: e, name: null, progress: progressOf(e));
      }
      return SyncRecord(
        entry: e,
        name: _nameOf(e, command, territory, language, typedNames),
        progress: progressOf(e),
        photos: e.type == CommandType.logVisit
            ? state.photosByCommand[e.id]
            : null,
        plotLabel: switch (command) {
          final SavePlotPayload p => territory.plot(p.plotId)?.label ?? p.label,
          _ => null,
        },
      );
    }

    final records = <SyncRecord>[];
    final conflicts = <SyncRecord>[];
    final resolved = <ResolvedRecord>[];
    final attention = <OutboxEntry>[];
    for (final e in state.records) {
      switch (e.state) {
        case OutboxState.queued ||
            OutboxState.sending ||
            OutboxState.applied ||
            OutboxState.merged:
          // A Keep mine resend shows on its resolved row.
          final replaces = e.meta[OutboxMeta.replaces];
          if (replaces is String && byId.containsKey(replaces)) continue;
          records.add(record(e));
        case OutboxState.conflict:
          conflicts.add(record(e));
        case OutboxState.resolved:
          final mine = e.meta[OutboxMeta.resolution] == 'mine';
          final by = e.meta[OutboxMeta.replacedBy];
          final resend = by is String ? byId[by] : null;
          resolved.add(
            ResolvedRecord(
              record: record(e),
              keptMine: mine,
              progress: mine && resend != null
                  ? progressOf(resend)
                  : RecordProgress.synced,
            ),
          );
        case OutboxState.rejected || OutboxState.dropped:
          attention.add(e);
      }
    }

    // Group rows that depend on a refused row under it (dropped ones, and
    // ones the server refused in the same batch).
    final attentionIds = {for (final e in attention) e.id};
    String rootOf(OutboxEntry e) {
      var current = e;
      final seen = <String>{};
      while (true) {
        final parent = current.dependsOnId;
        if (parent == null ||
            !attentionIds.contains(parent) ||
            !seen.add(parent)) {
          return current.id;
        }
        current = byId[parent]!;
      }
    }

    final groups = <String, List<OutboxEntry>>{};
    for (final e in attention) {
      (groups[rootOf(e)] ??= []).add(e);
    }
    final rejected = [
      for (final MapEntry(key: root, value: members) in groups.entries)
        RejectedGroup(
          record: record(byId[root]!),
          dropped: [
            for (final m in members)
              if (m.id != root) record(m),
          ],
        ),
    ];

    return SyncView(
      records: records,
      conflicts: conflicts,
      resolved: resolved,
      rejected: rejected,
    );
  }

  /// Waiting, uploading and synced rows.
  final List<SyncRecord> records;

  /// Conflicts waiting for Keep mine / Keep HO's.
  final List<SyncRecord> conflicts;

  /// Conflicts the FA resolved.
  final List<ResolvedRecord> resolved;

  /// Refused records, each with what was dropped because of it.
  final List<RejectedGroup> rejected;

  static String? _nameOf(
    OutboxEntry e,
    CommandPayload command,
    Territory territory,
    Language language,
    Map<String, String> typedNames,
  ) {
    String? farmerName(String? id) {
      if (id == null) return null;
      final name = territory.farmer(id)?.displayName(language);
      return name == null || name.isEmpty ? null : name;
    }

    switch (e.type) {
      case CommandType.ackAlert:
        return territory.alert(e.entityId)?.displayTitle(language);
      case CommandType.cancelVisit:
        return farmerName(territory.visit(e.entityId)?.farmerId);
      case CommandType.closeCallback:
        return farmerName(territory.callback(e.entityId)?.farmerId);
      case CommandType.enrolFarmer ||
          CommandType.recordConsent ||
          CommandType.savePlot ||
          CommandType.startSeason ||
          CommandType.updateFarmer ||
          CommandType.planVisit ||
          CommandType.logVisit:
        final id = command.farmerId;
        return farmerName(id) ?? (id == null ? null : typedNames[id]);
    }
  }
}
