// toJson -> fromJson round trips for what the local store and the session
// store keep: the whole snapshot (every Snap* and masters model) and the
// session's TokenPair, FieldAssistant and OfflinePolicy.

import 'dart:convert';

import 'package:fa/src/data/data.dart';
import 'package:fa/src/local/commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../support/mock_support.dart';

/// Through a JSON string, as a store would keep it.
Map<String, Object?> viaText(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  test('the seeded snapshot round-trips, every section and model', () async {
    final w = await MockWorld.signedIn();
    // The seed has something of every kind: a done visit with issues, a plot
    // with a boundary and one with a pin only, a salt-only rule.
    final snap = await w.snapshot();
    expect(snap.farmers, isNotEmpty);
    expect(snap.plots.where((p) => p.boundaryGeoJson != null), isNotEmpty);
    expect(snap.plots.where((p) => p.boundaryGeoJson == null), isNotEmpty);
    expect(snap.visits.where((v) => v.issues.isNotEmpty), isNotEmpty);
    expect(snap.callbacks, isNotEmpty);
    expect(snap.alerts, isNotEmpty);
    expect(snap.masters.rules.where((r) => r.skuId == null), isNotEmpty);
    expect(snap.villages.where((v) => v.location != null), isNotEmpty);

    final back = Snapshot.fromJson(viaText(snap.toJson()));
    expect(back, snap);
    expect(back.etag, snap.etag);
    // Item by item, so a failure names the model.
    for (final (a, b) in [
      for (var i = 0; i < snap.farmers.length; i++)
        (snap.farmers[i], back.farmers[i]),
      for (var i = 0; i < snap.plots.length; i++)
        (snap.plots[i], back.plots[i]),
      for (var i = 0; i < snap.visits.length; i++)
        (snap.visits[i], back.visits[i]),
      for (var i = 0; i < snap.masters.crops.length; i++)
        (snap.masters.crops[i], back.masters.crops[i]),
    ]) {
      expect(b, a);
    }
    expect(back.masters, snap.masters);
    expect(back.masters.seasonCodes, snap.masters.seasonCodes);
  });

  test('a missed visit and unknown enum values round-trip', () async {
    final w = await MockWorld.signedIn();
    await w.push([
      PlanVisitPayload(
        visitId: w.newId(),
        farmerId: MockBackend.raviId,
        plotId: MockBackend.raviPlotId,
        seasonId: MockBackend.raviSeasonId,
        plannedFor: LocalDate.istOf(mockTestNow),
        plannedSlot: VisitSlot.any,
      ),
    ]);
    w.clock.advance(const Duration(days: 1));
    final snap = await w.snapshot();
    expect(
      snap.visits.where((v) => v.status == VisitStatus.missed),
      isNotEmpty,
    );
    expect(Snapshot.fromJson(viaText(snap.toJson())), snap);

    // A value this app version does not know reads as `unknown` and is
    // written back as '' (still `unknown` when read again).
    final odd = SnapVisit.fromJson({
      ...snap.visits.first.toJson(),
      'status': 'rescheduled',
      'planned_slot': 'evening',
    });
    expect(odd.status, VisitStatus.unknown);
    expect(SnapVisit.fromJson(viaText(odd.toJson())), odd);
  });

  test('toJson uses the server keys and shapes', () async {
    final w = await MockWorld.signedIn();
    final snap = await w.snapshot();
    final json = viaText(snap.toJson());
    expect(json.keys, {
      'territory_version',
      'masters_version',
      'generated_at',
      'sections',
    });
    final sections = json['sections']! as Map<String, Object?>;
    expect(sections.keys, {
      'farmers',
      'plots',
      'seasons',
      'visits',
      'callbacks',
      'alerts',
      'masters',
      'villages',
    });
    final plot = (sections['plots']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .firstWhere((p) => p['boundary'] != null);
    // The boundary goes out as a GeoJSON object, like SnapPlot.boundary.
    expect(plot['boundary'], isA<Map<String, Object?>>());
    final farmer = (sections['farmers']! as List<Object?>).first! as Map;
    expect(farmer['created_at'], endsWith('Z'));
    expect(farmer.containsKey('photo_key'), isTrue); // nullable keys stay
  });

  test('session models round-trip through JSON', () async {
    final w = MockWorld();
    final s = await w.login();
    expect(TokenPair.fromJson(viaText(s.tokens.toJson())), s.tokens);
    expect(s.tokens.toJson()['token_type'], 'Bearer');
    expect(
      FieldAssistant.fromJson(viaText(s.fieldAssistant.toJson())),
      s.fieldAssistant,
    );
    expect(
      OfflinePolicy.fromJson(viaText(s.offlinePolicy.toJson())),
      s.offlinePolicy,
    );
  });
}
