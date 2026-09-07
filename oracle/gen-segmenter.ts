/** Intl.Segmenter boundary corpus, the reference for the pure-Dart UAX#29 port. */
import { writeFileSync, mkdirSync } from "node:fs";
import { CASES, NUMBER_CASES } from "../upstream/torph/packages/test-cases/src/index.ts";
import { EXTRA_VALUES, EXTRA_CHAINS } from "./extra-corpus.ts";

const OUT = new URL("./fixtures/", import.meta.url).pathname;
mkdirSync(OUT, { recursive: true });

const inputs = new Set<string>();
for (const c of CASES) c.values.forEach((v) => inputs.add(v));
for (const c of NUMBER_CASES) c.values.forEach((v) => inputs.add(String(v)));
EXTRA_VALUES.forEach((v) => inputs.add(v));
Object.values(EXTRA_CHAINS).flat().forEach((v) => inputs.add(v));

const MORE = [
  "The quick (brown) fox's \"tail\" isn't long; it's short.",
  "e.g. i.e. etc. U.S.A. 3.5 1,000 1'000 1_000 a_b a-b a.b a,b a:b a;b a/b a\\b",
  "wait... what?! yes—no – maybe",
  "x=1; y+=2 && z||w",
  "C++ C# F# .NET node.js",
  "@user #tag $var %pct &amp",
  "日本語テキスト 中文文本 한국어 텍스트",
  "ひらがな カタカナ 漢字",
  "Ελληνικά Кириллица Հայերեն ქართული",
  "தமிழ் বাংলা ਪੰਜਾਬੀ ગુજરાતી",
  "العربية 123 عربي",
  "עברית 'quoted' \"double\"",
  "🙂🙃 🧑🏽‍💻 👩‍❤️‍👨 🏴󠁧󠁢󠁥󠁮󠁧󠁿",
  "á é̂ x‍y a​b",
  "1st 22nd 333rd 4444th",
  "10:30 12/25/2024 2024-12-25 +1-800-555-0100",
  "3.14 .5 5. -.5 1e10 0x1F",
  "hello world hello world hello　world",
  "don’t can’t o’clock ’tis",
  "won't can't shan't y'all",
  "ab­cd",
  "ألف باء",
  "ﷺ ﷲ",
  "Ｈｅｌｌｏ　Ｗｏｒｌｄ",
  "ⅠⅡⅢ ⅳⅴ",
  "①②③",
  "a\r\nb a\rb a\nb",
  "\t \n",
  "अ्क हिन्दी",
  "ก่า ไทย",
  "​zero​width​",
  "a¯b a·b a‧b a‿b",
  "12,345.67 12.345,67 12 345,67",
  "£5 ¥100 ₹50 ₿1",
  "5‰ 5‱ 5°C 5″",
  "α+β=γ ∑x ∫y",
  "a—b a–b a‐b a‑b",
  "ab‌cd zw‍join",
  "Zoë Chloé façade",
  "ABC abc AbC",
  "M&M's AT&T",
  "http://x.y/z?a=1&b=2#f",
  "foo(bar) [baz] {qux} <quux>",
  "❤️ ❤ ♥",
  "1️⃣ 2️⃣ #️⃣",
  "Ǆ ǅ ǆ",
  "ᚠᚢᚦ",
  "ꦗꦮ",
  "𝔘𝔫𝔦𝔠𝔬𝔡𝔢",
  "𐍈 𝒜 𝟘𝟙",
];
MORE.forEach((v) => inputs.add(v));

function boundaries(value: string, granularity: "word" | "grapheme") {
  const seg = new Intl.Segmenter("en", { granularity });
  return [...seg.segment(value)].map((s) => ({
    index: s.index,
    segment: s.segment,
    ...(granularity === "word" ? { isWordLike: (s as Intl.SegmentData & { isWordLike?: boolean }).isWordLike ?? false } : {}),
  }));
}

const out = [...inputs].map((value) => ({
  value,
  word: boundaries(value, "word"),
  grapheme: boundaries(value, "grapheme"),
}));
writeFileSync(`${OUT}segmenter.json`, JSON.stringify(out, null, 1));
console.log("wrote segmenter", out.length);
