# RENDER-SPIKE-001 — how should `RenderTextMorph` paint fragments?

**Status: experimental evidence only. Nothing in `spike/` is production code, and this
document does not decide anything — the decision is the master's.** Ticket M4.

Harness: `spike/test/render_spike_test.dart`, raw data `spike/out/results.json`,
per-strategy PNGs `spike/out/*.png`. Run with `cd spike && flutter test`.

## 1. Methodology

Three strategies, one shared `TextStyle` (fontSize 32, `TextScaler.noScaling`,
`locale: en`), one `TextDirection` per case:

- **A — per-fragment `TextPainter`.** One painter per Torph segment string, laid out
  independently, positioned by accumulating `painter.width`, all fragments aligned on a
  shared alphabetic baseline (`max` over `computeDistanceToActualBaseline`). This is a
  1:1 model of upstream's DOM: root `inline-block; white-space:nowrap`, every segment its
  own `inline-block; position:relative` span.
- **B — whole-paragraph shaping + clipped replay.** One `TextPainter` over the joined
  line. Fragment geometry from `getBoxesForSelection(TextSelection(start, end),
  boxHeightStyle: max, boxWidthStyle: tight)` over each segment's UTF-16 range. Each
  fragment is painted as `save(); clipPath(union of its boxes, translated by the
  fragment's offset); paragraph.paint(offset); restore()`.
- **C — one paragraph painted once.** Exactly what a plain `Text` widget produces.
  Reference only.

Segmentation is `package:torph`'s own `segmentText(value, 'en')`, so the fragment sets are
the real ones (words + NBSP for multi-word values, graphemes for single-word values,
per-character with kinds for numeric words). **The joined string for B and C is the
concatenation of the segment strings, i.e. it contains NBSP (U+00A0) where the source had
U+0020**, because that is what Torph renders; this keeps B's UTF-16 offsets exact and makes
the A/B/C comparison apples-to-apples.

Fonts: default `flutter_test` font (the Ahem-like `FlutterTest` family) **and** real fonts
loaded via `FontLoader` from `spike/fonts/`: Roboto, NotoSansArabic, NotoSansDevanagari,
NotoColorEmoji (CBDT), NotoSansJP. All five downloaded successfully; no macOS system-font
fallback was needed and **emoji fidelity was measurable**. Caveat: each case uses a single
family with no fallback list, so the Latin word `family` inside the emoji case renders as
tofu under NotoColorEmoji — that affects all three strategies identically and does not
disturb the A-vs-B comparison.

Images: rendered through `PictureRecorder` → `Picture.toImage` → `toByteData(rawRgba)` and
diffed byte-wise in Dart (per-pixel max channel delta > 12 counts as differing). Reported
as *% of all canvas pixels / % of pixels inked in either image*. This replaces
`matchesGoldenFile` — it gives a number rather than a pass/fail and needs no golden files.

Timing: `Stopwatch` in a plain loop. **All numbers are debug-mode, host macOS, and are only
meaningful as relative measures.** Layout = 30 repetitions of building the whole strategy
from scratch. Paint = 60 frames of picture *recording* with every fragment translated by a
changing offset. Raster = 10 frames of record + `Picture.toImageSync` (software raster),
which is where B's cost actually lands.

Memory: `ProcessInfo.currentRss` before/after allocating 500 live `TextPainter`s.

## 2. Results per string

`advance A` = Σ fragment widths; `width B` = paragraph width. `max Δx` = largest
disagreement between A's accumulated fragment x and B's `getBoxesForSelection` left edge.
Pixel columns are *vs the plain-`Text` reference C*, `% all / % inked`. Times in µs, debug.

