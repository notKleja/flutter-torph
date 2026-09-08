# RTL parity matrix

Corpus: `oracle/fixtures/rtl/corpus.json` (162 cases: 149 RTL roots, 13 LTR controls; ar 127, fa 19, he 9, ur 4, en 3). Browser oracle: `oracle/fixtures/rtl/browser/` (Chrome, Helvetica 20 px, pinned bundle unmodified). Flutter: `test/rtl/`, `test/parity/rtl/`.

Columns: **Plain vs Torph (browser)** = does upstream Torph show the same visual glyph order as a plain browser paragraph (UAX#9 correctness of upstream). **Port vs upstream** = Flutter Torph item order / segmentation / kinematics against the browser capture (the parity gate).

| Category | Cases | Plain vs Torph (browser) | Port vs upstream |
| --- | --- | --- | --- |
| arabic-ascii-digits | 8 | 6 digit-run reversed, 2 symbol-split reversed (RTL-002) | 8/8 |
| persian-ascii-digits | 4 | 1 match, 2 reversed, 1 symbol-split (RTL-002) | 4/4 |
| arabic-indic | 9 | 7 match, 2 single-word char-split reversed (RTL-002) | 9/9 |
| persian-digits | 8 | 6 match, 2 single-word reversed (RTL-002) | 8/8 |
| hebrew | 5 | 1 match, 4 RTL-002 | 5/5 |
| mixed-latin | 81 | 24 match, 37 digit-run reversed, 20 word/symbol order (RTL-002) | 81/81 |
| punctuation | 6 | 1 match, 5 RTL-002 | 6/6 |
| bidi-controls | 9 | 3 match, 6 RTL-002 | 3/9 order-identical with a 0-width space (RTL-003); 9/9 segmentation |
| phone | 6 | 3 match, 3 RTL-002 | 6/6 |
| datetime | 6 | 2 match, 4 symbol-split reversed (RTL-002) | 6/6 |
| newline | 4 | RTL-002 per line | 4/4 (per line) |
| pure-number | 13 | 5 match, 8 RTL-002 | 13/13 |
| pure-rtl | 3 | 3 match | 3/3 |
| **static total** | **162** | **56 match / 106 RTL-002 (NBSP-normalised)** | **156/162 order, 162/162 segmentation** |
| morph (8 fractions) | 53 | entering digit takes the replaced slot at every fraction | 53/53 kinematic (tx/ty/scale/opacity/mover/rect/root ≤0.08 px) |
| interrupt (9 fractions × before/after/end) | 10 × 9 | no side changes | 90/90 kinematic |
| storm (5 values, 16 ms) | 5 | no side changes | 5/5 kinematic (1 DEV-005 pin, 1 px) |

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| STATIC RTL TEXT | PASS | pure-rtl 3/3, word items UBA-correct |
| STATIC MIXED BIDI | PARITY PASS / UBA FAIL (RTL-002, upstream) | mixed-latin 81/81 parity |
| ASCII NUMBERS INSIDE RTL | PARITY PASS / UBA FAIL (RTL-002, upstream) | arabic/persian/hebrew-ascii 17/17 parity |
| ARABIC-INDIC NUMBERS | PASS, upstream limitation documented (not digits) | arabic-indic 9/9 |
| PERSIAN DIGITS | PASS, upstream limitation documented (not digits) | persian-digits 8/8 |
| HEBREW + NUMBERS | PARITY PASS / UBA FAIL (RTL-002) | hebrew 5/5 |
| DECIMALS / GROUPING | PARITY PASS (separators stay between their digits; run reversed as a whole, RTL-002) | RTLC-002, 006, 118, 124 |
| CURRENCY / SIGNS / PERCENT | PASS (same side as plain paragraph) | RTLC-002, 032, 033, 035 |
| PUNCTUATION | PARITY PASS (RTL-002 for split symbols) | punctuation 6/6 |
| LATIN + RTL + NUMBER | PARITY PASS / UBA FAIL (word order, RTL-002) | RTLC-027, 028, 041 |
| NUMBER MORPHING | PASS | 53 traces |
| NUMBER INTERRUPTION | PASS | 90 traces |
| RTL STORMS | PASS (1 DEV-005 pin) | 5 traces |
| RTL FLIP | PASS | rect.x/ty within 0.08 px at every sample |
| RTL CONTAINER MOTION | PASS | root width/height within 0.12 px at every sample |
| RTL CALLBACKS | PASS | existing 18 RTL traces (callback log) — new traces do not record callbacks |
| PLAIN FLUTTER REFERENCE COMPARISON | PASS 153/162 (9 harness artefacts: 5 zero-width marks, 4 multi-line reference not captured) | reports/rtl/flutter_static.json |
| UPSTREAM BROWSER COMPARISON | PASS 156/162 order + 162/162 segmentation + 148/148 kinematic | test/parity/rtl |
| CROSS-PLATFORM | PASS: macOS desktop and iOS 26.4 simulator 162/162 each, 0 order differences, 8 geometry-only | reports/rtl/platform_report.md |
