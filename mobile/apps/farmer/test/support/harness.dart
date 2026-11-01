/// Test harness for every Farmer app test: containers over a fresh mock
/// backend, pumping screens (alone, inside a router, or the whole app) as the
/// app shows them, fakes for the phone's apps and the voice player, and
/// finders for Orbit widgets.
library;

import 'dart:async';
import 'dart:io';

import 'package:farmer/src/app.dart';
import 'package:farmer/src/data/data.dart';
import 'package:farmer/src/routing/routes.dart';
import 'package:farmer/src/shared/launch.dart';
import 'package:farmer/src/shared/voice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';
import 'package:orbit_voice/orbit_voice.dart';

// ---------------------------------------------------------------------------
// Fixed data.

/// Seeded farmer with an FA, visits and notices (mock and dev seed).
const raviPhone = '9000000101';

/// Second seeded farmer (paddy, no visits), for farmer-switch tests.
const venkateshPhone = '9000000102';

/// A number the mock doesn't know: verifying it is a new self sign-up.
const newPhone = '9876543210';

/// The fixed dev OTP the mock accepts.
const devOtp = '123456';

/// "Now" when every test starts: 1 Nov 2026, 10:30 IST.
final testStart = DateTime.utc(2026, 11, 1, 5);

/// A new clock at [testStart].
FixedClock newTestClock() => FixedClock(testStart);

FixedClock? _testClock;

/// The current test's clock, at [testStart] when the test starts. The app,
/// [testBackend] and the test share it within one test (advance it to move
/// time for all of them); the next test gets a new one, so no test sees
/// another's changes. Read outside a test (e.g. while declaring a group), it
/// is a new clock each time. In `setUpAll` it lasts for the group.
FixedClock get testClock {
  final current = _testClock;
  if (current != null) return current;
  final clock = newTestClock();
  try {
    addTearDown(() => _testClock = null);
  } on StateError {
    return clock; // not inside a test
  }
  return _testClock = clock;
}

/// The design frame: a 360 x 640 dp phone.
const phone = Size(360, 640);

/// Text scales screen layout tests run at (Android 100% and 130%).
const textScales = [1.0, 1.3];

/// Telugu strings, as the screens show them.
final te = lookupOrbitLocalizations(const Locale('te'));

/// English strings, as the screens show them.
final en = lookupOrbitLocalizations(const Locale('en'));

// ---------------------------------------------------------------------------
// Containers.

/// A fresh mock backend with no latency on the test clock. Keep it to switch
/// the scenario mid-test.
MockBackend testBackend() =>
    MockBackend(clock: testClock, latency: Duration.zero);

ProviderContainer _container(
  MockBackend backend,
  VoicePlayer? voice,
  ContactLauncher? launcher,
  List<Override> overrides, {
  Clock? clock,
  SessionStore? store,
}) => ProviderContainer.test(
  overrides: [
    ...farmerDataOverrides(
      env: OrbitEnv.devMock,
      store: store ?? InMemorySessionStore(),
      mockBackend: backend,
    ),
    clockProvider.overrideWithValue(clock ?? testClock),
    voicePlayerProvider.overrideWithValue(voice ?? SilentVoicePlayer()),
    contactLauncherProvider.overrideWithValue(
      launcher ?? FakeContactLauncher(),
    ),
    ...overrides,
  ],
  retry: (_, _) => null,
);

/// A test container over a fresh, zero-latency mock backend (or [backend]).
///
/// [signedIn] signs [phoneNumber] (Ravi) in first, through the real session
/// controller, so screens see an active farmer. [language] is chosen before
/// sign-in, like the language chips on F1. [scenario] is applied after
/// sign-in, so `offline` doesn't block signing in. [voice] replaces the
/// silent voice player and [launcher] the [FakeContactLauncher] (no test
/// opens the phone's apps); [overrides] are added last (page sizes, fakes).
/// [clock] replaces [testClock] for the app (give [backend] the same one)
/// and [store] the empty in-memory session store.
Future<ProviderContainer> createTestContainer({
  bool signedIn = true,
  String phoneNumber = raviPhone,
  MockScenario scenario = MockScenario.normal,
  MockBackend? backend,
  Language language = Language.te,
  VoicePlayer? voice,
  ContactLauncher? launcher,
  List<Override> overrides = const [],
  Clock? clock,
  SessionStore? store,
}) async {
  final mock = backend ?? testBackend();
  final container = _container(
    mock,
    voice,
    launcher,
    overrides,
    clock: clock,
    store: store,
  );
  final session = container.read(sessionProvider.notifier);
  await session.restored;
  if (language != Language.te) await session.setLanguage(language);
  if (signedIn) {
    await session.requestOtp(phoneNumber);
    await session.verifyOtp(devOtp);
  }
  mock.scenario = scenario;
  return container;
}

