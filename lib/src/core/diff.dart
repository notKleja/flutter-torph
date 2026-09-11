import 'joining.dart';
import 'lcs.dart';
import 'number.dart';
import 'segment.dart';
import 'segmenter.dart';

class DiffResult {
  const DiffResult(this.segments, this.splits);

  final List<Segment> segments;

  /// Old single-span words cut into per-character segments before measuring.
  final Map<String, List<Segment>> splits;
}

class DiffOptions {
  const DiffOptions({this.numbers = true, this.cursorIndex});

  /// Numeric words morph by place value. Off falls back to character LCS.
  final bool numbers;

  /// Caret position, honoured only when the value holds a single number.
  final int? cursorIndex;
}

// Numbers share too few characters to pair with each other, so they all
// collapse to one token.
const String _numberToken = '\u0000#';

/// Per-character segments of an old word, cutting it up first if it is still
/// one span: code units for numbers, grapheme clusters for text (DEV-007).
List<Segment> _splitIfWhole(
  WordGroup oldGroup,
  Map<String, List<Segment>> splits,
  List<String> Function(String) units,
) {
  final parts = units(oldGroup.word);
  // Cutting a one-character word mints a new ID for a character that never moved.
  if (oldGroup.segments.length != 1 || parts.length <= 1) {
    return oldGroup.segments;
  }

  final wordSeg = oldGroup.segments[0];
  final charSegs = <Segment>[];
  for (var i = 0; i < parts.length; i++) {
    charSegs.add(Segment('${wordSeg.id}:$i', parts[i]));
  }
  splits[wordSeg.id] = charSegs;
  return charSegs;
}

/// Fills in kinds an older, non-numeric segmentation of the same word lacked.
List<Segment> _asNumberSegments(List<Segment> segments) => segments
    .map(
      (seg) => seg.kind != null
          ? seg
          : Segment(seg.id, seg.string, kind: classifyKind(seg.string)),
    )
    .toList();

enum _Mode { fresh, reuse, morph, number }

class _WordPlan {
  const _WordPlan(this.mode, [this.oi = -1]);

  final _Mode mode;
  final int oi;
}

double _charSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final au = graphemeClusters(a);
  final bu = graphemeClusters(b);
  final (matched, _) = lcsIndices(au, bu);
  return matched.length / (au.length > bu.length ? au.length : bu.length);
}

/// How many LCS matches sit before each word — the index of the gap it occupies.
List<int> _gapIndices(int count, Set<int> matched) {
  final gaps = <int>[];
  var anchors = 0;
  for (var i = 0; i < count; i++) {
    gaps.add(anchors);
    if (matched.contains(i)) anchors++;
  }
  return gaps;
}

const double minSimilarity = 0.4;

/// An old word's claim on a new one. A matching numeric skeleton beats shared
/// characters.
double _pairAffinity(String a, String b) {
  if (isAtomicWord(a) || isAtomicWord(b)) return 0;
  if ((hasDigit(a) || hasDigit(b)) &&
      numericSkeleton(a) == numericSkeleton(b)) {
    return 1;
  }
  return _charSimilarity(a, b);
}

// The diff runs before the first frame, so past these it degrades rather than blocks.
const int maxMorphPairings = 2500;
const int maxLcsCells = 1000000;

