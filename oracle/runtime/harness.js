/**
 * Deterministic runtime harness for the pinned Torph 0.1.3 dist bundle.
 *
 * Determinism strategy (no wall clock anywhere the library can observe):
 *  1. `performance.now` is replaced by a virtual clock (`H.now`). utils/animate.ts's
 *     `now()` is the only wall-clock reader in the library, and it goes through
 *     `performance.now` at call time, so the override is total.
 *  2. `setTimeout`/`clearTimeout` are virtualised. `holdContainerSize` is the only user.
 *  3. `Element.prototype.animate` is patched: every animation the library creates is
 *     paused and seeked to 0 immediately (synchronously, before any frame can elapse)
 *     and registered with the virtual time it was created at. Sampling seeks each
 *     animation to `t - createdAt + seek0`.
 *     `seek0` preserves `animateAxis`'s resume seek (`anim.currentTime = previous.elapsed`).
 *  4. A paused animation NEVER reaches play state "finished" (the spec's play-state
 *     algorithm returns "paused" first), so `onfinish` would never fire. When virtual
 *     time reaches delay+duration we call `anim.finish()` explicitly, which queues the
 *     finish notification. Callers must then flush one animation frame.
 *
 * Everything here is measurement only; the library is used unmodified.
 */

const H = {
  now: 0,
  anims: [],
  timers: [],
  nextTimerId: 1,
  callbacks: [],
  morph: null,
  root: null,
  wrap: null,
  probes: {},
};
window.__H = H;

// ---------------------------------------------------------------- virtual clock
const realNow = performance.now.bind(performance);
H.realNow = realNow;
performance.now = () => H.now;

const realSetTimeout = window.setTimeout.bind(window);
const realClearTimeout = window.clearTimeout.bind(window);
H.realSetTimeout = realSetTimeout;
window.setTimeout = function (fn, delay, ...args) {
  const id = H.nextTimerId++;
  H.timers.push({
    id,
    at: H.now + (Number(delay) || 0),
    fn: () => fn.apply(null, args),
  });
  return id;
};
window.clearTimeout = function (id) {
  H.timers = H.timers.filter((t) => t.id !== id);
};

// ------------------------------------------------------- animation interception
function keyframeProps(keyframes) {
  const props = new Set();
  const list = Array.isArray(keyframes) ? keyframes : [keyframes];
  for (const kf of list) {
    if (!kf) continue;
    for (const k of Object.keys(kf)) {
      if (k === "offset" || k === "easing" || k === "composite") continue;
      props.add(k);
    }
  }
  return [...props];
}

const realAnimate = Element.prototype.animate;
Element.prototype.animate = function (keyframes, options) {
  const anim = realAnimate.call(this, keyframes, options);
  const opt = options && typeof options === "object" ? options : {};
  const duration = Number(opt.duration) || 0;
  const delay = Number(opt.delay) || 0;
  try {
    anim.pause();
    anim.currentTime = 0;
  } catch (e) {
    /* pending; harmless */
  }
  H.anims.push({
    i: H.anims.length,
    anim,
    el: this,
    createdAt: H.now,
    delay,
    duration,
    endTime: delay + duration,
    easing: opt.easing === undefined ? "linear" : String(opt.easing),
    fill: opt.fill || "none",
    props: keyframeProps(keyframes),
    keyframes: JSON.parse(JSON.stringify(keyframes)),
    seek0: null,
    finishCalled: false,
  });
  return anim;
};

// ------------------------------------------------------------------ measurement
const ATTR = {
  ID: "torph-id",
  KIND: "torph-kind",
  SLOT: "torph-slot",
  EXITING: "torph-exiting",
  SR: "torph-sr",
  ITEM: "torph-item",
};

const r4 = (n) =>
  typeof n === "number" && Number.isFinite(n) ? Math.round(n * 10000) / 10000 : n;

function parseMatrix(str) {
  if (!str || str === "none") {
    return { tx: 0, ty: 0, sx: 1, sy: 1, none: true };
  }
  let m = /^matrix\(([^)]+)\)$/.exec(str);
  if (m) {
    const v = m[1].split(",").map(Number);
    // a b c d e f -> scaleX = hypot(a,b) for a pure scale+translate this is |a|
    return {
      tx: v[4] || 0,
      ty: v[5] || 0,
      sx: Math.hypot(v[0], v[1]),
      sy: Math.hypot(v[2], v[3]),
      none: false,
    };
  }
  m = /^matrix3d\(([^)]+)\)$/.exec(str);
  if (m) {
    const v = m[1].split(",").map(Number);
    return {
      tx: v[12] || 0,
      ty: v[13] || 0,
      sx: Math.hypot(v[0], v[1], v[2]),
      sy: Math.hypot(v[4], v[5], v[6]),
      none: false,
    };
  }
  return { tx: 0, ty: 0, sx: 1, sy: 1, none: false, raw: str };
}

