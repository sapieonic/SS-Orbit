import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Thrown by [NoticeAudioCache.fetch] when the download fails.
class NoticeAudioException implements Exception {
  /// Creates the exception; [statusCode] is null for network errors.
  const NoticeAudioException(this.message, {this.statusCode});

  /// What failed.
  final String message;

  /// HTTP status, when the server answered.
  final int? statusCode;

  @override
  String toString() =>
      'NoticeAudioException: $message'
      '${statusCode == null ? '' : ' (HTTP $statusCode)'}';
}

/// Downloads notice voice notes once and keeps them on disk by cache key.
///
/// Notice `audio_url`s are short-lived presigned URLs, so the file is keyed
/// by the notice ID, never by the URL. A cached file plays offline.
///
/// Only audio is cached: a response that is empty, has a text type
/// (`text/html` from a Wi-Fi login page, `application/json` from an error
/// handler) or starts like markup is rejected before it gets a cache name,
/// so the next try downloads again instead of replaying a broken file.
///
/// The cache keeps itself under [maxBytes]: after each download the least
/// recently played files are deleted until the rest fit.
class NoticeAudioCache {
  /// Creates a cache in [directory] (default: `orbit_voice/` in the app's
  /// cache directory, which the OS may clear when storage is low).
  NoticeAudioCache({
    Future<Directory> Function()? directory,
    HttpClient Function()? httpClient,
    this.timeout = const Duration(seconds: 60),
    this.maxBytes = defaultMaxBytes,
  }) : _directory = directory ?? _defaultDirectory,
       _httpClient = httpClient ?? _defaultClient;

  /// Default [maxBytes]: 50 MB, about 100 minutes of voice notes at
  /// 64 kbit/s AAC.
  static const int defaultMaxBytes = 50 * 1024 * 1024;

  final Future<Directory> Function() _directory;
  final HttpClient Function() _httpClient;

  /// Limit for one whole download: connecting, waiting for the response and
  /// receiving the body, together. The default client also gives up on a
  /// connection that takes more than 20 seconds.
  final Duration timeout;

  /// Total size the cached files are kept under. After each download the
  /// files played least recently are deleted until the total fits; the file
  /// just downloaded is always kept, even when it alone is larger.
  final int maxBytes;

