# RTL / bidirectional text parity audit

Status: **COMPLETE** — verdict block in `reports/RTL_AUDIT_REPORT.md`. Upstream torph 0.1.3 @ d79a5aa63226acf97d49c3e34fafb2e85c07b026; port at master HEAD.

## Question
Numbers and numeric fragments inside RTL text appeared visually reversed in the Flutter port. Is that a port defect (segmentation, reconciliation, layout, bidi resolution, measurement, paint order, number slots, FLIP, interruption, container, punctuation, base direction), or upstream behaviour?

## Method
1. Corpus (`oracle/fixtures/rtl/corpus.json`, 162 cases, code points + grapheme clusters + python-bidi 0.6.11 UBA display order): Arabic, Persian, Urdu, Hebrew; ASCII, Arabic-Indic and Persian digits; decimals, grouping (`,`, NBSP, NNBSP, U+066B/U+066C), `%`, currency, `+`/`-`, parentheses, `/`, `:`, Latin words, phone strings, dates/times, `\n`, LRM/RLM/LRI/RLI/FSI/PDI; numbers at start/middle/end, next to punctuation, RTL and Latin; 53 morph pairs (123→124, 129→130, 999→1,000, 1,999→2,000, 9.99→10.00, −99→−100, $999→$1,000 and digit-set variants, in five positions), 10 interruption scenarios × 9 fractions (1–99 %), 5 storms.
2. Browser oracle (`oracle/runtime/trace-rtl.mjs`, pinned bundle unmodified, headless Chrome, virtual clock, Helvetica 20 px): for every case a plain `<span dir>` reference measured per grapheme cluster with `Range.getBoundingClientRect`, and Torph at rest with DOM order, per-item rects, computed `direction`/`unicode-bidi`/`display`, mover rects; morphs sampled at 0/10/25/37/50/73/90/100 %, interruptions at before/after/end, storms per update. Output `oracle/fixtures/rtl/browser/`, converted to replayable traces in `oracle/fixtures/rtl/traces/` (148).
3. Flutter harness (`test/rtl/rtl_static_audit_test.dart`, `rtl_morph_audit_test.dart`): plain `TextPainter` + `getBoxesForSelection` per grapheme (independent of the renderer's bookkeeping) versus `TextMorph` snapshots (`visualRect`), same fractions.
4. Parity tests (permanent): `test/parity/rtl/rtl_browser_static_order_test.dart` (asserting: item order per line + segmentation, 162; `rtl_browser_static_parity_test.dart` is the audit-only table writer), `test/parity/rtl/rtl_trace_kinematic_parity_test.dart` (engine driven with the browser's own widths: tx/ty/scale/opacity/mover/rect/root at every sample, 148), `test/rtl/rtl_invariants_test.dart` (readable expectations).
5. Cross-platform: `example/integration_test/rtl_platform_test.dart` on macOS desktop and iPhone 17 Pro simulator (iOS 26.4), `reports/rtl/platform_report.md`.

## Orders distinguished
LOGICAL STRING → SEGMENT ORDER (identical to upstream, 162/162) → NUMERIC SLOT ORDER (= segment order; movers slide only on the block axis) → PAINT ORDER (exiting first, then live in logical order; irrelevant to x) → VISUAL X-POSITION ORDER (the measurer's rule) → VISUAL GLYPH ORDER (x-order of items, then the platform text engine's UBA order inside each item).

## Findings
1. **Baseline browser** and **baseline Flutter** are UBA-correct and agree with each other (153/162; 9 harness artefacts, see matrix) and with python-bidi (differences only from glyph mirroring of parentheses and multi-line string flattening).
2. **Upstream Torph is not UBA-correct across items.** Every `[torph-item]` is `display:inline-block; direction: rtl; unicode-bidi: normal` (measured). Atomic inlines are neutral for bidi, so items flow from the right in logical order: multi-digit ASCII numbers, Latin word sequences and symbol-split tokens are visually reversed in an RTL root; RTL phrases are word-reversed in an LTR root. 106/162 cases differ from the plain paragraph, all by this one rule. → **RTL-002, upstream limitation.**
3. **The port matches upstream at every layer.** Segmentation 162/162; static item order 156/162 (6 = RTL-003 zero-width space geometry, order identical); morphs/interrupts/storms 148/148 kinematically (one DEV-005 1 px pin). Divergence layer in the port: none. The digit reversal is produced identically by `text_measurer.dart`'s RTL rule and by Chrome's inline-block layout.
4. **Numeric slots under RTL behave as upstream**: the entering digit occupies the slot of the digit it replaces at every sampled fraction; separators, currency, signs and words never change side during morph, interruption or storm; no temporary reversal beyond the steady-state RTL-002 order; no snap.
5. **Platforms agree**: macOS desktop and iOS simulator give identical Torph item order for 162/162 cases; 8 geometry-only differences (font metrics); one plain-paragraph shaper difference on a Hebrew line (RTLC-071), not a Torph difference.
6. No P0. P1: RTL-002 (user-visible, inherited, parity-exact). P2: RTL-003, DEV-005 instance.

## Outcome
DEV-006 was approved and implemented after this audit: `TextMorph.bidi` defaults to `true` and each item is placed at the visual left the platform paragraph engine gives its own character range, so an RTL root now reads correctly (digits `1234`, RTL word order, dates and times). `bidi: false` restores the upstream rule and is what every upstream-parity suite passes. One residual difference is RTL-004 (a grouping space inside a number renders as NBSP, keeping phone-shaped runs intact).

## Decision (pre-DEV-006)
Under the package's charter (1:1 port, `README.md`, `spec/DEVIATIONS.md`) the port is at parity for RTL; the release candidate is not blocked. UBA-correct ordering across items would be a new deviation (candidate **DEV-006**, `spec/DEVIATIONS.md`) requiring a product decision because it changes upstream-visible behaviour in both RTL and LTR roots and invalidates the 18 + 148 RTL traces as-is.
