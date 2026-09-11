# Deviations

None approved yet. Format:

```
DEV-### <title>
Upstream: ...
Flutter: ...
Cause: ...
Experiments: ...
Alternatives: ...
Why unavoidable: ...
Perceptual impact: ...
API impact: ...
Verifier evidence: ...
Status: proposed | approved (A0) | rejected
```

## DEV-001 ICU dictionary word breaks (approved A0, P2)
Upstream: Intl.Segmenter (ICU) cuts Han/Kana/Thai/Lao/Khmer/Myanmar runs with a dictionary (locale-invariant, Q-011). Flutter: rule-based UAX#29 port keeps such a run as one segment (see spec/SEGMENTER_KNOWN_GAPS.md, 4/352 fixtures). Cause: no dictionary in pure Dart; a bundled dictionary would be MBs. Reachable only when such text also contains a space or newline (otherwise the grapheme path is used and matches). Perceptual impact: a changed CJK/Thai run animates as a whole word instead of dictionary words. API impact: none. Evidence: test/core/text_segmenter_test.dart allowlist.

## DEV-002 Chrome LayoutUnit quantisation (documented tolerance, not a behaviour)
Chrome positions boxes at 1/64 px; widths read back for the next transition are quantised and float advance sums of proportional fonts accumulate a few units. Flutter uses unquantised doubles. Kinematic parity tests use 0.05 px on the root size and 0.08 px on item positions for proportional fonts (0.02 otherwise). Not perceptible.

## DEV-003 Callbacks during the build phase are deferred to the end of the frame (approved A0)
Upstream fires `onAnimationStart`/`onAnimationCancel` synchronously inside `update()`. In Flutter `update()` runs inside `didUpdateWidget`/build, where user `setState` is illegal, so those callbacks are queued and flushed in a post-frame callback of the same frame, order preserved. `onAnimationComplete` (ticker phase) stays synchronous.

## DEV-004 Disabled mode never soft-wraps (approved A0)
Upstream: an instance constructed disabled has no `[torph-root]` styles and wraps like any span; one disabled later keeps `white-space: nowrap`. Flutter: plain text is always laid out with `\n` as the only line break, matching the animated model.

## DEV-005 Integer pinning quantum (approved A0, P2)
Upstream pins exiting boxes at integer CSS-px `offsetLeft/offsetTop` and divides integer `offsetHeight` for the digit slide; the port rounds the same way in logical Flutter pixels (Q-026/Q-027). Same rule, different pixel grid; ≤0.5 px.

## DEV-006 (APPROVED, implemented, default on) UAX#9 reordering of items
Upstream lays every segment out as a bidi-neutral atomic inline, so digit runs and Latin words inside an RTL root (and RTL words inside an LTR root) appear in logical, not UBA, order (RTL-002, spec/RTL_KNOWN_LIMITATIONS.md). A deviation would place each line's items at the x positions the platform paragraph engine gives their substrings (one `TextPainter` per line, `getBoxesForSelection` per item range), keeping per-item painters for motion. Implemented in `lib/src/rendering/text_measurer.dart`: each line's items are concatenated into one `TextPainter` and every item is placed at the visual left `getBoxesForSelection` reports for its own character range; per-item painters still do the painting, so motion is unchanged. `TextMorph.bidi` (default `true`) turns it off, and the upstream-parity suites pass `bidi: false`, so the 18 + 148 RTL traces remain valid evidence for the upstream rule.

Deliberately not matched to upstream: with `bidi: true` a right-to-left root reads correctly instead of reproducing upstream's reversed digit runs and word order (RTL-002).

## DEV-007 Grapheme-cluster word morphing (approved A0, P1, default on)
Upstream: JS word-level morph (`split("")` + LCS + character similarity) pairs UTF-16 code units. Flutter: `lib/src/core/diff.dart` (`_splitIfWhole`, `_Mode.morph`, `_charSimilarity`) instead pairs extended grapheme clusters via `package:characters`, so a word containing an emoji, skin-tone modifier, ZWJ sequence, regional-indicator flag or NFD combining mark keeps each grapheme as one segment instead of being cut into lone surrogates or a base letter detached from its combining mark — both of which `TextPainter` renders as tofu/mojibake. Numeric words (`_Mode.number`, `segmentNumber`) are unaffected: that path only ever sees ASCII digits, separators and affixes and still splits on code units. Cause: Dart strings are UTF-16 and JS `split("")` parity would reproduce the tofu. Perceptual impact: a changed grapheme in a morphing word now visibly enters/exits as a whole unit instead of flickering broken glyphs; ID scheme (`${wordSegId}:$i`, minted `'$newWord~$ci'`) unchanged, just indexed by grapheme instead of code unit. API impact: none. Evidence: test/core/grapheme_morph_test.dart; oracle/fixtures/chains.json labels `extra:emoji`, `extra-nonum:emoji`, `extra:combining`, `extra-nonum:combining` skipped in test/parity/segmentation_parity_test.dart (reason `DEV-007 grapheme word morph`) since they encode the old code-unit tofu-splitting.

## DEV-008 Joining-script words are atomic (approved, default on)
Upstream: a word in Arabic, Syriac or N'Ko is cut into letters like any other — as graphemes when the value is a single word, and by LCS when a changed word is at least 40 % similar. Flutter: `lib/src/core/joining.dart` marks such words atomic; `segmentText` keeps a run of joining-script graphemes as one segment and `diffSegments` never pairs an atomic word for a character morph, so the smallest unit that enters or exits is the word. Cause: connected letters have no per-letter identity a reader recognises; a letter moving between joined neighbours reads as corruption, not motion (and RTL-005's isolated exiting forms go with it). Perceptual impact: a changed Arabic word cross-fades whole. Numbers, spaces and Latin words in the same value are unaffected. API impact: none; `debugSplitJoiningWords` (package:torph/testing.dart) restores upstream splitting for the parity suites. Evidence: test/core/joining_test.dart, test/widget/arabic_test.dart.

Candidates under investigation (not yet deviations):
- CJK/Thai dictionary word segmentation in ICU (only reachable when such text also contains a space or newline).
- Font metrics: browser vs Flutter line height / advances differ; kinematic parity is compared in normalised units (per-item deltas relative to that platform own layout).
