import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/core/lcs.dart';
import 'package:torph/src/core/number.dart';
import 'package:torph/src/core/segment.dart';

import 'fixtures.dart';

void main() {
  group('LCS (oracle:lcs)', () {
    final cases = loadFixture('lcs') as List;
    test('${cases.length} random pairs match', () {
      for (final c in cases) {
        final a = (c['a'] as List).cast<String>();
        final b = (c['b'] as List).cast<String>();
        final (ai, bi) = lcsIndices(a, b);
        expect([ai, bi], equals([(c['result'][0] as List), (c['result'][1] as List)]),
            reason: 'lcs($a, $b)');
      }
    });
  });

  group('numeric predicates (oracle:numeric-words)', () {
    final cases = loadFixture('numeric-words') as List;
    test('isNumericWord and numericSkeleton for ${cases.length} words', () {
      for (final c in cases) {
        final word = c['word'] as String;
        expect(isNumericWord(word), c['isNumeric'], reason: 'isNumericWord(${show(word)})');
        expect(numericSkeleton(word), c['skeleton'], reason: 'numericSkeleton(${show(word)})');
      }
    });
  });

  group('decimalSeparator (oracle:decimal-separator)', () {
    for (final c in loadFixture('decimal-separator') as List) {
      test(c['locale'] as String, () {
        expect(decimalSeparator(c['locale'] as String), c['separator']);
      });
    }
  });

  group('number formatting (oracle:number-format)', () {
    for (final c in loadFixture('number-format') as List) {
      test('${c['value']} ${c['locale']} decimals=${c['decimals']}', () {
        expect(formatNumber(c['value'] as num, c['locale'] as String, c['decimals'] as int?),
            c['formatted']);
      });
    }
  });

  group('segmentNumber chains (oracle:segment-number)', () {
    for (final chain in loadFixture('segment-number') as List) {
      test(chain['label'] as String, () {
        final norm = MintNormalizer();
        final decimalChar = chain['decimalChar'] as String;
        List<NumberSegment>? prev;
        for (final step in chain['steps'] as List) {
          final segs = segmentNumber(
            step['value'] as String,
            prev,
            step['cursorIndex'] as int?,
            decimalChar,
          );
          expect(norm.segments(segs), fixtureSegments(step['segments'] as List),
              reason: 'step ${show(step['value'] as String)}');
          prev = segs;
        }
      });
    }
  });

  test('segmentNumber maps space to NBSP and back', () {
    final a = segmentNumber('1 000');
    expect(a[1].string, nbsp);
    final b = segmentNumber('1 000', a);
    expect(b.map((s) => s.id), a.map((s) => s.id));
  });

  test('codeUnits splits surrogate pairs like JS split("")', () {
    expect(codeUnits('a😀').length, 3);
  });
}
