# Renderer contract (frozen by A0 after M4)

Decision M4 (evidence: spec/RENDERER_SPIKE.md, oracle/fixtures/runtime/scenario-6eac9d.json):
**Strategy A — one cached TextPainter per logical item, positioned by the engine's layout, no cross-item shaping, no bidi reordering of items.** Upstream renders every segment as its own `display:inline-block` span, so joining/kerning/ligatures across segments and UAX#9 reordering of segments are *absent* in the reference too; the browser trace for `"مرحبا"` shows the graphemes laid out left-to-right in logical order inside an LTR root. Strategy B (whole-paragraph slicing) would be a deviation. A also wins raster cost at scale and gives true per-item opacity.

## Files

```
lib/src/rendering/text_measurer.dart     TextMeasurer implements Measurer (TextPainter cache + line layout)
lib/src/rendering/render_text_morph.dart RenderTextMorph extends RenderBox (+ _TextMorphRenderWidget LeafRenderObjectWidget)
lib/src/widget/text_morph.dart           TextMorph (StatefulWidget) + TextMorphState
lib/src/widget/options.dart              option resolution (defaults, config key, ease/spring)
lib/src/semantics/accessibility.dart     reduced-motion query helper
lib/src/debug/morph_snapshot.dart        TextMorphSnapshot (test/debug API wrapping FrameState)
lib/torph.dart                           public exports
```

## TextMeasurer (`Measurer`)

Inputs fixed per instance: `TextStyle style` (already merged with `DefaultTextStyle`), `TextScaler`, `TextDirection`, `Locale?`, `TextAlign` (resolved to `left|center|right` using the direction: `start`→left in LTR / right in RTL, `end` the opposite, `justify`→left), `TextHeightBehavior?`, `StrutStyle?`.

`measure(items, {width})`:
1. Split `items` into lines at break items (`isBreak`). A trailing break creates an empty last line, as `<br>` does.
2. For each non-break item, a `TextPainter(text: TextSpan(text: item.string, style), textDirection, textScaler, locale, maxLines: 1)` laid out with no constraints (`layout()`); cached by `(string, style, textScaler, textDirection, locale)`. Item width = `painter.width`, item height = `painter.height`, item baseline = `painter.computeDistanceToActualBaseline(TextBaseline.alphabetic)`. NBSP measures like a space; U+200B measures 0 wide at full height.
3. Line metrics: `ascent = max(baseline_i)`, `descent = max(height_i − baseline_i)`, `lineHeight = ascent + descent`; a line with no items uses `painter('​')`'s height (strut). Item `y = lineTop + ascent − baseline_i` (baseline alignment, as the browser's line box does). `lineTop` accumulates line heights.
4. Horizontal: `lineWidth = Σ width_i`; `containerWidth = width ?? naturalWidth` where `naturalWidth = max lineWidth`; `free = containerWidth − lineWidth`. If `free ≤ 0` the line overflows and is start-aligned (LTR: left = 0; RTL: left = containerWidth − lineWidth). Else `left = free × {left: 0, center: 0.5, right: 1}`. LTR: `x_i = left + Σ_{j<i} width_j`. RTL: `x_i = left + lineWidth − Σ_{j≤i} width_j` (items flow from the right, logical order preserved — no bidi reordering).
5. `naturalHeight = Σ lineHeight` (0 when `items` is empty).
6. Deterministic and pure: the same inputs always give the same result; no render tree needed (usable from `State` during `didUpdateWidget`).
7. Painters are disposed when evicted, when the style/scaler/direction/locale change (cache cleared), and on dispose.

## RenderTextMorph

- Owns nothing about time. Receives `FrameState frame` (setter): if `frame.width/height` differ from the last laid-out size → `markNeedsLayout()`, else `markNeedsPaint()`. Receives `TextMeasurer measurer`, `bool debug`, `TextStyle style` (for the disabled plain-text path and the slot mask band `0.15 × fontSize × textScaler`).
- `performLayout`: `size = constraints.constrain(Size(frame.width, frame.height))`. `computeDryLayout` the same. Intrinsics report the natural size. No children.
- `paint(context, offset)`: items in `frame.items` order (exiting first, then live — DOM order; all are positioned so order is paint order). Skip breaks and items with `opacity == 0`. Per item with `t = transform`, origin `o`:
  `canvas.save(); canvas.translate(offset.dx + x + o.x + t.tx, offset.dy + y + o.y + t.ty); canvas.scale(t.sx, t.sy); canvas.translate(−o.x, −o.y);` then paint at `Offset.zero`. This equals CSS `transform-origin: o; transform: translate(t) scale(s)`.
  Opacity `< 1`: `canvas.saveLayer(itemBounds, Paint()..color = Color.fromRGBO(0, 0, 0, opacity))` around the paint (glyphs may overlap; a layer is the CSS group-opacity semantic).
  Numeric slot (`kind != null`): after the slot transform, `clipRect(Rect.fromLTWH(−10⁶, 0, 2·10⁶, height))` (block-axis clip only, `clip-path: inset(0 -100vw)`), then `saveLayer` over `Rect.fromLTWH(−10⁶, 0, 2·10⁶, height)`; paint the mover translated by `moverTransform.ty` (tx is always 0) with its own opacity layer if `< 1`; then `drawRect` over the clip with a vertical `LinearGradient` (transparent → black at `band` → black at `height − band` → transparent, `band = 0.15 × fontSize`) using `BlendMode.dstIn`; restore. This is the `--torph-fade` mask.
  Debug: `debug == true` strokes the root bounds magenta (2px) and each item's box cyan (2px, inset 4px).
