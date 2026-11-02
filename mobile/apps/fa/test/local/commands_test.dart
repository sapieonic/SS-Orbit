import 'dart:convert';

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/local/commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

const farmer = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a01';
const plot = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a02';
const season = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a03';
const visit = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a04';
const nextVisit = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a05';
const village = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a06';
const crop = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a07';

/// One literal payload per command type, field names as the Go decoders read
/// them (farmers/commands_payloads.go, visits/service_log.go logVisitPayload,
/// visits/commands.go, messaging AckAlert). Optional nulls are left out,
/// which is what `toJson()` sends.
final Map<CommandType, Map<String, Object?>> literal = {
  CommandType.enrolFarmer: {
    'farmer_id': farmer,
    'phone': '9000000101',
    'name': 'Ravi K',
    'name_te': 'రవి కె',
    'language': 'te',
    'village_id': village,
    'photo_key': 'farmers/$farmer/photo-1.jpg',
    'consent': {
      'purposes': ['programme', 'soil_partner'],
      'otp_proof': 'signed-proof',
      'audio_played': true,
      'notice_version': 'v3',
    },
  },
  CommandType.recordConsent: {
    'farmer_id': farmer,
    'purposes': ['programme'],
    'otp_proof': 'signed-proof',
    'audio_played': false,
    'notice_version': 'v3',
  },
  CommandType.savePlot: {
    'plot_id': plot,
    'farmer_id': farmer,
    'label': 'Plot 1',
    'boundary_geojson': {
      'type': 'Polygon',
      'coordinates': [
        [
          [78.36, 17.46],
          [78.37, 17.46],
          [78.37, 17.47],
          [78.36, 17.46],
        ],
      ],
    },
    'pin': {'lat': 17.465, 'lng': 78.365},
    'area_acres': 2.1,
    'area_source': 'boundary',
    'gps_accuracy_m': 4.5,
    'expected_version': 2,
  },
  CommandType.startSeason: {
    'season_id': season,
    'farmer_id': farmer,
    'plot_id': plot,
    'season_code': 'kharif-2026',
    'crop_id': crop,
    'sowing_date': '2026-07-01',
    'previous_crop_id': crop,
  },
  CommandType.updateFarmer: {
    'farmer_id': farmer,
    'expected_version': 4,
    'fields': {
      'name': 'Ravi Kumar',
      'name_te': 'రవి కుమార్',
      'language': 'en',
      'village_id': village,
      'photo_key': 'farmers/$farmer/photo-2.jpg',
    },
  },
  CommandType.planVisit: {
    'visit_id': visit,
    'farmer_id': farmer,
    'plot_id': plot,
    'season_id': season,
    'planned_for': '2026-11-03',
    'planned_slot': 'morning',
    'purpose': 'Check pink bollworm',
  },
  CommandType.logVisit: {
    'visit_id': visit,
    'farmer_id': farmer,
    'plot_id': plot,
    'season_id': season,
    'visited_at': '2026-11-02T05:30:00.000Z',
    'location': {'lat': 17.4651, 'lng': 78.3652},
    'farmer_present': true,
    'stage_id': 'stage-flowering',
    'notes': 'Pink bollworm on lower bolls',
    'issues': [
      {
        'issue_visit_id': 'iv-1',
        'issue_id': 'issue-pbw',
        'severity': 'moderate',
        'advisory_rule_id': 'rule-1',
      },
      {'issue_visit_id': 'iv-2', 'issue_id': 'issue-x', 'severity': 'low'},
    ],
    'photos': [
      {'photo_id': 'photo-1', 'content_type': 'image/jpeg'},
    ],
    'next_visit': {
      'visit_id': nextVisit,
      'planned_for': '2026-11-09',
      'planned_slot': 'any',
    },
  },
  CommandType.cancelVisit: {'visit_id': visit, 'reason': 'Farmer away'},
  CommandType.closeCallback: {
    'callback_id': 'cb-1',
    'note': 'Called, visit planned',
  },
  CommandType.ackAlert: {'alert_id': 'alert-1'},
};

