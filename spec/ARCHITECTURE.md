# Architecture

```
TextMorph (StatefulWidget)  → configures
TextMorphState              → owns MorphEngine + one Ticker (SingleTickerProviderStateMixin), reduced-motion listener
MorphEngine (pure Dart; no widgets)  → update(value, cursor) → Scene; frame(t) → FrameState
  ├── core/      segmentation, IDs, LCS, diff, numbers, replacement runs   (no dart:ui)
  ├── motion/    easing, spring, carry, WAAPI-equivalent tracks, container axes, FLIP maths
_TextMorphRenderWidget (LeafRenderObjectWidget)
RenderTextMorph (RenderBox)  → measures logical items with TextPainter (geometry authority), performLayout sizes the box
                                from the container axes, paint draws items with their current transform/opacity
```

Key decisions:

- D-1 One State-owned ticker; every animated property is a `Track` evaluated at the shared elapsed time. No AnimationControllers.
- D-2 The engine needs measurement mid-update (upstream measures the DOM between reconciliation steps). `MorphEngine.update` takes a `Measurer` interface: `measure(items, {double? width})` returns per-item layout offsets for the given item list under a given container width (null = natural), plus natural size and line count. The render object implements it with TextPainter; tests implement it with a fake monospace layout. This keeps geometry with Flutter and logic in the engine.
- D-3 Items are retained logical objects (`MorphItem`: id, string, kind, exiting flag, layout offset, size, transform tracks, opacity tracks, mover tracks). Never widgets.
- D-4 (decided M4, see RENDERER_SPIKE.md + RENDERER_CONTRACT.md) Per-item TextPainters (Strategy A). Upstream renders each item as its own inline-block, so cross-item shaping and bidi reordering of items are *not* upstream behaviour (trace `مرحبا`: graphemes flow left-to-right in logical order inside an LTR root).
- D-5 Layout invalidation only when the container axes change size or the value/style changes; per-frame ticks call `markNeedsPaint`.
- D-6 Time is injected: the engine's clock is the ticker's elapsed time (ms as double), so tests are deterministic via `tester.pump`.
- D-7 Semantics: one label = current value.
- D-8 (corrected by Q-012 runtime evidence) WAAPI is modelled as an *animation stack*: per element, per property, the ordered list of active `Track`s is folded bottom-up every frame; a neutral (missing) keyframe reads the value produced by the tracks beneath it, so a single-keyframe exit started over a still-running enter departs from wherever the enter is at that frame (non-monotonic mover opacity is upstream behaviour). Tracks with `fill: both` hold their end values; tracks are removed only by explicit cancel (mirroring `getAnimations().forEach(cancel)`, which never reaches the nested mover) or by the element's removal. `onfinish` of the fade track removes exiting elements.
- D-9 Play-pending semantics: a track created by `update()` starts at the next `frame()`; the State delivers a frame at the update's instant.
- D-10 `measure` reports the *visual* box minus translate (a running scale about the current origin shifts it) — upstream measures `getBoundingClientRect()`; item layout stays pure and is re-derived per frame under the animated container width (aligned lines move with the box).
