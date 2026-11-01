import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/orbit_ui.dart';

import 'support/harness.dart';
import 'support/wireframe_text.dart' as w;

void main() {
  group('ScreenHeader', () {
    layoutTest(
      'every tone with back, listen and subtitle',
      () => Column(
        children: [
          for (final tone in ScreenHeaderTone.values)
            ScreenHeader(
              title: w.calendarTitle,
              subtitle: w.calendarProgress,
              tone: tone,
              onBack: () {},
              listen: ListenButton(label: w.listen, onPressed: () {}),
            ),
          ScreenHeader(
            title: w.greeting,
            subtitle: w.greetingSub,
            trailing: const OrbitTag(
              label: 'FREE',
              tone: OrbitTagTone.highlight,
            ),
            listen: ListenButton(label: w.listen, onPressed: () {}),
          ),
        ],
      ),
    );

    // A long Listen label ("this audio isn't available yet") used to take
    // the row and squeeze the title to a few letters per line.
    const longListen = 'ఈ ఆడియో ఇంకా అందుబాటులో లేదు';
    layoutTest(
      'long listen and trailing labels',
      () => ScreenHeader(
        title: w.calendarTitle,
        subtitle: w.calendarProgress,
        onBack: () {},
        trailing: const OrbitTag(
          label: w.premium,
          tone: OrbitTagTone.highlight,
        ),
        listen: ListenButton(label: longListen, onPressed: () {}),
      ),
    );

    for (final scale in textScales) {
      testWidgets('a long listen label leaves the title room at $scale', (
        tester,
      ) async {
        await pumpOrbit(
          tester,
          ScreenHeader(
            title: w.calendarTitle,
            onBack: () {},
            listen: ListenButton(label: longListen, onPressed: () {}),
          ),
          textScale: scale,
          scroll: false,
        );
        final header = tester.getSize(find.byType(ScreenHeader)).width;
        final listen = tester.getSize(find.byType(ListenButton)).width;
        // The title's column (it wraps inside it).
        final title = tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(w.calendarTitle),
                    matching: find.byType(Column),
                  )
                  .first,
            )
            .width;
        expect(listen, lessThanOrEqualTo(header * 0.4));
        expect(title, greaterThan(header * 0.4));
        // The label wraps inside its button instead of being cut.
        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
      });
    }

    testWidgets('a short listen label keeps its natural width', (tester) async {
      await pumpOrbit(
        tester,
        Align(
          child: ListenButton(label: w.listen, onPressed: () {}),
        ),
        scroll: false,
      );
      final alone = tester.getSize(find.byType(ListenButton)).width;
      await pumpOrbit(
        tester,
        ScreenHeader(
          title: w.calendarTitle,
          listen: ListenButton(label: w.listen, onPressed: () {}),
        ),
        scroll: false,
      );
      expect(tester.getSize(find.byType(ListenButton)).width, alone);
    });

    testWidgets('title is a header; back uses the localised tooltip', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var back = 0;
      await pumpOrbit(
        tester,
        ScreenHeader(title: w.advisoryTitle, onBack: () => back++),
      );
      expect(
        tester.getSemantics(find.text(w.advisoryTitle)),
        isSemantics(isHeader: true),
      );
      final button = tester.widget<IconButton>(find.byType(IconButton));
      final context = tester.element(find.byType(ScreenHeader));
      expect(
        button.tooltip,
        MaterialLocalizations.of(context).backButtonTooltip,
      );
      await tester.tap(find.byType(IconButton));
      expect(back, 1);
      semantics.dispose();
    });

    testWidgets('uses the app screen-title style', (tester) async {
      await pumpOrbit(tester, const ScreenHeader(title: w.advisoryTitle));
      expect(
        tester.widget<Text>(find.text(w.advisoryTitle)).style!.fontSize,
        26,
      );
      await pumpOrbit(
        tester,
        const ScreenHeader(title: w.advisoryTitle),
        theme: OrbitTheme.fa(),
      );
      expect(
        tester.widget<Text>(find.text(w.advisoryTitle)).style!.fontSize,
        22,
      );
    });

    for (final (theme, build) in [
      ('farmer', OrbitTheme.farmer),
      ('FA', OrbitTheme.fa),
    ]) {
      testWidgets('status bar icons contrast with every tone ($theme)', (
        tester,
      ) async {
        for (final (tone, iconBrightness) in const [
          (ScreenHeaderTone.surface, Brightness.dark),
          (ScreenHeaderTone.primary, Brightness.light),
          (ScreenHeaderTone.inverse, Brightness.light),
        ]) {
          await pumpOrbit(
            tester,
            ScreenHeader(title: w.advisoryTitle, tone: tone),
            theme: build(),
            scroll: false,
          );
          final style = tester
              .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                find.descendant(
                  of: find.byType(ScreenHeader),
                  matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
                ),
              )
              .value;
          expect(
            style.statusBarIconBrightness,
            iconBrightness,
            reason: '$tone',
          );
          // iOS names the bar's brightness, the opposite of its icons.
          expect(
            style.statusBarBrightness,
            iconBrightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            reason: '$tone',
          );
          // The navigation bar is left to the app.
          expect(style.systemNavigationBarColor, isNull);
          expect(style.systemNavigationBarIconBrightness, isNull);

          // A header at the top of the screen is what the framework applies.
          await tester.pump();
          expect(
            SystemChrome.latestStyle?.statusBarIconBrightness,
            iconBrightness,
            reason: '$tone',
          );
        }
      });
    }
  });

  group('SectionHeader', () {
    layoutTest(
      'with inline secondary and trailing',
      () => SectionHeader(
        title: w.soilTestSection,
        secondary: w.soilTestSectionEn,
        trailing: TextButton(onPressed: () {}, child: const Text(w.tryNow)),
      ),
    );

    testWidgets('is announced as a header', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOrbit(tester, const SectionHeader(title: w.upcomingTasks));
      expect(
        tester.getSemantics(find.bySemanticsLabel(w.upcomingTasks)),
        isSemantics(isHeader: true, label: w.upcomingTasks),
      );
      semantics.dispose();
    });
  });

  group('OrbitNavigationBar', () {
    Widget bar({int selected = 0, ValueChanged<int>? onTap}) => Align(
      alignment: Alignment.bottomCenter,
      child: OrbitNavigationBar(
        selectedIndex: selected,
        onDestinationSelected: onTap ?? (_) {},
        destinations: [
          const OrbitNavigationDestination(
            icon: OrbitIcons.home,
            label: 'హోమ్',
          ),
          const OrbitNavigationDestination(
            icon: OrbitIcons.visit,
            label: 'సందర్శనలు',
          ),
          const OrbitNavigationDestination(
            icon: OrbitIcons.notice,
            label: 'సలహాలు',
            badge: '3',
          ),
          const OrbitNavigationDestination(
            icon: OrbitIcons.wallet,
            label: 'వాలెట్',
          ),
        ],
      ),
    );

    for (final scale in textScales) {
      testWidgets('four Telugu tabs fit at text scale $scale', (tester) async {
        await pumpOrbit(tester, bar(), textScale: scale, scroll: false);
        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
        for (final label in w.tabs) {
          expect(find.text(label), findsOneWidget);
        }
      });
    }

    testWidgets('reports taps and shows labels on every tab', (tester) async {
      int? tapped;
      await pumpOrbit(tester, bar(onTap: (i) => tapped = i), scroll: false);
      await tester.tap(find.text('వాలెట్'));
      expect(tapped, 3);
      expect(find.text('3'), findsOneWidget);
      final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        Theme.of(tester.element(find.byType(NavigationBar)))
            .navigationBarTheme
            .labelBehavior,
        NavigationDestinationLabelBehavior.alwaysShow,
      );
      expect(nav.height, greaterThanOrEqualTo(80));
    });
  });

  group('InfoRow, KeyValueRow and BilingualText', () {
    layoutTest(
      'rows',
      () => const Column(
        children: [
          InfoRow(
            icon: OrbitIcons.visit,
            text: w.nextVisit,
            secondaryText: w.nextVisitEn,
            trailing: StatusPill(label: w.paid, tone: OrbitStatusTone.success),
          ),
          KeyValueRow(label: w.service, value: w.soilTest),
          KeyValueRow(
            label: w.day,
            value: w.dayValue,
            secondaryValue: 'Thu 30 Oct',
          ),
          BilingualText(w.consentOk, secondary: w.consentOkEn),
          BilingualText(
            w.consentOk,
            secondary: w.consentOkEn,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    testWidgets('BilingualText sets the English line one step smaller', (
      tester,
    ) async {
      await pumpOrbit(
        tester,
        const BilingualText(w.callSuresh, secondary: w.callSureshEn),
      );
      final te = tester.widget<Text>(find.text(w.callSuresh)).style!;
      final en = tester.widget<Text>(find.text(w.callSureshEn)).style!;
      expect(te.fontSize, 16);
      expect(te.fontWeight, FontWeight.w700);
      expect(en.fontSize, 13);
    });
  });

  group('StepLayout and StepQuestion', () {
    Widget step({String? subtitle}) => StepLayout(
      title: w.newPlot,
      subtitle: subtitle,
      step: 2,
      totalSteps: 3,
      stepLabel: w.stepOf,
      onBack: () {},
      listen: ListenButton(label: w.listen, onPressed: () {}),
      action: OrbitButton(
        label: w.next,
        size: OrbitButtonSize.hero,
        onPressed: () {},
      ),
      child: Column(
        children: [
          const StepQuestion(w.whichCrop, helper: w.whichCropHelp),
          for (final crop in [w.cotton, w.paddy])
            ChoiceTile(label: crop, selected: false, onTap: () {}),
        ],
      ),
    );

    for (final scale in textScales) {
      testWidgets('a step fits 360x640 at text scale $scale', (tester) async {
        await pumpOrbit(
          tester,
          step(subtitle: w.plotStep),
          textScale: scale,
          scroll: false,
        );
        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
      });
    }

    testWidgets('shows the step, its progress and the pinned action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpOrbit(tester, step(), scroll: false);
      // Without a subtitle the header shows the step label.
      expect(find.widgetWithText(ScreenHeader, w.stepOf), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(2 / 3, 0.001));
      expect(progress.semanticsLabel, w.stepOf);
      expect(
        tester.getSemantics(find.text(w.whichCrop)),
        isSemantics(isHeader: true),
      );
      // The action stays at the bottom, outside the scrolling content.
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(OrbitButton),
        ),
        findsNothing,
      );
      expect(
        tester.getBottomLeft(find.byType(OrbitButton)).dy,
        greaterThan(phone.height - OrbitSize.controlXxl - OrbitSpace.s24),
      );
      semantics.dispose();
    });

    testWidgets('a subtitle replaces the step label in the header', (
      tester,
    ) async {
      await pumpOrbit(tester, step(subtitle: w.plotStep), scroll: false);
      expect(find.text(w.plotStep), findsOneWidget);
      expect(find.text(w.stepOf), findsNothing);
    });
  });

  group('LoadMoreFooter', () {
    layoutTest(
      'error with retry',
      () => LoadMoreFooter(
        loading: false,
        errorText: w.noInternetError,
        loadingLabel: w.loading,
        retryLabel: w.retry,
        onLoadMore: () {},
      ),
    );

    testWidgets('asks for the next page once when built', (tester) async {
      final semantics = tester.ensureSemantics();
      var asked = 0;
      await pumpOrbit(
        tester,
        LoadMoreFooter(
          loading: false,
          loadingLabel: w.loading,
          retryLabel: w.retry,
          onLoadMore: () => asked++,
        ),
      );
      await tester.pump();
      expect(asked, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel(w.loading), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('after an error it waits for Try again', (tester) async {
      var asked = 0;
      await pumpOrbit(
        tester,
        LoadMoreFooter(
          loading: false,
          errorText: w.noInternetError,
          loadingLabel: w.loading,
          retryLabel: w.retry,
          onLoadMore: () => asked++,
        ),
      );
      await tester.pump();
      expect(asked, 0);
      expect(find.text(w.noInternetError), findsOneWidget);
      await tester.tap(find.byType(OrbitButton));
      expect(asked, 1);
    });
  });
}
