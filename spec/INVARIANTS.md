# Invariants

Hold at every step of every chain, for every input, in both upstream and the port.

- INV-1 Live segment IDs are unique within one rendered value (`unique-ids.test.ts`, engine invariants test).
- INV-2 Concatenating live segment strings (NBSP→space, `\n` dropped) equals the value with `\n` removed, except the empty value which renders U+200B.
- INV-3 A segment string is never empty (except the `empty` placeholder).
- INV-4 Text-derived IDs never start with U+0000; minted IDs always do (`U+0000 n<counter>`). The two namespaces are disjoint.
- INV-5 A `kind` is present iff the segment came from `segmentNumber` (directly or inherited via `reuse`).
- INV-6 A `"\n"` segment always has an ID starting with `newline-`; an NBSP segment produced from `" "` always has `space-`.
- INV-7 The diff is a pure function of `(previousSegments, newText, locale, options)` plus the minted-ID counter.
- INV-8 Every persisting segment keeps its previous ID; every exiting element keeps the kind it left with.
- INV-9 Layout coordinates are never overwritten by animated coordinates: `measure` subtracts the current translate.
- INV-10 Exiting elements are never measured, never re-animated, never matched.
- INV-11 Exactly one of `onAnimationComplete` / `onAnimationCancel` runs per non-initial morph; `destroy` runs neither.
- INV-12 Fade durations are shares of `duration`: exit 0.25 (text) / 0.45 (number, group); enter 0.5 after 0.25 delay (text) / 0.25 (number) / 0.35 (group).
- INV-13 The container's width and height each animate from the previous *layout* size, never from a visual (transformed) box.
- INV-14 `slideDistance` is one line box: `height / lineCount`.
- INV-15 Semantics expose the whole value once; fragments are hidden.
