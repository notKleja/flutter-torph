// Generates lib/src/core/word_break_table.dart from the UCD files kept in
// tool/unicode/. Run from the package root:
//
//   dart run tool/gen_word_break_table.dart
//
// The table encodes, per code point, the ICU `word.txt` character classes
// (see tool/unicode/word.txt) rather than the stock UAX #29 classes:
//
//   * $Extend       = Word_Break=Extend minus Script=Han
//   * $ALetterPlus  = (Word_Break=ALetter minus $dictionaryCJK)
//                     union (LineBreak=SA minus $Extend minus GCB=Control)
//   * $dictionaryCJK = Script=Han/Hiragana/Katakana union U+AC00..U+D7A3
//
// plus the flags the rules and the ICU rule-status (isWordLike) need.
import 'dart:io';

const int catOther = 0;
const int catCR = 1;
const int catLF = 2;
const int catNewline = 3;
const int catExtend = 4;
const int catFormat = 5;
const int catZWJ = 6;
const int catRegionalIndicator = 7;
const int catWSegSpace = 8;
const int catKatakana = 9;
const int catHebrewLetter = 10;
const int catALetterPlus = 11;
const int catNumeric = 12;
const int catExtendNumLet = 13;
const int catSingleQuote = 14;
const int catDoubleQuote = 15;
const int catMidLetter = 16;
const int catMidNumLet = 17;
const int catMidNum = 18;

const int flagKanaKanji = 1 << 5;
const int flagHangulSyllable = 1 << 6;
const int flagWordLike = 1 << 7;
const int flagExtendedPictographic = 1 << 8;

const int maxCodePoint = 0x10FFFF;

const String unicodeVersion = '17.0.0';

/// Parses a UCD file of `range ; value` lines into `value -> set of code points`
/// via a callback per (start, end, value).
void parseUcd(String path, void Function(int start, int end, String value) emit) {
  for (var line in File(path).readAsLinesSync()) {
    final hash = line.indexOf('#');
    if (hash >= 0) line = line.substring(0, hash);
    line = line.trim();
    if (line.isEmpty) continue;
    final parts = line.split(';');
    if (parts.length < 2) continue;
    final range = parts[0].trim();
    final value = parts[1].trim();
    final dots = range.indexOf('..');
    final int start;
    final int end;
    if (dots >= 0) {
      start = int.parse(range.substring(0, dots), radix: 16);
      end = int.parse(range.substring(dots + 2), radix: 16);
    } else {
      start = int.parse(range, radix: 16);
      end = start;
    }
    emit(start, end, value);
  }
}

List<String?> loadProperty(String path, {Set<String>? keep}) {
  final out = List<String?>.filled(maxCodePoint + 1, null);
  parseUcd(path, (start, end, value) {
    if (keep != null && !keep.contains(value)) return;
    for (var cp = start; cp <= end; cp++) {
      out[cp] = value;
    }
  });
  return out;
}

List<bool> loadBinary(String path, String property) {
  final out = List<bool>.filled(maxCodePoint + 1, false);
  parseUcd(path, (start, end, value) {
    if (value != property) return;
    for (var cp = start; cp <= end; cp++) {
      out[cp] = true;
    }
  });
  return out;
}

