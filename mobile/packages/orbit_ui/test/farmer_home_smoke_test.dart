import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'support/harness.dart';
import 'support/wireframe_text.dart' as w;

/// F2 Home assembled only from orbit_ui pieces, as a screen builder would.
Widget _home() => Scaffold(
  floatingActionButton: ListenButton.floating(
    label: w.listen,
    onPressed: () {},
  ),
  bottomNavigationBar: OrbitNavigationBar(
    selectedIndex: 0,
    onDestinationSelected: (_) {},
    destinations: [
      for (final (icon, label) in [
        (OrbitIcons.home, w.tabs[0]),
        (OrbitIcons.visit, w.tabs[1]),
        (OrbitIcons.notice, w.tabs[2]),
        (OrbitIcons.wallet, w.tabs[3]),
      ])
        OrbitNavigationDestination(icon: icon, label: label),
    ],
  ),
  body: Column(
    children: [
      const ScreenHeader(
        title: w.greeting,
        subtitle: w.greetingSub,
        tone: ScreenHeaderTone.primary,
        trailing: OrbitTag(label: 'FREE', tone: OrbitTagTone.highlight),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(OrbitSpace.s16),
          children: [
            const OrbitBanner(
              kind: OrbitBannerKind.offline,
              title: w.noInternet,
              savedAt: 'Saved at 7:00 am',
            ),
            const SizedBox(height: OrbitSpace.s12),
            const FaCard(
              name: w.yourFa,
              initials: 'SK',
              subtitle: w.faVerified,
              verified: true,
              highlighted: true,
            ),
            const SizedBox(height: OrbitSpace.s12),
            OrbitButton(
              label: w.callSuresh,
              secondaryLabel: w.callSureshEn,
              variant: OrbitButtonVariant.call,
              size: OrbitButtonSize.hero,
              onPressed: () {},
            ),
            const SizedBox(height: OrbitSpace.s12),
            const InfoRow(
              icon: OrbitIcons.visit,
              text: w.nextVisit,
              secondaryText: w.nextVisitEn,
            ),
            const SizedBox(height: OrbitSpace.s16),
            IconTileGrid(
              children: [
                IconTile(
                  icon: OrbitIcons.cropCalendar,
                  label: w.cropCalendar,
                  secondaryLabel: w.cropCalendarEn,
                  onTap: () {},
                ),
                IconTile(
                  icon: OrbitIcons.pests,
                  label: w.pests,
                  secondaryLabel: w.pestsEn,
                  onTap: () {},
                ),
                IconTile(
                  icon: OrbitIcons.mic,
                  label: w.askVoice,
                  secondaryLabel: w.askVoiceEn,
                  locked: true,
                  lockedSemanticLabel: w.premium,
                  onTap: () {},
                ),
                IconTile(
                  icon: OrbitIcons.soilTest,
                  label: w.soilTest,
                  secondaryLabel: w.soilTestEn,
                  locked: true,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);

void main() {
  for (final scale in textScales) {
    for (final (name, theme) in [
      ('farmer', OrbitTheme.farmer),
      ('fa', OrbitTheme.fa),
    ]) {
      testWidgets('home screen ($name theme) at text scale $scale', (
        tester,
      ) async {
        await pumpOrbit(
          tester,
          _home(),
          theme: theme(),
          textScale: scale,
          scroll: false,
        );
        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
        // Scroll to the end: the last tiles also lay out cleanly.
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
      });
    }
  }
}
