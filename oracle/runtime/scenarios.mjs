/** Scenario definitions for the runtime motion oracle. */

const MENLO = { fontFamily: "Menlo", fontSize: 20, textAlign: "left" };
const HELV = { fontFamily: "Helvetica", fontSize: 20, textAlign: "left" };
const CENTER = { fontFamily: "Menlo", fontSize: 20, textAlign: "center" };
const RIGHT = { fontFamily: "Menlo", fontSize: 20, textAlign: "right" };
const RTL = { fontFamily: "Menlo", fontSize: 20, textAlign: "start", direction: "rtl" };
const RTL_CENTER = { fontFamily: "Menlo", fontSize: 20, textAlign: "center", direction: "rtl" };
const RTL_END = { fontFamily: "Menlo", fontSize: 20, textAlign: "end", direction: "rtl" };

const DEFAULT_OPTS = {};
const SPRING_OPTS = { ease: { stiffness: 200, damping: 20 } };
const NOSCALE_OPTS = { scale: false };

/** Short stable digest, so a non-ASCII or colliding label still gets a unique file. */
function hash6(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, "0").slice(0, 6);
}

export function slugify(label) {
  const base =
    label
      .replace(/\n/g, "-nl-")
      .replace(/[^a-zA-Z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .toLowerCase()
      .slice(0, 100) || "scenario";
  // Labels differing only in punctuation ("999"/"$999") or in non-ASCII text collapse
  // to the same base, so every slug carries the label digest.
  return `${base}-${hash6(label)}`;
}

/** A simple two-step morph: render `a`, then morph to `b` at t=0. */
function pair(a, b, opts = DEFAULT_OPTS, page = MENLO, tag = "") {
  return {
    label: `${tag ? tag + " " : ""}${JSON.stringify(a)} -> ${JSON.stringify(b)}`,
    page,
    options: opts,
    initial: a,
    steps: [{ at: 0, value: b }],
  };
}

/** Render `a`, morph to `b` at t=0, interrupt with `c` at `frac` of the duration. */
function interrupt(a, b, c, frac, opts = DEFAULT_OPTS, page = MENLO) {
  return {
    label: `interrupt@${Math.round(frac * 100)}% ${JSON.stringify(a)} -> ${JSON.stringify(b)} -> ${JSON.stringify(c)}`,
    page,
    options: opts,
    initial: a,
    interruptFraction: frac,
    steps: [{ at: 0, value: b }, { at: { frac }, value: c }],
  };
}

function storm(label, values, gap = 16, opts = DEFAULT_OPTS, page = MENLO) {
  return {
    label: `storm ${label}`,
    page,
    options: opts,
    initial: values[0],
    steps: values.slice(1).map((v, i) => ({ at: i * gap, value: v })),
  };
}

const WORD_PAIRS = [
  ["hello", "hello world"],
  ["hello world", "hello"],
  ["hello world", "world hello"],
  ["Transaction Safe", "Processing Transaction"],
  ["npm", "pnpm"],
  ["cat and dog", "fish and bird"],
  ["Copy Address", "Address Copied"],
  ["the cat the", "the dog the"],
  ["foo foo foo", "foo bar foo"],
  ["one two three", "three two one"],
  ["AAAA", "AAAB"],
  ["abcdef", "qwerty"],
  ["abcdefghijklmnop", "abcmnopqrstuvwx"],
];

const NUMBER_PAIRS = [
  ["9", "10"],
  ["99", "100"],
  ["999", "1,000"],
  ["9.99", "10.00"],
  ["-999.50", "-1,000.00"],
  ["$999", "$1,000"],
  ["1234", "1,234"],
  ["$999.50", "$1,000,000.00"],
  ["42", "hello"],
  ["hello", "42"],
  ["1 of 10", "2 of 10"],
];

const NEWLINE_PAIRS = [
  ["Hello\nWorld", "Hello"],
  ["a\n1,234\nb", "a\n5,678\nb"],
  ["hello world", "hello\nworld"],
];

const UNICODE_PAIRS = [
  ["مرحبا", "مرحبا بالعالم"],
  ["😀 hi", "hi 😀"],
  ["café", "cafe"],
];

const INTERRUPT_FRACS = [0.01, 0.05, 0.1, 0.25, 0.37, 0.5, 0.73, 0.9, 0.99];

const INTERRUPT_TRIPLES = [
  ["hello world", "hello there", "hello friend"],
  ["999", "1,000", "999"],
  ["abcdef", "qwerty", "abcdef"],
  ["hello", "", "hello"],
  ["a", "a\nb", "a"],
  ["hi", "hello world foo bar", "hi"],
];

/** Representative subset re-run under alternate configurations. */
const SUBSET = [
  ["hello", "hello world"],
  ["hello world", "world hello"],
  ["999", "1,000"],
  ["abcdefghijklmnop", "abcmnopqrstuvwx"],
  ["Hello\nWorld", "Hello"],
];

export function buildScenarios() {
  const out = [];

  for (const [a, b] of WORD_PAIRS) out.push(pair(a, b));
  for (const [a, b] of NUMBER_PAIRS) out.push(pair(a, b));
  for (const [a, b] of NEWLINE_PAIRS) out.push(pair(a, b));
  for (const [a, b] of UNICODE_PAIRS) out.push(pair(a, b));

  // RTL root direction (Q-025): inline-blocks flow from the right edge.
  for (const [pg, tag] of [[RTL, "rtl"], [RTL_CENTER, "rtl-center"], [RTL_END, "rtl-end"]]) {
    for (const [a, b] of [
      ["مرحبا", "مرحبا بالعالم"],
      ["hello world", "hello"],
      ["abc", "abcdef"],
      ["999", "1,000"],
      ["a\nbb", "a\nbbbbbb"],
      ["hello world", "world hello"],
    ]) {
      out.push(pair(a, b, DEFAULT_OPTS, pg, tag));
    }
  }

  // cursorIndex variant: "$120" caret after "$1" -> "$1120" caret after "$11"
  out.push({
    label: 'cursor "$120"@2 -> "$1120"@3',
    page: MENLO,
    options: DEFAULT_OPTS,
    initial: "$120",
    initialCursorIndex: 2,
    steps: [{ at: 0, value: "$1120", cursorIndex: 3 }],
  });

  // empty transitions
  out.push({
    label: 'empty "hello" -> "" -> "hello"',
    page: MENLO,
    options: DEFAULT_OPTS,
    initial: "hello",
    steps: [
      { at: 0, value: "" },
      { at: 600, value: "hello" },
    ],
  });
  out.push(pair("", "hello", DEFAULT_OPTS, MENLO, "fromEmpty"));

  // same-value updates must be complete no-ops
  out.push({
    label: 'noop "hello world" -> same -> same',
    page: MENLO,
    options: DEFAULT_OPTS,
    initial: "hello world",
    steps: [
      { at: 0, value: "hello world" },
      { at: 100, value: "hello world" },
    ],
  });
  out.push({
    label: 'noop number 1234 -> "1,234" -> "1,234"',
    page: MENLO,
    options: DEFAULT_OPTS,
    initial: "1,234",
    steps: [
      { at: 0, value: "1,234" },
      { at: 200, value: "1,234" },
    ],
  });

  // alternate configurations over the subset
  for (const [a, b] of SUBSET) {
    out.push(pair(a, b, SPRING_OPTS, MENLO, "spring"));
    out.push(pair(a, b, NOSCALE_OPTS, MENLO, "noscale"));
    out.push(pair(a, b, DEFAULT_OPTS, CENTER, "center"));
    out.push(pair(a, b, DEFAULT_OPTS, RIGHT, "right"));
    out.push(pair(a, b, DEFAULT_OPTS, HELV, "helvetica"));
  }

  // Q-004 focus: centre/right alignment on a pure grow and a pure shrink,
  // where every persisting item picks up a non-zero dx from the pinned old width.
  for (const page of [CENTER, RIGHT]) {
    out.push(pair("hi", "hello world", DEFAULT_OPTS, page, "align-grow"));
    out.push(pair("hello world", "hi", DEFAULT_OPTS, page, "align-shrink"));
    out.push(pair("a\nbb", "a\nbbbbbb", DEFAULT_OPTS, page, "align-multiline"));
    // The root width is fixed by line 1, so the container never resizes, yet the
    // survivors on line 2 still get a per-line alignment delta.
    out.push(
      pair(
        "aaaaaaaaaaaaaaaaaaaa\nhello world",
        "aaaaaaaaaaaaaaaaaaaa\nhello",
        DEFAULT_OPTS,
        page,
        "align-fixedwidth-shrink",
      ),
    );
    out.push(
      pair(
        "aaaaaaaaaaaaaaaaaaaa\nhello",
        "aaaaaaaaaaaaaaaaaaaa\nhello world",
        DEFAULT_OPTS,
        page,
        "align-fixedwidth-grow",
      ),
    );
    out.push(
      pair("hello world", "hello", DEFAULT_OPTS, page, "align-shrink-survivors"),
    );
  }

  // interruptions
  for (const [a, b, c] of INTERRUPT_TRIPLES) {
    for (const f of INTERRUPT_FRACS) out.push(interrupt(a, b, c, f));
  }

  // CARRY coverage. The default ease has slopeAt(0) = 1/0.19 = 5.263, so
  // `carry()` computes k <= 0 and never engages. Only a gentler base easing
  // produces the carried `linear(...)` curve, so exercise those explicitly.
  const CARRY_EASES = [
    ["easein", { ease: "ease-in" }],
    ["linear", { ease: "linear" }],
    ["spring", SPRING_OPTS],
  ];
  for (const [tag, opts] of CARRY_EASES) {
    for (const f of [0.1, 0.25, 0.5, 0.9]) {
      out.push({
        label: `carry-${tag}@${Math.round(f * 100)}% "hi" -> "hello world foo bar" -> "hello"`,
        page: MENLO,
        options: opts,
        initial: "hi",
        steps: [
          { at: 0, value: "hello world foo bar" },
          { at: { frac: f }, value: "hello" },
        ],
      });
    }
    // Same-target resume path (|previous.to - to| < 0.5) under a gentle ease.
    out.push({
      label: `carry-${tag} same-target storm "1" -> "2" -> "3" -> "4"`,
      page: MENLO,
      options: opts,
      initial: "1",
      steps: [
        { at: 0, value: "2" },
        { at: 16, value: "3" },
        { at: 32, value: "4" },
      ],
    });
    out.push({
      label: `carry-${tag} growth storm "a" -> "aa" -> "aaaa" -> "aaaaaaaa"`,
      page: MENLO,
      options: opts,
      initial: "a",
      steps: [
        { at: 0, value: "aa" },
        { at: 16, value: "aaaa" },
        { at: 32, value: "aaaaaaaa" },
      ],
    });
  }

  // storms
  out.push(storm("words A..E", ["A", "B", "C", "D", "E"]));
  out.push(storm("digits 1..5", ["1", "2", "3", "4", "5"]));
  out.push(storm("tabular $100..$103", ["$100", "$101", "$102", "$103"]));
  out.push(
    storm("grow hi->hello->hello world->hello world foo", [
      "hi",
      "hello",
      "hello world",
      "hello world foo",
    ]),
  );

  // Q-012 focus: a mover mid-enter that starts exiting.
  out.push({
    label: "Q012 mover mid-enter then exiting 999 -> 1,000 -> 42",
    page: MENLO,
    options: DEFAULT_OPTS,
    initial: "999",
    steps: [
      { at: 0, value: "1,000" },
      { at: { frac: 0.25 }, value: "999.5" },
    ],
  });

  // Q-004/CONTAINER focus: oldWidth read mid-flight.
  out.push({
    label: "container oldWidth mid-flight hi -> hello world -> hi",
    page: MENLO,
    options: DEFAULT_OPTS,
    initial: "hi",
    steps: [
      { at: 0, value: "hello world" },
      { at: { frac: 0.5 }, value: "hi" },
    ],
  });

  const seen = new Map();
  for (const s of out) {
    let slug = slugify(s.label);
    const n = (seen.get(slug) || 0) + 1;
    seen.set(slug, n);
    s.slug = n === 1 ? slug : `${slug}--${n}`;
  }
  return out;
}

/** Sample grid: update instants, duration fractions, and 16 ms steps for 100 ms. */
export function sampleTimes(updateTimes, duration) {
  const fracs = [0, 0.01, 0.05, 0.1, 0.25, 0.37, 0.5, 0.73, 0.9, 1.0, 1.1];
  const set = new Set();
  for (const a of updateTimes) {
    for (const f of fracs) set.add(round(a + duration * f));
    for (let k = 1; k <= 6; k++) set.add(round(a + 16 * k));
  }
  return [...set].sort((x, y) => x - y);
}

const round = (n) => Math.round(n * 1000) / 1000;
