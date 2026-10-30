# design/ implementation plan

## Purpose
`design/` is the single source for the look of every Orbit client: colour, type, spacing, radius, elevation,
fonts, icons and illustrations. The Flutter apps (`mobile/`) and the React apps (`web/`) never hard-code these
values; they read code generated from `design/tokens/`.

## Read first
- Wireframes (the only visual source today): `Orbit Shifting · Farmer App.html`, `... · Field Assistant App.html`,
  `... · Admin Dashboard.html` (bundled HTML; open in a browser), kept outside the repo (the product team shares them; never commit them). The token values below were taken from
  them; text extracts are in `docs/source/farmer-wireframes.txt` and `docs/source/fa-admin-wireframes.txt`.
- Build plan, sections "Mobile apps", "Web apps", "Repositories and shared code":
  https://claude.ai/artifact/M85KFgHynuZ4gWBqz87pSa
- Requirements NFR-01, NFR-02, NFR-03, NFR-05, NFR-08 (farmer design rules: icons first, Telugu by default with a
  speaker button, big high-contrast buttons, one task per screen, FA one tap away).
- Sibling plans: `../mobile/implementation-plan.md` (orbit_ui, orbit_voice), `../web/implementation-plan.md`
  (packages/ui), `../i18n/implementation-plan.md` (strings and voice prompts).

## Current state
- `design/` holds only `.gitkeep`. No tokens, fonts, icons or pipeline yet.
- The values below were extracted from the CSS inside the three wireframe files (38 + 32 + 36 style blocks plus
  inline styles). The wireframes use no CSS variables, so these are raw values grouped by role.

## Decisions (fixed)
- One token source in `design/tokens/` (W3C DTCG JSON), generated into Dart and CSS/TS. Generated files are
  committed; CI fails if they are stale (same rule as OpenAPI codegen).
- Three app themes over one shared palette: Farmer (saffron-brown), FA (blue), HO admin (purple). Green, red and
  amber mean the same thing in every app.
- Fonts: Noto Sans Telugu for Telugu, Figtree for Latin and digits (both SIL OFL, both used by the wireframes).
- Light theme only at launch. Sunlight readability (NFR-02) beats dark mode for farmers and FAs. The token files
  keep a slot for a dark set so the admin portal can add one later without renaming tokens.
- Shared components are shared by spec (name, props, states, tokens), not by code. Flutter and React each build
  their own, in `mobile/packages/orbit_ui` and `web/packages/ui`.

## Tokens extracted from the wireframes

### Colour (hex as found; count = uses across all three files)
| Token (proposed) | Value | Where it is used |
|---|---|---|
| `color.ink` | `#1B2420` | Primary text everywhere; dark bars and the floating Listen button in the farmer app |
| `color.ink-2` | `#4E5852` (also `#4E5953`, `#525C56`) | Secondary text, table headers. Merge to `#4E5852` |
| `color.muted` | `#67726C` | Meta text, inactive tabs (most used text colour after ink) |
| `color.surface` | `#FFFFFF` | Cards, sheets, inputs |
| `color.canvas` | `#F9FAF7` | Page background (admin body), list backgrounds |
| `color.canvas-2` | `#F4F6F1`, `#EEF0EC`, `#ECEFEA` | Table header, segmented control, row dividers |
| `color.line` | `#E1E5DE` | Card and table borders |
| `color.line-strong` | `#C9CEC6` (also `#C9CFC6`, `#CFD5CB`) | Input, chip and button borders |
| `color.green` / `-strong` / `-tint` | `#2C7A4B` / `#24673F` (`#23653D`, `#1F5E39`, `#1F7A45`) / `#E1F1E7` | Success, done steps, call buttons, "Shanmukha product found" |
| `color.red` / `-strong` / `-tint` | `#B4443A` / `#8E3128` (`#8E2E25`) / `#F8E3E0` | Errors, high severity, reject |
| `color.amber` / `-text` / `-tint` | `#B47713` / `#7A4F08` (`#8A5A0B`, `#5C3C07`) / `#FBF0D6` | Warnings, pending, moderate severity |
| `color.yellow` | `#F6C343` | Highlight badges (always with ink text) |
| `color.orange` | `#D2731A` | Accent dots and icons only |
| `color.farmer.primary` / `-strong` / `-tint` | `#A9560C` / `#7E3F08` / `#FCEEDF` | Farmer primary buttons (56-58 px), links, selected states |
| `color.fa.primary` / `-strong` / `-tint` | `#2263A6` / `#174A80` / `#E3EDF8` (`#C3D6EE` border) | FA primary buttons, active tab, selected chips |
| `color.admin.primary` / `-strong` / `-tint` | `#5B3B8F` / `#432B6B` (`#3E2766`) / `#EFE9F7` (`#8D76B5` mid) | Admin sidebar, primary buttons, links |
| `color.map.*` | `#E6EEDC` land, `#7F9C63`, `#91AD74`, `#6A8A50` plots | Farmers-near-me map and plot boundary drawing |
| `color.scrim` | `rgba(0,0,0,0.5)`; on-dark `rgba(255,255,255,0.18)` / `0.22` | Sheet backdrops; text and borders on primary bars |

