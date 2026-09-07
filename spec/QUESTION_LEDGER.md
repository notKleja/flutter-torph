# Question ledger

Format: `Q-### question / files / interpretation / tests / runtime experiment / conclusion / confidence / parity requirement`.

## Q-001 Which Unicode segmentation does `Intl.Segmenter` word granularity apply?
- Files: segment.ts:132. Runtime: Node 26.7 / ICU 78.3 (oracle/fixtures/segmenter.json).
- Interpretation: ICU word break (UAX#29 + ICU rule customisations; dictionary breaking for CJK/Thai/Khmer/Lao/Burmese).
- Conclusion: port UAX#29 word rules in pure Dart, validated against the fixture corpus; dictionary languages tracked as a candidate deviation. Confidence: high for non-dictionary scripts.
- Parity: SEG-002.

## Q-002 Does the character-level diff use graphemes or UTF-16 units?
- Files: diff.ts:40 (`word.split("")`), diff.ts:66, diff.ts:299, number.ts:100.
- Conclusion: UTF-16 code units everywhere after initial segmentation. Dart `split('')` matches. Confidence: certain. Parity: DIFF-006, SEG-005.

## Q-003 Does the root wrap?
- Files: styles.ts:15 (`white-space: nowrap`), index.ts:237 comment.
- Conclusion: never; only `<br>` breaks lines. Parity: LINES-001.

## Q-004 What does the first-frame measurement at the old width change?
- Files: index.ts:244-248. With `text-align: left` nothing; with center/right, shorter/longer lines shift relative to the old width, which is what persisting items are FLIPped against.
- Conclusion: port alignment-aware measurement at the old width. Parity: CONTAINER-007. Runtime confirmation requested from A2 (browser oracle, center alignment).

## Q-005 What is the underlying opacity of an exiting element?
- Files: dom.ts:90 (`style.opacity = snapshot`), animate.ts:29 (`opacity: 0, offset: 1`).
- Conclusion: the fade runs from the snapshot opacity to 0. Parity: INTERRUPT-003.

## Q-006 What happens to `scale` when a persisting item is interrupted?
- Files: animate.ts:56-66: only translate is read back; the new animation starts at scale(0.95 if new else 1). A mid-enter item (scale ~0.97) snaps to 1 on the next persist.
- Conclusion: reproduce the snap (do not "improve"). Parity: INTERRUPT-002.

## Q-007 Does `onAnimationComplete` fire for the initial render?
- Files: index.ts:298-303 — initial render returns before the container transition; no callbacks. Confidence: certain. Parity: CALLBACK-001/002.

## Q-008 `findNearestAnchor` for arrivals: index in `segments` vs DOM order?
- Files: index.ts:373-378 uses `segments.findIndex(id)` and `segmentIds`; DOM order equals segment order after reconcile (SR node excluded). Conclusion: same. Parity: FLIP-003.

## Q-009 Group exit runs: are previously-exiting children counted in `oldChildren`?
- Files: index.ts:212 (`oldChildren` = all non-SR children including exiting), index.ts:256 (`replacedRuns(oldChildren, new Set(exiting))`). A still-exiting element between two new exits breaks the run (it is not a member).
- Conclusion: port as-is. Parity: REPLACE-001.

## Q-010 Height of the container/line box in Flutter?
- Upstream: line box from CSS line-height (normal) of the root font. Flutter: `TextPainter.preferredLineHeight` of the style. Kinematic parity is normalised per platform; see DEVIATIONS candidate.

## Q-011 Is `Intl.Segmenter` locale-sensitive for word breaks in practice?
- ICU word break rules are locale-independent except for dictionary languages. Fixtures generated with "en"; the Dart port ignores locale for word breaks. Parity: SEG-002. Open for A2 to confirm with de/ja fixtures.

## Q-012 WAAPI: what does a later `element.animate` on the same property do to an earlier one?
- Spec: composite "replace" — the later animation's effect wins while both are active; the earlier keeps running underneath (and its `onfinish` still fires). Upstream always cancels first except: exit (after detach's cancel), group exit (explicit cancel).
- `detachFromFlow` cancels `child.getAnimations()` — per spec this returns only the element's own animations, NOT the nested mover's. So a mover mid-enter (opacity 0.3, translateY 5px) that starts exiting keeps its enter animations running under the new exit animations: the new mover transform (`offset: 1`, slide down) replaces the enter transform immediately (jump from 5px to 0 then slide); the new opacity (`offset: 1` → 0) starts from the *underlying* value (1), not 0.3 — a jump to opaque. RUNTIME EXPERIMENT REQUIRED (A2). Parity: INTERRUPT-003 (number variant).
