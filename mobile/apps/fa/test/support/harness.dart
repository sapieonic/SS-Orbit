/// Test harness for every FA app test: containers over a fresh mock backend
/// signed in as Suresh with his territory on the phone, pumping one screen
/// (inside a router with stub pages for everywhere else it can go) or the
/// whole app, a fake launcher, and finders and layout checks for Orbit
/// widgets.
///
/// ```dart
/// testWidgets('shows Ravi K', (tester) async {
///   final t = await pumpFaScreen(tester, const FarmersScreen());
///   expect(find.text('Ravi K'), findsOneWidget);
///   t.selectScenario(MockScenario.offline);
///   await tester.tap(find.byType(SyncPill));
///   await tester.pumpAndSettle();
///   expect(currentPath(t.router), AppRoutes.sync);
/// });
/// ```
library;

import 'dart:io';

import 'package:fa/src/app.dart';
import 'package:fa/src/data/data.dart';
import 'package:fa/src/device/device.dart';
import 'package:fa/src/local/local.dart';
import 'package:fa/src/routing/router.dart';
import 'package:fa/src/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_core/orbit_core.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

// ---------------------------------------------------------------------------
// Fixed data (the mock world in the build brief).

/// Suresh Kumar's login ID (Kondapur and Gachibowli).
const sureshLogin = 'FA-KDP-014';

/// Suresh's password.
const sureshPassword = 'orbit2026';

/// The PIN every signed-in test sets.
const testPin = '2580';

/// A login with a temporary password (must change it).
const tempLogin = 'FA-KDP-099';

/// Its temporary password.
const tempPassword = 'temp1234';

/// The OTP the mock accepts everywhere (consent and the like).
const devOtp = '123456';

/// "Now" when every test starts: Monday 2 Nov 2026, 10:30 IST.
final testStart = DateTime.utc(2026, 11, 2, 5);

/// A new clock at [testStart].
FixedClock newTestClock() => FixedClock(testStart);

FixedClock? _testClock;

/// The current test's clock, at [testStart] when the test starts. The app,
/// [testBackend] and the test share it within one test (advance it to move
/// time for all of them); the next test gets a new one.
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

/// A fresh mock backend with no latency on the test clock. Change the
/// scenario mid-test with [FaTest.selectScenario] (the network follows), or
/// `backend.scenario = ...` for the server's answers only.
MockBackend testBackend() =>
    MockBackend(clock: testClock, latency: Duration.zero);

/// What a test works with: the container, the mock server behind it, and
/// (once something is pumped) the router.
class FaTest {
  FaTest._(this.container, this.backend);

  /// The app's providers.
  final ProviderContainer container;

  /// The mock server.
  final MockBackend backend;

  /// The router of the pumped screen or app; set by [pumpFaScreen] and
  /// [pumpFaApp].
  late GoRouter router;

  /// Shortcut for `container.read`.
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  /// The current territory on the phone.
  Territory get territory => container.read(territoryProvider).requireValue;

  /// The current session phase.
  SessionPhase get phase => container.read(sessionProvider).phase;

  /// The fake launcher (calls, WhatsApp, directions).
  FakeLauncher get launcher => container.read(launcherProvider) as FakeLauncher;

  /// Switches the mock scenario as the dev screen does, so the network state
  /// follows (`offline` is also no network). Setting `backend.scenario`
  /// directly changes only the server's answers.
  void selectScenario(MockScenario scenario) =>
      container.read(mockScenarioProvider.notifier).select(scenario);
}

/// A test container over a fresh, zero-latency mock backend (or [backend]).
///
/// [signedIn] logs Suresh in through the real session controller, sets
/// [testPin] and pulls his territory, so screens see an active FA with 46
/// farmers. [language] is chosen first, as on A1d. [scenario] is applied
/// after sign-in, so `offline` doesn't block it, through
/// `mockScenarioProvider` as the dev screen does (so `connectivityProvider`
/// follows: `offline` also means no network). [overrides] are added last.
/// [clock] replaces [testClock] for the app (give [backend] the same one)
/// and [store] the empty in-memory session store.
Future<FaTest> createFaTest({
  bool signedIn = true,
  MockScenario scenario = MockScenario.normal,
  MockBackend? backend,
  Language language = Language.te,
  List<Override> overrides = const [],
  Clock? clock,
  SessionStore? store,
}) async {
  final mock = backend ?? testBackend();
  final container = ProviderContainer.test(
    overrides: [
      ...faDataOverrides(
        env: OrbitEnv.devMock,
        store: store ?? InMemorySessionStore(),
        mockBackend: mock,
      ),
      ...localEngineOverrides(),
      clockProvider.overrideWithValue(clock ?? testClock),
      // A fast verifier: PBKDF2 at full strength takes seconds per PIN.
      pinLockProvider.overrideWithValue(PinLock(iterations: 10)),
      launcherProvider.overrideWithValue(FakeLauncher()),
      ...overrides,
    ],
    retry: (_, _) => null,
  );
  final t = FaTest._(container, mock);
  final session = container.read(sessionProvider.notifier);
  await session.restored;
  if (language != Language.te) await session.setLanguage(language);
  if (signedIn) {
    await signInSuresh(t);
  }
  t.selectScenario(scenario);
  return t;
}

