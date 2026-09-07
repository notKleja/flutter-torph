# Runtime motion oracle

Drives the **pinned** upstream bundle
(`upstream/torph/packages/torph/dist/index.mjs`, Torph 0.1.3 @
`d79a5aa63226acf97d49c3e34fafb2e85c07b026`) in headless Chrome against a *virtual
clock*, and writes one machine-readable trace per scenario to
`oracle/fixtures/runtime/`.

The library is used **unmodified**. Everything here is measurement.

## Regenerating

```sh
cd oracle/runtime
npm install          # puppeteer-core only; no browser download
npm run trace        # probes + all scenarios (~15 min, ~24 MB of JSON)
npm run probe        # probes only (fast, ~20 s)

node trace.mjs --only=<slug substring>   # one scenario or a family
```

Requires Google Chrome at
`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` and Node ≥ 20.
`trace.mjs` serves `index.html`, `harness.js` and `/dist/*` over an ephemeral
loopback HTTP server (a `file://` URL cannot `import` an ES module).

> `--only=` also rewrites `index.json` with just the filtered set. Do a full
> `npm run trace` before relying on `index.json`.

## Determinism

No wall clock is observable by the library. Four mechanisms, all in `harness.js`:

1. **`performance.now` is replaced** by `H.now`, the virtual clock.
   `lib/utils/animate.ts`'s `const now = () => performance.now()` is the library's
   only wall-clock reader and it dereferences at call time, so the override is total.
   This is what makes `axisState().elapsed` and the carry velocity reproducible.
2. **`setTimeout`/`clearTimeout` are virtualised** into `H.timers`, fired from
   `seekAll()`. `holdContainerSize` is the only user.
3. **`Element.prototype.animate` is patched.** Every animation is `pause()`d and
   seeked to 0 *synchronously* on creation — before any frame can elapse — and
   registered with `createdAt = H.now`, its duration, delay, easing and keyframes.
   `sample`/`seek` then set `currentTime = t - createdAt + seek0`.
   `seek0` is read back after each `update()` so that `animateAxis`'s resume seek
   (`anim.currentTime = previous.elapsed`) survives.
