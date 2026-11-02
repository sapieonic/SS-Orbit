# orbit_ui

The Orbit design system for Flutter, shared by the Farmer app and the FA app (Android and iOS): design tokens,
two Material 3 themes, bundled fonts, icons and components.

## What is in it

| Part | Where | Notes |
|---|---|---|
| Tokens | `lib/src/tokens/orbit_tokens.g.dart` | Generated from `design/tokens/`. Never edit by hand. |
| Theme | `OrbitTheme.farmer()`, `OrbitTheme.fa()` | Light, Material 3, built only from tokens. |
| Extra colours | `OrbitColors` (`ThemeExtension`) | success / warning / danger / info, severities, bar colours. |
| Fonts | `fonts/` | Figtree (Latin, digits) + Noto Sans Telugu, 400/500/700/800, OFL. Copies of `design/fonts/`; update both together (a test compares them). |
| Icons | `OrbitIcons` | Lucide, via the pinned `flutter_lucide` package. |
| Components | `lib/src/components/` | Listed below and in `design/components/README.md`. |

## Using it in an app

```dart
import 'package:orbit_l10n/orbit_l10n.dart'; // in the app: orbit_ui itself takes plain strings
import 'package:orbit_ui/orbit_ui.dart';

void main() {
  OrbitFonts.registerLicenses(); // OFL texts on the licence page
  runApp(
    MaterialApp(
      theme: OrbitTheme.farmer(),
      localizationsDelegates: OrbitLocalizations.localizationsDelegates,
      supportedLocales: OrbitLocalizations.supportedLocales,
      home: const HomeScreen(),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n; // OrbitLocalizations.of(context)
    return Scaffold(
      floatingActionButton: ListenButton.floating(
        label: l10n.commonListen,
        state: ListenState.idle, // the app maps orbit_voice's VoicePlayer.state to this
        onPressed: () {/* orbit_voice plays the screen prompt */},
      ),
      body: Column(
        children: [
          ScreenHeader(
            title: l10n.farmerHomeGreeting(name: 'రవి'),
            subtitle: 'Kondapur · Cotton',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(OrbitSpace.s16),
              children: [
                OrbitButton(
                  label: l10n.commonCallName(name: 'సురేష్'),
                  secondaryLabel: 'Call Suresh',
                  variant: OrbitButtonVariant.call,
                  size: OrbitButtonSize.hero,
                  onPressed: () {/* launch tel: */},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- Fonts need no setup: the theme sets `fontFamily: 'Figtree'` with `package: 'orbit_ui'` and
  `fontFamilyFallback: ['Noto Sans Telugu']` on every text style, so Telugu always renders with the bundled
  font, never the phone's. Use `Theme.of(context).textTheme` for custom text.
- Colours: read `Theme.of(context).colorScheme` and `OrbitColors.of(context)`. Do not use `OrbitPalette` or
  `OrbitSemanticColors` in widgets, so the farmer and FA apps differ only by theme. Spacing, radius and size
  tokens (`OrbitSpace`, `OrbitRadius`, `OrbitSize`) are the same in both apps and fine to use directly.
- Icons: use `OrbitIcons.*`. Never import the icon package; add a member to `OrbitIcons` instead.
- Put `ScreenHeader` at the top of the body, not in `Scaffold.appBar`: it grows with Telugu text at 130% font
  scale instead of clipping in a fixed-height bar. It also sets the status bar icons (dark on the `surface`
  tone, light on `primary` and `inverse`), so do not set `SystemChrome` styles per screen.
- Use `IconTileGrid` for tile grids rather than a fixed-ratio `GridView`, which clips wrapped Telugu.

## Layering rule

orbit_ui is string-agnostic and data-agnostic. Widgets take already-localised strings and plain values
(`String`, `int`, `double`, `IconData`, `ImageProvider`, callbacks). orbit_ui never depends on orbit_l10n,
orbit_voice, orbit_core or app models, and never hard-codes user-facing text. The one exception is the back
button tooltip in `ScreenHeader`, which comes from Flutter's own `MaterialLocalizations` (Telugu included).

Wherever it fits, a widget takes an optional second line (`secondaryLabel`, `subtitle`, ...) for the
wireframes' bilingual pattern: Telugu first, smaller English below.

## Components

| Widget | Key parameters |
|---|---|
| `OrbitButton` | `label`, `onPressed`, `secondaryLabel`, `variant` (primary, secondary, danger, call), `size` (medium 48, large 56, hero 64), `icon`, `fullWidth`, `loading` |
| `ListenButton` / `ListenButton.floating` | `label`, `onPressed`, `state` (idle, loading, playing, unavailable), `secondaryLabel` |
| `ScreenHeader` | `title`, `subtitle`, `onBack`, `listen`, `trailing`, `tone` (surface, primary, inverse). `listen` and `trailing` together take at most 40% of the width (`actionsMaxWidthFactor`): long labels wrap, the title keeps its room |
| `StateCard` | `icon`, `title`, `subtitle`, `message`, `action`, `listen`, `tone` (neutral, info, warning, danger) |
| `IconTile`, `IconTileGrid` | `icon`, `label`, `secondaryLabel`, `onTap`, `locked`, `lockedSemanticLabel`, `badge`; grid: `children`, `columns` |
| `FaCard` | `name`, `initials`, `image`, `subtitle`, `detail`, `tag`, `verified`, `highlighted`, `callLabel`/`onCall`, `whatsAppLabel`/`onWhatsApp`, `onTap` |
| `NoticeCard` | `source`, `title`, `meta`, `body`, `secondaryBody`, `pinned`/`pinnedLabel`, `unread`/`unreadLabel`, `actions`, `onTap` |
| `StatusPill` | `label`, `tone` (success, warning, danger, info, neutral), `icon` |
| `SeverityPill` | `severity` (low, moderate, high), `label` |
| `OrbitTag` | `label`, `tone` (neutral, primary, highlight), `icon` |
| `AdviceResult.product` / `.saltOnly` | `heading`, `secondaryHeading`, `name`, `dose`, `note`, `action` |
| `OrbitBanner` | `kind` (offline, info, success, error), `title`, `message`, `savedAt`, `action` |
| `PhoneField` | `controller`, `label`, `hint`, `helperText`, `errorText`, `countryCode` (+91), `onChanged`, `onSubmitted`. Holds at most 10 digits: a typed 11th digit is refused; a pasted or autofilled number loses a `+91`, `91`, `0091` or `0` prefix (`IndianMobileNumberFormatter`) |
| `OtpInput` | `length` (6), `controller`, `onChanged`, `onCompleted`, `errorText`, `semanticLabel` |
| `InlineError` | `message`: an icon-plus-words error line under the control that failed, announced when it appears |
| `ChoiceTile` | `label`, `secondaryLabel`, `icon`, `tag`, `selected`, `onTap`: one option in a pick-one list (56 dp, tick when selected) |
| `SegmentedTabs` | `labels`, `selectedIndex`, `onChanged` |
| `SectionHeader` | `title`, `secondary`, `trailing` |
| `StepLayout`, `StepQuestion` | `title`, `step`, `totalSteps`, `stepLabel` ("Step 2 of 3"), `subtitle`, `onBack`, `listen`, `child`, `action` (pinned above the keyboard); question: `text`, `helper` |
| `LoadMoreFooter` | `loading`, `errorText`, `onLoadMore`, `loadingLabel`, `retryLabel`: last row of a paged list; asks for the next page when built, Try again after an error |
| `StageStrip` | `stages`, `currentIndex`, `progress`, `progressLabel`, `currentLabel`, `doneLabel`, `axis` |
| `OrbitNavigationBar` | `destinations` (`OrbitNavigationDestination(icon, label, selectedIcon, badge)`), `selectedIndex`, `onDestinationSelected` |
| `InfoRow`, `KeyValueRow` | `icon`, `text`, `secondaryText`, `trailing`; `label`, `value`, `secondaryValue` |
| `BilingualText` | `primary`, `secondary`, `primaryStyle`, `secondaryStyle`, `textAlign` |
| `PinPad`, `PinPadKey`, `PinDots` | `onDigit`, `onDelete`, `deleteLabel`, `leading` (`PinPadKey.icon` / `.text`), `enabled`, `keyHeight` (64); dots: `length`, `filled`, `semanticLabel`, `error` |
| `FilterChipsBar` | `items` (`FilterChipItem(label, count)`), `selectedIndex`, `onSelected`, `semanticLabel`, `padding`: pick-one chips that scroll sideways |
| `DayStrip` | `days` (`DayStripDay(weekday, day, semanticLabel, dots, isToday)`), `selectedIndex`, `onSelected`, `semanticLabel` |
| `ConflictCard` | `title`, `meta`, `statusLabel`, `mineLabel`/`mineValue`, `theirsLabel`/`theirsValue`, `keepMineLabel`/`onKeepMine` (label null hides Keep mine: only HO's can be kept), `keepTheirsLabel`/`onKeepTheirs`, `resolving` |
| `SwitchRow` | `title`, `subtitle`, `value`, `onChanged`, `bordered`: a 60 dp setting row that toggles as a whole |
| `StepIndicator` | `labels`, `currentIndex` (`labels.length` = all done), `semanticLabel`, `doneLabel`, `currentLabel`: named steps with done ticks |

## Accessibility built in

- Touch targets: 48 dp minimum everywhere, 56 dp for primary actions, 64 dp for the farmer's main action
  (`OrbitButtonSize.hero`).
- Text wraps; nothing is cut with an ellipsis. Buttons grow taller instead of shrinking text.
- Status and severity are always icon plus word. Lone icons carry a semantic label (padlock, unread dot,
  back button); decorative icons are excluded.
- Text colour pairs meet WCAG AA (4.5:1); input borders meet 3:1. `test/contrast_test.dart` enforces it.

## Regenerating tokens

Edit the JSON in `design/tokens/`, then from `mobile/`:

```bash
melos run gen:tokens            # or: dart run ../tools/tokens/build.dart
dart run ../tools/tokens/build.dart --check   # CI: exit 1 if stale
```

Commit the JSON and the regenerated `orbit_tokens.g.dart` together. See `tools/tokens/README.md`.

## Tests

`flutter test` from this folder. Layout tests render every component on a 360 x 640 surface at text scale
1.0 and 1.3 with real Telugu from the wireframes and the real bundled fonts, under the `te` locale, and fail
on any overflow or clipped text. Also: theme, contrast, font-weight and generator-freshness tests, and a check
that every file in `fonts/` is byte-identical to its source in `design/fonts/` (skipped outside the repo).