void main() {
  final dir = 'tool/unicode';
  final wb = loadProperty('$dir/WordBreakProperty.txt');
  final script = loadProperty('$dir/Scripts.txt',
      keep: {'Han', 'Hiragana', 'Katakana'});
  final lineBreak = loadProperty('$dir/LineBreak.txt', keep: {'SA'});
  final gcbControl = loadBinary('$dir/GraphemeBreakProperty.txt', 'Control');
  final ideographic = loadBinary('$dir/PropList.txt', 'Ideographic');
  final pictographic = loadBinary('$dir/emoji-data.txt', 'Extended_Pictographic');

  final values = List<int>.filled(maxCodePoint + 1, 0);
  for (var cp = 0; cp <= maxCodePoint; cp++) {
    final w = wb[cp];
    final scr = script[cp];
    final isHan = scr == 'Han';
    final isHiragana = scr == 'Hiragana';
    final isKatakanaScript = scr == 'Katakana';
    final isHangulSyllable = cp >= 0xAC00 && cp <= 0xD7A3;
    final isDictCJK =
        isHan || isHiragana || isKatakanaScript || isHangulSyllable;
    final isComplexContext = lineBreak[cp] == 'SA';

    // $Extend = [\p{Word_Break = Extend} - $Han]
    final isExtend = w == 'Extend' && !isHan;
    // $ALetterPlus = [$ALetter-$dictionaryCJK [$ComplexContext-$Extend-$Control]]
    final isALetterPlus = (w == 'ALetter' && !isDictCJK) ||
        (isComplexContext && !isExtend && !gcbControl[cp]);

    int cat;
    switch (w) {
      case 'CR':
        cat = catCR;
      case 'LF':
        cat = catLF;
      case 'Newline':
        cat = catNewline;
      case 'ZWJ':
        cat = catZWJ;
      case 'Regional_Indicator':
        cat = catRegionalIndicator;
      case 'WSegSpace':
        cat = catWSegSpace;
      case 'Katakana':
        cat = catKatakana;
      case 'Hebrew_Letter':
        cat = catHebrewLetter;
      case 'Numeric':
        cat = catNumeric;
      case 'ExtendNumLet':
        cat = catExtendNumLet;
      case 'Single_Quote':
        cat = catSingleQuote;
      case 'Double_Quote':
        cat = catDoubleQuote;
      case 'MidLetter':
        cat = catMidLetter;
      case 'MidNumLet':
        cat = catMidNumLet;
      case 'MidNum':
        cat = catMidNum;
      case 'Format':
        cat = catFormat;
      default:
        cat = catOther;
    }
    if (isExtend) {
      cat = catExtend;
    } else if (cat == catOther && isALetterPlus) {
      cat = catALetterPlus;
    } else if (cat == catFormat && isALetterPlus) {
      // No such code point exists today; ICU's longest-match would prefer the
      // letter class, so mirror that if one ever appears.
      cat = catALetterPlus;
    }

    // ICU rule status: {100} Numeric, {200} ALetterPlus/HangulSyllable/
    // Hebrew_Letter, {400} Katakana/Hiragana/Ideographic. V8 reports
    // isWordLike = status != UBRK_WORD_NONE, so any of them counts.
    final wordLike = cat == catNumeric ||
        cat == catALetterPlus ||
        cat == catHebrewLetter ||
        cat == catKatakana ||
        isHangulSyllable ||
        isHiragana ||
        ideographic[cp];

    var v = cat;
    if (isHan || isHiragana || isKatakanaScript) v |= flagKanaKanji;
    if (isHangulSyllable) v |= flagHangulSyllable;
    if (wordLike) v |= flagWordLike;
    if (pictographic[cp]) v |= flagExtendedPictographic;
    values[cp] = v;
  }

  // Contiguous partition of the whole code space: one start per run.
  final starts = <int>[0];
  final vals = <int>[values[0]];
  for (var cp = 1; cp <= maxCodePoint; cp++) {
    if (values[cp] != vals.last) {
      starts.add(cp);
      vals.add(values[cp]);
    }
  }

  final buf = StringBuffer()
    ..writeln('// GENERATED FILE -- do not edit by hand.')
    ..writeln('// Generated by tool/gen_word_break_table.dart from the UCD')
    ..writeln('// files in tool/unicode/ (Unicode $unicodeVersion) and the ICU')
    ..writeln('// word break rules in tool/unicode/word.txt.')
    ..writeln('//')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln("/// The Unicode version the table was generated from.")
    ..writeln("const String unicodeVersion = '$unicodeVersion';")
    ..writeln();

  void constant(String name, int value, String doc) {
    buf
      ..writeln('/// $doc')
      ..writeln('const int $name = $value;');
  }

  constant('catOther', catOther, 'Word_Break=Other (ICU rule 999 fallback).');
  constant('catCR', catCR, 'Word_Break=CR.');
  constant('catLF', catLF, 'Word_Break=LF.');
  constant('catNewline', catNewline, 'Word_Break=Newline.');
  constant('catExtend', catExtend, r'ICU $Extend (Word_Break=Extend minus Han).');
  constant('catFormat', catFormat, 'Word_Break=Format.');
  constant('catZWJ', catZWJ, 'Word_Break=ZWJ.');
  constant('catRegionalIndicator', catRegionalIndicator,
      'Word_Break=Regional_Indicator.');
  constant('catWSegSpace', catWSegSpace, 'Word_Break=WSegSpace.');
  constant('catKatakana', catKatakana, 'Word_Break=Katakana.');
  constant('catHebrewLetter', catHebrewLetter, 'Word_Break=Hebrew_Letter.');
  constant('catALetterPlus', catALetterPlus, r'ICU $ALetterPlus.');
  constant('catNumeric', catNumeric, 'Word_Break=Numeric.');
  constant('catExtendNumLet', catExtendNumLet, 'Word_Break=ExtendNumLet.');
  constant('catSingleQuote', catSingleQuote, 'Word_Break=Single_Quote.');
  constant('catDoubleQuote', catDoubleQuote, 'Word_Break=Double_Quote.');
  constant('catMidLetter', catMidLetter, 'Word_Break=MidLetter.');
  constant('catMidNumLet', catMidNumLet, 'Word_Break=MidNumLet.');
  constant('catMidNum', catMidNum, 'Word_Break=MidNum.');
  buf.writeln();
  constant('catMask', 0x1F, 'Mask isolating the category from a table value.');
  constant('flagKanaKanji', flagKanaKanji,
      r'Script is Han, Hiragana or Katakana (ICU $KanaKanji).');
  constant('flagHangulSyllable', flagHangulSyllable,
      r'U+AC00..U+D7A3 (ICU $HangulSyllable).');
  constant('flagWordLike', flagWordLike,
      'Carries a non-zero ICU rule status, i.e. makes a segment word-like.');
  constant('flagExtendedPictographic', flagExtendedPictographic,
      'Extended_Pictographic.');
  buf.writeln();

  void writeList(String name, List<int> list, String doc) {
    buf
      ..writeln('/// $doc')
      ..writeln('const List<int> $name = <int>[');
    for (var i = 0; i < list.length; i += 16) {
      final chunk = list.sublist(i, i + 16 > list.length ? list.length : i + 16);
      buf.writeln('  ${chunk.join(', ')},');
    }
    buf.writeln('];');
    buf.writeln();
  }

  writeList('wordBreakRangeStart', starts,
      'First code point of each run; a contiguous partition of U+0000..U+10FFFF.');
  writeList('wordBreakRangeValue', vals,
      'Packed category plus flags for the run starting at the same index.');

  buf
    ..writeln('/// Packed category and flags for [codePoint].')
    ..writeln('int wordBreakValue(int codePoint) {')
    ..writeln('  var lo = 0;')
    ..writeln('  var hi = wordBreakRangeStart.length - 1;')
    ..writeln('  while (lo < hi) {')
    ..writeln('    final mid = (lo + hi + 1) >> 1;')
    ..writeln('    if (wordBreakRangeStart[mid] <= codePoint) {')
    ..writeln('      lo = mid;')
    ..writeln('    } else {')
    ..writeln('      hi = mid - 1;')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln('  return wordBreakRangeValue[lo];')
    ..writeln('}');

  File('lib/src/core/word_break_table.dart').writeAsStringSync(buf.toString());
  stdout.writeln('wrote lib/src/core/word_break_table.dart '
      '(${starts.length} ranges, Unicode $unicodeVersion)');
}