| string | font | frags | advance A | width B | Δ advance | max Δx | A vs C | B vs C | layout A | layout B | paint A | paint B |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `AVAWAY To` | FlutterTest | 3 | 288.00 | 288.00 | +0.00 | 0.00 | 0.00% / 0.00% | 2.70% / 3.73% | 68 | 24 | 10.2 | 9.4 |
| `office ﬁne` | FlutterTest | 3 | 320.00 | 320.00 | +0.00 | 0.00 | 0.00% / 0.00% | 2.62% / 3.81% | 62 | 27 | 6.1 | 13.8 |
| `hello world` | FlutterTest | 3 | 352.00 | 352.00 | +0.00 | 0.00 | 0.00% / 0.00% | 2.67% / 3.59% | 58 | 24 | 6.0 | 9.3 |
| `café café` | FlutterTest | 3 | 288.00 | 288.00 | +0.00 | 0.00 | 0.00% / 0.00% | 2.70% / 3.73% | 66 | 22 | 4.5 | 6.9 |
| `$1,234.56` | FlutterTest | 9 | 288.00 | 288.00 | +0.00 | 0.00 | 0.00% / 0.00% | 2.97% / 3.68% | 183 | 34 | 10.1 | 16.2 |
| `AVAWAY To` | Roboto | 3 | 168.56 | 168.56 | +0.00 | 0.00 | 0.00% / 0.00% | 0.01% / 0.06% | 54 | 22 | 3.8 | 7.4 |
| `office ﬁne` (U+FB01) | Roboto | 3 | 141.03 | 141.03 | +0.00 | 0.00 | 0.00% / 0.00% | 0.00% / 0.00% | 55 | 24 | 3.5 | 11.1 |
| `office fine` (f+i) | Roboto | 3 | 141.03 | 141.03 | +0.00 | 0.00 | 0.00% / 0.00% | 0.00% / 0.00% | 58 | 21 | 3.7 | 6.1 |
| `hello world` | Roboto | 3 | 155.22 | 155.22 | +0.00 | 0.00 | 0.00% / 0.00% | 0.00% / 0.00% | 53 | 30 | 3.4 | 7.0 |
| `مرحبا بالعالم` (rtl) | NotoSansArabic | 3 | 154.18 | 154.18 | +0.00 | **86.85** | **16.06% / 85.81%** | 0.00% / 0.00% | 57 | 22 | 3.9 | 5.5 |
| `سلام دنیا` (rtl) | NotoSansArabic | 3 | 113.18 | 113.18 | +0.00 | **68.06** | **13.50% / 81.35%** | 0.00% / 0.00% | 55 | 21 | 8.5 | 4.8 |
| `नमस्ते दुनिया` | NotoSansDevanagari | 3 | 145.44 | 145.44 | +0.00 | 0.00 | 0.00% / 0.00% | 0.32% / 1.29% | 52 | 21 | 3.3 | 4.5 |
| `café café` | Roboto | 3 | 132.36 | 132.36 | +0.00 | 0.00 | 0.00% / 0.00% | 0.00% / 0.00% | 52 | 22 | 4.9 | 9.3 |
| `👨‍👩‍👧‍👦 family 🏳️‍🌈` | NotoColorEmoji | 5 | 448.00 | 448.00 | +0.00 | 0.00 | 0.00% / 0.00% | 1.84% / 3.72% | 90 | 28 | 5.1 | 7.6 |
| `abc مرحبا 123` (ltr) | NotoSansArabic | 7 | 196.48 | 196.48 | +0.00 | **75.65** | **11.00% / 68.53%** | 0.00% / 0.00% | 127 | 30 | 4.6 | 9.9 |
| `日本語 text` | NotoSansJP | 3 | 159.36 | 159.36 | +0.00 | 0.00 | 0.00% / 0.00% | 0.00% / 0.00% | 56 | 35 | 3.3 | 4.9 |
| `$1,234.56` | Roboto | 9 | 140.48 | 140.48 | +0.00 | 0.00 | 0.00% / 0.00% | 0.00% / 0.00% | 151 | 33 | 10.3 | 10.0 |

### Reading of the table

