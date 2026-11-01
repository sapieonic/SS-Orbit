import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/calendar/calendar_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

Stage _stage(String code, int seq, int start, int end) => Stage(
  id: 'stage-$code',
  code: code,
  name: code,
  nameTe: code,
  seq: seq,
  startDay: start,
  endDay: end,
);

final _stages = [
  _stage('seedling', 1, 0, 20),
  _stage('flowering', 2, 21, 60),
  _stage('picking', 3, 61, 100),
];

FarmerCropList _crops({int? durationDays = 100}) => FarmerCropList(
  version: 1,
  seasonCodes: SeasonCodes(
    current: 'rabi-2026-27',
    next: 'summer-2027',
    allOpen: const ['kharif-2026', 'rabi-2026-27', 'summer-2027'],
    validUntil: LocalDate(2027, 3, 31),
  ),
  items: [
    FarmerCrop(
      id: 'crop',
      code: 'crop',
      nameTe: 'పంట',
      name: 'Crop',
      durationDays: durationDays,
      stages: _stages,
    ),
  ],
);

HomePlot _plot({int? days, Stage? current, String cropId = 'crop'}) {
  final at = DateTime.utc(2026);
  return HomePlot(
    plot: Plot(
      id: 'plot',
      farmerId: 'farmer',
      label: 'Plot 1',
      villageId: null,
      boundary: null,
      pin: null,
      areaAcres: 1,
      areaSource: AreaSource.typed,
      gpsAccuracyM: null,
      status: PlotStatus.active,
      version: 1,
      createdAt: at,
      updatedAt: at,
    ),
    activeSeason: Season(
      id: 'season',
      farmerId: 'farmer',
      plotId: 'plot',
      seasonCode: 'rabi-2026-27',
      cropId: cropId,
      sowingDate: days == null ? null : LocalDate(2026, 10, 1),
      previousCropId: null,
      status: SeasonStatus.active,
      version: 1,
      createdAt: at,
      updatedAt: at,
    ),
    daysAfterSowing: days,
    currentStage: current,
  );
}

void main() {
  group('CalendarPlot', () {
    test('a sowing date still ahead: no day, no stage, sows later', () {
      final c = CalendarPlot.of(_plot(days: -3), _crops());
      expect(c.sowsLater, isTrue);
      expect(c.daysAfterSowing, isNull);
      expect(c.currentStage, isNull);
      expect(c.progress, isNull);
    });

    test('sowing day itself is day 0, already sown', () {
      final c = CalendarPlot.of(_plot(days: 0), _crops());
      expect(c.sowsLater, isFalse);
      expect(c.daysAfterSowing, 0);
      expect(c.currentStage?.code, 'seedling');
    });

    test("Home's current stage wins over the day count", () {
      final c = CalendarPlot.of(_plot(days: 10, current: _stages[1]), _crops());
      expect(c.currentIndex, 1);
      expect(c.currentStage, _stages[1]);
    });

    test('without a current stage, the day picks the stage', () {
      expect(CalendarPlot.of(_plot(days: 45), _crops()).currentIndex, 1);
      expect(CalendarPlot.of(_plot(days: 0), _crops()).currentIndex, 0);
    });

    test('past the last stage, the crop stays in it at full progress', () {
      final c = CalendarPlot.of(_plot(days: 130), _crops());
      expect(c.currentIndex, 2);
      expect(c.progress, 1);
    });

    test('no sowing date: no stage and no progress', () {
      final c = CalendarPlot.of(_plot(), _crops());
      expect(c.currentIndex, isNull);
      expect(c.currentStage, isNull);
      expect(c.progress, isNull);
    });

    test('no duration: no progress, the stage still shows', () {
      final c = CalendarPlot.of(_plot(days: 50), _crops(durationDays: null));
      expect(c.progress, isNull);
      expect(c.currentIndex, 1);
    });

    test('a crop missing from the list: no stages, no progress', () {
      final c = CalendarPlot.of(_plot(days: 50, cropId: 'gone'), _crops());
      expect(c.crop, isNull);
      expect(c.currentIndex, isNull);
      expect(c.progress, isNull);
    });

    test('progress is the share of the duration gone', () {
      expect(CalendarPlot.of(_plot(days: 25), _crops()).progress, 0.25);
    });
  });
}
