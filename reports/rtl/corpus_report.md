# RTL / numeric / bidi corpus report

Corpus: `oracle/fixtures/rtl/corpus.json` (schema and category descriptions in
`oracle/fixtures/rtl/README.md`). Total cases: **162**. `lib/` (production
code) was not modified to build this corpus.

## Category / count summary

| category | count |
|---|---|
| arabic-ascii-digits | 8 |
| persian-ascii-digits | 4 |
| arabic-indic | 9 |
| persian-digits | 8 |
| hebrew | 5 |
| mixed-latin | 81 |
| punctuation | 6 |
| bidi-controls | 9 |
| phone | 6 |
| datetime | 6 |
| newline | 4 |
| pure-number | 13 |
| pure-rtl | 3 |
| **total** | **162** |

The `mixed-latin` bucket is intentionally the largest: it absorbs the audit
brief's required "Mixed" literal strings, all positional variants (start,
middle, end, adjacent-to-Latin, no-space runs), NBSP/narrow-NBSP grouping
cases, Arabic decimal/thousands separators on ASCII digits, and the full
morph-pair / interrupt / storm matrices (since most of those are built on
Arabic text interleaved with ASCII numbers).

### By locale

| locale | count |
|---|---|
| ar (Arabic) | 127 |
| fa (Persian) | 19 |
| he (Hebrew) | 9 |
| ur (Urdu) | 4 |
| en (English, LTR controls) | 3 |

### By direction

| direction | count |
|---|---|
| rtl | 149 |
| ltr (paragraph-direction controls, same strings) | 13 |

### Animated-audit payloads

| kind | count |
|---|---|
| `morph` (single A→B target) | 53 |
| `interrupt` (A→B→C) | 10 |
| `storm` (A→B→C→D→E) | 5 |

The 53 morph cases cover all 7 required pairs (`123→124`, `129→130`,
`999→1,000`, `1,999→2,000`, `9.99→10.00`, `-99→-100`, `$999→$1,000`) across 6
positions each (standalone, isolated-in-RTL-paragraph, before-RTL,
after-RTL, between-two-RTL-phrases, adjacent-to-Latin) = 42, plus 2 Arabic-Indic
and 2 Persian-digit equivalent pairs each embedded/standalone = 8, plus 3
additional direction-control morphs (LTR mirrors of an isolated-in-RTL case
and the `999→1,000` standalone pair in both `ltr` and `rtl` paragraph
direction) = 53 total.

## UPSTREAM NUMERIC SUPPORT

Read directly from
`upstream/torph/packages/torph/src/lib/text-morph/utils/number.ts` (pinned
`d79a5aa63226acf97d49c3e34fafb2e85c07b026`) and cross-checked against the
Dart port `lib/src/core/number.dart` / `lib/src/core/segmenter.dart` (read
only, not modified).

### Digit recognition — ASCII only

```ts
export function isDigit(char: string): boolean {
  return char >= "0" && char <= "9";
}
```

This is a plain code-unit range check against `"0"`–`"9"` (U+0030–U+0039).
It does **not** special-case any other Unicode decimal-digit block. Consequently:

- **Arabic-Indic digits** (`٠-٩`, U+0660–U+0669) are **not** recognized as
  digits.
- **Extended Arabic-Indic / Persian digits** (`۰-۹`, U+06F0–U+06F9) are
  **not** recognized as digits.
- Only **ASCII `0`–`9`** is numeric for every purpose downstream of
  `isDigit`: `hasDigit`, `numericSkeleton`, `isNumericWord`,
  `classifyKind`, and `segmentNumber`'s per-character digit/symbol kind
  assignment.

The Dart port (`lib/src/core/number.dart`) mirrors this exactly:

```dart
bool isDigit(String char) =>
    char.length == 1 && char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;
```

— same ASCII-only range, same behavior. **This is a faithful, not a
divergent, port** as far as digit recognition goes; any RTL/numeric parity
gap in the Dart runtime is not in this function.

### `isNumericWord` — what counts as a numeric token