- Disabled (`frame.plainText != null`): a single `TextPainter` of the whole value (same style, `softWrap` off: lines only at `\n`), painted at `offset`; size = its size.
- `describeSemanticsConfiguration`: `config.label = frame.value; config.textDirection = direction`. Nothing else; fragments are not nodes.
- Never mutates `size` outside `performLayout`.

## TextMorph / TextMorphState

- Constructor per spec/API_SURFACE.md. `value` is `String` or `num`.
- Resolution in `didChangeDependencies`/`build`: `style = DefaultTextStyle.of(context).style.merge(widget.style)`, `textScaler = MediaQuery.textScalerOf(context)`, `direction = widget.textDirection ?? Directionality.of(context)`, `locale = widget.locale ?? Localizations.maybeLocaleOf(context) ?? Locale('en')` (upstream default `"en"`; the engine takes the BCP-47 string), `align = widget.textAlign ?? DefaultTextStyle.of(context).textAlign ?? TextAlign.start`.
- Reduced motion, read at every update (upstream reads the media query live): `disabled = widget.disabled || (widget.respectReducedMotion && (MediaQuery.disableAnimationsOf(context) || accessibilityFeatures.reduceMotion))`.
- Config key (`LIFECYCLE-001`): `ease, duration, locale, scale, numbers, decimals, debug, disabled, respectReducedMotion`. When it changes: dispose the engine (no callbacks), create a new one, replay the last value with the last cursor → renders as an initial render (no motion). Callbacks are read through the latest widget, never captured.
- Geometry inputs (`style, textScaler, direction, locale, align`) changing: rebuild the `TextMeasurer`; do not reset morph history; re-measure the current items (`engine.remeasure()` — engine method to add: re-runs `_measureInto(liveItems, width: pinnedWidth, natural: true)` and refreshes natural size).
- Time: one `Ticker` from `SingleTickerProviderStateMixin`. `engineTime = _base + ticker.elapsed` in ms (double); when the ticker stops, `_base = engineTime`. On `engine.update(...)`: if `engine.isAnimating` and the ticker is not active → `ticker.start()`. Tick: `frame = engine.frame(engineTime)`; hand it to the render object; if `!frame.animating` → `ticker.stop()`. The frame in which the update happened must also deliver a frame: after `engine.update`, call `engine.frame(engineTime)` immediately (so play-pending tracks start at the update's instant, matching WAAPI's next-frame start resolved by the harness at `createdAt`), and push that frame to the render object.
- `TickerMode` off mutes ticks (animation freezes); nothing else.
- Callbacks: the engine calls them synchronously. Because `update` runs inside the build phase, `TextMorphState` wraps each callback: if `SchedulerBinding.instance.schedulerPhase` is `idle`, `transientCallbacks` or `postFrameCallbacks` call immediately; otherwise queue and flush in `addPostFrameCallback`, preserving order (DEV-003).
- `dispose`: ticker dispose, `engine.dispose()` (no callbacks), measurer dispose.
- `debugSnapshot()` on the render object returns `TextMorphSnapshot` (wraps `FrameState`, adds `lineCount`, `naturalSize`, `animating`).

## Tests the delegate must make pass (Flutter widget tests, `tester.pump`)

- Resting geometry: `TextMorph(value: 'hello world')` has the size of `Text('hello world')` (same style) within 0.01; multi-line `'a\nb'` height = 2 line heights; `''` → height of one line, width 0 (initial render of `''` is a no-op upstream: renders nothing — replicate: no items, size 0×0 — LINES/EMPTY tests must assert exactly this: first value `''` → empty root; later `'x'`→`''` → one-line-high stand-in).
- Alignment: `TextAlign.center/right` shift short lines; overflow stays start-aligned; RTL flows from the right.
- Motion: `hello`→`hello world` at `pump(0)`: `world` opacity 0 & scale 0.95, size = old width; at `pump(400ms)` settled, size = new natural; `pump` in 16 ms steps never throws; `TickerMode(enabled:false)` freezes.
- Semantics: one node with label = value during a morph.
- Reduced motion: `MediaQuery(disableAnimations: true)` → plain text, no ticker; toggling back → next update is an initial render.
- Lifecycle: config change replays without motion; value change fires `onAnimationStart` once, then exactly one of complete/cancel; dispose mid-morph fires nothing.
- Golden: `test/goldens/` for `"$1,234.56"` at rest and mid-slide (`pump(60ms)` after `999`→`1,000`), `"hello world"` mid-enter, group replacement mid-flight, `"a\n1,234\nb"` — Flutter-to-Flutter goldens, generated with `--update-goldens`, using a bundled font (Roboto from spike/fonts or the test default).
