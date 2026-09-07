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
| FLIP | ENGINE PASS (150 runtime traces) / widget pending |
| Persistent motion | ENGINE PASS / widget pending |
| Enter motion | ENGINE PASS / widget pending |
| Exit motion | ENGINE PASS / widget pending |
| Number motion | ENGINE PASS (slot/mover, stack composition Q-013) / widget pending |
| Container width | ENGINE PASS (resume, carry, hold, zero) / widget pending |
| Container height | ENGINE PASS / widget pending |
| Interruption | ENGINE PASS (1–99 % × 6 scenarios) / widget pending |
| Rapid retargeting | ENGINE PASS (storms 16 ms) / widget pending |
| Empty state | ENGINE PASS / widget pending |
| Explicit newlines | ENGINE PASS / widget pending |
| RTL | pending (Q-025: RTL-root trace + widget) |
| Semantics | pending (M5) |
| Reduced motion | pending (M5) |
| Callbacks/lifecycle | ENGINE PASS (callback log in all traces) / widget pending |