### Type
- Families: `'Noto Sans Telugu'` and `'Figtree'`; stack `Figtree, 'Noto Sans Telugu', system-ui, sans-serif`
  for mixed text, `'Noto Sans Telugu', Figtree, sans-serif` for Telugu-first labels. Admin uses `ui-monospace`
  once (IDs).
- Weights used: 400, 500, 600, 700, 800 (700 is the most common).
- Sizes found: farmer 13, 16, 12, 15, 14, 17, 18, 20, 19, 22 (plus 24-48 for big numbers and OTP boxes);
  FA 14, 15, 13, 16, 21, 17; admin 14, 13, 12, 11, 13.5, 28, 24, 26.
- Line heights: farmer 1.4 / 1.45 / 1.35 / 1.5; FA 1.2 / 1.4 / 1.3; admin 1.25 / 1.2.

Proposed scale (px; Flutter uses the same numbers as logical px):

| Token | Size / weight | Use |
|---|---|---|
| `type.display` | 40 / 800 | Wallet balance, OTP digits |
| `type.h1` | 26 / 800 | Admin page title, farmer screen title |
| `type.h2` | 22 / 700 | Section titles, FA screen title |
| `type.h3` | 18 / 700 | Card titles |
| `type.body-lg` | 16 / 500 | Farmer body text (default in the farmer app) |
| `type.body` | 15 / 500 | FA body text |
| `type.body-sm` | 14 / 400 | Admin body and table cells |
| `type.caption` | 13 / 500 | Meta lines (date, FA name, distance) |
| `type.micro` | 12 / 600 | Pills, tags, table headers. Farmer app never goes below this |

### Spacing, radius, size, elevation
- Spacing values found (gap and padding): 2, 4, 6, 8, 10, 12, 14, 16, 20, 24. Proposed `space.*`: 2, 4, 6, 8, 10,
  12, 16, 20, 24, 32 (drop 14, round to 12 or 16). Screen side padding 16; card padding 12-14.
- Radius found: farmer 14 (most), 12, 16, 24, 10, 18, 999; FA 14, 999, 50%, 16, 12; admin 10 (most), 12, 14, 999.
  Proposed `radius.*`: `xs` 4, `sm` 8, `md` 10 (admin default), `lg` 14 (mobile card default), `xl` 18,
  `sheet` 24 (top corners of bottom sheets), `pill` 999.
- Control heights found: farmer 48, 52, 56, 64 (58 once, snap to 56); FA 48, 52, 56, 64; admin 44, 40, 34.
  Proposed `size.control.*`: `sm` 40 (admin compact), `md` 44 (admin), `lg` 48 (mobile minimum), `xl` 56 (mobile
  primary), `xxl` 64 (farmer main action, FA big buttons).
- Elevation: `e1` `0 1px 3px rgba(0,0,0,.12)` (cards), `e2` `0 2px 6px rgba(0,0,0,.15)` (menus, admin popovers),
  `e3` `0 8px 20px -8px rgba(0,0,0,.5)` (floating Listen button, sheets), `outline` `inset 0 0 0 1px
  rgba(27,36,32,.15)`.
- Frames: phones are 360 x 780 (FA sync screen 360 x 960); admin desktop is 1440 x 980 with a 360 px mobile view
  (H10). Design and golden tests target 360 dp wide.

## Telugu typography
- Font: Noto Sans Telugu (Google, OFL, full Telugu conjunct and vowel-sign coverage, variable weight 100-900).
  Ship weights 400, 500, 700, 800 only to keep the farmer APK small (target under 20 MB). Fallbacks if the
  usability test finds it too thin in sunlight: Anek Telugu or Mandali (both OFL). Do not rely on the phone's
  system Telugu font; cheap phones render conjuncts inconsistently.
