import 'joining.dart';
import 'number.dart';
import 'segment.dart';
import 'text_segmenter.dart';

/// Re-cuts every numeric word into per-character segments carrying a kind. A
/// pass over the finished segmentation, not part of it: the word segmenter
/// splits "$1,234" on its own terms, and regrouping on whitespace is what keeps
/// this and the diff agreeing.
List<Segment> _expandNumbers(List<Segment> segments) {
  final out = <Segment>[];
  var run = <Segment>[];

  void flush() {
    if (run.isEmpty) return;
    final word = run.map((s) => s.string).join();
    if (isNumericWord(word)) {
      out.addAll(segmentNumber(word));
    } else {
      out.addAll(run);
    }
    run = <Segment>[];
  }

  for (final seg in segments) {
    if (seg.string == nbsp || seg.string == '\n') {
      flush();
      out.add(seg);
    } else {
      run.add(seg);
    }
  }
  flush();
  return out;
}

/// Splits [value] into the units `TextMorph` animates (upstream
/// `segmentText`); `numbers: false` keeps numbers as ordinary words.
List<Segment> segmentText(String value, String locale, {bool numbers = true}) {
  final hasNewlines = value.contains('\n');
  final byWord = value.contains(' ') || hasNewlines;
  final alloc = IdAllocator();

  if (hasNewlines) {
    // `offset` indexes the full value, so IDs derived from it stay unique across lines.
    final lines = value.split('\n');
    final all = <Segment>[];
    var offset = 0;

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      if (lineIndex > 0) {
        all.add(Segment(alloc.take('newline-$offset'), '\n'));
        offset += 1;
      }
      if (line.isNotEmpty) {
        all.addAll(_segmentLine(line, locale, true, offset, alloc));
      }
      offset += line.length;
    }
    return numbers ? _expandNumbers(all) : all;
  }

  final segments = _segmentLine(value, locale, byWord, 0, alloc);
  return numbers ? _expandNumbers(segments) : segments;
}

List<Segment> _segmentLine(
  String line,
  String locale,
  bool byWord,
  int offset,
  IdAllocator alloc,
) {
  final parts = byWord
      ? segmentWords(line)
      : _mergeJoiningRuns(segmentGraphemes(line));
  final segments = <Segment>[];

  for (final data in parts) {
    final index = offset + data.index;
    if (data.segment == ' ') {
      segments.add(Segment(alloc.take('space-$index'), nbsp));
    } else {
      segments.add(
        Segment(allocSegmentId(data.segment, index, alloc), data.segment),
      );
    }
  }
  return segments;
}

String allocSegmentId(String part, int index, IdAllocator alloc) =>
    alloc.has(part) ? alloc.take('$part-$index') : alloc.take(part);

/// A run of graphemes in a joining script is one unit (DEV-008).
List<TextSegment> _mergeJoiningRuns(List<TextSegment> graphemes) {
  final out = <TextSegment>[];
  for (final g in graphemes) {
    final last = out.isEmpty ? null : out.last;
    if (last != null && isAtomicWord(last.segment) && isAtomicWord(g.segment)) {
      out[out.length - 1] = TextSegment(last.index, last.segment + g.segment);
    } else {
      out.add(g);
    }
  }
  return out;
}
