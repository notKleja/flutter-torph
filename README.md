# torph

`TextMorph` is a Flutter widget that animates text from one value to the
next: unchanged words and characters persist in place, changed ones enter and
exit, and numbers morph by place value instead of fading as a block.

A 1:1 port of [Torph](https://github.com/lochieaxon/torph) by Lochie Axon,
pinned to upstream 0.1.3 (`d79a5aa`). Behaviour matches upstream except where
noted under [Deviations from upstream](#deviations-from-upstream).

## Installation

```bash
flutter pub add torph
```

## Usage

```dart
TextMorph(value: text)
```

Rebuild it with a new `value` and the text morphs from what is on screen.
Rebuilding again before a morph finishes interrupts it and continues from
wherever it was.

```dart
import 'package:flutter/widgets.dart';
import 'package:torph/torph.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => count++),
      child: TextMorph(value: '$count'),
    );
  }
}
```

`value` takes a `String`, used verbatim, or a `num`, formatted for you (see
[Numbers](#numbers)).

## Styling

```dart
TextMorph(
  value: text,
  style: const TextStyle(fontSize: 32),
  textAlign: TextAlign.center,
)
```

`style` is merged over the enclosing `DefaultTextStyle`; `textAlign` falls
back to `DefaultTextStyle`'s, then `start`; `textDirection` falls back to the
ambient `Directionality` — the only ancestor `TextMorph` actually requires, the
same as `Text`. `locale` falls back to the ambient `Localizations`, then
`'en'`, and affects both numeric formatting and word segmentation.

Inside a box wider than the text, `textAlign` positions the block the way it
positions a `Text`. Text never soft-wraps (upstream's no-wrap model): a line
only breaks at an explicit `'\n'`; see [Multi-line text](#multi-line-text).

## Animation

```dart
TextMorph(
  value: text,
  duration: const Duration(milliseconds: 400),
  ease: 'cubic-bezier(0.19, 1, 0.22, 1)',
  scale: true,
  blur: 1.5,
)
```

`ease` accepts three forms:

- a CSS easing **`String`**, e.g. `'ease-out'`, `'cubic-bezier(0.19, 1, 0.22, 1)'`
  (the default) or a `'linear(...)'` step function
- a Flutter **`Curve`**, e.g. `Curves.easeOutCubic`
- **`SpringParams`**, for physics-based motion — see [Spring animations](#spring-animations)

`scale` controls whether entering and exiting characters scale as well as
fade; `blur` is the blur sigma (logical pixels) they animate through, `0` to
turn it off.

### Spring animations

```dart
TextMorph(
  value: text,
  ease: const SpringParams(stiffness: 200, damping: 20),
)
```

A spring settles on its own physics, so `duration` is ignored.

| Parameter   | Type     | Default | Description                                 |
| ----------- | -------- | ------- | -------------------------------------------- |
| `stiffness` | `double` | `100`   | How strongly the spring pulls toward rest    |
| `damping`   | `double` | `10`    | How quickly oscillation is absorbed          |
| `mass`      | `double` | `1`     | The moving object's mass                     |
| `precision` | `double` | `0.001` | How close to rest counts as settled          |

## Numbers

Numeric words morph by place value: digits slide along the block axis, and
the symbols around them — currency, separators, signs, suffixes — travel with
the places they belong to. It is on by default, so any value that contains a
number already animates this way. Pass `numbers: false` to fall back to the
character-level text morph.

```dart
// 1,204 → 1,318 rolls the hundreds and tens, leaves the thousands alone
TextMorph(value: '\$${NumberFormat.decimalPattern('en').format(total)}')
```

A value passed as a `num` rather than a `String` is formatted for you, so
`locale` and `decimals` apply:

```dart
TextMorph(value: 1234.5, decimals: 2, locale: const Locale('de', 'DE'))
```

Pair a counter with tabular figures so the digits hold their columns:

```dart
TextMorph(
  value: total,
  decimals: 2,
  style: const TextStyle(
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  ),
)
```

### Editable fields

Place matching is the right default for a value that changes on its own — a
counter, a total, a chart readout. It is the wrong one for a field somebody is
typing in, where the character that just changed is known and place value is
not the point: typing `1` in front of `20` should insert a digit, not
renumber the column.

Pass `cursorIndex` to switch that update from place matching to caret
matching.

```dart
final TextEditingController controller = TextEditingController();

TextField(controller: controller),
TextMorph(
  value: controller.text,
  cursorIndex: controller.selection.isValid
      ? controller.selection.baseOffset
      : null,
),
```

## Multi-line text

Newlines in a value are rendered as line breaks, and text morphs normally
across them. This is the only way a line breaks — the text never wraps at
the box's width.

```dart
TextMorph(value: 'Total\n1,234')
```

## Callbacks

```dart
TextMorph(
  value: text,
  onAnimationStart: () => debugPrint('morph started'),
  onAnimationComplete: () => debugPrint('morph settled'),
  onAnimationCancel: () => debugPrint('morph interrupted'),
)
```

`onAnimationStart` fires once per morph. Exactly one of
`onAnimationComplete` (it finished) or `onAnimationCancel` (a later value
interrupted it first) follows every `onAnimationStart`. The very first render
of a `TextMorph` is not a morph and fires none of these.

## Accessibility

The rendered value is exposed to screen readers as a single semantics node
carrying its plain text, so a morph never reads out as a pile of individual
characters entering and exiting.

Motion is skipped — the value still updates, just without animation — when
`disabled: true`, or when `respectReducedMotion` is `true` (the default) and
the platform's reduce-motion setting is on. Pass `respectReducedMotion: false`
to animate regardless of that setting.

## API

### Options

| Option                 | Type                                | Default                              | Description |
| ----------------------- | ------------------------------------ | ------------------------------------- | ----------- |
| `value`                | `Object` (`String`/`num`)           | required                             | The value to display |
| `cursorIndex`          | `int?`                               | `null`                                | Caret position; switches a single-number value from place matching to caret matching |
| `style`                | `TextStyle?`                         | `null`                                | Merged over the enclosing `DefaultTextStyle` |
| `textAlign`            | `TextAlign?`                         | `DefaultTextStyle`, then `start`     | Alignment of the morphing text |
| `textDirection`        | `TextDirection?`                     | ambient `Directionality`             | Text direction |
| `locale`               | `Locale?`                            | `Localizations`, then `Locale('en')` | Locale for text segmentation, and for formatting a numeric value |
| `duration`             | `Duration`                           | `400ms`                              | Animation duration. Ignored when `ease` is a spring, which settles on its own physics |
| `ease`                 | `Object` (`String`/`Curve`/`SpringParams`) | `'cubic-bezier(0.19, 1, 0.22, 1)'` | CSS easing string, Flutter `Curve`, or spring parameters |
| `scale`                | `bool`                               | `true`                                | Scale animation on entering and exiting segments |
| `numbers`              | `bool`                               | `true`                                | Morph numeric words by place value, sliding digits along the block axis. Off falls back to the character-level text morph |
| `decimals`             | `int?`                               | `null`                                | Fraction digits to format a numeric value to. Applies when `value` is a `num`; ignored for strings |
| `blur`                 | `double`                             | `1.5`                                 | Blur sigma (logical px) entering segments start from and exiting segments fade into, riding the same fade. `0` turns it off. Not in upstream |
| `bidi`                 | `bool`                               | `true`                                | Place each segment where the Unicode Bidirectional Algorithm puts its text. `false` restores upstream's logical-order placement. Not in upstream |
| `disabled`             | `bool`                               | `false`                               | Disable all morphing animations |
| `respectReducedMotion` | `bool`                               | `true`                                | Respect the platform's reduce-motion setting |
| `debug`                | `bool`                               | `false`                               | Outlines the root (magenta) and every item (cyan) |
| `onAnimationStart`     | `VoidCallback?`                      | `null`                                | Fired when a morph begins |
| `onAnimationComplete`  | `VoidCallback?`                      | `null`                                | Fired when a morph completes uninterrupted |
| `onAnimationCancel`    | `VoidCallback?`                      | `null`                                | Fired when a morph is interrupted by the next one. Exactly one of `onAnimationComplete` and `onAnimationCancel` runs per morph |

`defaultDuration`, `defaultEase`, `defaultBlur` and `defaultLocaleTag` expose
those same defaults as top-level constants.

### Utilities

The text matching torph runs on is exported for building your own behaviour on
top of it:

- `segmentText(String value, String locale, {bool numbers = true})` — split a
  value into `Segment`s
- `diffSegments(List<Segment> oldSegments, String newText, String locale, [DiffOptions options])`
  — match a new value against existing segments, returning the segments that
  persist, enter and exit
- `segmentNumber(String value, [List<Segment>? prevSegments, int? cursorIndex, String decimalChar])`
  — per-character `NumberSegment`s, matched by caret where `cursorIndex` is
  given, else by place
- `isNumericWord(String word)` and `decimalSeparator(String locale)`
- `spring(SpringParams params)` — the `linear(...)` easing and duration a
  spring resolves to

`package:torph/testing.dart` additionally exports the rendering internals
(`RenderTextMorph`, `TextMeasurer`, `FrameState`, `ItemFrame`, `Lifecycle`,
`TextMorphSnapshot`) used to inspect a running `TextMorph` from tests —
nothing there is needed to just use the widget, and none of it is covered by
this package's compatibility promise.

## Deviations from upstream

- Right-to-left roots follow the Unicode Bidirectional Algorithm: numbers,
  Latin words and RTL words land where a plain paragraph puts them. Upstream
  instead lays every segment out as an atomic box in logical order, which
  reverses digit runs and word order; pass `bidi: false` for that behaviour
  (DEV-006, see [`spec/RTL_KNOWN_LIMITATIONS.md`](spec/RTL_KNOWN_LIMITATIONS.md)).
- Words that morph character by character are cut into grapheme clusters, so
  an emoji, flag or accented letter moves as one unit; upstream cuts into
  UTF-16 code units (DEV-007).
- `ease` additionally accepts a Flutter `Curve`, sampled into the same
  step-function form a spring resolves to; upstream only accepts a CSS easing
  string or spring parameters.
- The remaining places where the platform forced a difference are recorded in
  [`spec/DEVIATIONS.md`](spec/DEVIATIONS.md) — ICU dictionary word breaks for
  CJK/Thai, browser layout quantisation tolerances, callbacks fired during a
  build being flushed at the end of the same frame, and line breaking in
  `disabled` mode.

## Example

[`example/`](example/) is a runnable app covering the counter, the upstream
sentence and number corpus, an editable field wired to `cursorIndex`,
multi-line values, the option toggles and an interruption storm. Frame timings
are in [`spec/PERFORMANCE.md`](spec/PERFORMANCE.md).

## License

MIT. Torph, the upstream JavaScript library, is copyright Lochie Axon; see
[`LICENSE`](LICENSE).
