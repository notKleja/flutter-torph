# A2 challenge report

Behaviours the Flutter port is most likely to get wrong, ranked by
(likelihood of a mistake) × (visibility of the mistake). Every item carries a
reproducible input sequence and the **upstream-observed numbers**, taken from
`oracle/fixtures/runtime/` (Torph 0.1.3 @ `d79a5aa63226acf97d49c3e34fafb2e85c07b026`,
Chrome 152 headless, Menlo 20 px / `line-height: normal` → line box 24 px, glyph
advance 12.046875 px, virtual clock).

Regenerate with `cd oracle/runtime && npm run trace` (see its README). None of the
items below is covered by any upstream unit test — `__tests__` stops at
segmentation, diffing, numbers, easing and container-size arithmetic.

---

## 1. A single-keyframe animation composites over a LIVE underlying value, not a snapshot

`ARCHITECTURE.md` D-8 says "the *last started* active track wins for that property".
That is right for two-keyframe tracks and **wrong** for the `offset: 1` / `offset: 0`
single-keyframe tracks, whose missing keyframe is the *underlying value re-resolved
every frame*. Because `detachFromFlow` cancels only `slot.getAnimations()` and never
the nested mover's (`probes.json → getAnimationsScope`: own 1, subtree 3, mover own
2), a numeric mover mid-enter that starts exiting has **two live animations stacked on
one property**, and the exit interpolates away from a moving target.

**Repro** (`probes.json → moverMidFadeThenExit`; scenario
`q012-mover-mid-enter-then-exiting-999-1-000-42-*`):

```
mount(Menlo 20px, default options)   update("999")            # initial render
t=0    update("1,000")
t=40   update("42")                  # 10% — the 100 ms enter fade is still running
```

Mover opacity of the exiting `1` (enter fade 0→1 over 100 ms; exit fade →0 over
`400 × 0.45 = 180` ms):

| t | 40 | 44 | 56 | 72 | 90 | 130 | 220 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| opacity | **0.4** | **0.4302** | **0.5102** | **0.592** | **0.65** | 0.5 | (removed) |

It **rises to ~0.65 before falling**. The naive model (snapshot 0.4, fade to 0)
predicts a monotone 0.4 → 0. Exact law: `enterFade(t) · (1 − exitProgress(t))`.

Mover `translateY` of the same element, and of the `,` (which entered from *below*):

| t | 40 | 44 | 56 | 72 | 90 | 130 |
| --- | --- | --- | --- | --- | --- | --- |
| digit `1` | −12.4859 | −9.6907 | −2.2688 | +5.5242 | +11.7773 | +19.0221 |
| symbol `,` | +12.4859 | **+12.2088** | **+12.1749** | +13.4713 | +15.6929 | +19.8231 |

The `,` is **non-monotonic** — it dips before rising, because the enter animation is
still pulling it toward 0 while the exit pulls it toward +24.

Interrupt after the fade has settled (t = 100, 25 %) and there is **no jump at all**:
mover `ty` runs `−3.7557 (t=100) → −2.031 (104) → +2.771 (116) → +8.2767 (132) →
+13.1232 (150) → +20.1611 (200) → +24`, continuous across the interrupt. The ledger's
earlier prediction of "a jump from 5px to 0" and "a jump to opaque" is disproved.

**Scope:** numeric movers only. Text exit, group exit and group enter all `cancel()`
first, so their underlying value is the static inline style.

**Required:** per (element, property) an ordered stack of tracks evaluated bottom-up
every frame; single-keyframe tracks are `lerp(underlying(t), keyframe, progress(t))`.

---

## 2. `text-align` shifts an under-full line but never an overflowing one

The pinned first-frame measurement (`element.style.width = oldWidth`) is the whole
reason `text-align` matters — and Chrome does **not** shift a line wider than the
box.

**Repro** (`probes.json → alignPinBehaviour`): render `"hello"`, then read item x
with the root width pinned.

| pin | left | center | right |
| --- | --- | --- | --- |
| natural (60.234) | 0, 12.05, 24.09, 36.14, 48.19 | same | same |
| **30 px (overflow)** | 0, 12.05, 24.09, 36.14, 48.19 | **same** | **same** |
| 300 px (under-full) | 0, 12.05, … | **+119.88** each | **+239.77** each |

