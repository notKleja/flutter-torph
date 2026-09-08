// Browser RTL/bidi oracle over the UNMODIFIED pinned bundle: plain-browser UBA layout,
// upstream Torph order/geometry at rest and through morphs, per oracle/fixtures/rtl/corpus.json.
import http from "node:http";
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "../..");
const DIST = path.join(REPO, "upstream/torph/packages/torph/dist");
const CORPUS_FILE = path.join(REPO, "oracle/fixtures/rtl/corpus.json");
const OUT_DIR = path.join(REPO, "oracle/fixtures/rtl/browser");
const REPORT_DIR = path.join(REPO, "reports/rtl");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const FONT_FAMILY = 'Arial, "Helvetica Neue", system-ui, sans-serif';
const FONT_SIZE = 20;

const FRACS_MORPH = [0, 0.1, 0.25, 0.37, 0.5, 0.73, 0.9, 1.0];
const FRACS_INTERRUPT = [0.01, 0.05, 0.1, 0.25, 0.37, 0.5, 0.73, 0.9, 0.99];

const argv = process.argv.slice(2);
const useFallback = argv.includes("--fallback");
const onlyArg = argv.find((a) => a.startsWith("--only="));
const only = onlyArg ? onlyArg.slice("--only=".length) : null;

function hash6(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, "0").slice(0, 6);
}
function slugify(label) {
  const base =
    label
      .replace(/[^a-zA-Z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .toLowerCase()
      .slice(0, 60) || "case";
  return `${base}-${hash6(label)}`;
}

function fallbackCorpus() {
  const cases = [];
  const push = (category, text, direction, locale, extra) =>
    cases.push({
      id: slugify(`${category}-${text}`),
      category,
      text,
      direction,
      locale,
      ...extra,
    });

  push("currency-ar", "السعر 1234 ريال", "rtl", "ar");
  push("currency-ar", "السعر $1,234.56 اليوم", "rtl", "ar");
  push("quantity-ar", "لدي 123 تفاحة", "rtl", "ar");
  push("time-ar", "الوقت 10:45 مساءً", "rtl", "ar");
  push("currency-fa", "قیمت 1234 تومان", "rtl", "fa");
  push("currency-fa", "قیمت 1,234.50 دلار", "rtl", "fa");
  push("native-digits-ar", "السعر ١٢٣٤ ريال", "rtl", "ar");
  push("native-digits-fa", "قیمت ۱۲۳۴ تومان", "rtl", "fa");
  push("currency-he", "מחיר 1234 ₪", "rtl", "he");
  push("currency-he", "מחיר $1,234.56 היום", "rtl", "he");

  push("mixed", "مرحبا ABC 123 DEF", "rtl", "ar");
  push("mixed", "ABC مرحبا 123 عالم DEF", "rtl", "ar");
  push("mixed", "123 مرحبا", "rtl", "ar");
  push("mixed", "مرحبا 123", "rtl", "ar");
  push("mixed-punct", "مرحبا (123)", "rtl", "ar");
  push("mixed-sign", "مرحبا -123", "rtl", "ar");
  push("mixed-sign", "مرحبا +123", "rtl", "ar");
  push("mixed-currency", "مرحبا $123", "rtl", "ar");
  push("mixed-percent", "مرحبا 123%", "rtl", "ar");
  push("mixed-fraction", "مرحبا 1/2", "rtl", "ar");
  push("mixed-time", "مرحبا 12:34", "rtl", "ar");

  const morphs = [
    ["مرحبا 123", "مرحبا 124"],
    ["مرحبا 129", "مرحبا 130"],
    ["مرحبا 999", "مرحبا 1,000"],
    ["مرحبا 1,999", "مرحبا 2,000"],
    ["مرحبا 9.99", "مرحبا 10.00"],
    ["مرحبا -99", "مرحبا -100"],
    ["مرحبا $999", "مرحبا $1,000"],
  ];
  for (const [a, b] of morphs) {
    cases.push({
      id: slugify(`morph-${a}-${b}`),
      category: "morph",
      text: a,
      direction: "rtl",
      locale: "ar",
      morph: { to: b },
    });
  }

  cases.push({
    id: slugify("interrupt-999-1000-999"),
    category: "interrupt",
    text: "مرحبا 999",
    direction: "rtl",
    locale: "ar",
    interrupt: { to: "مرحبا 1,000", then: "مرحبا 999" },
  });
  cases.push({
    id: slugify("interrupt-word-rtl"),
    category: "interrupt",
    text: "مرحبا 123",
    direction: "rtl",
    locale: "ar",
    interrupt: { to: "مرحبا 124", then: "مرحبا 125" },
  });
  cases.push({
    id: slugify("storm-digits-rtl"),
    category: "storm",
    text: "مرحبا 1",
    direction: "rtl",
    locale: "ar",
    storm: ["مرحبا 2", "مرحبا 3", "مرحبا 4", "مرحبا 5"],
  });

  return cases;
}

async function loadCorpus() {
  if (useFallback) {
    console.log("--fallback passed: using built-in corpus");
    return fallbackCorpus();
  }
  const maxWaitMs = 20 * 60 * 1000;
  const pollMs = 15000;
  const start = Date.now();
  process.stdout.write("waiting for oracle/fixtures/rtl/corpus.json ");
  while (!fs.existsSync(CORPUS_FILE) && Date.now() - start < maxWaitMs) {
    process.stdout.write(".");
    await new Promise((r) => setTimeout(r, pollMs));
  }
  console.log("");
  if (fs.existsSync(CORPUS_FILE)) {
    const raw = JSON.parse(await fsp.readFile(CORPUS_FILE, "utf8"));
    const cases = Array.isArray(raw) ? raw : raw.cases;
    if (Array.isArray(cases) && cases.length > 0) {
      console.log(`loaded corpus.json: ${cases.length} cases`);
      return cases;
    }
  }
  console.log("corpus.json not found/empty after waiting; using fallback list");
  return fallbackCorpus();
}

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

function pageCfg(direction, locale) {
  return {
    direction,
    fontFamily: FONT_FAMILY,
    fontSize: FONT_SIZE,
    textAlign: "start",
    locale,
  };
}

async function mountFor(page, direction, locale) {
  await page.evaluate(
    (cfg) => window.__H.mount(cfg),
    { page: pageCfg(direction, locale), options: { locale } },
  );
}

async function snapshot(page, locale) {
  return page.evaluate((loc) => window.__H.torphSnapshot(loc), locale ?? null);
}

async function runMorph(page, kase, direction, locale) {
  await mountFor(page, direction, locale);
  await page.evaluate((v) => window.__H.applyUpdate(v), kase.text);
  const upd = await page.evaluate((v) => window.__H.applyUpdate(v), kase.morph.to);
  const duration = Math.max(0, ...upd.animsCreated.map((a) => a.duration));
  const samples = [];
  for (const f of FRACS_MORPH) {
    const t = Math.round(duration * f * 1000) / 1000;
    await page.evaluate((tt) => window.__H.seek(tt), t);
    const snap = await snapshot(page, locale);
    samples.push({ frac: f, t, snap });
  }
  return { to: kase.morph.to, resolvedDuration: duration, samples };
}

async function runInterrupt(page, kase, direction, locale) {
  const runs = [];
  for (const f of FRACS_INTERRUPT) {
    await mountFor(page, direction, locale);
    await page.evaluate((v) => window.__H.applyUpdate(v), kase.text);
    const upd1 = await page.evaluate(
      (v) => window.__H.applyUpdate(v),
      kase.interrupt.to,
    );
    const d1 = Math.max(0, ...upd1.animsCreated.map((a) => a.duration));
    const t1 = Math.round(d1 * f * 1000) / 1000;
    await page.evaluate((tt) => window.__H.seek(tt), t1);
    const before = await snapshot(page, locale);
    const upd2 = await page.evaluate(
      (v) => window.__H.applyUpdate(v),
      kase.interrupt.then,
    );
    const d2 = Math.max(0, ...upd2.animsCreated.map((a) => a.duration));
    const after = await snapshot(page, locale);
    const endT = t1 + Math.max(d1, d2) + 50;
    await page.evaluate((tt) => window.__H.seek(tt), endT);
    const end = await snapshot(page, locale);
    runs.push({ frac: f, t1, resolvedDurationAtInterrupt: d1, resolvedDurationAfter: d2, before, after, end });
  }
  return { to: kase.interrupt.to, then: kase.interrupt.then, runs };
}

async function runStorm(page, kase, direction, locale) {
  await mountFor(page, direction, locale);
  await page.evaluate((v) => window.__H.applyUpdate(v), kase.text);
  const samples = [];
  let t = 0;
  for (const val of kase.storm) {
    await page.evaluate((tt) => window.__H.seek(tt), t);
    await page.evaluate((v) => window.__H.applyUpdate(v), val);
    const snap = await snapshot(page, locale);
    samples.push({ t, value: val, snap });
    t += 16;
  }
  await page.evaluate((tt) => window.__H.seek(tt), t + 500);
  samples.push({ t: t + 500, value: "(settled)", snap: await snapshot(page, locale) });
  return { values: kase.storm, samples };
}

async function processCase(page, kase) {
  const direction = kase.direction || "rtl";
  const locale = kase.locale || undefined;
  const text = kase.text;
  const id = kase.id || slugify(`${kase.category || "case"}-${text}`);

  const plain = await page.evaluate(
    (t, o) => window.__H.measurePlainGraphemes(t, o),
    text,
    { direction, fontFamily: FONT_FAMILY, fontSize: FONT_SIZE, locale, textAlign: "start" },
  );

  await mountFor(page, direction, locale);
  await page.evaluate((v) => window.__H.applyUpdate(v), text);
  const torphAtRest = await snapshot(page, locale);

  const record = {
    id,
    category: kase.category ?? null,
    text,
    direction,
    locale: locale ?? null,
    font: FONT_FAMILY,
    fontSize: FONT_SIZE,
    plain,
    torphAtRest,
  };

  if (kase.morph && kase.morph.to) {
    record.morph = await runMorph(page, kase, direction, locale);
  }
  if (kase.interrupt && kase.interrupt.to && kase.interrupt.then) {
    record.interrupt = await runInterrupt(page, kase, direction, locale);
  }
  if (Array.isArray(kase.storm) && kase.storm.length) {
    record.storm = await runStorm(page, kase, direction, locale);
  }

  await fsp.writeFile(
    path.join(OUT_DIR, `${id}.json`),
    JSON.stringify(record, null, 1) + "\n",
  );
  return {
    id,
    file: `${id}.json`,
    category: record.category,
    text,
    plainStr: plain.plainVisualOrderString,
    torphStr: torphAtRest.torphVisualGlyphOrderString,
    match: plain.plainVisualOrderString === torphAtRest.torphVisualGlyphOrderString,
  };
}

function mdEscape(s) {
  return String(s).replace(/\|/g, "\\|").replace(/\n/g, "\\n");
}

async function buildReport(summaries) {
  const lines = [];
  lines.push("# Browser RTL Oracle Report");
  lines.push("");
  lines.push(
    "Comparison of plain-browser UBA (Unicode Bidi Algorithm) grapheme layout " +
      "against upstream Torph's own `[torph-item]` DOM ordering, at rest, for " +
      "every corpus case. `plainVisualOrder` and `torphVisualGlyphOrder` both " +
      "read left → right in viewport (screen) coordinates.",
  );
  lines.push("");
  lines.push(`Font: \`${FONT_FAMILY}\`, size ${FONT_SIZE}px.`);
  lines.push("");
  lines.push("| id | text | plainVisualOrder | torphVisualGlyphOrder | result | note |");
  lines.push("|---|---|---|---|---|---|");
  let mismatches = 0;
  let nbspOnly = 0;
  for (const s of summaries) {
    let note = "";
    if (!s.match) {
      mismatches++;
      const collapsed = (str) => str.replace(/ /g, " ");
      if (collapsed(s.plainStr) === collapsed(s.torphStr)) {
        nbspOnly++;
        note = "same visual order; differs only by NBSP vs plain space";
      } else {
        note = "reordered relative to plain UBA rendering";
      }
    }
    lines.push(
      `| ${mdEscape(s.id)} | ${mdEscape(s.text)} | ${mdEscape(s.plainStr)} | ${mdEscape(s.torphStr)} | ${
        s.match ? "MATCH" : "MISMATCH"
      } | ${note} |`,
    );
  }
  lines.push("");
  lines.push(
    `**${summaries.length} cases, ${summaries.length - mismatches} MATCH, ${mismatches} MISMATCH ` +
      `(of which ${nbspOnly} differ only by NBSP-vs-space, ${mismatches - nbspOnly} are true reorderings).**`,
  );
  lines.push("");

  lines.push("## Findings");
  lines.push("");

  const digitCase = summaries.find((s) => /[0-9]{2,}/.test(s.text) || /[٠-٩۰-۹]{2,}/.test(s.text));
  const currencyCase = summaries.find((s) => /[$₪%]/.test(s.text));
  const latinCase = summaries.find((s) => /[A-Za-z]{2,}/.test(s.text) && /[؀-ۿ֐-׿]/.test(s.text));
  const rtlWordCase = summaries.find((s) => /[؀-ۿ֐-׿]{2,}/.test(s.text));
  const whitespaceCase = summaries.find((s) => s.text.includes(" ") && /[؀-ۿ֐-׿]/.test(s.text));

  async function loadRec(s) {
    if (!s) return null;
    return JSON.parse(await fsp.readFile(path.join(OUT_DIR, s.file), "utf8"));
  }

  const digitRec = await loadRec(digitCase);
  const currencyRec = await loadRec(currencyCase);
  const latinRec = await loadRec(latinCase);
  const rtlWordRec = await loadRec(rtlWordCase);
  const wsRec = await loadRec(whitespaceCase);

  function itemLine(rec) {
    return rec.torphAtRest.items
      .map((it) => `\`${it.text}\`@x=${it.rect.x}${it.kind ? ` (kind=${it.kind})` : ""}${it.slot ? " slot" : ""}`)
      .join(", ");
  }
  function plainLine(rec) {
    return rec.plain.graphemes.map((g) => `\`${g.grapheme}\`@x=${g.rect.x}`).join(", ");
  }

  lines.push("### (i) Multi-digit numbers");
  if (digitRec) {
    lines.push(`Case \`${digitRec.id}\` (\`${digitRec.text}\`):`);
    lines.push("");
    lines.push(`- Plain browser graphemes, left→right by x: ${plainLine(digitRec)}`);
    lines.push(`- Torph \`[torph-item]\` DOM children, by x: ${itemLine(digitRec)}`);
    lines.push(
      `- Torph visual glyph order string: \`${digitRec.torphAtRest.torphVisualGlyphOrderString}\`; plain: \`${digitRec.plain.plainVisualOrderString}\`.`,
    );
  } else {
    lines.push("(no digit case found in this corpus run)");
  }
  lines.push("");

  lines.push("### (ii) Currency / sign / percent / separators");
  if (currencyRec) {
    lines.push(`Case \`${currencyRec.id}\` (\`${currencyRec.text}\`):`);
    lines.push("");
    lines.push(`- Plain browser graphemes, by x: ${plainLine(currencyRec)}`);
    lines.push(`- Torph items, by x: ${itemLine(currencyRec)}`);
  } else {
    lines.push("(no currency/percent case found in this corpus run)");
  }
  lines.push("");

  lines.push("### (iii) Latin words embedded in RTL text");
  if (latinRec) {
    lines.push(`Case \`${latinRec.id}\` (\`${latinRec.text}\`):`);
    lines.push("");
    lines.push(`- Plain browser graphemes, by x: ${plainLine(latinRec)}`);
    lines.push(`- Torph items, by x: ${itemLine(latinRec)}`);
  } else {
    lines.push("(no mixed Latin/RTL case found in this corpus run)");
  }
  lines.push("");

  lines.push("### (iv) RTL words");
  if (rtlWordRec) {
    lines.push(`Case \`${rtlWordRec.id}\` (\`${rtlWordRec.text}\`):`);
    lines.push("");
    lines.push(`- Plain browser graphemes, by x: ${plainLine(rtlWordRec)}`);
    lines.push(`- Torph items, by x: ${itemLine(rtlWordRec)}`);
  }
  lines.push("");

  lines.push("### (v) Whitespace items inside an RTL root");
  if (wsRec) {
    const spaceItems = wsRec.torphAtRest.items.filter((it) => it.text === " " || it.text === " ");
    lines.push(`Case \`${wsRec.id}\` (\`${wsRec.text}\`):`);
    lines.push("");
    lines.push(
      `- Space item(s): ${
        spaceItems.length
          ? spaceItems.map((it) => `index=${it.index} x=${it.rect.x} w=${it.rect.w}`).join("; ")
          : "(none found as standalone DOM items — spaces may be embedded in numeric/word slots)"
      }`,
    );
  }
  lines.push("");

  lines.push("### inline-block items and bidi (measured, not assumed)");
  if (digitRec) {
    const it = digitRec.torphAtRest.items.find((i) => i.slot) || digitRec.torphAtRest.items[0];
    lines.push(
      `- Sample item \`${it.id}\` (text \`${it.text}\`): computed \`display=${it.computed.display}\`, ` +
        `\`direction=${it.computed.direction}\`, \`unicode-bidi=${it.computed.unicodeBidi}\`` +
        (it.mover
          ? `; its mover: \`display=${it.mover.computed.display}\`, \`direction=${it.mover.computed.direction}\`, \`unicode-bidi=${it.mover.computed.unicodeBidi}\`.`
          : "."),
    );
    lines.push(
      `- Root computed: \`direction=${digitRec.torphAtRest.root.direction}\`, \`unicode-bidi=${digitRec.torphAtRest.root.unicodeBidi}\`, \`display=${digitRec.torphAtRest.root.display}\`.`,
    );
  }
  lines.push("");

  lines.push("### Mover/slot ordering during morphs, interrupts, storms");
  lines.push("");
  let morphRec = null;
  let interruptRec = null;
  let stormRec = null;
  for (const s of summaries) {
    if (!morphRec || !interruptRec || !stormRec) {
      const rec = await loadRec(s);
      if (!morphRec && rec.morph) morphRec = rec;
      if (!interruptRec && rec.interrupt) interruptRec = rec;
      if (!stormRec && rec.storm) stormRec = rec;
    }
  }

  if (morphRec) {
    lines.push(`**Morph** — case \`${morphRec.id}\`: \`${morphRec.text}\` → \`${morphRec.morph.to}\` (resolved duration ${morphRec.morph.resolvedDuration}ms).`);
    lines.push("");
    for (const s of morphRec.morph.samples) {
      const order = s.snap.torphVisualOrder.map((it) => `${it.text}@${it.x}`).join(", ");
      lines.push(`- t=${s.t} (frac ${s.frac}): visual order by x: ${order}`);
    }
  } else {
    lines.push("(no morph case found)");
  }
  lines.push("");

  if (interruptRec) {
    lines.push(
      `**Interrupt** — case \`${interruptRec.id}\`: \`${interruptRec.text}\` → \`${interruptRec.interrupt.to}\` → \`${interruptRec.interrupt.then}\`.`,
    );
    lines.push("");
    const midRun = interruptRec.interrupt.runs[Math.floor(interruptRec.interrupt.runs.length / 2)];
    lines.push(`- Interrupted at frac ${midRun.frac} (t1=${midRun.t1}):`);
    lines.push(`  - before: ${midRun.before.torphVisualOrder.map((it) => `${it.text}@${it.x}`).join(", ")}`);
    lines.push(`  - right after interrupt: ${midRun.after.torphVisualOrder.map((it) => `${it.text}@${it.x}`).join(", ")}`);
    lines.push(`  - at end: ${midRun.end.torphVisualOrder.map((it) => `${it.text}@${it.x}`).join(", ")}`);
  } else {
    lines.push("(no interrupt case found)");
  }
  lines.push("");

  if (stormRec) {
    lines.push(`**Storm** — case \`${stormRec.id}\`: \`${stormRec.text}\` → ${stormRec.storm.values.map((v) => `\`${v}\``).join(" → ")}.`);
    lines.push("");
    for (const s of stormRec.storm.samples) {
      const order = s.snap.torphVisualOrder.map((it) => `${it.text}@${it.x}`).join(", ");
      lines.push(`- t=${s.t} value=\`${s.value}\`: visual order by x: ${order}`);
    }
  } else {
    lines.push("(no storm case found)");
  }
  lines.push("");

  await fsp.mkdir(REPORT_DIR, { recursive: true });
  await fsp.writeFile(path.join(REPORT_DIR, "browser_oracle_report.md"), lines.join("\n") + "\n");
}

