/**
 * Runtime motion oracle: drives the pinned Torph dist bundle in headless Chrome
 * against a virtual clock and writes machine-readable traces.
 *
 *   npm run trace              # all scenarios + probes
 *   npm run trace -- --probes-only
 *   npm run trace -- --only=<slug substring>
 */
import http from "node:http";
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";
import { buildScenarios, sampleTimes } from "./scenarios.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "../..");
const DIST = path.join(REPO, "upstream/torph/packages/torph/dist");
const OUT = path.join(REPO, "oracle/fixtures/runtime");
const CHROME =
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const argv = process.argv.slice(2);
const probesOnly = argv.includes("--probes-only");
const onlyArg = argv.find((a) => a.startsWith("--only="));
const only = onlyArg ? onlyArg.slice("--only=".length) : null;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
};

function startServer() {
  const server = http.createServer((req, res) => {
    let rel = decodeURIComponent(req.url.split("?")[0]);
    if (rel === "/") rel = "/index.html";
    const file = rel.startsWith("/dist/")
      ? path.join(DIST, rel.slice("/dist/".length))
      : path.join(HERE, rel);
    if (rel === "/favicon.ico") {
      res.writeHead(204).end();
      return;
    }
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404).end("not found");
      return;
    }
    res.writeHead(200, {
      "Content-Type": MIME[path.extname(file)] || "application/octet-stream",
      "Cache-Control": "no-store",
    });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () =>
      resolve({ server, port: server.address().port }),
    );
  });
}

const r3 = (n) => Math.round(n * 1000) / 1000;

async function resolveDuration(page, options) {
  // The resolved duration is observable on the container's width animation timing,
  // which is the only place a spring's computed duration surfaces.
  await page.evaluate(
    (cfg) => window.__H.mount(cfg),
    { page: { fontFamily: "Menlo", fontSize: 20 }, options },
  );
  await page.evaluate((v) => window.__H.applyUpdate(v), "a");
  await page.evaluate((v) => window.__H.applyUpdate(v), "ab");
  const info = await page.evaluate(() => ({
    axes: window.__H.axisDurations(),
    max: window.__H.maxDuration(),
  }));
  return { duration: info.axes[0]?.duration ?? info.max ?? 400, info };
}

async function runScenario(page, sc, duration) {
  const updateTimes = sc.steps.map((s) =>
    typeof s.at === "object" ? r3(duration * s.at.frac) : s.at,
  );
  const samples = sampleTimes([0, ...updateTimes], duration);
  const timeline = [...new Set([...updateTimes, ...samples])].sort(
    (a, b) => a - b,
  );

  await page.evaluate((cfg) => window.__H.mount(cfg), {
    page: sc.page,
    options: sc.options,
  });

  const trace = {
    slug: sc.slug,
    label: sc.label,
    upstream: "torph 0.1.3 @ d79a5aa63226acf97d49c3e34fafb2e85c07b026",
    page: sc.page,
    options: sc.options,
    resolvedDuration: duration,
    initial: sc.initial,
    initialCursorIndex: sc.initialCursorIndex ?? null,
    steps: sc.steps.map((s, i) => ({
      at: updateTimes[i],
      value: s.value,
      cursorIndex: s.cursorIndex ?? null,
    })),
    sampleTimes: samples,
    updates: [],
    samples: [],
    callbacks: [],
  };

  // Initial render at virtual t = 0 (creates no animations, fires no callbacks).
  const init = await page.evaluate(
    (v, c) => window.__H.applyUpdate(v, c),
    sc.initial,
    sc.initialCursorIndex ?? null,
  );
  trace.updates.push({
    at: 0,
    kind: "initial",
    value: sc.initial,
    cursorIndex: sc.initialCursorIndex ?? null,
    animsCreated: init.animsCreated,
    callbacks: init.callbacks,
  });
  trace.initialSample = await page.evaluate((t) => window.__H.sample(t), 0);
  delete trace.initialSample.callbacksSoFar;
  delete trace.initialSample._cbMark;

  for (const t of timeline) {
    await page.evaluate((tt) => window.__H.seek(tt), t);
    for (let i = 0; i < sc.steps.length; i++) {
      if (updateTimes[i] !== t) continue;
      const res = await page.evaluate(
        (v, c) => window.__H.applyUpdate(v, c),
        sc.steps[i].value,
        sc.steps[i].cursorIndex ?? null,
      );
      trace.updates.push({
        at: t,
        kind: "morph",
        value: sc.steps[i].value,
        cursorIndex: sc.steps[i].cursorIndex ?? null,
        animsCreated: res.animsCreated,
        callbacks: res.callbacks,
      });
    }
    if (!samples.includes(t)) continue;
    const s = await page.evaluate((tt) => window.__H.sample(tt), t);
    s.cbCount = s.callbacksSoFar.length;
    delete s.callbacksSoFar;
    delete s._cbMark;
    trace.samples.push(s);
  }

  trace.callbacks = await page.evaluate(() => window.__H.callbackLog());
  return trace;
}