So a **grow** produces zero deltas under every alignment, and only a **shrink** with
survivors produces motion (`probes.json → alignDeltas`):

| align | pair | oldW → new line | persisting delta |
| --- | --- | --- | --- |
| left | any | any | `translate(0px, 0px)` |
| center | `"hello world"`→`"hello"` | 132.484 → 60.219 | `translate(-36.125px, 0px)` |
| right | `"hello world"`→`"hello"` | 132.484 → 60.219 | `translate(-72.25px, 0px)` |
| center | `"hello world foo"`→`"hello world"` | 180.656 → 132.484 | `translate(-24.078125px, 0px)` ×3 |
| right | same | same | `translate(-48.15625px, 0px)` ×3 |
| center/right | `"hello"`→`"hello world"` (grow) | 60.234 → 132.5 | `translate(0px, 0px)` |

`centre = −(oldW − lineW)/2`, `right = −(oldW − lineW)`, clamped to 0 when
`lineW > oldW`.

**Required:** `Measurer.measure(items, width:)` must be a real constrained layout with
per-line-box alignment and a zero clamp — not `naturalOffsets + shift`.
Traces: `center-*`, `right-*`, `align-shrink-survivors-*`.

---

## 3. Alignment is per line box, so items move while the container does not

The trap in item 2 gets worse when a *different* line fixes the root width: the
container animation is a literal no-op and the text still travels.

**Repro** (`align-fixedwidth-shrink-*`, `probes.json → alignDeltas`):

```
mount(Menlo 20px, text-align: center)
update("aaaaaaaaaaaaaaaaaaaa\nhello world")
t=0  update("aaaaaaaaaaaaaaaaaaaa\nhello")
```

| observation | value |
| --- | --- |
| container width keyframes | `240.828px → 240.828px` (no-op) |
| container height keyframes | `48px → 48px` (no-op) |
| `aaaaaaaaaaaaaaaaaaaa` (line 1) | `translate(0px, 0px)` |
| `hello` (line 2, survivor), center | `translate(-36.125px, 0px)` |
| `space-26`, `world` (line 2, exiting), center | `translate(+36.125px, 0px)` |
| `hello` survivor, right | `translate(-72.25px, 0px)` |
| exiting, right | `translate(+72.265625px, 0px)` |

Growing line 2 instead gives `+36.140625px` (center) / `+72.28125px` (right).
Note the departure deltas are non-zero too: they come from
`currentMeasures − prevMeasures`, both natural, which cancels for a single-line value
but not across lines.

---

## 4. `scale: false` only disables the *plain text exit* scale

**Repro** (`noscale-*`, options `{scale: false}`):

| animation | keyframe with `scale: false` |
| --- | --- |
| text exit (`"Hello\nWorld"`→`"Hello"`) | `{transform: "translate(0px, 0px)", offset: 1}` — scale **omitted** ✔ |
| text **enter** (`"hello"`→`"hello world"`, item `world`) | `[{transform: "translate(0px, 0px) scale(0.95)"}, {transform:"none"}]` — **still 0.95** |
| text persist (item `h`) | `scale(1)` — unchanged |
| group exit (`"abcdefghijklmnop"`→`"abcmnopqrstuvwx"`) | `{transform: "scale(0.8)", offset: 1}` — **still 0.8** |
| group enter | `{transform: "scale(0.8)", offset: 0}` — **still 0.8** |

A port that threads one `scale` flag through all five paths, or that "fixes" the
inconsistency, breaks parity. `scale` reaches only `animateExit` (index.ts:270).

---

## 5. A same-target storm does not postpone `onAnimationComplete`; a moving-target storm does

`animateAxis`'s resume branch (`|previous.to − to| < 0.5`) re-creates the animation
seeked to `previous.elapsed` with `startedAt = now() − seek`, so the axis finishes
`duration` after the **first** update.

**Repro A** (`storm-digits-1-5-*`): `"1"→"2"→"3"→"4"→"5"`, 16 ms apart. Width is
12.046875 throughout, so the target never moves.

