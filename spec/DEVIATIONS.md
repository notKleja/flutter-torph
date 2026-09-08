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

Candidates under investigation (not yet deviations):
- CJK/Thai dictionary word segmentation in ICU (only reachable when such text also contains a space or newline).
- Font metrics: browser vs Flutter line height / advances differ; kinematic parity is compared in normalised units (per-item deltas relative to that platform own layout).
