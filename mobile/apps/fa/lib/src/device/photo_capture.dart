import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_core/orbit_core.dart';

import '../data/models/models.dart';
import '../data/providers.dart' show clockProvider, orbitEnvProvider;

/// A photo the FA just took, still only on the phone.
final class CapturedPhoto {
  /// Creates a photo.
  const CapturedPhoto({
    required this.bytes,
    required this.contentType,
    required this.takenAt,
  });

  /// The encoded image.
  final Uint8List bytes;

  /// The encoding of [bytes] (JPEG from the camera, PNG from the mock).
  final PhotoContentType contentType;

  /// When it was taken (UTC).
  final DateTime takenAt;

  @override
  String toString() =>
      'CapturedPhoto(${contentType.wire}, ${bytes.length} bytes)';
}

/// Thrown by [PhotoCapture.take] when the camera cannot be used.
final class CameraUnavailable implements Exception {
  /// Creates the error.
  const CameraUnavailable([this.message = 'camera unavailable']);

  /// What went wrong (for logs).
  final String message;

  @override
  String toString() => 'CameraUnavailable($message)';
}

/// The phone's camera, for visit and farmer photos.
///
/// Written so `image_picker` drops in later: [take] is
/// `ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600,
/// imageQuality: 80)`; null `XFile` (the FA backed out) -> null; otherwise
/// `XFile.readAsBytes()`, `XFile.mimeType` -> [CapturedPhoto.contentType]
/// (JPEG when unknown) and the clock for [CapturedPhoto.takenAt]. A
/// `PlatformException` (`camera_access_denied`) -> [CameraUnavailable]. On
/// Android also call `ImagePicker().retrieveLostData()` at start, for a photo
/// taken while the system killed the app.
abstract interface class PhotoCapture {
  /// Opens the camera. Null when the FA backed out without a photo. Throws
  /// [CameraUnavailable].
  Future<CapturedPhoto?> take();
}

/// A [PhotoCapture] for mock mode and tests: makes a small valid PNG in
/// memory, a different colour each time so thumbnails can be told apart.
final class MockPhotoCapture implements PhotoCapture {
  /// Creates the mock.
  MockPhotoCapture({this.clock = const SystemClock()});

  /// Pixel size of the mock photos.
  static const width = 48, height = 36;

  /// Leaf, soil, sky, flower, dry stalk, paddy water (RGB).
  static const palette = [
    0x4F8A3C,
    0x8B5A2B,
    0x6FA8DC,
    0xE8B23A,
    0xC9B28A,
    0x3E7F8C,
  ];

  /// Time source for [CapturedPhoto.takenAt].
  final Clock clock;

  var _taken = 0;
  var _cancelNext = false;
  Object? _failNext;

  /// Photos made so far.
  int get taken => _taken;

  /// The next [take] returns null, as if the FA backed out.
  void cancelNext() => _cancelNext = true;

  /// The next [take] throws [error] (default [CameraUnavailable]).
  void failNext([Object error = const CameraUnavailable()]) =>
      _failNext = error;

  @override
  Future<CapturedPhoto?> take() async {
    if (_failNext case final error?) {
      _failNext = null;
      throw error;
    }
    if (_cancelNext) {
      _cancelNext = false;
      return null;
    }
    final rgb = palette[_taken % palette.length];
    _taken++;
    return CapturedPhoto(
      bytes: solidPng(width, height, rgb),
      contentType: PhotoContentType.png,
      takenAt: clock.now(),
    );
  }

  /// A [w] x [h] PNG (8-bit RGB) filled with [rgb] (`0xRRGGBB`), with a
  /// lighter band across the middle so it does not look like a blank tile.
  static Uint8List solidPng(int w, int h, int rgb) {
    final r = (rgb >> 16) & 0xff, g = (rgb >> 8) & 0xff, b = rgb & 0xff;
    int lighter(int c) => c + (255 - c) ~/ 3;
    final raw = BytesBuilder(copy: false);
    for (var y = 0; y < h; y++) {
      raw.addByte(0); // filter: none
      final band = (y - h ~/ 2).abs() < h ~/ 8;
      for (var x = 0; x < w; x++) {
        raw
          ..addByte(band ? lighter(r) : r)
          ..addByte(band ? lighter(g) : g)
          ..addByte(band ? lighter(b) : b);
      }
    }
    final header = ByteData(13)
      ..setUint32(0, w)
      ..setUint32(4, h)
      ..setUint8(8, 8) // bit depth
      ..setUint8(9, 2) // colour type: RGB
      ..setUint8(10, 0) // compression
      ..setUint8(11, 0) // filter
      ..setUint8(12, 0); // interlace
    final out = BytesBuilder(copy: false)
      ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    _chunk(out, 'IHDR', header.buffer.asUint8List());
    _chunk(out, 'IDAT', ZLibCodec().encode(raw.takeBytes()));
    _chunk(out, 'IEND', const []);
    return out.takeBytes();
  }

  static void _chunk(BytesBuilder out, String type, List<int> data) {
    final typeBytes = type.codeUnits;
    out
      ..add(_u32(data.length))
      ..add(typeBytes)
      ..add(data)
      ..add(_u32(_crc32([...typeBytes, ...data])));
  }

  static List<int> _u32(int v) => [
    (v >> 24) & 0xff,
    (v >> 16) & 0xff,
    (v >> 8) & 0xff,
    v & 0xff,
  ];

  static int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var k = 0; k < 8; k++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return crc ^ 0xffffffff;
  }
}

/// The camera the screens use: [MockPhotoCapture] on mock data. There is no
/// real camera yet, so on the API this throws instead of uploading generated
/// images as visit photos.
final photoCaptureProvider = Provider<PhotoCapture>((ref) {
  if (!ref.watch(orbitEnvProvider).usesMock) {
    throw UnimplementedError(
      'PhotoCapture on the API needs the image_picker plugin (a camera '
      'implementation of PhotoCapture); only MockPhotoCapture exists. See '
      '"Not done yet" in mobile/README.md.',
    );
  }
  return MockPhotoCapture(clock: ref.watch(clockProvider));
});