  final Map<String, Future<File>> _inFlight = {};

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationCacheDirectory()).path}/orbit_voice');

  static HttpClient _defaultClient() =>
      HttpClient()..connectionTimeout = const Duration(seconds: 20);

  /// File extensions this cache writes, by response content type.
  static const _extensions = {
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    // Some object stores label an .m4a upload with the generic MP4 type.
    'video/mp4': 'm4a',
    'audio/aac': 'aac',
    'audio/mpeg': 'mp3',
    'audio/mp3': 'mp3',
    'audio/ogg': 'ogg',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
  };

  /// Untyped binary responses: accepted, and checked by their first bytes.
  static const _binaryTypes = {
    'application/octet-stream',
    'binary/octet-stream',
  };

  /// The cached file for [cacheKey], or null when it has not been downloaded.
  Future<File?> cached(String cacheKey) async {
    final dir = await _directory();
    final name = _safeName(cacheKey);
    for (final ext in {..._extensions.values}) {
      final file = File('${dir.path}/$name.$ext');
      if (file.existsSync()) return file;
    }
    return null;
  }

  /// The file for [cacheKey], downloading it from [url] first if needed.
  /// Concurrent calls for the same key share one download.
  ///
  /// Throws [NoticeAudioException] when the download fails, takes longer
  /// than [timeout], or is not audio; nothing is cached then.
  Future<File> fetch(Uri url, String cacheKey) async {
    if (cacheKey.isEmpty) throw ArgumentError.value(cacheKey, 'cacheKey');
    final existing = await cached(cacheKey);
    if (existing != null) {
      await _touch(existing);
      return existing;
    }
    // The callback must not return the removed future: whenComplete would
    // then wait for this very future and never finish.
    return _inFlight[cacheKey] ??= _download(url, cacheKey).whenComplete(() {
      _inFlight.remove(cacheKey);
    });
  }

  /// Deletes the cached file for [cacheKey], if any. The player calls this
  /// when a cached file fails to play, so the next try downloads it again.
  Future<void> remove(String cacheKey) async {
    final file = await cached(cacheKey);
    if (file != null && file.existsSync()) await file.delete();
  }

  /// Deletes every cached file.
  Future<void> clear() async {
    final dir = await _directory();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<File> _download(Uri url, String cacheKey) async {
    final dir = await _directory();
    await dir.create(recursive: true);
    final base = '${dir.path}/${_safeName(cacheKey)}';
    final part = File('$base.part');
    final client = _httpClient();
    try {
      final file = await _receive(client, url, part, base).timeout(
        timeout,
        onTimeout: () => throw NoticeAudioException(
          'download took longer than ${timeout.inSeconds} s',
        ),
      );
      await _evict(dir, keep: file);
      return file;
    } on NoticeAudioException {
      rethrow;
    } on Object catch (e) {
      throw NoticeAudioException('download failed: $e');
    } finally {
      // Also ends a download cut off by the timeout.
      client.close(force: true);
      try {
        if (part.existsSync()) await part.delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }

  /// Downloads [url] into [part] and, only when it is audio, renames it to
  /// [base] plus the extension for its type.
  Future<File> _receive(
    HttpClient client,
    Uri url,
    File part,
    String base,
  ) async {
    final request = await client.getUrl(url);
    final response = await request.close();
    final status = response.statusCode;
    if (status != HttpStatus.ok) {
      await response.drain<void>();
      throw NoticeAudioException('download failed', statusCode: status);
    }
    final type = response.headers.contentType?.mimeType.toLowerCase();
    if (type != null &&
        !_extensions.containsKey(type) &&
        !type.startsWith('audio/') &&
        !_binaryTypes.contains(type)) {
      // A login page or an error document. The body is not read: closing
      // the client drops it.
      throw NoticeAudioException('not audio: $type', statusCode: status);
    }
    await response.pipe(part.openWrite());
    if (part.lengthSync() == 0) {
      throw NoticeAudioException('empty download', statusCode: status);
    }
    if (await _startsLikeText(part)) {
      throw NoticeAudioException(
        'not audio: ${type ?? 'untyped'} body starts like markup',
        statusCode: status,
      );
    }
    return part.rename('$base.${_extensionFor(type, url)}');
  }

  /// Space, tab, line breaks and the UTF-8 byte order mark.
  static const _leadingTextBytes = {0x20, 0x09, 0x0A, 0x0D, 0xEF, 0xBB, 0xBF};

  /// Whether [file] starts with `<` or `{` (after any whitespace or UTF-8
  /// byte order mark), or holds only whitespace: HTML, XML or JSON served
  /// with an audio or binary type. No audio container starts that way.
  static Future<bool> _startsLikeText(File file) async {
    final raf = await file.open();
    try {
      for (final byte in await raf.read(64)) {
        if (_leadingTextBytes.contains(byte)) continue;
        return byte == 0x3C || byte == 0x7B; // '<' or '{'
      }
      return true;
    } finally {
      await raf.close();
    }
  }

  /// Marks [file] as just played, so eviction keeps it longer.
  static Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } on FileSystemException {
      // Eviction then goes by download time instead: harmless.
    }
  }

  /// Deletes the least recently played files until the total is under
  /// [maxBytes], never [keep]. Best effort: a failure only leaves the cache
  /// larger until the next download.
  Future<void> _evict(Directory dir, {required File keep}) async {
    try {
      final files = <(File, FileStat)>[];
      await for (final entity in dir.list()) {
        // Skip other downloads still in progress.
        if (entity is! File || entity.path.endsWith('.part')) continue;
        files.add((entity, await entity.stat()));
      }
      // The new file first, then the most recently played.
      files.sort((a, b) {
        if (a.$1.path == keep.path) return -1;
        if (b.$1.path == keep.path) return 1;
        final byTime = b.$2.modified.compareTo(a.$2.modified);
        return byTime != 0 ? byTime : a.$1.path.compareTo(b.$1.path);
      });
      var total = 0;
      var full = false;
      for (final (file, stat) in files) {
        full = full || (file.path != keep.path && total + stat.size > maxBytes);
        if (full) {
          await file.delete();
        } else {
          total += stat.size;
        }
      }
    } on FileSystemException {
      // Not fatal.
    }
  }

  String _extensionFor(String? type, Uri url) {
    final byType = _extensions[type];
    if (byType != null) return byType;
    final path = url.path.toLowerCase();
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1);
    return _extensions.values.contains(ext) ? ext : 'm4a';
  }

  static String _safeName(String cacheKey) =>
      cacheKey.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
}
