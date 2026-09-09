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

## 0.1.3

* A 1:1 port of Torph 0.1.3 (upstream commit `d79a5aa`) to Flutter: `TextMorph`
  and the pure segmentation, diffing, number and easing utilities, matching
  upstream behaviour except where `spec/DEVIATIONS.md` records otherwise.