/// Matches [newText] against [oldSegments] so persisting text keeps its ids.
DiffResult diffSegments(
  List<Segment> oldSegments,
  String newText,
  String locale, [
  DiffOptions options = const DiffOptions(),
]) {
  final newHasSpaces = newText.contains(' ');
  final newHasNewlines = newText.contains('\n');
  final oldWords = groupIntoWords(oldSegments);

  final numbersOn = options.numbers;
  bool isNum(String word) => numbersOn && isNumericWord(word);
  String token(String word) => isNum(word) ? _numberToken : word;

  // Text IDs are derived from the text and survive re-segmentation; minted
  // numeric IDs don't.
  final digitsInvolved =
      numbersOn && (hasDigit(newText) || oldWords.any((g) => hasDigit(g.word)));

  if (oldWords.length <= 1 &&
      !newHasSpaces &&
      !newHasNewlines &&
      !digitsInvolved) {
    return DiffResult(segmentText(newText, locale, numbers: numbersOn), {});
  }

  final newWordStrings = <String>[];
  final newSeparators = <List<String>>[]; // separators BEFORE each word
  var pendingSeps = <String>[];
  for (final part in _splitKeepingSeparators(newText)) {
    if (part == ' ' || part == '\n') {
      pendingSeps.add(part);
    } else if (part.isNotEmpty) {
      newSeparators.add(pendingSeps);
      newWordStrings.add(part);
      pendingSeps = <String>[];
    }
  }
  final trailingSeparators = pendingSeps;

  final oldWordStrings = oldWords.map((g) => g.word).toList();

  if (oldWordStrings.length * newWordStrings.length > maxLcsCells) {
    return DiffResult(segmentText(newText, locale, numbers: numbersOn), {});
  }

  final (oldLcsIdx, newLcsIdx) = lcsIndices(
    oldWordStrings.map(token).toList(),
    newWordStrings.map(token).toList(),
  );
  final oldMatchedSet = oldLcsIdx.toSet();
  final newMatchedSet = newLcsIdx.toSet();

  final newToOldWord = <int, int>{};
  for (var k = 0; k < newLcsIdx.length; k++) {
    newToOldWord[newLcsIdx[k]] = oldLcsIdx[k];
  }

  var oldUnmatched = [
    for (var i = 0; i < oldWordStrings.length; i++)
      if (!oldMatchedSet.contains(i)) i,
  ];
  var newUnmatched = [
    for (var i = 0; i < newWordStrings.length; i++)
      if (!newMatchedSet.contains(i)) i,
  ];

  // Exact-match reordered words that LCS couldn't capture (order-preserving)
  final exactUsed = <int>{};
  for (final ni in newUnmatched) {
    for (final oi in oldUnmatched) {
      if (exactUsed.contains(oi)) continue;
      if (token(newWordStrings[ni]) == token(oldWordStrings[oi])) {
        newToOldWord[ni] = oi;
        exactUsed.add(oi);
        break;
      }
    }
  }
  if (exactUsed.isNotEmpty) {
    oldUnmatched = oldUnmatched.where((i) => !exactUsed.contains(i)).toList();
    newUnmatched = newUnmatched
        .where((i) => !newToOldWord.containsKey(i))
        .toList();
  }

  final morphPairs = <int, int>{};
  final usedOld = <int>{};

  // From the LCS alone: the exact-match pass reorders, so its pairs anchor nothing.
  final oldGaps = _gapIndices(oldWordStrings.length, oldMatchedSet);
  final newGaps = _gapIndices(newWordStrings.length, newMatchedSet);

  if (oldUnmatched.length * newUnmatched.length <= maxMorphPairings) {
    for (final ni in newUnmatched) {
      var bestOi = -1;
      var bestSim = minSimilarity;

      for (final oi in oldUnmatched) {
        if (usedOld.contains(oi)) continue;
        // A pairing that crosses a surviving word drags its characters the width of the value.
        if (oldGaps[oi] != newGaps[ni]) continue;
        final sim = _pairAffinity(oldWordStrings[oi], newWordStrings[ni]);
        if (sim > bestSim) {
          bestSim = sim;
          bestOi = oi;
        }
      }

      if (bestOi >= 0) {
        morphPairs[ni] = bestOi;
        usedOld.add(bestOi);
      }
    }
  }

  // Keyed on what the word is becoming, not on what it was.
  final plans = <_WordPlan>[];
  for (var ni = 0; ni < newWordStrings.length; ni++) {
    final newWord = newWordStrings[ni];
    final lcsOi = newToOldWord[ni];
    final oi = lcsOi ?? morphPairs[ni];
    if (oi == null) {
      plans.add(const _WordPlan(_Mode.fresh));
    } else if (isNum(newWord)) {
      plans.add(_WordPlan(_Mode.number, oi));
    } else {
      plans.add(_WordPlan(lcsOi != null ? _Mode.reuse : _Mode.morph, oi));
    }
  }

  // Meaningless once a value holds several figures.
  final cursorIndex =
      plans.where((plan) => plan.mode == _Mode.number).length == 1
      ? options.cursorIndex
      : null;
  final decimalChar = decimalSeparator(locale);

  final alloc = IdAllocator();

  // Reserved up front: an ID inherited later would otherwise go to an earlier segment.
  for (final plan in plans) {
    if (plan.mode == _Mode.fresh) continue;
    final oldGroup = oldWords[plan.oi];

    if (plan.mode != _Mode.reuse && oldGroup.segments.length == 1) {
      // About to be split into per-character spans
      final wordSeg = oldGroup.segments[0];
      final partCount = plan.mode == _Mode.morph
          ? graphemeClusters(oldGroup.word).length
          : oldGroup.word.length;
      for (var i = 0; i < partCount; i++) {
        alloc.reserve('${wordSeg.id}:$i');
      }
    } else {
      for (final seg in oldGroup.segments) {
        alloc.reserve(seg.id);
      }
    }
  }

  final segments = <Segment>[];
  final splits = <String, List<Segment>>{};
  var charOffset = 0;

  // Includes the edges — segmentText keeps leading and trailing whitespace on first render.
  void pushSeparators(List<String> seps) {
    for (final sep in seps) {
      if (sep == '\n') {
        segments.add(Segment(alloc.take('newline-$charOffset'), '\n'));
      } else {
        segments.add(Segment(alloc.take('space-$charOffset'), nbsp));
      }
      charOffset++;
    }
  }

  for (var ni = 0; ni < newWordStrings.length; ni++) {
    pushSeparators(
      ni < newSeparators.length ? newSeparators[ni] : (ni > 0 ? [' '] : []),
    );

    final plan = plans[ni];
    final newWord = newWordStrings[ni];

    switch (plan.mode) {
      case _Mode.reuse:
        segments.addAll(oldWords[plan.oi].segments);
      case _Mode.number:
        final oldGroup = oldWords[plan.oi];
        segments.addAll(
          segmentNumber(
            newWord,
            _asNumberSegments(_splitIfWhole(oldGroup, splits, codeUnits)),
            cursorIndex == null ? null : cursorIndex - charOffset,
            decimalChar,
          ),
        );
      case _Mode.morph:
        final oldGroup = oldWords[plan.oi];
        final oldCharSegs = _splitIfWhole(oldGroup, splits, graphemeClusters);

        final oldChars = graphemeClusters(oldGroup.word);
        final newChars = graphemeClusters(newWord);
        final (oldCharLcs, newCharLcs) = lcsIndices(oldChars, newChars);

        final newCharToOldSeg = <int, Segment>{};
        for (var k = 0; k < newCharLcs.length; k++) {
          final idx = oldCharLcs[k];
          if (idx < oldCharSegs.length) {
            newCharToOldSeg[newCharLcs[k]] = oldCharSegs[idx];
          }
        }

        for (var ci = 0; ci < newChars.length; ci++) {
          final oldSeg = newCharToOldSeg[ci];
          if (oldSeg != null) {
            segments.add(Segment(oldSeg.id, newChars[ci]));
          } else {
            segments.add(Segment(alloc.take('$newWord~$ci'), newChars[ci]));
          }
        }
      case _Mode.fresh:
        if (isNum(newWord)) {
          segments.addAll(segmentNumber(newWord));
        } else {
          segments.add(Segment(alloc.take(newWord), newWord));
        }
    }

    charOffset += newWord.length;
  }

  pushSeparators(trailingSeparators);

  return DiffResult(segments, splits);
}

/// `newText.split(/( |\n)/)` — separators are kept as their own parts.
List<String> _splitKeepingSeparators(String text) {
  final parts = <String>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 0x20 || c == 0x0a) {
      parts.add(text.substring(start, i));
      parts.add(text[i]);
      start = i + 1;
    }
  }
  parts.add(text.substring(start));
  return parts;
}
