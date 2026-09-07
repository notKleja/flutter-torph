import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/core/diff.dart';
import 'package:torph/src/core/segment.dart';
import 'package:torph/src/core/segmenter.dart';

import 'fixtures.dart';

/// Values ICU cuts with a dictionary (CJK, Thai); the rule-based port cannot
/// reproduce those cuts. See spec/SEGMENTER_KNOWN_GAPS.md.
const Set<String> dictionaryScriptValues = {
  '你好世界',
  'สวัสดี ชาวโลก',
  '日本語テキスト 中文文本 한국어 텍스트',
  'ひらがな カタカナ 漢字',
  'こんにちは 世界',
};

bool _dictionaryScript(String value) =>
    dictionaryScriptValues.contains(value) ||
    RegExp(r'[぀-ヿ㐀-鿿฀-๿຀-໿ក-៿က-႟]')
        .hasMatch(value);

void main() {
  group('segmentText (oracle:segment-text)', () {
    final cases = loadFixture('segment-text') as List;
    var skipped = 0;
    for (final c in cases) {
      final value = c['value'] as String;
      final numbers = c['numbers'] as bool;
      final gap = _dictionaryScript(value) && value.contains(' ');
      if (gap) skipped++;
      test('${show(value)} numbers=$numbers', () {
        final norm = MintNormalizer();
        final segs = segmentText(value, c['locale'] as String, numbers: numbers);
        expect(norm.segments(segs), fixtureSegments(c['segments'] as List));
      }, skip: gap ? 'ICU dictionary segmentation (SEGMENTER_KNOWN_GAPS.md)' : false);
    }
    test('dictionary-script skips stay rare', () {
      expect(skipped, lessThanOrEqualTo(8));
    });
  });

  group('diff chains (oracle:chains)', () {
    final chains = loadFixture('chains') as List;
    for (final chain in chains) {
      final label = chain['label'] as String;
      final locale = chain['locale'] as String;
      final numbers = chain['numbers'] as bool;
      final steps = chain['steps'] as List;
      final gap = steps.any((s) => _dictionaryScript(s['value'] as String) && (s['value'] as String).contains(' '));
      test(label, () {
        final norm = MintNormalizer();
        var prev = <Segment>[];
        for (final step in steps) {
          final value = step['value'] as String;
          final cursorIndex = step['cursorIndex'] as int?;
          List<Segment> segs;
          Map<String, List<Segment>> splits;
          if (prev.isNotEmpty) {
            final r = diffSegments(prev, value, locale, DiffOptions(numbers: numbers, cursorIndex: cursorIndex));
            segs = r.segments;
            splits = r.splits;
          } else {
            segs = segmentText(value, locale, numbers: numbers);
            splits = {};
          }
          expect(norm.segments(segs), fixtureSegments(step['segments'] as List),
              reason: 'segments of step ${show(value)}');
          final expectedSplits = (step['splits'] as Map).map(
              (k, v) => MapEntry(k as String, fixtureSegments(v as List)));
          final actualSplits = splits.map((k, v) => MapEntry(norm(k), norm.segments(v)));
          expect(actualSplits, expectedSplits, reason: 'splits of step ${show(value)}');
          prev = segs;
        }
      }, skip: gap ? 'ICU dictionary segmentation' : false);
    }
  });

  group('invariants over every chain step', () {
    final chains = loadFixture('chains') as List;
    test('unique IDs, rendered text equals value', () {
      for (final chain in chains) {
        var prev = <Segment>[];
        for (final step in chain['steps'] as List) {
          final value = step['value'] as String;
          final segs = prev.isEmpty
              ? segmentText(value, chain['locale'] as String, numbers: chain['numbers'] as bool)
              : diffSegments(prev, value, chain['locale'] as String,
                      DiffOptions(numbers: chain['numbers'] as bool, cursorIndex: step['cursorIndex'] as int?))
                  .segments;
          final ids = segs.map((s) => s.id).toList();
          expect(ids.toSet().length, ids.length, reason: 'duplicate ID in ${show(value)}: $ids');
          final rendered = segs.map((s) => s.string).join().replaceAll(nbsp, ' ');
          expect(rendered, value.replaceAll(nbsp, ' '), reason: 'rendered text of ${show(value)}');
          for (final s in segs) {
            expect(s.string.isNotEmpty, true);
            if (s.string == '\n') expect(s.id.startsWith('newline-'), true);
          }
          prev = segs;
        }
      }
    });
  });

  group('diff bounds', () {
    test('bails to segmentText past MAX_LCS_CELLS and still renders the text', () {
      final oldText = List.generate(1001, (i) => 'w$i').join(' ');
      final newText = List.generate(1001, (i) => 'x$i').join(' ');
      final old = segmentText(oldText, 'en');
      final r = diffSegments(old, newText, 'en');
      expect(r.segments.map((s) => s.string).join().replaceAll(nbsp, ' '), newText);
      expect(r.splits, isEmpty);
    });
    test('skips similarity pairing past MAX_MORPH_PAIRINGS', () {
      final oldText = List.generate(60, (i) => 'abc$i').join(' ');
      final newText = List.generate(60, (i) => 'abd$i').join(' ');
      final old = segmentText(oldText, 'en');
      final r = diffSegments(old, newText, 'en', const DiffOptions(numbers: false));
      expect(r.splits, isEmpty);
      expect(r.segments.map((s) => s.string).join().replaceAll(nbsp, ' '), newText);
    });
  });
}
