# Orbit components

One row per shared component. Flutter builds live in `mobile/packages/orbit_ui/lib/src/components/`. React
builds (`web/packages/ui`) follow the same names, props, states and tokens.

All components take already-localised strings; none has text of its own. "Bilingual" means an optional
smaller English line under the Telugu one. Colour roles refer to Material's `ColorScheme` (built from
`semantic.json` + the app file) and the `OrbitColors` theme extension (`success`, `warning`, `danger`, `info`
and severity tones, each `fg` / `strong` / `tint`).

| Component | Props | States | Tokens and colour roles | Wireframe |
|---|---|---|---|---|
| OrbitButton | label, secondaryLabel, onPressed, variant, size, icon, fullWidth, loading | enabled, pressed, disabled (no onPressed), loading (spinner, taps ignored); variants primary, secondary, danger, call | height `size.control.lg/xl/xxl` (48/56/64); radius `radius.lg`; label `type.label-lg` (hero: `type.h3`); primary/onPrimary, surface + outline + secondary, error/onError, success.fg + onPrimary | all |
| ListenButton (inline, floating) | label, secondaryLabel, onPressed, state | idle, loading, playing, unavailable (muted, still tappable) | inline 48 dp pill: primaryContainer/onPrimaryContainer, playing primary; floating 56 dp: inverseSurface/onInverseSurface, `elevation.e3`; icons listen, stop, listenUnavailable | F1-F11 |
| ScreenHeader | title, subtitle, onBack, listen, trailing, tone | surface, primary, inverse tone; with/without back; listen + trailing capped at 40% of the width (long labels wrap, then stack) | title `headlineMedium` = app `screen-title` (farmer `type.h1`, FA `type.h2`); sub `type.caption`; bars use OrbitColors.onPrimaryBar | every screen |
| StateCard | icon, title, subtitle, message, action, listen, tone | neutral, info, warning, danger | card `radius.lg`, border outlineVariant; icon disc tone.tint + tone.strong, `size.icon.xxl`; title `type.h2` | empty, offline, error states |
| IconTile, IconTileGrid | icon, label, secondaryLabel, onTap, locked, lockedSemanticLabel, badge; grid columns | normal, locked (padlock, muted disc, still tappable), with badge | min height `size.tile.min-height` (112); disc primaryContainer; badge highlight/onHighlight; label `type.label-lg` + `type.caption` | F2 Home (FAR-06) |
| FaCard | name, initials, image, subtitle, detail, tag, verified, highlighted, callLabel/onCall, whatsAppLabel/onWhatsApp, onTap | your FA (highlighted, primary border), plain; actions optional | avatar `size.avatar.md`, primaryContainer; tag OrbitTag primary; Call = OrbitButton call (medium), WhatsApp = secondary | F2, F3 |
| NoticeCard | source, meta, title, body, secondaryBody, pinned/pinnedLabel, unread/unreadLabel, actions, onTap | pinned (primary border + pin tag), unread (primary dot + heavier title), read | source tag neutral; title `type.h3`; body app body | F5 |
| StatusPill | label, tone, icon | success, warning, danger, info, neutral (each with a default icon) | tone.tint background, tone.strong text and icon; `type.micro`; `radius.pill` | FA calendar, F8, F9 |
| SeverityPill | severity, label | low, moderate, high (signal-low/medium/high icons) | severity tones, tint + strong | F4, FA visit log |
| OrbitTag | label, tone, icon | neutral, primary, highlight | surfaceContainerHighest/onSurfaceVariant, primaryContainer/onPrimaryContainer, highlight/onHighlight | F2 plan badge, F5 source |
| AdviceResult (.product, .saltOnly) | heading, secondaryHeading, name, dose, note, action | product found (success tint, package-check icon), salt only (sunken, shop icon) | name `type.h2`; heading `type.label-lg` in tone.strong | F4, F8a, F8b |
| OrbitBanner | kind, title, message, savedAt, action | offline (warning), info (primary), success, error (danger); live region | tone.tint fill, tone.fg border, tone.strong text | offline states, FA errors |
| PhoneField | controller, label, hint, helperText, errorText, countryCode, onChanged, onSubmitted, enabled, autofocus | empty, filled, focused, error, disabled | digits `type.h2`; border outline (`color.line-input`), focus primary 2 px, error red | F1 |
| OtpInput | length, controller, onChanged, onCompleted, errorText, semanticLabel, enabled, autofocus | empty, typing (active box primary 2 px), complete, error (red borders + live message) | boxes `size.control.xxl` tall, `radius.lg`; digits `type.h1` | F1, FA consent OTP |
| InlineError | message | - (live region) | alert icon danger.fg `size.icon.md`; text app body in danger.strong | F1 phone and OTP errors |
| ChoiceTile | label, secondaryLabel, icon, tag, selected, onTap | selected (primaryContainer fill, primary 2 px border, tick), unselected (surface, outline), disabled (no onTap); announced as selected in a one-of group | min height `size.control.xl` (56); `radius.lg`; icon `size.icon.xl` | F10 start season, close season |
| SegmentedTabs | labels, selectedIndex, onChanged | selected (surface + `elevation.e1`, onPrimaryContainer text), unselected, disabled | track surfaceContainerHighest, `radius.lg`; segments 48 dp, `radius.md` | F3 |
| SectionHeader | title, secondary, trailing | - | title `type.h3`; secondary `type.caption` onSurfaceVariant | F2, F8, F11 |
| StepLayout, StepQuestion | title, step, totalSteps, stepLabel, subtitle, onBack, listen, child, action; question text, helper | step n of m (progress bar primary), action pinned above the keyboard | header = ScreenHeader; question `type.h2` (titleLarge) as a header; helper body onSurfaceVariant | F10 add plot, start season |
| LoadMoreFooter | loading, errorText, onLoadMore, loadingLabel, retryLabel | loading (spinner, labelled), error (message + secondary Try again) | button OrbitButton secondary medium | F4, F5 long lists |
| StageStrip | stages, currentIndex, progress, progressLabel, currentLabel, doneLabel, axis | done (success disc + tick), current (primary disc + ring, bold label), upcoming (outline ring); horizontal or vertical | connectors success.fg / outlineVariant; progress bar primary on surfaceContainerHighest | F11 |
| OrbitNavigationBar | destinations (icon, label, selectedIcon, badge), selectedIndex, onDestinationSelected | selected (primaryContainer indicator, onPrimaryContainer icon and bold label), unselected; labels always shown | height grows with text scale; top border outlineVariant | F2-F11 bottom bar |
| InfoRow | icon, text, secondaryText, trailing | - | icon onSurfaceVariant `size.icon.lg`; text app body-lg | F2 next visit |
| KeyValueRow | label, value, secondaryValue | - | key onSurfaceVariant; value `type.label-lg` | F8 check and book |
| BilingualText | primary, secondary, primaryStyle, secondaryStyle, textAlign | - | Telugu `type.label-lg` (16/700) over English `type.caption` (13/500) | everywhere |

Rules every component follows: touch targets of at least 48 dp; text wraps and is never cut with an
ellipsis; status is never shown by colour alone; standalone icons have a semantic label; colours come from
the theme, never from token constants, so the FA and farmer apps differ only by theme.
