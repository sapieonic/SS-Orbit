import 'package:meta/meta.dart';

/// Guntas in one acre. The API stores areas in acres (`area_acres`).
const guntasPerAcre = 40;

/// Converts guntas to acres (`4` guntas is `0.1` acres).
double guntasToAcres(num guntas) => guntas / guntasPerAcre;

/// Converts acres to guntas (`2.1` acres is `84` guntas).
double acresToGuntas(num acres) => acres * guntasPerAcre.toDouble();

/// An area split into whole acres and guntas, the way farmers say it
/// ("2 ఎ. 4 గుం." for 2.10 acres).
@immutable
final class AcresGuntas {
  /// Creates an area of [acres] acres and [guntas] guntas. Both are
  /// non-negative and [guntas] is below [guntasPerAcre] (40 guntas are the
  /// next acre); validate user input before building one.
  const AcresGuntas(this.acres, this.guntas)
    : assert(acres >= 0, 'acres must not be negative'),
      assert(
        guntas >= 0 && guntas < guntasPerAcre,
        'guntas must be 0-${guntasPerAcre - 1}',
      );

  /// Splits [acres] into whole acres and the nearest whole gunta.
  /// `2.1` gives 2 acres 4 guntas; `0.99` gives 1 acre 0 guntas.
  ///
  /// Any positive area is at least 1 gunta, so a tiny plot (`0.01` acres)
  /// never shows as "0 acres 0 guntas": the API only stores areas above
  /// zero. `0` gives 0 acres 0 guntas. Throws [ArgumentError] for a negative
  /// or non-finite value.
  factory AcresGuntas.fromAcres(num acres) {
    if (!acres.isFinite || acres < 0) {
      throw ArgumentError.value(acres, 'acres', 'must be zero or more');
    }
    var total = acresToGuntas(acres).round();
    if (total == 0 && acres > 0) total = 1;
    return AcresGuntas(total ~/ guntasPerAcre, total % guntasPerAcre);
  }

  /// Whole acres.
  final int acres;

  /// Guntas on top of [acres].
  final int guntas;

  /// The area in acres, for `area_acres`.
  double get totalAcres => acres + guntasToAcres(guntas);

  @override
  bool operator ==(Object other) =>
      other is AcresGuntas && other.acres == acres && other.guntas == guntas;

  @override
  int get hashCode => Object.hash(acres, guntas);

  @override
  String toString() => '$acres ac $guntas gunta';
}