/// Logs Suresh in, sets [testPin] and pulls his territory onto the phone.
Future<void> signInSuresh(FaTest t) async {
  final session = t.container.read(sessionProvider.notifier);
  await session.login(sureshLogin, sureshPassword);
  if (t.phase == SessionPhase.setup) await session.setPin(testPin);
  expect(t.phase, SessionPhase.active);
  await t.container.read(syncEngineProvider).syncNow();
  await t.container.read(territoryProvider.future);
}

/// A container whose session is already in [phase], over a fresh
/// zero-latency mock. `active` and `locked` have Suresh's territory on the
/// phone; `mustChangePassword` uses [tempLogin]; `updateRequired` and
/// `removed` come from the mock scenarios. [scenario] is applied once the
/// phase is reached (where the phase does not need one itself).
///
/// Not for [SessionPhase.restoring], which the session leaves on its own.
Future<FaTest> createFaTestAt(
  SessionPhase phase, {
  MockScenario scenario = MockScenario.normal,
  MockBackend? backend,
  List<Override> overrides = const [],
}) async {
  if (phase == SessionPhase.restoring) {
    throw ArgumentError.value(phase, 'phase', 'is left before this returns');
  }
  final t = await createFaTest(
    signedIn: false,
    backend: backend,
    overrides: overrides,
  );
  final session = t.container.read(sessionProvider.notifier);
  switch (phase) {
    case SessionPhase.restoring:
    case SessionPhase.signedOut:
      break;
    case SessionPhase.mustChangePassword:
      await session.login(tempLogin, tempPassword);
    case SessionPhase.setup:
      await session.login(sureshLogin, sureshPassword);
    case SessionPhase.active:
      await signInSuresh(t);
    case SessionPhase.locked:
      await signInSuresh(t);
      session.lock();
    case SessionPhase.passwordNeeded:
      await signInSuresh(t);
      session
        ..lock()
        ..usePassword();
    case SessionPhase.updateRequired:
      await signInSuresh(t);
      t.selectScenario(MockScenario.updateRequired);
      await session.recheck();
    case SessionPhase.removed:
      await signInSuresh(t);
      t.selectScenario(MockScenario.deviceRemoved);
      await session.recheck().catchError((_) {});
  }
  expect(t.phase, phase);
  if (phase != SessionPhase.updateRequired && phase != SessionPhase.removed) {
    t.selectScenario(scenario);
  }
  return t;
}

// ---------------------------------------------------------------------------
// Fakes.

/// Records dialer, WhatsApp, maps and store launches instead of opening
/// apps.
class FakeLauncher implements Launcher {
  /// [opens] is what every launch returns (false: no such app).
  FakeLauncher({this.opens = true});

  /// What every launch returns.
  bool opens;

  /// Numbers the dialer was opened with.
  final calls = <String>[];

  /// Numbers a WhatsApp chat was opened with, and its text.
  final whatsApps = <(String, String?)>[];

  /// Places directions were asked for.
  final directionsTo = <(double, double)>[];

  /// Store pages opened.
  final stores = <String>[];

  @override
  Future<bool> call(String phone) async {
    calls.add(phone);
    return opens;
  }

  @override
  Future<bool> whatsApp(String phone, {String? text}) async {
    whatsApps.add((phone, text));
    return opens;
  }

  @override
  Future<bool> directions(double lat, double lng) async {
    directionsTo.add((lat, lng));
    return opens;
  }