```
width keyframes each time: [{width:"12.0469px"},{width:"12.0469px"}]
seek0:  0, 16, 32, 48                  # <- the resume seek
callbacks: start@0, start@16, cancel@16, start@32, cancel@32,
           start@48, cancel@48, complete@400        # NOT 448
```

**Repro B** (`storm-grow-*`): `"hi"→"hello"→"hello world"→"hello world foo"`, 16 ms
apart.

```
width  @0  [24.0938 → 60.2344]  seek0 0
width  @16 [31.5469 → 132.5]    seek0 0     # target moved -> fresh curve
width  @32 [52.375  → 180.672]  seek0 0
height @16 [24 → 24]            seek0 16    # height target did NOT move -> resumed
height @32 [24 → 24]            seek0 32
callbacks: ... complete@432                 # 32 + 400
```

Two things to get right: (a) the two axes snapshot and resume **independently**;
(b) the `from` of each restart is the interpolated mid-flight size
(31.5469 at t = 16, 52.375 at t = 32), not the previous `from` or `to`.

---

## 6. `oldWidth` is the interpolated in-flight width; `oldWidth == 0` cancels the container outright

**Repro A** (`probes.json → midFlightComputedWidth`): `"hi"` → `"hello world foo bar"`.
`getComputedStyle(root).width` reads **24.0938** (t=0), **196.781** (100),
**224.281** (200), **228.469** (300), **228.828** (400). An interrupt therefore
inherits the animated value: `container-oldwidth-mid-flight-*` interrupts `"hi"` →
`"hello world"` at t = 200 and the next axis is `[130.078px → 24.0938px]` — not
132.484, not 24.0938.

**Repro B** (`probes.json → zeroOldWidth`, case b):

```
mount(Menlo 20px)   update("hello")          # root 60.2344 x 24
t=0    update("")                            # empty transition -> holdContainerSize
                                             # inline width pinned "60.2344px"
t=400  hold timer fires -> restore; root computed width becomes 0, height stays 24
t=500  update("hello")                       # oldWidth == 0
```

Observed at t = 500: callbacks `start@500` then `cancel@500`, **zero** root
width/height animations created, and the root jumps 0 → 60.2344 in one frame. The
item animations still run normally (`scale(0.95)` → `none` over 400; opacity 0 → 1
over 200 with delay 100).

Contrast an interrupt **during** the hold (`interrupt-25-hello-hello-*`): `oldWidth`
is the pinned 60.2344, so a degenerate `[60.2344px → 60.2344px]` pair *is* created and
`complete` fires at 500 = 100 + 400. Callbacks: `start@0, start@100, cancel@100,
complete@500`.

`onAnimationComplete` timing is exact to the millisecond: nothing at t = 399.9, fired
at t = 400 (`probes.json → completeTiming`, three pairs).

---

## 7. Interrupting a mid-enter item snaps its scale to 1 (or 0.95) — and a zero-delta persist still cancels

`animateEnterOrPersist` reads back only `tx, ty, opacity`; scale is discarded.

**Repro** (`interrupt-25-hello-world-hello-there-hello-friend-*`):

```
update("hello world"); t=0 update("hello there"); t=100 update("hello friend")
```

`there` arrived at t = 0 and is mid-enter at t = 100:

| t | 80 | 96 | **100 (interrupt)** | 104 |
| --- | --- | --- | --- | --- |
| `sx` | 0.9883 | **0.9915** | **1** | 0.9974 |
| opacity | 0 | **0** | **1** | 0.96 |
| exiting | false | false | true | true |

`detachFromFlow` cancelled its animations, so `sx` snapped from 0.9915 to the
underlying `none` (1) and the fresh exit keyframe re-runs it down to 0.95.

