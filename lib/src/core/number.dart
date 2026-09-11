import 'package:intl/intl.dart' as intl;

import 'lcs.dart';
import 'segment.dart';

/// A segment that came out of [segmentNumber] and so always carries a kind.
class NumberSegment extends Segment {
  const NumberSegment(super.id, super.string, {required SegmentKind kind})
    : super(kind: kind);

  @override
  SegmentKind get kind => super.kind!;
}

// Numeric and text IDs share a namespace. A NULL prefix cannot occur in a
// text-derived ID, and the counter only climbs, so neither can collide with
// the other.
const String mintedPrefix = '\u0000n';
int _nextNewId = 0;

String mintId() => '$mintedPrefix${_nextNewId++}';

/// Test hook: the upstream counter is process-global; fixtures compare minted
/// IDs up to renaming, but a fresh counter keeps chains readable.
void debugResetMintedIds() => _nextNewId = 0;

bool isDigit(String char) =>
    char.length == 1 &&
    char.codeUnitAt(0) >= 0x30 &&
    char.codeUnitAt(0) <= 0x39;

bool _isDigitUnit(int unit) => unit >= 0x30 && unit <= 0x39;

bool hasDigit(String value) {
  for (var i = 0; i < value.length; i++) {
    if (_isDigitUnit(value.codeUnitAt(i))) return true;
  }
  return false;
}

/// What is left of a token once its digits and separators go — "$", "%", "()".
String numericSkeleton(String word) {
  final out = StringBuffer();
  for (var i = 0; i < word.length; i++) {
    final char = word[i];
    if (!isDigit(char) && !coreSeparators.contains(char)) out.write(char);
  }
  return out.toString();
}

/// Separators that can appear *between* digits without ending the number.
const String coreSeparators = ".,'    ";
const String _prefixChars = '+-−(#';
const String _suffixChars = '%.,!?:;)"\'”’';

// `/\p{Sc}/u` tested against one UTF-16 code unit: only BMP currency symbols
// can match, a lone surrogate never does. Unicode 17 set.
const Set<int> _currencyUnits = {
  0x24, 0xa2, 0xa3, 0xa4, 0xa5, 0x58f, 0x60b, 0x7fe, 0x7ff, 0x9f2, 0x9f3, //
  0x9fb, 0xaf1, 0xbf9, 0xe3f, 0x17db, 0x20a0, 0x20a1, 0x20a2, 0x20a3, 0x20a4,
  0x20a5, 0x20a6, 0x20a7, 0x20a8, 0x20a9, 0x20aa, 0x20ab, 0x20ac, 0x20ad,
  0x20ae, 0x20af, 0x20b0, 0x20b1, 0x20b2, 0x20b3, 0x20b4, 0x20b5, 0x20b6,
  0x20b7, 0x20b8, 0x20b9, 0x20ba, 0x20bb, 0x20bc, 0x20bd, 0x20be, 0x20bf,
  0x20c0, 0x20c1, 0xa838, 0xfdfc, 0xfe69, 0xff04, 0xffe0, 0xffe1, 0xffe5,
  0xffe6,
};

bool _isAffix(String char, String set) =>
    set.contains(char) || _currencyUnits.contains(char.codeUnitAt(0));

/// Whether a token is a quantity. Strict on purpose, and on by default: merely
/// containing a digit is not enough, or "COVID-19" and "2024-01-01" morph by
/// place.
bool isNumericWord(String word) {
  var start = 0;
  var end = word.length;

  while (start < end && _isAffix(word[start], _prefixChars)) {
    start++;
  }
  while (end > start && _isAffix(word[end - 1], _suffixChars)) {
    end--;
  }

  if (start >= end) return false;
  if (!isDigit(word[start]) || !isDigit(word[end - 1])) return false;

  for (var i = start; i < end; i++) {
    final char = word[i];
    if (!isDigit(char) && !coreSeparators.contains(char)) return false;
  }
  return true;
}

SegmentKind classifyKind(String char) =>
    isDigit(char) ? SegmentKind.digit : SegmentKind.symbol;

final Map<String, String> _separators = {};

/// The locale's decimal separator — the pivot every alignment is measured from.
String decimalSeparator(String locale) {
  final cached = _separators[locale];
  if (cached != null) return cached;

  var separator = '.';
  try {
    separator = intl.NumberFormat(
      null,
      canonicalLocale(locale),
    ).symbols.DECIMAL_SEP;
  } catch (_) {
    // Invalid or unsupported locale tag: upstream falls back the same way.
  }
  _separators[locale] = separator;
  return separator;
}

/// BCP 47 → the underscore form package:intl expects.
String canonicalLocale(String locale) => intl.Intl.canonicalizedLocale(locale);