A whitespace-delimited word (per `groupIntoWords`, which splits on ` `
and `\n`) is numeric if, after trimming a *prefix run* of `PREFIX_CHARS` from
the front and a *suffix run* of `SUFFIX_CHARS` from the back, the remaining
core is non-empty, starts and ends with an ASCII digit, and every character
in it is either an ASCII digit or one of `CORE_SEPARATORS`.

```ts
const CORE_SEPARATORS = ".,'    ";
const PREFIX_CHARS = "+-−(#";
const SUFFIX_CHARS = "%.,!?:;)\"'”’";
const CURRENCY = /\p{Sc}/u;   // any Unicode "Currency Symbol" (Sc) code point
```

`isAffix(char, set)` treats a character as a valid prefix/suffix if it is
either literally in `PREFIX_CHARS`/`SUFFIX_CHARS` **or** matches `\p{Sc}`
(so `$`, `€`, `£`, `¥`, `₪`, `₹`, etc. are all valid affixes on either side,
in addition to the ASCII sign/punctuation characters listed explicitly).

Recognized **core separators** (chars allowed *between* digits without
breaking numeric-ness): ASCII period `.`, ASCII comma `,`, apostrophe `'`,
NBSP (`U+00A0`), narrow no-break space (`U+202F`), thin space (`U+2009`),
figure space (`U+2007`).

**Not** recognized as separators (so a token containing them fails
`isNumericWord` as a single unit, even with ASCII digits on both sides):
Arabic decimal separator `٫` (U+066B), Arabic thousands separator `٬`
(U+066C), colon `:`, slash `/`, hyphen `-` (hyphen is a *prefix* char only,
not a mid-token separator — `"2024-01-01"` and `"COVID-19"` are the
motivating counter-examples in the upstream source comment), space (plain
ASCII `U+0020` — only the exact set above is "core"; groupIntoWords also
already treats NBSP/newline as word boundaries so ordinary spaces are moot as
word-internal characters here).

Recognized **prefix** characters (before the digit core): `+`, `-`, minus
sign `−` (U+2212), `(`, `#`, and any `\p{Sc}` currency symbol.

Recognized **suffix** characters (after the digit core): `%`, `.`, `,`, `!`,
`?`, `:`, `;`, `)`, `"`, `'`, right double quotation mark `”` (U+201D), right
single quotation mark `’` (U+2019), and any `\p{Sc}` currency symbol.

The Dart port (`lib/src/core/number.dart`) implements the identical
algorithm with an identical `CORE_SEPARATORS`/`PREFIX_CHARS`/`SUFFIX_CHARS`
string and an explicit `_currencyUnits` set that is a materialized BMP
enumeration of the Unicode 17 `Sc` category (since Dart has no native
`\p{Sc}` regex class matching Unicode's live category assignments) — the
comment in the Dart source notes this was tested "against one UTF-16 code
unit: only BMP currency symbols can match, a lone surrogate never does",
i.e. any non-BMP currency symbol (none exist in Unicode 17 to date) would be
a theoretical, not actual, divergence.

### Practical consequences for this corpus

- Any case whose digits are Arabic-Indic or Persian (categories
  `arabic-indic`, `persian-digits`, and the corresponding entries folded into
  `mixed-latin`/`datetime`/`phone`/`mixed-latin` morph cases) has
  `upstreamNumeric: false` — upstream's `expandNumbers` pass in `segment.ts`
  leaves that word as an ordinary word/grapheme segment; it is **not**
  re-cut into per-character digit/symbol segments, so a Torph morph
  animation over that text would **not** get the per-digit column-alignment
  behavior (`segmentNumber`'s place-matching, magnitude-jump detection,
  etc.) that ASCII-digit numbers get. This is the single highest-value
  parity question for the two sibling audits to check against the Dart
  runtime: does the Flutter port's `isNumericWord`/`isDigit` (verified above
  to be a faithful ASCII-only port) actually get exercised identically by
  whatever RTL text shaping / bidi reordering happens before segmentation?
