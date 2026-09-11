import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/core/diff.dart';
import 'package:torph/src/core/segment.dart';
import 'package:torph/src/core/segmenter.dart';

/// DEV-007: a word morph pairs grapheme clusters, never UTF-16 code units.
bool _isLoneSurrogate(String s) {
  if (s.length != 1) return false;
  final u = s.codeUnitAt(0);
  return u >= 0xd800 && u <= 0xdfff;
}

bool _isBareCombiningMark(String s) {
  if (s.length != 1) return false;
  final u = s.codeUnitAt(0);
  return (u >= 0x0300 && u <= 0x036f) || (u >= 0x1ab0 && u <= 0x1aff);
}

void main() {
  test('emoji skin-tone change keeps whole graphemes, no tofu', () {
    final oldSegs = segmentText('wave 👋 hi', 'en');
    final result = diffSegments(oldSegs, 'wave 👋🏽 hi', 'en');

    for (final seg in result.segments) {
      expect(
        _isLoneSurrogate(seg.string),
        false,
        reason: 'lone surrogate segment: ${seg.toString()}',
      );
      expect(
        _isBareCombiningMark(seg.string),
        false,
        reason: 'bare combining mark segment: ${seg.toString()}',
      );
    }

    final oldById = {for (final s in oldSegs) s.id: s};
    for (final seg in result.segments) {
      final old = oldById[seg.id];
      if (old != null && (old.string == 'w' || seg.string == 'h')) {
        expect(seg.string, old.string, reason: 'id ${seg.id} changed text');
      }
    }
  });

  test('NFD combining acute (café -> cafe) keeps whole graphemes, no tofu', () {
    // "café" — plain e + combining acute, NFD.
    const cafeAccented = 'café hi';
    final oldSegs = segmentText(cafeAccented, 'en');
    final result = diffSegments(oldSegs, 'cafe hi', 'en');

    for (final seg in result.segments) {
      expect(
        _isLoneSurrogate(seg.string),
        false,
        reason: 'lone surrogate segment: ${seg.toString()}',
      );
      expect(
        _isBareCombiningMark(seg.string),
        false,
        reason: 'bare combining mark segment: ${seg.toString()}',
      );
    }

    final oldById = {for (final s in oldSegs) s.id: s};
    for (final seg in result.segments) {
      final old = oldById[seg.id];
      if (old != null && ['c', 'a', 'f'].contains(old.string)) {
        expect(seg.string, old.string, reason: 'id ${seg.id} changed text');
      }
    }

    expect(
      result.segments.map((s) => s.string).join().replaceAll(nbsp, ' '),
      'cafe hi',
    );
  });

  test(
    'segment split for a morphing emoji word carries grapheme-indexed IDs',
    () {
      final oldSegs = segmentText('👋 hi', 'en');
      final result = diffSegments(oldSegs, '👋🏽 hi', 'en');
      final split = result.splits.values.where(
        (segs) =>
            segs.any((s) => s.string.runes.length > 1 || s.string == '👋'),
      );
      for (final segs in split) {
        for (final seg in segs) {
          expect(_isLoneSurrogate(seg.string), false);
        }
      }
    },
  );
}
