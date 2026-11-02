import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/local/fa_actions.dart';
import 'package:fa/src/local/territory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import 'support/fakes.dart';
import 'support/fixture.dart';

void main() {
  late Harness h;
  late Territory t;

  setUp(() async {
    h = Harness();
    await h.seed();
    t = await h.territory();
  });

  tearDown(() => h.dispose());

  List<String> ids(List<FarmerRow> rows) => [for (final r in rows) r.farmer.id];

  test('an empty store has no data', () async {
    final empty = Territory.empty(asOf: fixtureNow);
    expect(empty.hasData, isFalse);
    expect(empty.farmers, isEmpty);
    expect(empty.farmerRows(), isEmpty);
    expect(empty.masters.crops, isEmpty);
  });

  group('farmers near me', () {
    test('nearest first: plot pin, boundary centre, else village', () {
      final rows = t.farmerRows(from: kondapurAt);
      expect(ids(rows), [raju, ravi, padma, venkat, lakshmi]);
      expect(rows[0].distanceKm, closeTo(0, 1e-9), reason: 'Raju: village');
      expect(rows[1].distanceKm, closeTo(0.15, 0.01), reason: 'Ravi: pin');
      expect(rows[2].distanceKm, closeTo(2.36, 0.05));
      expect(
        rows[3].distanceKm,
        closeTo(2.51, 0.05),
        reason: 'Venkat: village',
      );
      expect(
        rows[4].distanceKm,
        closeTo(3.88, 0.05),
        reason: 'Lakshmi: centre',
      );
      expect(rows[4].location!.lat, closeTo(17.4305, 1e-9));
    });

    test('without a point the order is by name', () {
      expect(ids(t.farmerRows()), [lakshmi, padma, raju, ravi, venkat]);
      expect(t.farmerRows().first.distanceKm, isNull);
    });

    test('filters and their counts', () {
      List<String> f(FarmerFilter filter) =>
          ids(t.farmerRows(filter: filter))..sort();
      expect(f(FarmerFilter.isNew), [lakshmi, raju]..sort());
      expect(f(FarmerFilter.visitDue), [padma, ravi]..sort());
      expect(f(FarmerFilter.notVisited30), [padma, venkat]..sort());
      expect(f(FarmerFilter.finishEnrolment), [raju, venkat]..sort());
      expect(t.filterCounts(), {
        FarmerFilter.all: 5,
        FarmerFilter.isNew: 2,
        FarmerFilter.visitDue: 2,
        FarmerFilter.notVisited30: 2,
        FarmerFilter.finishEnrolment: 2,
      });
    });

    test('row details: last visit, days since, gaps', () {
      final padmaRow = t.farmerRow(padma)!;
      expect(padmaRow.daysSinceLastVisit, 34);
      expect(padmaRow.lastDoneVisit!.id, padmaDoneVisit);
      expect(padmaRow.mainPlot!.crop!.name, 'Paddy');
      final rajuRow = t.farmerRow(raju)!;
      expect(rajuRow.enrolmentGaps, {
        EnrolmentGap.profile,
        EnrolmentGap.consent,
        EnrolmentGap.plot,
      });
      expect(t.farmerRow(venkat)!.enrolmentGaps, {EnrolmentGap.plot});
      expect(t.farmerRow(ravi)!.nextPlannedVisit!.id, raviPlannedVisit);
    });

    test('search by name (English, Telugu) or phone', () {
      List<String> s(String q) => [for (final f in t.search(q)) f.id];
      expect(s('ravi'), [ravi]);
      expect(s('రవి'), [ravi]);
      expect(s('0101'), [ravi]);
      expect(s('90000 00103'), [padma]);
      expect(s('+91 9000000150'), [raju]);
      // A prefix typed before a partial number is dropped first.
      expect(s('+91 900000015'), [raju, lakshmi]);
      expect(s('0900000010'), containsAll([ravi, padma]));
      expect(s('09000000103'), [padma]);
      expect(s('+919000000101'), [ravi]);
      expect(s('nobody'), isEmpty);
      expect(s(''), hasLength(5));
      expect(ids(t.farmerRows(query: 'padma')), [padma]);
    });

    test('a farmer by phone, any way it is typed', () {
      expect(t.farmerByPhone('90000 00101')!.id, ravi);
      expect(t.farmerByPhone('+919000000101')!.id, ravi);
      expect(t.farmerByPhone('12345'), isNull);
    });
  });

  group('farmer 360', () {
    test(
      'Ravi K: plot, crop, stage, day after sowing, last visit, call-back',
      () {
        final v = t.farmer360(ravi)!;
        expect(v.farmer.name, 'Ravi K');
        final plot = v.plots.single;
        expect(plot.plot.label, 'Plot 1');
        expect(plot.crop!.name, 'Cotton');
        expect(plot.stage!.code, 'flowering');
        expect(plot.daysAfterSowing, 137);
        expect(v.lastDoneVisit!.visit.id, raviDoneVisit);
        expect(v.lastDoneVisit!.visit.issues.single.issueName, 'Pink bollworm');
        expect(v.plannedVisits.single.visit.id, raviPlannedVisit);
        expect(v.openCallback!.id, raviCallback);
        expect(v.consentPending, isFalse);
        expect(v.pendingSync, isFalse);
      },
    );

    test('unknown farmer', () => expect(t.farmer360('nobody'), isNull));
  });

  group('calendar', () {
    test('visits of a day by slot, and the week strip counts', () async {
      await h.actions.logVisit(const VisitLogInput(farmerId: padma));
      await h.actions.planVisit(
        farmerId: lakshmi,
        plannedFor: today,
        slot: VisitSlot.afternoon,
      );
      t = await h.territory();

      final day = t.visitsOn(today);
      expect([for (final r in day.morning) r.farmer!.id], [padma]);
      expect(day.morning.single.isDone, isTrue);
      expect(day.morning.single.pendingSync, isTrue);
      expect([for (final r in day.afternoon) r.farmer!.id], [lakshmi]);
      expect(day.count, 2);
      expect(day.doneCount, 1);

      final thursday = t.visitsOn(today.addDays(3));
      expect(thursday.morning.single.visit.id, raviPlannedVisit);
      expect(thursday.morning.single.crop!.name, 'Cotton');

      expect(t.weekCounts(today), [
        DayCount(day: today, planned: 1, done: 1),
        DayCount(day: today.addDays(1), planned: 0, done: 0),
        DayCount(day: today.addDays(2), planned: 0, done: 0),
        DayCount(day: today.addDays(3), planned: 1, done: 0),
        DayCount(day: today.addDays(4), planned: 0, done: 0),
        DayCount(day: today.addDays(5), planned: 0, done: 0),
        DayCount(day: today.addDays(6), planned: 0, done: 0),
      ]);
    });

    test('a cancelled visit leaves the calendar', () async {
      await h.actions.cancelVisit(raviPlannedVisit);
      t = await h.territory();
      expect(t.visitsOn(today.addDays(3)).isEmpty, isTrue);
      expect(t.weekCounts(today)[3].total, 0);
    });
  });

  group('alerts', () {
    test('open alerts newest first, invoice_check hidden, badge', () {
      expect(
        [for (final a in t.alerts) a.id],
        [alertNewFarmer, alertCallback, alertNote],
      );
      expect(t.openAlertCount, 3);
    });

    test('allAlerts keeps closed ones; invoice_check stays hidden', () async {
      expect(
        [for (final a in t.allAlerts) a.id],
        [alertNewFarmer, alertCallback, alertNote],
      );
      await h.actions.enrolFarmer(
        phone: '+919000000150',
        name: 'Raju P',
        language: Language.te,
        villageId: kondapur,
      );
      t = await h.territory();
      expect(t.alert(alertNewFarmer)!.status, AlertStatus.closed);
      expect([for (final a in t.alerts) a.id], [alertCallback, alertNote]);
      expect(
        [for (final a in t.allAlerts) a.id],
        [alertNewFarmer, alertCallback, alertNote],
      );
      expect(t.openAlertCount, 2);
    });

    test('an acknowledged note stays listed but leaves the badge', () async {
      await h.actions.ackAlert(alertNote);
      t = await h.territory();
      expect(t.alerts, hasLength(3));
      expect(t.alert(alertNote)!.status, AlertStatus.acknowledged);
      expect(t.openAlertCount, 2);
    });
  });

  group('counts for Me and the PIN screen', () {
    test('plots, done visits and enrolments by month', () {
      expect(t.plotCount, 3);
      expect(t.doneVisitsInMonth(today), 0);
      expect(t.doneVisitsInMonth(LocalDate(2026, 10, 31)), 1);
      expect(t.doneVisitsInMonth(LocalDate(2026, 9, 1)), 1);
      expect(t.enrolledInMonth(today), 1, reason: 'Lakshmi; Raju is pending');
      expect(t.enrolledInMonth(LocalDate(2026, 6, 15)), 3);
    });

    test(
      'a visit logged and a self sign-up enrolled count this month',
      () async {
        await h.actions.logVisit(
          const VisitLogInput(farmerId: ravi, visitId: raviPlannedVisit),
        );
        await h.actions.enrolFarmer(
          phone: '+919000000150',
          name: 'Raju P',
          language: Language.te,
          villageId: kondapur,
        );
        t = await h.territory();
        expect(t.doneVisitsInMonth(today), 1);
        expect(t.enrolledInMonth(today), 2);
        expect(t.enrolledInMonth(LocalDate(2026, 6, 1)), 3);
      },
    );

    test(
      'a farmer without plots adds none; an enrolled one adds its plot',
      () async {
        final f = await h.actions.enrolFarmer(
          phone: '9848012345',
          name: 'Suresh B',
          language: Language.te,
          villageId: kondapur,
        );
        t = await h.territory();
        expect(t.plotCount, 3);
        await h.actions.savePlot(
          farmerId: f,
          label: 'Plot 1',
          pin: const LatLng(17.47, 78.37),
          areaAcres: 1,
          areaSource: AreaSource.typed,
        );
        t = await h.territory();
        expect(t.plotCount, 4);
      },
    );
  });

  group('masters for the visit log', () {
    test('suggested stage from days after sowing', () {
      expect(t.suggestedStage(raviSeason)!.code, 'flowering');
      expect(
        t.suggestedStage(raviSeason, day: today.addDays(5))!.code,
        'picking',
      );
      expect(
        t.suggestedStage(raviSeason, day: today.addDays(100))!.code,
        'picking',
        reason: 'past the last stage: the last one',
      );
      expect(
        t.suggestedStage(raviSeason, day: today.addDays(-140))!.code,
        'emergence',
        reason: 'before sowing: the first one',
      );
      expect(t.suggestedStage(lakshmiSeason), isNull, reason: 'no stages');
    });

    test('issues of a crop by type, and advice with salt, SKU and dose', () {
      expect(t.issueTypesFor(cotton), [
        IssueType.pest,
        IssueType.disease,
        IssueType.deficiency,
      ]);
      expect(
        [for (final i in t.issuesFor(cotton, type: IssueType.pest)) i.id],
        [issBollworm],
      );
      final advice = t.adviceFor(issBollworm);
      expect(advice, hasLength(2));
      expect(advice[0].hasProduct, isTrue);
      expect(advice[0].sku!.productName, 'Sample 5 SG');
      expect(advice[0].saltName(Language.te), 'ఎమామెక్టిన్ బెంజోయేట్');
      expect(advice[0].dose(Language.en), '80 g per acre');
      expect(advice[1].hasProduct, isFalse);
      expect(
        advice[1].saltName(Language.te),
        'Spinosad 45% SC',
        reason: 'no Telugu salt name: English',
      );
      expect(t.adviceFor(issBoron), isEmpty);
    });
  });

  test('nearest village to a point', () {
    expect(t.nearestVillage(padmaPin)!.id, gachibowli);
    expect(t.nearestVillage(raviPin)!.id, kondapur);
  });

  test('pending entity ids and the PIN screen counts', () async {
    expect(t.pendingEntityIds, isEmpty);
    expect(t.farmerCount, 5);
    expect(t.unsyncedCount, 0);
    final logged = await h.actions.logVisit(
      VisitLogInput(
        farmerId: ravi,
        visitId: raviPlannedVisit,
        nextVisit: NextVisitInput(
          plannedFor: today.addDays(10),
          slot: VisitSlot.morning,
        ),
      ),
    );
    await h.actions.ackAlert(alertNote);
    t = await h.territory();
    expect(t.isPending(raviPlannedVisit), isTrue);
    expect(t.isPending(logged.nextVisitId!), isTrue);
    expect(t.isPending(ravi), isTrue);
    expect(t.isPending(padma), isFalse);
    expect(t.farmerRow(ravi)!.pendingSync, isTrue);
    expect(t.unsyncedCount, 2);
    expect(t.isVisitEditable(raviPlannedVisit), isTrue);
  });

  test('past valid_until the old next season is offered as current', () {
    final later = Territory(
      tables: fixtureSnapshot(),
      outbox: const [],
      asOf: DateTime.utc(2027, 4, 2, 5),
    );
    expect(later.seasonCodes.current, 'summer-2027');
    expect(later.seasonCodes.allOpen, isNot(contains('rabi-2026-27')));
    expect(t.seasonCodes.current, 'rabi-2026-27');
  });

  group('overdue and missed visits', () {
    late Territory od;

    setUp(() async {
      final snap = withVersion(
        fixtureSnapshot(),
        10,
        visits: [
          ...fixtureSnapshot().visits,
          fixtureVisit(
            id: 'vis-padma-missed',
            farmerId: padma,
            plotId: padmaPlot2,
            seasonId: padmaSeason,
            status: VisitStatus.missed,
            plannedFor: today.addDays(-3),
          ),
          fixtureVisit(
            id: 'vis-padma-late',
            farmerId: padma,
            plotId: padmaPlot2,
            seasonId: padmaSeason,
            plannedFor: today.addDays(-1),
          ),
        ],
      );
      await h.engine.writeSnapshot(snap);
      od = await h.territory();
    });

    test('overdueVisits: planned or missed before today, oldest first', () {
      expect(
        [for (final r in od.overdueVisits()) r.visit.id],
        ['vis-padma-missed', 'vis-padma-late'],
      );
      expect(od.overdueVisits(day: today.addDays(-3)), isEmpty);
    });

    test('startableVisitFor: the earliest plan not after the day', () {
      expect(od.startableVisitFor(padma)!.id, 'vis-padma-missed');
      expect(
        od.startableVisitFor(padma, plotId: 'p-other'),
        isNull,
        reason: 'plot-aware',
      );
      expect(od.startableVisitFor(ravi), isNull, reason: 'Thursday is later');
      expect(
        od.startableVisitFor(ravi, day: today.addDays(3))!.id,
        raviPlannedVisit,
      );
      expect(od.nextPlannedVisit(padma)!.id, 'vis-padma-missed');
      expect(od.farmerRow(padma)!.isVisitDue, isTrue);
    });

    test('a missed visit can be logged, moved or cancelled', () async {
      final logged = await h.actions.logVisit(
        const VisitLogInput(farmerId: padma, visitId: 'vis-padma-missed'),
      );
      expect(logged.visitId, 'vis-padma-missed');
      await h.actions.replanVisit('vis-padma-late', plannedFor: today);
      await h.actions.cancelVisit('vis-padma-late');
      final t2 = await h.territory();
      expect(t2.visit('vis-padma-missed')!.status, VisitStatus.done);
      expect(t2.visit('vis-padma-late')!.status, VisitStatus.cancelled);
      expect(t2.overdueVisits(), isEmpty);
    });
  });
}