- Cases with Arabic decimal (`٫` U+066B) or thousands (`٬` U+066C)
  separators **on ASCII digits** (e.g. `"السعر 1234٫56 ريال"`,
  `"السعر 1٬234٬567 ريال"`) have `upstreamNumeric: false` for that
  fragment even though every digit is ASCII, because the separator itself
  isn't in `CORE_SEPARATORS` — the token fails the "every character is a
  digit or a core separator" scan.
- Cases with NBSP/narrow-NBSP thousands grouping on ASCII digits (e.g.
  `"السعر 1 234 567 ريال"`) have `upstreamNumeric: true` for that
  fragment — those two whitespace-like characters are explicitly
  whitelisted as core separators, so despite looking like "spaces" they do
  not break the token the way a plain space would (a plain space would
  already be a word boundary before `isNumericWord` even runs, per
  `groupIntoWords`).
- Colon-separated times (`"10:45"`, `"14:30"`, `"12:34"`) and
  slash-separated dates (`"08/09/2026"`) have `upstreamNumeric: false` (or
  `"partial"` at the case level, since a case can contain other,
  fully-numeric fragments) as single tokens, since `:` and `/` are neither
  separators nor affixes.
- Hyphenated phone numbers and ISO dates (`"2024-01-01"`-shaped strings)
  are the exact motivating counter-example in the upstream source comment
  and are `upstreamNumeric: false`/`"partial"` as single tokens for the
  same reason: `-` is a prefix-only character, not a mid-token separator.

Each case in `corpus.json` carries `"upstreamNumeric": true | false |
"partial"` — `"partial"` marks a case whose whitespace-delimited words
disagree (some numeric, some not, per the rules above); see the `notes`
field on each such case for the specific fragment-level reasoning.

## Independent UBA expectation

`python3 -c "import bidi"` initially failed (`ModuleNotFoundError`) because
`pip3 install --user python-bidi` (invoked via the ambient `pip3`, which
targets a Python 3.9 user site) did not match the ambient `python3`
(Python 3.14, a separate `Library/Frameworks/Python.framework` interpreter
with its own site-packages). Installing again with
`/Library/Frameworks/Python.framework/Versions/3.14/bin/python3 -m pip
install --user python-bidi` succeeded (`python-bidi` 0.6.11, a wrapper over
the Rust `unicode-bidi` crate), and `import bidi.algorithm` now resolves
under the `python3` used to generate the corpus.

**`ubaVisual` is populated for all 162 cases** (`corpus.json`'s top-level
`"haveBidi"` is `true`). For each case it is
`bidi.algorithm.get_display(text, base_dir=("L" if direction == "ltr" else
"R"))`, re-segmented into the same best-effort grapheme clusters as the
`graphemes` field, i.e. the UBA's visual/display order of the case's
grapheme clusters under the case's stated paragraph base direction. This is
an independent (non-upstream, non-Dart) reference for what a UBA-conformant
renderer should show — useful to the sibling audits as a check on whatever
visual reordering, if any, the Flutter/Skia text layer performs, separate
from Torph's own logical-order segmentation and diffing.

Spot check (`RTLC-001`, `"السعر 1234 ريال"`, `direction: "rtl"`): the ASCII
digit run `1234` stays in left-to-right logical order inside the
visually-mirrored Arabic runs on either side of it (`ريال` → mirrored to
`ل ا ي ر`, then `1 2 3 4` unchanged, then `السعر` → mirrored to `ر ع س ل ا`),
matching the expected UBA behavior for a European-number run embedded in an
RTL paragraph.

## Notes for the sibling audits

- This corpus intentionally includes both `rtl`- and `ltr`-base variants of
  several literal-required strings (search `notes` for "LTR-base control")
  so a parity check can isolate "does paragraph direction change the
  segmentation/animation" from "does the text's own script change it."
- `id`s are stable (`RTLC-001`…`RTLC-162`) and will not be renumbered on
  future regenerations of this corpus; new cases append.
- No test files were written and no files under `lib/` or `spec/*.md` were
  modified in the course of building this corpus.
