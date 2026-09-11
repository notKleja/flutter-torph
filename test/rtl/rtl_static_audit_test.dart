// ignore_for_file: avoid_print
// RTL/bidi static audit (SONNET B); widget built `bidi: false` so numbers stay comparable to the browser fixtures.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import '../widget/harness.dart';
import 'rtl_corpus.dart';
import 'rtl_visual.dart';

const List<String> _arabicScriptCandidates = [
  '/System/Library/Fonts/GeezaPro.ttc',
  '/System/Library/Fonts/SFArabic.ttf',
  '/System/Library/Fonts/Supplemental/GeezaPro.ttc',
];
const List<String> _hebrewScriptCandidates = [
  '/System/Library/Fonts/SFHebrew.ttf',
  '/System/Library/Fonts/Supplemental/Arial Hebrew.ttc',
];

final Map<String, List<String>> _systemFontCandidatesByLocale = {
  'ar': _arabicScriptCandidates,
  'fa': _arabicScriptCandidates,
  'ur': _arabicScriptCandidates,
  'he': _hebrewScriptCandidates,
};

final Map<String, String?> _loadedFamilyByLocale = {};

Future<String?> _systemFamilyFor(String locale) async {
  if (_loadedFamilyByLocale.containsKey(locale)) {
    return _loadedFamilyByLocale[locale];
  }
  if (Platform.environment['RTL_AUDIT_SYSTEM_FONT'] != '1') {
    return _loadedFamilyByLocale[locale] = null;
  }
  final candidates = _systemFontCandidatesByLocale[locale] ?? const [];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      final bytes = file.readAsBytesSync();
      final family = 'RtlAudit_$locale';
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      return _loadedFamilyByLocale[locale] = family;
    } catch (_) {
      continue;
    }
  }
  return _loadedFamilyByLocale[locale] = null;
}

final List<Map<String, dynamic>> _results = [];
int _matchCount = 0;
int _mismatchCount = 0;

Map<String, dynamic> _geometryOf(dynamic item) => {
  'id': item.id,
  'text': item.text,
  'kind': item.kind?.toString(),
  'x': item.x,
  'y': item.y,
  'width': item.width,
  'height': item.height,
  'visualLeft': item.visualRect.left,
  'visualRight': item.visualRect.right,
};

Future<Map<String, dynamic>> _runOnePass(
  WidgetTester tester,
  RtlCase c,
  TextDirection dir,
  Locale locale,
  TextStyle style,
  String fontLabel,
) async {
  final plainBoxes = graphemeBoxesOf(
    c.text,
    direction: dir,
    style: style,
    locale: locale,
  );
  final plainVisualOrder = visualOrderList(plainBoxes);

  await tester.pumpWidget(
    host(
      TextMorph(value: c.text, locale: locale, style: style, bidi: false),
      direction: dir,
    ),
  );
  await tester.pumpAndSettle();

  final snap = snapshotOf(tester);
  final logical = snap.liveItems.where((i) => !i.isBreak).toList();
  final torphLogical = logical.map(_geometryOf).toList();

  final visual = [...logical]
    ..sort((a, b) => a.visualRect.left.compareTo(b.visualRect.left));
  final torphVisualOrder = visual.map(_geometryOf).toList();

  final glyphOrder = <String>[];
  for (final item in visual) {
    final boxes = graphemeBoxesOf(
      item.text,
      direction: dir,
      style: style,
      locale: locale,
    );
    glyphOrder.addAll(visualOrderList(boxes));
  }

  final match = plainVisualOrder.join() == glyphOrder.join();
  final mismatchIndices = match
      ? const <int>[]
      : divergingIndices(plainVisualOrder, glyphOrder);

  if (match) {
    _matchCount++;
  } else {
    _mismatchCount++;
  }

  await tester.pumpWidget(const SizedBox());

  return {
    'font': fontLabel,
    'plainVisualOrder': plainVisualOrder.join(),
    'plainVisualOrderGraphemes': plainVisualOrder,
    'torphLogical': torphLogical,
    'torphVisualOrder': torphVisualOrder,
    'torphVisualGlyphOrder': glyphOrder.join(),
    'match': match,
    'mismatchIndices': mismatchIndices,
  };
}

void main() {
  final cases = loadRtlCorpus();

  tearDownAll(() {
    final dir = Directory('reports/rtl');
    dir.createSync(recursive: true);
    final file = File('reports/rtl/flutter_static.json');
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'corpusSource': rtlCorpusIsFallback ? 'fallback' : 'generated',
        'caseCount': cases.length,
        'matchCount': _matchCount,
        'mismatchCount': _mismatchCount,
        'cases': _results,
      }),
    );
    print(
      'rtl_static_audit: ${cases.length} cases '
      '(source: ${rtlCorpusIsFallback ? "fallback" : "generated"}), '
      '$_matchCount pass-matches, $_mismatchCount pass-mismatches '
      '(a case may run 1-2 font passes) -> reports/rtl/flutter_static.json',
    );
  });

  for (final c in cases) {
    testWidgets('${c.id} [${c.category}] "${c.text}"', (tester) async {
      final dir = c.direction == 'rtl' ? TextDirection.rtl : TextDirection.ltr;
      final locale = Locale(c.locale);
      const defaultStyle = testStyle;

      final defaultResult = await _runOnePass(
        tester,
        c,
        dir,
        locale,
        defaultStyle,
        'default',
      );

      Map<String, dynamic>? systemResult;
      final family = await _systemFamilyFor(c.locale);
      if (family != null) {
        final systemStyle = defaultStyle.copyWith(fontFamily: family);
        systemResult = await _runOnePass(
          tester,
          c,
          dir,
          locale,
          systemStyle,
          'system:$family',
        );
      }

      _results.add({
        'id': c.id,
        'category': c.category,
        'text': c.text,
        'direction': c.direction,
        'locale': c.locale,
        'passes': {'default': defaultResult, 'system': systemResult},
      });

      expect(true, isTrue);
    });
  }

  test('summary sanity', () {
    expect(cases, isNotEmpty);
  });
}
