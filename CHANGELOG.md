## Unreleased

* Arabic and other joining scripts keep their connected letter forms when a
  word morphs character by character: live items are painted out of a painter
  that saw the whole line (RTL-005).

* `bidi` option (default `true`): right-to-left and mixed-direction values are
  laid out by the Unicode Bidirectional Algorithm, so numbers, Latin words and
  RTL words appear where a plain paragraph puts them. `bidi: false` restores
  upstream's logical-order placement (DEV-006).

* `blur` option: entering segments start slightly blurred and exiting ones
  blur out, for text, digits and group replacements alike. Defaults to `1.5`;
  `0` restores upstream's look. Not an upstream option.

* Words that morph character by character are cut into grapheme clusters
  instead of UTF-16 code units, so emoji, flags, ZWJ sequences and combining
  marks move as one unit rather than as tofu fragments (DEV-007).

* `ease` also accepts a Flutter `Curve` (`Curves.easeOutCubic`), sampled the
  way a spring is. The engine is keyed on the resolved easing, so an
  equivalent non-const `Curve` or `SpringParams` on every rebuild no longer
  restarts a morph in flight.

* `textAlign` now positions the text inside a box wider than its content, as
  `Text` does; previously it only aligned lines against each other.

* Per-line geometry and joining-script shaping are cached across frames, so a
  container-size transition no longer re-runs bidi layout every frame
  (~50× cheaper per frame for a long RTL line); the painter cache is bounded.

* A large `blur` is no longer clipped at the edge of its layer.

* **Breaking:** the inspection hooks (`RenderTextMorph`, `TextMeasurer`,
  `FrameState`, `ItemFrame`, `Lifecycle`, `TextMorphSnapshot`) moved out of
  `package:torph/torph.dart` into a new `package:torph/testing.dart`, and are
  no longer part of the main library's surface. `TextMorphOptions` and
  `defaultTextMorphOptions` were removed.

* Package metadata: real `homepage`/`repository`/`issue_tracker` URLs, an
  honest `flutter: ">=3.44.0"` constraint, and a tightened description.
  Added `.pubignore` so the published archive excludes `upstream/`, `oracle/`,
  `spike/`, `reports/`, dev tooling and IDE files, and example build output —
  shrinking the `dart pub publish --dry-run` archive well under 1 MB.

* CI (`.github/workflows/ci.yml`, `tool/ci.sh`) now also runs
  `dart format --output=none --set-exit-if-changed .` and
  `dart pub publish --dry-run`.

* The example app leads with a minimal "Hello" card — a `String` in state and
  a `TextMorph` that morphs on tap, no option plumbing — and its README now
  explains how to run it and what each demo shows.

* Added widget tests covering initial-render geometry, settled morph geometry
  against a fresh render, rapid interrupted updates, empty-value transitions,
  repeated-character churn, style and text-scaling changes, `Duration.zero`,
  grapheme-cluster morphs, the `disabled` toggle, and disposal mid-morph
  (route pop, `TickerMode`, and a deferred-callback race).

## 0.1.3

* A 1:1 port of Torph 0.1.3 (upstream commit `d79a5aa`) to Flutter: `TextMorph`
  and the pure segmentation, diffing, number and easing utilities, matching
  upstream behaviour except where `spec/DEVIATIONS.md` records otherwise.