- Line height: Telugu needs room for stacked conjuncts (vattulu) and vowel signs above and below. Use 1.5 for
  Telugu body and 1.3 for Telugu headings (wireframes use 1.4-1.45; raise them). Latin keeps 1.4 / 1.2.
- Size: Telugu body at least 16 in the farmer app and 15 in the FA app. Telugu glyphs look smaller than Latin at
  the same size, so Telugu-first labels with an English sub-line set English one step smaller (as the
  wireframes do: Telugu 16/700, English 13/500).
- Never truncate Telugu with an ellipsis inside a word cluster; let labels wrap to two lines. Buttons grow in
  height, not shrink in font.
- Digits, money and dates use Figtree with Indian grouping (`₹1,00,000`), `dd-MM-yyyy` dates.
- Web: self-host both fonts as WOFF2 with `font-display: swap` and `unicode-range` subsets (Telugu U+0C00-0C7F),
  served from the same CloudFront as the app. No Google Fonts runtime call (data use, privacy).

## Components shared by Flutter and React
One spec per component in `design/components/<name>.md` (props, states, tokens, Telugu example, wireframe
screen). Flutter builds all of them; React builds the ones its apps need (Admin = admin portal, Web = farmer
web pages).

| Component | Wireframe source | Flutter | React |
|---|---|---|---|
| Button (primary, secondary, danger, call) | all | yes | Admin, Web |
| ListenButton (speaker, plays a voice key or URL) | F1-F11 | yes | Web (notice page) |
| FACard (photo, name, area, call) | F2, F3 | yes | no |
| NoticeCard (HO/CIV tag, time, title, listen) | F5, H3 preview | yes | Admin preview, Web |
| StatusPill (planned, done, missed, sent, delivered, failed, pending) | FA calendar, H1, H9 | yes | Admin |
| Chip / FilterChip / SegmentedControl | F3, FA near me, H7 | yes | Admin |
| ListRow with call action | F3, FA near me | yes | no |
| StepIndicator (Farmer, Farm, Crop) | FA enrol 1-3 | yes | no |
| SeverityPicker (low, moderate, high) | FA visit log | yes | no |
| AdviceResult (product found / salt only) | FA visit log, F8a, F8b | yes | Web (product card, Phase 2) |
| ConflictChooser ("Keep mine / Keep HO's") | FA sync status | yes | no |
| Banner (offline, syncing, new farmer, error) | F empty states, FA error states | yes | Admin |
| EmptyState / OfflineState / ErrorState | "Farmer app empty, offline and error states", "FA app · Error and offline states" | yes | Admin, Web |
| OtpInput (6 boxes) | F1, FA consent OTP | yes | no |
| KPI tile, DataTable, SidePanel, FilterBar | H1, H7, H2 | no | Admin |

## Icons and illustrations
- The wireframes draw every icon as inline SVG with round caps and joins, mostly 2 px stroke: the Lucide style.
  Use Lucide (ISC licence): `lucide-react` on web and the Lucide icon font package for Flutter, pinned versions.
  Custom farm icons (crop, sprayer, soil, drone, sticky trap, salt bottle) are drawn on the same 24 px grid and
  2 px stroke and kept in `design/icons/*.svg`.
- Flutter: custom icons compiled with `vector_graphics_compiler` (or packed into an icon font) so they tint with
  tokens. React: imported as components via SVGR.
- Icons always sit next to a label on farmer screens (icons first, words second, NFR-02); never icon-only.
- Illustrations: the wireframes have none (no raster images). Commission a small flat SVG set (~20: empty
  states, offline, success, crops of Telangana such as paddy, cotton, chilli, maize, red gram) in the palette above,
  stored in `design/illustrations/`. Pest and disease photos belong to Agronomy's masters content, not here.
- App icon and logo: the Orbit Shifting mark from the wireframe header; final artwork from Shanmukha marketing.

## Token export pipeline (recommendation)
- Style Dictionary v4 (pinned), config in `design/style-dictionary.config.mjs`, run by `make tokens` at the repo
  root (add the target) or `pnpm --dir design build`.
- Inputs: `design/tokens/base.json` (palette, type, space, radius, size, elevation), `semantic.json`
  (text, surface, border, status, action), `apps/farmer.json`, `apps/fa.json`, `apps/ho-portal.json` (primary
  overrides).
- Outputs (committed, never hand-edited):
  - `mobile/packages/orbit_ui/lib/src/tokens/orbit_tokens.g.dart` (`OrbitColors`, `OrbitType`, `OrbitSpace`,
    `OrbitRadius` constants) plus a hand-written `orbit_theme.dart` that builds `ThemeData` per app from them.
  - `web/packages/ui/src/tokens/tokens.css` (CSS custom properties on `:root`, app theme via
    `[data-app="admin"]`), `tokens.ts` (typed constants) and `tailwind-preset.ts` for the admin portal.
