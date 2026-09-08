# RTL audit report

Companion: `spec/RTL_AUDIT.md` (method, findings), `spec/RTL_PARITY_MATRIX.md` (per-category/gate table), `spec/RTL_KNOWN_LIMITATIONS.md`. Workhorse reports: `reports/rtl/browser_oracle_report.md`, `reports/rtl/flutter_audit_report.md`, `reports/rtl/flutter_morph_report.md`, `reports/rtl/corpus_report.md`, `reports/rtl/test_audit.md`, `reports/rtl/platform_report.md`; machine data `reports/rtl/*.json`.

## RTL PARITY FAILURE: RTL-002

SEVERITY: P1 (user-visible) — classification UPSTREAM-TORPH; port parity: PASS

INPUT: `السعر 1234 ريال` (representative; 106 corpus cases)

BASE DIRECTION: rtl

LOCALE: ar

CODE POINTS: U+0627 U+0644 U+0633 U+0639 U+0631 U+0020 U+0031 U+0032 U+0033 U+0034 U+0020 U+0631 U+064A U+0627 U+0644

UPSTREAM LOGICAL SEGMENTS: `السعر` · ` ` · `1`(digit slot) · `2` · `3` · `4` · ` ` · `ريال`

UPSTREAM VISUAL ORDER (left→right, Chrome, x): `ريال`@0 · ` `@24.44 · `4`@30.00 · `3`@41.13 · `2`@52.25 · `1`@63.38 · ` `@74.50 · `السعر`@80.06

FLUTTER LOGICAL SEGMENTS: identical (ids ` n0..n3`, `space-5`, `space-10`)

FLUTTER VISUAL ORDER (left→right, test font 20 px): `ريال`@0 · ` `@80 · `4`@100 · `3`@120 · `2`@140 · `1`@160 · ` `@180 · `السعر`@200

PLAIN FLUTTER VISUAL ORDER: `ريال`(0–80) · ` ` · `1`@100 · `2`@120 · `3`@140 · `4`@160 · ` ` · `السعر`(200–300) — UBA-correct, same as the plain browser paragraph (`1`@29.98 … `4`@63.34).

UPSTREAM GEOMETRY: items `display:inline-block`, `direction:rtl`, `unicode-bidi:normal`; root 105.6 × 23.

FLUTTER GEOMETRY: `x_i = left + lineWidth − Σ_{j≤i} w_j` (RENDERER_CONTRACT §4).

MORPH TIMESTAMP: static (rest); identical at every sampled fraction of every morph.

EXPECTED (UAX#9): `ريال 1234 السعر`. EXPECTED (upstream parity): `ريال 4321 السعر`.

ACTUAL: `ريال 4321 السعر` in both upstream and the port.

DIVERGENCE LAYER: RTL-BIDI-RESOLUTION in upstream's DOM model (atomic inline per segment). Port layer: none (the RTL-LAYOUT rule reproduces it exactly).

REPRO TEST: `test/rtl/rtl_invariants_test.dart` (RTL-002 cases), `test/parity/rtl/rtl_browser_static_order_test.dart` RTLC-001.

EVIDENCE: `oracle/fixtures/rtl/browser/RTLC-001.json` (`plain.graphemes[].rect.x`, `torphAtRest.items[].rect.x`, `computed`), `reports/rtl/flutter_static.json` RTLC-001, `oracle/fixtures/runtime/rtl-999-1-000-744888.json` (`1`@48.19 rightmost in `1,000`).

RESOLUTION: documented upstream limitation; candidate DEV-006 recorded, not implemented (product decision).

## RTL PARITY FAILURE: RTL-003

SEVERITY: P2 (geometry only, order identical)

INPUT: `السعر <LRM>1234<LRM> ريال` (RTLC-048; also 049–052, 054; LRM = U+200E)

BASE DIRECTION: rtl · LOCALE: ar · CODE POINTS: … U+0020 U+200E U+0031 … U+200E U+0020 …

UPSTREAM LOGICAL SEGMENTS: `السعر` · `" <LRM>"` · `1234<LRM>` · ` `(NBSP) · `ريال` — FLUTTER: identical.

UPSTREAM VISUAL ORDER: `ريال`@0 · ` `@24.44 · `1234<LRM>`@30 · `" <LRM>"`@74.5 (w = 0) · `السعر`@74.5

FLUTTER VISUAL ORDER: `ريال`@0 · ` `@80 · `1234<LRM>`@100 · `" <LRM>"`@180 (w = 20) · `السعر`@200

EXPECTED/ACTUAL: same order; the space+LRM item is 0 px wide in Chrome (collapsible space in a nowrap inline-block) and 20 px in Flutter.

DIVERGENCE LAYER: RTL-MEASUREMENT (whitespace collapsing), not bidi.

REPRO TEST: `test/parity/rtl/rtl_browser_static_order_test.dart` (RTLC-048, tie in x tolerated); EVIDENCE: `oracle/fixtures/rtl/browser/RTLC-048.json`.

RESOLUTION: documented (spec/RTL_KNOWN_LIMITATIONS.md); unreachable without bidi controls glued to a space.

## DEV-005 instance (P2)
`RTLC-157` storm, t = 48 ms, exiting space: browser rect.x 3.2344, engine 4.2436 (1.0 px pinning quantum at a half-pixel offsetLeft). Explicitly allowed in `rtl_trace_kinematic_parity_test.dart`; every other value in 148 traces within 0.08 px.

## Cross-platform
macOS desktop and iPhone 17 Pro simulator (iOS 26.4): 162/162 cases each; 0 Torph item-order differences between them; 8 geometry-only differences (RTLC-023, 024, 025, 026, 062, 068, 071, 078; system-font metrics); 1 plain-paragraph shaper difference (RTLC-071 Hebrew line, not Torph). Android: no device available, not run.

## Summary
RTL AUDIT STATUS: COMPLETE
TOTAL RTL CASES: 162 static (149 rtl / 13 ltr) + 148 motion traces (53 morph, 90 interrupt, 5 storm)
STATIC FAILURES: 0 port failures (106 upstream UBA divergences = RTL-002; 6 geometry-only = RTL-003)
NUMBER-ORDER FAILURES: 0 port failures (58 digit-run reversals inherited from upstream, parity exact)
ANIMATION FAILURES: 0
INTERRUPTION FAILURES: 0
PLATFORM-SPECIFIC FAILURES: 0 order failures (8 geometry-only, macOS vs iOS)
P0: 0
P1: 1 (RTL-002, upstream limitation, parity PASS)
P2: 2 (RTL-003, DEV-005 instance)
FIXES REQUIRED: 0 for parity; DEV-006 (UAX#9 item reordering) is an optional product decision
KNOWN UPSTREAM LIMITATIONS: RTL-002 (no bidi reordering across items), ASCII-only digits (Arabic-Indic/Persian not numeric), bidi controls not isolating at item level
KNOWN FLUTTER LIMITATIONS: RTL-003 (space+bidi-control item keeps its width), DEV-005 pin quantum (1 px, one sample)
RELEASE BLOCKED: NO
FINAL VERDICT: The port is at exact parity with pinned upstream for all RTL/bidi behaviour measured; the reversed digits are upstream's atomic-inline layout, reproduced faithfully, and are documented as RTL-002 with an optional deviation path.
