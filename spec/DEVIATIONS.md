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

Candidates under investigation (not yet deviations):
- CJK/Thai dictionary word segmentation in ICU (only reachable when such text also contains a space or newline).
- Font metrics: browser vs Flutter line height / advances differ; kinematic parity is compared in normalised units (per-item deltas relative to that platform own layout).