4. **`anim.finish()` is called explicitly** once virtual time reaches
   `delay + duration`. A paused animation never reaches play state `finished` (the
   spec's play-state algorithm returns `paused` first), so `onfinish` would never
   fire on its own, and `onfinish` is what removes exiting elements and fires
   `onAnimationComplete`. Verified — see `probes.json → pausedOnfinish`.

Two traps the harness must avoid, both verified in `probes.json`:

- Writing `currentTime` on a **cancelled** animation *resurrects its effect*
  (`pausedOnfinish.cancelledResurrect`: opacity goes `0 → 0.2` again). `seekAll`
  therefore skips anything whose `playState` is `idle` / `currentTime` is `null`.
- `H.reset()` must call `morph.destroy()`. Removing the library's `<style
  data-torph>` element by hand leaves the module's `styleEl` pointing at a detached
  node, so `addStyles()` short-circuits and **every later mount runs with no torph
  CSS at all** — the root is not `inline-block` and `getComputedStyle(root).width`
  reads `auto`. Every sample records `root.display` so this cannot pass silently.

After each seek the harness flushes two `requestAnimationFrame`s so queued finish
notifications (and the element removals they trigger) land before measurement.

## Files

| file | role |
| --- | --- |
| `harness.js` | clock, animation interception, measurement, `window.__H` API. Loaded as a classic script *before* the library module. |
| `index.html` | the page: `harness.js`, then `import * as Torph from "/dist/index.mjs"`. |
| `scenarios.mjs` | scenario definitions and the sample-time grid. |
| `trace.mjs` | HTTP server, puppeteer driver, probes, trace writer. |

## Harness API (`window.__H`)

| call | effect |
| --- | --- |
| `mount({page, options})` | destroys any previous instance, builds `div#wrap > div(abs 100,100) > span`, constructs `TextMorph` with callbacks wired to the callback log |
| `applyUpdate(value, cursorIndex?)` | `morph.update(...)` at the current virtual time; returns `{animsCreated, callbacks}` |
| `seek(t)` | advance the virtual clock to `t`, seek/finish every animation, fire due timers, flush frames |
| `sample(t)` | the JSON record (see below) |
| `measureAt(width)` | pure measurement: item `x`/`y` with the root width pinned. Reproduces `firstFrameMeasures` without involving the library. |
| `maxDuration()` / `axisDurations()` | resolved duration — the only way a spring's computed duration is observable |
| `callbackLog()` | `[{name: start|complete|cancel, at}]` |

## Trace shape

```jsonc
{
  "slug", "label", "upstream", "page", "options",
  "resolvedDuration": 400,          // 725 for spring{200,20}
  "initial", "steps", "sampleTimes",
  "initialSample": { /* a sample taken right after the initial render */ },
  "updates": [{                     // one per update(), including the initial render
    "at", "kind": "initial|morph", "value", "cursorIndex",
    "animsCreated": [{ "el", "props", "duration", "delay", "easing", "fill",
                       "keyframes", "createdAt", "seek0", "playState" }],
    "callbacks": [{ "name", "at" }]
  }],
  "samples": [{
    "t", "now",
    "root": { computedWidth, computedHeight, rectWidth, rectHeight, offsetWidth,
              offsetHeight, inlineWidth, inlineHeight, transformNone, display,
              textAlign, transitionProperty },
    "items": [{ index, id, tag, text, kind, exiting, slot,
                rect: {x, y, w, h},          // relative to the root's bounding rect
                transform, translate: {tx, ty}, scale: {sx, sy}, opacity,
                transformOrigin, position, inlineLeft, inlineTop, inlineOpacity,
                mover: { transform, translate, scale, opacity, rect } }],
    "sr": "<accessible text>",
    "anims": [{ i, el, props, playState, currentTime }],
    "cbCount"
  }],
  "callbacks": [ /* the whole log */ ]
}
```

`el` names are stable and readable: `root`, `<torph-id>`,
`<torph-id>[exiting]`, `mover(<torph-id>)`, `mover(<torph-id>[exiting])`.
Numeric IDs begin with U+0000 (upstream mints `" n<counter>"` with a NUL prefix)
and their counter is **process-global and monotonic**, so it differs between
scenarios and between runs — match numeric items by `text` / `index` / `kind`,
never by ID across files.

`index.json` maps every slug to its label, page config, options and steps. Slugs
carry a 6-hex digest of the label, so labels that differ only in punctuation
(`"999"` vs `"$999"`) or that are entirely non-ASCII (Arabic) still get distinct,
stable filenames.

## Sample grid

For every update instant `A` (the initial render counts as `A = 0`), with the
resolved duration `D`:

- `A + D · {0, 0.01, 0.05, 0.10, 0.25, 0.37, 0.50, 0.73, 0.90, 1.00, 1.10}`
- `A + 16·k` for `k = 1..6` (the first 100 ms)

sorted and de-duplicated across all updates. `A` itself is always sampled, and
that sample is taken **immediately after** the update at `A`.

## Probes

`probes.json` holds the targeted experiments, keyed by question:

| key | question |
| --- | --- |
| `pausedOnfinish` | does `onfinish` fire for a paused, seeked animation? does `finish()`? does writing `currentTime` resurrect a cancelled one? |
| `getAnimationsScope` | `getAnimations()` own vs `{subtree: true}` (Q-012) |
| `midFlightComputedWidth` | what `getComputedStyle(root).width` reads during a container transition (the next morph's `oldWidth`) |
| `zeroOldWidth` | `oldWidth == 0`; and that `update("")` right after construction is a no-op |
| `completeTiming` | the exact virtual time `onAnimationComplete` fires |
| `segmenterLocales` | Q-011, also written standalone as `segmenter-locales.json` |
| `moverMidEnterThenExit` | Q-012 at 25 % (mover mid-slide) |
| `moverMidFadeThenExit` | Q-012 at 10 % (mover mid-*fade*) — the live-underlying composite |
| `alignPinBehaviour` | does `text-align` shift an overflowing line? an under-full one? |
| `alignDeltas` | Q-004: the delta a persisting item is given under each alignment |
