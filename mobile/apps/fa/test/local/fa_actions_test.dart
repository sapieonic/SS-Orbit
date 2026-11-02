import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/local/commands.dart';
import 'package:fa/src/local/fa_actions.dart';
import 'package:fa/src/local/outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import 'support/fakes.dart';
import 'support/fixture.dart';

Matcher _actionError(String code, {String? field}) => isA<FaActionError>()
    .having((e) => e.code, 'code', code)
    .having((e) => e.field, 'field', field ?? anything);

ConsentProof _proof(
  String phone, {
  Duration validFor = const Duration(days: 7),
}) => ConsentProof(
  phone: phone,
  otpProof: 'signed-proof',
  verifiedAt: fixtureNow,
  expiresAt: fixtureNow.add(validFor),
);

void main() {
  late Harness h;
  late FaActions a;

  setUp(() async {
    h = Harness();
    a = h.actions;
    await h.seed();
  });

  tearDown(() => h.dispose());

  test('nothing can be written before the first snapshot', () async {
    final fresh = Harness();
    await expectLater(
      fresh.actions.ackAlert(alertNote),
      throwsA(_actionError(FaActionError.noData)),
    );
    await fresh.dispose();
  });

  test('IDs are UUIDv7', () {
    final id = a.newId();
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(id),
      isTrue,
      reason: id,
    );
  });

  group('enrol', () {
    test(
      'a full offline enrolment: chain of dependencies and projection',
      () async {
        final farmerId = await a.enrolFarmer(
          phone: '98480 12345',
          name: 'Suresh B',
          language: Language.te,
          villageId: kondapur,
          audioPlayed: true,
          noticeVersion: 'v3',
        );
        final plotId = await a.savePlot(
          farmerId: farmerId,
          label: 'Plot 1',
          pin: const LatLng(17.47, 78.37),
          areaAcres: 1.5,
          areaSource: AreaSource.typed,
          gpsAccuracyM: 6,
        );
        final seasonId = await a.startSeason(
          farmerId: farmerId,
          plotId: plotId,
          cropId: cotton,
          sowingDate: today.addDays(-3),
        );
        final visitId = await a.planVisit(
          farmerId: farmerId,
          plannedFor: today.addDays(1),
          slot: VisitSlot.morning,
        );
        await a.logVisit(VisitLogInput(farmerId: farmerId, visitId: visitId));

        final rows = await h.outbox();
        expect(
          [for (final r in rows) r.type],
          [
            CommandType.enrolFarmer,
            CommandType.savePlot,
            CommandType.startSeason,
            CommandType.planVisit,
            CommandType.logVisit,
          ],
        );
        expect([for (final r in rows) r.seq], [1, 2, 3, 4, 5]);
        expect(rows[0].dependsOnId, isNull);
        expect(rows[1].dependsOnId, rows[0].id);
        expect(rows[2].dependsOnId, rows[1].id);
        expect(rows[3].dependsOnId, rows[2].id);
        expect(
          rows[4].dependsOnId,
          rows[2].id,
          reason: 'needs the season; a refused plan must not drop the log',
        );
        expect(rows.every((r) => r.state == OutboxState.queued), isTrue);

        final t = await h.territory();
        final f = t.farmer(farmerId)!;
        expect(f.consentPending, isTrue, reason: 'no proof offline');
        expect(f.phone, '+919848012345');
        final plot = t.farmer360(farmerId)!.plots.single;
        expect(plot.season!.id, seasonId);
        expect(plot.season!.seasonCode, 'rabi-2026-27', reason: 'current');
        expect(t.visit(visitId)!.status, VisitStatus.done);
        expect(t.isPending(farmerId), isTrue);
      },
    );

    test('input checks', () async {
      Future<String> enrol({
        String phone = '9848012345',
        String name = 'X',
        String village = kondapur,
      }) => a.enrolFarmer(
        phone: phone,
        name: name,
        language: Language.te,
        villageId: village,
      );
      await expectLater(
        enrol(phone: '12345'),
        throwsA(_actionError(FaActionError.invalidPhone)),
      );
      await expectLater(
        enrol(name: '  '),
        throwsA(_actionError(FaActionError.required, field: 'name')),
      );
      await expectLater(
        enrol(name: 'x' * 101),
        throwsA(_actionError(FaActionError.tooLong, field: 'name')),
      );
      await expectLater(
        enrol(village: 'v-elsewhere'),
        throwsA(_actionError(FaActionError.notFound, field: 'village_id')),
      );
      await expectLater(
        enrol(phone: '90000 00101'),
        throwsA(
          isA<FaActionError>()
              .having((e) => e.code, 'code', FaActionError.alreadyEnrolled)
              .having((e) => e.farmerId, 'farmerId', ravi),
        ),
      );
      expect(await h.outbox(), isEmpty, reason: 'nothing written');
    });

    test(
      'a self sign-up with the same phone is enrolled under its own ID',
      () async {
        expect(await a.farmerIdForPhone('9000000150'), raju);
        final id = await a.enrolFarmer(
          farmerId: 'minted-elsewhere',
          phone: '9000000150',
          name: 'Raju P',
          language: Language.te,
          villageId: kondapur,
          photoKey: 'farmers/minted-elsewhere/p.jpg',
          proof: _proof('+919000000150'),
          noticeVersion: 'v3',
        );
        expect(id, raju);
        final t = await h.territory();
        expect(t.search('9000000150'), hasLength(1));
        expect(t.farmer(raju)!.status, FarmerStatus.active);
        expect(t.farmer(raju)!.consentPending, isFalse);
        final e = (await h.outbox()).single;
        expect(
          e.payload['photo_key'],
          isNull,
          reason: 'wrong prefix: left out',
        );
        expect(e.meta[OutboxMeta.consentProofExpiresAt], isNotNull);
      },
    );

    test('a proof that expired or is for another phone is not sent', () async {
      await a.enrolFarmer(
        phone: '9848012345',
        name: 'A',
        language: Language.te,
        villageId: kondapur,
        proof: _proof('+919848099999'),
      );
      h.clock.advance(const Duration(seconds: 1));
      await a.enrolFarmer(
        phone: '9848012346',
        name: 'B',
        language: Language.te,
        villageId: kondapur,
        proof: _proof('+919848012346', validFor: Duration.zero),
      );
      for (final e in await h.outbox()) {
        expect(
          (e.payload['consent']! as Map<String, Object?>)['otp_proof'],
          isNull,
        );
        expect(e.meta, isEmpty);
      }
    });

    test('a photo key under the farmer ID is kept', () async {
      final id = await a.farmerIdForPhone('9848012345');
      await a.enrolFarmer(
        farmerId: id,
        phone: '9848012345',
        name: 'A',
        language: Language.te,
        villageId: kondapur,
        photoKey: 'farmers/$id/photo.jpg',
      );
      expect(
        (await h.outbox()).single.payload['photo_key'],
        'farmers/$id/photo.jpg',
      );
    });
  });

  test('record consent needs a valid proof for the farmer phone', () async {
    await expectLater(
      a.recordConsent(
        farmerId: raju,
        proof: _proof('+919848012345'),
        noticeVersion: 'v3',
      ),
      throwsA(_actionError(FaActionError.proofInvalid)),
    );
    await a.recordConsent(
      farmerId: raju,
      proof: _proof('+919000000150'),
      noticeVersion: 'v3',
    );
    expect((await h.territory()).farmer(raju)!.consentPending, isFalse);
  });

  group('plots and seasons', () {
    test(
      'an edit carries the version the FA sees; a second edit the next',
      () async {
        await a.savePlot(
          farmerId: padma,
          plotId: padmaPlot2,
          label: 'Plot 2',
          pin: padmaPin,
          areaAcres: 1.75,
          areaSource: AreaSource.typed,
        );
        await a.savePlot(
          farmerId: padma,
          plotId: padmaPlot2,
          label: 'Plot 2 (river side)',
          pin: padmaPin,
          areaAcres: 1.75,
          areaSource: AreaSource.typed,
        );
        // Never sent: the second edit replaces the first in place, at the
        // version the FA saw (one live edit per plot).
        var rows = await h.rows(CommandType.savePlot);
        expect(rows, hasLength(1));
        expect(rows[0].payload['expected_version'], 3);
        expect(rows[0].payload['label'], 'Plot 2 (river side)');
        expect(
          rows[0].dependsOnId,
          isNull,
          reason: 'the plot is on the server',
        );
        var t = await h.territory();
        expect(t.plot(padmaPlot2)!.label, 'Plot 2 (river side)');
        expect(t.plot(padmaPlot2)!.version, 4);

        // On its way (sent, no answer): the next edit waits for it and
        // assumes it applies.
        await h.store.updateOutbox(
          rows[0].copyWith(state: OutboxState.sending, attempts: 1),
        );
        await a.savePlot(
          farmerId: padma,
          plotId: padmaPlot2,
          label: 'Plot 2 (canal)',
          pin: padmaPin,
          areaAcres: 1.75,
          areaSource: AreaSource.typed,
        );
        rows = await h.rows(CommandType.savePlot);
        expect(rows, hasLength(2));
        expect(rows[1].payload['expected_version'], 4);
        expect(rows[1].meta[OutboxMeta.versionParent], rows[0].id);
        expect(rows[1].dependsOnId, isNull, reason: 'an edit creates nothing');
        t = await h.territory();
        expect(t.plot(padmaPlot2)!.label, 'Plot 2 (canal)');
        expect(t.plot(padmaPlot2)!.version, 5);
      },
    );

    test('plot checks', () async {
      Future<String> save({
        String? plotId,
        String farmerId = padma,
        LatLng? pin = padmaPin,
        double area = 1,
        AreaSource source = AreaSource.typed,
      }) => a.savePlot(
        farmerId: farmerId,
        plotId: plotId,
        label: 'P',
        pin: pin,
        areaAcres: area,
        areaSource: source,
      );
      await expectLater(
        save(pin: null),
        throwsA(_actionError(FaActionError.locationRequired)),
      );
      await expectLater(
        save(source: AreaSource.boundary),
        throwsA(_actionError(FaActionError.locationRequired)),
      );
      await expectLater(
        save(area: 0),
        throwsA(_actionError(FaActionError.outOfRange)),
      );
      await expectLater(
        save(area: 10001),
        throwsA(_actionError(FaActionError.outOfRange)),
      );
      await expectLater(
        save(plotId: raviPlot),
        throwsA(_actionError(FaActionError.notFound, field: 'plot_id')),
        reason: "another farmer's plot",
      );
      await expectLater(
        save(farmerId: 'nobody'),
        throwsA(_actionError(FaActionError.notFound, field: 'farmer_id')),
      );
    });

    test('season code must be open; one active season per plot', () async {
      await expectLater(
        a.startSeason(farmerId: venkat, plotId: raviPlot, cropId: cotton),
        throwsA(_actionError(FaActionError.notFound, field: 'plot_id')),
      );
      await expectLater(
        a.startSeason(farmerId: padma, plotId: padmaPlot2, cropId: cotton),
        throwsA(_actionError(FaActionError.seasonActive, field: 'plot_id')),
        reason: 'the server would answer active_season and refuse its visits',
      );
      final plot = await a.savePlot(
        farmerId: venkat,
        label: 'Plot 1',
        pin: const LatLng(17.46, 78.36),
        areaAcres: 1,
        areaSource: AreaSource.typed,
      );
      await expectLater(
        a.startSeason(
          farmerId: venkat,
          plotId: plot,
          cropId: cotton,
          seasonCode: 'kharif-2020',
        ),
        throwsA(_actionError(FaActionError.invalidSeasonCode)),
      );
      await expectLater(
        a.startSeason(farmerId: venkat, plotId: plot, cropId: 'c-unknown'),
        throwsA(_actionError(FaActionError.notFound, field: 'crop_id')),
      );
    });
  });

  test('texts are counted in UTF-8 bytes, as the server does', () async {
    // 34 Telugu letters = 102 bytes: over the 100-byte name limit although
    // it is only 34 characters.
    final telugu = 'ర' * 34;
    await expectLater(
      a.updateFarmer(farmerId: ravi, name: telugu),
      throwsA(_actionError(FaActionError.tooLong, field: 'name')),
    );
    await expectLater(
      a.savePlot(
        farmerId: padma,
        label: 'ప' * 21, // 63 bytes > 60
        pin: padmaPin,
        areaAcres: 1,
        areaSource: AreaSource.typed,
      ),
      throwsA(_actionError(FaActionError.tooLong, field: 'label')),
    );
    await a.updateFarmer(farmerId: ravi, nameTe: 'ర' * 100); // 300 bytes
    await expectLater(
      a.updateFarmer(farmerId: ravi, nameTe: 'ర' * 101),
      throwsA(_actionError(FaActionError.tooLong, field: 'name_te')),
    );
  });

  test(
    'a Telugu name cannot be cleared (the server refuses a blank one)',
    () async {
      expect((await h.territory()).farmer(ravi)!.nameTe, isNotNull);
      await expectLater(
        a.updateFarmer(farmerId: ravi, nameTe: '  '),
        throwsA(_actionError(FaActionError.cannotClear, field: 'name_te')),
      );
    },
  );

  test(
    'a walked boundary: crossing itself or no area has its own code',
    () async {
      Future<void> save(List<LatLng> ring, {double area = 1}) => a.savePlot(
        farmerId: padma,
        label: 'Plot 3',
        boundaryGeoJson: polygonGeoJson(ring),
        areaAcres: area,
        areaSource: AreaSource.boundary,
      );
      const p1 = LatLng(17.4300, 78.3400);
      const p2 = LatLng(17.4300, 78.3410);
      const p3 = LatLng(17.4310, 78.3410);
      const p4 = LatLng(17.4310, 78.3400);
      await expectLater(
        save(const [p1, p3, p2, p4]),
        throwsA(
          _actionError(FaActionError.boundaryCrossesItself, field: 'boundary'),
        ),
      );
      await expectLater(
        save(const [p1, p2, LatLng(17.4300, 78.3420)]),
        throwsA(_actionError(FaActionError.areaTooSmall, field: 'boundary')),
        reason: 'corners in a line',
      );
      await expectLater(
        save(const [p1, p2, p3, p4], area: 0),
        throwsA(_actionError(FaActionError.areaTooSmall, field: 'boundary')),
      );
      await save(const [p1, p2, p3, p4], area: 2.7);
    },
  );

  test('actions take their time from the clock they are given (the app '
      'gives the server-corrected one)', () async {
    // The phone runs 20 minutes slow; the server clock is right. A visit
    // logged "now" by the server clock passes the 15-minute check.
    final serverNow = fixtureNow.add(const Duration(minutes: 20));
    final actions = FaActions(store: h.store, clock: FixedClock(serverNow));
    await actions.logVisit(
      VisitLogInput(
        farmerId: ravi,
        visitId: raviPlannedVisit,
        visitedAt: serverNow,
      ),
    );
    final e = (await h.rows(CommandType.logVisit)).single;
    expect(e.payload['visited_at'], utcIso(serverNow));
    expect(e.clientCreatedAt, serverNow);
  });

  test('update farmer sends only what changed, at the version seen', () async {
    await expectLater(
      a.updateFarmer(farmerId: ravi, name: 'Ravi K', language: Language.te),
      throwsA(_actionError(FaActionError.nothingToChange)),
    );
    await expectLater(
      a.updateFarmer(farmerId: ravi, photoKey: 'farmers/someone-else/p.jpg'),
      throwsA(_actionError(FaActionError.notFound, field: 'photo_key')),
    );
    await a.updateFarmer(
      farmerId: ravi,
      name: 'Ravi K',
      nameTe: 'రవి కుమార్',
      language: Language.en,
    );
    final e = (await h.rows(CommandType.updateFarmer)).single;
    expect(e.payload, {
      'farmer_id': ravi,
      'expected_version': 2,
      'fields': {'name_te': 'రవి కుమార్', 'language': 'en'},
    });
    expect((await h.territory()).farmer(ravi)!.language, Language.en);
  });

  group('visits', () {
    test(
      'plan: plot and season default to the active ones; no past days',
      () async {
        final id = await a.planVisit(farmerId: ravi, plannedFor: today);
        final p =
            (await h.rows(CommandType.planVisit)).single.command
                as PlanVisitPayload;
        expect(p.visitId, id);
        expect(p.plotId, raviPlot);
        expect(p.seasonId, raviSeason);
        expect(p.plannedSlot, VisitSlot.any);
        await expectLater(
          a.planVisit(farmerId: ravi, plannedFor: today.addDays(-1)),
          throwsA(_actionError(FaActionError.invalidDate)),
        );
        await expectLater(
          a.planVisit(farmerId: venkat, plannedFor: today),
          throwsA(_actionError(FaActionError.noSeason)),
        );
      },
    );

    test(
      'log: planned visit, issues with advice, photos queued, next visit',
      () async {
        final logged = await a.logVisit(
          VisitLogInput(
            farmerId: ravi,
            visitId: raviPlannedVisit,
            location: raviPin,
            stageId: stFlowering,
            notes: ' bolls damaged ',
            issues: const [
              VisitIssueInput(
                issueId: issBollworm,
                severity: Severity.high,
                ruleId: ruleEmamectin,
              ),
              VisitIssueInput(issueId: issBoron, severity: Severity.low),
            ],
            photos: [
              VisitPhotoInput(
                bytes: photoBytes(1),
                contentType: PhotoContentType.jpeg,
              ),
              VisitPhotoInput(
                bytes: photoBytes(2),
                contentType: PhotoContentType.jpeg,
              ),
            ],
            nextVisit: NextVisitInput(
              plannedFor: today.addDays(7),
              slot: VisitSlot.afternoon,
            ),
          ),
        );
        expect(logged.visitId, raviPlannedVisit);
        expect(logged.photoIds, hasLength(2));
        final e = (await h.rows(CommandType.logVisit)).single;
        final p = e.command as LogVisitPayload;
        expect(p.notes, 'bolls damaged');
        expect(p.issues[0].advisoryRuleId, ruleEmamectin);
        expect(p.issues[1].advisoryRuleId, isNull);
        expect(p.nextVisit!.visitId, logged.nextVisitId);
        expect(p.dependsOnIds, isNot(contains(raviPlannedVisit)));

        final queued = await h.store.photos();
        expect([for (final q in queued) q.photoId], logged.photoIds);
        expect(
          queued.every((q) => q.state == PhotoUploadState.waiting),
          isTrue,
        );
        expect(queued.every((q) => q.commandId == e.id), isTrue);
        expect(queued[0].sha256, hasLength(64));
        expect(queued[0].byteCount, 66);

        final t = await h.territory();
        final v = t.visit(raviPlannedVisit)!;
        expect(v.status, VisitStatus.done);
        expect(v.issues[0].productName, 'Sample 5 SG');
        expect(v.issues[1].adviceStatus, AdviceStatus.unresolved);
        expect(t.visit(logged.nextVisitId!)!.status, VisitStatus.planned);
        expect(t.openCallback(ravi), isNull, reason: 'LogVisit closes it');
      },
    );

    test('log checks', () async {
      await expectLater(
        a.logVisit(
          const VisitLogInput(
            farmerId: ravi,
            issues: [
              VisitIssueInput(
                issueId: issLeafCurl,
                severity: Severity.low,
                ruleId: ruleEmamectin,
              ),
            ],
          ),
        ),
        throwsA(_actionError(FaActionError.notFound, field: 'rule_id')),
      );
      await expectLater(
        a.logVisit(
          VisitLogInput(
            farmerId: ravi,
            issues: [
              for (var i = 0; i < 21; i++)
                const VisitIssueInput(
                  issueId: issBoron,
                  severity: Severity.low,
                ),
            ],
          ),
        ),
        throwsA(_actionError(FaActionError.tooMany, field: 'issues')),
      );
      await expectLater(
        a.logVisit(
          VisitLogInput(
            farmerId: ravi,
            visitedAt: fixtureNow.add(const Duration(hours: 1)),
          ),
        ),
        throwsA(_actionError(FaActionError.invalidDate, field: 'visited_at')),
      );
      await expectLater(
        a.logVisit(const VisitLogInput(farmerId: ravi, visitId: raviDoneVisit)),
        throwsA(_actionError(FaActionError.notPlanned)),
      );
      await expectLater(
        a.logVisit(const VisitLogInput(farmerId: ravi, stageId: 'st-other')),
        throwsA(_actionError(FaActionError.notFound, field: 'stage_id')),
      );
    });

    test(
      'edit a queued visit: payload replaced in place, photos follow',
      () async {
        final logged = await a.logVisit(
          VisitLogInput(
            farmerId: ravi,
            visitId: raviPlannedVisit,
            photos: [
              VisitPhotoInput(
                bytes: photoBytes(1),
                contentType: PhotoContentType.jpeg,
              ),
              VisitPhotoInput(
                bytes: photoBytes(2),
                contentType: PhotoContentType.jpeg,
              ),
            ],
            nextVisit: NextVisitInput(
              plannedFor: today.addDays(7),
              slot: VisitSlot.morning,
            ),
          ),
        );
        final before = (await h.rows(CommandType.logVisit)).single;
        final input = (await a.queuedVisitInput(raviPlannedVisit))!;
        expect(input.photos, hasLength(2));

        final edited = await a.editQueuedVisit(
          raviPlannedVisit,
          VisitLogInput(
            farmerId: ravi,
            stageId: stFlowering,
            issues: const [
              VisitIssueInput(issueId: issBoron, severity: Severity.moderate),
            ],
            photos: [
              input.photos.first,
              VisitPhotoInput(
                bytes: photoBytes(3),
                contentType: PhotoContentType.png,
              ),
            ],
            nextVisit: NextVisitInput(
              plannedFor: today.addDays(9),
              slot: VisitSlot.afternoon,
            ),
          ),
        );
        final rows = await h.outbox();
        expect(rows, hasLength(1), reason: 'replaced, not added');
        final after = rows.single;
        expect(after.id, before.id);
        expect(after.seq, before.seq);
        final p = after.command as LogVisitPayload;
        expect(p.visitId, raviPlannedVisit);
        expect(p.stageId, stFlowering);
        expect(
          p.nextVisit!.visitId,
          logged.nextVisitId,
          reason: 'same next visit',
        );
        expect(p.nextVisit!.plannedFor, today.addDays(9));
        expect(edited.photoIds.first, logged.photoIds.first);
        final photos = {for (final q in await h.store.photos()) q.photoId};
        expect(photos, edited.photoIds.toSet());
        expect(photos, isNot(contains(logged.photoIds[1])));

        final t = await h.territory();
        expect(t.visit(raviPlannedVisit)!.issues.single.issueId, issBoron);
        expect(t.visit(logged.nextVisitId!)!.plannedFor, today.addDays(9));
        expect(t.visitsOn(today.addDays(7)).isEmpty, isTrue);
      },
    );

    test('a visit already sent cannot be edited', () async {
      await a.logVisit(
        const VisitLogInput(farmerId: ravi, visitId: raviPlannedVisit),
      );
      final e = (await h.rows(CommandType.logVisit)).single;
      await h.store.updateOutbox(e.copyWith(attempts: 1));
      expect(await a.canEditVisit(raviPlannedVisit), isFalse);
      expect(await a.queuedVisitInput(raviPlannedVisit), isNull);
      await expectLater(
        a.editQueuedVisit(
          raviPlannedVisit,
          const VisitLogInput(farmerId: ravi),
        ),
        throwsA(_actionError(FaActionError.notEditable)),
      );
    });

    test('re-plan: the same visit ID on a new day; slot and purpose kept '
        'unless given', () async {
      await a.replanVisit(raviPlannedVisit, plannedFor: today.addDays(5));
      final rows = await h.rows(CommandType.planVisit);
      final p = rows.single.command as PlanVisitPayload;
      expect(p.visitId, raviPlannedVisit);
      expect(p.farmerId, ravi);
      expect(p.plotId, raviPlot);
      expect(p.seasonId, raviSeason);
      expect(p.plannedFor, today.addDays(5));
      expect(p.plannedSlot, VisitSlot.morning, reason: 'kept');
      expect(p.purpose, isNull);
      final v = (await h.territory()).visit(raviPlannedVisit)!;
      expect(v.status, VisitStatus.planned);
      expect(v.plannedFor, today.addDays(5));
      expect(v.plannedSlot, VisitSlot.morning);

      await a.replanVisit(
        raviPlannedVisit,
        plannedFor: today.addDays(5),
        slot: VisitSlot.afternoon,
        purpose: ' Soil sample ',
      );
      final t = await h.territory();
      expect(t.visit(raviPlannedVisit)!.plannedSlot, VisitSlot.afternoon);
      expect(t.visit(raviPlannedVisit)!.purpose, 'Soil sample');
      expect(t.visitsOn(today.addDays(3)).isEmpty, isTrue);
      expect(t.visitsOn(today.addDays(5)).count, 1);
    });

    test(
      're-plan: the same plan sends nothing; checks the visit and day',
      () async {
        await a.replanVisit(raviPlannedVisit, plannedFor: today.addDays(3));
        expect(await h.rows(CommandType.planVisit), isEmpty);
        await expectLater(
          a.replanVisit(raviDoneVisit, plannedFor: today),
          throwsA(_actionError(FaActionError.notPlanned)),
        );
        await expectLater(
          a.replanVisit('nobody', plannedFor: today),
          throwsA(_actionError(FaActionError.notFound)),
        );
        await expectLater(
          a.replanVisit(raviPlannedVisit, plannedFor: today.addDays(-1)),
          throwsA(_actionError(FaActionError.invalidDate)),
        );
      },
    );

    test(
      're-plan of a visit planned on the phone waits for that plan',
      () async {
        final id = await a.planVisit(farmerId: ravi, plannedFor: today);
        await a.replanVisit(id, plannedFor: today.addDays(2));
        final rows = await h.rows(CommandType.planVisit);
        expect(rows, hasLength(2));
        expect(rows.last.dependsOnId, rows.first.id);
        expect((rows.last.command as PlanVisitPayload).visitId, id);
        expect((await h.territory()).visit(id)!.plannedFor, today.addDays(2));
      },
    );

    test('cancel only a planned visit', () async {
      await expectLater(
        a.cancelVisit(raviDoneVisit),
        throwsA(_actionError(FaActionError.notPlanned)),
      );
      await a.cancelVisit(raviPlannedVisit, reason: 'farmer away');
      expect(
        (await h.territory()).visit(raviPlannedVisit)!.status,
        VisitStatus.cancelled,
      );
    });
  });

  test('close call-back and ack alert', () async {
    await a.closeCallback(raviCallback, note: 'spoke to him');
    await a.ackAlert(alertNote);
    await a.ackAlert(alertNote);
    expect(await h.outbox(), hasLength(2), reason: 'a second ack is a no-op');
    final t = await h.territory();
    expect(t.openCallback(ravi), isNull);
    expect(t.alert(alertCallback)!.status, AlertStatus.closed);
    expect(t.alert(alertNote)!.status, AlertStatus.acknowledged);
    await expectLater(
      a.closeCallback(raviCallback),
      throwsA(_actionError(FaActionError.notFound, field: 'callback_id')),
    );
  });

  test('every action calls onWrite after committing', () async {
    var writes = 0;
    final counted = FaActions(
      store: h.store,
      clock: h.clock,
      onWrite: () => writes++,
    );
    await counted.ackAlert(alertNote);
    await counted.setPhotosOnWifiOnly(false);
    expect(writes, 2);
    expect((await h.store.settings()).photosOnWifiOnly, isFalse);
  });

  test('dismiss only rejected, dropped or resolved rows', () async {
    await a.ackAlert(alertNote);
    final e = (await h.outbox()).single;
    await expectLater(
      a.dismiss(e.id),
      throwsA(_actionError(FaActionError.wrongState)),
    );
    await h.store.updateOutbox(e.copyWith(state: OutboxState.rejected));
    await a.dismiss(e.id);
    expect(await h.outbox(), isEmpty);
    expect((await h.store.syncLog()).last.kind, SyncLogKind.dismissed);
  });
}
