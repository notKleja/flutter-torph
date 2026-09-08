# torph

Animated text morphing for Flutter. Words and characters persist, enter and
exit between values; numbers morph by place value.

A 1:1 port of [Torph](https://github.com/lochieaxon/torph) by Lochie Axon,
pinned to upstream 0.1.3 (`d79a5aa`). Behaviour matches upstream except where
[`spec/DEVIATIONS.md`](spec/DEVIATIONS.md) records otherwise.

## Installation

```yaml
dependencies:
  torph: ^0.1.3
```

```bash
flutter pub add torph
```

## Usage

```dart
import 'package:torph/torph.dart';

class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  String text = 'Hello World';

  @override
  Widget build(BuildContext context) {
    return TextMorph(
      value: text,
      duration: const Duration(milliseconds: 400),
      ease: 'cubic-bezier(0.19, 1, 0.22, 1)',
      locale: const Locale('en'),
      style: const TextStyle(fontSize: 32),
      onAnimationComplete: () => debugPrint('Animation done!'),
    );
  }
}
```

`value` takes a `String` used verbatim, or a `num` formatted with `locale` and
`decimals`. The widget is the whole API: rebuild it with a new `value` and it
morphs from the value it is showing, interrupting a morph in flight if there is
one.

Text styling comes from `style` merged over the enclosing `DefaultTextStyle`;
`textAlign` and `textDirection` fall back to `DefaultTextStyle` and the ambient
`Directionality`. Upstream's `as`, `className` and CSS `style` have no Flutter
equivalent.

## Spring animations

Pass `SpringParams` to `ease` for physics-based easing. The duration is
computed from the spring physics, so `duration` is ignored.

```dart
TextMorph(
  value: text,
  ease: const SpringParams(stiffness: 200, damping: 20),
)
```

### Spring parameters

| Parameter   | Type     | Default | Description                               |
| ----------- | -------- | ------- | ----------------------------------------- |
| `stiffness` | `double` | `100`   | Spring stiffness coefficient              |
| `damping`   | `double` | `10`    | Damping coefficient                       |
| `mass`      | `double` | `1`     | Mass of the spring                        |
| `precision` | `double` | `0.001` | Threshold for determining settled position |

## Numbers

Numeric words morph by place value: digits slide along the block axis, and the
symbols around them — currency, separators, signs, suffixes — travel with the
places they belong to. It is on by default, so any value that contains a number
already animates this way. Pass `numbers: false` to fall back to the
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
typing in, where the character that just changed is known and place value is not
the point: typing `1` in front of `20` should insert a digit, not renumber the
column.

Pass `cursorIndex` to switch that update from place matching to caret matching.

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
across them.

```dart
TextMorph(value: 'Total\n1,234')
```

## API

### Options

| Option                 | Type                       | Default                            | Description |
| ---------------------- | -------------------------- | ---------------------------------- | ----------- |
| `value`                | `Object` (`String`/`num`)  | required                           | The value to display |
| `duration`             | `Duration`                 | `400ms`                            | Animation duration. Ignored when `ease` is a spring, which settles on its own physics |
| `ease`                 | `Object` (`String`/`SpringParams`) | `'cubic-bezier(0.19, 1, 0.22, 1)'` | CSS easing function or spring parameters |
| `scale`                | `bool`                     | `true`                             | Scale animation on entering and exiting segments |
| `numbers`              | `bool`                     | `true`                             | Morph numeric words by place value, sliding digits along the block axis. Off falls back to the character-level text morph |
| `decimals`             | `int?`                     | `null`                             | Fraction digits to format a numeric value to. Applies when `value` is a `num`; ignored for strings |
| `locale`               | `Locale?`                  | `Localizations`, then `Locale('en')` | Locale for text segmentation, and for formatting a numeric value |
| `cursorIndex`          | `int?`                     | `null`                             | Caret position; switches a single-number value from place matching to caret matching |
| `debug`                | `bool`                     | `false`                            | Outlines the root (magenta) and every item (cyan) |
| `disabled`             | `bool`                     | `false`                            | Disable all morphing animations |
| `respectReducedMotion` | `bool`                     | `true`                             | Respect the platform's reduce-motion setting |
| `onAnimationStart`     | `VoidCallback?`            | `null`                             | Fired when an animation begins |
| `onAnimationComplete`  | `VoidCallback?`            | `null`                             | Fired when an animation completes |
| `onAnimationCancel`    | `VoidCallback?`            | `null`                             | Fired when a morph is interrupted by the next one. Exactly one of `onAnimationComplete` and `onAnimationCancel` runs per morph |
| `style`                | `TextStyle?`               | `null`                             | Merged over the enclosing `DefaultTextStyle` |
| `textAlign`            | `TextAlign?`               | `DefaultTextStyle`, then `start`   | Alignment of the morphing text |
| `textDirection`        | `TextDirection?`           | ambient `Directionality`           | Text direction |

`defaultTextMorphOptions` exposes the same defaults as a value, mirroring
upstream's `DEFAULT_TEXT_MORPH_OPTIONS`.

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
- `spring(SpringParams params)` — the `linear(...)` easing and duration a spring
  resolves to

## Accessibility

The rendered value is exposed to screen readers as its plain text, so a morph
never reads as a pile of characters. When the platform asks for reduced motion
(`MediaQuery.disableAnimationsOf`), values swap without motion; pass
`respectReducedMotion: false` to animate anyway, or `disabled: true` to render
plain text always.

## Deviations from upstream

This is a 1:1 port; the places where the platform forced a difference are
recorded in [`spec/DEVIATIONS.md`](spec/DEVIATIONS.md) — ICU dictionary word
breaks for CJK/Thai, browser layout quantisation tolerances, callbacks fired
during a build being flushed at the end of the same frame, and line breaking in
`disabled` mode.

## Example

[`example/`](example/) is a runnable app covering the counter, the upstream
sentence and number corpus, an editable field wired to `cursorIndex`,
multi-line values, the option toggles and an interruption storm. Frame timings
are in [`spec/PERFORMANCE.md`](spec/PERFORMANCE.md).

## License

MIT. Torph, the upstream JavaScript library, is copyright Lochie Axon; see
[`LICENSE`](LICENSE).
