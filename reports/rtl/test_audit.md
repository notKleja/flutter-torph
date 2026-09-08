# RTL / bidi blind-spot audit of the existing test suite

Scope: `test/widget/alignment_test.dart`, `test/widget/semantics_test.dart`,
`test/parity/widget_adversarial_test.dart` (RTL section),
`test/parity/runtime_trace_parity_test.dart`, `test/parity/widget_trace_parity_test.dart`,
`test/fuzz/morph_fuzz_test.dart`, `test/core/*`, `test/motion/*`, plus a
whole-tree grep for Arabic/Hebrew/Persian script, `rtl`, Arabic-Indic digits and
bidi control characters. Cross-referenced against `spec/RENDERER_CONTRACT.md`
§4 and `spec/QUESTION_LEDGER.md` Q-025.

## 1. Which tests assert visual x-order vs. string/segment equality only?

Tests that assert **visual x position** (`item(...).x`, i.e.
`ItemFrame.x`, the pre-transform box position — see caveat below) in an RTL
root:

- `test/widget/alignment_test.dart:44-52` — `'RTL flows the items from the
  right, in logical order'`: `snapshot.item('aaa').x` / `snapshot.item('b').x`.
- `test/widget/alignment_test.dart:54-63` — `'RTL keeps logical order within a
  line'`: `snapshot.item('ab').x` == 60, `snapshot.item('cd').x` == 0. This is
  the only place a *multi-item single line* RTL x-order is asserted end to end
  through the widget, and both items are plain Latin words.
- `test/widget/alignment_test.dart:90-95` (`TextMeasurer` unit test, RTL,
  overflow case) — `result.offsets['i0']!.x`.
- `test/parity/widget_adversarial_test.dart:462-472` —
  `'a Directionality flip mid-morph re-lays out from the other edge'`:
  `rtl.item('world').x`, compared with `rtl.item('h').x` via `lessThan` /
  `greaterThan`. Latin words only.
- `test/parity/runtime_trace_parity_test.dart:266-268` (`_near(... 'rect.x' ...,
  vr.left ...)`) — asserts `visualRect.left` (post-transform) for **every
  item in every one of the 18 `rtl-*` traces**, per animation frame, against
  the browser's recorded `rect.x`. This is the only place visual left-edge
  position is checked against an independent (browser) oracle rather than
  against a hand-computed expected value. Caveat: the "engine" here is fed by
  `TraceMeasurer`, a hand-rolled re-implementation of the RTL placement rule
  (`runtime_trace_parity_test.dart:81-84`, `x = rtl ? left + lineWidths[li] -
  run - w : ...`) built from the trace's own widths — it does **not** exercise
  the real `TextMeasurer`/`TextPainter` pipeline. It validates the *motion
  engine's* transform math, not whether Flutter's real text layout agrees with
  the browser's item placement.
- `test/parity/widget_trace_parity_test.dart` — the widget-level counterpart:
  it drives real `TextMorph` widgets with the real `TextMeasurer` (real
  `TextPainter`/`dart:ui` layout) and asserts translated/scaled rect positions
  against the same 18 `rtl-*` traces (see `_runWidgetTrace`, further down the
  file past what was read here — same `rect.x`/`rect.y` style comparison
  pattern as the runtime version). This is the one place the *real* Flutter
  bidi/layout stack is checked against the browser oracle for RTL, including
  the three digit-morph traces (`rtl-999-1-000-744888.json`,
  `rtl-center-999-1-000-0c9522.json`, `rtl-end-999-1-000-651d48.json`).

Tests that assert only **string/segment equality** (label text, semantics
label, or logical segmentation) with no positional check at all:

- `test/widget/semantics_test.dart:29-38` — `'the label follows the
  direction'`: asserts `node.label == 'مرحبا'` and `node.textDirection ==
  TextDirection.rtl`. No geometry assertion — it cannot catch a visual-order
  bug because the semantics label is always the plain logical string.