function describeEl(el) {
  if (!el) return null;
  if (el === H.root) return "root";
  if (el.hasAttribute && el.hasAttribute(ATTR.ID)) {
    return (
      (el.tagName === "BR" ? "br:" : "") +
      el.getAttribute(ATTR.ID) +
      (el.hasAttribute(ATTR.EXITING) ? "[exiting]" : "")
    );
  }
  // nested mover span
  const p = el.parentElement;
  if (p && p.hasAttribute && p.hasAttribute(ATTR.ID)) {
    return (
      "mover(" +
      p.getAttribute(ATTR.ID) +
      (p.hasAttribute(ATTR.EXITING) ? "[exiting]" : "") +
      ")"
    );
  }
  return el.tagName.toLowerCase();
}

function sampleItems() {
  const root = H.root;
  const rootRect = root.getBoundingClientRect();
  const out = [];
  const children = Array.from(root.children);
  children.forEach((child, index) => {
    if (child.hasAttribute(ATTR.SR)) return;
    const cs = getComputedStyle(child);
    const rect = child.getBoundingClientRect();
    const tr = parseMatrix(cs.transform);
    const item = {
      index,
      id: child.getAttribute(ATTR.ID),
      tag: child.tagName.toLowerCase(),
      text: child.textContent,
      kind: child.getAttribute(ATTR.KIND) || null,
      exiting: child.hasAttribute(ATTR.EXITING),
      slot: child.hasAttribute(ATTR.SLOT),
      rect: {
        x: r4(rect.left - rootRect.left),
        y: r4(rect.top - rootRect.top),
        w: r4(rect.width),
        h: r4(rect.height),
      },
      transform: cs.transform,
      translate: { tx: r4(tr.tx), ty: r4(tr.ty) },
      scale: { sx: r4(tr.sx), sy: r4(tr.sy) },
      opacity: r4(Number(cs.opacity)),
      transformOrigin: cs.transformOrigin,
      position: cs.position,
      inlineLeft: child.style.left || null,
      inlineTop: child.style.top || null,
      inlineOpacity: child.style.opacity || null,
    };
    if (child.hasAttribute(ATTR.SLOT)) {
      const mover = child.firstElementChild || child;
      const ms = getComputedStyle(mover);
      const mtr = parseMatrix(ms.transform);
      const mrect = mover.getBoundingClientRect();
      item.mover = {
        transform: ms.transform,
        translate: { tx: r4(mtr.tx), ty: r4(mtr.ty) },
        scale: { sx: r4(mtr.sx), sy: r4(mtr.sy) },
        opacity: r4(Number(ms.opacity)),
        rect: {
          x: r4(mrect.left - rootRect.left),
          y: r4(mrect.top - rootRect.top),
          w: r4(mrect.width),
          h: r4(mrect.height),
        },
      };
    }
    out.push(item);
  });
  return out;
}

function sampleRoot() {
  const root = H.root;
  const cs = getComputedStyle(root);
  const rect = root.getBoundingClientRect();
  return {
    computedWidth: r4(parseFloat(cs.width)),
    computedHeight: r4(parseFloat(cs.height)),
    rectWidth: r4(rect.width),
    rectHeight: r4(rect.height),
    offsetHeight: r4(root.offsetHeight),
    offsetWidth: r4(root.offsetWidth),
    inlineWidth: root.style.width || "",
    inlineHeight: root.style.height || "",
    transformNone: cs.transform === "none",
    display: cs.display,
    textAlign: cs.textAlign,
    transitionProperty: root.style.transitionProperty || "",
  };
}

function srText() {
  const sr = H.root.querySelector("[" + ATTR.SR + "]");
  return sr ? sr.textContent : null;
}

function animStates() {
  return H.anims.map((rec) => ({
    i: rec.i,
    el: describeEl(rec.el),
    props: rec.props,
    playState: rec.anim.playState,
    currentTime:
      rec.anim.currentTime === null ? null : r4(Number(rec.anim.currentTime)),
  }));
}