1. **Advance delta is exactly 0.000 for every string at Torph's real segmentation.**
   Word-level segmentation never crosses a shaping boundary in these samples: Latin
   kerning does not run across U+00A0, Devanagari conjuncts and combining marks stay
   inside one grapheme segment, ZWJ emoji stay inside one grapheme segment, and the
   digits case is Latin digits with no contextual forms. Summing independent advances is
   *bit-identical* to the paragraph width for all 17 cases.
2. **A vs C is 0.00% for every LTR case** — per-fragment painting is pixel-identical to a
   plain `Text` widget wherever segmentation does not cut a shaping cluster.
3. **A vs C is 11–16% (68–86% of inked pixels) for the three bidi cases.** This is *not*
   a shaping loss — each Arabic word is still shaped and joined correctly inside its own
   painter. It is a **visual-order** failure: naive left-to-right accumulation puts the
   first logical segment leftmost, so the RTL line comes out with its words mirrored
   (`spike/out/realfont_arabic_A.png` vs `_C.png`). Any Strategy-A renderer must run a
   bidi reordering pass over the fragment list — which is exactly what the browser does
   with the inline-block spans, so this is parity work, not a defect of A.
4. **B vs C is 0.00% on real proportional fonts, but not zero everywhere.** 2.6–3.0% under
   the Ahem-like `FlutterTest` font (every glyph is a solid block, so a 1px clip seam
   along a full-height edge is a large share of the ink), 0.32% on Devanagari and 1.84% on
   color emoji — glyph ink that overhangs the tight selection box gets shaved by the clip.
   B is therefore not free of visual error either; it trades shaping error for clip error.
5. **Layout: A is 2.5–6× slower than B** and scales linearly with fragment count
   (≈10–19 µs per painter, debug). B is ≈20 µs of paragraph layout plus ≈1 µs per
   `getBoxesForSelection` call.
6. **Paint: A is cheaper than B in almost every case**, roughly 2× at 9 fragments.

### Scaling (Roboto, `w0 w1 …` word lists, debug µs)

| fragments | layout A | layout B | paint A (record) | paint B (record) | raster A | raster B |
|---|---|---|---|---|---|---|
| 15 | 232 | 46 | 8.1 | 15.1 | 71 | 88 |
| 31 | 490 | 46 | 31.6 | 30.5 | 81 | 150 |
| 63 | 774 | 62 | 18.5 | 55.1 | 137 | 316 |
| 127 | 1412 | 221 | 26.9 | 90.0 | 249 | 785 |
| 255 | 2704 | 220 | 56.9 | 185.1 | 490 | 1864 |

A's layout cost is linear and dominates at high fragment counts (2.7 ms for 255
fragments, debug). B's layout is ~12× cheaper. But B's **raster** cost grows
super-linearly — it records N copies of the whole-paragraph draw call, one per clip — and
overtakes A by 1.2× → 1.9× → 2.3× → 3.2× → **3.8×** as N grows. Layout happens on value
change; raster happens 60×/second during a morph. (Software raster, debug; Impeller/GPU
numbers will differ, and Skia culls glyphs outside the clip so this is not a clean O(n²),
but the direction is unambiguous.)

### Memory

500 live `TextPainter`s: RSS 208.7 MB → 214.4 MB, **+5.67 MB ≈ 11.3 KB per painter**.
One paragraph painter over the same 500 words: **+0.11 MB**. Strategy A costs roughly 50×
the retained bytes of Strategy B for the same text. For realistic Torph values (tens of
fragments) this is tens to a few hundred KB — not a blocker, but it is real, and it argues
for retaining painters across frames rather than rebuilding them.

## 3. Failure modes of B (and what A does in the same spot)

The interesting cases are char morphs, where a *word* is re-segmented into graphemes.
Full data in `spike/out/results.json` under `failures`.