// ---------------------------------------------------------------------- probes
async function runProbes(page) {
  const probes = {};

  // P1: does onfinish fire for a paused-and-seeked animation, and does finish() fire it?
  probes.pausedOnfinish = await page.evaluate(async () => {
    const el = document.createElement("div");
    el.style.cssText = "width:10px;height:10px";
    document.body.appendChild(el);
    const raw = Element.prototype.animate;
    const out = {};
    const frame = () =>
      new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));

    // (a) paused + seeked past the end
    const a = raw.call(el, [{ opacity: 1 }, { opacity: 0 }], {
      duration: 100,
      fill: "both",
    });
    let firedA = false;
    a.onfinish = () => (firedA = true);
    a.pause();
    a.currentTime = 250;
    await frame();
    out.seekPastEnd = {
      fired: firedA,
      playState: a.playState,
      currentTime: Number(a.currentTime),
    };

    // (b) same animation, then finish()
    a.finish();
    await frame();
    out.afterFinishCall = {
      fired: firedA,
      playState: a.playState,
      currentTime: Number(a.currentTime),
    };

    // (c) delayed animation: does finish() honour delay+duration?
    const b = raw.call(el, [{ opacity: 1 }, { opacity: 0 }], {
      duration: 100,
      delay: 100,
      fill: "both",
    });
    b.pause();
    b.currentTime = 150;
    const mid = Number(getComputedStyle(el).opacity);
    b.finish();
    await frame();
    out.delayed = {
      afterFinishCurrentTime: Number(b.currentTime),
      midOpacityAt150: mid,
      playState: b.playState,
    };

    // (d) writing currentTime on a cancelled animation resurrects it?
    const c = raw.call(el, [{ opacity: 1 }, { opacity: 0.2 }], {
      duration: 100,
      fill: "both",
    });
    c.pause();
    c.currentTime = 100;
    const beforeCancel = Number(getComputedStyle(el).opacity);
    c.cancel();
    const afterCancel = Number(getComputedStyle(el).opacity);
    const ctNull = c.currentTime === null;
    c.currentTime = 100;
    const afterWrite = Number(getComputedStyle(el).opacity);
    out.cancelledResurrect = {
      beforeCancel,
      afterCancel,
      currentTimeNullAfterCancel: ctNull,
      opacityAfterWritingCurrentTime: afterWrite,
      playState: c.playState,
    };
    el.remove();
    return out;
  });

  // P2: getAnimations() scope — own vs subtree.
  probes.getAnimationsScope = await page.evaluate(async () => {
    const raw = Element.prototype.animate;
    const outer = document.createElement("div");
    const inner = document.createElement("span");
    outer.appendChild(inner);
    document.body.appendChild(outer);
    const ao = raw.call(outer, [{ opacity: 1 }, { opacity: 0 }], {
      duration: 100,
    });
    const ai = raw.call(inner, [{ opacity: 1 }, { opacity: 0 }], {
      duration: 100,
    });
    ao.pause();
    ai.pause();
    const res = {
      outerOwn: outer.getAnimations().length,
      outerSubtree: outer.getAnimations({ subtree: true }).length,
      innerOwn: inner.getAnimations().length,
      documentIncludesBoth:
        document.getAnimations().includes(ao) &&
        document.getAnimations().includes(ai),
    };
    ao.cancel();
    ai.cancel();
    outer.remove();
    return res;
  });

  // P3: computed width during an in-flight width animation (= next morph's oldWidth).
  probes.midFlightComputedWidth = await page.evaluate(async () => {
    await window.__H.mount({
      page: { fontFamily: "Menlo", fontSize: 20 },
      options: {},
    });
    const out = [];
    await window.__H.applyUpdate("hi");
    out.push({ phase: "initial", ...window.__H.sample(0).root });
    await window.__H.applyUpdate("hello world foo bar");
    for (const t of [0, 100, 200, 300, 400, 440]) {
      await window.__H.seek(t);
      const r = window.__H.sample(t).root;
      out.push({ phase: "t=" + t, ...r });
    }
    return out;
  });

  // P4: oldWidth == 0.
  probes.zeroOldWidth = await page.evaluate(async () => {
    const summarise = (u) => ({
      anims: u.animsCreated.map((a) => ({
        el: a.el,
        props: a.props,
        duration: a.duration,
        delay: a.delay,
        keyframes: a.keyframes,
      })),
      callbacks: u.callbacks,
    });
    const out = {};

    // (a) `update("")` straight after construction: `this.data` already is "",
    // so it is a no-op and the FOLLOWING update is still the initial render.
    await window.__H.mount({
      page: { fontFamily: "Menlo", fontSize: 20 },
      options: {},
    });
    const a0 = await window.__H.applyUpdate("");
    out.emptyFirstUpdate = {
      ...summarise(a0),
      root: window.__H.sample(0).root,
      items: window.__H.sample(0).items.map((i) => ({ id: i.id, text: i.text })),
    };
    const a1 = await window.__H.applyUpdate("hello");
    out.thenHello = {
      ...summarise(a1),
      root: window.__H.sample(0).root,
      note: "no anims + no callbacks => this was the INITIAL render, not a morph",
    };

    // (b) the reachable oldWidth == 0 path: "hello" -> "" (hold, ZWSP is 0 wide)
    //     -> "hello" with oldWidth 0.
    await window.__H.mount({
      page: { fontFamily: "Menlo", fontSize: 20 },
      options: {},
    });
    await window.__H.applyUpdate("hello");
    out.b_initialRoot = window.__H.sample(0).root;
    const b1 = await window.__H.applyUpdate("");
    out.b_toEmpty = summarise(b1);
    out.b_toEmptyRootAt0 = window.__H.sample(0).root;
    await window.__H.seek(400);
    out.b_toEmptyRootAt400 = window.__H.sample(400).root;
    await window.__H.seek(500);
    out.b_toEmptyRootAt500 = window.__H.sample(500).root;
    out.b_callbacksAfterEmpty = window.__H.callbackLog().slice();
    const b2 = await window.__H.applyUpdate("hello");
    out.b_backToHello = summarise(b2);
    out.b_backRootAt500 = window.__H.sample(500).root;
    await window.__H.seek(700);
    out.b_backRootAt700 = window.__H.sample(700).root;
    out.b_callbacks = window.__H.callbackLog();
    return out;
  });

  // P5: exact virtual time onAnimationComplete fires (width-axis finish).
  probes.completeTiming = await page.evaluate(async () => {
    const runs = [];
    for (const [a, b] of [
      ["hi", "hello world"],
      ["999", "1,000"],
      ["hello", ""],
    ]) {
      await window.__H.mount({
        page: { fontFamily: "Menlo", fontSize: 20 },
        options: {},
      });
      await window.__H.applyUpdate(a);
      await window.__H.applyUpdate(b);
      const log = [];
      for (const t of [0, 100, 399, 399.9, 400, 400.1, 401, 500]) {
        await window.__H.seek(t);
        log.push({ t, callbacks: window.__H.callbackLog().slice() });
      }
      runs.push({ from: a, to: b, log });
    }
    return runs;
  });

  // P6: Q-011 — Intl.Segmenter word output across locales.
  probes.segmenterLocales = await page.evaluate(() => {
    const corpus = [
      "hello world",
      "Transaction Safe",
      "$1,000.00",
      "1,234",
      "9.99",
      "-999.50",
      "don't stop",
      "e-mail me",
      "a1b2c3",
      "3.14 pi",
      "1 of 10",
      "co-op's",
      "über straße",
      "Straße 1a",
      "ｆｕｌｌｗｉｄｔｈ",
      "日本語のテキスト",
      "東京都に行く",
      "ภาษาไทยง่าย",
      "สวัสดีครับ",
      "مرحبا بالعالم",
      "café",
      "café",
      "😀 hi",
      "👨‍👩‍👧‍👦 family",
      "a\tb",
      "a  b",
      "10:30 am",
      "1/2/2024",
      "v1.2.3-beta",
      "100%",
      "#42",
      "(999)",
      "42",
      "hello",
      "npm",
      "pnpm",
    ];
    const locales = ["en", "de", "ja", "th"];
    const out = { locales, corpus: {} };
    for (const text of corpus) {
      const row = {};
      for (const loc of locales) {
        const words = [
          ...new Intl.Segmenter(loc, { granularity: "word" }).segment(text),
        ].map((s) => s.segment);
        const graphemes = [
          ...new Intl.Segmenter(loc, { granularity: "grapheme" }).segment(text),
        ].map((s) => s.segment);
        row[loc] = { word: words, grapheme: graphemes };
      }
      row.wordDiffers = locales.some(
        (l) => JSON.stringify(row[l].word) !== JSON.stringify(row.en.word),
      );
      row.graphemeDiffers = locales.some(
        (l) =>
          JSON.stringify(row[l].grapheme) !== JSON.stringify(row.en.grapheme),
      );
      out.corpus[text] = row;
    }
    out.anyWordDiffers = Object.values(out.corpus).some((r) => r.wordDiffers);
    out.anyGraphemeDiffers = Object.values(out.corpus).some(
      (r) => r.graphemeDiffers,
    );
    out.decimalSeparators = locales.reduce((acc, l) => {
      acc[l] = new Intl.NumberFormat(l)
        .formatToParts(1.1)
        .find((p) => p.type === "decimal").value;
      return acc;
    }, {});
    out.icu = { navigatorLanguages: navigator.languages };
    return out;
  });

  // P7: Q-012 — a mover mid-enter that starts exiting; what the exit animations
  // composite over. Recorded as an explicit before/after trace.
  probes.moverMidEnterThenExit = await page.evaluate(async () => {
    await window.__H.mount({
      page: { fontFamily: "Menlo", fontSize: 20 },
      options: {},
    });
    const out = {};
    await window.__H.applyUpdate("999");
    const enter = await window.__H.applyUpdate("1,000");
    out.enterAnims = enter.animsCreated.map((a) => ({
      el: a.el,
      props: a.props,
      duration: a.duration,
      delay: a.delay,
      keyframes: a.keyframes,
    }));
    await window.__H.seek(100); // 25% of 400: movers are mid-enter
    const midEnter = window.__H.sample(100);
    out.midEnterItems = midEnter.items.map((i) => ({
      id: i.id,
      text: i.text,
      kind: i.kind,
      slot: i.slot,
      opacity: i.opacity,
      translate: i.translate,
      mover: i.mover
        ? { opacity: i.mover.opacity, translate: i.mover.translate }
        : null,
    }));
    // Probe the getAnimations() scope on a real slot before the interrupt.
    out.slotScope = (() => {
      const slot = [...window.__H.root.children].find(
        (c) => c.hasAttribute("torph-slot") && c.firstElementChild,
      );
      if (!slot) return null;
      return {
        id: slot.getAttribute("torph-id"),
        own: slot.getAnimations().length,
        subtree: slot.getAnimations({ subtree: true }).length,
        moverOwn: slot.firstElementChild.getAnimations().length,
      };
    })();
    const exit = await window.__H.applyUpdate("42");
    out.exitAnims = exit.animsCreated.map((a) => ({
      el: a.el,
      props: a.props,
      duration: a.duration,
      keyframes: a.keyframes,
    }));
    out.rightAfterExit = window.__H.sample(100).items.map((i) => ({
      id: i.id,
      text: i.text,
      exiting: i.exiting,
      slot: i.slot,
      opacity: i.opacity,
      inlineOpacity: i.inlineOpacity,
      translate: i.translate,
      mover: i.mover
        ? { opacity: i.mover.opacity, translate: i.mover.translate }
        : null,
    }));
    const later = [];
    for (const t of [104, 116, 132, 150, 200, 280, 500]) {
      await window.__H.seek(t);
      later.push({
        t,
        items: window.__H.sample(t).items.map((i) => ({
          id: i.id,
          exiting: i.exiting,
          opacity: i.opacity,
          translate: i.translate,
          mover: i.mover
            ? { opacity: i.mover.opacity, translate: i.mover.translate }
            : null,
        })),
      });
    }
    out.after = later;
    return out;
  });

  // P7b: the same interrupt at t=40, while the mover's ENTER FADE is still running
  // (enter fade = duration * 0.25 = 100 ms), so the exit fade's implicit 0% keyframe
  // has a partially-transparent underlying value to composite over.
  probes.moverMidFadeThenExit = await page.evaluate(async () => {
    const out = {};
    await window.__H.mount({
      page: { fontFamily: "Menlo", fontSize: 20 },
      options: {},
    });
    await window.__H.applyUpdate("999");
    await window.__H.applyUpdate("1,000");
    await window.__H.seek(40);
    const pick = (t) =>
      window.__H
        .sample(t)
        .items.map((i) => ({
          id: i.id,
          text: i.text,
          exiting: i.exiting,
          opacity: i.opacity,
          mover: i.mover
            ? { opacity: i.mover.opacity, translate: i.mover.translate }
            : null,
        }));
    out.at40BeforeInterrupt = pick(40);
    const u = await window.__H.applyUpdate("42");
    out.exitAnims = u.animsCreated.map((a) => ({
      el: a.el,
      props: a.props,
      duration: a.duration,
      keyframes: a.keyframes,
    }));
    out.at40AfterInterrupt = pick(40);
    out.after = [];
    for (const t of [44, 56, 72, 90, 130, 220, 500]) {
      await window.__H.seek(t);
      out.after.push({ t, items: pick(t) });
    }
    return out;
  });

  // P8a: does text-align shift the line at all? Overflowing vs under-full pin.
  probes.alignPinBehaviour = await page.evaluate(async () => {
    const runs = [];
    for (const align of ["left", "center", "right"]) {
      for (const value of ["hello", "aaaa\nbb", "aa\nbbbbbbbb"]) {
        await window.__H.mount({
          page: { fontFamily: "Menlo", fontSize: 20, textAlign: align },
          options: {},
        });
        await window.__H.applyUpdate(value);
        const natural = window.__H.measureAt(null);
        runs.push({
          align,
          value,
          natural,
          pinnedNarrow: window.__H.measureAt(30),
          pinnedWide: window.__H.measureAt(300),
        });
      }
    }
    return runs;
  });

  // P8b: Q-004 — the delta a PERSISTING item is given under each text-align.
  // The pinned first-frame measurement only shifts a line that is narrower than the
  // pin, so the interesting direction is a SHRINK with survivors.
  probes.alignDeltas = await page.evaluate(async () => {
    const runs = [];
    const PAIRS = [
      ["hello world", "hello"], // shrink, 5 survivors
      ["hello world foo", "hello world"], // shrink, whole words survive
      ["hello", "hello world"], // grow, survivors, line overflows the pin
      ["a\nbbbbbbbb", "a\nbb"], // multi-line shrink
      ["a\nbb", "a\nbbbbbbbb"], // multi-line grow
      // Root width is fixed by line 1, so the container never moves, yet the
      // survivors on line 2 still pick up a per-line alignment delta.
      ["aaaaaaaaaaaaaaaaaaaa\nhello world", "aaaaaaaaaaaaaaaaaaaa\nhello"],
      ["aaaaaaaaaaaaaaaaaaaa\nhello", "aaaaaaaaaaaaaaaaaaaa\nhello world"],
    ];
    for (const align of ["left", "center", "right"]) {
      for (const [a, b] of PAIRS) {
        await window.__H.mount({
          page: { fontFamily: "Menlo", fontSize: 20, textAlign: align },
          options: {},
        });
        await window.__H.applyUpdate(a);
        const oldWidth = window.__H.sample(0).root.computedWidth;
        const prevMeasuresNatural = window.__H.measureAt(null);
        const u = await window.__H.applyUpdate(b);
        await window.__H.seek(2000);
        const settled = window.__H.sample(2000);
        runs.push({
          align,
          from: a,
          to: b,
          oldWidth,
          newNaturalWidth: settled.root.computedWidth,
          prevMeasuresNatural,
          // what measure() would have returned with the root pinned to oldWidth,
          // i.e. `firstFrameMeasures`, recomputed on the settled new DOM
          firstFramePin: window.__H.measureAt(oldWidth),
          currentMeasuresNatural: window.__H.measureAt(null),
          itemKeyframes: u.animsCreated
            .filter((x) => x.el !== "root" && x.props.includes("transform"))
            .map((x) => ({ el: x.el, keyframes: x.keyframes })),
          containerKeyframes: u.animsCreated
            .filter((x) => x.el === "root")
            .map((x) => ({
              props: x.props,
              keyframes: x.keyframes,
              easing: x.easing,
              duration: x.duration,
            })),
        });
      }
    }
    return runs;
  });

  return probes;
}

