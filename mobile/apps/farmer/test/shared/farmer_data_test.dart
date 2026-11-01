import 'dart:async';

import 'package:farmer/src/features/farm/farm_providers.dart';
import 'package:farmer/src/shared/async_view.dart';
import 'package:farmer/src/shared/farmer_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';

import '../support/harness.dart';

/// The farmer the test signs in, without a session.
final _farmer = NotifierProvider<_Farmer, String?>(_Farmer.new);

class _Farmer extends Notifier<String?> {
  @override
  String? build() => 'ravi';

  void signIn(String? farmerId) => state = farmerId;
}

/// Loads of [_list], in order; the test completes each.
final _loads = <Completer<String>>[];

/// A farmer-scoped list whose loads the test answers.
final _list = FutureProvider<String>(
  (ref) => loadFarmerData(ref, 'list', () {
    final load = Completer<String>();
    _loads.add(load);
    return load.future;
  }),
);

/// A detail on [_list], like a notice on the inbox.
final _detail = FutureProvider<String>(
  (ref) => loadFarmerData(
    ref,
    'detail',
    () async => 'detail of ${await followFarmerData(ref, _list.future)}',
  ),
);

const _offline = ApiError.network();

void main() {
  setUp(_loads.clear);

  ProviderContainer container({
    Duration? Function(int retryCount, Object error)? retry,
  }) {
    final c = ProviderContainer.test(
      overrides: [
        currentFarmerIdProvider.overrideWith((ref) => ref.watch(_farmer)),
      ],
      retry: retry ?? (_, _) => null,
    );
    c.listen(_list, (_, _) {});
    return c;
  }

  AsyncValue<String> fresh(ProviderContainer c, [Object? of]) =>
      c.read(of == null ? _list : _detail).fresh;

  /// Answers [c]'s current load of the list with [value] and lets it land.
  Future<void> answer(ProviderContainer c, String value) async {
    c.read(_list); // starts the load when it is due
    _loads.last.complete(value);
    await pumpEventQueue();
  }

  /// Fails [c]'s current load of the list with [error] and lets it land.
  Future<void> fail(ProviderContainer c, [Object error = _offline]) async {
    c.read(_list);
    _loads.last.completeError(error);
    await pumpEventQueue();
  }

  test(
    'a refresh, and a refresh that failed, keep the farmer\'s data',
    () async {
      final c = container();
      await answer(c, 'ravi 1');

      c.invalidate(_list);
      expect(fresh(c).isRefreshing, isTrue);
      expect(fresh(c).value, 'ravi 1');

      await fail(c);
      expect(fresh(c).error, isA<ApiError>());
      expect(fresh(c).value, 'ravi 1');

      // Trying again keeps it too.
      c.invalidate(_list);
      expect(fresh(c).value, 'ravi 1');
      await answer(c, 'ravi 2');
      expect(fresh(c), const AsyncData('ravi 2'));
    },
  );

  test(
    'another farmer never sees the data: loading, failed, retried',
    () async {
      final c = container();
      await answer(c, 'ravi 1');

      c.read(_farmer.notifier).signIn('venkatesh');
      expect(c.read(_list).value, 'ravi 1', reason: 'Riverpod keeps it');
      expect(fresh(c), isA<AsyncLoading<String>>());
      expect(fresh(c).hasValue, isFalse);

      await fail(c);
      expect(fresh(c).hasValue, isFalse);
      expect(fresh(c).error, isA<ApiError>());

      c.invalidate(_list);
      expect(fresh(c).isLoading, isTrue);
      expect(fresh(c).hasValue, isFalse);
      await fail(c);
      expect(fresh(c).hasValue, isFalse);

      c.invalidate(_list);
      await answer(c, 'venkatesh 1');
      expect(fresh(c), const AsyncData('venkatesh 1'));

      // From here on it is his data: a failed refresh keeps it.
      c.invalidate(_list);
      await fail(c);
      expect(fresh(c).value, 'venkatesh 1');
    },
  );

  test('a failed refresh still on screen is dropped when another farmer '
      'signs in', () async {
    final c = container();
    await answer(c, 'ravi 1');
    c.invalidate(_list);
    await fail(c);
    expect(fresh(c).value, 'ravi 1');

    c.read(_farmer.notifier).signIn(null);
    c.read(_farmer.notifier).signIn('venkatesh');
    expect(fresh(c).hasValue, isFalse);
  });

  test('while Riverpod retries a failed refresh the data stays, until '
      'another farmer signs in', () async {
    final c = container(retry: (_, _) => const Duration(hours: 1));
    await answer(c, 'ravi 1');

    c.invalidate(_list);
    await fail(c);
    final retrying = c.read(_list);
    expect(retrying.retrying, isTrue);
    expect(retrying.isReloading, isTrue, reason: 'it looks like a reload');
    expect(fresh(c).value, 'ravi 1');

    c.read(_farmer.notifier).signIn('venkatesh');
    expect(fresh(c).hasValue, isFalse);
    c.dispose();
  });

  test('a dev-menu data reset counts as another scope', () async {
    final c = container();
    await answer(c, 'ravi 1');
    c.read(farmerDataGenerationProvider.notifier).bump();
    expect(fresh(c).hasValue, isFalse);
    await fail(c);
    expect(fresh(c).hasValue, isFalse);
  });

  test(
    'a detail refreshes with its list and keeps its data meanwhile',
    () async {
      final c = container()..listen(_detail, (_, _) {});
      await answer(c, 'ravi 1');
      expect(fresh(c, _detail), const AsyncData('detail of ravi 1'));

      // The list reloads (a resume): the detail refreshes, it does not reload.
      c.invalidate(_list);
      expect(c.read(_detail).isReloading, isFalse);
      expect(fresh(c, _detail).value, 'detail of ravi 1');
      await fail(c);
      expect(fresh(c, _detail).value, 'detail of ravi 1');
      expect(fresh(c, _detail).error, isA<ApiError>());

      c.invalidate(_list);
      await answer(c, 'ravi 2');
      expect(fresh(c, _detail), const AsyncData('detail of ravi 2'));

      // Another farmer: the detail goes too.
      c.read(_farmer.notifier).signIn('venkatesh');
      expect(fresh(c, _detail).hasValue, isFalse);
      await answer(c, 'venkatesh 1');
      expect(fresh(c, _detail), const AsyncData('detail of venkatesh 1'));
    },
  );

  test('the plot pin stays while Home refreshes on a new day', () async {
    final backend = testBackend();
    final c = await createTestContainer(backend: backend);
    c.listen(plotPinProvider, (_, _) {});
    final pin = await c.read(plotPinProvider.future);
    expect(pin, isNotNull);

    backend.latency = const Duration(milliseconds: 50);
    c.invalidate(farmerHomeProvider);
    expect(c.read(plotPinProvider).fresh.value, pin);
    await c.read(farmerHomeProvider.future);
    await c.read(plotPinProvider.future);
    expect(c.read(plotPinProvider).fresh.value, pin);
  });
}
