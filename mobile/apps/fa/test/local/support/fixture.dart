// A small, fixed territory for the offline engine tests (not a test file).
//
// Today is Mon 2 Nov 2026, 10:30 IST (05:00 UTC). FA Suresh's area is
// Kondapur and Gachibowli. Ravi K grows cotton (day 137, flowering) with a
// visit 12 days ago and one planned for Thursday; Padma S grows paddy, last
// visited 34 days ago, and her Plot 2 is at version 3; Raju P signed up today
// and needs enrolment; Lakshmi N joined yesterday (maize, boundary only);
// Venkat R has no plot.

import 'package:fa/src/data/models/models.dart';
import 'package:orbit_core/orbit_core.dart';

/// 2 Nov 2026, 10:30 IST.
final DateTime fixtureNow = DateTime.utc(2026, 11, 2, 5);

/// A clock at [fixtureNow].
FixedClock fixtureClock() => FixedClock(fixtureNow);

/// Today in IST.
final LocalDate today = LocalDate(2026, 11, 2);

const faId = 'fa-suresh';

// Villages
const kondapur = 'v-kondapur';
const gachibowli = 'v-gachibowli';
const kondapurAt = LatLng(17.4600, 78.3600);
const gachibowliAt = LatLng(17.4400, 78.3490);

// Masters
const cotton = 'c-cotton';
const paddy = 'c-paddy';
const maize = 'c-maize';
const stEmergence = 'st-cotton-emergence';
const stVegetative = 'st-cotton-vegetative';
const stFlowering = 'st-cotton-flowering';
const stPicking = 'st-cotton-picking';
const issBollworm = 'i-pink-bollworm';
const issLeafCurl = 'i-leaf-curl';
const issBoron = 'i-boron';
const saltEmamectin = 's-emamectin';
const saltSpinosad = 's-spinosad';
const skuSample5 = 'sku-sample-5';
const ruleEmamectin = 'r-bollworm-emamectin';
const ruleSpinosad = 'r-bollworm-spinosad';
const ruleLeafCurl = 'r-leaf-curl';

// Farmers and their records
const ravi = 'f-ravi';
const raviPlot = 'p-ravi-1';
const raviSeason = 's-ravi-kharif';
const raviDoneVisit = 'vis-ravi-done';
const raviPlannedVisit = 'vis-ravi-planned';
const raviCallback = 'cb-ravi';
const padma = 'f-padma';
const padmaPlot2 = 'p-padma-2';
const padmaSeason = 's-padma-kharif';
const padmaDoneVisit = 'vis-padma-done';
const raju = 'f-raju';
const lakshmi = 'f-lakshmi';
const lakshmiPlot = 'p-lakshmi-1';
const lakshmiSeason = 's-lakshmi-rabi';
const venkat = 'f-venkat';

// Alerts
const alertCallback = 'a-callback-ravi';
const alertNote = 'a-ho-note';
const alertInvoice = 'a-invoice';
const alertNewFarmer = 'a-new-raju';

const raviPin = LatLng(17.4610, 78.3610);
const padmaPin = LatLng(17.4410, 78.3500);

/// Lakshmi's plot boundary (no pin), a small square near Gachibowli.
final String lakshmiBoundary = polygonGeoJson(const [
  LatLng(17.4300, 78.3400),
  LatLng(17.4300, 78.3410),
  LatLng(17.4310, 78.3410),
  LatLng(17.4310, 78.3400),
]);