- `test/widget/semantics_test.dart:40-46` — numeric semantics label
  (`'1,234'`) is LTR-only, not relevant to RTL but worth noting no RTL+digit
  semantics test exists at all.
- `test/fuzz/morph_fuzz_test.dart` — the alignment invariant checked per
  sequence (`_checkAlignment`-style logic around line 377-420) recomputes the
  *expected* left/x from the **same formula** the production `TextMeasurer`
  uses (`resolved`, `alignmentCanShift`, `free`, `rtl ? free : 0.0`, etc.). It
  is a self-consistency/regression check against the implementation's own
  algorithm, not an independent oracle — it would not flag "digits reversed"
  because the expected value is derived by re-deriving the same rule under
  test, not by an outside source of truth (browser trace or plain-Flutter
  reference).

## 2. Multi-digit numbers inside an RTL root — is visual digit order asserted?

Yes, but only via the 18 `rtl-*` oracle traces, not via any hand-written test
in `alignment_test.dart` / `widget_adversarial_test.dart` / `semantics_test.dart`.

Three of the 18 `oracle/fixtures/runtime/rtl-*.json` fixtures morph a number:
`rtl-999-1-000-744888.json`, `rtl-center-999-1-000-0c9522.json`,
`rtl-end-999-1-000-651d48.json` (label e.g. `rtl "999" -> "1,000"`). Reading
the fixture directly (not a test assertion, but the ground-truth data these
tests replay):

```
resting sample, value "1,000", direction rtl:
  "1"  x=48.1875
  ","  x=36.1406
  "0"  x=24.0938
  "0"  x=12.0469
  "0"  x=0
```

Read left→right by x, the browser (and the trace-driven engine/widget tests
that reproduce it) places the digits as **`0 0 0 , 1`** — i.e. the digit glyphs
are individually flowed right-to-left in logical order, so a human reading the
screen left-to-right sees the number's digits in *reverse* order, not `1,000`.
This is asserted implicitly by `runtime_trace_parity_test.dart` (`vr.left`
== `rect.x` per item) and `widget_trace_parity_test.dart`, but only as "does
the engine/widget reproduce whatever the browser did," never as an explicit,
readable assertion like "the digit '1' is left of the digit '0'." No test
states this reversal as a human-readable invariant, so a regression that
silently changes the *sign* of the rule (e.g. someone "fixes" it to be
UBA-correct) would surface only as an opaque tolerance failure inside a
168-case parametrised loop, with no test name or comment pointing at "digit
order."

This behavior is not accidental: it is the resolved, certain-confidence answer
to `spec/QUESTION_LEDGER.md` Q-025, codified in `spec/RENDERER_CONTRACT.md` §4
as "RTL: `x_i = left + lineWidth − Σ_{j≤i} width_j` (items flow from the
right, logical order preserved — no bidi reordering)," and implemented
verbatim in `lib/src/rendering/text_measurer.dart` with the comment "Items
flow from the right in logical order — no bidi reordering of items, which is
what the browser does with inline-block spans." So today's answer to
"UBA-correct vs. logical-order-reversed" is: Torph (upstream JS and this
port) deliberately implements per-segment reversal to match the browser's
inline-block rendering, which is *not* full Unicode Bidi Algorithm behavior
for a numeric run (UBA keeps the digits of one number together and in
left-to-right internal order as a single European-Number run). Because each
digit is its own `MorphItem`/inline-block segment (segmentation happens above
the measurer), the measurer has no way to know "these five items are one
number" and so reverses them individually along with everything else. Whether
that is the product's intended behavior for *this* port (matching upstream
pixel-for-pixel) or a bug relative to real RTL text rendering is exactly the
open adjudication question — the audit's job is only to document that no test
states the invariant in readable form and that no test exercises it with
*actual Arabic words surrounding the number* (see below).

## 3. Actual RTL-script text in tests?

Yes:

