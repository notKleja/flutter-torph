/// Pure-Dart stand-in for `Intl.Segmenter` with `granularity: "word"` and
/// `granularity: "grapheme"`, matching what V8 (ICU 78 / Unicode 17) yields.
///
/// Word segmentation follows ICU's own `word.txt` rule set (a copy lives in
/// tool/unicode/word.txt), which is UAX #29 with ICU's substitutions: CJK and
/// Kana are pulled out of `$ALetter` and chained as whole runs for the
/// dictionary breaker, and complex-context scripts (Thai, Lao, Khmer, Myanmar)
/// are pushed *into* the letter class so a whole run chains as one word. The
/// dictionary pass that ICU then applies to those runs is not reproduced; see
/// spec/SEGMENTER_KNOWN_GAPS.md.
library;

import 'dart:typed_data';

import 'package:characters/characters.dart';

import 'word_break_table.dart';

/// One segment of `Intl.Segmenter.prototype.segment` output.
class TextSegment {
  /// Creates a segment starting at UTF-16 offset [index].
  const TextSegment(this.index, this.segment, {this.isWordLike = false});

  /// UTF-16 offset of the segment in the input string, as JS reports it.
  final int index;

  /// The segment text.
  final String segment;

  /// ICU's rule status for the segment was not `UBRK_WORD_NONE`, i.e. the
  /// segment ends in a letter, number, kana or ideograph. Always false for
  /// grapheme segmentation, which is what `Intl.Segmenter` does.
  final bool isWordLike;

  @override
  bool operator ==(Object other) =>
      other is TextSegment &&
      other.index == index &&
      other.segment == segment &&
      other.isWordLike == isWordLike;

  @override
  int get hashCode => Object.hash(index, segment, isWordLike);

  @override
  String toString() =>
      'TextSegment($index, ${_quote(segment)}, isWordLike: $isWordLike)';
}

String _quote(String s) {
  final buf = StringBuffer('"');
  for (final rune in s.runes) {
    switch (rune) {
      case 0x0A:
        buf.write(r'\n');
      case 0x0D:
        buf.write(r'\r');
      case 0x09:
        buf.write(r'\t');
      case 0x22:
        buf.write(r'\"');
      default:
        if (rune < 0x20) {
          buf.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
        } else {
          buf.writeCharCode(rune);
        }
    }
  }
  return (buf..write('"')).toString();
}

/// Extended grapheme clusters (UAX #29), one segment each.
List<TextSegment> segmentGraphemes(String s) {
  if (s.isEmpty) return const <TextSegment>[];
  final out = <TextSegment>[];
  var index = 0;
  for (final cluster in s.characters) {
    out.add(TextSegment(index, cluster));
    index += cluster.length;
  }
  return out;
}

bool _isIgnorable(int cat) =>
    cat == catExtend || cat == catFormat || cat == catZWJ;

bool _isAHLetter(int cat) => cat == catALetterPlus || cat == catHebrewLetter;

