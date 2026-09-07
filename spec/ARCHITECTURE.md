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
- D-4 Per-item TextPainters (Strategy A) unless the M4 spike proves otherwise; upstream renders each item as its own inline-block, so cross-item shaping is *not* upstream behaviour.
- D-5 Layout invalidation only when the container axes change size or the value/style changes; per-frame ticks call `markNeedsPaint`.
- D-6 Time is injected: the engine's clock is the ticker's elapsed time (ms as double), so tests are deterministic via `tester.pump`.
- D-7 Semantics: one label = current value.
- D-8 WAAPI is modelled as: per element, per property (`transform`, `opacity`), an ordered list of active `Track`s; the *last started* active track wins for that property (composite replace); tracks with `fill: both` hold their end values; tracks are removed only by explicit cancel (mirroring `getAnimations().forEach(cancel)`) or by the element's removal. `onfinish` of the fade track removes exiting elements.