function animsCreatedSince(mark) {
  return H.anims.slice(mark).map((rec) => ({
    i: rec.i,
    el: describeEl(rec.el),
    props: rec.props,
    duration: rec.duration,
    delay: rec.delay,
    easing: rec.easing,
    fill: rec.fill,
    keyframes: rec.keyframes,
    createdAt: rec.createdAt,
    seek0: rec.seek0,
    playState: rec.anim.playState,
  }));
}

// ------------------------------------------------------------------ time driving
function fireTimers(t) {
  // Timers may schedule further timers; loop until quiet.
  for (let guard = 0; guard < 100; guard++) {
    const due = H.timers.filter((x) => x.at <= t).sort((a, b) => a.at - b.at);
    if (due.length === 0) return;
    H.timers = H.timers.filter((x) => x.at > t);
    for (const d of due) d.fn();
  }
}

function seekAll(t) {
  H.now = t;
  for (const rec of H.anims) {
    const a = rec.anim;
    // A cancelled animation reads back currentTime === null / playState "idle".
    // Writing currentTime would RESURRECT its effect, so never touch it.
    if (a.playState === "idle" || a.currentTime === null) continue;
    const local = t - rec.createdAt + (rec.seek0 || 0);
    try {
      if (local >= rec.endTime) {
        if (!rec.finishCalled) {
          rec.finishCalled = true;
          a.finish();
        } else {
          a.currentTime = rec.endTime;
        }
      } else {
        a.currentTime = Math.max(0, local);
      }
    } catch (e) {
      /* finish() on a zero/infinite effect; ignore */
    }
  }
  fireTimers(t);
}

const frame = () =>
  new Promise((res) => requestAnimationFrame(() => requestAnimationFrame(res)));

// --------------------------------------------------------------------- lifecycle
H.reset = function () {
  // destroy() is what decrements the library's <style> refcount. Removing the
  // element by hand instead leaves the module's `styleEl` pointing at a detached
  // node, so `addStyles()` short-circuits and every later mount runs with NO
  // torph CSS at all (root not inline-block, computed width "auto").
  if (H.morph) {
    try {
      H.morph.destroy();
    } catch (e) {
      /* ignore */
    }
  }
  H.now = 0;
  H.anims = [];
  H.timers = [];
  H.callbacks = [];
  H.morph = null;
  if (H.wrap) H.wrap.remove();
  H.wrap = null;
  H.root = null;
};

H.mount = async function (config) {
  H.reset();
  const page = config.page || {};
  const wrap = document.createElement("div");
  wrap.id = "wrap";
  wrap.style.position = "relative";
  wrap.style.width = (page.wrapWidth || 900) + "px";
  wrap.style.height = "400px";
  wrap.style.fontFamily = page.fontFamily || "Menlo";
  wrap.style.fontSize = (page.fontSize || 20) + "px";
  wrap.style.lineHeight = page.lineHeight || "normal";
  wrap.style.textAlign = page.textAlign || "left";
  if (page.direction) wrap.dir = page.direction;
  document.body.appendChild(wrap);

  const holder = document.createElement("div");
  holder.style.position = "absolute";
  holder.style.left = "100px";
  holder.style.top = "100px";
  holder.style.width = (page.wrapWidth || 900) + "px";
  holder.style.textAlign = page.textAlign || "left";
  if (page.direction) holder.dir = page.direction;
  wrap.appendChild(holder);

  const root = document.createElement("span");
  holder.appendChild(root);
  H.wrap = wrap;
  H.root = root;

  const opts = Object.assign({}, config.options, {
    element: root,
    onAnimationStart: () => H.callbacks.push({ name: "start", at: H.now }),
    onAnimationComplete: () => H.callbacks.push({ name: "complete", at: H.now }),
    onAnimationCancel: () => H.callbacks.push({ name: "cancel", at: H.now }),
  });
  H.morph = new window.Torph.TextMorph(opts);
  await frame();
  return true;
};

/** Applies an update at the current virtual time and returns what it created. */
H.applyUpdate = async function (value, cursorIndex) {
  const mark = H.anims.length;
  const cbMark = H.callbacks.length;
  if (cursorIndex === null || cursorIndex === undefined) {
    H.morph.update(value);
  } else {
    H.morph.update(value, cursorIndex);
  }
  // Capture the seek the library applied (animateAxis resume) before we drive time.
  for (let i = mark; i < H.anims.length; i++) {
    const rec = H.anims[i];
    const ct = rec.anim.currentTime;
    rec.seek0 = ct === null ? 0 : Number(ct);
  }
  await frame();
  return {
    animsCreated: animsCreatedSince(mark),
    callbacks: H.callbacks.slice(cbMark),
  };
};

