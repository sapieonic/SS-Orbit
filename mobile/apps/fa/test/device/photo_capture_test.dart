import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

import 'package:fa/src/data/models/models.dart';
import 'package:fa/src/device/photo_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

/// The PNG's chunks as (type, data), checking each CRC on the way.
List<(String, Uint8List)> _chunks(Uint8List png) {
  expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final data = ByteData.sublistView(png);
  final out = <(String, Uint8List)>[];
  var at = 8;
  while (at < png.length) {
    final length = data.getUint32(at);
    final type = String.fromCharCodes(png.sublist(at + 4, at + 8));
    final body = png.sublist(at + 8, at + 8 + length);
    final crc = data.getUint32(at + 8 + length);
    expect(crc, _crc32(png.sublist(at + 4, at + 8 + length)), reason: type);
    out.add((type, body));
    at += 12 + length;
  }
  return out;
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}

/// The mock camera.
void main() {
  late FixedClock clock;
  late MockPhotoCapture camera;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 11, 2, 4, 30));
    camera = MockPhotoCapture(clock: clock);
  });

  test('makes a small valid PNG', () async {
    final photo = (await camera.take())!;
    expect(photo.contentType, PhotoContentType.png);
    expect(photo.takenAt, clock.now());
    expect(photo.bytes.length, lessThan(2000));

    final chunks = _chunks(photo.bytes);
    expect(chunks.map((c) => c.$1), ['IHDR', 'IDAT', 'IEND']);
    final header = ByteData.sublistView(chunks.first.$2);
    expect(header.getUint32(0), MockPhotoCapture.width);
    expect(header.getUint32(4), MockPhotoCapture.height);
    expect(header.getUint8(8), 8);
    expect(header.getUint8(9), 2);

    final raw = ZLibCodec().decode(chunks[1].$2);
    const row = 1 + MockPhotoCapture.width * 3;
    expect(raw, hasLength(row * MockPhotoCapture.height));
    // First pixel of the first row is the first palette colour.
    final rgb = MockPhotoCapture.palette.first;
    expect(raw.sublist(1, 4), [
      (rgb >> 16) & 0xff,
      (rgb >> 8) & 0xff,
      rgb & 0xff,
    ]);
  });

  test('each photo has another colour, so thumbnails differ', () async {
    final a = (await camera.take())!;
    final b = (await camera.take())!;
    expect(a.bytes, isNot(b.bytes));
    expect(camera.taken, 2);
  });

  test('backing out gives null; a broken camera throws', () async {
    camera.cancelNext();
    expect(await camera.take(), isNull);
    camera.failNext();
    await expectLater(camera.take(), throwsA(isA<CameraUnavailable>()));
    expect(await camera.take(), isNotNull);
    expect(camera.taken, 1);
  });
}
