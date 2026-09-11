# RTL / bidi known limitations

Evidence: `reports/RTL_AUDIT_REPORT.md`, fixtures `oracle/fixtures/rtl/`. Upstream: torph 0.1.3 @ d79a5aa.

## RTL-002 Items are bidi-neutral atoms: no UAX#9 reordering across segments (UPSTREAM; FIXED in the port by DEV-006, reachable with `bidi: false`)

**Resolved for users.** `TextMorph.bidi` defaults to `true`, so the port places every item where the Unicode Bidirectional Algorithm puts its text: digit runs read left to right, Latin words keep their order, and RTL words run right to left. The rest of this entry describes the upstream behaviour, which `bidi: false` still reproduces exactly.
Upstream renders every segment as its own `display:inline-block` span (`utils/styles.ts`). CSS treats an atomic inline as a neutral character (U+FFFC) for the bidi algorithm, so in a `dir=rtl` root every item takes the paragraph direction and the items are laid out from the right edge in **logical** order, whatever their content. Measured in Chrome (Helvetica 20px, `oracle/fixtures/rtl/browser/`):

| Input (RTL root) | Plain paragraph, left→right | Upstream Torph, left→right |
| --- | --- | --- |
| `السعر 1234 ريال` | `ريال 1234 السعر` | `ريال 4321 السعر` (digit x = 30, 41.1, 52.3, 63.4 for 4,3,2,1) |
| `1,000` | `1,000` | `000,1` (`1` at x = 48.19, rightmost) |
| `السعر $1,234.56 اليوم` | `اليوم 1,234.56$ السعر` | `اليوم 65.432,1$ السعر` |
| `مرحبا ABC 123 DEF` | `ABC 123 DEF مرحبا` | `DEF 321 ABC مرحبا` |
| `مرحبا 12:34` | `12:34 مرحبا` | `34:12 مرحبا` |
| `اليوم 08/09/2026` | `08/09/2026 اليوم` | `2026/09/08 اليوم` |
| LTR root, `السعر 1234 ريال` | `ريال 1234 السعر` | `السعر 1234 ريال` (words in logical order) |

What is affected: any run that upstream splits into more than one item and that the Unicode Bidirectional Algorithm would display against the paragraph direction — ASCII digit runs (every digit is its own numeric slot), Latin words inside RTL text (word order), numbers with `:`, `/`, `-` (split at the symbol), single-word values (character-split), and RTL phrases inside an LTR root (word order). Glyph order **inside** one item is correct on both sides (a word, a Latin word, an Arabic-Indic number, `$`, `%`, `-` keep the side they have in logical adjacency).

Not affected: whole-word RTL items, Arabic-Indic (U+0660–0669) and Persian (U+06F0–06F9) numbers inside text (they are not digits for `isNumericWord`, so they remain one word item and are not reversed), pure-RTL values.

The Flutter port reproduces upstream exactly (`spec/RENDERER_CONTRACT.md` §4, `x_i = left + lineWidth − Σ_{j≤i} w_j`): 162/162 corpus cases have identical segmentation, 156/162 identical item order (the other 6 are RTL-003), and 148/148 morph/interrupt/storm traces match kinematically. It is therefore **not a port defect**. It is recorded here because a Flutter user who sets `Directionality.rtl` will see digit runs reversed, which is wrong by UAX#9. Fixing it would be a deliberate deviation from upstream (candidate DEV-006 in `spec/DEVIATIONS.md`, not implemented).

## RTL-003 A whitespace item carrying a bidi control collapses to zero width in the browser (P2, geometry only)
`السعر ‎1234‎ ريال` segments as `السعر`, `" ‎"` (space + LRM), `1234‎`, … The whitespace item is not whitespace-only, so upstream does not convert it to NBSP; a lone collapsible space inside a `white-space: nowrap` inline-block collapses, and the item measures 0 px wide (x = 74.5, same as its neighbour). Flutter measures the space at its advance (20 px in the test font). Order is unchanged; only that item's width differs. Reachable only with bidi control characters glued to a space (6 corpus cases: RTLC-048..052, 054). Same class as the existing font-metric tolerance; not RTL-specific in mechanism.

## Arabic-Indic and Persian digits (UPSTREAM, documented)
`isDigit` is ASCII-only upstream and in the port, so `١٢٣٤`/`۱۲۳۴` never morph by place value; they morph as ordinary words (or by character when the value is a single word, in which case RTL-002 reverses them, upstream too). Arabic separators U+066B/U+066C and `:`/`/`/mid-token `-` are not numeric separators, so `10:45`, `08/09/2026`, `1٬234٫56` split into several items. Parity is exact (`oracle:numeric-words`, `oracle:segment-number`, corpus report §UPSTREAM NUMERIC SUPPORT).

## Bidi control characters (UPSTREAM, documented)
LRM/RLM/LRI/RLI/FSI/PDI are ordinary characters to the segmenter; they attach to the neighbouring word or space item and do not isolate anything at the item level (the atomic-inline rule above wins). Both sides agree (parity 9/9 cases up to RTL-003).

## DEV-005 instance in an RTL storm (P2)
`RTLC-157` (`מחיר 1 ₪` → four values 16 ms apart): one exiting space, one sample, pinned 1.0 px apart (browser 3.2344, engine 4.2436) — the integer pinning quantum at a half-pixel offsetLeft. Allowed explicitly in `test/parity/rtl/rtl_trace_kinematic_parity_test.dart`.

## RTL-004 A grouping space inside a number is rendered as NBSP, so the number stays one run (P2, by design)
`isNumericWord` treats a space as a thousands separator, and the port renders it as NBSP (U+00A0). NBSP is a common separator for the bidi algorithm where U+0020 is whitespace, so a phone-shaped value keeps its groups in typed order instead of having them reordered: `اتصل بي على +971 50 123 4567` renders `971 50 123 4567+`, while the same string typed with plain spaces into a paragraph gives `4567 123 50 971+`. Both are the algorithm's own answer for the text each actually contains, so `bidi: true` is self-consistent; the difference is upstream's grouping rule, not the bidi pass. Verified on RTLC-058, 061, 062, 094 (test/rtl/rtl_bidi_corpus_test.dart compares against the rendered text for this reason).

## RTL-005 An exiting letter of a split word is drawn in its isolated form (P2; unreachable by default since DEV-008 keeps joining-script words whole)
A word that morphs character by character is split into one item per letter. Live items are painted as slices of a painter over the whole line, so joining forms survive (`RenderTextMorph._shapedSlices`, proven by test/rtl/rtl_shaping_test.dart: the ink profile of a split word matches the same word drawn as one run within 8 %, versus 67 % without the slice). Items already leaving the flow are not in that line any more and keep their own painter, so a departing Arabic letter shows its isolated shape while it fades (under 200 ms at the default duration).

## Not limitations (verified)
- Currency, sign, percent, parentheses and separators keep the same side as in the plain paragraph whenever they are one item with their neighbour or adjacent in logical order (`$`@112.0 in both renderings of `السعر $1,234.56 اليوم`; `-`@33.4; `%`@0).
- Entering digits land in the slot of the digit they replace at every sampled fraction; separators and words never change side during a morph, an interruption (1–99 %) or a storm.
- Semantics label is the logical string, unaffected by item order.