H.seek = async function (t) {
  seekAll(t);
  await frame();
  // onfinish removals can land in the flushed frame; re-seek is not needed because
  // removal does not change any other animation's phase.
  return true;
};

H.sample = function (t) {
  const cbMark = H.callbacks.length;
  return {
    t: r4(t),
    now: r4(H.now),
    root: sampleRoot(),
    items: sampleItems(),
    sr: srText(),
    anims: animStates(),
    callbacksSoFar: H.callbacks.slice(),
    _cbMark: cbMark,
  };
};

H.callbackLog = function () {
  return H.callbacks.slice();
};

/** Longest animation duration seen so far — reveals the resolved spring duration. */
H.maxDuration = function () {
  return H.anims.reduce((m, a) => Math.max(m, a.duration), 0);
};

H.axisDurations = function () {
  return H.anims
    .filter((a) => a.props.includes("width") || a.props.includes("height"))
    .map((a) => ({ props: a.props, duration: a.duration, easing: a.easing }));
};

/** Pure measurement: item x/y (relative to the root) with the root width pinned. */
H.measureAt = function (width) {
  const root = H.root;
  const prev = root.style.width;
  if (width !== null && width !== undefined) root.style.width = width + "px";
  void root.offsetWidth;
  const rootRect = root.getBoundingClientRect();
  const out = [];
  for (const child of root.children) {
    if (child.hasAttribute(ATTR.SR)) continue;
    if (child.tagName === "BR") {
      out.push({ id: child.getAttribute(ATTR.ID), br: true });
      continue;
    }
    const rect = child.getBoundingClientRect();
    out.push({
      id: child.getAttribute(ATTR.ID),
      x: r4(rect.left - rootRect.left),
      y: r4(rect.top - rootRect.top),
    });
  }
  const cs = getComputedStyle(root);
  const res = {
    pinnedWidth: width ?? null,
    rootComputedWidth: r4(parseFloat(cs.width)),
    items: out,
  };
  root.style.width = prev;
  void root.offsetWidth;
  return res;
};

// ============================================================ RTL/bidi oracle
// Additive helpers for the browser RTL oracle (oracle/runtime/trace-rtl.mjs).

H.measurePlainGraphemes = function (text, opts) {
  const direction = opts.direction || "ltr";
  const fontFamily = opts.fontFamily || "Menlo";
  const fontSize = opts.fontSize || 20;
  const locale = opts.locale || undefined;
  const textAlign = opts.textAlign || "start";

  const container = document.createElement("div");
  container.style.position = "absolute";
  container.style.left = "100px";
  container.style.top = "100px";
  container.style.fontFamily = fontFamily;
  container.style.fontSize = fontSize + "px";
  container.style.textAlign = textAlign;
  container.dir = direction;
  document.body.appendChild(container);

  const span = document.createElement("span");
  span.textContent = text;
  container.appendChild(span);

  const cs = getComputedStyle(span);
  const spanRect = span.getBoundingClientRect();
  const textNode = span.firstChild;

  let graphemes = [];
  if (textNode && text.length > 0) {
    const seg = new Intl.Segmenter(locale, { granularity: "grapheme" });
    graphemes = [...seg.segment(text)].map((g, logicalIndex) => {
      const range = document.createRange();
      range.setStart(textNode, g.index);
      range.setEnd(textNode, g.index + g.segment.length);
      const r = range.getBoundingClientRect();
      return {
        logicalIndex,
        grapheme: g.segment,
        rect: {
          x: r4(r.left - spanRect.left),
          y: r4(r.top - spanRect.top),
          w: r4(r.width),
          h: r4(r.height),
        },
      };
    });
  }

  const visualOrder = graphemes
    .slice()
    .sort((a, b) => a.rect.x - b.rect.x || a.rect.y - b.rect.y);

  const out = {
    text,
    computed: {
      direction: cs.direction,
      unicodeBidi: cs.unicodeBidi,
      textAlign: cs.textAlign,
    },
    spanRect: { w: r4(spanRect.width), h: r4(spanRect.height) },
    graphemes,
    plainVisualOrder: visualOrder.map((g) => ({
      logicalIndex: g.logicalIndex,
      grapheme: g.grapheme,
      x: g.rect.x,
    })),
    plainVisualOrderString: visualOrder.map((g) => g.grapheme).join(""),
  };
  container.remove();
  return out;
};

