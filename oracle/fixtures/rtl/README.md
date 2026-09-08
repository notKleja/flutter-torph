# RTL / numeric / bidi corpus

`corpus.json` is a hand-curated (script-generated) corpus of RTL, numeric, and
bidi test strings for auditing whether the Flutter port of Torph matches the
upstream JS behavior (`upstream/torph/packages/torph/src/lib/text-morph/utils/number.ts`
and `segment.ts`, pinned at `d79a5aa63226acf97d49c3e34fafb2e85c07b026`) when the
subject text is Arabic, Persian, Hebrew, Urdu, or otherwise right-to-left,
contains non-ASCII digits, currency signs, bidi control characters, or mixed
LTR/RTL runs.

This corpus is read-only test data. It does not itself assert pass/fail; two
sibling audits consume it to compare the Dart segmenter/number engine against
the upstream JS engine and against an independent Unicode Bidi Algorithm (UBA)
reference.

## File

`corpus.json`:

```json
{
  "version": 1,
  "haveBidi": false,
  "cases": [ { ... }, ... ]
}
```

`haveBidi` records whether `ubaVisual` was computed for this corpus (see
"UBA visual order" below).

## Case schema

```jsonc
{
  "id": "RTLC-001",                 // stable, zero-padded, never reused
  "category": "arabic-ascii-digits", // see Categories below
  "text": "السعر 1234 ريال",         // the literal test string
  "direction": "rtl",                // paragraph/base direction the case is rendered under
  "locale": "ar",                    // BCP-47-ish tag: ar | fa | ur | he | en
  "codePoints": ["U+0627", "U+0644", ...], // one entry per Unicode scalar value, in logical (source) order
  "graphemes": ["ال", "س", ...],     // grapheme clusters in logical order (best-effort UAX #29 approximation, see below)
  "notes": "...",                    // why this case exists / what it probes
  "upstreamNumeric": true,           // true | false | "partial" — see below
  "morph": { "to": "..." } | null,        // optional single morph target
  "interrupt": { "to": "...", "then": "..." } | null, // optional A -> B -> C
  "storm": ["...", "...", "...", "..."] | null,       // optional B,C,D,E of an A -> B -> C -> D -> E sequence (A is `text`)
  "ubaVisual": ["...", ...]          // OPTIONAL, only present when haveBidi is true (see below)
}
```

Notes on fields:

- `id` is stable across regenerations of this file — if the corpus is
  regenerated, existing ids keep the same case (same `text`/category slot),
  new cases append with the next unused number.
- `codePoints` is derived directly from `text` (`U+XXXX` per Unicode scalar
  value, uppercase hex, logical/source order — not any reordered/display
  order).
- `graphemes` is a best-effort grapheme-cluster segmentation (base character
  plus any trailing combining marks / Arabic-Hebrew diacritics / ZWJ) computed
  by the generator script, in **logical** (source) order. It approximates
  UAX #29 for the scripts used in this corpus (Latin, Arabic, Hebrew, Persian,
  digits, common punctuation, bidi control characters) but is not a certified
  ICU/UAX29 implementation. Treat it as a convenience reference, not ground
  truth — auditors that need exact grapheme-cluster boundaries should
  cross-check with `Intl.Segmenter`/ICU output for disputed cases.
- `storm` holds only the four states *after* the initial `text` (i.e.
  `[B, C, D, E]` for an `A -> B -> C -> D -> E` sequence, where `A === text`),
  matching the "storm" terminology used elsewhere in this repo's oracle
  fixtures (`oracle/fixtures/runtime/storm-*.json`).
- `interrupt` is `{ "to": B, "then": C }` for an `A -> B -> C` sequence where
  `A === text`.

## `upstreamNumeric`

