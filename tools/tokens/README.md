# tools/tokens

Generates client code from the design tokens in `design/tokens/` (W3C DTCG JSON).
Plain Dart, no packages, so mobile CI needs no Node.

```bash
# from mobile/ (what `melos run gen:tokens` runs)
dart run ../tools/tokens/build.dart
# from the repo root
dart run tools/tokens/build.dart
# CI: exit 1 if a generated file is stale, 0 if fresh
dart run tools/tokens/build.dart --check
```

Exit codes: `0` ok, `1` stale (`--check`), `2` invalid tokens (bad reference, cycle, wrong `$type`, a token
group with no output mapping).

## Inputs

Loaded in this order (later files may reference earlier ones):

| File | Holds |
|---|---|
| `design/tokens/base.json` | palette (`color`), `font`, `type`, `space`, `radius`, `size`, `elevation` |
| `design/tokens/semantic.json` | `text`, `surface`, `border`, `status`, `severity`, `action`, `on-primary-bar` |
| `design/tokens/apps/farmer.json` | farmer overrides, namespaced as `farmer.*` |
| `design/tokens/apps/fa.json` | FA overrides, namespaced as `fa.*` |

Supported `$type`s: `color` (`#RRGGBB` or `#RRGGBBAA`), `dimension` and `number` (plain numbers, `px`
strings accepted), `fontFamily`, `fontWeight` (100-900), `typography` (`fontSize`, `fontWeight`,
`lineHeight` as a multiplier, `letterSpacing`) and `shadow` (one layer or a list). `$type` is inherited from
the nearest group. A value of the form `{group.token}` is an alias; aliases also work inside composite values.

## Outputs

| Format | File |
|---|---|
| `DartFormat` | `mobile/packages/orbit_ui/lib/src/tokens/orbit_tokens.g.dart` |

The Dart file has one `abstract final class` per group, listed in `DartFormat.classes`: `OrbitPalette`,
`OrbitFont`, `OrbitTypeScale`, `OrbitSpace`, `OrbitRadius`, `OrbitSize`, `OrbitElevation`,
`OrbitSemanticColors`, `OrbitFarmerTokens`, `OrbitFaTokens`. Member names are camelCase paths with `base`
dropped (`color.green.base` -> `OrbitPalette.green`, `color.green.strong` -> `greenStrong`,
`space.16` -> `OrbitSpace.s16`). Output is deterministic and already `dart format` clean.

Adding a token group (a new first path segment) fails the build until you map it to a Dart class, so
nothing is dropped silently.

## Adding an output (CSS for web, later)

1. Write a class that implements `TokenFormat`: `outputPath` (relative to the repo root) and
   `render(TokenSet tokens)` returning the whole file. `TokenSet.tokens` is a flat, ordered list of resolved
   `Token`s (`path`, `type`, `value`, `description`, `alias`).
2. Add it to the `formats` list at the top of `build.dart`.

For example a `CssFormat` would write `web/packages/ui/src/tokens/tokens.css` with `--orbit-color-ink:
#1b2420;` on `:root` and the app overrides under `[data-app="farmer"]` / `[data-app="fa"]`. `--check`
covers every format automatically.
