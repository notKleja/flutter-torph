# Release candidate audit (A0)

Upstream: torph 0.1.3 @ d79a5aa63226acf97d49c3e34fafb2e85c07b026. Candidate: `torph` Flutter package 0.1.3, master HEAD.

## Evidence chain
1. Semantic oracle (oracle/gen-semantic.ts, tsx over pinned source): 2,466 items across 15 fixture files; Dart parity suites test/parity/{number,motion_math,segmentation}_parity_test.dart — all pass (minted IDs compared up to renaming).
2. Segmentation: pure-Dart ICU-78 word/grapheme port, 348/352 word + 352/352 grapheme fixtures; 4 dictionary-script gaps = DEV-001.
3. Runtime oracle (oracle/runtime, puppeteer + Chrome, virtual clock): 168 traces, 10 probes. Engine parity: test/parity/runtime_trace_parity_test.dart 168/168 at every sample (tx/ty/scale/opacity/mover/rect/root size/callbacks, 0.02 px; DEV-002 tolerances for LayoutUnit).
4. Widget parity: test/parity/widget_trace_parity_test.dart drives TextMorph with a Ticker through all 168 traces (4,272 samples), font-metric-normalised; mutation check proves sensitivity.
5. Upstream unit tests ported: engine.test, options.test, container-size.test, easing.test (test/motion), diff/number/unique-id semantics via fixtures.
6. Fuzz: 320 seeded sequences with interrupts and storms, INV-1..15 at every pump; adversarial corpus (A2_CHALLENGE_REPORT items 1–10, TextScaler/style/direction/disabled/TickerMode/dispose mid-morph, 1000-update storm).
7. Questioner findings: Q-001..Q-031 resolved; F-1 (reflow on container release) fixed at 795f398 and covered by adversarial + fuzz tests.
8. Performance (spec/PERFORMANCE.md, macOS profile): build ≤1.3 ms avg under per-frame updates; update cost for very long values is the known P2 hotspot.

## Criteria
P0 = 0, P1 = 0, unexplained oracle mismatches = 0, unapproved deviations = 0 (DEV-001..005 approved, all P2, none masks motion or reconciliation).

Verdict: APPROVED as release candidate. Not published (per policy).