Ported directly from `isNumericWord` / `CORE_SEPARATORS` /
`PREFIX_CHARS` / `SUFFIX_CHARS` in upstream `number.ts` (see
"UPSTREAM NUMERIC SUPPORT" in `reports/rtl/corpus_report.md` for the full
rule set). For each case, the generator splits `text` on whitespace (matching
`groupIntoWords`'s unit of segmentation) and classifies every word that
contains a decimal digit (ASCII, Arabic-Indic U+0660-U+0669, or Extended
Arabic-Indic/Persian U+06F0-U+06F9):

- `true` — every digit-bearing word in the case satisfies upstream's
  `isNumericWord` (so upstream's `expandNumbers` would re-segment it
  character-by-character with digit/symbol kinds).
- `false` — no digit-bearing word in the case satisfies `isNumericWord` (most
  commonly because the digits are Arabic-Indic/Persian, which `isDigit()`
  never matches since it is `char >= '0' && char <= '9'`, ASCII-only).
- `"partial"` — the case mixes words that do and do not satisfy
  `isNumericWord` (e.g. one clause has a bare ASCII number, another has a
  Persian-digit number; or a single word mixes ASCII and non-ASCII digits).

This is a case-level rollup for convenience; where a case contains multiple
whitespace-separated numeric fragments, see `notes` for the per-fragment
detail.

## UBA visual order

The audit brief asked for an independent Unicode Bidirectional Algorithm
(UBA) expectation, best-effort, using `python-bidi` if available.

**Status in this corpus: not populated.** `python3 -c "import bidi"` failed
(`ModuleNotFoundError`). `pip3 install --user python-bidi` was attempted;
if a later regeneration of this file records `"haveBidi": true` at the top of
`corpus.json`, every case additionally carries `"ubaVisual"` — the
grapheme-clustered result of `bidi.algorithm.get_display(text, base_dir=...)`
(`base_dir="L"` for `direction: "ltr"` cases, `"R"` for `direction: "rtl"`
cases), i.e. the UBA's visual/display order of `text`'s grapheme clusters
under that base direction. Consult `corpus.json`'s top-level `"haveBidi"`
field before assuming `ubaVisual` is present — do not assume from this README
alone, since the corpus can be regenerated independently of it.

## Categories

| category | what it probes |
|---|---|
| `arabic-ascii-digits` | Arabic prose with ASCII (`0-9`) digit runs, currency, times |
| `persian-ascii-digits` | Persian prose with ASCII digit runs, currency, decimals |
| `arabic-indic` | Arabic prose with Arabic-Indic digits (`٠-٩`) and Arabic separators (`٬` U+066C, `٫` U+066B) |
| `persian-digits` | Persian prose with Extended Arabic-Indic / Persian digits (`۰-۹`) |
| `hebrew` | Hebrew prose with ASCII digits, Shekel sign, phone numbers |
| `mixed-latin` | Arabic/Persian/Urdu/Hebrew interleaved with Latin words and numbers at various positions (start/middle/end/adjacent, no-space runs), NBSP/narrow-NBSP grouping, Arabic decimal/thousands separators on ASCII digits, morph pairs, interrupts, storms |
| `punctuation` | Numbers adjacent to Arabic/Latin punctuation (Arabic comma, curly quotes, colon, semicolon, parens) |
| `bidi-controls` | LRM (U+200E), RLM (U+200F), LRI (U+2066), RLI (U+2067), FSI (U+2068), PDI (U+2069) wrapped around numbers |
| `phone` | International phone-number-shaped strings, standalone and embedded in RTL prose |
| `datetime` | ISO/slash/colon-separated dates and times, embedded in RTL prose |
| `newline` | Explicit `\n`-separated multi-line strings with numbers on different lines |
| `pure-number` | Bare numbers (ASCII / Arabic-Indic / Persian) with no surrounding letters, under both `ltr` and `rtl` paragraph direction |
| `pure-rtl` | Pure RTL prose with no digits at all, as a baseline/control |

Most cases use `direction: "rtl"`; a subset of the literal-required strings
and a few representative others are duplicated with `direction: "ltr"` as
paragraph-direction controls for the same text (see `notes` referencing
"LTR-base control of RTLC-NNN").

## Regenerating

The corpus is produced by a script kept outside this repo (in the audit
agent's scratch directory, not checked in) — regenerating it re-derives
`codePoints`, `graphemes`, and `upstreamNumeric` deterministically from
`text`, so hand-edits to those derived fields will be lost on regeneration.
Hand-edit only `notes`, or add new cases with new stable ids, if extending
this file by hand instead of by rerunning the generator.