/// A container whose session is already in [phase], over a fresh
/// zero-latency mock (or [backend]).
///
/// Sign-up phases use [newPhone] (the Kondapur village); `active` and
/// `inactive` sign Ravi in. [scenario] is applied once the phase is reached
/// (except `inactive`, which needs `accountPaused` first). [voice],
/// [launcher] and [overrides] as in [createTestContainer].
///
/// Not for [SessionPhase.restoring], which the session leaves on its own:
/// read `sessionProvider` of a new container before awaiting `restored`.
Future<ProviderContainer> createContainerAt(
  SessionPhase phase, {
  MockScenario scenario = MockScenario.normal,
  MockBackend? backend,
  VoicePlayer? voice,
  ContactLauncher? launcher,
  List<Override> overrides = const [],
}) async {
  if (phase == SessionPhase.restoring) {
    throw ArgumentError.value(phase, 'phase', 'is left before this returns');
  }
  final mock = backend ?? testBackend();
  final container = _container(mock, voice, launcher, overrides);
  final session = container.read(sessionProvider.notifier);
  await session.restored;

  Future<void> signIn(String phone) async {
    await session.requestOtp(phone);
    await session.verifyOtp(devOtp);
  }

  switch (phase) {
    case SessionPhase.restoring:
    case SessionPhase.signedOut:
      break;
    case SessionPhase.otpSent:
      await session.requestOtp(newPhone);
    case SessionPhase.needsConsent:
      await signIn(newPhone);
    case SessionPhase.needsVillage:
      await signIn(newPhone);
      await session.giveConsent();
    case SessionPhase.needsName:
      await signIn(newPhone);
      await session.giveConsent();
      session.pickVillage(await kondapur(container));
    case SessionPhase.active:
      await signIn(raviPhone);
    case SessionPhase.inactive:
      mock.scenario = MockScenario.accountPaused;
      await signIn(raviPhone);
  }
  expect(phaseOf(container), phase);
  if (phase != SessionPhase.inactive) mock.scenario = scenario;
  return container;
}

/// Signs up a new farmer in Kondapur (FA Suresh, no plots yet) through the
/// real session flow.
Future<ProviderContainer> createNewFarmerContainer() async {
  final container = await createTestContainer(phoneNumber: '9000000199');
  final session = container.read(sessionProvider.notifier);
  await session.giveConsent();
  session.pickVillage(await kondapur(container));
  await session.completeProfile(name: 'Ramu', nameTe: 'రాము');
  expect(phaseOf(container), SessionPhase.active);
  return container;
}

/// The seeded Kondapur village.
Future<Village> kondapur(ProviderContainer container) async =>
    (await container
            .read(geoRepositoryProvider)
            .searchVillages(query: 'Kondapur'))
        .single;

/// The current session phase.
SessionPhase phaseOf(ProviderContainer container) =>
    container.read(sessionProvider).phase;

// ---------------------------------------------------------------------------
// Fakes.

/// Records dialer and WhatsApp launches instead of opening apps.
class FakeContactLauncher implements ContactLauncher {
  /// [opens] is what every launch returns (false: no dialer, no WhatsApp).
  FakeContactLauncher({this.opens = true});

  /// What every launch returns.
  bool opens;

  /// Numbers the dialer was opened with.
  final calls = <String>[];

  /// Numbers a WhatsApp chat was opened with.
  final whatsApps = <String>[];

  /// The pre-filled text of each WhatsApp chat, in order.
  final whatsAppTexts = <String?>[];

  @override
  Future<bool> call(String phone) async {
    calls.add(phone);
    return opens;
  }

  @override
  Future<bool> whatsApp(String phone, {String? text}) async {
    whatsApps.add(phone);
    whatsAppTexts.add(text);
    return opens;
  }
}

/// A voice player the test drives: it records what was asked and plays it,
/// then the test says whether the audio finished ([complete]) or failed
/// ([fail]).
class FakeVoicePlayer implements VoicePlayer {
  final ValueNotifier<VoicePlayerState> _state = ValueNotifier(
    const VoiceIdle(),
  );
  final StreamController<String> _completed = StreamController.broadcast();

  /// Prompt keys asked for, in order.
  final played = <String>[];

  /// Every `playUrl` call: (url, cacheKey).
  final urlsPlayed = <(Uri, String)>[];

  @override
  ValueListenable<VoicePlayerState> get state => _state;

  @override
  Stream<String> get completed => _completed.stream;

