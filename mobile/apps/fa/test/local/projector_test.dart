import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/outbox.dart';
import 'package:fa/src/local/projector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixture.dart';

const _projector = Projector();

OutboxEntry _entry(CommandPayload c, {String id = 'cmd', OutboxState? state}) =>
    OutboxEntry.create(
      id: id,
      command: c,
      now: fixtureNow,
    ).copyWith(state: state);

Snapshot _apply(Snapshot base, List<CommandPayload> commands) =>
    _projector.replay(base, [
      for (var i = 0; i < commands.length; i++) _entry(commands[i], id: 'c$i'),
    ]);

T _byId<T>(List<T> items, String id, String Function(T) idOf) =>
    items.firstWhere((x) => idOf(x) == id);

void main() {
  final base = fixtureSnapshot();

  const enrol = EnrolFarmerPayload(
    farmerId: 'f-new',
    phone: '98480 12345',
    name: ' Suresh B ',
    language: Language.te,
    villageId: kondapur,
    consent: EnrolConsent(
      purposes: [ConsentPurpose.programme],
      otpProof: null,
      audioPlayed: true,
      noticeVersion: 'v3',
    ),
  );
  const plot = SavePlotPayload(
    plotId: 'p-new',
    farmerId: 'f-new',
    label: 'Plot 1',
    pin: LatLng(17.47, 78.37),
    areaAcres: 1.5,
    areaSource: AreaSource.typed,
  );
  final season = StartSeasonPayload(
    seasonId: 's-new',
    farmerId: 'f-new',
    plotId: 'p-new',
    seasonCode: 'rabi-2026-27',
    cropId: cotton,
    sowingDate: today.addDays(-10),
  );
  final logVisit = LogVisitPayload(
    visitId: raviPlannedVisit,
    farmerId: ravi,
    plotId: raviPlot,
    seasonId: raviSeason,
    visitedAt: fixtureNow,
    farmerPresent: true,
    stageId: stFlowering,
    notes: 'Bolls damaged',
    issues: const [
      LogVisitIssue(
        issueVisitId: 'iv-1',
        issueId: issBollworm,
        severity: Severity.high,
        advisoryRuleId: ruleEmamectin,
      ),
      LogVisitIssue(
        issueVisitId: 'iv-2',
        issueId: issLeafCurl,
        severity: Severity.low,
        // A bollworm rule on a leaf curl issue: stored unresolved.
        advisoryRuleId: ruleEmamectin,
      ),
    ],
    photos: const [
      LogVisitPhoto(photoId: 'ph-1', contentType: PhotoContentType.jpeg),
    ],
    nextVisit: LogVisitNextVisit(
      visitId: 'vis-next',
      plannedFor: today.addDays(7),
      plannedSlot: VisitSlot.afternoon,
    ),
  );

  test('every command type replays twice to the same tables', () {
    final commands = <CommandPayload>[
      enrol,
      const RecordConsentPayload(
        farmerId: 'f-new',
        purposes: [ConsentPurpose.programme],
        otpProof: 'proof',
        audioPlayed: true,
        noticeVersion: 'v3',
      ),
      plot,
      season,
      const UpdateFarmerPayload(
        farmerId: ravi,
        expectedVersion: 2,
        fields: UpdateFarmerFields(name: 'Ravi Kumar'),
      ),
      PlanVisitPayload(
        visitId: 'vis-plan',
        farmerId: 'f-new',
        plotId: 'p-new',
        seasonId: 's-new',
        plannedFor: today.addDays(1),
        plannedSlot: VisitSlot.morning,
      ),
      logVisit,
      const CancelVisitPayload(visitId: 'vis-plan'),
      const CloseCallbackPayload(callbackId: raviCallback),
      const AckAlertPayload(alertId: alertNote),
    ];
    final entries = [
      for (var i = 0; i < commands.length; i++) _entry(commands[i], id: 'c$i'),
    ];
    final once = _projector.replay(base, entries);
    final twice = _projector.replay(once, entries);
    expect(twice, once);
    expect(_projector.replay(base, [...entries, ...entries]), once);
  });

  test('EnrolFarmer without a proof creates a consent-pending farmer', () {
    final t = _apply(base, [enrol]);
    final f = _byId(t.farmers, 'f-new', (f) => f.id);
    expect(f.name, 'Suresh B');
    expect(f.phone, '+919848012345');
    expect(f.status, FarmerStatus.active);
    expect(f.source, FarmerSource.fa);
    expect(f.consentPending, isTrue);
    expect(f.consentsGranted, isEmpty);
    expect(f.version, 1);
    expect(f.createdAt, fixtureNow);
  });

  test(
    'EnrolFarmer onto an existing self sign-up fills only what is missing',
    () {
      final t = _apply(base, [
        const EnrolFarmerPayload(
          farmerId: raju,
          phone: '+919000000150',
          name: 'Raju Pallapu',
          nameTe: 'రాజు',
          language: Language.en,
          villageId: gachibowli,
          consent: EnrolConsent(
            purposes: [ConsentPurpose.programme, ConsentPurpose.loyalty],
            otpProof: 'proof',
            audioPlayed: true,
            noticeVersion: 'v3',
          ),
        ),
      ]);
      final f = _byId(t.farmers, raju, (f) => f.id);
      expect(f.name, 'Raju P', reason: "the farmer's own answer wins");
      expect(f.nameTe, 'రాజు');
      expect(f.villageId, kondapur);
      expect(f.language, Language.en, reason: 'pending profile takes it');
      expect(f.status, FarmerStatus.active);
      expect(f.consentPending, isFalse);
      expect(f.consentsGranted, [
        ConsentPurpose.programme,
        ConsentPurpose.loyalty,
      ]);
      expect(t.farmers.where((x) => x.phone == '+919000000150'), hasLength(1));
      expect(
        _byId(t.alerts, alertNewFarmer, (a) => a.id).status,
        AlertStatus.closed,
        reason: 'the new-farmer alert has done its job, as on the server',
      );
      expect(
        _byId(t.alerts, alertCallback, (a) => a.id).status,
        AlertStatus.open,
        reason: "other farmers' and other kinds' alerts stay",
      );
    },
  );

  test('EnrolFarmer of another farmer leaves the new-farmer alert open', () {
    final t = _apply(base, [enrol]);
    expect(
      _byId(t.alerts, alertNewFarmer, (a) => a.id).status,
      AlertStatus.open,
    );
  });

  test(
    'SavePlot: new at version 1, an edit at expected + 1, pin from boundary',
    () {
      var t = _apply(base, [enrol, plot]);
      expect(_byId(t.plots, 'p-new', (p) => p.id).version, 1);
      expect(_byId(t.plots, 'p-new', (p) => p.id).villageId, kondapur);

      t = _apply(base, [
        SavePlotPayload(
          plotId: padmaPlot2,
          farmerId: padma,
          label: 'Plot 2',
          boundaryGeoJson: lakshmiBoundary,
          areaAcres: 1.75,
          areaSource: AreaSource.boundary,
          expectedVersion: 3,
        ),
      ]);
      final p = _byId(t.plots, padmaPlot2, (p) => p.id);
      expect(p.version, 4);
      expect(p.areaAcres, 1.75);
      expect(p.pin!.lat, closeTo(17.4305, 1e-9));
      expect(p.pin!.lng, closeTo(78.3405, 1e-9));
    },
  );

  test('LogVisit: planned visit done, advice from masters, next visit, '
      'call-back and its alert closed', () {
    final t = _apply(base, [logVisit]);
    final v = _byId(t.visits, raviPlannedVisit, (v) => v.id);
    expect(v.status, VisitStatus.done);
    expect(v.plannedFor, today.addDays(3), reason: 'plan kept');
    expect(v.stageName, 'Flowering');
    expect(v.stageNameTe, 'పూత');
    expect(v.photoCount, 1);
    final given = v.issues[0];
    expect(given.adviceStatus, AdviceStatus.given);
    expect(given.issueName, 'Pink bollworm');
    expect(given.saltName, 'Emamectin benzoate 5% SG');
    expect(given.productName, 'Sample 5 SG');
    expect(given.dose, '80 g per acre');
    expect(given.doseTe, 'ఎకరాకు 80 గ్రా');
    final unresolved = v.issues[1];
    expect(unresolved.adviceStatus, AdviceStatus.unresolved);
    expect(unresolved.ruleId, isNull);
    expect(unresolved.saltName, isNull);

    final next = _byId(t.visits, 'vis-next', (v) => v.id);
    expect(next.status, VisitStatus.planned);
    expect(next.plannedSlot, VisitSlot.afternoon);
    expect(next.faId, faId);

    expect(t.callbacks, isEmpty);
    expect(
      _byId(t.alerts, alertCallback, (a) => a.id).status,
      AlertStatus.closed,
    );
  });

  test('a LogVisit without a planned visit adds a done one', () {
    final t = _apply(base, [
      LogVisitPayload(
        visitId: 'vis-unplanned',
        farmerId: padma,
        plotId: padmaPlot2,
        seasonId: padmaSeason,
        visitedAt: fixtureNow,
        farmerPresent: false,
      ),
    ]);
    final v = _byId(t.visits, 'vis-unplanned', (v) => v.id);
    expect(v.status, VisitStatus.done);
    expect(v.plannedFor, isNull);
    expect(v.farmerPresent, isFalse);
  });

  test('CancelVisit, CloseCallback and AckAlert', () {
    final t = _apply(base, [
      const CancelVisitPayload(visitId: raviPlannedVisit),
      const CancelVisitPayload(visitId: raviDoneVisit),
      const CloseCallbackPayload(callbackId: raviCallback),
      const AckAlertPayload(alertId: alertNote),
    ]);
    expect(
      _byId(t.visits, raviPlannedVisit, (v) => v.id).status,
      VisitStatus.cancelled,
    );
    expect(
      _byId(t.visits, raviDoneVisit, (v) => v.id).status,
      VisitStatus.done,
      reason: 'only a planned visit can be cancelled',
    );
    expect(t.callbacks, isEmpty);
    expect(
      _byId(t.alerts, alertCallback, (a) => a.id).status,
      AlertStatus.closed,
    );
    final note = _byId(t.alerts, alertNote, (a) => a.id);
    expect(note.status, AlertStatus.acknowledged);
    expect(note.acknowledgedAt, fixtureNow);
  });

  test('UpdateFarmer and RecordConsent', () {
    final t = _apply(base, [
      const UpdateFarmerPayload(
        farmerId: padma,
        expectedVersion: 5,
        fields: UpdateFarmerFields(nameTe: 'పద్మ', villageId: kondapur),
      ),
      const RecordConsentPayload(
        farmerId: raju,
        purposes: [ConsentPurpose.programme],
        otpProof: 'proof',
        audioPlayed: true,
        noticeVersion: 'v3',
      ),
    ]);
    final p = _byId(t.farmers, padma, (f) => f.id);
    expect(p.nameTe, 'పద్మ');
    expect(p.name, 'Padma S');
    expect(p.villageId, kondapur);
    expect(p.version, 6);
    final r = _byId(t.farmers, raju, (f) => f.id);
    expect(r.consentPending, isFalse);
    expect(r.consentsGranted, [ConsentPurpose.programme]);
  });

  group('replays()', () {
    OutboxEntry e(OutboxState state, [int? v]) =>
        _entry(const AckAlertPayload(alertId: 'a'))
            .copyWith(state: state, batchTerritoryVersion: v);

    test('queued and sending always', () {
      expect(Projector.replays(e(OutboxState.queued), 10), isTrue);
      expect(Projector.replays(e(OutboxState.sending), 10), isTrue);
    });

    test('applied / merged only while newer than the snapshot', () {
      expect(Projector.replays(e(OutboxState.applied, 11), 10), isTrue);
      expect(Projector.replays(e(OutboxState.applied, 10), 10), isFalse);
      expect(Projector.replays(e(OutboxState.merged, 12), 11), isTrue);
    });

    test('never conflict, rejected, dropped, resolved', () {
      for (final s in [
        OutboxState.conflict,
        OutboxState.rejected,
        OutboxState.dropped,
        OutboxState.resolved,
      ]) {
        expect(Projector.replays(e(s), 10), isFalse, reason: s.wire);
      }
    });
  });
}
