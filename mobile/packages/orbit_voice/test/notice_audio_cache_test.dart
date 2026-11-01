import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_voice/orbit_voice.dart';

/// Audio-looking bytes (an ADTS AAC frame header, then filler).
final List<int> audioBytes = [0xFF, 0xF1, ...List.filled(1022, 7)];

void main() {
  late HttpServer server;
  late Directory dir;
  late NoticeAudioCache cache;
  var hits = 0;

  setUp(() async {
    hits = 0;
    dir = Directory.systemTemp.createTempSync('notice_cache_test');
    cache = NoticeAudioCache(directory: () async => dir);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      hits++;
      final response = request.response;
      void send(ContentType? type, List<int> body) {
        if (type != null) response.headers.contentType = type;
        response.add(body);
      }

      try {
        switch (request.uri.path) {
          case final p when p.startsWith('/missing'):
            response.statusCode = HttpStatus.forbidden;
          case '/portal':
            send(ContentType.html, utf8.encode('<html>Log in to Wi-Fi</html>'));
          case '/json':
            send(ContentType.json, utf8.encode('{"error":"expired"}'));
          case '/text':
            send(ContentType.text, utf8.encode('Access denied'));
          case '/empty':
            send(ContentType('audio', 'mpeg'), const []);
          case '/octet.m4a':
            send(ContentType.binary, audioBytes);
          case '/octet-html':
            send(ContentType.binary, utf8.encode('\n  <!DOCTYPE html>'));
          case '/untyped.mp3':
            response.headers.removeAll(HttpHeaders.contentTypeHeader);
            send(null, audioBytes);
          case '/slow':
            response.headers.contentType = ContentType('audio', 'mpeg');
            response.add(audioBytes);
            await response.flush();
            await Future<void>.delayed(const Duration(seconds: 2));
            response.add(audioBytes);
          default:
            send(ContentType('audio', 'mpeg'), audioBytes);
        }
        await response.close();
      } on Object {
        // The client hung up (timeout test).
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  List<String> filesInCache() => dir.existsSync()
      ? (dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort())
      : const [];

  test('downloads once and then serves the file by cache key', () async {
    final first = await cache.fetch(url('/a?sig=1'), 'notice-1');
    expect(first.path, endsWith('notice-1.mp3'));
    expect(first.lengthSync(), 1024);

    // A new presigned URL for the same notice does not download again.
    final second = await cache.fetch(url('/a?sig=2'), 'notice-1');
    expect(second.path, first.path);
    expect(hits, 1);
    expect((await cache.cached('notice-1'))?.path, first.path);
  });

  test('concurrent fetches share one download', () async {
    final files = await Future.wait([
      cache.fetch(url('/b'), 'notice-2'),
      cache.fetch(url('/b'), 'notice-2'),
    ]);
    expect(files[0].path, files[1].path);
    expect(hits, 1);
  });

  test('a failed download throws and leaves nothing behind', () async {
    await expectLater(
      cache.fetch(url('/missing'), 'notice-3'),
      throwsA(
        isA<NoticeAudioException>().having(
          (e) => e.statusCode,
          'statusCode',
          HttpStatus.forbidden,
        ),
      ),
    );
    expect(await cache.cached('notice-3'), isNull);
    expect(filesInCache(), isEmpty);
  });

  group('only audio is cached', () {
    for (final path in ['/portal', '/json', '/text', '/empty', '/octet-html']) {
      test('$path is rejected and downloaded again next time', () async {
        await expectLater(
          cache.fetch(url(path), 'notice-x'),
          throwsA(isA<NoticeAudioException>()),
        );
        expect(await cache.cached('notice-x'), isNull);
        expect(filesInCache(), isEmpty);
        // Not remembered as a failure either: the next fetch tries again.
        await expectLater(
          cache.fetch(url(path), 'notice-x'),
          throwsA(isA<NoticeAudioException>()),
        );
        expect(hits, 2);
      });
    }

    test('untyped and generic binary audio is kept, named by URL', () async {
      final octet = await cache.fetch(url('/octet.m4a'), 'notice-o');
      expect(octet.path, endsWith('notice-o.m4a'));
      final untyped = await cache.fetch(url('/untyped.mp3'), 'notice-u');
      expect(untyped.path, endsWith('notice-u.mp3'));
    });
  });

  test('timeout covers the whole download, body included', () async {
    final slow = NoticeAudioCache(
      directory: () async => dir,
      timeout: const Duration(milliseconds: 300),
    );
    final watch = Stopwatch()..start();
    await expectLater(
      slow.fetch(url('/slow'), 'notice-s'),
      throwsA(isA<NoticeAudioException>()),
    );
    // The headers and first bytes arrived at once; the body never finished.
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(await slow.cached('notice-s'), isNull);
    expect(filesInCache(), isEmpty);
  });

  test('remove and clear delete cached files', () async {
    await cache.fetch(url('/c'), 'notice-4');
    await cache.remove('notice-4');
    expect(await cache.cached('notice-4'), isNull);
    await cache.fetch(url('/c'), 'notice-5');
    await cache.clear();
    expect(dir.existsSync(), isFalse);
  });

  group('size cap', () {
    // Each download is 1024 bytes; two fit under 2500, three do not.
    late NoticeAudioCache capped;
    setUp(
      () =>
          capped = NoticeAudioCache(directory: () async => dir, maxBytes: 2500),
    );

    Future<void> age(String key, Duration ago) async =>
        (await capped.cached(key))!
            .setLastModifiedSync(DateTime.now().subtract(ago));

    test('evicts the least recently played files', () async {
      await capped.fetch(url('/1'), 'a');
      await capped.fetch(url('/2'), 'b');
      await age('a', const Duration(minutes: 10));
      await age('b', const Duration(minutes: 5));
      // Playing "a" again makes "b" the least recent.
      await capped.fetch(url('/1'), 'a');
      await capped.fetch(url('/3'), 'c');
      expect(filesInCache(), ['a.mp3', 'c.mp3']);
    });

    test('keeps the new file even when it alone is over the cap', () async {
      final tiny = NoticeAudioCache(directory: () async => dir, maxBytes: 100);
      await tiny.fetch(url('/1'), 'a');
      expect(filesInCache(), ['a.mp3']);
      await tiny.fetch(url('/2'), 'b');
      expect(filesInCache(), ['b.mp3']);
    });

    test('the default cap is 50 MB', () {
      expect(NoticeAudioCache().maxBytes, 50 * 1024 * 1024);
    });
  });
}