  @override
  Future<void> playPrompt(String key) async {
    played.add(key);
    _state.value = VoicePlaying(key);
  }

  @override
  Future<void> playUrl(Uri url, {required String cacheKey}) async {
    urlsPlayed.add((url, cacheKey));
    _state.value = VoicePlaying(cacheKey);
  }

  @override
  Future<void> stop() async => _state.value = const VoiceIdle();

  /// How many times the cached notice audio was cleared.
  int cacheClears = 0;

  @override
  Future<void> clearCache() async => cacheClears++;

  /// The audio for [key] (default: the one playing) played to the end.
  void complete([String? key]) {
    final done = key ?? _state.value.key!;
    _state.value = const VoiceIdle();
    _completed.add(done);
  }

  /// The download or playback for [key] failed with [error] (default: the
  /// host could not be reached).
  void fail(String key, [Object? error]) =>
      _state.value = VoiceError(key, error ?? Exception('unreachable host'));

  @override
  Future<void> dispose() async {
    await _completed.close();
    _state.dispose();
  }
}

// ---------------------------------------------------------------------------
// Pumping.

bool _fontsLoaded = false;

/// Loads orbit_ui's bundled fonts so layout tests measure real Telugu
/// shaping instead of the test font's boxes.
Future<void> loadOrbitFonts() async {
  if (_fontsLoaded) return;
  const dir = '../../packages/orbit_ui/fonts';
  const families = {
    'packages/orbit_ui/Figtree': [
      'Figtree-Regular',
      'Figtree-Medium',
      'Figtree-Bold',
      'Figtree-ExtraBold',
    ],
    'packages/orbit_ui/Noto Sans Telugu': [
      'NotoSansTelugu-Regular',
      'NotoSansTelugu-Medium',
      'NotoSansTelugu-Bold',
      'NotoSansTelugu-ExtraBold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('$dir/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

Future<void> _setUpPhone(WidgetTester tester) async {
  await loadOrbitFonts();
  tester.view
    ..physicalSize = phone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _scaled(BuildContext context, Widget? child, double textScale) =>
    MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    );

/// Pumps [screen] as the app shows it: farmer theme, Orbit localisations in
/// [locale] (Telugu by default), [textScale], on a 360 x 640 phone with the
/// real fonts, over [container].
///
/// For screens that navigate, use [pumpRouter] or [pumpRouted]; for the
/// whole app, [pumpFarmerApp].
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required ProviderContainer container,
  Locale locale = const Locale('te'),
  double textScale = 1.0,
}) async {
  await _setUpPhone(tester);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: OrbitTheme.farmer(),
        themeAnimationDuration: Duration.zero,
        locale: locale,
        supportedLocales: OrbitLocalizations.supportedLocales,
        localizationsDelegates: OrbitLocalizations.localizationsDelegates,
        builder: (context, child) => _scaled(context, child, textScale),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps [routes] in a `GoRouter` starting at [location], like
/// [pumpScreen] otherwise. Returns the router, for [currentPath].
///
/// [launcher] replaces the container's dialer/WhatsApp launcher, and
/// [overrides] are extra overrides, both scoped to the app.
Future<GoRouter> pumpRouter(
  WidgetTester tester, {
  required ProviderContainer container,
  required String location,
  required List<RouteBase> routes,
  FakeContactLauncher? launcher,
  List<Override> overrides = const [],
  Locale locale = const Locale('te'),
  double textScale = 1.0,
}) async {
  await _setUpPhone(tester);
  final router = GoRouter(initialLocation: location, routes: routes);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ProviderScope(
        overrides: [
          if (launcher != null)
            contactLauncherProvider.overrideWithValue(launcher),
          ...overrides,
        ],
        child: MaterialApp.router(
          theme: OrbitTheme.farmer(),
          themeAnimationDuration: Duration.zero,
          locale: locale,
          supportedLocales: OrbitLocalizations.supportedLocales,
          localizationsDelegates: OrbitLocalizations.localizationsDelegates,
          builder: (context, child) => _scaled(context, child, textScale),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// A stand-in screen for [path], for routes the test doesn't render. It
/// shows `stub <path>`, so tests can see where a tap went.
Widget stubScreen(String path) =>
    Scaffold(body: Center(child: Text('stub $path')));

/// Pumps [screen] at [path] with [pumpRouter], plus stub routes for the
/// signed-in screens it can go to (Home, Look for FAs, Calendar and the
/// tabs).
Future<GoRouter> pumpRouted(
  WidgetTester tester, {
  required ProviderContainer container,
  required String path,
  required Widget screen,
  FakeContactLauncher? launcher,
  List<Override> overrides = const [],
  Locale locale = const Locale('te'),
  double textScale = 1.0,
}) {
  Widget at(String p) => p == path ? screen : stubScreen(p);
  return pumpRouter(
    tester,
    container: container,
    location: path,
    launcher: launcher,
    overrides: overrides,
    locale: locale,
    textScale: textScale,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (_, _) => at(Routes.home),
        routes: [
          GoRoute(path: 'fas', builder: (_, _) => at(Routes.fas)),
          GoRoute(path: 'calendar', builder: (_, _) => at(Routes.calendar)),
        ],
      ),
      for (final p in [Routes.visits, Routes.advisory, Routes.farm])
        GoRoute(path: p, builder: (_, _) => at(p)),
    ],
  );
}

/// Pumps the whole app (router, shell, session redirects) over [container].
Future<void> pumpFarmerApp(
  WidgetTester tester, {
  required ProviderContainer container,
}) async {
  await _setUpPhone(tester);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const FarmerApp()),
  );
  await tester.pumpAndSettle();
}

/// The path of the top route, also after a `push`.
String currentPath(GoRouter router) => router.state.uri.path;

// ---------------------------------------------------------------------------
// Finders and gestures.

/// Finds text shown exactly as [label], also inside an icon + label
/// `Text.rich` (OrbitButton, ListenButton, FaCard sub-line), where the icon
/// is a placeholder character before the text.
Finder findLabel(String label) =>
    find.textContaining(RegExp('^￼?${RegExp.escape(label)}\$'));

/// The [OrbitButton] labelled [label]. (`find.text` misses button labels
/// that have an icon: the icon is a placeholder inside the same text.)
Finder orbitButton(String label) =>
    find.byWidgetPredicate((w) => w is OrbitButton && w.label == label);

/// The [StatusPill] labelled [label] (icon and word in one `Text.rich`).
Finder statusPill(String label) =>
    find.byWidgetPredicate((w) => w is StatusPill && w.label == label);

/// The voice key of the Listen button inside the open [AlertDialog].
String dialogVoiceKey(WidgetTester tester) => _voiceKeyIn(tester, AlertDialog);

/// The voice key of the Listen button inside the open bottom sheet.
String sheetVoiceKey(WidgetTester tester) => _voiceKeyIn(tester, BottomSheet);

String _voiceKeyIn(WidgetTester tester, Type container) => tester
    .widget<ScreenListenButton>(
      find.descendant(
        of: find.byType(container),
        matching: find.byType(ScreenListenButton),
      ),
    )
    .voiceKey;

/// Scrolls the screen's first scrollable until [finder] is built and fully
/// visible, then taps it.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Pumps one frame (16 ms) at a time for [total], calling [check] after each
/// (with when it is, for a reason), so a state shown for a single frame
/// (a spinner flash) is caught.
Future<void> pumpFrames(
  WidgetTester tester,
  Duration total,
  void Function(String when) check,
) async {
  const frame = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < total; t += frame) {
    await tester.pump(frame);
    check('at ${t.inMilliseconds} ms');
  }
}

