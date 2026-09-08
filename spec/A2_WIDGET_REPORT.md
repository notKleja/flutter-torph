# A2 widget parity report

Scope: the **widget**, not the engine. `test/parity/runtime_trace_parity_test.dart`
already proves the pure engine reproduces all 168 browser traces when it is fed
the browser's own widths. This report asks the next question: does
`TextMorph` + `RenderTextMorph` + `TextMeasurer` + one `Ticker` still reproduce
them, and does anything a widget can suffer — a scaler, a style, a direction, a
`TickerMode`, a `dispose`, 320 random storms — break an invariant.

Pinned reference: torph 0.1.3 @ `d79a5aa63226acf97d49c3e34fafb2e85c07b026`,
Chrome 152 headless, Menlo 20 px (glyph 12.046875, line box 24).
Flutter 3.44.6, default test font (glyph 20, line box 20).

## Verdict

| suite | tests | result |
| --- | --- | --- |
| `test/parity/widget_trace_parity_test.dart` | 169 | **pass** |
| `test/parity/widget_adversarial_test.dart` | 28 | 26 pass, **2 fail (F-1)** |
| `test/fuzz/morph_fuzz_test.dart` | 322 | 321 pass, **1 fail (F-1, 13 cases)** |
| `flutter test test/parity test/fuzz` | 1580 | 1573 pass, 4 skip (pre-existing ICU dictionary gaps), **3 fail** |
| `flutter test` (whole repo) | 2430 | 2423 pass, 4 skip, **3 fail** — the same three |

Every failure in the repo is **one defect**, F-1. Nothing else diverges: all 168
traces reproduce through the widget, and every invariant INV-1…INV-15 holds at
every pump of 320 random sequences.

Two further divergences are *unavoidable* rather than wrong (F-2, F-3): upstream
quantises two numbers to whole CSS pixels, and the port quantises the same two
numbers to whole Flutter pixels. Same semantics, different quantum. They are
logged as Q-026 and Q-027 with the evidence that proved them.

---

## PARITY FAILURE F-1 — the frame that completes a container transition never re-measures

**Where.** `lib/src/motion/morph_engine.dart:906-916`:

```dart
final c = _container;
if (c != null && !c.stopped && c.finished(t)) {
  _container = null;              // the root's width becomes the natural width
  c.stop();
  c.onComplete?.call();
}
final pinned = _pinnedWidth;      // ← now null
if (pinned != null) _measureInto(liveItems, width: pinned);   // ← so no re-measure
```

Every other frame of a transition re-measures the live items at the animated
width, which is what makes per-line alignment follow the container. The frame
that *ends* the transition swaps the root to its natural width and skips the
re-measure, so the line keeps the alignment offset of a width the root no longer
has — permanently, until the next update.

Upstream cannot have this bug: `animate.ts:313-318` runs
`restoreSize(element)` **before** `onComplete?.()`, and the DOM re-lays the
spans out the instant the inline width is removed.

**Why it is normally invisible.** The animated width converges on the natural
width, so on a well-fed 60 fps timeline the residual is a rounding error, and
under `TextAlign.left` + LTR the line starts at 0 whatever the container width
is. It becomes visible whenever the final container width differs *materially*
from the natural width, which happens in two reachable ways.

### F-1a — a natural width that moved mid-flight

`test/parity/widget_adversarial_test.dart` →
`F-1 (open finding): … leaves the line outside the root`

```
host(TextMorph('hello world'), textAlign: center)     // natural 220 × 20
pumpWidget(TextMorph('hello'))                        // width animates 220 → 100
pump(100 ms)
pumpWidget(TextMorph('hello'), textScaler: 0.5)       // natural becomes 50 × 10
pump 40 × 16 ms                                       // the transition finishes
```

| observation | value |
| --- | --- |
| `snapshot.size` / `renderObject.size` | `Size(50, 10)` ✔ |
| `item('hello').width` | `50` ✔ |
| `item('hello').transform.tx` | `0` ✔ |
| **`item('hello').x`** | **`25.00013126358207`** — expected `0` |

The line is 50 px wide, its box is 50 px wide, and it is painted 25 px outside
it, centred in the released 100 px container. The exact failing assertion:

```
Expected: <0>
  Actual: <25.00013126358207>
```