/// The crop masters.
final SnapMasters fixtureMasters = SnapMasters(
  version: 3,
  seasonCodes: SnapSeasonCodes(
    current: 'rabi-2026-27',
    next: 'summer-2027',
    allOpen: const ['kharif-2026', 'rabi-2026-27', 'summer-2027'],
    validUntil: LocalDate(2027, 3, 31),
  ),
  crops: const [
    SnapCrop(
      id: cotton,
      code: 'cotton',
      name: 'Cotton',
      nameTe: 'పత్తి',
      durationDays: 180,
      stages: [
        SnapStage(
          id: stEmergence,
          code: 'emergence',
          name: 'Emergence',
          nameTe: 'మొలక',
          seq: 1,
          startDay: 0,
          endDay: 20,
        ),
        SnapStage(
          id: stVegetative,
          code: 'vegetative',
          name: 'Vegetative',
          nameTe: 'పెరుగుదల',
          seq: 2,
          startDay: 21,
          endDay: 60,
        ),
        SnapStage(
          id: stFlowering,
          code: 'flowering',
          name: 'Flowering',
          nameTe: 'పూత',
          seq: 3,
          startDay: 61,
          endDay: 140,
        ),
        SnapStage(
          id: stPicking,
          code: 'picking',
          name: 'Picking',
          nameTe: 'కోత',
          seq: 4,
          startDay: 141,
          endDay: 180,
        ),
      ],
    ),
    SnapCrop(
      id: paddy,
      code: 'paddy',
      name: 'Paddy',
      nameTe: 'వరి',
      durationDays: 120,
      stages: [],
    ),
    SnapCrop(
      id: maize,
      code: 'maize',
      name: 'Maize',
      nameTe: 'మొక్కజొన్న',
      durationDays: 110,
      stages: [],
    ),
  ],
  issues: const [
    SnapIssue(
      id: issBollworm,
      cropId: cotton,
      type: IssueType.pest,
      name: 'Pink bollworm',
      nameTe: 'గులాబీ రంగు పురుగు',
    ),
    SnapIssue(
      id: issLeafCurl,
      cropId: cotton,
      type: IssueType.disease,
      name: 'Leaf curl',
      nameTe: 'ఆకు ముడత',
    ),
    SnapIssue(
      id: issBoron,
      cropId: cotton,
      type: IssueType.deficiency,
      name: 'Boron deficiency',
      nameTe: 'బోరాన్ లోపం',
    ),
  ],
  salts: const [
    SnapSalt(
      id: saltEmamectin,
      name: 'Emamectin benzoate 5% SG',
      nameTe: 'ఎమామెక్టిన్ బెంజోయేట్',
    ),
    SnapSalt(id: saltSpinosad, name: 'Spinosad 45% SC', nameTe: null),
  ],
  skus: const [
    SnapSku(
      id: skuSample5,
      code: 'S5SG',
      productName: 'Sample 5 SG',
      productNameTe: 'శాంపిల్ 5 SG',
      saltId: saltEmamectin,
      packSize: '100 g',
      mrpPaise: 45000,
      cashbackEligible: true,
    ),
  ],
  rules: const [
    SnapRule(
      id: ruleEmamectin,
      ruleKey: 'bollworm-emamectin',
      version: 1,
      issueId: issBollworm,
      saltId: saltEmamectin,
      skuId: skuSample5,
      dosePerAcre: '80 g per acre',
      dosePerAcreTe: 'ఎకరాకు 80 గ్రా',
    ),
    SnapRule(
      id: ruleSpinosad,
      ruleKey: 'bollworm-spinosad',
      version: 1,
      issueId: issBollworm,
      saltId: saltSpinosad,
      skuId: null,
      dosePerAcre: '60 ml per acre',
      dosePerAcreTe: 'ఎకరాకు 60 మి.లీ',
    ),
    SnapRule(
      id: ruleLeafCurl,
      ruleKey: 'leaf-curl',
      version: 1,
      issueId: issLeafCurl,
      saltId: saltSpinosad,
      skuId: null,
      dosePerAcre: '1 ml per litre',
      dosePerAcreTe: 'లీటరుకు 1 మి.లీ',
    ),
  ],
);

SnapFarmer _farmer({
  required String id,
  required String phone,
  String? name,
  String? nameTe,
  String? villageId,
  FarmerSource source = FarmerSource.fa,
  FarmerStatus status = FarmerStatus.active,
  bool consentPending = false,
  int version = 2,
  required DateTime createdAt,
}) => SnapFarmer(
  id: id,
  phone: phone,
  name: name,
  nameTe: nameTe,
  language: Language.te,
  villageId: villageId,
  source: source,
  photoKey: null,
  plan: Plan.free,
  status: status,
  consentsGranted: consentPending ? const [] : const [ConsentPurpose.programme],
  consentPending: consentPending,
  profileCompletedAt: status == FarmerStatus.active ? createdAt : null,
  version: version,
  createdAt: createdAt,
  updatedAt: createdAt,
);

SnapVisit fixtureVisit({
  required String id,
  required String farmerId,
  required String plotId,
  required String seasonId,
  VisitStatus status = VisitStatus.planned,
  LocalDate? plannedFor,
  VisitSlot? slot,
  DateTime? visitedAt,
  List<SnapVisitIssue> issues = const [],
}) => SnapVisit(
  id: id,
  farmerId: farmerId,
  plotId: plotId,
  seasonId: seasonId,
  faId: faId,
  status: status,
  plannedFor: plannedFor,
  plannedSlot: slot,
  purpose: null,
  visitedAt: visitedAt,
  farmerPresent: visitedAt == null ? null : true,
  stageId: null,
  stageName: null,
  stageNameTe: null,
  notes: null,
  photoCount: 0,
  issues: issues,
);

