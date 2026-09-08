import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import '../widget/harness.dart';
import 'rtl_corpus.dart';
import 'rtl_visual.dart';

/// Cases whose plain-paragraph reference cannot be compared this way, with
/// the reason recorded next to each id. Bidi-control characters (LRM, RLM,
/// LRI/RLI/FSI, PDI) lay out as zero-width boxes in a plain `TextPainter`, so
/// they carry no visual position to sort by — Torph drops them from the
/// segment stream entirely, so there is nothing on Torph's side to compare
/// them against either.
const Map<String, String> excludedCorpusIds = {
  'RTLC-048': 'LRM (U+200E) is a zero-width bidi control; no visual box to compare',
  'RTLC-049': 'RLM (U+200F) is a zero-width bidi control; no visual box to compare',
  'RTLC-050': 'LRI/PDI (U+2066/U+2069) are zero-width bidi controls',
  'RTLC-051': 'RLI/PDI (U+2067/U+2069) are zero-width bidi controls',
  'RTLC-052': 'FSI/PDI (U+2068/U+2069) are zero-width bidi controls',
  'RTLC-053': 'LRI/PDI (U+2066/U+2069) are zero-width bidi controls',
  'RTLC-054': 'LRI/PDI (U+2066/U+2069) are zero-width bidi controls',
  'RTLC-055': 'RLM (U+200F) is a zero-width bidi control; no visual box to compare',
};

List<ItemFrame> liveNonBreak(TextMorphSnapshot snapshot) => snapshot.liveItems
    .where((i) => !i.isBreak)
    .toList();

/// Splits the live item stream (in value order, breaks included) into one
/// list per visual line.
List<List<ItemFrame>> splitIntoLines(TextMorphSnapshot snapshot) {
  final lines = <List<ItemFrame>>[[]];
  for (final item in snapshot.liveItems) {
    if (item.isBreak) {
      lines.add([]);
    } else {
      lines.last.add(item);
    }
  }
  return lines;
}

/// NBSP is how Torph renders a lone space item; a plain reference uses a
/// literal U+0020. Normalize both to a literal space before comparing.
String _normalize(String text) => text.replaceAll(' ', ' ');

/// Torph's visual string for one line: its items sorted by `visualRect.left`,
/// each laid out on its own so a multi-character item's internal glyph order
/// (e.g. a whole RTL word) is included too.
String torphLineVisual(List<ItemFrame> lineItems, TextDirection direction) {
  final visual = [...lineItems]
    ..sort((a, b) => a.visualRect.left.compareTo(b.visualRect.left));
  final buffer = StringBuffer();
  for (final item in visual) {
    final boxes = graphemeBoxesOf(_normalize(item.text), direction: direction, style: testStyle);
    buffer.write(visualOrderString(boxes));
  }
  return buffer.toString();
}

/// The plain-paragraph reference for one line of text. Built from the text
/// Torph actually renders, which turns a grouping space inside a number into
/// NBSP (RTL-004) — a different bidi class, so the raw value would not do.
String plainLineVisual(String line, TextDirection direction, Locale locale) {
  final boxes = graphemeBoxesOf(line, direction: direction, style: testStyle, locale: locale);
  return _normalize(visualOrderString(boxes));
}

void main() {
  final cases = loadRtlCorpus();

  test('corpus loaded from oracle/fixtures/rtl/corpus.json (not the fallback)', () {
    expect(rtlCorpusIsFallback, isFalse,
        reason: 'oracle/fixtures/rtl/corpus.json must exist and be non-empty for this audit');
    expect(cases.length, greaterThanOrEqualTo(162));
  });

  for (final c in cases) {
    final reason = excludedCorpusIds[c.id];
    if (reason != null) {
      test('${c.id} (${c.category}): excluded — $reason', () {}, skip: reason);
      continue;
    }

    testWidgets('${c.id} (${c.category}): "${c.text.replaceAll('\n', '\\n')}"', (tester) async {
      final direction = c.direction == 'ltr' ? TextDirection.ltr : TextDirection.rtl;
      final locale = Locale(c.locale);

      await tester.pumpWidget(host(
        TextMorph(value: c.text, locale: locale, style: testStyle),
        direction: direction,
      ));
      await tester.pumpAndSettle();

      final snapshot = snapshotOf(tester);
      final torphLines = splitIntoLines(snapshot);
      final textLines = c.text.split('\n');

      expect(torphLines.length, textLines.length,
          reason: 'Torph produced ${torphLines.length} line(s) for '
              '${textLines.length} logical line(s) in "${c.text}"');

      for (var i = 0; i < textLines.length; i++) {
        final torphVisual = torphLineVisual(torphLines[i], direction);
        final rendered = torphLines[i].map((item) => item.text).join();
        final plainVisual = plainLineVisual(rendered, direction, locale);
        expect(torphVisual, plainVisual,
            reason: '${c.id} line $i: Torph visual order must match the '
                'plain-paragraph (UBA) reference for "$rendered"');
      }
    });
  }

  group('morph safety under bidi', () {
    testWidgets(
      '999 -> 1,000 in an RTL root settles reading 1 , 0 0 0 left-to-right',
      (tester) async {
        await tester.pumpWidget(host(TextMorph(value: 999), direction: TextDirection.rtl));
        await tester.pumpWidget(host(TextMorph(value: 1000), direction: TextDirection.rtl));
        await startClock(tester);

        await tester.pump(const Duration(milliseconds: 200));
        final mid = snapshotOf(tester);
        final midOrder = [for (final i in liveNonBreak(mid)..sort((a, b) => a.visualRect.left.compareTo(b.visualRect.left))) i.text];

        await tester.pump(const Duration(milliseconds: 300));
        final settled = snapshotOf(tester);
        expect(settled.animating, isFalse,
            reason: 'the morph must be settled before reading final geometry');

        final settledLive = liveNonBreak(settled)
          ..sort((a, b) => a.visualRect.left.compareTo(b.visualRect.left));
        expect([for (final i in settledLive) i.text], ['1', ',', '0', '0', '0']);
        expect([for (final i in settledLive) i.visualRect.left], [0, 20, 40, 60, 80]);
        expect(midOrder, ['1', ',', '0', '0', '0'],
            reason: 'order must already be settled-correct mid-morph, not just at rest');
      },
    );

    testWidgets(
      '"السعر 1234 ريال" -> "السعر 1235 ريال" keeps السعر and ريال on the same '
      'sides at 0%, 50% and settle',
      (tester) async {
        Future<void> expectSides(TextMorphSnapshot snapshot) async {
          expect(
            snapshot.item('ريال').visualRect.left,
            lessThan(snapshot.item('السعر').visualRect.left),
            reason: 'ريال must stay at the visual left, السعر at the visual right',
          );
        }

        await tester.pumpWidget(host(
          TextMorph(value: 'السعر 1234 ريال'),
          direction: TextDirection.rtl,
        ));
        await expectSides(snapshotOf(tester));

        await tester.pumpWidget(host(
          TextMorph(value: 'السعر 1235 ريال'),
          direction: TextDirection.rtl,
        ));
        await startClock(tester);
        await expectSides(snapshotOf(tester));

        await tester.pump(const Duration(milliseconds: 200));
        await expectSides(snapshotOf(tester));

        await tester.pump(const Duration(milliseconds: 300));
        final settled = snapshotOf(tester);
        expect(settled.animating, isFalse);
        await expectSides(settled);
        expect(liveNonBreak(settled).firstWhere((i) => i.kind == SegmentKind.digit && i.text == '5'),
            isNotNull,
            reason: 'the morphed digit (4 -> 5) is present in the settled frame');
      },
    );
  });
}