/// `value.toLocaleString(locale, {minimumFractionDigits: decimals,
/// maximumFractionDigits: decimals})`.
String formatNumber(num value, String locale, int? decimals) {
  intl.NumberFormat format;
  try {
    format = intl.NumberFormat.decimalPattern(canonicalLocale(locale));
  } catch (_) {
    format = intl.NumberFormat.decimalPattern('en');
  }
  if (decimals != null) {
    format.minimumFractionDigits = decimals;
    format.maximumFractionDigits = decimals;
  }
  return format.format(value);
}

/// Per-character segments of the numeric word [value], carrying ids over from
/// [prevSegments] by caret when [cursorIndex] is given, else by place value.
List<NumberSegment> segmentNumber(
  String value, [
  List<Segment>? prevSegments,
  int? cursorIndex,
  String decimalChar = '.',
]) {
  final chars = codeUnits(value);

  if (prevSegments == null || prevSegments.isEmpty) {
    return _simpleSegment(chars);
  }

  final oldChars = prevSegments
      .map((s) => s.string == nbsp ? ' ' : s.string)
      .toList(growable: false);

  final matches = cursorIndex != null
      ? _cursorMatch(oldChars, chars, cursorIndex, decimalChar)
      : _placeMatch(oldChars, chars, decimalChar);

  final usedIds = <String>{};
  for (final oldIdx in matches.values) {
    usedIds.add(prevSegments[oldIdx].id);
  }

  final result = <NumberSegment>[];
  for (var i = 0; i < chars.length; i++) {
    final char = chars[i];
    final kind = classifyKind(char);
    final displayChar = char == ' ' ? nbsp : char;

    final oldIdx = matches[i];
    if (oldIdx != null) {
      result.add(
        NumberSegment(prevSegments[oldIdx].id, displayChar, kind: kind),
      );
    } else {
      var id = mintId();
      while (usedIds.contains(id)) {
        id = mintId();
      }
      usedIds.add(id);
      result.add(NumberSegment(id, displayChar, kind: kind));
    }
  }
  return result;
}

/// Fresh segmentation for a number with nothing to carry over from.
List<NumberSegment> _simpleSegment(List<String> chars) => chars
    .map(
      (char) => NumberSegment(
        mintId(),
        char == ' ' ? nbsp : char,
        kind: classifyKind(char),
      ),
    )
    .toList();

/// The caret in the new string says where the edit was; both sides of it map
/// across. The walk is over everything *but* the grouping separators.
Map<int, int> _cursorMatch(
  List<String> oldChars,
  List<String> newChars,
  int cursor,
  String decimalChar,
) {
  final matches = <int, int>{};

  final oldKept = _keptIndices(oldChars, decimalChar);
  final newKept = _keptIndices(newChars, decimalChar);
  void pair(int ni, int oi) => matches[newKept[ni]] = oldKept[oi];

  var keptCursor = 0;
  while (keptCursor < newKept.length && newKept[keptCursor] < cursor) {
    keptCursor++;
  }

  final lenDiff = newKept.length - oldKept.length;

  if (lenDiff > 0) {
    final editStart = keptCursor - lenDiff;
    for (var i = 0; i < editStart && i < oldKept.length; i++) {
      pair(i, i);
    }
    for (var i = keptCursor; i < newKept.length; i++) {
      final oldIdx = i - lenDiff;
      if (oldIdx >= 0 && oldIdx < oldKept.length) pair(i, oldIdx);
    }
  } else if (lenDiff < 0) {
    for (var i = 0; i < keptCursor && i < newKept.length; i++) {
      pair(i, i);
    }
    for (var i = keptCursor; i < newKept.length; i++) {
      final oldIdx = i - lenDiff;
      if (oldIdx >= 0 && oldIdx < oldKept.length) pair(i, oldIdx);
    }
  } else {
    for (var i = 0; i < newKept.length; i++) {
      if (newChars[newKept[i]] == oldChars[oldKept[i]]) pair(i, i);
    }
  }

  // Paired from the units end, so the thousands comma stays the thousands comma.
  final oldSeps = _groupingIndices(oldChars, decimalChar);
  final newSeps = _groupingIndices(newChars, decimalChar);
  for (var k = 1; k <= oldSeps.length && k <= newSeps.length; k++) {
    final oldIdx = oldSeps[oldSeps.length - k];
    final newIdx = newSeps[newSeps.length - k];
    if (oldChars[oldIdx] == newChars[newIdx]) matches[newIdx] = oldIdx;
  }

  return matches;
}

bool _isGrouping(String char, String decimalChar) =>
    char != decimalChar && coreSeparators.contains(char);

List<int> _keptIndices(List<String> chars, String decimalChar) {
  final indices = <int>[];
  for (var i = 0; i < chars.length; i++) {
    if (!_isGrouping(chars[i], decimalChar)) indices.add(i);
  }
  return indices;
}

List<int> _groupingIndices(List<String> chars, String decimalChar) {
  final indices = <int>[];
  for (var i = 0; i < chars.length; i++) {
    if (_isGrouping(chars[i], decimalChar)) indices.add(i);
  }
  return indices;
}

