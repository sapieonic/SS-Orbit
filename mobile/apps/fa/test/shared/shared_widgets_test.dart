import 'package:fa/src/data/data.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:fa/src/shared/async_view.dart';
import 'package:fa/src/shared/fa_header.dart';
import 'package:fa/src/shared/farmer_avatar.dart';
import 'package:fa/src/shared/pending_sync_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../support/harness.dart';

Widget _page(Widget header) => Scaffold(body: Column(children: [header]));

void main() {
  group('FaHeader', () {
    screenLayoutTest(
      'with back, an action, the sync pill and Me',
      () => _page(
        FaHeader(
          title: 'దగ్గరలోని రైతులు',
          subtitle: 'కొండాపూర్ · 46 రైతులు · దగ్గరి వారు ముందు',
          back: true,
          leading: const FarmerAvatar(name: 'Ravi K', outlined: true),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(OrbitIcons.search),
              color: Colors.white,
            ),
          ],
          showMe: true,
        ),
      ),
    );

    testWidgets('the sync pill reads what waits and opens Sync', (
      tester,
    ) async {
      final t = await pumpFaScreen(
        tester,
        _page(const FaHeader(title: 'Farmers')),
      );
      final queued = t.read(syncStateProvider).queuedCount;
      final label = queued == 0
          ? te.faShellSyncAllSynced
          : te.faShellSyncWaiting(count: queued);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(
        tester.getSize(find.byType(SyncPill)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byType(SyncPill));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.sync);
    });

    testWidgets("Me shows the FA's initials and opens Me", (tester) async {
      final t = await pumpFaScreen(
        tester,
        _page(const FaHeader(title: 'Farmers', showMe: true)),
      );
      expect(find.text('SK'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(te.faShellMe));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.me);
    });

    testWidgets('back pops, or goes to Farmers with nothing to pop', (
      tester,
    ) async {
      final t = await pumpFaScreen(
        tester,
        _page(const FaHeader(title: 'Sync', back: true, showSync: false)),
      );
      expect(find.byType(SyncPill), findsNothing);
      await tester.tap(find.byIcon(OrbitIcons.back));
      await tester.pumpAndSettle();
      expect(currentPath(t.router), AppRoutes.farmers);
    });

    testWidgets('onBack replaces the default back', (tester) async {
      var backs = 0;
      await pumpFaScreen(
        tester,
        _page(FaHeader(title: 'Enrol', onBack: () => backs++)),
      );
      await tester.tap(find.byIcon(OrbitIcons.back));
      expect(backs, 1);
    });

    test('the pill status follows the engine', () {
      // Conflicts and rejections outrank queued records.
      SyncPillStatus status(SyncState s) {
        final container = ProviderContainer.test(
          overrides: [syncStateProvider.overrideWithBuild((_, _) => s)],
        );
        return container.read(syncPillStatusProvider);
      }

      expect(status(const SyncState(queuedCount: 3)), (
        queued: 3,
        needsYou: 0,
        running: false,
      ));
      expect(status(const SyncState(running: true)).running, isTrue);
    });
  });

  group('FarmerAvatar', () {
    testWidgets('initials and colour by status and plan', (tester) async {
      await pumpFaScreen(
        tester,
        const Row(
          children: [
            FarmerAvatar(name: 'Raju P', status: FarmerStatus.pendingProfile),
            FarmerAvatar(name: 'Padma S', plan: Plan.premium),
            FarmerAvatar(name: 'Ravi K'),
            FarmerAvatar(name: null),
          ],
        ),
        signedIn: false,
      );
      expect(find.text('RP'), findsOneWidget);
      expect(find.text('PS'), findsOneWidget);
      expect(find.byIcon(OrbitIcons.person), findsOneWidget);
      final context = tester.element(find.text('RK'));
      final colors = OrbitColors.of(context);
      expect(
        FarmerAvatar.colorFor(
          context,
          plan: Plan.free,
          status: FarmerStatus.pendingProfile,
        ),
        colors.success.fg,
      );
      expect(
        FarmerAvatar.colorFor(
          context,
          plan: Plan.premium,
          status: FarmerStatus.active,
        ),
        isNot(
          FarmerAvatar.colorFor(
            context,
            plan: Plan.free,
            status: FarmerStatus.active,
          ),
        ),
      );
    });
  });

  testWidgets('PendingSyncTag says "Not synced yet"', (tester) async {
    await pumpFaScreen(
      tester,
      const Center(child: PendingSyncTag()),
      signedIn: false,
      locale: const Locale('en'),
    );
    expect(statusPill(en.faCommonNotSynced), findsOneWidget);
  });

  group('ErrorStateCard', () {
    testWidgets('offline: the offline card with Try again', (tester) async {
      var retries = 0;
      await pumpFaScreen(
        tester,
        Scaffold(
          body: ErrorStateCard(
            error: const ApiError.network(),
            onRetry: () => retries++,
          ),
        ),
        signedIn: false,
      );
      expect(find.text(te.faCommonOfflineTitle), findsOneWidget);
      await tester.tap(orbitButton(te.commonRetry));
      expect(retries, 1);
      expect(find.text(te.faCommonLogOut), findsNothing);
    });

    testWidgets('an API error by its code, never the server message', (
      tester,
    ) async {
      await pumpFaScreen(
        tester,
        Scaffold(
          body: ErrorStateCard(
            error: const ApiError(
              code: ApiErrorCode.notFound,
              message: 'farmer 7 not found',
              status: 404,
            ),
            onRetry: () {},
          ),
        ),
        signedIn: false,
      );
      expect(find.text(te.errorNotFound), findsOneWidget);
      expect(find.textContaining('farmer 7'), findsNothing);
    });

    testWidgets('a session error also offers Log out', (tester) async {
      final t = await pumpFaScreen(
        tester,
        Scaffold(
          body: ErrorStateCard(
            error: const ApiError(
              code: ApiErrorCode.unauthorized,
              message: 'expired',
              status: 401,
            ),
            onRetry: () {},
          ),
        ),
      );
      await tester.tap(find.text(te.faCommonLogOut));
      await tester.pumpAndSettle();
      expect(t.phase, SessionPhase.signedOut);
    });
  });
}
