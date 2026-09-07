import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/core/text_segmenter.dart';

/// Fixture inputs whose word boundaries only ICU's dictionary breaker can
/// produce. Each one is a single run of a dictionary script (Han, Hiragana,
/// Katakana or Thai) that the rule engine deliberately chains into one lump for
/// the dictionary pass we do not ship. Justified entry by entry, with the
/// expected and actual boundaries, in spec/SEGMENTER_KNOWN_GAPS.md.
const List<String> dictionaryScriptAllowlist = <String>[
  // Han run: ICU's Chinese dictionary knows 你好 and 世界.
  '你好世界',
  // Thai run: ICU's Thai dictionary splits ชาวโลก into ชาว + โลก.
  'สวัสดี ชาวโลก',
  // Han + Katakana chained by `$KanaKanji $KanaKanji`, then cut by the CJ
  // dictionary (日本語 / テキスト, 中文 / 文本).
  '日本語テキスト 中文文本 한국어 텍스트',
  // ひらがな is not a dictionary word, and the dictionary breaker falls back to
  // one segment per code point for an unmatched run.
  'ひらがな カタカナ 漢字',
];

List<TextSegment> _expectedWords(Map<String, dynamic> entry) =>
    (entry['word'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> m) => TextSegment(
              m['index'] as int,
              m['segment'] as String,
              isWordLike: m['isWordLike'] as bool,
            ))
        .toList();

List<TextSegment> _expectedGraphemes(Map<String, dynamic> entry) =>
    (entry['grapheme'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> m) =>
            TextSegment(m['index'] as int, m['segment'] as String))
        .toList();

