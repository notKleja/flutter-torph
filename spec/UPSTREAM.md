# Upstream: Torph (pinned)

| Field | Value |
| --- | --- |
| Repository | https://github.com/lochie/torph |
| Pinned SHA | `d79a5aa63226acf97d49c3e34fafb2e85c07b026` |
| Version | 0.1.3 (packages/torph/package.json) |
| Commit date | 2026-09-07 23:17:22 +1000 |
| License | MIT (upstream/torph/LICENSE) |
| Snapshot | `upstream/torph/` (full clone, checked out at the pinned SHA; never tracks `main`) |
| Oracle runtime | Node 26.7.0, V8 14.6, ICU 78.3, Unicode 17.0 |

`spec/UPSTREAM_SHA` holds the SHA alone for scripts.

## Relevant source tree (packages/torph/src)

| File | Role | Ported to |
| --- | --- | --- |
| `lib/utils/types.ts` | `Segment`, `SegmentKind`, `BaseMorphOptions`, `BASE_DEFAULTS` | `core/segment.dart`, `widget/options.dart` |
| `lib/utils/constants.ts` | DOM attribute names, `EMPTY_ID = "empty"` | `core/segment.dart` |
| `lib/utils/lcs.ts` | `lcsIndices` (forward tie-break) | `core/lcs.dart` |
| `lib/utils/easing.ts` | `parseEasing` (keywords, cubic-bezier, linear()), `slopeAt` | `motion/easing.dart` |
| `lib/utils/spring.ts` | `spring`, `springPosition`, `computeDuration`, `resolveEase` | `motion/spring.dart` |
| `lib/utils/animate.ts` | `fadeDuration`, `carry`, `sampleEasing`, container axis transitions, `holdContainerSize` | `motion/carry.dart`, `motion/container_motion.dart` |
| `lib/utils/flip.ts` | `measure`, `computeDelta`, `findNearestAnchor`, `resolveExitingAnchors` | `motion/flip.dart` |
| `lib/utils/dom.ts` | `detachFromFlow`, `splitWordSpans`, `syncSlot`, `moverOf`, `reconcileChildren` | `motion/scene.dart` (logical children) |
| `lib/utils/styles.ts` | root/item/slot/sr CSS (nowrap, inline-block, clip-path, mask) | `rendering/*` |
| `lib/utils/reduced-motion.ts` | live `prefers-reduced-motion` listener | `widget/text_morph_state.dart` |
| `lib/text-morph/index.ts` | `TextMorph` engine: `update`, `createTextGroup`, `updateStyles`, `syncAccessibleText`, `destroy` | `motion/motion_engine.dart` |
| `lib/text-morph/controller.ts` | `MorphController` (attach/update/needsRecreate) | `widget/text_morph_controller.dart` |
| `lib/text-morph/types.ts` | `TextMorphOptions` | `widget/options.dart` |
| `lib/text-morph/utils/segment.ts` | `createIdAllocator`, `groupIntoWords`, `expandNumbers`, `segmentText`, `segmentLine`, `segmentsFromIntl`, `allocSegmentId`, `segmentsFallback` | `core/segmenter.dart`, `core/identity.dart` |
| `lib/text-morph/utils/diff.ts` | `diffSegments`, `splitIfWhole`, `charSimilarity`, `gapIndices`, `pairAffinity`, constants | `core/diff.dart`, `core/similarity.dart` |
| `lib/text-morph/utils/number.ts` | `mintId`, `isDigit`, `hasDigit`, `numericSkeleton`, `isNumericWord`, `classifyKind`, `decimalSeparator`, `segmentNumber`, `cursorMatch`, `placeMatch`, `findPivot` | `core/number.dart`, `core/number_match.dart` |
| `lib/text-morph/utils/animate.ts` | `animateExit`, `animateEnterOrPersist` | `motion/segment_motion.dart` |
| `lib/text-morph/utils/number-animate.ts` | `animateNumberExit/Enter/Persist` (slot + mover) | `motion/number_motion.dart` |
| `lib/text-morph/utils/replace-animate.ts` | `GROUP_MIN`, `originsFor`, `animateGroupExit/Enter`, `replacedRuns` | `core/replacement.dart`, `motion/replacement_motion.dart` |
| `react/TextMorph.tsx` | props → controller; `cursorIndex`; number children | `widget/text_morph.dart` |
| `vue/TextMorph.ts`, `svelte/TextMorph.svelte` | same controller, no cursorIndex | n/a (behaviour identical) |
| `index.ts` | public surface | `torph.dart` |

## Tests and corpus

| Path | What it pins |
| --- | --- |
| `packages/test-cases/src/cases.ts` | text morph corpus (`CASES`), verifiers over `segmentText`/`diffSegments` |
| `packages/test-cases/src/number-cases.ts` | number corpus (`NUMBER_CASES`), cursors, locales, decimals |
| `packages/test-cases/src/verify.ts`, `number-verify.ts` | verifier semantics (persistence, alignment, lateral shift, cycle stability) |
| `lib/text-morph/__tests__/engine.test.ts` | animation dispatch per kind, slot/mover split, slide distance per line, replacement runs, fades as shares, sizing, disabled, screen-reader node, reduced-motion toggle |
| `lib/text-morph/__tests__/options.test.ts` | `undefined` options fall back to defaults |
| `lib/utils/__tests__/container-size.test.ts` | resume-in-flight, elapsed accumulation, carry on moved target |
| `lib/utils/__tests__/easing.test.ts` | parser, slope, carry bounds, sampling density |
| `lib/text-morph/utils/__tests__/*.test.ts` | diff, number-segment, unique IDs, corpus integrity |

## Oracle

`oracle/` regenerates every fixture in `oracle/fixtures/*.json` from the pinned source (`npm run gen` inside `oracle/`). The fixtures are the semantic baseline; see `spec/PARITY.md`.