- `test/widget/semantics_test.dart:31` — `'مرحبا'` (Arabic, "hello"), used
  only for a semantics-label/direction check, no geometry.
- `test/fuzz/morph_fuzz_test.dart:118` — corpus case 10:
  `['مرحبا', 'مرحبا بالعالم', 'بالعالم مرحبا']` (Arabic "hello", "hello
  world", "world hello"), picked independently of the numeric corpus cases
  (3, 4, 5, 6, 11) — i.e. the fuzzer never combines Arabic words and digits in
  the same value, and never produces something like "السعر 1234 ريال".

No Hebrew or Persian-specific script (Persian reuses the Arabic block; no
Persian-only characters, e.g. ک/گ/پ/چ/ژ, appear) and no Arabic-Indic or
Extended Arabic-Indic digits (`٠-٩` / `۰-۹`) anywhere in `test/`. No bidi
control characters (LRM/RLM U+200E/U+200F, isolates U+2066-U+2069) anywhere in
`test/`.

`oracle/fixtures/runtime/*.json` (not test code, but the data the parity
tests replay) has three RTL fixtures with real Arabic text
(`rtl-78d026.json`, `rtl-center-37a775.json`, `rtl-end-00c761.json`, all
labelled `rtl "مرحبا" -> "مرحبا بالعالم"` / `-center` / `-end` variants) — see
full list in §5. None of the 18 mixes Arabic script and digits in one value.

## 4. Do any tests compare Torph's rendering against a plain Flutter Text/TextPainter reference?

No. Nothing in `test/widget/*`, `test/parity/*`, `test/fuzz/*`,
`test/core/*`, or `test/motion/*` builds a plain `Text`/`TextPainter` (or a
`RenderParagraph`) as an independent reference and diffs Torph's item
positions or Torph's semantics against it. The two sources of truth used
anywhere in the suite are (a) hand-computed expected numbers derived from the
documented placement formula (alignment_test.dart, fuzz test), and (b) the
browser oracle traces (parity tests). Nothing checks Torph against what
Flutter's own paragraph/bidi resolution would do for the same logical string
laid out as one run (which is precisely what would surface a UBA-vs.-reversed
discrepancy for "1,000" or "السعر 1234 ريال", since a single
`TextPainter`/`RenderParagraph` given that whole string would apply real ICU
bidi resolution — keeping "1234"'s internal digit order intact — while
Torph's segment-flow rule would not).

## 5. The 18 `rtl-*` traces — script content, by label

| file | label | script |
|---|---|---|
| rtl-78d026.json | rtl "مرحبا" -> "مرحبا بالعالم" | Arabic |
| rtl-999-1-000-744888.json | rtl "999" -> "1,000" | digits only |
| rtl-a-nbb-a-nbbbbbb-5b56e8.json | rtl "a\nbb" -> "a\nbbbbbb" | Latin |
| rtl-abc-abcdef-fd00b3.json | rtl "abc" -> "abcdef" | Latin |
| rtl-center-37a775.json | rtl-center "مرحبا" -> "مرحبا بالعالم" | Arabic |
| rtl-center-999-1-000-0c9522.json | rtl-center "999" -> "1,000" | digits only |
| rtl-center-a-nbb-a-nbbbbbb-73837e.json | rtl-center "a\nbb" -> "a\nbbbbbb" | Latin |
| rtl-center-abc-abcdef-989b9f.json | rtl-center "abc" -> "abcdef" | Latin |
| rtl-center-hello-world-hello-79d181.json | rtl-center "hello world" -> "hello" | Latin |
| rtl-center-hello-world-world-hello-076842.json | rtl-center "hello world" -> "world hello" | Latin |
| rtl-end-00c761.json | rtl-end "مرحبا" -> "مرحبا بالعالم" | Arabic |
| rtl-end-999-1-000-651d48.json | rtl-end "999" -> "1,000" | digits only |
| rtl-end-a-nbb-a-nbbbbbb-82c0cf.json | rtl-end "a\nbb" -> "a\nbbbbbb" | Latin |
| rtl-end-abc-abcdef-317d90.json | rtl-end "abc" -> "abcdef" | Latin |
| rtl-end-hello-world-hello-6d69fa.json | rtl-end "hello world" -> "hello" | Latin |
| rtl-end-hello-world-world-hello-b64476.json | rtl-end "hello world" -> "world hello" | Latin |
| rtl-hello-world-hello-dab72c.json | rtl "hello world" -> "hello" | Latin |
| rtl-hello-world-world-hello-4e8842.json | rtl "hello world" -> "world hello" | Latin |

Summary: 3 Arabic-script, 3 digits-only, 12 Latin-only. **None combine
RTL script and digits in the same value.** No Hebrew, Persian-only, or
Arabic-Indic-digit fixture exists among the 18, or anywhere else in
`oracle/fixtures/runtime/`.

## 6. Minimal assertion to catch "digits inside RTL text visually reversed"

Using the existing `TextMorphSnapshot`/`ItemFrame` API
(`test/widget/harness.dart`'s `snapshotOf(tester)`, `lib/src/debug/morph_snapshot.dart`,
`lib/src/motion/morph_engine.dart`'s `ItemFrame.visualRect`):

```dart
await tester.pumpWidget(host(TextMorph(value: 'السعر 1234 ريال'),
    direction: TextDirection.rtl));
final snapshot = snapshotOf(tester);

// Pull out the four digit items by their logical text, in logical order.
final digitTexts = ['1', '2', '3', '4'];
final lefts = [for (final t in digitTexts) snapshot.item(t).visualRect.left];

// UBA-correct candidate: digits keep their written left-to-right order,
// i.e. '1' is left of '2' is left of '3' is left of '4' (a monotonically
// increasing sequence), even though the number sits inside an RTL line.
expect(lefts, orderedEquals(lefts.toList()..sort()));
```

The minimal, direction-agnostic form of the invariant is: **for any run of
items that are consecutive digits of one written number, their
`visualRect.left` values must be monotonically increasing in the same order
the digits were typed** (`lefts[i] < lefts[i+1]` for `i`-th vs `(i+1)`-th
digit). Today's implementation does not preserve this for RTL roots (see §2);
whether it should is the adjudication question, not something this audit
decides. The Arabic-words-around-the-number half of the invariant ("ريال"
appears at a smaller x than "السعر" — i.e. the *words* are still correctly
placed by logical order flowing from the right, which nothing here disputes)
can be asserted the same way: `snapshot.item('السعر').visualRect.left >
snapshot.item('ريال').visualRect.left`.

## 7. Blind spots (numbered, severity, proposed test name)

1. **(P0)** No test combines RTL script text with embedded digits in one
   value (e.g. `"السعر 1234 ريال"`, a price string) at any layer — not in
   `alignment_test.dart`, not in `semantics_test.dart`, not in the fuzz
   corpus (which picks Arabic-only or digit-only values, never both), and not
   in any of the 18 oracle traces. This is exactly the shape of input where a
   UBA-vs.-segment-reversal divergence would be visible and it is completely
   untested.
   Proposed test: `rtl_regression_draft_test.dart` → `'a number embedded in
   RTL Arabic text keeps its digits in written order'` (or the inverse
   candidate, pending adjudication).

2. **(P0)** No test asserts multi-digit visual order as a human-readable
   invariant (`left < left < left ...` across digit glyphs). The only signal
   today is the byte-for-byte trace replay in
   `runtime_trace_parity_test.dart` / `widget_trace_parity_test.dart`, which
   is opaque (a tolerance diff against a JSON fixture) and would not read as
   "digit order broke" in a failure message, and only ever replays what the
   browser already recorded — it cannot ask "is this actually correct," only
   "did we reproduce the recording."
   Proposed test: `'RTL "999" -> "1,000": at rest the digits read left-to-right
   as written'` (skeleton in the draft file).

3. **(P1)** No test compares Torph's item placement against a plain
   `TextPainter`/`RenderParagraph` laid out with real ICU bidi resolution for
   the same logical string. Without that reference, there is no
   implementation-independent way for the suite itself to tell "matches
   upstream's browser behavior" apart from "matches real bidi correctness" —
   they are conflated because the only oracle in the repo is the browser
   trace, which encodes the *same* segment-reversal design as the port.
   Proposed test: `'plain Flutter TextPainter vs. Torph: RTL digit run
   placement'` (comparison helper skeleton in the draft file).

4. **(P1)** No RTL morph (as opposed to a static render) exercises a number
   transition with Arabic text present. The three `rtl-*-999-1-000-*` traces
   morph `"999"` → `"1,000"` in isolation (no surrounding words at all), so
   there is no coverage of "a digit block moving/scaling mid-morph while
   sitting between two Arabic words," which is the realistic product
   scenario (a price counter in an Arabic-locale UI).
   Proposed test: `'RTL morph 999 -> 1,000 embedded in Arabic text: digit
   order holds at 100%%'` (skeleton in the draft file).

5. **(P1)** No test covers Hebrew or Persian-specific script at all (only
   Arabic). Torph's segment-reversal rule is presumably script-agnostic (it
   operates on `MorphItem` segments regardless of script), but nothing
   verifies that, and Hebrew in particular differs from Arabic in having no
   contextual shaping, which could interact differently with the width
   cache/painter reuse in `TextMeasurer`.
   Proposed test name (not drafted, flagged only): `'Hebrew RTL root: item
   flow direction matches Arabic'`.

6. **(P2)** No test covers Arabic-Indic or Extended Arabic-Indic digits
   (`٠-٩`, `۰-۹`), which many real Arabic/Persian locales use instead of
   European digits for numeric display, and which `NumberFormat`-driven
   locales could plausibly produce. Whether Torph's `numbers: true` grouping
   engine (segment.dart) even recognizes these as digits for slot-morphing
   purposes is unknown and untested.
   Proposed test name (not drafted, flagged only): `'Arabic-Indic digits are
   grouped as numeric slots, and land in the same visual order as European
   digits under direction: rtl'`.

7. **(P2)** No test covers explicit bidi control characters (LRM U+200E, RLM
   U+200F, isolates U+2066-U+2069) appearing inside a value — e.g. a value
   that manually forces an LTR-embedded number inside RTL text, which is a
   common real-world workaround for exactly the "digits look reversed" class
   of bug this audit is investigating. Torph's segmenter
   (`lib/src/core/segment.dart`) may or may not treat these as their own
   segments, and no test documents the intended behavior.
   Proposed test name (not drafted, flagged only): `'an RLM/LRM-wrapped digit
   run is left where the isolate places it'`.

8. **(P2)** `semantics_test.dart` never checks a semantics label for a value
   that mixes RTL script and digits, so there's no coverage of whether the
   accessible name (which is just the plain logical string, per
   `semantics_test.dart:29-38`'s existing Arabic case) stays correct — it
   almost certainly does, since the semantics label is untouched by the
   visual placement bug class, but it's currently *inferred* rather than
   tested for the mixed case.
   Proposed test name (not drafted, flagged only): `'semantics label for a
   mixed Arabic+digit value is the plain logical string'`.

9. **(P2)** The fuzz corpus (`morph_fuzz_test.dart`) has no case that unions
   the Arabic-word list (case 10) with a digit suffix/prefix, so property
   testing (320 random seeds) never stresses this combination even
   probabilistically. Its existing alignment invariant, per §1, is also
   self-referential (derived from the same rule under test) and would not
   catch this class of bug even if the corpus were widened.
   Proposed test name (not drafted, flagged only): extend corpus case 10 with
   `'السعر 1234 ريال'`-shaped values — left to the audit lead since this
   touches an existing test file, out of scope for this audit's draft.
