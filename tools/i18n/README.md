# tools/i18n

`build.dart` turns `i18n/te.json`, `en.json` and `meta.json` into the Flutter string package and checks
them. Plain Dart (SDK libraries only), deterministic, and safe to run from any directory: paths resolve
from the script's location.

```bash
cd mobile
melos run gen:l10n                          # build.dart, then flutter gen-l10n in orbit_l10n
dart run ../tools/i18n/build.dart           # generator only
dart run ../tools/i18n/build.dart --check   # CI: exit 1 if anything is stale; writes nothing
```

Options: `--check`, `--root <repo>` (default: two levels above the script), `--help`.

## Outputs

| Path | Contents |
|---|---|
| `i18n/{te,en,meta}.json` | Rewritten sorted with 2-space indent (so `--check` fails on unsorted files). |
| `mobile/packages/orbit_l10n/lib/l10n/app_te.arb`, `app_en.arb` | ARB, `farmer.home.call_fa` -> `farmerHomeCallFa`. Te is the template and carries `@key` metadata (description, placeholders, `x-key`, `x-screen`). |
| `mobile/packages/orbit_l10n/lib/src/voice_keys.g.dart` | `VoiceKeys` constants, `voiceAssetPaths` (every voice key) and `recordedVoiceKeys` (the ones with a file). |
| `mobile/packages/orbit_l10n/lib/src/lookups.g.dart` | `errorMessageFor` / `errorDetailFor` / `enumLabelFor` switches, `knownErrorCodes`, `enumSchemas` and the `labelX(value)` helpers. |
| `mobile/packages/orbit_l10n/test/all_messages.g.dart` | Every message rendered with sample arguments, for the "every key resolves" test. |
| `mobile/packages/orbit_voice/assets/voice/te/` | Copies of `i18n/voice/te/<key>.m4a` for voice keys, plus `.gitkeep`. Bundled files without a source are deleted. |

Generated Dart is passed through `dart format` from the running SDK (pinned by FVM), so `dart format .`
never fights the generator. `flutter gen-l10n` (run by the melos script) then writes
`orbit_l10n/lib/l10n/generated/`.

## Checks

Errors (exit 1):
- JSON is valid; every value is a string; keys are dotted snake_case; no two keys map to one ARB name;
  `label.*` and `describe.*` are reserved.
- Same key set in `te.json`, `en.json` and `meta.json` (English may be missing only when meta has
  `"farmer_only": true`; the app then falls back to Telugu).
- No empty Telugu (or English) text.
- ICU syntax is valid and is the subset `flutter gen-l10n` parses: `{x}`, `{x, plural, ...}` (cases
  zero/one/two/few/many/other/=0/=1/=2), `{x, select, ...}` and `{x, date|time, ::skeleton}` with a skeleton
  gen-l10n knows. `{x, number}`, `selectordinal`, `offset:`, other `=N` cases, date styles like `short`,
  case names that are keywords (`date`, `plural`...) and names starting with a digit fail here instead of
  half-way through gen-l10n. `#` inside a plural fails too: gen-l10n would print it as is.
- Plural/select has an `other` case; placeholders used in te and in en exactly match the ones declared in
  meta; plural arguments are `int`/`num`, select `String`, date/time `DateTime`.
- `max_len`: the longest rendering (each plural case; placeholders counted by their `example`) of te and of
  en, in Unicode code points.
- No deny-list term in te or en (whole-word match for Latin terms, substring for Telugu).
- Meta entries have `description`, `screen`, `voice`, `placeholders` and no unknown fields; DateTime
  placeholders have a `format`; a placeholder `example` is a string.
- `voice: true` keys have no placeholders; `error.<code>` and `enum.*` keys have none;
  `error.detail.<field>` has exactly one (`int`, `num` or `String`).
- With `--check`: any output (including the sorted source JSON) differs from what would be written.

Warnings (listed, exit 0): a voice key without `i18n/voice/te/<key>.m4a`; a recording whose key is not a
voice key (not bundled).

Not built yet: the plan's `voice/te/manifest.json` stale-audio check (no recordings or recording tool
exist yet), and the web locale output (`web/packages/i18n/src/locales/`), which waits for the web package.
