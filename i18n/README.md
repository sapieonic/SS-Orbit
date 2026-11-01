# i18n

Single source for every UI string in the Farmer and FA apps (Telugu first, then English) and for the
recorded Telugu voice prompts. Decisions and the review process are in `implementation-plan.md`.

| File | What |
|---|---|
| `te.json` | Telugu text, flat `key -> ICU message`, keys sorted. The reference language. |
| `en.json` | English text, same keys. |
| `meta.json` | Per key: `description`, `screen`, `voice`, `placeholders` (name -> `type`, optional `format`, `example`), optional `max_len`, `review: "pending"`, `farmer_only`. |
| `deny-list.txt` | Competitor brands and chemical names that must never appear in UI strings. Owned by Agronomy. |
| `voice/te/<key>.m4a` | Recorded prompt for a `voice: true` key (AAC-LC, mono, 24 kHz, ~32 kbps, -16 LUFS, <= 15 s). |

## Add or change a string

1. Pick a key: `<surface>.<screen>.<element>` in snake_case (`farmer.home.call_fa`). Shared words go in
   `common.*`, API errors in `error.<backend_code>`, details sentences in `error.detail.<details_field>`,
   enum labels in `enum.<schema>.<value>`. Never reuse a key for a new meaning; add a new one.
2. Add the key to `te.json`, `en.json` and `meta.json`. Use ICU for variables: `{name}`,
   `{count, plural, =0{...} one{...} other{...}}`. Every placeholder needs a type in `meta.json`
   (`String`, `int`, `num`, `DateTime` with a `format` such as `MMMEd` or `jm`).
3. If you wrote the Telugu yourself (not from the wireframes), add `"review": "pending"` so the Telugu
   reviewer checks it. Remove it once they sign off.
4. Set `"voice": true` if the Listen button should play a recording of this text. Voice prompts cannot
   have placeholders.
5. From `mobile/`, run:

   ```bash
   melos run gen:l10n
   ```

   This checks the files, writes the ARB files and Dart helpers into `mobile/packages/orbit_l10n`, copies
   recordings into `mobile/packages/orbit_voice/assets/voice/te/`, and runs `flutter gen-l10n`.
6. Use it in a screen: `context.l10n.farmerHomeCallFa`. Commit the source and generated files together.

Order and formatting do not matter while editing: the generator rewrites the three JSON files sorted.
See `tools/i18n/README.md` for every check it runs.

## Add a recording

Save it as `voice/te/<key>.m4a` (same name as the key) and run `melos run gen:l10n`. Until a key has a
recording the generator lists it as a warning and the app shows the Listen button as unavailable.