function itemGraphemes(el, locale, rootRect) {
  let textEl = el;
  if (el.hasAttribute(ATTR.SLOT)) {
    textEl = el.firstElementChild || el;
  }
  let textNode = null;
  for (const n of textEl.childNodes) {
    if (n.nodeType === Node.TEXT_NODE) {
      textNode = n;
      break;
    }
  }
  if (!textNode || !textNode.textContent) return [];
  const text = textNode.textContent;
  const seg = new Intl.Segmenter(locale, { granularity: "grapheme" });
  return [...seg.segment(text)].map((g, logicalIndex) => {
    const range = document.createRange();
    range.setStart(textNode, g.index);
    range.setEnd(textNode, g.index + g.segment.length);
    const r = range.getBoundingClientRect();
    return {
      logicalIndex,
      grapheme: g.segment,
      rect: {
        x: r4(r.left - rootRect.left),
        y: r4(r.top - rootRect.top),
        w: r4(r.width),
        h: r4(r.height),
      },
    };
  });
}

H.torphSnapshot = function (locale) {
  const root = H.root;
  const rootRect = root.getBoundingClientRect();
  const rootCs = getComputedStyle(root);
  const children = Array.from(root.children).filter(
    (c) => !c.hasAttribute(ATTR.SR),
  );

  const items = children.map((child, index) => {
    const cs = getComputedStyle(child);
    const rect = child.getBoundingClientRect();
    const tr = parseMatrix(cs.transform);
    const isSlot = child.hasAttribute(ATTR.SLOT);
    const mover = isSlot ? child.firstElementChild || child : null;
    let moverOut = null;
    if (mover) {
      const mcs = getComputedStyle(mover);
      const mrect = mover.getBoundingClientRect();
      const mtr = parseMatrix(mcs.transform);
      moverOut = {
        rect: {
          x: r4(mrect.left - rootRect.left),
          y: r4(mrect.top - rootRect.top),
          w: r4(mrect.width),
          h: r4(mrect.height),
        },
        transform: mcs.transform,
        translate: { tx: r4(mtr.tx), ty: r4(mtr.ty) },
        scale: { sx: r4(mtr.sx), sy: r4(mtr.sy) },
        opacity: r4(Number(mcs.opacity)),
        computed: {
          direction: mcs.direction,
          unicodeBidi: mcs.unicodeBidi,
          display: mcs.display,
        },
      };
    }
    return {
      index,
      id: child.getAttribute(ATTR.ID),
      tag: child.tagName.toLowerCase(),
      text: child.textContent,
      kind: child.getAttribute(ATTR.KIND) || null,
      slot: isSlot,
      exiting: child.hasAttribute(ATTR.EXITING),
      rect: {
        x: r4(rect.left - rootRect.left),
        y: r4(rect.top - rootRect.top),
        w: r4(rect.width),
        h: r4(rect.height),
      },
      transform: cs.transform,
      translate: { tx: r4(tr.tx), ty: r4(tr.ty) },
      scale: { sx: r4(tr.sx), sy: r4(tr.sy) },
      opacity: r4(Number(cs.opacity)),
      computed: {
        direction: cs.direction,
        unicodeBidi: cs.unicodeBidi,
        display: cs.display,
      },
      mover: moverOut,
      graphemes: itemGraphemes(child, locale, rootRect),
    };
  });

  const torphVisualOrder = items
    .slice()
    .sort((a, b) => a.rect.x - b.rect.x || a.rect.y - b.rect.y);

  const torphVisualGlyphOrderString = torphVisualOrder
    .map((it) => {
      const gs = it.graphemes
        .slice()
        .sort((a, b) => a.rect.x - b.rect.x || a.rect.y - b.rect.y);
      return gs.map((g) => g.grapheme).join("");
    })
    .join("");

  return {
    root: {
      direction: rootCs.direction,
      unicodeBidi: rootCs.unicodeBidi,
      display: rootCs.display,
      textAlign: rootCs.textAlign,
      rect: { w: r4(rootRect.width), h: r4(rootRect.height) },
    },
    domOrder: items.map((it) => ({
      index: it.index,
      id: it.id,
      text: it.text,
      kind: it.kind,
      slot: it.slot,
      exiting: it.exiting,
    })),
    items,
    torphVisualOrder: torphVisualOrder.map((it) => ({
      index: it.index,
      id: it.id,
      text: it.text,
      kind: it.kind,
      x: it.rect.x,
    })),
    torphVisualGlyphOrderString,
  };
};