/// The fixture snapshot at [territoryVersion].
Snapshot fixtureSnapshot({
  int territoryVersion = 10,
  int mastersVersion = 3,
  double padmaPlotAcres = 2.0,
  int padmaPlotVersion = 3,
  List<SnapAlert>? alerts,
  List<SnapCallback>? callbacks,
}) {
  final created = DateTime.utc(2026, 6, 1, 5);
  return Snapshot(
    territoryVersion: territoryVersion,
    mastersVersion: mastersVersion,
    generatedAt: fixtureNow.subtract(const Duration(hours: 1)),
    farmers: [
      _farmer(
        id: ravi,
        phone: '+919000000101',
        name: 'Ravi K',
        nameTe: 'రవి కె',
        villageId: kondapur,
        createdAt: created,
      ),
      _farmer(
        id: padma,
        phone: '+919000000103',
        name: 'Padma S',
        nameTe: 'పద్మ ఎస్',
        villageId: gachibowli,
        createdAt: created,
        version: 5,
      ),
      _farmer(
        id: raju,
        phone: '+919000000150',
        name: 'Raju P',
        villageId: kondapur,
        source: FarmerSource.self,
        status: FarmerStatus.pendingProfile,
        consentPending: true,
        version: 1,
        createdAt: fixtureNow.subtract(const Duration(hours: 2)),
      ),
      _farmer(
        id: lakshmi,
        phone: '+919000000151',
        name: 'Lakshmi N',
        villageId: gachibowli,
        createdAt: fixtureNow.subtract(const Duration(days: 1)),
      ),
      _farmer(
        id: venkat,
        phone: '+919000000104',
        name: 'Venkat R',
        villageId: gachibowli,
        createdAt: created,
      ),
    ],
    plots: [
      SnapPlot(
        id: raviPlot,
        farmerId: ravi,
        label: 'Plot 1',
        villageId: kondapur,
        boundaryGeoJson: null,
        pin: raviPin,
        areaAcres: 2.1,
        areaSource: AreaSource.typed,
        gpsAccuracyM: 6,
        status: PlotStatus.active,
        version: 1,
        updatedAt: created,
      ),
      SnapPlot(
        id: padmaPlot2,
        farmerId: padma,
        label: 'Plot 2',
        villageId: gachibowli,
        boundaryGeoJson: null,
        pin: padmaPin,
        areaAcres: padmaPlotAcres,
        areaSource: AreaSource.typed,
        gpsAccuracyM: 8,
        status: PlotStatus.active,
        version: padmaPlotVersion,
        updatedAt: created,
      ),
      SnapPlot(
        id: lakshmiPlot,
        farmerId: lakshmi,
        label: 'Plot 1',
        villageId: gachibowli,
        boundaryGeoJson: lakshmiBoundary,
        pin: null,
        areaAcres: 1.5,
        areaSource: AreaSource.boundary,
        gpsAccuracyM: 5,
        status: PlotStatus.active,
        version: 1,
        updatedAt: created,
      ),
    ],
    seasons: [
      SnapSeason(
        id: raviSeason,
        farmerId: ravi,
        plotId: raviPlot,
        seasonCode: 'kharif-2026',
        cropId: cotton,
        sowingDate: today.addDays(-137),
        previousCropId: null,
        status: SeasonStatus.active,
        version: 1,
        updatedAt: created,
      ),
      SnapSeason(
        id: padmaSeason,
        farmerId: padma,
        plotId: padmaPlot2,
        seasonCode: 'kharif-2026',
        cropId: paddy,
        sowingDate: today.addDays(-90),
        previousCropId: null,
        status: SeasonStatus.active,
        version: 1,
        updatedAt: created,
      ),
      SnapSeason(
        id: lakshmiSeason,
        farmerId: lakshmi,
        plotId: lakshmiPlot,
        seasonCode: 'rabi-2026-27',
        cropId: maize,
        sowingDate: today.addDays(-1),
        previousCropId: null,
        status: SeasonStatus.active,
        version: 1,
        updatedAt: created,
      ),
    ],
    visits: [
      fixtureVisit(
        id: raviDoneVisit,
        farmerId: ravi,
        plotId: raviPlot,
        seasonId: raviSeason,
        status: VisitStatus.done,
        visitedAt: DateTime.utc(2026, 10, 21, 6),
        issues: const [
          SnapVisitIssue(
            id: 'iv-ravi-1',
            issueId: issBollworm,
            issueName: 'Pink bollworm',
            issueNameTe: 'గులాబీ రంగు పురుగు',
            severity: Severity.moderate,
            adviceStatus: AdviceStatus.given,
            ruleId: ruleEmamectin,
            saltId: saltEmamectin,
            saltName: 'Emamectin benzoate 5% SG',
            saltNameTe: null,
            skuId: skuSample5,
            productName: 'Sample 5 SG',
            productNameTe: null,
            dose: '80 g per acre',
            doseTe: null,
          ),
        ],
      ),
      fixtureVisit(
        id: raviPlannedVisit,
        farmerId: ravi,
        plotId: raviPlot,
        seasonId: raviSeason,
        plannedFor: today.addDays(3),
        slot: VisitSlot.morning,
      ),
      fixtureVisit(
        id: padmaDoneVisit,
        farmerId: padma,
        plotId: padmaPlot2,
        seasonId: padmaSeason,
        status: VisitStatus.done,
        visitedAt: DateTime.utc(2026, 9, 29, 9),
      ),
    ],
    callbacks:
        callbacks ??
        [
          SnapCallback(
            id: raviCallback,
            farmerId: ravi,
            requestedAt: fixtureNow.subtract(const Duration(minutes: 25)),
          ),
        ],
    alerts:
        alerts ??
        [
          SnapAlert(
            id: alertCallback,
            faId: faId,
            kind: AlertKind.callback,
            farmerId: ravi,
            refId: raviCallback,
            title: 'Ravi K asked you to call',
            body: null,
            titleTe: null,
            bodyTe: null,
            status: AlertStatus.open,
            createdAt: fixtureNow.subtract(const Duration(minutes: 25)),
            acknowledgedAt: null,
          ),
          SnapAlert(
            id: alertNote,
            faId: faId,
            kind: AlertKind.hoNote,
            farmerId: null,
            refId: null,
            title: 'Please finish pending enrolments by Friday.',
            body: null,
            titleTe: null,
            bodyTe: null,
            status: AlertStatus.open,
            createdAt: fixtureNow.subtract(const Duration(days: 1)),
            acknowledgedAt: null,
          ),
          SnapAlert(
            id: alertInvoice,
            faId: faId,
            kind: AlertKind.invoiceCheck,
            farmerId: ravi,
            refId: null,
            title: 'Invoice to check',
            body: null,
            titleTe: null,
            bodyTe: null,
            status: AlertStatus.open,
            createdAt: fixtureNow.subtract(const Duration(hours: 1)),
            acknowledgedAt: null,
          ),
          SnapAlert(
            id: alertNewFarmer,
            faId: faId,
            kind: AlertKind.newFarmer,
            farmerId: raju,
            refId: raju,
            title: 'Raju P joined',
            body: null,
            titleTe: null,
            bodyTe: null,
            status: AlertStatus.open,
            createdAt: fixtureNow.subtract(const Duration(minutes: 10)),
            acknowledgedAt: null,
          ),
        ],
    masters: fixtureMasters,
    villages: [
      SnapVillage(
        id: kondapur,
        name: 'Kondapur',
        nameTe: 'కొండాపూర్',
        lgdCode: null,
        location: kondapurAt,
        mandalId: 'm-serilingampally',
        mandalName: 'Serilingampally',
        mandalNameTe: null,
        districtId: 'd-rangareddy',
        districtName: 'Rangareddy',
        districtNameTe: null,
        createdAt: created,
      ),
      SnapVillage(
        id: gachibowli,
        name: 'Gachibowli',
        nameTe: 'గచ్చిబౌలి',
        lgdCode: null,
        location: gachibowliAt,
        mandalId: 'm-serilingampally',
        mandalName: 'Serilingampally',
        mandalNameTe: null,
        districtId: 'd-rangareddy',
        districtName: 'Rangareddy',
        districtNameTe: null,
        createdAt: created,
      ),
    ],
  );
}

/// [s] with another territory version (and optionally other plots or
/// seasons).
Snapshot withVersion(
  Snapshot s,
  int territoryVersion, {
  List<SnapPlot>? plots,
  List<SnapSeason>? seasons,
  List<SnapVisit>? visits,
}) => Snapshot(
  territoryVersion: territoryVersion,
  mastersVersion: s.mastersVersion,
  generatedAt: s.generatedAt,
  farmers: s.farmers,
  plots: plots ?? s.plots,
  seasons: seasons ?? s.seasons,
  visits: visits ?? s.visits,
  callbacks: s.callbacks,
  alerts: s.alerts,
  masters: s.masters,
  villages: s.villages,
);