/// Word segments, as `new Intl.Segmenter(locale, {granularity: "word"})` yields
/// them: every boundary-to-boundary run, punctuation and whitespace included.
List<TextSegment> segmentWords(String s) {
  final length = s.length;
  if (length == 0) return const <TextSegment>[];

  // Decode once: UTF-16 offset and packed word-break value per code point.
  final offsets = Int32List(length + 1);
  final values = Int32List(length);
  var count = 0;
  for (var i = 0; i < length;) {
    final unit = s.codeUnitAt(i);
    var cp = unit;
    var width = 1;
    if (unit >= 0xD800 && unit <= 0xDBFF && i + 1 < length) {
      final next = s.codeUnitAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        cp = 0x10000 + ((unit - 0xD800) << 10) + (next - 0xDC00);
        width = 2;
      }
    }
    offsets[count] = i;
    values[count] = wordBreakValue(cp);
    count++;
    i += width;
  }
  offsets[count] = length;

  final out = <TextSegment>[];
  var segmentStart = 0; // index into the code point arrays
  var prevBase = -1; // last non-ignorable code point index
  var prevPrevBase = -1;
  // Last base of the segment being built, and the base before it inside that
  // same segment: together they decide the ICU rule status (isWordLike).
  var segLastBase = -1;
  var segPrevBase = -1;
  var riRun = 0;
  if (!_isIgnorable(values[0] & catMask)) {
    prevBase = 0;
    segLastBase = 0;
    riRun = (values[0] & catMask) == catRegionalIndicator ? 1 : 0;
  }

  for (var k = 1; k < count; k++) {
    final prevCat = values[k - 1] & catMask;
    final curValue = values[k];
    final curCat = curValue & catMask;
    final shouldBreak = _breakBefore(values, count, prevCat, curValue, curCat,
        k, prevBase, prevPrevBase, riRun);

    if (!_isIgnorable(curCat)) {
      if (curCat == catRegionalIndicator) {
        riRun = !shouldBreak &&
                prevBase >= 0 &&
                (values[prevBase] & catMask) == catRegionalIndicator
            ? riRun + 1
            : 1;
      } else {
        riRun = 0;
      }
      prevPrevBase = prevBase;
      prevBase = k;
    }

    if (shouldBreak) {
      out.add(TextSegment(
        offsets[segmentStart],
        s.substring(offsets[segmentStart], offsets[k]),
        isWordLike: _wordLike(values, segLastBase, segPrevBase, k - 1),
      ));
      segmentStart = k;
      segLastBase = _isIgnorable(curCat) ? -1 : k;
      segPrevBase = -1;
    } else if (!_isIgnorable(curCat)) {
      segPrevBase = segLastBase;
      segLastBase = k;
    }
  }

  out.add(TextSegment(
    offsets[segmentStart],
    s.substring(offsets[segmentStart], length),
    isWordLike: _wordLike(values, segLastBase, segPrevBase, count - 1),
  ));
  return out;
}

/// ICU sets a segment's rule status from the last rule that matched, so the
/// answer hangs off the segment's final base character (trailing Extend, Format
/// and ZWJ keep the status of what they attach to, per rule 4):
///
///   * `$Numeric $ExFm* {100}`, `$ALetterPlus $ExFm* {200}`,
///     `$HangulSyllable {200}`, `$Hebrew_Letter $ExFm* {200}`,
///     `$Katakana/$Hiragana/$Ideographic $ExFm* {400}` -- word-like.
///   * `... $ExtendNumLet {100|200|400}` (13a) -- word-like, but only when the
///     ExtendNumLet actually chained onto something, so a lone "_" is not.
///   * `$Hebrew_Letter $ExFm* $Single_Quote {200}` (7a) -- word-like.
///   * everything else, including `$CR $LF`, `$ZWJ $Extended_Pict`,
///     `$WSegSpace $WSegSpace` and the regional-indicator pair, has no status,
///     which is why "x‍\u{1f600}" is *not* word-like even though it starts
///     with a letter.
bool _wordLike(
    Int32List values, int segLastBase, int segPrevBase, int segLastCp) {
  if (segLastBase < 0) return false;
  final value = values[segLastBase];
  // Only the single-character status rules carry a trailing `$ExFm*`, so those
  // keep their status through attached Extend/Format/ZWJ ("1\u20e3" is
  // word-like) while `$HangulSyllable {200}`, the 13a ExtendNumLet rules and
  // rule 7a do not: with anything attached, rule 4 (status-less) is the last
  // match and the segment stops being word-like.
  final endsInBase = segLastBase == segLastCp;
  if ((value & flagHangulSyllable) != 0) return endsInBase;
  if ((value & flagWordLike) != 0) return true;
  final cat = value & catMask;
  if (cat == catExtendNumLet) return endsInBase && segPrevBase >= 0;
  if (cat == catSingleQuote) {
    return endsInBase &&
        segPrevBase >= 0 &&
        (values[segPrevBase] & catMask) == catHebrewLetter;
  }
  return false;
}

/// The next non-ignorable category after code point [k], or -1 at end of text.
int _nextBaseCat(Int32List values, int count, int k) {
  for (var j = k + 1; j < count; j++) {
    final cat = values[j] & catMask;
    if (!_isIgnorable(cat)) return cat;
  }
  return -1;
}

