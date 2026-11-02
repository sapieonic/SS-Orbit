import 'dart:convert';

import 'package:fa/src/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

/// Checks that [values] spell exactly [wires] (spec order, `unknown` last
/// with an empty wire when [fallback] is given) and that `fromWire` maps
/// every wire back, and unknown or null text to [fallback].
void expectWire<T extends WireEnum>(
  List<T> values,
  T Function(String?) fromWire,
  List<String> wires, {
  required T fallback,
}) {
  final known = values.where((v) => v != fallback).toList();
  expect(known.map((v) => v.wire).toList(), wires);
  for (final v in known) {
    expect(fromWire(v.wire), v, reason: v.wire);
  }
  expect(fromWire('something_new'), fallback);
  expect(fromWire(null), fallback);
  expect(fromWire(''), fallback);
}

const _farmerId = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a01';
const _plotId = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a02';
const _seasonId = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a03';
const _visitId = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a04';
const _faId = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a05';
const _villageId = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a06';
const _cropId = '0190a5b2-7c1e-7d4a-9b3f-2f1e4c5d6a07';

/// A snapshot as the server writes it (keys from the Go snapshot providers
/// and the Snap* schemas in sync.yaml).
final Map<String, Object?> snapshotJson = {
  'territory_version': 12,
  'masters_version': 3,
  'generated_at': '2026-11-02T04:30:00Z',
  'sections': {
    'farmers': [
      {
        'id': _farmerId,
        'phone': '+919000000101',
        'name': 'Ravi K',
        'name_te': 'రవి కె',
        'language': 'te',
        'village_id': _villageId,
        'source': 'fa',
        'photo_key': null,
        'plan': 'free',
        'status': 'active',
        'consents_granted': ['programme', 'soil_partner'],
        'consent_pending': false,
        'profile_completed_at': '2026-06-01T05:00:00Z',
        'version': 4,
        'created_at': '2026-06-01T05:00:00Z',
        'updated_at': '2026-10-12T06:00:00Z',
      },
    ],
    'plots': [
      {
        'id': _plotId,
        'farmer_id': _farmerId,
        'label': 'Plot 1',
        'village_id': _villageId,
        'boundary': {
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
        'status': 'active',
        'version': 2,
        'updated_at': '2026-06-01T05:10:00Z',
      },
    ],
    'seasons': [
      {
        'id': _seasonId,
        'farmer_id': _farmerId,
        'plot_id': _plotId,
        'season_code': 'kharif-2026',
        'crop_id': _cropId,
        'sowing_date': '2026-07-01',
        'previous_crop_id': null,
        'status': 'active',
        'version': 1,
        'updated_at': '2026-07-01T05:00:00Z',
      },
    ],
    'visits': [
      {
        'id': _visitId,
        'farmer_id': _farmerId,
        'plot_id': _plotId,
        'season_id': _seasonId,
        'fa_id': _faId,
        'status': 'done',
        'planned_for': null,
        'planned_slot': null,
        'purpose': null,
        'visited_at': '2026-10-12T05:30:00Z',
        'farmer_present': true,
        'stage_id': null,
        'stage_name': 'Flowering',
        'stage_name_te': 'పూత దశ',
        'notes': 'Pink bollworm on lower bolls',
        'photo_count': 2,
        'issues': [
          {
            'id': 'iv-1',
            'issue_id': 'issue-pbw',
            'issue_name': 'Pink bollworm',
            'issue_name_te': 'గులాబీ రంగు పురుగు',
            'severity': 'moderate',
            'advice_status': 'given',
            'rule_id': 'rule-1',
            'salt_id': 'salt-1',
            'salt_name': 'Emamectin benzoate',
            'salt_name_te': null,
            'sku_id': null,
            'product_name': null,
            'product_name_te': null,
            'dose': '80 g per acre',
            'dose_te': 'ఎకరాకు 80 గ్రా',
          },
          {
            'id': 'iv-2',
            'issue_id': 'issue-x',
            'issue_name': null,
            'issue_name_te': null,
            'severity': 'low',
            'advice_status': 'unresolved',
            'rule_id': null,
            'salt_id': null,
            'salt_name': null,
            'salt_name_te': null,
            'sku_id': null,
            'product_name': null,
            'product_name_te': null,
            'dose': null,
            'dose_te': null,
          },
        ],
      },
      {
        'id': 'visit-planned',
        'farmer_id': _farmerId,
        'plot_id': _plotId,
        'season_id': _seasonId,
        'fa_id': _faId,
        'status': 'planned',
        'planned_for': '2026-11-03',
        'planned_slot': 'morning',
        'purpose': 'Follow-up',
        'visited_at': null,
        'farmer_present': null,
        'stage_id': null,
        'stage_name': null,
        'stage_name_te': null,
        'notes': null,
        'photo_count': 0,
        'issues': <Object?>[],
      },
    ],
    'callbacks': [
      {
        'id': 'cb-1',
        'farmer_id': _farmerId,
        'requested_at': '2026-11-01T10:00:00Z',
      },
    ],
    'alerts': [
      {
        'id': 'alert-1',
        'fa_id': _faId,
        'kind': 'callback',
        'farmer_id': _farmerId,
        'ref_id': 'cb-1',
        'title': 'Ravi K asked for a call',
        'body': null,
        'title_te': null,
        'body_te': null,
        'status': 'open',
        'created_at': '2026-11-01T10:00:00Z',
        'acknowledged_at': null,
      },
    ],
    'masters': {
      'version': 3,
      'season_codes': {
        'current': 'rabi-2026',
        'next': 'kharif-2027',
        'all_open': ['kharif-2026', 'rabi-2026', 'kharif-2027'],
        'valid_until': '2027-03-31',
      },
      'crops': [
        {
          'id': _cropId,
          'code': 'cotton',
          'name': 'Cotton',
          'name_te': 'పత్తి',
          'duration_days': 160,
          'stages': [
            {
              'id': 'st-1',
              'code': 'vegetative',
              'name': 'Vegetative',
              'name_te': 'ఎదుగుదల',
              'seq': 1,
              'start_day': 0,
              'end_day': 59,
            },
            {
              'id': 'st-2',
              'code': 'flowering',
              'name': 'Flowering',
              'name_te': 'పూత దశ',
              'seq': 2,
              'start_day': 60,
              'end_day': 109,
            },
          ],
        },
      ],
      'issues': [
        {
          'id': 'issue-pbw',
          'crop_id': _cropId,
          'type': 'pest',
          'name': 'Pink bollworm',
          'name_te': 'గులాబీ రంగు పురుగు',
        },
      ],
      'salts': [
        {'id': 'salt-1', 'name': 'Emamectin benzoate', 'name_te': null},
      ],
      'skus': [
        {
          'id': 'sku-1',
          'code': 'EMB-100',
          'product_name': 'Proclaim',
          'product_name_te': null,
          'salt_id': 'salt-1',
          'pack_size': '100 g',
          'mrp_paise': 45000,
          'cashback_eligible': true,
        },
      ],
      'rules': [
        {
          'id': 'rule-1',
          'rule_key': 'rk-1',
          'version': 2,
          'issue_id': 'issue-pbw',
          'salt_id': 'salt-1',
          'sku_id': 'sku-1',
          'dose_per_acre': '80 g per acre',
          'dose_per_acre_te': 'ఎకరాకు 80 గ్రా',
        },
      ],
    },
    'villages': [
      {
        'id': _villageId,
        'name': 'Kondapur',
        'name_te': 'కొండాపూర్',
        'lgd_code': '574123',
        'lat': 17.4613,
        'lng': 78.3637,
        'mandal_id': 'mandal-1',
        'mandal_name': 'Serilingampally',
        'mandal_name_te': 'శేరిలింగంపల్లి',
        'district_id': 'district-1',
        'district_name': 'Rangareddy',
        'district_name_te': null,
        'created_at': '2026-01-01T00:00:00Z',
      },
    ],
    'some_future_section': {'ignored': true},
  },
};

void main() {
  group('enum wire values', () {
    test('Language falls back to Telugu', () {
      expect(Language.values.map((v) => v.wire), ['te', 'en']);
      expect(Language.fromWire('en'), Language.en);
      expect(Language.fromWire('hi'), Language.te);
      expect(Language.fromWire(null), Language.te);
    });

    test('farmer, plot and season enums', () {
      expectWire(AreaLevel.values, AreaLevel.fromWire, [
        'village',
        'mandal',
        'district',
      ], fallback: AreaLevel.unknown);
      expectWire(FarmerSource.values, FarmerSource.fromWire, [
        'self',
        'fa',
        'ho',
      ], fallback: FarmerSource.unknown);
      expectWire(Plan.values, Plan.fromWire, [
        'free',
        'premium',
      ], fallback: Plan.unknown);
      expectWire(FarmerStatus.values, FarmerStatus.fromWire, [
        'pending_profile',
        'active',
        'inactive',
      ], fallback: FarmerStatus.unknown);
      expectWire(ConsentPurpose.values, ConsentPurpose.fromWire, [
        'programme',
        'soil_partner',
        'schemes_finance',
        'loyalty',
      ], fallback: ConsentPurpose.unknown);
      expectWire(AreaSource.values, AreaSource.fromWire, [
        'boundary',
        'typed',
      ], fallback: AreaSource.unknown);
      expectWire(PlotStatus.values, PlotStatus.fromWire, [
        'active',
        'archived',
      ], fallback: PlotStatus.unknown);
      expectWire(SeasonStatus.values, SeasonStatus.fromWire, [
        'active',
        'harvested',
        'abandoned',
      ], fallback: SeasonStatus.unknown);
    });

    test('visit, issue and alert enums', () {
      expectWire(VisitStatus.values, VisitStatus.fromWire, [
        'planned',
        'done',
        'cancelled',
        'missed',
      ], fallback: VisitStatus.unknown);
      expectWire(VisitSlot.values, VisitSlot.fromWire, [
        'morning',
        'afternoon',
        'any',
      ], fallback: VisitSlot.unknown);
      expectWire(Severity.values, Severity.fromWire, [
        'low',
        'moderate',
        'high',
      ], fallback: Severity.unknown);
      expectWire(AdviceStatus.values, AdviceStatus.fromWire, [
        'given',
        'unresolved',
      ], fallback: AdviceStatus.unknown);
      // CONVENTIONS section 6 spells it "resolved"; the server sends "given".
      expect(AdviceStatus.fromWire('resolved'), AdviceStatus.given);
      expectWire(IssueType.values, IssueType.fromWire, [
        'pest',
        'disease',
        'deficiency',
      ], fallback: IssueType.unknown);
      expectWire(AlertKind.values, AlertKind.fromWire, [
        'new_farmer',
        'callback',
        'invoice_check',
        'ho_note',
      ], fallback: AlertKind.unknown);
      expectWire(AlertStatus.values, AlertStatus.fromWire, [
        'open',
        'acknowledged',
        'closed',
      ], fallback: AlertStatus.unknown);
      expectWire(PhotoContentType.values, PhotoContentType.fromWire, [
        'image/jpeg',
        'image/png',
        'image/webp',
      ], fallback: PhotoContentType.unknown);
    });

    test('auth, enrolment and sync enums', () {
      expectWire(FaStatus.values, FaStatus.fromWire, [
        'active',
        'leaving',
        'inactive',
      ], fallback: FaStatus.unknown);
      expectWire(PhoneLookupStatus.values, PhoneLookupStatus.fromWire, [
        'new',
        'mine',
        'unassigned_in_my_area',
        'outside_my_area',
        'other_fa',
        'deactivated',
      ], fallback: PhoneLookupStatus.unknown);
      expectWire(CommandStatus.values, CommandStatus.fromWire, [
        'applied',
        'merged',
        'conflict',
        'rejected',
      ], fallback: CommandStatus.unknown);
    });
  });

  group('Snapshot.fromJson', () {
    late Snapshot snap;
    setUp(() => snap = Snapshot.fromJson(snapshotJson));

    test('versions, ETag and every section', () {
      expect(snap.territoryVersion, 12);
      expect(snap.mastersVersion, 3);
      expect(snap.etag, '"t12-m3"');
      expect(snap.generatedAt, DateTime.utc(2026, 11, 2, 4, 30));
      expect(snap.generatedAt.isUtc, isTrue);
      expect(snap.farmers, hasLength(1));
      expect(snap.plots, hasLength(1));
      expect(snap.seasons, hasLength(1));
      expect(snap.visits, hasLength(2));
      expect(snap.callbacks, hasLength(1));
      expect(snap.alerts, hasLength(1));
      expect(snap.villages, hasLength(1));
    });

    test('farmer', () {
      final f = snap.farmers.single;
      expect(f.displayName(Language.te), 'రవి కె');
      expect(f.displayName(Language.en), 'Ravi K');
      expect(f.source, FarmerSource.fa);
      expect(f.plan, Plan.free);
      expect(f.status, FarmerStatus.active);
      expect(f.consentsGranted, [
        ConsentPurpose.programme,
        ConsentPurpose.soilPartner,
      ]);
      expect(f.consentPending, isFalse);
      expect(f.version, 4);
      expect(f.photoKey, isNull);
    });

    test('plot keeps the boundary as GeoJSON text', () {
      final p = snap.plots.single;
      expect(p.pin, const LatLng(17.465, 78.365));
      expect(p.areaAcres, 2.1);
      expect(p.areaSource, AreaSource.boundary);
      expect(p.status, PlotStatus.active);
      expect(jsonDecode(p.boundaryGeoJson!), {
        'type': 'Polygon',
        'coordinates': [
          [
            [78.36, 17.46],
            [78.37, 17.46],
            [78.37, 17.47],
            [78.36, 17.46],
          ],
        ],
      });
      expect(p.boundaryRings.single.first, const LatLng(17.46, 78.36));
      expect(p.boundaryRings.single, hasLength(4));
    });

    test('season, visits and issues', () {
      final s = snap.seasons.single;
      expect(s.sowingDate, LocalDate(2026, 7, 1));
      expect(s.daysAfterSowing(LocalDate(2026, 10, 12)), 103);
      expect(s.status, SeasonStatus.active);

      final done = snap.visits.first;
      expect(done.status, VisitStatus.done);
      expect(done.plannedFor, isNull);
      expect(done.plannedSlot, isNull);
      expect(done.visitedAt, DateTime.utc(2026, 10, 12, 5, 30));
      expect(done.farmerPresent, isTrue);
      expect(done.photoCount, 2);
      expect(done.issues.first.severity, Severity.moderate);
      expect(done.issues.first.adviceStatus, AdviceStatus.given);
      expect(done.issues.last.adviceStatus, AdviceStatus.unresolved);
      expect(done.issues.last.saltId, isNull);

      final planned = snap.visits.last;
      expect(planned.status, VisitStatus.planned);
      expect(planned.plannedFor, LocalDate(2026, 11, 3));
      expect(planned.plannedSlot, VisitSlot.morning);
      expect(planned.issues, isEmpty);
    });

    test('call-back, alert and village', () {
      expect(snap.callbacks.single.requestedAt, DateTime.utc(2026, 11, 1, 10));
      final a = snap.alerts.single;
      expect(a.kind, AlertKind.callback);
      expect(a.status, AlertStatus.open);
      expect(a.refId, 'cb-1');
      // No Telugu text: falls back to English.
      expect(a.displayTitle(Language.te), 'Ravi K asked for a call');
      expect(a.displayBody(Language.te), isNull);

      final v = snap.villages.single;
      expect(v.location, const LatLng(17.4613, 78.3637));
      expect(v.displayName(Language.te), 'కొండాపూర్');
      expect(v.displayMandal(Language.te), 'శేరిలింగంపల్లి');
      expect(v.displayDistrict(Language.te), 'Rangareddy');
    });

    test('masters and lookups', () {
      final m = snap.masters;
      expect(m.version, 3);
      expect(m.seasonCodes.current, 'rabi-2026');
      expect(m.seasonCodes.validUntil, LocalDate(2027, 3, 31));
      final cotton = m.cropById(_cropId)!;
      expect(cotton.durationDays, 160);
      expect(cotton.stageAt(70)?.code, 'flowering');
      expect(cotton.stageAt(200), isNull);
      expect(m.issuesForCrop(_cropId).single.type, IssueType.pest);
      final rule = m.rulesForIssue('issue-pbw').single;
      expect(rule.displayDose(Language.te), 'ఎకరాకు 80 గ్రా');
      expect(m.skuById(rule.skuId!)?.mrpPaise, 45000);
      expect(
        m.saltById('salt-1')?.displayName(Language.te),
        'Emamectin '
        'benzoate',
      );
      expect(m.ruleById('nope'), isNull);
    });

    test('value equality: parsing twice gives equal snapshots', () {
      final again = Snapshot.fromJson(snapshotJson);
      expect(again, snap);
      expect(again.hashCode, snap.hashCode);
    });

    test('missing list sections read as empty; masters is required', () {
      final minimal = Snapshot.fromJson({
        'territory_version': 1,
        'masters_version': 1,
        'generated_at': '2026-11-02T00:00:00Z',
        'sections': {'masters': (snapshotJson['sections']! as Map)['masters']},
      });
      expect(minimal.farmers, isEmpty);
      expect(minimal.villages, isEmpty);
      expect(
        () => Snapshot.fromJson({
          'territory_version': 1,
          'masters_version': 1,
          'generated_at': '2026-11-02T00:00:00Z',
          'sections': <String, Object?>{},
        }),
        throwsFormatException,
      );
    });

    test('wrong types throw FormatException', () {
      expect(
        () => SnapCallback.fromJson({
          'id': 1,
          'farmer_id': _farmerId,
          'requested_at': '2026-11-01T10:00:00Z',
        }),
        throwsFormatException,
      );
      expect(
        () => SnapSeason.fromJson({
          ...((snapshotJson['sections']! as Map)['seasons'] as List).first
              as Map<String, Object?>,
          'sowing_date': '1 July',
        }),
        throwsFormatException,
      );
    });

    test('a boundary sent as a string is kept as is', () {
      final plot =
          ((snapshotJson['sections']! as Map)['plots'] as List).first
              as Map<String, Object?>;
      const text = '{"type":"Polygon","coordinates":[]}';
      expect(
        SnapPlot.fromJson({...plot, 'boundary': text}).boundaryGeoJson,
        text,
      );
      expect(
        SnapPlot.fromJson({...plot, 'boundary': null}).boundaryGeoJson,
        isNull,
      );
    });
  });

  group('FaAlert.fromJson', () {
    test('wraps the snapshot fields and adds the farmer', () {
      final json = {
        ...((snapshotJson['sections']! as Map)['alerts'] as List).first
            as Map<String, Object?>,
        'title_te': 'రవి కె కాల్ చేయమన్నారు',
        'farmer_name': 'Ravi K',
        'farmer_phone': '+919000000101',
      };
      final a = FaAlert.fromJson(json);
      expect(a.id, 'alert-1');
      expect(a.farmerName, 'Ravi K');
      expect(a.farmerPhone, '+919000000101');
      expect(a.alert.displayTitle(Language.te), 'రవి కె కాల్ చేయమన్నారు');
      expect(FaAlert.fromJson(json), a);
    });
  });

  group('sync results', () {
    test('CommandBatchResult.fromJson / toJson round trip', () {
      final json = <String, Object?>{
        'results': [
          {
            'id': 'c1',
            'status': 'applied',
            'entity_id': _farmerId,
            'merged_into': null,
            'conflict': null,
            'error': null,
          },
          {
            'id': 'c2',
            'status': 'merged',
            'entity_id': _farmerId,
            'merged_into': 'existing-farmer',
            'conflict': null,
            'error': null,
          },
          {
            'id': 'c3',
            'status': 'conflict',
            'entity_id': _plotId,
            'merged_into': null,
            'conflict': {'field': 'area_acres', 'yours': 1.75, 'theirs': 2.0},
            'error': null,
          },
          {
            'id': 'c4',
            'status': 'rejected',
            'entity_id': null,
            'merged_into': null,
            'conflict': null,
            'error': 'registered_with_another_fa',
          },
        ],
        'retry_from': 4,
        'territory_version': 13,
        'masters_version': 3,
      };
      final r = CommandBatchResult.fromJson(json);
      expect(r.complete, isFalse);
      expect(r.retryFrom, 4);
      expect(r.results.map((c) => c.status), [
        CommandStatus.applied,
        CommandStatus.merged,
        CommandStatus.conflict,
        CommandStatus.rejected,
      ]);
      expect(r.results[1].mergedInto, 'existing-farmer');
      expect(
        r.results[2].conflict,
        const Conflict(field: 'area_acres', yours: 1.75, theirs: 2.0),
      );
      expect(r.results[3].entityId, isNull);
      expect(r.results[3].error, ApiErrorCode.registeredWithAnotherFa);
      expect(r.toJson(), json);
      expect(CommandBatchResult.fromJson(r.toJson()), r);
    });

    test('Conflict compares JSON values deeply', () {
      const a = Conflict(
        field: 'boundary',
        yours: {
          'a': [1, 2],
        },
        theirs: null,
      );
      const b = Conflict(
        field: 'boundary',
        yours: {
          'a': [1, 2],
        },
        theirs: null,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('CommandIn and SyncStatus', () {
      final cmd = CommandIn(
        id: 'cmd-1',
        type: 'AckAlert',
        payload: const {'alert_id': 'alert-1'},
        clientCreatedAt: DateTime.utc(2026, 11, 2, 4, 30),
      );
      final json = cmd.toJson();
      expect(json, {
        'id': 'cmd-1',
        'type': 'AckAlert',
        'payload': {'alert_id': 'alert-1'},
        'client_created_at': '2026-11-02T04:30:00.000Z',
      });
      expect(CommandIn.fromJson(json), cmd);
      expect(
        SyncStatus.fromJson({
          'territory_version': 12,
          'masters_version': 3,
          'etag': '"t12-m3"',
        }).etag,
        Snapshot.snapshotEtag(12, 3),
      );
    });
  });

  group('GeoJSON helpers', () {
    test('polygonGeoJson closes the ring and round-trips', () {
      const ring = [
        LatLng(17.46, 78.36),
        LatLng(17.46, 78.37),
        LatLng(17.47, 78.37),
      ];
      final text = polygonGeoJson(ring);
      expect(jsonDecode(text), {
        'type': 'Polygon',
        'coordinates': [
          [
            [78.36, 17.46],
            [78.37, 17.46],
            [78.37, 17.47],
            [78.36, 17.46],
          ],
        ],
      });
      expect(geoJsonOuterRings(text).single, [...ring, ring.first]);
    });

    test('MultiPolygon gives one ring per polygon; junk gives none', () {
      final multi = jsonEncode({
        'type': 'MultiPolygon',
        'coordinates': [
          [
            [
              [1, 2],
              [3, 4],
            ],
          ],
          [
            [
              [5, 6],
              [7, 8],
            ],
          ],
        ],
      });
      expect(geoJsonOuterRings(multi), [
        [const LatLng(2, 1), const LatLng(4, 3)],
        [const LatLng(6, 5), const LatLng(8, 7)],
      ]);
      expect(geoJsonOuterRings(null), isEmpty);
      expect(geoJsonOuterRings('not json'), isEmpty);
      expect(
        geoJsonOuterRings('{"type":"Point","coordinates":[1,2]}'),
        isEmpty,
      );
    });
  });

  group('auth and enrolment models', () {
    test('OfflinePolicy and ConsentProof helpers', () {
      expect(OfflinePolicy.standard.offlineGrace, const Duration(days: 7));
      final proof = ConsentProof(
        phone: '+919848012345',
        otpProof: 'proof',
        verifiedAt: DateTime.utc(2026, 11, 2),
        expiresAt: DateTime.utc(2026, 11, 9),
      );
      expect(proof.isValidAt(DateTime.utc(2026, 11, 8)), isTrue);
      expect(proof.isValidAt(DateTime.utc(2026, 11, 9)), isFalse);
    });

    test('FieldAssistant display name and equality', () {
      FieldAssistant suresh() => FieldAssistant(
        id: _faId,
        code: 'FA-KDP-014',
        name: 'Suresh Kumar',
        nameTe: 'సురేష్ కుమార్',
        phone: '+919848012345',
        level: AreaLevel.village,
        languages: const ['te', 'en'],
        workingHours: null,
        photoKey: null,
        status: FaStatus.active,
        mustChangePassword: false,
        lastLoginAt: null,
        lastSyncAt: null,
        appVersion: null,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(suresh().displayName(Language.te), 'సురేష్ కుమార్');
      expect(suresh().displayName(Language.en), 'Suresh Kumar');
      expect(suresh(), suresh());
      expect(suresh().hashCode, suresh().hashCode);
    });

    test('presigned uploads compare headers by value', () {
      VisitPhotoUpload upload() => VisitPhotoUpload(
        photoId: 'p1',
        storageKey: 'visits/v1/p1.jpg',
        url: 'https://storage.example/p1',
        method: 'PUT',
        headers: {'Content-Type': 'image/jpeg'},
        expiresAt: DateTime.utc(2026, 11, 2, 5),
      );
      expect(upload(), upload());
      final PresignedUpload target = upload();
      expect(target.method, 'PUT');
    });
  });
}