- CI: run `make tokens` and `git diff --exit-code` in the mobile and web workflows.

## Accessibility (low-literacy users and sunlight)
Contrast checked from the extracted values (WCAG 2.2; AA needs 4.5:1 for text, 3:1 for large text and UI
borders):

| Pair | Ratio | Verdict |
|---|---|---|
| White on farmer `#A9560C` | 5.22 | OK |
| White on green `#2C7A4B` / FA `#2263A6` / admin `#5B3B8F` / red `#B4443A` | 5.26 / 6.17 / 8.51 / 5.49 | OK |
| Ink `#1B2420` on white / canvas | 15.91 / 15.19 | OK |
| Muted `#67726C` on white / canvas | 5.00 / 4.77 | OK, but not for farmer body text |
| `#A9560C` on its tint `#FCEEDF` | 4.58 | Borderline; use `#7E3F08` text on tint |
| Green `#2C7A4B` on `#E1F1E7` | 4.49 | Fails by a hair; use `#24673F` (5.81) for text on tint |
| White on amber `#B47713` / orange `#D2731A` | 3.76 / 3.38 | Fails for text. Amber text is `#7A4F08` on `#FBF0D6` (6.28) |
| Border `#E1E5DE` / `#C9CEC6` on white | 1.28 / 1.60 | Fine for card edges; input borders need 3:1, use `#8A948E` (3.13) |

Rules
- Touch targets: farmer 56 dp minimum for primary actions and 48 dp for everything else; FA 48 dp; admin
  44 px (40 px only in dense tables). At least 8 dp between targets.
- Colour is never the only signal: every status pill has a word and an icon.
- Every farmer screen has the ListenButton (NFR-01). One task per screen (NFR-03).
- Support Android font scale up to 130% without clipping; golden tests render each farmer screen in Telugu
  at 1.0 and 1.3.
- Admin portal: keyboard reachable, visible focus ring (2 px `color.admin.primary`), labels on every input.

## Build order
1. **Phase 0 (by wk 4): tokens and fonts.** Write `tokens/*.json` from the tables above; set up Style Dictionary;
   add fonts and `OFL.txt`; copy the three wireframe files into `design/wireframes/` so the repo is
   self-contained. Done when `make tokens` produces the Dart and CSS files and a Flutter and a React sample
   page render the type scale in Telugu correctly on a ₹8k Android phone and Chrome.
2. **Phase 0: icon set.** Pick the Lucide version; draw the custom farm icons. Done when every icon used in the
   wireframes maps to a Lucide name or a file in `design/icons/` (list in `design/icons/README.md`).
3. **Phase 1a (wk 4-12): FA and admin components.** Specs plus Flutter widgets for Button, Chip, ListRow,
   StepIndicator, SeverityPicker, AdviceResult, ConflictChooser, Banner, states, OtpInput; React Button,
   StatusPill, DataTable, FilterBar, KPI tile, SidePanel. Done when the FA screens and H1/H2/H5/H7 are built only
   from these and golden tests pass.
4. **Phase 1b (wk 12-20): farmer components.** ListenButton, FACard, NoticeCard, bottom tab bar, empty and
   offline states, illustrations. Done when the usability test with 5-10 farmers passes without help (NFR-02).
5. **Phase 2 (wk 20-30): money components.** Plan card, payment result, wallet balances, bill upload, ID check,
   product card for the farmer web page. Done when F7-F9c and H4 screens use only shared components.
6. **Phase 3:** chat bubbles and mic input for the AI bot (F6), analytics charts for H6.

## Open decisions
- Final logo and app icon artwork (Shanmukha marketing).
- Whether farmers want a high-contrast mode beyond the default (decide after the Phase 1b usability test).
- Illustration supplier and budget.
- Map tile style must match `color.map.*` and its licence must allow offline caching (Phase 0 gate in the plan).

## Definition of done
- `design/tokens/` is the only place a colour, size or radius is defined; grep finds no hex colours in
  `mobile/apps`, `mobile/packages` (outside generated files) or `web/apps`.
- Generated Dart and CSS/TS are committed and CI checks they are fresh.
- Every shared component has a spec in `design/components/` and passes the contrast and touch-target rules.
- Fonts, icons and illustrations carry their licences in the folder.