The scaler is the cheapest trigger; any mid-flight change to a measurement input
(`style`, `textScaler`, `textDirection`, `locale`, `textAlign` — everything that
calls `MorphEngine.remeasure()`) does the same, because `remeasure` updates the
natural size while the container transition keeps the target it was created
with (correctly — WAAPI keyframes are fixed too).

### F-1b — a completed hold

`test/parity/widget_adversarial_test.dart` →
`F-1 (open finding): a completed hold leaves the empty stand-in offset`

```
host(TextMorph('hello'), textAlign: center)   // 100 × 20
pumpWidget(TextMorph(''))                     // holdContainerSize pins 100 for 400 ms
pump 40 × 16 ms                               // the hold completes, width → 0
```

| observation | value |
| --- | --- |
| `snapshot.size.width` | `0` ✔ |
| **`liveItems.single.x`** (the `​` stand-in) | **`50`** — expected `0` |

```
Expected: <0>
  Actual: <50.0>
```

The stand-in is zero-wide so nothing is painted; this case matters because it is
the same defect and because the fuzz corpus hits it constantly:
`test/fuzz/morph_fuzz_test.dart` → `F-1: a settled line is aligned to the width
the root actually has` collects **13 of 320** seeds, e.g.

```
seed 25 (ltr, center, last ""):  the line "​" rests 111.581 px from where the root width 0.000 puts it
seed 139 (rtl, right, last ""):  the line "​" rests 166.265 px from where the root width 0.000 puts it
seed 188 (rtl, start,  last ""): the line "​" rests 146.595 px from where the root width 0.000 puts it
```