| split | Σ A widths | paragraph width | what B returns |
|---|---|---|---|
| `office` → `o f f i c e` (Roboto) | 81.94 | 80.78 | 6 boxes, but the `fi` **ligature** is split: fragments 2 and 3 both get width 8.859 at x 29.36 and 38.22 — halves of one glyph |
| `ﬁne` → `ﬁ n e` (U+FB01 precomposed) | 52.33 | 52.33 | 3 clean boxes, Δ = 0 |
| `مرحبا` → 5 graphemes | **87.07** | 67.33 | 5 clean, contiguous boxes in visual RTL order (lefts 50.5, 37.9, 20.3, 9.3, 0.0), widths summing to the paragraph width |
| `مرحبة` → 5 graphemes | **92.42** | 73.57 | same: 5 clean boxes |
| `नमस्ते` → **per UTF-16 unit** (6) | 109.41 | 67.58 | **4 of 6 return zero boxes** — offsets inside a grapheme cluster have no selection geometry |
| `नमस्ते` → **`segmentText` graphemes** (3) | 67.58 | 67.58 | 3 clean boxes, Δ = 0 |
| `café` → per code unit (`e` + U+0301) | 62.22 | 62.22 | **both fragments return zero boxes** |
| `café` → `segmentText` graphemes (4) | 62.22 | 62.22 | 4 clean boxes, Δ = 0 |
| `a😀b` → per UTF-16 unit (lone surrogates) | 128.00 | 96.00 | **zero boxes for both surrogate halves**; A does **not** crash — each lone surrogate lays out as a 32.0-wide `.notdef` box, inflating the advance by 33% |
| `👨‍👩‍👧‍👦` → per UTF-16 unit (11) | 256.00 | 128.00 | **zero boxes for all 11 units**; A renders 8 tofu boxes + 3 zero-width ZWJs |
| `👨‍👩‍👧‍👦` → `segmentText` graphemes (1) | 128.00 | 128.00 | 1 clean box, Δ = 0 |
| `🏳️‍🌈` → `segmentText` graphemes (1) | 64.00 | 64.00 | 1 clean box, Δ = 0 |

Findings:

- **`getBoxesForSelection` silently returns an empty list for any range that does not fall
  on a grapheme-cluster boundary.** Not an exception — an empty list. A B-based renderer
  must treat "no boxes" as a hard case and fall back, or it will simply not draw the
  fragment.
- **Inside a ligature, B does not fail — it lies.** It divides the ligature glyph's advance
  evenly between the participating code points and returns overlapping half-boxes. Clipping
  to those halves cuts the `ﬁ` glyph down the middle: the `f` fragment carries the left
  half of the ligature including part of the dot-less `i` bowl. Moving the two halves apart
  produces a visibly broken glyph.
- **Torph never produces those bad ranges.** `segmentText` uses grapheme segmentation for
  single-word values, so every fragment boundary is a grapheme boundary: Devanagari
  conjuncts, NFD `café`, astral emoji and ZWJ sequences all come out as whole clusters with
  Δ = 0 and clean boxes under both strategies. The lone-surrogate and mid-cluster splits
  above are only reachable if a future code path re-segments by UTF-16 unit. **A does not
  crash on lone surrogates** (it renders `.notdef`), but the guard is worth keeping: pair
  surrogates within a fragment before building a painter.
- **The one real, reachable divergence for A is `office` split per character**: +1.157 px
  (+1.4%) because Roboto's `fi` ligature is lost. The second is Arabic/Persian char
  morphs: +29.3% / +25.6% advance, because A renders every letter in its isolated form.

## 4. Parity note — what does upstream do here?

This is the decisive column, because parity is with upstream, not with a plain `Text`.

In the browser every segment is its own `display:inline-block` span. Inline-blocks are
atomic inline-level boxes: **no shaping, kerning, ligature formation, cursive joining or
mark attachment crosses an inline-block boundary in any browser engine.** So for every
string below, upstream loses exactly what Strategy A loses:

