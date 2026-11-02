import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../data/data.dart';

/// The plot drawn on a plain grid (A4 step 2): the walked corners joined
/// up (filled once [closed]), the start point, a [pin] for a typed area,
/// and where the FA stands now ([here]) with its GPS accuracy ring.
///
/// A sketch, not a map: no tiles, so it works offline and in tests, and
/// stays light on a Redmi 9A. The view fits everything drawn with at least
/// [minSpanM] metres across.
class BoundarySketch extends StatelessWidget {
  /// Creates the sketch.
  const BoundarySketch({
    super.key,
    required this.semanticLabel,
    this.corners = const [],
    this.closed = false,
    this.pin,
    this.here,
    this.accuracyM,
    this.height = 200,
    this.minSpanM = 60,
  });

  /// What the sketch shows, for screen readers.
  final String semanticLabel;

  /// Walked corners in order.
  final List<LatLng> corners;

  /// The boundary is closed (last corner joins the first, filled).
  final bool closed;

  /// The typed area's pin, or null.
  final LatLng? pin;

  /// The FA's position, or null.
  final LatLng? here;

  /// Accuracy of [here] in metres, or null.
  final double? accuracyM;

  /// Height in dp.
  final double height;

  /// The smallest span shown, in metres.
  final double minSpanM;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final orbit = OrbitColors.of(context);
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(OrbitRadius.lg)),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SketchPainter(
              corners: corners,
              closed: closed,
              pin: pin,
              here: here,
              accuracyM: accuracyM,
              minSpanM: minSpanM,
              background: scheme.surfaceContainerLow,
              grid: scheme.outlineVariant,
              line: scheme.primary,
              fill: scheme.primary.withValues(alpha: 0.2),
              start: orbit.success.fg,
              pinColor: orbit.danger.fg,
              onLine: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter({
    required this.corners,
    required this.closed,
    required this.pin,
    required this.here,
    required this.accuracyM,
    required this.minSpanM,
    required this.background,
    required this.grid,
    required this.line,
    required this.fill,
    required this.start,
    required this.pinColor,
    required this.onLine,
  });

  final List<LatLng> corners;
  final bool closed;
  final LatLng? pin;
  final LatLng? here;
  final double? accuracyM;
  final double minSpanM;
  final Color background;
  final Color grid;
  final Color line;
  final Color fill;
  final Color start;
  final Color pinColor;
  final Color onLine;

  static const _metresPerDegLat = 110574.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final all = [...corners, ?pin, ?here];
    if (all.isEmpty) return;
    final lat0 = all.map((p) => p.lat).reduce((a, b) => a + b) / all.length;
    final lng0 = all.map((p) => p.lng).reduce((a, b) => a + b) / all.length;
    final perLng = 111320.0 * math.cos(lat0 * math.pi / 180);
    // Local metres east / north of the centre.
    Offset metres(LatLng p) =>
        Offset((p.lng - lng0) * perLng, (p.lat - lat0) * _metresPerDegLat);
    var maxDx = minSpanM / 2;
    var maxDy = minSpanM / 2;
    for (final p in all) {
      final m = metres(p);
      maxDx = math.max(maxDx, m.dx.abs());
      maxDy = math.max(maxDy, m.dy.abs());
    }
    const pad = 20.0;
    final scale = math.min(
      (size.width / 2 - pad) / maxDx,
      (size.height / 2 - pad) / maxDy,
    );
    final centre = size.center(Offset.zero);
    Offset at(LatLng p) {
      final m = metres(p);
      return centre + Offset(m.dx * scale, -m.dy * scale);
    }

    if (corners.isNotEmpty) {
      final path = Path()..moveTo(at(corners.first).dx, at(corners.first).dy);
      for (final c in corners.skip(1)) {
        final o = at(c);
        path.lineTo(o.dx, o.dy);
      }
      if (closed) {
        path.close();
        canvas.drawPath(path, Paint()..color = fill);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
      for (final c in corners.skip(1)) {
        canvas.drawCircle(at(c), 4, Paint()..color = line);
      }
      final s = at(corners.first);
      canvas
        ..drawCircle(s, 8, Paint()..color = start)
        ..drawCircle(s, 3, Paint()..color = onLine);
    }

    if (pin case final pin?) {
      final o = at(pin);
      final p = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(o.dx - 8, o.dy - 14)
        ..arcToPoint(
          Offset(o.dx + 8, o.dy - 14),
          radius: const Radius.circular(9),
        )
        ..close();
      canvas
        ..drawPath(p, Paint()..color = pinColor)
        ..drawCircle(Offset(o.dx, o.dy - 15), 3, Paint()..color = onLine);
    }

    if (here case final here?) {
      final o = at(here);
      final ring = (accuracyM ?? 0) * scale;
      if (ring > 6) {
        canvas.drawCircle(
          o,
          ring,
          Paint()..color = line.withValues(alpha: 0.12),
        );
      }
      canvas
        ..drawCircle(o, 7, Paint()..color = onLine)
        ..drawCircle(o, 5, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_SketchPainter old) =>
      old.corners != corners ||
      old.closed != closed ||
      old.pin != pin ||
      old.here != here ||
      old.accuracyM != accuracyM ||
      old.background != background;
}