const reportOnly = argv.includes("--report-only");

async function main() {
  await fsp.mkdir(OUT_DIR, { recursive: true });

  if (reportOnly) {
    const idx = JSON.parse(
      await fsp.readFile(path.join(OUT_DIR, "index.json"), "utf8"),
    );
    const summaries = [];
    for (const c of idx.cases) {
      const rec = JSON.parse(
        await fsp.readFile(path.join(OUT_DIR, c.file), "utf8"),
      );
      summaries.push({
        id: rec.id,
        file: c.file,
        category: rec.category,
        text: rec.text,
        plainStr: rec.plain.plainVisualOrderString,
        torphStr: rec.torphAtRest.torphVisualGlyphOrderString,
        match: rec.plain.plainVisualOrderString === rec.torphAtRest.torphVisualGlyphOrderString,
      });
    }
    await buildReport(summaries);
    console.log(`report-only: rebuilt report from ${summaries.length} existing case files`);
    return;
  }

  const corpus = (await loadCorpus()).filter((c) => !only || (c.id || "").includes(only));

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
  const pageErrors = [];
  page.on("pageerror", (e) => pageErrors.push(String(e)));
  page.on("console", (m) => {
    if (m.type() === "error") pageErrors.push(m.text());
  });
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "load" });
  await page.waitForFunction(() => window.__ready === true && window.Torph);

  const summaries = [];
  let n = 0;
  for (const kase of corpus) {
    const s = await processCase(page, kase);
    summaries.push(s);
    n++;
    process.stdout.write(`\r[${n}/${corpus.length}] ${s.id}                              `);
  }
  console.log(`\n${n} cases captured`);

  await fsp.writeFile(
    path.join(OUT_DIR, "index.json"),
    JSON.stringify(
      {
        upstream: "torph 0.1.3 @ d79a5aa63226acf97d49c3e34fafb2e85c07b026",
        generatedBy: "oracle/runtime/trace-rtl.mjs",
        font: FONT_FAMILY,
        fontSize: FONT_SIZE,
        cases: summaries.map((s) => ({ id: s.id, file: s.file, category: s.category, text: s.text })),
      },
      null,
      1,
    ) + "\n",
  );

  await buildReport(summaries);

  if (pageErrors.length) {
    console.error("PAGE ERRORS:", pageErrors.slice(0, 10));
  }
  await browser.close();
  server.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
