import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'support/harness.dart';
import 'support/wireframe_text.dart' as w;

void main() {
  group('StatusPill and SeverityPill', () {
    layoutTest(
      'every tone and severity',
      () => Wrap(
        spacing: OrbitSpace.s8,
        runSpacing: OrbitSpace.s8,
        children: [
          for (final tone in OrbitStatusTone.values)
            StatusPill(label: w.checking, tone: tone),
          const SeverityPill(severity: OrbitSeverity.low, label: w.severityLow),
          const SeverityPill(
            severity: OrbitSeverity.moderate,
            label: w.severityModerate,
          ),
          const SeverityPill(severity: OrbitSeverity.high, label: 'ఎక్కువ'),
          for (final tone in OrbitTagTone.values)
            OrbitTag(label: w.noticeSource, tone: tone),
        ],
      ),
    );

    testWidgets('a pill inside a plain Row does not need Expanded', (
      tester,
    ) async {
      await pumpOrbit(
        tester,
        const Row(
          children: [
            Text(w.paid),
            Spacer(),
            StatusPill(label: w.paid, tone: OrbitStatusTone.success),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('always shows an icon next to the word', (tester) async {
      await pumpOrbit(
        tester,
        const Column(
          children: [
            StatusPill(label: w.paid, tone: OrbitStatusTone.success),
            StatusPill(label: w.checking, tone: OrbitStatusTone.warning),
            StatusPill(
              label: w.checking,
              tone: OrbitStatusTone.info,
              icon: OrbitIcons.send,
            ),
            SeverityPill(severity: OrbitSeverity.low, label: w.severityLow),
            SeverityPill(
              severity: OrbitSeverity.moderate,
              label: w.severityModerate,
            ),
            SeverityPill(severity: OrbitSeverity.high, label: 'ఎక్కువ'),
          ],
        ),
      );
      for (final icon in [
        OrbitIcons.success,
        OrbitIcons.pending,
        OrbitIcons.send,
        OrbitIcons.severityLow,
        OrbitIcons.severityModerate,
        OrbitIcons.severityHigh,
      ]) {
        expect(find.byIcon(icon), findsOneWidget, reason: '$icon');
      }
    });
  });

  group('OrbitBanner', () {
    layoutTest(
      'every kind with saved-at line and action',
      () => Column(
        children: [
          for (final kind in OrbitBannerKind.values) ...[
            OrbitBanner(
              kind: kind,
              title: w.noInternet,
              message: w.noInternetSub,
              savedAt: 'Saved at 7:00 am',
              action: TextButton(onPressed: () {}, child: const Text(w.tryNow)),
            ),
            const SizedBox(height: OrbitSpace.s8),
          ],
        ],
      ),
    );

    testWidgets('is a live region with a kind icon', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOrbit(
        tester,
        const OrbitBanner(kind: OrbitBannerKind.offline, title: w.noInternet),
      );
      expect(find.byIcon(OrbitIcons.offline), findsOneWidget);
      final node = tester.getSemantics(find.byType(OrbitBanner));
      expect(node, isSemantics(isLiveRegion: true));
      semantics.dispose();
    });
  });

  group('StageStrip', () {
    layoutTest(
      'horizontal with progress',
      () => const StageStrip(
        stages: w.stages,
        currentIndex: 3,
        progress: 137 / 170,
        progressLabel: w.calendarProgress,
        currentLabel: 'ఇప్పుడు',
        doneLabel: 'పూర్తయింది',
      ),
    );

    layoutTest(
      'vertical',
      () => const StageStrip(
        stages: w.stages,
        currentIndex: 0,
        axis: Axis.vertical,
        progressLabel: w.calendarProgress,
      ),
    );

    testWidgets('ticks done stages and marks the current one', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOrbit(
        tester,
        const StageStrip(
          stages: w.stages,
          currentIndex: 3,
          progress: 0.8,
          currentLabel: 'ఇప్పుడు',
        ),
      );
      expect(find.byIcon(OrbitIcons.check), findsNWidgets(3));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(w.stages[3])), findsOneWidget);
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp(w.stages[3])),
      );
      expect(node, isSemantics(isSelected: true, value: 'ఇప్పుడు'));
      semantics.dispose();
    });
  });
}