// ------------------------------------------------------------------------ main
async function main() {
  await fsp.mkdir(OUT, { recursive: true });
  const { server, port } = await startServer();
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: true,
    args: [
      "--font-render-hinting=none",
      "--disable-lcd-text",
      "--force-device-scale-factor=1",
      "--hide-scrollbars",
    ],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 700, deviceScaleFactor: 1 });
  const consoleErrors = [];
  page.on("pageerror", (e) => consoleErrors.push(String(e)));
  page.on("console", (m) => {
    if (m.type() === "error") consoleErrors.push(m.text());
  });
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "load" });
  await page.waitForFunction(() => window.__ready === true && window.Torph);

  const written = [];

  if (!only) {
    process.stdout.write("probes... ");
    const probes = await runProbes(page);
    probes.env = await page.evaluate(() => ({
      userAgent: navigator.userAgent,
      chromeVersion: (navigator.userAgent.match(/Chrome\/([\d.]+)/) || [])[1],
    }));
    await write("probes.json", probes);
    // Q-011 asked for its own file.
    await write("segmenter-locales.json", probes.segmenterLocales);
    console.log("done");
  }

  if (!probesOnly) {
    const scenarios = buildScenarios().filter(
      (s) => !only || s.slug.includes(only),
    );
    const durCache = new Map();
    let n = 0;
    for (const sc of scenarios) {
      const key = JSON.stringify(sc.options);
      if (!durCache.has(key)) {
        durCache.set(key, (await resolveDuration(page, sc.options)).duration);
      }
      const trace = await runScenario(page, sc, durCache.get(key));
      await write(`${sc.slug}.json`, trace);
      n++;
      process.stdout.write(`\r[${n}/${scenarios.length}] ${sc.slug}          `);
    }
    console.log(`\n${n} scenario traces written`);
    await write("index.json", {
      upstream: "torph 0.1.3 @ d79a5aa63226acf97d49c3e34fafb2e85c07b026",
      generatedBy: "oracle/runtime/trace.mjs",
      chrome: await page.evaluate(
        () => (navigator.userAgent.match(/Chrome\/([\d.]+)/) || [])[1],
      ),
      resolvedDurations: Object.fromEntries(durCache),
      scenarios: scenarios.map((s) => ({
        slug: s.slug,
        label: s.label,
        page: s.page,
        options: s.options,
        initial: s.initial,
        steps: s.steps,
      })),
    });
  }

  if (consoleErrors.length) {
    console.error("PAGE ERRORS:", consoleErrors.slice(0, 10));
  }
  await browser.close();
  server.close();

  async function write(name, data) {
    const file = path.join(OUT, name);
    await fsp.writeFile(file, JSON.stringify(data, null, 1) + "\n");
    written.push(name);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
