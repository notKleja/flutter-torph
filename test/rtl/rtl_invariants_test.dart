import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/testing.dart';
import 'package:torph/torph.dart';

import '../widget/harness.dart';
import 'rtl_visual.dart';

List<ItemFrame> liveByLeft(TextMorphSnapshot snapshot) {
  final live = snapshot.liveItems.where((i) => !i.isBreak).toList()
    ..sort((a, b) => a.visualRect.left.compareTo(b.visualRect.left));
  return live;
}

List<String> liveTextsByLeft(TextMorphSnapshot snapshot) => [
  for (final i in liveByLeft(snapshot)) i.text,
];

List<double> liveLefts(TextMorphSnapshot snapshot) => [
  for (final i in liveByLeft(snapshot)) i.visualRect.left,
];

/// The plain-paragraph reference: what a bare `TextPainter` puts left-to-right
/// for [text] in [direction], at grapheme granularity, NBSP normalized to a
/// regular space so a rendered NBSP item compares equal to a literal one.
String plainVisualOf(String text, TextDirection direction, {Locale? locale}) {
  final boxes = graphemeBoxesOf(
    text,
    direction: direction,
    style: testStyle,
    locale: locale,
  );
  return visualOrderString(boxes).replaceAll(' ', ' ');
}

/// Torph's live items, in visual order, each laid out on its own so a
/// multi-character item's internal glyph order is included too.
String torphVisualOf(TextMorphSnapshot snapshot, TextDirection direction) {
  final buffer = StringBuffer();
  for (final item in liveByLeft(snapshot)) {
    final text = item.text.replaceAll(' ', ' ');
    buffer.write(
      visualOrderString(
        graphemeBoxesOf(text, direction: direction, style: testStyle),
      ),
    );
  }
  return buffer.toString();
}

/// Asserts Torph's item order, read left-to-right, reconstructs exactly what
/// a plain `TextPainter` would show for [text] in [direction] — the Unicode
/// Bidirectional Algorithm's answer, not Torph's own opinion.
void expectMatchesPlainReference(
  TextMorphSnapshot snapshot,
  String text,
  TextDirection direction, {
  Locale? locale,
}) {
  expect(
    torphVisualOf(snapshot, direction),
    plainVisualOf(text, direction, locale: locale),
    reason: 'Torph visual order must match the plain-paragraph (UBA) reference',
  );
}

void main() {
  testWidgets(
    '"1,000" in an RTL root: bidi places digits UBA-correctly (1,0,0,0 left-to-right)',
    (tester) async {
      const value = '1,000';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), ['1', ',', '0', '0', '0']);
      expect(liveLefts(snapshot), [0, 20, 40, 60, 80]);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"السعر 1234 ريال" in an RTL root: ريال, space, 1234 (forward), space, السعر',
    (tester) async {
      const value = 'السعر 1234 ريال';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), [
        'ريال',
        ' ',
        '1',
        '2',
        '3',
        '4',
        ' ',
        'السعر',
      ]);
      expect(liveLefts(snapshot), [0, 80, 100, 120, 140, 160, 180, 200]);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"مرحبا ABC 123 DEF" in an RTL root: ABC, space, 123, space, DEF, space, مرحبا',
    (tester) async {
      const value = 'مرحبا ABC 123 DEF';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), [
        'ABC',
        ' ',
        '1',
        '2',
        '3',
        ' ',
        'DEF',
        ' ',
        'مرحبا',
      ]);
      expect(liveLefts(snapshot), [0, 60, 80, 100, 120, 140, 160, 220, 240]);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"مرحبا بالعالم" in an RTL root: both words visually reversed to بالعالم, space, مرحبا',
    (tester) async {
      const value = 'مرحبا بالعالم';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), ['بالعالم', ' ', 'مرحبا']);
      expect(liveLefts(snapshot), [0, 140, 160]);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"مرحبا \$123" in an RTL root: digits and \$ stay left-to-right (123\$)',
    (tester) async {
      const value = 'مرحبا \$123';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), ['1', '2', '3', '\$', ' ', 'مرحبا']);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"مرحبا -123" in an RTL root: digits and hyphen stay left-to-right (123-)',
    (tester) async {
      const value = 'مرحبا -123';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), ['1', '2', '3', '-', ' ', 'مرحبا']);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"مرحبا 123%" in an RTL root: the % sits to the left of the digits (%123)',
    (tester) async {
      const value = 'مرحبا 123%';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), ['%', '1', '2', '3', ' ', 'مرحبا']);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"مرحبا (123)" in an RTL root: mirrored parens, digits forward ()123()',
    (tester) async {
      const value = 'مرحبا (123)';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), [
        ')',
        '1',
        '2',
        '3',
        '(',
        ' ',
        'مرحبا',
      ]);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"مرحبا 12:34" in an RTL root: the digit runs and colon stay left-to-right',
    (tester) async {
      const value = 'مرحبا 12:34';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), ['12', ':', '34', ' ', 'مرحبا']);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"اليوم 08/09/2026" in an RTL root: the date fields and slashes stay left-to-right',
    (tester) async {
      const value = 'اليوم 08/09/2026';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), [
        '08',
        '/',
        '09',
        '/',
        '2026',
        ' ',
        'اليوم',
      ]);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    'Hebrew "מחיר 1234 ₪" in an RTL root: ₪, space, 1234 (forward), space, מחיר',
    (tester) async {
      const value = 'מחיר 1234 ₪';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), [
        '₪',
        ' ',
        '1',
        '2',
        '3',
        '4',
        ' ',
        'מחיר',
      ]);
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    '"السعر ١٢٣٤ ريال" (Arabic-Indic digits): the number stays one item, unreversed',
    (tester) async {
      const value = 'السعر ١٢٣٤ ريال';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.rtl),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), ['ريال', ' ', '١٢٣٤', ' ', 'السعر']);
      final numberItem = snapshot.item('١٢٣٤');
      expect(
        numberItem.kind,
        isNull,
        reason:
            'Arabic-Indic digits are not ASCII 0-9, so classifyKind sees them as text',
      );
      expectMatchesPlainReference(snapshot, value, TextDirection.rtl);
    },
  );

  testWidgets(
    'An LTR root with "السعر 1234 ريال": words placed logically, digits forward',
    (tester) async {
      const value = 'السعر 1234 ريال';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.ltr),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), [
        'ريال',
        ' ',
        '1',
        '2',
        '3',
        '4',
        ' ',
        'السعر',
      ]);
      expectMatchesPlainReference(snapshot, value, TextDirection.ltr);
    },
  );

  testWidgets(
    'Pure-LTR control "hello world" under ltr: unchanged logical order',
    (tester) async {
      const value = 'hello world';
      await tester.pumpWidget(
        host(TextMorph(value: value), direction: TextDirection.ltr),
      );
      final snapshot = snapshotOf(tester);

      expect(liveTextsByLeft(snapshot), ['hello', ' ', 'world']);
      expect(liveLefts(snapshot), [0, 100, 120]);
      expectMatchesPlainReference(snapshot, value, TextDirection.ltr);
    },
  );
}
