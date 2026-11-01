# design/fonts

Source font files for every Orbit client. Both families are SIL Open Font License 1.1; each folder keeps its
`OFL.txt`. Static instances, one file per shipped weight (400, 500, 700, 800), so weights render the same on
every renderer. Copies ship in `mobile/packages/orbit_ui/fonts/` (with `OFL-*.txt`).

| Family | Use | Source | Files |
|---|---|---|---|
| Figtree | Latin and all digits (has `₹`) | github.com/erikdkennedy/figtree, `fonts/ttf/` at commit `032dfa7f` (the commit google/fonts `ofl/figtree` is built from) | Regular, Medium, Bold, ExtraBold, ~57 KB each |
| Noto Sans Telugu | Telugu script | github.com/notofonts/telugu release `NotoSansTelugu-v2.005` (the archive google/fonts `ofl/notosanstelugu` is built from), `NotoSansTelugu/unhinted/ttf/` | Regular, Medium, Bold, ExtraBold, ~165 KB each |

Total: about 890 KB uncompressed. google/fonts itself only carries variable fonts for these families; the
statics above come from the same upstream sources. Unhinted Telugu files are used because hinting does nothing
on high-density phone screens and costs ~100 KB per weight.

SHA-256:

```
448d74e778cc9774db27bd86cf451bba982b2e4dc348f610390eb6e3439cf6ca  figtree/Figtree-Regular.ttf
358a4de79ae6c3fd7c6a54fcd778c1101ba376af75b8463e715df6988387bc19  figtree/Figtree-Medium.ttf
71a35e2bd92a05427e2dc9897bab41f8a865800e148238007735b5934508198a  figtree/Figtree-Bold.ttf
c86cc3d813f6af7723474ff78ba1d1351254d1f4d4bfeedf58d9e8ed389b1dc4  figtree/Figtree-ExtraBold.ttf
dcb86a5da09365a2d73d725e429403dca988e6d50c1b1d564579a25dbc18bd29  noto-sans-telugu/NotoSansTelugu-Regular.ttf
92e111010e6399e50f525bc07383c06be762f3b2b12cd509f3d8f04d64e720c1  noto-sans-telugu/NotoSansTelugu-Medium.ttf
44393b05a863057cc2cbfe86623fc20b906b00cf19a2ae9304cdd0f3608889db  noto-sans-telugu/NotoSansTelugu-Bold.ttf
67c8ada8f72e4f61d764e95d9313d21d78cf1163e56bd37c5b0cfc64d0c5f10b  noto-sans-telugu/NotoSansTelugu-ExtraBold.ttf
```

Web (later): convert these to WOFF2 with a Telugu `unicode-range` subset (U+0C00-0C7F) and self-host them;
no Google Fonts runtime call.