void main() {
  test('CommandType wire names and entity types', () {
    expect(CommandType.values.map((t) => t.wire), [
      'EnrolFarmer',
      'RecordConsent',
      'SavePlot',
      'StartSeason',
      'UpdateFarmer',
      'PlanVisit',
      'LogVisit',
      'CancelVisit',
      'CloseCallback',
      'AckAlert',
    ]);
    for (final t in CommandType.values) {
      expect(CommandType.fromWire(t.wire), t);
    }
    expect(CommandType.fromWire('DeleteFarmer'), isNull);
    expect(CommandType.fromWire(null), isNull);
    expect(CommandType.logVisit.entityType, EntityType.visit);
    expect(EntityType.values.map((e) => e.wire), [
      'farmer',
      'plot',
      'season',
      'visit',
      'callback',
      'alert',
    ]);
    expect(EntityType.fromWire('season'), EntityType.season);
    expect(EntityType.fromWire('x'), isNull);
  });

  group('round trip through toJson / fromJson', () {
    for (final type in CommandType.values) {
      test(type.wire, () {
        final json = literal[type]!;
        final payload = CommandPayload.decode(type, json);
        expect(payload.type, type);
        expect(payload.toJson(), json);
        // The JSON survives encoding to text and back (what the outbox and
        // the HTTP body do).
        final again = CommandPayload.decode(
          type,
          jsonDecode(jsonEncode(payload.toJson())) as Map<String, Object?>,
        );
        expect(again, payload);
        expect(again.hashCode, payload.hashCode);
      });
    }
  });

  group('typed fields', () {
    test('EnrolFarmer', () {
      final p = CommandPayload.decode(
        CommandType.enrolFarmer,
        literal[CommandType.enrolFarmer]!,
      ) as EnrolFarmerPayload;
      expect(p.language, Language.te);
      expect(p.consent.purposes, [
        ConsentPurpose.programme,
        ConsentPurpose.soilPartner,
      ]);
      expect(p.consent.hasProof, isTrue);
      expect(p.entityType, EntityType.farmer);
      expect(p.entityId, farmer);
      expect(p.farmerId, farmer);
      expect(p.createdIds, {farmer});
      expect(p.dependsOnIds, isEmpty);
    });

    test('EnrolFarmer offline: no proof, optional fields left out', () {
      const p = EnrolFarmerPayload(
        farmerId: farmer,
        phone: '9000000101',
        name: 'Raju P',
        language: Language.te,
        villageId: village,
        consent: EnrolConsent(
          purposes: [ConsentPurpose.programme],
          otpProof: null,
          audioPlayed: true,
          noticeVersion: 'v3',
        ),
      );
      expect(p.consent.hasProof, isFalse);
      expect(p.toJson(), {
        'farmer_id': farmer,
        'phone': '9000000101',
        'name': 'Raju P',
        'language': 'te',
        'village_id': village,
        'consent': {
          'purposes': ['programme'],
          'audio_played': true,
          'notice_version': 'v3',
        },
      });
    });

    test('explicit nulls are read like absent fields', () {
      final p = EnrolFarmerPayload.fromJson({
        ...literal[CommandType.enrolFarmer]!,
        'name_te': null,
        'photo_key': null,
        'consent': {
          'purposes': ['programme'],
          'otp_proof': null,
          'audio_played': false,
          'notice_version': 'v3',
        },
      });
      expect(p.nameTe, isNull);
      expect(p.photoKey, isNull);
      expect(p.consent.otpProof, isNull);
      expect(
        CancelVisitPayload.fromJson({'visit_id': visit, 'reason': null}),
        const CancelVisitPayload(visitId: visit),
      );
    });

    test('SavePlot: new vs edit, boundary as text, pin', () {
      final edit = SavePlotPayload.fromJson(literal[CommandType.savePlot]!);
      expect(edit.isUpdate, isTrue);
      expect(edit.areaSource, AreaSource.boundary);
      expect(edit.pin, const LatLng(17.465, 78.365));
      expect(geoJsonOuterRings(edit.boundaryGeoJson).single, hasLength(4));
      expect(edit.createdIds, isEmpty);
      expect(edit.dependsOnIds, {farmer, plot});

      const created = SavePlotPayload(
        plotId: plot,
        farmerId: farmer,
        label: 'Plot 2',
        pin: LatLng(17.1, 78.2),
        areaAcres: 1.5,
        areaSource: AreaSource.typed,
      );
      expect(created.isUpdate, isFalse);
      expect(created.createdIds, {plot});
      expect(created.dependsOnIds, {farmer});
      expect(created.toJson(), {
        'plot_id': plot,
        'farmer_id': farmer,
        'label': 'Plot 2',
        'pin': {'lat': 17.1, 'lng': 78.2},
        'area_acres': 1.5,
        'area_source': 'typed',
      });
    });

    test('SavePlot accepts boundary_geojson as a string (Go accepts both)', () {
      final ring = polygonGeoJson(const [
        LatLng(17.46, 78.36),
        LatLng(17.46, 78.37),
        LatLng(17.47, 78.37),
      ]);
      final p = SavePlotPayload.fromJson({
        ...literal[CommandType.savePlot]!,
        'boundary_geojson': ring,
      });
      expect(p.boundaryGeoJson, ring);
      expect(
        p.toJson()['boundary_geojson'],
        literal[CommandType.savePlot]!['boundary_geojson'],
      );
      // area_acres as a JSON integer is fine.
      expect(
        SavePlotPayload.fromJson({
          ...literal[CommandType.savePlot]!,
          'area_acres': 2,
        }).areaAcres,
        2.0,
      );
    });

    test('StartSeason and PlanVisit use LocalDate and VisitSlot', () {
      final s = StartSeasonPayload.fromJson(literal[CommandType.startSeason]!);
      expect(s.sowingDate, LocalDate(2026, 7, 1));
      expect(s.dependsOnIds, {farmer, plot});
      expect(s.createdIds, {season});

      final v = PlanVisitPayload.fromJson(literal[CommandType.planVisit]!);
      expect(v.plannedFor, LocalDate(2026, 11, 3));
      expect(v.plannedSlot, VisitSlot.morning);
      expect(v.dependsOnIds, {farmer, plot, season});
      expect(v.createdIds, {visit});
    });

    test('UpdateFarmer fields', () {
      final u = UpdateFarmerPayload.fromJson(
        literal[CommandType.updateFarmer]!,
      );
      expect(u.fields.language, Language.en);
      expect(u.fields.isEmpty, isFalse);
      expect(u.createdIds, isEmpty);
      expect(u.dependsOnIds, {farmer});
      const nameOnly = UpdateFarmerPayload(
        farmerId: farmer,
        expectedVersion: 4,
        fields: UpdateFarmerFields(name: 'Ravi'),
      );
      expect(nameOnly.toJson(), {
        'farmer_id': farmer,
        'expected_version': 4,
        'fields': {'name': 'Ravi'},
      });
      expect(const UpdateFarmerFields().isEmpty, isTrue);
    });

    test('LogVisit issues, photos and next visit', () {
      final l = LogVisitPayload.fromJson(literal[CommandType.logVisit]!);
      expect(l.visitedAt, DateTime.utc(2026, 11, 2, 5, 30));
      expect(l.visitedAt.isUtc, isTrue);
      expect(l.location, const LatLng(17.4651, 78.3652));
      expect(l.issues.first.severity, Severity.moderate);
      expect(l.issues.first.advisoryRuleId, 'rule-1');
      expect(l.issues.last.advisoryRuleId, isNull);
      expect(l.photos.single.contentType, PhotoContentType.jpeg);
      expect(l.nextVisit?.plannedSlot, VisitSlot.any);
      expect(l.createdIds, {visit, nextVisit});
      // Not the visit: a refused PlanVisit must not drop the visit log.
      expect(l.dependsOnIds, {farmer, plot, season});
    });

    test('LogVisit without optional parts sends empty lists', () {
      final l = LogVisitPayload(
        visitId: visit,
        farmerId: farmer,
        plotId: plot,
        seasonId: season,
        visitedAt: DateTime.utc(2026, 11, 2, 5, 30),
        farmerPresent: false,
      );
      expect(l.toJson(), {
        'visit_id': visit,
        'farmer_id': farmer,
        'plot_id': plot,
        'season_id': season,
        'visited_at': '2026-11-02T05:30:00.000Z',
        'farmer_present': false,
        'issues': <Object?>[],
        'photos': <Object?>[],
      });
      expect(l.createdIds, {visit});
    });

    test('a local time is sent as UTC', () {
      final local = DateTime(2026, 11, 2, 11);
      final l = LogVisitPayload(
        visitId: visit,
        farmerId: farmer,
        plotId: plot,
        seasonId: season,
        visitedAt: local,
        farmerPresent: true,
      );
      final sent = DateTime.parse(l.toJson()['visited_at']! as String);
      expect(sent.isUtc, isTrue);
      expect(sent, local.toUtc());
    });

    test('commands without a farmer in the payload', () {
      const cancel = CancelVisitPayload(visitId: visit);
      expect(cancel.farmerId, isNull);
      expect(cancel.entityId, visit);
      expect(cancel.dependsOnIds, {visit});
      expect(cancel.createdIds, isEmpty);

      const close = CloseCallbackPayload(callbackId: 'cb-1');
      expect(close.entityType, EntityType.callback);
      expect(close.farmerId, isNull);
      expect(close.toJson(), {'callback_id': 'cb-1'});

      const ack = AckAlertPayload(alertId: 'alert-1');
      expect(ack.entityType, EntityType.alert);
      expect(ack.entityId, 'alert-1');
      expect(ack.farmerId, isNull);
    });
  });

  group('validation', () {
    test('missing required fields throw FormatException', () {
      for (final type in CommandType.values) {
        expect(
          () => CommandPayload.decode(type, const {}),
          throwsFormatException,
          reason: type.wire,
        );
      }
    });

    test('unknown enum values throw instead of becoming unknown', () {
      Map<String, Object?> logWith(Map<String, Object?> issue) => {
        ...literal[CommandType.logVisit]!,
        'issues': [issue],
      };
      expect(
        () => LogVisitPayload.fromJson(
          logWith({'issue_visit_id': 'a', 'issue_id': 'b', 'severity': 'x'}),
        ),
        throwsFormatException,
      );
      expect(
        () => PlanVisitPayload.fromJson({
          ...literal[CommandType.planVisit]!,
          'planned_slot': 'evening',
        }),
        throwsFormatException,
      );
      expect(
        () => EnrolFarmerPayload.fromJson({
          ...literal[CommandType.enrolFarmer]!,
          'language': 'hi',
        }),
        throwsFormatException,
      );
      expect(
        () => RecordConsentPayload.fromJson({
          ...literal[CommandType.recordConsent]!,
          'purposes': ['marketing'],
        }),
        throwsFormatException,
      );
      expect(
        () => SavePlotPayload.fromJson({
          ...literal[CommandType.savePlot]!,
          'area_source': 'satellite',
        }),
        throwsFormatException,
      );
    });

    test('a bad date throws FormatException', () {
      expect(
        () => PlanVisitPayload.fromJson({
          ...literal[CommandType.planVisit]!,
          'planned_for': '03/11/2026',
        }),
        throwsFormatException,
      );
    });
  });

  group('outbox helpers', () {
    test('replaceId rewrites a merged farmer ID everywhere', () {
      const merged = 'existing-farmer';
      final log = CommandPayload.decode(
        CommandType.logVisit,
        literal[CommandType.logVisit]!,
      );
      final rewritten = log.replaceId(farmer, merged) as LogVisitPayload;
      expect(rewritten.farmerId, merged);
      expect(rewritten.visitId, visit);
      expect(rewritten.issues, (log as LogVisitPayload).issues);

      final update = CommandPayload.decode(
        CommandType.updateFarmer,
        literal[CommandType.updateFarmer]!,
      ).replaceId(farmer, merged) as UpdateFarmerPayload;
      expect(update.farmerId, merged);
      // The photo key is a different string, so it is left alone.
      expect(update.fields.photoKey, 'farmers/$farmer/photo-2.jpg');
    });

    test('the enrolment chain links through createdIds / dependsOnIds', () {
      final chain = [
        for (final t in [
          CommandType.enrolFarmer,
          CommandType.savePlot,
          CommandType.startSeason,
          CommandType.planVisit,
          CommandType.logVisit,
        ])
          CommandPayload.decode(t, literal[t]!),
      ];
      // A new plot (no expected_version) so SavePlot creates the plot.
      chain[1] = SavePlotPayload.fromJson(
        {...literal[CommandType.savePlot]!}..remove('expected_version'),
      );

      CommandPayload? parentOf(int i) {
        for (var j = i - 1; j >= 0; j--) {
          if (chain[j].createdIds
              .intersection(chain[i].dependsOnIds)
              .isNotEmpty) {
            return chain[j];
          }
        }
        return null;
      }

      expect(parentOf(0), isNull);
      expect(parentOf(1)?.type, CommandType.enrolFarmer);
      expect(parentOf(2)?.type, CommandType.savePlot);
      expect(parentOf(3)?.type, CommandType.startSeason);
      expect(
        parentOf(4)?.type,
        CommandType.startSeason,
        reason: 'a LogVisit stands without its PlanVisit',
      );
    });

    test('toCommandIn', () {
      const ack = AckAlertPayload(alertId: 'alert-1');
      final cmd = ack.toCommandIn(
        id: 'cmd-1',
        clientCreatedAt: DateTime.utc(2026, 11, 2),
      );
      expect(cmd.type, 'AckAlert');
      expect(cmd.payload, {'alert_id': 'alert-1'});
      expect(cmd.toJson()['client_created_at'], '2026-11-02T00:00:00.000Z');
    });
  });
}