/// Pulls [finder]'s scrollable down to refresh, and waits for it.
Future<void> pullToRefresh(WidgetTester tester, Finder finder) async {
  await tester.fling(finder, const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Layout checks.

/// Fails if any text was cut (ellipsis or maxLines) anywhere on screen.
void expectNoClippedText(WidgetTester tester) {
  final clipped = tester.allRenderObjects
      .whereType<RenderParagraph>()
      .where((p) => p.didExceedMaxLines)
      .map((p) => p.text.toPlainText())
      .toList();
  expect(clipped, isEmpty, reason: 'text cut off: $clipped');
}

/// Fails on an overflow (or any other exception) or cut text.
void expectCleanLayout(WidgetTester tester) {
  final error = tester.takeException();
  expect(error, isNull, reason: '$error');
  expectNoClippedText(tester);
}

/// One test per text scale: pumps the screen [build] makes, in Telugu on
/// 360 x 640, with the session in [phase] (an active Ravi by default), and
/// checks there is no overflow and no clipped text. [after] can tap into a
/// busier state first.
void screenLayoutTest(
  String description,
  Widget Function() build, {
  SessionPhase phase = SessionPhase.active,
  MockScenario scenario = MockScenario.normal,
  Future<void> Function(WidgetTester tester)? after,
}) {
  for (final scale in textScales) {
    testWidgets('$description fits 360x640 at text scale $scale', (
      tester,
    ) async {
      final container = await createContainerAt(phase, scenario: scenario);
      await pumpScreen(tester, build(), container: container, textScale: scale);
      if (after != null) await after(tester);
      expectCleanLayout(tester);
    });
  }
}
