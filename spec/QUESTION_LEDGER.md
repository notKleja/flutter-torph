# Question ledger

Format: `Q-### question / files / interpretation / tests / runtime experiment / conclusion / confidence / parity requirement`.

## Q-001 Which Unicode segmentation does `Intl.Segmenter` word granularity apply?
- Files: segment.ts:132. Runtime: Node 26.7 / ICU 78.3 (oracle/fixtures/segmenter.json).
- Interpretation: ICU word break (UAX#29 + ICU rule customisations; dictionary breaking for CJK/Thai/Khmer/Lao/Burmese).
- Conclusion: port UAX#29 word rules in pure Dart, validated against the fixture corpus; dictionary languages tracked as a candidate deviation. Confidence: high for non-dictionary scripts.
- Parity: SEG-002.

## Q-002 Does the character-level diff use graphemes or UTF-16 units?
- Files: diff.ts:40 (`word.split("")`), diff.ts:66, diff.ts:299, number.ts:100.
- Conclusion: UTF-16 code units everywhere after initial segmentation. Dart `split('')` matches. Confidence: certain. Parity: DIFF-006, SEG-005.

## Q-003 Does the root wrap?
- Files: styles.ts:15 (`white-space: nowrap`), index.ts:237 comment.
- Conclusion: never; only `<br>` breaks lines. Parity: LINES-001.

## Q-004 What does the first-frame measurement at the old width change?
- Files: index.ts:244-248. With `text-align: left` nothing; with center/right, shorter/longer lines shift relative to the old width, which is what persisting items are FLIPped against.
- Conclusion: port alignment-aware measurement at the old width. Parity: CONTAINER-007. Runtime confirmation requested from A2 (browser oracle, center alignment).
- **A2 finding (runtime).** Confirmed, with a sharp restriction. `text-align` shifts a line **only when the line is narrower than the pinned width**; Chrome leaves an *overflowing* line at the start edge for every alignment (`probes.json → alignPinBehaviour`: `"hello"` pinned to 30 px reads x = 0, 12.05, 24.09, 36.14, 48.19 under left/center/right alike; pinned to 300 px the same run reads +119.88 under center and +239.77 under right). So the pinned first-frame measurement only bites on a **shrink**, and it bites *every* persisting item on the affected line:
  - `text-align: left` — every persisting delta is exactly `0px, 0px`, all pairs, single- and multi-line.
  - `center`, `"hello world"` → `"hello"` (oldW 132.484, new line 60.219): persisting `hello` gets `translate(-36.125px, 0px)`; `right` gets `translate(-72.25px, 0px)` = `-(oldW - newLineW)` (centre is half that). Both start left of their final position and slide right.
  - `center`, `"hello world foo"` → `"hello world"` (oldW 180.656): `hello`, `space-5`, `world` each get `-24.078125px`; `right` gives each `-48.15625px`.
  - Grow (`"hello"` → `"hello world"`, oldW 60.234 < new line 132.5): `0px, 0px` under all three alignments — the pinned line overflows, so nothing shifts.
  - **Per-line, and independent of the container.** `"aaaaaaaaaaaaaaaaaaaa\nhello world"` → `"aaaaaaaaaaaaaaaaaaaa\nhello"`: the root width is fixed by line 1 at 240.828 px and the container animation is a no-op (`240.828 → 240.828`), yet under `center` the surviving `hello` still gets `-36.125px` and the exiting `space-26`/`world` get `+36.125px`; under `right`, `-72.25px` and `+72.265625px`. The reverse (grow on line 2) gives `+36.140625px` / `+72.28125px`.
  - Departures are measured `currentMeasures - prevMeasures`, both at natural widths, so alignment cancels for a **single-line** value but not for a multi-line one (the line above).
  - Consequence for the port: the `Measurer` must apply the root's alignment per line box, must clamp the shift at zero for lines wider than the given width, and `measure(items, width: oldWidth)` must be a real constrained layout, not `naturalOffsets + shift`.
  - Evidence: `oracle/fixtures/runtime/probes.json` (`alignPinBehaviour`, `alignDeltas`) and 15 scenario traces prefixed `center-`, `right-`, `align-grow-`, `align-shrink-`, `align-shrink-survivors-`, `align-multiline-`, `align-fixedwidth-shrink-`, `align-fixedwidth-grow-`.

## Q-005 What is the underlying opacity of an exiting element?
- Files: dom.ts:90 (`style.opacity = snapshot`), animate.ts:29 (`opacity: 0, offset: 1`).
- Conclusion: the fade runs from the snapshot opacity to 0. Parity: INTERRUPT-003.

## Q-006 What happens to `scale` when a persisting item is interrupted?
- Files: animate.ts:56-66: only translate is read back; the new animation starts at scale(0.95 if new else 1). A mid-enter item (scale ~0.97) snaps to 1 on the next persist.
- Conclusion: reproduce the snap (do not "improve"). Parity: INTERRUPT-002.

## Q-007 Does `onAnimationComplete` fire for the initial render?
- Files: index.ts:298-303 — initial render returns before the container transition; no callbacks. Confidence: certain. Parity: CALLBACK-001/002.

## Q-008 `findNearestAnchor` for arrivals: index in `segments` vs DOM order?
- Files: index.ts:373-378 uses `segments.findIndex(id)` and `segmentIds`; DOM order equals segment order after reconcile (SR node excluded). Conclusion: same. Parity: FLIP-003.

## Q-009 Group exit runs: are previously-exiting children counted in `oldChildren`?
- Files: index.ts:212 (`oldChildren` = all non-SR children including exiting), index.ts:256 (`replacedRuns(oldChildren, new Set(exiting))`). A still-exiting element between two new exits breaks the run (it is not a member).
- Conclusion: port as-is. Parity: REPLACE-001.

## Q-010 Height of the container/line box in Flutter?
- Upstream: line box from CSS line-height (normal) of the root font. Flutter: `TextPainter.preferredLineHeight` of the style. Kinematic parity is normalised per platform; see DEVIATIONS candidate.

## Q-011 Is `Intl.Segmenter` locale-sensitive for word breaks in practice?
- ICU word break rules are locale-independent except for dictionary languages. Fixtures generated with "en"; the Dart port ignores locale for word breaks. Parity: SEG-002. Open for A2 to confirm with de/ja fixtures.
- **A2 finding (runtime).** Confirmed for word **and** grapheme granularity: over a 36-item corpus × `{en, de, ja, th}`, `anyWordDiffers = false` and `anyGraphemeDiffers = false` — byte-identical output in all 144 combinations (`oracle/fixtures/runtime/segmenter-locales.json`, Chrome 152 / ICU). The corpus deliberately includes the dictionary-breaking scripts, and they segment identically under every locale, including `"en"`: `"日本語のテキスト"` → `["日本語","の","テキスト"]`, `"東京都に行く"` → `["東京","都","に","行く"]`, `"ภาษาไทยง่าย"` → `["ภาษา","ไทย","ง่าย"]`, `"สวัสดีครับ"` → `["สวัสดี","ครับ"]`. ICU selects the dictionary by **script**, not by locale, so `locale` is inert for segmentation.
- The one genuinely locale-sensitive path is `decimalSeparator(locale)`: `{en: ".", de: ",", ja: ".", th: "."}`. That is the only place the port must branch on locale for text handling (`toLocaleString` for numeric `update()` values being the other).
- Resolution: the Dart port may ignore `locale` for word/grapheme breaks entirely — this is now pinned, not assumed. Dictionary breaking for CJK/Thai remains a real deviation candidate (a Dart UAX#29 port has no dictionary), but it is a *presence* problem, not a *locale* problem, and it is the same in every locale, so a single fixture set covers it. Parity: SEG-002.

## Q-012 WAAPI: what does a later `element.animate` on the same property do to an earlier one?
- Spec: composite "replace" — the later animation's effect wins while both are active; the earlier keeps running underneath (and its `onfinish` still fires). Upstream always cancels first except: exit (after detach's cancel), group exit (explicit cancel).
- `detachFromFlow` cancels `child.getAnimations()` — per spec this returns only the element's own animations, NOT the nested mover's. So a mover mid-enter (opacity 0.3, translateY 5px) that starts exiting keeps its enter animations running under the new exit animations: the new mover transform (`offset: 1`, slide down) replaces the enter transform immediately (jump from 5px to 0 then slide); the new opacity (`offset: 1` → 0) starts from the *underlying* value (1), not 0.3 — a jump to opaque. RUNTIME EXPERIMENT REQUIRED (A2). Parity: INTERRUPT-003 (number variant).
- **A2 finding (runtime), part 1 — scope.** Confirmed: `element.getAnimations()` returns **only the element's own** animations. Synthetic probe: outer own = 1, `outer.getAnimations({subtree: true})` = 2, inner own = 1 (`probes.json → getAnimationsScope`). On a real slot mid-enter: `slot.getAnimations()` = 1, `{subtree: true}` = 3, `mover.getAnimations()` = 2 (`probes.json → moverMidEnterThenExit.slotScope`). So `detachFromFlow` and `cancelAnimations` never touch a mover, and a mover's enter animations keep running underneath its exit animations. Confirmed.
- **A2 finding (runtime), part 2 — the composite is LIVE, and there is NO jump.** The predicted "jump to opaque / jump from 5px to 0" is **wrong**. `animateNumberExit` passes a *single* keyframe at `offset: 1`; the implicit 0 % keyframe is the **underlying value**, and WAAPI re-resolves the underlying value **every frame** — so the still-running enter animation keeps contributing while the exit animation interpolates away from it. Two traces:
  - `"999"` → `"1,000"`, interrupt with `"42"` at t = 100 (25 %, after the 100 ms enter fade has finished). Mover `ty` at t = 100 is `-3.7557` and stays continuous: `-3.7557 → -2.031 (t=104) → +2.771 (116) → +8.2767 (132) → +13.1232 (150) → +20.1611 (200) → +24`. No discontinuity at the interrupt. Opacity is 1 throughout the exit (the enter fade had already settled at 1). `probes.json → moverMidEnterThenExit`.
  - `"999"` → `"1,000"`, interrupt with `"42"` at t = **40** (10 %, while the 100 ms enter fade is still running). Mover opacity at t = 40 is `0.4`, and after the interrupt it **rises before it falls**: `0.4 (t=40) → 0.4302 (44) → 0.5102 (56) → 0.592 (72) → 0.65 (90) → 0.5 (130) → 0`. The peak is ~0.65 at t ≈ 90. It is exactly `enterFade(t) · (1 − exitProgress(t))`, with `enterFade` a live 0→1 linear ramp over 100 ms and `exitProgress` linear over `duration·0.45 = 180 ms`. The `,` symbol's `ty` is likewise non-monotonic: `+12.4859 (40) → 12.2088 (44) → 12.1749 (56) → 13.4713 (72) → 15.6929 (90) → 19.8231 (130) → 24`. `probes.json → moverMidFadeThenExit`.
  - Scope: this bites **only** on numeric movers. Text exit, group exit and group enter all `cancel()` the element's own animations first, so their underlying value is the static inline style (opacity = the detach snapshot, transform = `none`), and Q-005's "snapshot → 0" reading holds there.
- **Consequence for the port — ARCHITECTURE.md D-8 is wrong as written.** "the *last started* active track wins for that property" is right for *two-keyframe* tracks (`[{from},{to}]`), which are self-contained. It is wrong for the *single-keyframe `offset: 1`* tracks (text exit transform/opacity, number exit slot transform, mover transform/opacity, group exit) and the *single-keyframe `offset: 0`* tracks (number persist/enter). Those must be modelled as `lerp(underlying(t), keyframe, progress(t))` where `underlying(t)` is the value produced by evaluating **all lower-priority tracks at t**, recomputed per frame — not a value snapshotted when the track started. Parity: INTERRUPT-003 (number variant); see A2_CHALLENGE_REPORT.md item 1.

---

# A2 additions (runtime oracle, Chrome 152 headless)

New questions raised by the runtime traces. Every one is a behaviour that is
*observable* and *not* pinned by any upstream unit test — `__tests__` covers
segmentation, diffing, numbers, easing and container-size maths, but never the
WAAPI composite, the callback timeline, or alignment-aware measurement.
Evidence lives in `oracle/fixtures/runtime/`.

## Q-013 Do single-keyframe animations composite over a LIVE underlying value?
- Yes. See the Q-012 finding above. `{prop: X, offset: 1}` is
  `lerp(underlying(t), X, progress(t))` with `underlying(t)` recomputed each frame
  from every lower-priority track; `{prop: X, offset: 0}` is
  `lerp(X, underlying(t), progress(t))`.
- Only reachable where the library does *not* cancel first, i.e. numeric movers
  (`detachFromFlow` cancels the slot only). Everywhere else the underlying value is
  a static inline style and the distinction is invisible.
- Resolution: model tracks as an ordered per-(element, property) stack evaluated
  bottom-up per frame. Do not snapshot a start value for single-keyframe tracks.
  Confidence: certain (numeric traces, 4 decimal places). Amends ARCHITECTURE.md D-8.

## Q-014 Does `scale: false` disable every scale?
- **No — it only affects `animateExit`.** `oracle/fixtures/runtime/noscale-*.json`,
  `scale: false`:
  - plain text exit: `{transform: "translate(0px, 0px)", offset: 1}` — scale omitted ✔
  - text **enter**: `[{transform: "translate(0px, 0px) scale(0.95)"}, {transform: "none"}]` — **still 0.95**
  - text persist: `scale(1)` — unchanged
  - group exit: `{transform: "scale(0.8)", offset: 1}` — **still 0.8**
  - group enter: `{transform: "scale(0.8)", offset: 0}` — **still 0.8**
- Source agrees: `scale` is threaded only into `animateExit` (index.ts:270).
- Resolution: port as-is. A "fix" here is a parity break. Confidence: certain.

## Q-015 When exactly does `onAnimationComplete` fire, and does a storm postpone it?
- It fires on the **width** axis's `onfinish`, at `updateTime + duration` in virtual
  time, to the millisecond: nothing at t = 399.9, fired at t = 400
  (`probes.json → completeTiming`, three value pairs, identical).
- A storm of updates whose container **target does not move** takes the resume branch
  (`|previous.to - to| < 0.5`): the new animation is created with
  `currentTime = previous.elapsed` and `startedAt = now() - seek`, so it finishes
  `duration` after the **first** update, not the last. `storm-digits-1-5`
  (`"1"→"2"→"3"→"4"→"5"` at 16 ms): `seek0` = 0, 16, 32, 48 and
  `complete@400` — *not* 448.
- A storm whose target **does** move restarts the axis: `storm-grow` (`"hi"→"hello"
  →"hello world"→"hello world foo"`) gives `seek0` = 0, 0, 0 on width and
  `complete@432` = last update (32) + 400.
- Note the asymmetry: **height** takes the resume branch in the growth storm
  (`seek0` = 16, 32) while **width** restarts, because only the width target moved.
  Each axis snapshots and resumes independently.
- Every interrupt fires `onAnimationStart` and `onAnimationCancel` at the *same*
  virtual time, in that order. Resolution: exactly one of complete/cancel per morph,
  the cancel synchronous with the interrupting update. Confidence: certain.

## Q-016 What does `oldWidth` read during an in-flight container transition?
- The **interpolated** animated width, not the natural one. `"hi"` → `"hello world
  foo bar"`: `getComputedStyle(root).width` = 24.0938 (t=0), 196.781 (100),
  224.281 (200), 228.469 (300), 228.828 (400) (`probes.json → midFlightComputedWidth`).
- So an interrupt at 50 % of `"hi"` → `"hello world"` reads `oldWidth = 130.078`
  (not 132.484, not 24.0938) and the next container animation starts there
  (`container-oldwidth-mid-flight-*`). At t = 0 it reads the animation's *from*
  value, so the very first frame is already under WAAPI control.
- Resolution: the port's container axis must expose its current interpolated value as
  the next morph's `oldWidth`/`oldHeight`. Confidence: certain.

## Q-017 What happens when `oldWidth == 0`?
- Reachable only via an empty value: after `"hello"` → `""`, `holdContainerSize` pins
  60.2344 × 24 for `duration`, fires `complete@400`, then restores — and the root
  collapses to computed width **0** (the ZWSP stand-in has zero advance) while height
  stays 24 (the stand-in keeps the line box).
- The next morph (`""` → `"hello"`) therefore hits the zero branch: `restoreSize()`,
  `onCancel?.()`, return. Observed callbacks `start@500, cancel@500`; **no** root
  width/height animation is created at all, and the root jumps 0 → 60.2344 in one
  frame. Item animations run normally (enter `scale(0.95)`, opacity 0→1 over
  `duration·0.5` with `duration·0.25` delay). `probes.json → zeroOldWidth` (case b).
- If the same update lands **during** the hold instead, `oldWidth` is the pinned
  60.2344, so the container *does* animate — a degenerate `60.2344 → 60.2344` pair,
  and `complete` fires at `interrupt + duration` (`interrupt-25-hello-hello`:
  `start@0, start@100, cancel@100, complete@500`).
- Resolution: reproduce both branches, including the "no container animation, cancel
  immediately, items still animate" case. Confidence: certain.

## Q-018 Is `update("")` on a fresh instance a morph?
- **No — it is a no-op.** The constructor sets `this.data = ""`, so the first
  `update("")` returns at the `formatted === this.data` guard: no segments, no SR
  node, `previousSegments` stays `[]`, `isInitialRender` stays `true`. The *next*
  update is therefore still an initial render (no animations, no callbacks).
  `probes.json → zeroOldWidth.emptyFirstUpdate` / `.thenHello` — 0 animations,
  0 callbacks, root 0 × 0 then 60.2344 × 24 with no motion.
- So "first morph out of an empty value" is unreachable through the public API; you
  must go `"x"` → `""` → `"x"`. Confidence: certain. Affects the `fromempty-hello`
  fixture, which is an initial render, not a morph.

## Q-019 Does `carry()` ever engage with the default easing?
- **Practically never.** `carry` needs `k = min(8, normalisedVelocity) − slopeAt(base, 0) > 0`,
  and the default `cubic-bezier(0.19, 1, 0.22, 1)` has `slopeAt(0) = 1/0.19 = 5.263`.
  Across every interrupt and storm scenario at the default ease, **not one** container
  axis got a carried `linear(...)` curve — all kept `cubic-bezier(0.19, 1, 0.22, 1)`.
- It does engage under a gentler base. `carry-easein@10%` gives
  `linear(0, 0.0367, 0.065, 0.0867, 0.103, ...)`; `carry-linear@10%` gives
  `linear(0, 0.1057, 0.1416, 0.1495, 0.1496, ...)`; the spring growth storm's third
  update gives a curve distinct from the spring's own. 10 of 18 `carry-*` traces
  contain a carried curve; the rest legitimately compute `k <= 0` (a direction
  reversal makes `normalisedVelocity` negative).
- Sample count is `min(120, max(32, round(duration / 8)))` — 50 points at 400 ms,
  91 at the spring's 725 ms — and values are rounded to 4 dp with the last forced
  to exactly 1.
- Resolution: `carry` must still be ported exactly (a user can pass any ease), but it
  is dead code at the default and must not be exercised as a default-path regression.
  The `carry-easein-*` / `carry-linear-*` / `carry-spring-*` traces are the only
  coverage that exists for it. Confidence: certain.

## Q-020 Are separator IDs position-keyed, and what does that cost on a reorder?
- Yes: `space-<utf16CharOffset>` / `newline-<offset>` into the **new** value. A
  reorder that preserves the words but moves the separators replaces every separator.
- `"one two three"` → `"three two one"`: all three words are **reused** (and travel a
  long way) while **both spaces exit and two fresh spaces arrive** (offsets 3, 7 →
  5, 9). `"Copy Address"` → `"Address Copied"`: `Address` reused, the space at
  offset 4 exits and a fresh one at offset 7 arrives.
- Counter-example worth keeping: `"😀 hi"` → `"hi 😀"` reuses *everything* including
  the space, because the space sits at UTF-16 offset 2 in both (the emoji is a
  surrogate pair). Zero exits, zero arrivals.
- Resolution: port the offset-keyed IDs verbatim; do not "stabilise" separators.
  Confidence: certain.

## Q-021 Numeric digits are matched by LCS over characters, not by column, when the integer digit counts differ.
- `"$999"` → `"$1,000"`: only `$` is reused. All three `9`s exit; `1 , 0 0 0` are all
  fresh — because `matchDigits(..., reversed)` runs an LCS over the digit
  *characters* `"999"` vs `"1000"`, whose LCS is empty. Same for `"9"`→`"10"`,
  `"99"`→`"100"`, `"9.99"`→`"10.00"` (only `.` survives).
- Contrast `"1234"` → `"1,234"` (equal integer digit counts → column pairing): all
  four digits reused, only `,` is fresh. And `"1 of 10"` → `"2 of 10"`: `of`, both
  spaces and `1 0` reused, only the leading `1` → `2` swaps.
- `"-999.50"` → `"-1,000.00"` reuses `-`, `.` and exactly one `0`.
- Full reuse digest for 21 value pairs is in A2_CHALLENGE_REPORT.md item 8.
- Resolution: already implied by BEHAVIOR_MAP §3, but the *visual* consequence (a
  rolling-odometer value change replaces the whole number rather than rolling it) is
  surprising enough that it needs a named parity test. Confidence: certain.

## Q-022 A reused-ID collision can put two elements with the same `torph-id` in the DOM.
- After `"hello"` → `""`, `previousSegments` is `[{id: "empty"}]`, so the next
  `"hello"` takes the `oldWords.length <= 1` fast path into `segmentText("hello")`,
  which mints a *fresh* allocator and returns the same IDs `h, e, l, l-3, o`. The
  old elements with those IDs are still in the DOM marked `torph-exiting`, and
  `reconcileChildren` refuses to reuse exiting elements — so it creates new spans
  with duplicate IDs.
- Harmless in practice: `measure()` skips exiting children, so no `Measures` key is
  ever ambiguous, and the old ones are removed by their own fade `onfinish`. But a
  port keying items by ID in a single map **will** collide.
- Reproduced and measured: `interrupt-1-hello-hello` (interrupt at 1 % = t = 4). From
  t = 4 to t = 96 the root holds **ten** children with five duplicated IDs —
  `h, e, l, l-3, o` each appear twice, once `exiting: true` at the fading opacity
  (0.96 at t=4, 0.84 at 16, 0.68 at 32 …) and once `exiting: false` at opacity 0
  (its enter fade is still inside its 100 ms delay). The exiting copies vanish at
  t = 100 when their 100 ms fade finishes.
- The `empty` ZWSP stand-in is *not* animated out: it is removed synchronously
  (`child.getAttribute(ATTR_ID) === EMPTY_ID → child.remove()`), so it is present at
  t = 0 and gone at t = 4.
- Resolution: the port's item collection must tolerate duplicate IDs, or key exiting
  items in a separate list. Confidence: certain.

## Q-023 A zero-delta persisting item still gets a full-duration animation.
- `animateEnterOrPersist` is called for every non-arriving child unconditionally, so a
  persisting item with `dx = dy = 0` gets
  `[{transform: "translate(0px, 0px) scale(1)"}, {transform: "none"}]` over the full
  duration — a 400 ms animation that renders nothing. Visible in nearly every trace
  (`hello`, `space-5` in `interrupt-25-hello-world-...`).
- It matters because it **cancels** whatever was running on that element, which is
  exactly the Q-006 scale snap. `animateNumberPersist` is the one place that *does*
  bail early (`if (startX === 0 && startY === 0) return`) — after it has already
  cancelled the slot's animations.
- Resolution: reproduce the cancel-then-no-op ordering; do not skip the animation.
  Confidence: certain.

## Q-024 `Number(getComputedStyle(el).opacity) || 1` coerces opacity 0 to 1.
- Files: dom.ts:83 (`detachFromFlow`), animate.ts:47 (`cancelAnimations`). In JS
  `0 || 1` is `1`, so an element currently at opacity **0** is snapshotted as **1**.
- Reachable and visible. A new text item's enter fade has `delay = duration * 0.25`,
  so for the first quarter of a morph it sits at opacity 0. Interrupt there and:
  - `detachFromFlow` writes `style.opacity = "1"` and the exit fade runs **1 → 0**
    over `duration * 0.25` — the invisible item **flashes fully opaque**.
    Measured (`interrupt-25-hello-world-hello-there-hello-friend`, item `there`):
    opacity `0 (t=80) → 0 (96) → 1 (100, interrupt) → 0.96 (104)`; `sx` in the same
    frames `0.9883 → 0.9915 → 1 → 0.9974`.
  - `cancelAnimations` returns `prev.opacity = 1`, so `animateEnterOrPersist` computes
    `startOpacity = 1` and the `if (startOpacity < 1)` guard **skips the fade**,
    snapping the item to opaque instead of continuing its fade-in.
- Resolution: reproduce exactly. Dart's `double.tryParse(s) ?? 1` gives `0` and is
  wrong; use `(o == 0 || o.isNaN) ? 1 : o`. Confidence: certain (measured).
  Parity: INTERRUPT-003, and amends Q-005: the exiting fade runs from the *coerced*
  snapshot, so its start opacity is never 0 — it is either the true value in (0, 1]
  or 1.

## Q-025 How does an RTL root lay out and morph? (A0, runtime)
- Experiment: `oracle/runtime` page option `direction: "rtl"`; 18 traces `rtl-*`, `rtl-center-*`, `rtl-end-*` (Menlo 20px).
- Findings: inline-block items flow from the **right** edge in **logical order** (first segment rightmost; `مرحبا` → `م` at x=48, `ا` at x=0); `text-align: start` = right, `end` = left, `center` unchanged; an overflowing line keeps its right edge on the container's right edge and extends into negative x (`بالعالم` at −93.96 under a 60 px pinned width); exits are pinned by integer `offsetLeft` exactly as in LTR; every transform/opacity/callback is identical to the LTR model. A 1/64 px `translate(0.0156px)` noise appears on persisting items (LayoutUnit, DEV-002).
- Resolution: `Measurer` rule in RENDERER_CONTRACT.md §4 (RTL placement `x_i = left + lineWidth − Σ_{j≤i} w_j`, overflow `left = containerWidth − lineWidth`) — verified by test/parity/runtime_trace_parity_test.dart (18/18). Parity: RTL-001. Confidence: certain.