  @override
  Future<bool> openStore(String url) async {
    stores.add(url);
    return opens;
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

/// A stand-in page for [path], for places a test doesn't render. It shows
/// `stub <path>`, so tests can see where a tap went.
Widget stubScreen(String path) =>
    Scaffold(body: Center(child: Text('stub $path')));

/// Stub routes for every page of the app ([AppRoutes]), query and path
/// parameters included; the stub shows the full location.
List<RouteBase> stubRoutes() {
  Widget stub(GoRouterState state) => stubScreen(state.uri.toString());
  GoRoute route(String path, [List<RouteBase> routes = const []]) =>
      GoRoute(path: path, builder: (_, s) => stub(s), routes: routes);
  return [
    for (final p in AppRoutes.entryPaths) route(p),
    route(AppRoutes.farmers, [route(':farmerId')]),
    route(AppRoutes.calendar, [route('plan')]),
    route(AppRoutes.enrol, [route(':farmerId/plot'), route(':farmerId/crop')]),
    route(AppRoutes.alerts),
    route(AppRoutes.sync),
    route(AppRoutes.me),
    route(AppRoutes.dev),
    route(AppRoutes.visitPath),
  ];
}

/// Pumps [screen] as the app shows it, over a new [FaTest] (signed in as
/// Suresh with his territory unless [signedIn] is false; [scenario] after
/// sign-in) or over [test]: FA theme, Orbit localisations in [locale]
/// (Telugu by default), [textScale], on a 360 x 640 phone with real fonts.
///
/// The screen sits at [location] in a `GoRouter` whose other pages are
/// [stubRoutes], so its taps navigate (`currentPath(t.router)`, or
/// `find.text('stub /sync')`). Give the screen's real path as [location]
/// (`AppRoutes.farmer(id)`) when it reads the route, or leave the default.
Future<FaTest> pumpFaScreen(
  WidgetTester tester,
  Widget screen, {
  FaTest? test,
  bool signedIn = true,
  MockScenario scenario = MockScenario.normal,
  String location = '/screen',
  Locale locale = const Locale('te'),
  double textScale = 1.0,
  List<Override> overrides = const [],
}) async {
  final t =
      test ??
      await createFaTest(
        signedIn: signedIn,
        scenario: scenario,
        overrides: overrides,
      );
  await _setUpPhone(tester);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: Uri.parse(location).path, builder: (_, _) => screen),
      ...stubRoutes(),
    ],
  );
  addTearDown(router.dispose);
  t.router = router;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: t.container,
      child: MaterialApp.router(
        theme: OrbitTheme.fa(),
        themeAnimationDuration: Duration.zero,
        locale: locale,
        supportedLocales: OrbitLocalizations.supportedLocales,
        localizationsDelegates: OrbitLocalizations.localizationsDelegates,
        builder: (context, child) => _scaled(context, child, textScale),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return t;
}

/// Pumps the whole app (router, shell, session redirects, lifecycle) over a
/// new [FaTest] (see [createFaTest]) or over [test]. A signed-in test lands
/// on Farmers.
Future<FaTest> pumpFaApp(
  WidgetTester tester, {
  FaTest? test,
  bool signedIn = true,
  MockScenario scenario = MockScenario.normal,
  double textScale = 1.0,
}) async {
  final t = test ?? await createFaTest(signedIn: signedIn, scenario: scenario);
  await _setUpPhone(tester);
  t.router = t.container.read(routerProvider);
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(container: t.container, child: const FaApp()),
  );
  await tester.pumpAndSettle();
  return t;
}

/// The path of the top route, also after a `push`.
String currentPath(GoRouter router) => router.state.uri.path;

/// The full location (path and query) of the top route.
String currentLocation(GoRouter router) => router.state.uri.toString();

// ---------------------------------------------------------------------------
// Finders and gestures.

/// Finds text shown exactly as [label], also inside an icon + label
/// `Text.rich` (OrbitButton, StatusPill), where the icon is a placeholder
/// character before the text.
Finder findLabel(String label) =>
    find.textContaining(RegExp('^￼?${RegExp.escape(label)}\$'));

/// The [OrbitButton] labelled [label].
Finder orbitButton(String label) =>
    find.byWidgetPredicate((w) => w is OrbitButton && w.label == label);

/// The [StatusPill] labelled [label].
Finder statusPill(String label) =>
    find.byWidgetPredicate((w) => w is StatusPill && w.label == label);

/// A bottom-bar tab by its label.
Finder navTab(String label) => find.descendant(
  of: find.byType(OrbitNavigationBar),
  matching: find.text(label),
);

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

/// Android back, as the system sends it.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
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
/// 360 x 640, signed in as Suresh ([signedIn]), and checks there is no
/// overflow and no clipped text. [after] can tap into a busier state first.
void screenLayoutTest(
  String description,
  Widget Function() build, {
  bool signedIn = true,
  MockScenario scenario = MockScenario.normal,
  String location = '/screen',
  Future<void> Function(WidgetTester tester, FaTest t)? after,
}) {
  for (final scale in textScales) {
    testWidgets('$description fits 360x640 at text scale $scale', (
      tester,
    ) async {
      final t = await pumpFaScreen(
        tester,
        build(),
        signedIn: signedIn,
        scenario: scenario,
        location: location,
        textScale: scale,
      );
      if (after != null) await after(tester, t);
      expectCleanLayout(tester);
    });
  }
}