void main() {
  final fixture = jsonDecode(
    File('oracle/fixtures/segmenter.json').readAsStringSync(),
  ) as List<dynamic>;
  final entries = fixture.cast<Map<String, dynamic>>();

  test('fixture corpus is loaded', () {
    expect(entries, hasLength(352));
  });

  group('segmentGraphemes matches Intl.Segmenter', () {
    for (final entry in entries) {
      final value = entry['value'] as String;
      test('grapheme ${jsonEncode(value)}', () {
        expect(segmentGraphemes(value), _expectedGraphemes(entry));
      });
    }
  });

  group('segmentWords matches Intl.Segmenter', () {
    for (final entry in entries) {
      final value = entry['value'] as String;
      if (dictionaryScriptAllowlist.contains(value)) continue;
      test('word ${jsonEncode(value)}', () {
        expect(segmentWords(value), _expectedWords(entry));
      });
    }
  });

  test('every allowlisted value is in the fixture and still deviates', () {
    final values = entries.map((e) => e['value'] as String).toSet();
    for (final allowed in dictionaryScriptAllowlist) {
      expect(values, contains(allowed),
          reason: 'stale allowlist entry ${jsonEncode(allowed)}');
      final entry = entries.firstWhere((e) => e['value'] == allowed);
      expect(segmentWords(allowed), isNot(_expectedWords(entry)),
          reason: 'allowlist entry ${jsonEncode(allowed)} now matches; '
              'drop it from the allowlist and from '
              'spec/SEGMENTER_KNOWN_GAPS.md');
    }
  });

  test('the whole corpus passes except the allowlist', () {
    final failures = <String>[];
    for (final entry in entries) {
      final value = entry['value'] as String;
      if (segmentGraphemes(value).toString() !=
          _expectedGraphemes(entry).toString()) {
        failures.add('grapheme ${jsonEncode(value)}');
      }
      if (dictionaryScriptAllowlist.contains(value)) continue;
      if (segmentWords(value).toString() != _expectedWords(entry).toString()) {
        failures.add('word ${jsonEncode(value)}');
      }
    }
    expect(failures, isEmpty);
  });

  group('indices are UTF-16 offsets', () {
    test('astral code points advance by two', () {
      expect(segmentWords('a😀b'), <TextSegment>[
        const TextSegment(0, 'a', isWordLike: true),
        const TextSegment(1, '😀'),
        const TextSegment(3, 'b', isWordLike: true),
      ]);
    });

    test('segments concatenate back to the input', () {
      const value = 'Total: \$12.50 — 1,234 items 👨‍👩‍👧‍👦';
      for (final segments in <List<TextSegment>>[
        segmentWords(value),
        segmentGraphemes(value),
      ]) {
        expect(segments.map((s) => s.segment).join(), value);
        var offset = 0;
        for (final segment in segments) {
          expect(segment.index, offset);
          offset += segment.segment.length;
        }
        expect(offset, value.length);
      }
    });
  });

  group('empty and degenerate input', () {
    test('empty string yields nothing', () {
      expect(segmentWords(''), isEmpty);
      expect(segmentGraphemes(''), isEmpty);
    });

    test('a lone combining mark is its own segment', () {
      expect(segmentWords('́a'), <TextSegment>[
        const TextSegment(0, '́'),
        const TextSegment(1, 'a', isWordLike: true),
      ]);
    });

    test('CR LF stays together but CR alone does not swallow letters', () {
      expect(segmentWords('a\r\nb').map((s) => s.segment).toList(),
          <String>['a', '\r\n', 'b']);
      expect(segmentWords('a\rb').map((s) => s.segment).toList(),
          <String>['a', '\r', 'b']);
    });
  });

  group('ICU rule-status quirks', () {
    test('letters, numbers and ideographs are word-like', () {
      expect(segmentWords('don’t').single.isWordLike, isTrue);
      expect(segmentWords('1,234.56').single.isWordLike, isTrue);
      expect(segmentWords('1️⃣').single.isWordLike, isTrue);
    });

    test('status-less rules win at the tail', () {
      // `$ZWJ $Extended_Pict` carries no status.
      expect(segmentWords('x‍\u{1f600}').first.isWordLike, isFalse);
      // `#` keycap: the base is not a letter or number.
      expect(segmentWords('#️⃣').single.isWordLike, isFalse);
      // Regional indicator pair.
      expect(segmentWords('\u{1f1ec}\u{1f1e7}').single.isWordLike, isFalse);
      // `$HangulSyllable {200}` has no trailing `$ExFm*`.
      expect(segmentWords('가').single.isWordLike, isTrue);
      expect(segmentWords('가́').single.isWordLike, isFalse);
      // Rule 13a gives `__` a status, a lone `_` has none.
      expect(segmentWords('__').single.isWordLike, isTrue);
      expect(segmentWords('_').single.isWordLike, isFalse);
      expect(segmentWords('__́').single.isWordLike, isFalse);
    });
  });

  group('ICU-specific word boundaries', () {
    test('numbers, quotes and mid-letters', () {
      expect(segmentWords('e.g. 3.5 1,000 a.b a-b M&M\'s')
          .map((s) => s.segment)
          .toList(), <String>[
        'e.g', '.', ' ', '3.5', ' ', '1,000', ' ', 'a.b', ' ', 'a', '-', 'b',
        ' ', 'M', '&', 'M\'s',
      ]);
    });

    test('a URL breaks on its punctuation', () {
      expect(segmentWords('http://x.y/z?a=1').map((s) => s.segment).toList(),
          <String>['http', ':', '/', '/', 'x.y', '/', 'z', '?', 'a', '=', '1']);
    });

    test('ZWJ between letters keeps them together, ZWSP does not', () {
      expect(segmentWords('x‍y').map((s) => s.segment).toList(),
          <String>['x‍y']);
      expect(segmentWords('a​b').map((s) => s.segment).toList(),
          <String>['a', '​', 'b']);
    });

    test('Hangul and CJK runs chain, but not across an Extend', () {
      expect(segmentWords('한국어').map((s) => s.segment).toList(),
          <String>['한국어']);
      expect(segmentWords('가́각').map((s) => s.segment).toList(),
          <String>['가́', '각']);
      expect(segmentWords('一́一').map((s) => s.segment).toList(),
          <String>['一́', '一']);
      // Rule 13 does allow it for Katakana.
      expect(segmentWords('カ́カ').map((s) => s.segment).toList(),
          <String>['カ́カ']);
    });

    test('emoji ZWJ sequences, flags and skin tones are single segments', () {
      expect(segmentWords('👨‍👩‍👧‍👦').map((s) => s.segment).toList(),
          <String>['👨‍👩‍👧‍👦']);
      expect(segmentWords('🏳️‍🌈').map((s) => s.segment).toList(),
          <String>['🏳️‍🌈']);
      expect(segmentWords('👋🏽').map((s) => s.segment).toList(),
          <String>['👋🏽']);
      expect(segmentWords('🇬🇧🇺🇸').map((s) => s.segment).toList(),
          <String>['🇬🇧', '🇺🇸']);
    });
  });

  test('500 characters segment well under a millisecond', () {
    const line = 'The quick brown fox jumps over the lazy dog, 1,234.56 '
        'times; don\'t stop e.g. a.b https://x.y/z?q=1 ';
    final value = (line * 6).substring(0, 500);
    expect(value.length, 500);
    // Warm up, then take the best of a few runs: a cold first call also pays for
    // JIT warmup, which is not what the budget is about.
    for (var i = 0; i < 200; i++) {
      segmentWords(value);
      segmentGraphemes(value);
    }
    var best = double.infinity;
    for (var round = 0; round < 5; round++) {
      final sw = Stopwatch()..start();
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        segmentWords(value);
        segmentGraphemes(value);
      }
      final per = sw.elapsedMicroseconds / iterations;
      if (per < best) best = per;
    }
    expect(best, lessThan(1000), reason: '${best.toStringAsFixed(1)}us per pass');
  });
}