**And the opacity jumps 0 → 1.** `detachFromFlow` snapshots
`Number(getComputedStyle(child).opacity) || 1` — and `0 || 1` is **1** in JS. The
enter fade of a new text item has `delay = duration × 0.25`, so at t = 100 `there`
was still at opacity 0; the snapshot coerces that to 1, writes `style.opacity = "1"`,
and the exit fade then runs **1 → 0** over 100 ms. An item that was invisible flashes
fully opaque on the interrupt. The same `|| 1` coercion is in `cancelAnimations`
(`utils/animate.ts:47`), so a re-persisting zero-opacity item also reads
`prev.opacity = 1`, which makes `startOpacity = 1` and therefore **skips the fade
entirely** (`if (startOpacity < 1)`), snapping it to opaque.

This is a coercion bug in upstream, and it must be reproduced verbatim: Dart's
`double.tryParse('0') ?? 1` gives `0`, which is *not* what upstream does. Port it as
`(o == 0 || o.isNaN) ? 1 : o`.

In the same update, the persisting `hello` and `space-5` each receive
`[{transform: "translate(0px, 0px) scale(1)"}, {transform: "none"}]` over the full
400 ms — a **zero-delta animation that renders nothing but cancels whatever was
running**. That cancel *is* the snap. `animateNumberPersist` is the only path that
bails early (`if (startX === 0 && startY === 0) return`) — and only *after* it has
cancelled the slot's animations.

Do not optimise the no-op animation away; the cancel is load-bearing.

---

## 8. Numeric digits pair by LCS over characters when the integer digit counts differ, so "999 → 1,000" replaces everything

`matchDigits(..., reversed)` runs an LCS over the digit *characters*. `"999"` vs
`"1000"` has an empty LCS, so nothing pairs.

**Repro** — reuse digest at t = 0 of each two-step trace (`kept` = same `torph-id` as
the initial render and not exiting):

| from → to | kept | exiting | fresh |
| --- | --- | --- | --- |
| `"9"` → `"10"` | — | `9` | `1 0` |
| `"99"` → `"100"` | — | `9 9` | `1 0 0` |
| `"$999"` → `"$1,000"` | `$` | `9 9 9` | `1 , 0 0 0` |
| `"9.99"` → `"10.00"` | `.` | `9 9 9` | `1 0 0 0` |
| `"-999.50"` → `"-1,000.00"` | `- . 0` | `9 9 9 5` | `1 , 0 0 0 0` |
| `"$999.50"` → `"$1,000,000.00"` | `$` | `9 9 9 . 5 0` | 12 fresh |
| **`"1234"` → `"1,234"`** | **`1 2 3 4`** | — | `,` |
| `"1 of 10"` → `"2 of 10"` | `␠ of ␠ 1 0` | `1` | `2` |
| `"$120"`@2 → `"$1120"`@3 (cursor) | `$ 1 2 0` | — | `1` |
| `"a\n1,234\nb"` → `"a\n5,678\nb"` | `a , b` | 4 digits | 4 digits |

Equal integer digit counts pair by **column** (`"1234"`→`"1,234"` keeps all four);
unequal counts fall to a character LCS and usually keep nothing. The visible
consequence is that a counter crossing a power of ten does *not* roll — it is wholly
replaced. Worth a named parity test in both directions.

---

## 9. Separator IDs are keyed by UTF-16 offset, so a word reorder replaces every separator

`space-<utf16CharOffset>` / `newline-<offset>` into the **new** value.

| from → to | kept | exiting | fresh |
| --- | --- | --- | --- |
| `"one two three"` → `"three two one"` | `three two one` (all 3 words!) | `␠ ␠` | `␠ ␠` |
| `"Copy Address"` → `"Address Copied"` | `Address` | `Copy ␠` | `␠ Copied` |
| `"Transaction Safe"` → `"Processing Transaction"` | `Transaction` | `␠ Safe` | `Processing ␠` |
| `"the cat the"` → `"the dog the"` | `the ␠ ␠ the` | `cat` | `dog` |
| **`"😀 hi"` → `"hi 😀"`** | **everything, incl. the space** | — | — |
| `"مرحبا"` → `"مرحبا بالعالم"` | all 5 graphemes | — | `␠ بالعالم` |
| `"café"`(NFC) → `"cafe"` | `c a f` | `é` | `e` |
| `"npm"` → `"pnpm"` | `p n m` | — | `p` |
| `"AAAA"` → `"AAAB"` | `A A A` | `A` | `B` |