**Suggested fix (A1's call, not mine):** re-measure at the natural width on the
completing frame — i.e. re-read `_pinnedWidth` *after* the container is cleared
and call `_measureInto(liveItems, width: null)` when it went from non-null to
null. That is upstream's `restoreSize` before `onComplete`, in the same order.
Both failing tests then assert the correct value and turn green; nothing in the
168 traces changes, because there the animated width already equals the natural
width at completion (the widget trace suite passes with the current code to
0.25 px, so a fix cannot regress it).

**Repro commands**

```
flutter test test/parity/widget_adversarial_test.dart --plain-name "F-1"
flutter test test/fuzz/morph_fuzz_test.dart          # the aggregate at the end
flutter test test/fuzz/morph_fuzz_test.dart --plain-name "seed 25"
```

---

## How the widget trace suite compares (and what it deliberately cannot)

`test/parity/widget_trace_parity_test.dart` drives the real widget through every
scenario in `oracle/fixtures/runtime/*.json`: the trace's own options
(`ease` string or `SpringParams`, `duration`, `scale`, `numbers`, `decimals`,
`locale`), its `page.textAlign` through `DefaultTextStyle`, its
`page.direction: rtl` through `Directionality`, its `initialCursorIndex` /
`cursorIndex`, and `tester.pump` at every sample time, every step time and every
callback time.

Clock discipline: a `Ticker`'s first tick reports elapsed 0, so the zero tick is
consumed after every start (`test/widget/harness.dart` `startClock`) and each
later `pump(delta)` lands on the trace instant exactly. Updates are applied by
`pumpWidget` at the instant of the last tick, so `engineTime == traceTime` at
every step and every sample. Callbacks are timestamped with the trace instant
they fire at (see Q-029: the engine clock freezes while the ticker is stopped,
so absolute engine time drifts from wall time across idle gaps — nothing
observable depends on it, but a naive `snapshot.now` comparison would be wrong).

Compared at every one of the 4 272 samples (168 traces × their sample times, plus each trace's initial render):

| quantity | how | tolerance |
| --- | --- | --- |
| item set, order, exiting flag, text | id-normalised (`U+0000 n<counter>` → `#i` by first appearance), joined and compared as a sequence | exact |
| `transform.sx`, `transform.sy`, `opacity`, `moverOpacity` | verbatim — they are shares, not lengths | 2 × 10⁻³ |
| `moverTransform.ty` | `ty / lineBox` on both sides | 2 × 10⁻³ of a line |
| `transform.tx`, `transform.ty` | browser value × `S` (`S` = flutterWidth/browserWidth, `Sv` = 20/24) | 2 % or 0.25 px |
| `visualRect.left/top` | browser rect × `S` / `Sv` | 0.25 px (+ 1.33 px for an exiting box, F-2) |
| root width / height | browser computed size × `S` / `Sv` | 2 % or 0.25 px |
| `renderObject.size` | equals the frame's own size | 10⁻³ px |
| callbacks | `name@instant`, in order | exact |

`S` is only meaningful when the two fonts are metrically proportional, which the
test checks per trace rather than assuming (the spread of per-text width ratios
must be ≤ 2 %). Where it is not, that axis is skipped and named:

| traces | skipped |
| --- | --- |
| `helvetica-*` (5) | horizontal geometry — Helvetica is proportional, ratios 1.20…4.49 |
| `hi-hi-d128c3` (emoji) | horizontal *and* vertical — the emoji falls back to a 22 × 29 box |
| `rtl-*`, `rtl-center-*`, `rtl-end-*`, `scenario-6eac9d` (4) | vertical geometry — the Arabic fallback makes a 25 px line box |

Those 10 traces still compare item identity, order, scale, opacity, mover
geometry and callbacks. The other 158 compare everything.

**Sensitivity check.** Multiplying the widget's `tx` by 1.03 and adding 0.3 px
makes 162 of the 168 traces fail, so the suite is not vacuous.

---

## PASS/FAIL matrix at widget level (spec/PARITY.md categories)

| ID range | widget-level evidence | result |
| --- | --- | --- |
| SEG-001…006 | every trace's item texts and ids through the widget; emoji/RTL/`café`/NBSP corpus in the fuzz | **pass** |
| ID-001…006 | id sequences per sample (minted ids normalised); `INV-1`, `INV-4`, `INV-6` at every pump of 320 seeds; adversarial 9 (`"😀 hi"` → `"hi 😀"` reuses every id, `"one two three"` → `"three two one"` replaces both separators) | **pass** |
| DIFF-001…010 | trace item sets at every sample; adversarial 8 (`1234`→`1,234` keeps 4, `999`→`1,000` keeps 0, `-999.50`→`-1,000.00` keeps 3) | **pass** |
| NUM-001…008 | numeric traces through the widget; `INV-5` per item; num-typed values in the fuzz corpus | **pass** |
| REPLACE-001…003 | `abcdefghijklmnop`→`abcmnopqrstuvwx` traces; adversarial 4 (group scale 0.8 survives `scale: false`) | **pass** |
| FLIP-001…004, ENTER-001, PERSIST-001, EXIT-001 | per-item `tx`/`sx`/`opacity` at every sample; adversarial 2, 3, 7 | **pass** |
| NUM-MOTION-001…003 | mover `ty`/opacity normalised by the line box at every sample; adversarial 1 | **pass** |
| NUM-MOTION-004 (mask) | not observable through the snapshot; Flutter-to-Flutter golden owned by A1 | not covered here |
| INTERRUPT-001…005 | 90 interrupt/storm traces; adversarial 1, 6, 7, 10; 320 fuzz sequences with 1–99 % interrupts and 16 ms storms | **pass** |
| CONTAINER-001…006 | root size at every sample; `INV-13` at every update; adversarial 5 (storm completes at 400 vs 432), 6 (in-flight `oldWidth`), 6b (`oldWidth == 0` → `start`,`cancel`, no container motion) | **pass** |
| CONTAINER-007 | adversarial 2 and 3: grow → 0 under every alignment, centred shrink → −60, per line box with a fixed root | **pass** |
| **the restore at completion** | F-1a, F-1b | **FAIL** |
| CALLBACK-001…003 | callback name+instant per trace; `starts == morphs` and `complete+cancel == starts` per fuzz sequence | **pass** |
| LIFECYCLE-001…003 | adversarial `disabled` mid-morph (ticker stops, plain text, no callback, re-enable renders without motion), dispose mid-morph (no callbacks, no exception, `cachedPainterCount` 0) | **pass** |
| EMPTY-001, EMPTY-002 | adversarial 6b and 10 (`empty` removed synchronously, never animated); fuzz corpus includes `''` | **pass** |
| LINES-001, LINES-002 | multi-line traces; `INV-9` resting layout per line in the fuzz | **pass** |
| RTL-001 | 18 RTL traces through `Directionality`; adversarial direction flip mid-morph | **pass** |
| ACCESS-001 | `tester.getSemantics(...).label == value` in all 320 fuzz sequences | **pass** |
| ACCESS-002 | A1's `test/widget/reduced_motion_test.dart`; `disabled` path re-checked here | **pass** |
| SPRING-001, EASE-001, CARRY-001 | the 11 spring traces and 12 `carry-*` traces run through the widget | **pass** |

---

## Two divergences that cannot be fixed, only known

### F-2 — an exiting box is pinned at a *rounded* offset (Q-026)

`utils/dom.ts:18-29` walks `offsetLeft`/`offsetTop`, which Chrome returns as
**integers**. `"one two three"` → `"three two one"`: the exact layout puts
`space-7` at 84.328125, and the trace shows every frame consistent with a pin at
**84.0**. The port replicates the rounding (`jsRound`, `morph_engine.dart:498`)
— but in Flutter pixels, where the same box sits at 140.0 and rounds to itself.
Two integer roundings of two different metrics are not related by a scale
factor, so the widget trace suite allows an exiting box's absolute position
0.5 × S + 0.5 ≈ 1.33 px of slack. Its `tx` stays strict (it matched to 0.04 px).

Nothing to fix; worth knowing that exiting text can sit up to half a logical
pixel off its exact layout position, by design.

### F-3 — `slideDistance` is quantised by `offsetHeight` (Q-027)

`text-morph/index.ts:242` divides `element.offsetHeight`, another integer, by
the line count. The port rounds its own root height the same way
(`morph_engine.dart:373`). With a fractional line box (a real font at a real
scale factor, e.g. 23.4 px) the browser slides 23 and the port slides 23 as
well — but the *fraction* they each throw away is different, so a mover's travel
can differ from the reference by up to 1 px ÷ lineCount. Semantics identical,
quantum different. The widget trace suite normalises the mover by each side's
own line box, which is why it does not see this.

---

## Top risks

1. **F-1.** One-line defect, permanent visual effect, and it needs only a font
   scale change (an accessibility setting!) landing during a morph under a
   non-left alignment. Fix it before anything else.
2. **Anything that changes the natural size while a container transition runs**
   is the least-tested corner of the port in general. `remeasure()` updates the
   natural size but never the in-flight transition's target — which matches
   WAAPI — so the root's size *jumps* at completion. Parity holds (the browser
   jumps too, `restoreSize`), but the jump is large and nobody has looked at it
   with an eye to whether it is *acceptable*, only whether it is *faithful*.
3. **The callback fires one frame stale at the widget layer** (Q-030). The
   engine calls `onAnimationComplete` from inside `engine.frame()`, before
   `TextMorphState` stores the frame or hands it to the render object, so a
   callback that reads `debugSnapshot()` or the render object's size sees the
   *previous* frame. Upstream calls back after `restoreSize`, i.e. after the box
   is final. Cheap to fix, invisible until someone measures in a callback.
4. **The engine clock freezes while the ticker is stopped** (Q-029). No upstream
   behaviour depends on absolute time, so this is currently harmless — but any
   future feature that does (a delay, a debounce, a timestamp) would silently
   diverge, and the widget trace suite only passes because it timestamps
   callbacks with trace instants rather than engine time.
5. **`TickerMode` semantics are an unlogged decision** (Q-031). A muted `Ticker`
   keeps its start time, so an off-screen morph keeps *aging* and jumps forward
   on unmute. That is WAAPI's behaviour (an off-screen animation keeps playing),
   so it is the right choice — but it is a choice, and it is now pinned by
   `test/parity/widget_adversarial_test.dart`.
6. **Cost.** A 100-word, 700-character value morphing into a permutation of
   itself, measured in a widget test on this machine: **update 26.1 ms**, frame
   **median 1.18 ms**, **worst 2.41 ms** (whole `tester.pump`, pipeline
   included). No quadratic behaviour — but the *update* is 20× a frame and it
   runs inside the build phase, so a 100-word morph drops frames at the moment
   it starts. Worth a look at `_measureInto` (three full measures per update)
   before anyone ships a live-updating paragraph.

## Repro commands

```
flutter test test/parity test/fuzz            # everything: 1573 pass, 4 skip, 3 fail (all F-1)
flutter test test/parity/widget_trace_parity_test.dart
flutter test test/parity/widget_trace_parity_test.dart --plain-name "center-999-1-000"
flutter test test/parity/widget_adversarial_test.dart --plain-name "F-1"
flutter test test/fuzz/morph_fuzz_test.dart --plain-name "seed 25"
```