// Past this the digits overlap into a smear and nothing should carry across.
const int _magnitudeJump = 3;

/// Pairs characters by distance from the decimal separator, not left to right —
/// a digit's identity is its column. Both walks skip mismatches rather than
/// stopping.
Map<int, int> _placeMatch(
  List<String> oldChars,
  List<String> newChars,
  String decimalChar,
) {
  final matches = <int, int>{};

  var start = 0;
  while (start < oldChars.length &&
      start < newChars.length &&
      oldChars[start] == newChars[start] &&
      !isDigit(oldChars[start])) {
    matches[start] = start;
    start++;
  }

  var oldEnd = oldChars.length;
  var newEnd = newChars.length;
  while (oldEnd > start &&
      newEnd > start &&
      oldChars[oldEnd - 1] == newChars[newEnd - 1] &&
      !isDigit(oldChars[oldEnd - 1])) {
    matches[newEnd - 1] = oldEnd - 1;
    oldEnd--;
    newEnd--;
  }

  final oldPivot = _findPivot(oldChars, start, oldEnd, decimalChar);
  final newPivot = _findPivot(newChars, start, newEnd, decimalChar);

  final oldDigits = _integerDigits(oldChars, start, oldPivot);
  final newDigits = _integerDigits(newChars, start, newPivot);

  // A side with no digits is a field being typed into or emptied, not a magnitude.
  if (oldDigits > 0 &&
      newDigits > 0 &&
      (oldDigits - newDigits).abs() >= _magnitudeJump) {
    return matches;
  }

  void matchSeparator(int oldIndex, int newIndex) {
    final char = oldChars[oldIndex];
    if (isDigit(char)) return;
    if (char == newChars[newIndex]) matches[newIndex] = oldIndex;
  }

  /// Pairs the digits on one side of the pivot, by column where the count
  /// matches and by subsequence where it changed. Returns whether digits
  /// survived a reshape.
  bool matchDigits(
    int oldFrom,
    int oldTo,
    int newFrom,
    int newTo,
    bool towardsPivot,
  ) {
    final oldIndices = _digitIndices(oldChars, oldFrom, oldTo);
    final newIndices = _digitIndices(newChars, newFrom, newTo);

    if (oldIndices.length == newIndices.length || !towardsPivot) {
      final pairs = oldIndices.length < newIndices.length
          ? oldIndices.length
          : newIndices.length;
      for (var k = 0; k < pairs; k++) {
        final oi = oldIndices[k];
        final ni = newIndices[k];
        if (oldChars[oi] == newChars[ni]) matches[ni] = oi;
      }
      return false;
    }

    // Reversed, so the subsequence walk resolves its ties from the units end.
    final oldRun = oldIndices
        .map((i) => oldChars[i])
        .toList()
        .reversed
        .toList();
    final newRun = newIndices
        .map((i) => newChars[i])
        .toList()
        .reversed
        .toList();
    final (ai, bi) = lcsIndices(oldRun, newRun);

    for (var k = 0; k < ai.length; k++) {
      final oi = oldIndices[oldIndices.length - 1 - ai[k]];
      final ni = newIndices[newIndices.length - 1 - bi[k]];
      matches[ni] = oi;
    }
    return ai.isNotEmpty;
  }

  // A separator holds its distance from the pivot unless a reshape carried
  // digits across it, in which case it leaves instead.
  final reshaped = matchDigits(start, oldPivot, start, newPivot, true);
  if (!reshaped) {
    for (var k = 1; oldPivot - k >= start && newPivot - k >= start; k++) {
      matchSeparator(oldPivot - k, newPivot - k);
    }
  }

  // Absent from either value, the pivot is that value's end.
  if (oldPivot < oldEnd && newPivot < newEnd) {
    matches[newPivot] = oldPivot;

    for (var k = 1; oldPivot + k < oldEnd && newPivot + k < newEnd; k++) {
      matchSeparator(oldPivot + k, newPivot + k);
    }
    matchDigits(oldPivot + 1, oldEnd, newPivot + 1, newEnd, false);
  }

  return matches;
}

List<int> _digitIndices(List<String> chars, int from, int to) {
  final indices = <int>[];
  for (var i = from; i < to; i++) {
    if (isDigit(chars[i])) indices.add(i);
  }
  return indices;
}

int _integerDigits(List<String> chars, int start, int pivot) {
  var count = 0;
  for (var i = start; i < pivot; i++) {
    if (isDigit(chars[i])) count++;
  }
  return count;
}

/// Last decimal separator within the affix-trimmed range, else the range end.
int _findPivot(List<String> chars, int start, int end, String decimalChar) {
  for (var i = end - 1; i >= start; i--) {
    if (chars[i] == decimalChar) return i;
  }
  return end;
}
