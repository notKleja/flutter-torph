import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:torph/torph.dart';

import 'rtl_corpus_data.dart';

const TextStyle _style = TextStyle(fontSize: 20, color: Color(0xFF000000));

Widget _widgetFor(RtlPlatformCase c, TextDirection dir) {
  return MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.noScaling),
    child: Directionality(
      textDirection: dir,
      child: DefaultTextStyle(
        style: _style,
        child: Align(
          alignment: Alignment.topLeft,
          child: TextMorph(value: c.text, locale: Locale(c.locale)),
        ),
      ),
    ),
  );
}

List<Map<String, dynamic>> _plainOrder(
  String text,
  TextDirection dir,
  Locale locale,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _style),
    textDirection: dir,
    locale: locale,
  )..layout();
  final entries = <Map<String, dynamic>>[];
  var offset = 0;
  for (final g in text.characters) {
    final start = offset;
    final end = offset + g.length;
    offset = end;
    if (start == end) continue;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    if (boxes.isEmpty) continue;
    var left = boxes.first.left;
    for (final b in boxes) {
      if (b.left < left) left = b.left;
    }
    entries.add({'text': g, 'left': left});
  }
  painter.dispose();
  entries.sort(
    (a, b) => (a['left'] as double).compareTo(b['left'] as double),
  );
  return entries;
}

List<Map<String, dynamic>> _torphOrder(TextMorphSnapshot snap) {
  final live = snap.liveItems.where((i) => !i.isBreak).toList();
  final entries = [
    for (final item in live)
      {'text': item.text, 'left': item.visualRect.left},
  ];
  entries.sort(
    (a, b) => (a['left'] as double).compareTo(b['left'] as double),
  );
  return entries;
}

String _round2(double v) => v.toStringAsFixed(2);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final results = <Map<String, dynamic>>[];

  tearDownAll(() {
    // ignore: avoid_print
    print(
      'RTL-PLATFORM-SUMMARY '
      '${jsonEncode({'caseCount': results.length})}',
    );
  });

  for (final c in rtlPlatformCorpus) {
    testWidgets('${c.id} "${c.text}"', (tester) async {
      final dir = c.direction == 'rtl' ? TextDirection.rtl : TextDirection.ltr;
      final locale = Locale(c.locale);

      await tester.pumpWidget(_widgetFor(c, dir));
      await tester.pumpAndSettle();

      final render = tester.renderObject<RenderTextMorph>(
        find.byType(TextMorph),
      );
      final snap = render.debugSnapshot();
      final torph = _torphOrder(snap);
      final plain = _plainOrder(c.text, dir, locale);

      final record = {
        'id': c.id,
        'text': c.text,
        'direction': c.direction,
        'locale': c.locale,
        'torphVisualOrder': torph.map((e) => e['text']).join(),
        'torphVisualTexts': [for (final e in torph) e['text']],
        'torphVisualLefts': [
          for (final e in torph) _round2(e['left'] as double),
        ],
        'plainVisualOrder': plain.map((e) => e['text']).join(),
        'plainVisualGraphemes': [for (final e in plain) e['text']],
        'plainVisualLefts': [
          for (final e in plain) _round2(e['left'] as double),
        ],
      };
      results.add(record);

      // ignore: avoid_print
      print('RTL-PLATFORM ${jsonEncode(record)}');

      await tester.pumpWidget(const SizedBox());
      expect(true, isTrue);
    });
  }
}