The emoji row is the one to keep: `"😀 hi"` → `"hi 😀"` reuses *everything* because
the space sits at UTF-16 offset 2 in both strings (the emoji is a surrogate pair) —
so an offset scheme that counts *runes* instead of UTF-16 units would break a case
that currently produces zero exits and zero arrivals.

---

## 10. Two elements can carry the same `torph-id` at once

`"hello"` → `""` leaves `previousSegments = [{id: "empty"}]`, so the next `"hello"`
takes the `oldWords.length <= 1` fast path into `segmentText`, which mints a fresh
allocator and returns the **same** IDs. `reconcileChildren` refuses to reuse exiting
elements, so it creates new spans beside them.

**Repro** (`interrupt-1-hello-hello-*`):

```
update("hello"); t=0 update(""); t=4 update("hello")
```

| t | children | duplicated ids | exiting copies' opacity | live copies' opacity |
| --- | --- | --- | --- | --- |
| 0 | 6 | — | 1 (5 items) + `empty` | — |
| 4 | **10** | `h e l l-3 o` | 0.96 | 0 |
| 16 | 10 | same | 0.84 | 0 |
| 32 | 10 | same | 0.68 | 0 |
| 100 | 5 | — | (removed) | 0 |

Harmless upstream (`measure()` skips exiting children, so no `Measures` key is
ambiguous), fatal for a port that keys items by ID in one map. Note also that the
`empty` ZWSP stand-in is **removed synchronously**, never animated out.

---

## Also verified, lower risk

- **`carry()` is dead code at the default ease.** `cubic-bezier(0.19, 1, 0.22, 1)`
  has `slopeAt(0) = 1/0.19 = 5.263`, so `k = min(8, normV) − 5.263 <= 0` in every
  interrupt and storm scenario at default options — not one carried `linear(...)`
  curve appears. It engages only under a gentler base; the only coverage that exists
  is `carry-easein-*` (e.g. `linear(0, 0.0367, 0.065, 0.0867, 0.103, …)`),
  `carry-linear-*` (`linear(0, 0.1057, 0.1416, 0.1495, 0.1496, …)`) and
  `carry-spring-*`. Sample count is `min(120, max(32, round(duration/8)))` = 50 at
  400 ms, 91 at the spring's 725 ms; values are 4 dp with the last forced to 1.
- **`spring{stiffness: 200, damping: 20}` resolves to duration 725 ms** and a 91-point
  `linear(0, 0.0214, 0.0771, 0.1556, 0.2478, 0.3461, …)`. It replaces `duration`
  everywhere, including all the fade fractions (enter fade = 362.5 ms, etc.).
- **Same-value updates are total no-ops:** `noop-*` traces show 0 animations and 0
  callbacks for both a text and a numeric repeat.
- **`slideDistance = offsetHeight / lineCount`** and it is the *line box*, not the
  font size: 24 px at Menlo 20 px. Three-line `"a\n1,234\nb"` gives
  `offsetHeight = 72`, `lineCount = 3`, `slideDistance = 24` — digits arrive from
  `translate(0px, -24px)`, symbols from `+24px`.
- **Group replacement `transform-origin`** is restated per member and is *not*
  cleared for the run's duration. `"abcdefghijklmnop"` → `"abcmnopqrstuvwx"`, the
  9 exiting members get origins `54.5234px 12px, 42.5234px, 30.5234px, 18.5234px,
  6.52344px, -5.47656px, -17.4766px, -29.4766px, -42.4766px` (all `12px` vertical) —
  i.e. negative values are normal. Persisting members read the default
  `6.02344px 12px` because `reconcileChildren` clears the inline origin.
- **Group fades:** exit `duration × 0.45` (180 ms), enter `duration × 0.35`
  (140 ms) and enter *always* animates opacity even from 1, unlike
  `animateEnterOrPersist` which only does so when `startOpacity < 1`.
- **Enter fade timing:** new text items get `delay = duration × 0.25` and
  `duration × 0.5`, so at t = 100 of a 400 ms morph a newly arrived item is still at
  opacity **0** — first motion, then fade in. Persisting items get no delay and
  `duration × 0.25`.