bool _breakBefore(
  Int32List values,
  int count,
  int prevCat,
  int curValue,
  int curCat,
  int k,
  int prevBase,
  int prevPrevBase,
  int riRun,
) {
  // Rule 3: CR x LF.
  if (prevCat == catCR && curCat == catLF) return false;
  // Rules 3a/3b: always break around CR, LF and Newline otherwise.
  if (prevCat == catCR || prevCat == catLF || prevCat == catNewline) return true;
  if (curCat == catCR || curCat == catLF || curCat == catNewline) return true;
  // Rule 3c: ZWJ x Extended_Pictographic, before rule 4 so no intervening
  // Extend is allowed.
  if (prevCat == catZWJ && (curValue & flagExtendedPictographic) != 0) {
    return false;
  }
  // Rule 3d: keep horizontal whitespace together.
  if (prevCat == catWSegSpace && curCat == catWSegSpace) return false;
  // Rule 4: Extend, Format and ZWJ attach to what precedes them.
  if (_isIgnorable(curCat)) return false;
  // Leading ignorables form their own segment (ICU's `^$ExFm+`).
  if (prevBase < 0) return true;

  final prevValue = values[prevBase];
  final pb = prevValue & catMask;
  final ppb = prevPrevBase >= 0 ? values[prevPrevBase] & catMask : -1;
  final pAHL = _isAHLetter(pb);
  final cAHL = _isAHLetter(curCat);

  // Rule 5.
  if (pAHL && cAHL) return false;
  // Rules 6 and 7.
  if (pAHL &&
      (curCat == catMidLetter ||
          curCat == catMidNumLet ||
          curCat == catSingleQuote) &&
      _isAHLetter(_nextBaseCat(values, count, k))) {
    return false;
  }
  if ((pb == catMidLetter || pb == catMidNumLet || pb == catSingleQuote) &&
      _isAHLetter(ppb) &&
      cAHL) {
    return false;
  }
  // Rule 7a.
  if (pb == catHebrewLetter && curCat == catSingleQuote) return false;
  // Rules 7b and 7c.
  if (pb == catHebrewLetter &&
      curCat == catDoubleQuote &&
      _nextBaseCat(values, count, k) == catHebrewLetter) {
    return false;
  }
  if (pb == catDoubleQuote && ppb == catHebrewLetter && curCat == catHebrewLetter) {
    return false;
  }
  // Rule 8.
  if (pb == catNumeric && curCat == catNumeric) return false;
  // Rules 9 and 10.
  if (pAHL && curCat == catNumeric) return false;
  if (pb == catNumeric && cAHL) return false;
  // Rules 11 and 12.
  if ((pb == catMidNum || pb == catMidNumLet || pb == catSingleQuote) &&
      ppb == catNumeric &&
      curCat == catNumeric) {
    return false;
  }
  if (pb == catNumeric &&
      (curCat == catMidNum ||
          curCat == catMidNumLet ||
          curCat == catSingleQuote) &&
      _nextBaseCat(values, count, k) == catNumeric) {
    return false;
  }
  // Rule 13.
  if (pb == catKatakana && curCat == catKatakana) return false;
  // Rules 13a and 13b.
  if (curCat == catExtendNumLet &&
      (pAHL ||
          pb == catNumeric ||
          pb == catKatakana ||
          pb == catExtendNumLet)) {
    return false;
  }
  if (pb == catExtendNumLet &&
      (cAHL || curCat == catNumeric || curCat == catKatakana)) {
    return false;
  }
  // Rules 15-17: regional indicators pair up.
  if (pb == catRegionalIndicator &&
      curCat == catRegionalIndicator &&
      riRun.isOdd) {
    return false;
  }
  // ICU extras: chain CJK runs for the dictionary breaker. Unlike every rule
  // above, `$HangulSyllable $HangulSyllable` and `$KanaKanji $KanaKanji` carry
  // no `$ExFm*`, so they need real adjacency: ICU breaks "\uac00\u0301\uac01"
  // and "\u4e00\u0301\u4e00" even though it joins "\u30ab\u0301\u30ab"
  // through rule 13.
  if (prevBase == k - 1) {
    if ((prevValue & flagHangulSyllable) != 0 &&
        (curValue & flagHangulSyllable) != 0) {
      return false;
    }
    if ((prevValue & flagKanaKanji) != 0 && (curValue & flagKanaKanji) != 0) {
      return false;
    }
  }
  // Rule 999.
  return true;
}