| string | does upstream also lose shaping at segment boundaries? |
|---|---|
| `AVAWAY To` | Yes in principle (kerning across the span boundary) — but the boundary is a NBSP span and there is no kern pair, so no visible loss. A matches: Δ 0. |
| `office ﬁne` (word segments) | No loss either way: `office` and `ﬁne` are each one span/painter. |
| `office` **char-morphed** | **Yes** — six spans, the `fi` ligature is gone in the browser too. A reproduces upstream exactly (+1.157 px); B would *preserve* the ligature and therefore **diverge from upstream**. |
| `hello world` | No loss. |
| `مرحبا بالعالم` (word segments) | No shaping loss — each word is one span, joining intact. But the browser **does** bidi-reorder the spans, so upstream shows the words right-to-left; naive A does not, and must add that reorder. |
| `مرحبا` **char-morphed** | **Yes** — every letter is its own inline-block, so the browser renders isolated forms and loses cursive joining exactly as A does (+29.3%). B would keep the joining and **diverge from upstream**. |
| `سلام دنیا` | Same as Arabic: word-level fine, char-level loses joining upstream too. |
| `नमस्ते दुनिया` | No loss — conjuncts stay inside a grapheme segment, which is one span. |
| `café café` | No loss — the combining mark stays inside its grapheme span. |
| `👨‍👩‍👧‍👦 family 🏳️‍🌈` | No loss — each ZWJ sequence is one grapheme, one span. |
| `abc مرحبا 123` | No shaping loss; upstream bidi-reorders the spans (A must too). |
| `日本語 text` | No loss; font fallback is per-span in the browser as it is per-painter in A. |
| `$1,234.56` | Per-character spans upstream by design (numeric slots); no contextual forms in Latin digits, so no loss. A matches: Δ 0. |

In other words: **on the two cases where A differs from a plain `Text` widget for shaping
reasons (`office` char morph, Arabic char morph), upstream differs from plain HTML text in
exactly the same way and by the same mechanism.** Strategy B's "better" typography is a
deviation from the port's reference, not a fix.

## 5. Recommendation (advisory — the decision is the master's)

**Strategy A, with two additions.** The evidence:

- *Parity*: A is a mechanical translation of the upstream box model. Every place A loses
  shaping, upstream loses it too, for the same reason. B is typographically nicer and
  therefore *wrong* for a 1:1 port — a char morph of `office` or `مرحبا` would look
  different from the JS library it is porting, and DEVIATIONS would have to record it.
- *Robustness*: B has a silent-failure mode (`getBoxesForSelection` → empty list for any
  non-cluster-boundary range) and a silent-corruption mode (half-boxes inside a ligature).
  Both would need a fallback that is, in effect, Strategy A — so B costs A's code *plus*
  B's code.
- *Independence*: A gives each fragment a real, self-contained box with its own baseline
  and its own font fallback. B's fragments are windows onto one shared paragraph; the
  moment fragments overlap during a morph, the clips overlap and the same glyphs are drawn
  twice with different alphas, which is not what per-element opacity means. Independent
  per-fragment opacity — which Torph needs for enter/exit fades — is essentially free in A
  and awkward in B.
- *Cost*: A is 2.5–6× slower to lay out (linear in fragment count; only on value change,
  and cacheable per unique string+style) and ~11 KB retained per painter. It is *cheaper*
  to paint and rasterizes 1.2–3.8× faster than B under motion, which is the per-frame path.
  For an animation library, paying at layout to save at raster is the right side of the
  trade.

Additions A needs:
1. **Bidi visual reordering of the fragment list.** Naive accumulation is 11–16% pixel-wrong
   on every RTL or bidi-mixed string. The browser reorders inline-blocks per UAX #9; the
   render object must do the same before assigning x offsets. This is a geometry concern
   the engine has to own regardless of strategy.
2. **A layout cache keyed by (string, style, textScaler, locale, direction)**, so unchanged
   fragments are not re-laid-out and painters are retained across frames. That removes most
   of A's layout disadvantage and all of its per-frame cost.

Where B still earns a look: nowhere in the current fragment model. It becomes interesting
only if the port ever needs shaping to survive a fragment boundary — which, per §4, would
itself be a deviation from upstream.

This confirms rather than overturns architecture decision **D-4** (per-item TextPainters
unless the spike proves otherwise). The spike did not prove otherwise. **The decision
remains the master's.**
