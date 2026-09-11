# torph example

Demos for the `torph` package.

## Run it

```
cd example
flutter run
```

## What's here

* **Hello** — the minimal case: a `String` in state and a `TextMorph` that
  morphs when it changes. Tap to cycle through a few phrases.
* **Options** — global controls (language/RTL, alignment, scale, numbers,
  blur, duration, easing, bidi, disabled) that every other demo below reads.
* **Counter** — a currency value that morphs digit by digit as it changes.
* **Sentence** — word-level morphs from the upstream test corpus (reorders,
  emoji, accents, RTL, complete replacements).
* **Numbers** — number-only cases from the upstream test corpus.
* **Multi-line** — values that wrap across more than one line.
* **Editable field (cursorIndex)** — a text field whose caret position drives
  `cursorIndex`, switching the number from place matching to caret matching.
* **Interruption storm** — rapid updates (every 16 ms for 2 s) to exercise
  interrupted, cancelled and restarted morphs.
