import 'dart:io';

import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/features/visits/advice_screen.dart';
import 'package:farmer/src/features/visits/advice_text.dart';
import 'package:farmer/src/features/visits/dealers_section.dart';
import 'package:farmer/src/features/visits/visits_providers.dart';
import 'package:farmer/src/routing/resume_refresh.dart';
import 'package:farmer/src/shared/voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../support/harness.dart';

/// Seeded visits of Ravi (newest first).
const pinkBollwormVisit = '4ab75e76-0167-5a52-8020-cdc3c833f2dc'; // product
const leafSpotVisit = '1673bc71-79d0-59fe-96e9-7934c6df81e6'; // salt only
const whiteflyVisit = '2b836a40-793f-58d9-ad69-760ea0bd46af'; // pending
const noIssueVisit = '695f04d4-01d2-51eb-a2ce-24a6b6ce27da';

/// Competitor brands from `i18n/deny-list.txt` (Latin, whole words).
List<String> _competitorBrands() {
  final lines = File('../../../i18n/deny-list.txt').readAsLinesSync();
  final start = lines.indexOf('# Competitor brands');
  return [
    for (final line in lines.skip(start + 1).takeWhile((l) => l.isNotEmpty))
      if (!line.startsWith('#')) line.trim().toLowerCase(),
  ];
}

String _allText(WidgetTester tester) => tester.allRenderObjects
    .whereType<RenderParagraph>()
    .map((p) => p.text.toPlainText())
    .join('\n')
    .toLowerCase();

