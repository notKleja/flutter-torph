# Definition of done

Release candidate requires every row PASS with automated evidence, P0 = P1 = 0, unexplained oracle mismatches = 0, unapproved deviations = 0.

| Category | Status |
| --- | --- |
| Segmentation | PASS (semantic: segment-text 448, segmenter 348/352 + DEV-001) |
| Identity | PASS (chains 250/824 steps, unique-ID invariants) |
| Word diff | PASS (chains) |
| Character diff | PASS (chains) |
| Reordering | PASS (chains, runtime one-two-three) |
| Similarity matching | PASS (chains, Copy Address) |
| Number detection | PASS (numeric-words 290) |
| Number matching | PASS (segment-number 32 chains, runtime 999→1,000 etc.) |
| Replacement groups | PASS (replaced-runs 100, runtime group traces) |
| Spring/easing | PASS (easing 39×101, spring 15, carry 65) |
| FLIP | PASS (150 runtime traces) + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Persistent motion | PASS + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Enter motion | PASS + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Exit motion | PASS + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Number motion | PASS (slot/mover, stack composition Q-013) + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Container width | PASS (resume, carry, hold, zero) + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Container height | PASS + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Interruption | PASS (1–99 % × 6 scenarios) + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Rapid retargeting | PASS (storms 16 ms) + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Empty state | PASS + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Explicit newlines | PASS + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| RTL | PASS (18 RTL-root traces, Q-025) + widget: widget_trace_parity 169 traces, adversarial, fuzz |
| Semantics | PASS (test/widget/semantics_test, fuzz label invariant) |
| Reduced motion | PASS (test/widget/reduced_motion_test, adversarial disabled mid-morph) |
| Callbacks/lifecycle | PASS (callback log in all traces) + widget: widget_trace_parity 169 traces, adversarial, fuzz |
