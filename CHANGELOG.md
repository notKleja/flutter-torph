## Unreleased

* `blur` option: entering segments start slightly blurred and exiting ones
  blur out, for text, digits and group replacements alike. Defaults to `1.5`;
  `0` restores upstream's look. Not an upstream option.

## 0.1.3

* A 1:1 port of Torph 0.1.3 (upstream commit `d79a5aa`) to Flutter: `TextMorph`
  and the pure segmentation, diffing, number and easing utilities, matching
  upstream behaviour except where `spec/DEVIATIONS.md` records otherwise.
