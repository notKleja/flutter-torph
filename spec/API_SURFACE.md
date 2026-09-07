# API surface

## Upstream (index.ts)

`TextMorph` (class), `MorphController`, `DEFAULT_AS`, `DEFAULT_TEXT_MORPH_OPTIONS`, `segmentText`, `diffSegments`, `segmentNumber`, `isNumericWord`, `decimalSeparator`; types `TextMorphOptions`, `SpringParams`, `Segment`, `NumberSegment`, `DiffOptions`, `DiffResult`.

React props: `children` (string | number), `cursorIndex`, `className`, `style`, `as`, plus options minus `element`.

## Flutter package `torph`

```dart
TextMorph({
  required Object value,            // String or num (num is formatted with locale/decimals, as upstream)
  int? cursorIndex,
  TextStyle? style,
  TextAlign? textAlign,             // null → DefaultTextStyle / start
  TextDirection? textDirection,
  Locale? locale,                   // default Locale('en') — upstream default
  Duration duration = 400ms,
  Object ease = 'cubic-bezier(0.19, 1, 0.22, 1)',   // String (CSS easing) | SpringParams
  bool scale = true,
  bool numbers = true,
  int? decimals,
  bool disabled = false,
  bool respectReducedMotion = true,
  bool debug = false,
  VoidCallback? onAnimationStart, onAnimationComplete, onAnimationCancel,
})
```

Public pure exports mirroring upstream: `segmentText`, `diffSegments`, `segmentNumber`, `isNumericWord`, `decimalSeparator`, `spring`, `SpringParams`, `Segment`, `NumberSegment`, `DiffOptions`, `DiffResult`, `defaultTextMorphOptions`.

`as`, `className`, `style` (CSS) have no Flutter equivalent; `TextStyle`/`textAlign`/`textDirection` replace them (the root inherits `text-align` upstream; here it is a parameter or inherited from `DefaultTextStyle`).

Debug/test-only: `TextMorphSnapshot` via `debugSnapshot()` on the render object (see ARCHITECTURE).