void main() {
  group('AdviceScreen', () {
    testWidgets('product advice (F8a): name, dose, call FA, dealers', (
      tester,
    ) async {
      final container = await createTestContainer();
      await pumpScreen(
        tester,
        const AdviceScreen(visitId: pinkBollwormVisit, issueIndex: 0),
        container: container,
      );

      expect(find.text('ఈ మందు కొనండి'), findsOneWidget);
      expect(find.text('సురేష్ కె గారి సలహా · 12 అక్టో'), findsOneWidget);
      expect(find.text('గులాబీ రంగు పురుగు'), findsOneWidget);
      expect(find.textContaining('మధ్యస్థం'), findsOneWidget);
      expect(findLabel('పొలం 1'), findsOneWidget);
      expect(findLabel('కాయ దశ'), findsOneWidget);
      final result = tester.widget<AdviceResult>(find.byType(AdviceResult));
      expect(result.kind, AdviceKind.product);
      expect(result.heading, 'షణ్ముఖ మందు');
      expect(result.name, 'శాంపిల్ 5 SG\nSample 5 SG');
      expect(result.dose, 'ఎకరానికి 200 లీ. నీటిలో 80 గ్రా.');
      expect(
        find.textContaining('సురేష్ కె గారికి కాల్ చేయండి'),
        findsOneWidget,
      );
      // No cashback, pack or MRP on the farmer card.
      expect(find.textContaining('₹'), findsNothing);

      await tester.scrollUntilVisible(find.text('రైతు మిత్ర ట్రేడర్స్'), 200);
      expect(find.text('దగ్గర దుకాణాలు'), findsOneWidget);
      expect(find.text('శ్రీ సాయి ఆగ్రో ట్రేడర్స్'), findsOneWidget);
      // Nearest first, each with its distance in the app language.
      expect(find.text('Sri Sai Agro Traders · 0.4 కి.మీ'), findsOneWidget);
      expect(find.text('Raithu Mitra Traders · 3.4 కి.మీ'), findsOneWidget);

      final text = _allText(tester);
      for (final brand in _competitorBrands()) {
        expect(
          RegExp('\\b${RegExp.escape(brand)}\\b').hasMatch(text),
          isFalse,
          reason: brand,
        );
      }
    });

    testWidgets('salt-only advice (F8b): ask at the shop, no dealers', (
      tester,
    ) async {
      final container = await createTestContainer();
      await pumpScreen(
        tester,
        const AdviceScreen(visitId: leafSpotVisit, issueIndex: 0),
        container: container,
      );

      expect(find.text('FA సలహా'), findsOneWidget);
      expect(find.text('సురేష్ కె గారి సలహా · 9 సెప్టెం'), findsOneWidget);
      final result = tester.widget<AdviceResult>(find.byType(AdviceResult));
      expect(result.kind, AdviceKind.saltOnly);
      expect(result.heading, 'షణ్ముఖ మందు లేదు');
      expect(result.name, 'మాంకోజెబ్ 75% WP\nMancozeb 75% WP');
      expect(
        result.note,
        'దుకాణంలో ఈ పేరు అడగండి. సందేహం ఉంటే FA కి కాల్ చేయండి.',
      );
      expect(
        find.textContaining('సురేష్ కె గారికి కాల్ చేయండి'),
        findsOneWidget,
      );
      expect(find.byType(DealersSection), findsNothing);
    });

    testWidgets('advice pending: "your FA will follow up" and call FA', (
      tester,
    ) async {
      final container = await createTestContainer();
      await pumpScreen(
        tester,
        const AdviceScreen(visitId: whiteflyVisit, issueIndex: 0),
        container: container,
      );

      expect(find.text('తెల్ల దోమ'), findsOneWidget);
      expect(
        find.text('సలహా ఇంకా రాలేదు. మీ FA తర్వాత చెబుతారు.'),
        findsOneWidget,
      );
      expect(find.byType(AdviceResult), findsNothing);
      expect(
        find.textContaining('సురేష్ కె గారికి కాల్ చేయండి'),
        findsOneWidget,
      );
      // Neither "buy this product" nor the salt card's title.
      expect(
        find.widgetWithText(ScreenHeader, te.farmerAdviceTitle),
        findsOneWidget,
      );
      expect(find.text(te.farmerAdviceSaltTitle), findsNothing);
      // Listen explains the pending advice, not the empty inbox.
      expect(
        tester
            .widget<ScreenListenButton>(find.byType(ScreenListenButton))
            .voiceKey,
        VoiceKeys.farmerAdviceVoiceHelpPending,
      );
    });

    testWidgets('a resume refresh keeps the advice on screen', (tester) async {
      final backend = testBackend();
      final container = await createTestContainer(backend: backend);
      final resume = container.read(resumeRefreshProvider);
      await pumpScreen(
        tester,
        const AdviceScreen(visitId: pinkBollwormVisit, issueIndex: 0),
        container: container,
      );
      expect(container.exists(visitsControllerProvider), isTrue);

      // Back after a while: My visits reloads, slowly.
      backend.latency = const Duration(milliseconds: 300);
      testClock.advance(ResumeRefresh.messagesInterval);
      resume.onResume();
      expect(container.read(visitsControllerProvider).isRefreshing, isTrue);
      await pumpFrames(tester, const Duration(milliseconds: 700), (when) {
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: when,
        );
        expect(find.text('ఈ మందు కొనండి'), findsOneWidget, reason: when);
        expect(find.text('గులాబీ రంగు పురుగు'), findsOneWidget, reason: when);
      });
      expect(container.read(visitsControllerProvider).isLoading, isFalse);
    });

    testWidgets('unknown visit: not found, with a way back', (tester) async {
      final container = await createTestContainer();
      await pumpScreen(
        tester,
        const AdviceScreen(visitId: 'no-such-visit', issueIndex: 0),
        container: container,
      );
      expect(find.text('ఇది దొరకలేదు. మళ్ళీ తెరిచి చూడండి.'), findsOneWidget);
      expect(find.textContaining('వెనక్కి'), findsOneWidget);
      expect(
        find.widgetWithText(ScreenHeader, te.farmerAdviceTitle),
        findsOneWidget,
      );
    });

    testWidgets('issue index outside the visit: not found', (tester) async {
      final container = await createTestContainer();
      await pumpScreen(
        tester,
        const AdviceScreen(visitId: noIssueVisit, issueIndex: 0),
        container: container,
      );
      expect(find.text('ఇది దొరకలేదు. మళ్ళీ తెరిచి చూడండి.'), findsOneWidget);
    });

    testWidgets('a visit beyond the loaded pages is fetched', (tester) async {
      final container = await createTestContainer(
        overrides: [visitsPageSizeProvider.overrideWithValue(1)],
      );
      await pumpScreen(
        tester,
        const AdviceScreen(visitId: whiteflyVisit, issueIndex: 0),
        container: container,
      );
      expect(find.text('తెల్ల దోమ'), findsOneWidget);
    });

    testWidgets('offline: one card with Try again', (tester) async {
      final container = await createTestContainer(
        scenario: MockScenario.offline,
      );
      await pumpScreen(
        tester,
        const AdviceScreen(visitId: pinkBollwormVisit, issueIndex: 0),
        container: container,
      );
      expect(find.text('ఇంటర్నెట్ లేదు'), findsOneWidget);
      expect(find.byType(OrbitButton), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      final container = await createTestContainer(language: Language.en);
      await pumpScreen(
        tester,
        const AdviceScreen(visitId: leafSpotVisit, issueIndex: 0),
        container: container,
        locale: const Locale('en'),
      );
      expect(find.text('FA advice'), findsOneWidget);
      expect(find.text('Advised by Suresh K · Sep 9'), findsOneWidget);
      expect(find.text('Leaf spot'), findsOneWidget);
      // English stage names don't carry the word, so the screen adds it.
      expect(findLabel('Flowering stage'), findsOneWidget);
      expect(findLabel('Plot 1'), findsOneWidget);
      final result = tester.widget<AdviceResult>(find.byType(AdviceResult));
      expect(result.heading, 'No Shanmukha product for this');
      expect(result.name, 'Mancozeb 75% WP\nమాంకోజెబ్ 75% WP');
      expect(find.textContaining('Call Suresh K'), findsOneWidget);
    });
  });

  group('adviceTypeOf', () {
    const base = FarmerAdvice(
      issueName: 'Leaf spot',
      issueNameTe: null,
      severity: Severity.low,
      advicePending: false,
      saltName: null,
      saltNameTe: null,
      skuId: null,
      productName: null,
      productNameTe: null,
      dose: null,
      doseTe: null,
      saltOnly: false,
    );

    FarmerAdvice advice({
      bool pending = false,
      bool saltOnly = false,
      String? product,
      String? salt,
    }) => FarmerAdvice(
      issueName: base.issueName,
      issueNameTe: base.issueNameTe,
      severity: base.severity,
      advicePending: pending,
      saltName: salt,
      saltNameTe: null,
      skuId: product == null ? null : 'sku',
      productName: product,
      productNameTe: null,
      dose: null,
      doseTe: null,
      saltOnly: saltOnly,
    );

    test('only shows what the data says', () {
      expect(adviceTypeOf(advice(pending: true)), AdviceType.pending);
      expect(adviceTypeOf(advice(product: 'Sample 5 SG')), AdviceType.product);
      expect(
        adviceTypeOf(advice(saltOnly: true, salt: 'Mancozeb')),
        AdviceType.saltOnly,
      );
      // salt_only wins over a stray product name.
      expect(
        adviceTypeOf(advice(saltOnly: true, product: 'X', salt: 'Mancozeb')),
        AdviceType.saltOnly,
      );
      // Nothing to show: treated as pending, never invented.
      expect(adviceTypeOf(base), AdviceType.pending);
      expect(adviceTypeOf(advice(saltOnly: true)), AdviceType.pending);
    });
  });

  screenLayoutTest(
    'Advice with a product',
    () => const AdviceScreen(visitId: pinkBollwormVisit, issueIndex: 0),
  );
  screenLayoutTest(
    'Advice with a salt only',
    () => const AdviceScreen(visitId: leafSpotVisit, issueIndex: 0),
  );
  screenLayoutTest(
    'Advice pending',
    () => const AdviceScreen(visitId: whiteflyVisit, issueIndex: 0),
  );
}
