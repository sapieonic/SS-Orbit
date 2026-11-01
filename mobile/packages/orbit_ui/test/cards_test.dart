import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'support/harness.dart';
import 'support/wireframe_text.dart' as w;

void main() {
  group('StateCard', () {
    layoutTest(
      'offline, no-FA and failed states',
      () => Column(
        children: [
          StateCard(
            icon: OrbitIcons.offline,
            tone: StateCardTone.warning,
            title: w.noInternet,
            subtitle: w.noInternetSub,
            message: w.noInternetNote,
            listen: ListenButton(label: w.listen, onPressed: () {}),
          ),
          const SizedBox(height: OrbitSpace.s16),
          StateCard(
            icon: OrbitIcons.people,
            tone: StateCardTone.info,
            title: w.noFa,
            subtitle: w.noFaSub,
            action: OrbitButton(
              label: w.helpline,
              secondaryLabel: w.helplineEn,
              variant: OrbitButtonVariant.call,
              onPressed: () {},
            ),
          ),
          const SizedBox(height: OrbitSpace.s16),
          StateCard(
            icon: OrbitIcons.error,
            tone: StateCardTone.danger,
            title: w.billFailed,
            subtitle: w.billFailedSub,
            action: OrbitButton(
              label: w.tryNow,
              secondaryLabel: w.tryNowEn,
              icon: OrbitIcons.refresh,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );

    testWidgets('shows one action and the listen slot', (tester) async {
      var taps = 0;
      await pumpOrbit(
        tester,
        StateCard(
          icon: OrbitIcons.visit,
          title: w.noFa,
          action: OrbitButton(label: w.helpline, onPressed: () => taps++),
          listen: ListenButton(label: w.listen, onPressed: () {}),
        ),
      );
      expect(find.text(w.noFa), findsOneWidget);
      expect(find.byType(OrbitButton), findsOneWidget);
      expect(find.byType(ListenButton), findsOneWidget);
      await tester.tap(find.byType(OrbitButton));
      expect(taps, 1);
    });
  });

  group('IconTile', () {
    layoutTest(
      'home grid with locked and badged tiles',
      () => IconTileGrid(
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
            badge: '2',
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
          const IconTile(
            icon: OrbitIcons.soilTest,
            label: w.soilTest,
            secondaryLabel: w.soilTestEn,
            locked: true,
            badge: 'FREE',
          ),
          const IconTile(icon: OrbitIcons.weather, label: w.premium),
        ],
      ),
    );

    testWidgets('locked tile shows a padlock, still taps, reads the reason', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpOrbit(
        tester,
        IconTile(
          icon: OrbitIcons.mic,
          label: w.askVoice,
          locked: true,
          lockedSemanticLabel: w.premium,
          onTap: () => taps++,
        ),
      );
      expect(find.byIcon(OrbitIcons.lock), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(w.premium)), findsOneWidget);
      await tester.tap(find.byType(IconTile));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('tiles in a row share the tallest height', (tester) async {
      await pumpOrbit(
        tester,
        const IconTileGrid(
          children: [
            IconTile(
              key: ValueKey('a'),
              icon: OrbitIcons.crop,
              label: w.cropCalendar,
            ),
            IconTile(
              key: ValueKey('b'),
              icon: OrbitIcons.mic,
              label: w.askVoice,
              secondaryLabel: w.askVoiceEn,
            ),
          ],
        ),
        textScale: 1.3,
      );
      final a = tester.getSize(find.byKey(const ValueKey('a')));
      final b = tester.getSize(find.byKey(const ValueKey('b')));
      expect(a.height, b.height);
      expect(a.height, greaterThanOrEqualTo(OrbitSize.tileMinHeight));
    });
  });

  group('FaCard', () {
    layoutTest(
      'with tag, avatar initials and both actions',
      () => Column(
        children: [
          FaCard(
            name: w.yourFa,
            initials: 'SK',
            tag: 'మీ FA',
            subtitle: w.faVerified,
            detail: w.nextVisitEn,
            verified: true,
            highlighted: true,
            callLabel: w.call,
            onCall: () {},
            whatsAppLabel: w.whatsApp,
            onWhatsApp: () {},
          ),
          const SizedBox(height: OrbitSpace.s8),
          const FaCard(name: w.yourFa, subtitle: w.faVerified),
        ],
      ),
    );

    testWidgets('call and WhatsApp buttons call back', (tester) async {
      var calls = 0;
      var chats = 0;
      await pumpOrbit(
        tester,
        FaCard(
          name: w.yourFa,
          initials: 'SK',
          callLabel: w.call,
          onCall: () => calls++,
          whatsAppLabel: w.whatsApp,
          onWhatsApp: () => chats++,
        ),
      );
      expect(find.text('SK'), findsOneWidget);
      await tester.tap(find.byIcon(OrbitIcons.phone));
      await tester.tap(find.byIcon(OrbitIcons.whatsApp));
      expect((calls, chats), (1, 1));
    });

    testWidgets('falls back to a person icon without initials or image', (
      tester,
    ) async {
      await pumpOrbit(tester, const FaCard(name: w.yourFa));
      expect(find.byIcon(OrbitIcons.person), findsOneWidget);
      expect(find.byType(OrbitButton), findsNothing);
    });
  });

  group('NoticeCard', () {
    layoutTest(
      'pinned, unread and plain notices',
      () => Column(
        children: [
          NoticeCard(
            source: w.noticeSource,
            meta: w.noticeMeta,
            title: w.noticeTitle,
            body: w.noticeBody,
            secondaryBody: w.noticeBodyEn,
            pinned: true,
            pinnedLabel: w.pinned,
            unread: true,
            unreadLabel: 'కొత్తది',
            actions: [
              ListenButton(label: w.listen, onPressed: () {}),
              OrbitButton(
                label: w.whatsApp,
                icon: OrbitIcons.whatsApp,
                variant: OrbitButtonVariant.secondary,
                size: OrbitButtonSize.medium,
                fullWidth: false,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: OrbitSpace.s8),
          const NoticeCard(source: 'CIV', title: w.noticeTitle),
        ],
      ),
    );

    testWidgets('unread dot is announced and pin tag shown', (tester) async {
      final semantics = tester.ensureSemantics();
      var opened = 0;
      await pumpOrbit(
        tester,
        NoticeCard(
          source: 'HO',
          title: w.noticeTitle,
          pinned: true,
          pinnedLabel: w.pinned,
          unread: true,
          unreadLabel: 'కొత్తది',
          onTap: () => opened++,
        ),
      );
      expect(find.bySemanticsLabel(RegExp('కొత్తది')), findsOneWidget);
      expect(find.byIcon(OrbitIcons.pin), findsOneWidget);
      await tester.tap(find.byType(NoticeCard));
      expect(opened, 1);
      semantics.dispose();
    });
  });

  group('AdviceResult', () {
    layoutTest(
      'product found and salt only',
      () => Column(
        children: [
          const AdviceResult.product(
            heading: w.productHeading,
            secondaryHeading: w.productHeadingEn,
            name: 'Sample 5 SG',
            dose: w.productDose,
          ),
          const SizedBox(height: OrbitSpace.s8),
          AdviceResult.saltOnly(
            heading: w.saltHeading,
            secondaryHeading: w.saltHeadingEn,
            name: w.saltName,
            dose: w.saltDose,
            note: w.saltNote,
            action: OrbitButton(
              label: w.callSuresh,
              variant: OrbitButtonVariant.call,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );

    testWidgets('the two kinds differ by icon, not only colour', (
      tester,
    ) async {
      await pumpOrbit(
        tester,
        const Column(
          children: [
            AdviceResult.product(heading: w.productHeading, name: 'Sample'),
            AdviceResult.saltOnly(heading: w.saltHeading, name: w.saltName),
          ],
        ),
      );
      expect(find.byIcon(OrbitIcons.productFound), findsOneWidget);
      expect(find.byIcon(OrbitIcons.shop), findsOneWidget);
      final widgets = tester.widgetList<AdviceResult>(
        find.byType(AdviceResult),
      );
      expect(widgets.map((a) => a.kind), [
        AdviceKind.product,
        AdviceKind.saltOnly,
      ]);
    });
  });
}
