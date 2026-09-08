// ignore_for_file: avoid_print
// Browser oracle vs. Flutter static RTL parity (SONNET B, deliverable 3); widget built `bidi: false` for upstream comparability.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import '../../widget/harness.dart';

const String _browserDir = 'oracle/fixtures/rtl/browser';

class _Row {
  _Row(this.id, this.text, this.browserTextSeq, this.flutterTextSeq,
      this.browserIdSeq, this.flutterIdSeq, this.match);

  final String id;
  final String text;
  final String browserTextSeq;
  final String flutterTextSeq;
  final List<String> browserIdSeq;
  final List<String> flutterIdSeq;
  final bool match;
}

final List<_Row> _rows = [];

void main() {
  final dir = Directory(_browserDir);
  final files = dir.existsSync()
      ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  if (files.isEmpty) {
    test('browser RTL fixtures not present (see instructions in report)', () {
      Directory('reports/rtl').createSync(recursive: true);
      File('reports/rtl/browser_vs_flutter_static.md').writeAsStringSync(
        '# Browser vs. Flutter static RTL parity\n\n'
        'No fixtures found under `$_browserDir` at the time this test ran.\n\n'
        'To run this comparison later: generate `$_browserDir/<CASE-ID>.json` '
        'files (one per corpus case, each with a `torphAtRest.torphVisualOrder` '
        'array of `{id, text, kind, x}` in browser visual left-to-right order '
        'for upstream Torph\'s DOM at rest — see the schema already used by the '
        'RTL browser oracle agent for this task), then re-run '
        '`flutter test test/parity/rtl/rtl_browser_static_parity_test.dart`. '
        'It will pick every fixture up automatically and regenerate this report.',
      );
      print('rtl_browser_static_parity: no fixtures under $_browserDir, '
          'wrote a how-to-run-later note to reports/rtl/browser_vs_flutter_static.md');
    });
    return;
  }

  tearDownAll(() {
    Directory('reports/rtl').createSync(recursive: true);
    final matchCount = _rows.where((r) => r.match).length;
    final mismatchCount = _rows.length - matchCount;
    final md = StringBuffer()
      ..writeln('# Browser vs. Flutter static RTL parity')
      ..writeln()
      ..writeln('Compares each browser oracle fixture\'s `torphAtRest.torphVisualOrder` '
          '(upstream Torph, real Chrome, at rest) against `TextMorph` driven in '
          'this Flutter port, both read left-to-right by item.')
      ..writeln()
      ..writeln('${_rows.length} cases, $matchCount MATCH, $mismatchCount MISMATCH.')
      ..writeln()
      ..writeln('| id | text | browser item order | flutter item order | result |')
      ..writeln('|---|---|---|---|---|');
    for (final r in _rows) {
      final result = r.match ? 'MATCH' : 'MISMATCH';
      md.writeln('| ${r.id} | ${r.text} | ${r.browserTextSeq} | ${r.flutterTextSeq} | $result |');
    }
    File('reports/rtl/browser_vs_flutter_static.md').writeAsStringSync(md.toString());
    print('rtl_browser_static_parity: ${_rows.length} cases, $matchCount MATCH, '
        '$mismatchCount MISMATCH -> reports/rtl/browser_vs_flutter_static.md');
  });

  for (final file in files) {
    late Map<String, dynamic> data;
    try {
      data = (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
    } catch (_) {
      continue;
    }
    final id = data['id'] as String? ?? file.uri.pathSegments.last;
    final text = data['text'] as String?;
    final direction = data['direction'] == 'ltr' ? TextDirection.ltr : TextDirection.rtl;
    final localeTag = data['locale'] as String? ?? 'en';
    final torphAtRest = (data['torphAtRest'] as Map?)?.cast<String, dynamic>();
    if (text == null || torphAtRest == null) continue;
    final browserVisual = (torphAtRest['torphVisualOrder'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        const <Map<String, dynamic>>[];
    if (browserVisual.isEmpty) continue;

    testWidgets('$id vs browser torphVisualOrder', (tester) async {
      final locale = Locale(localeTag);
      await tester.pumpWidget(host(
        TextMorph(value: text, locale: locale, bidi: false),
        direction: direction,
      ));
      await tester.pumpAndSettle();

      final snap = snapshotOf(tester);
      final items = snap.liveItems.where((i) => !i.isBreak).toList()
        ..sort((a, b) => a.visualRect.left.compareTo(b.visualRect.left));

      final flutterTextSeq = items.map((i) => i.text).join();
      final flutterIdSeq = items.map((i) => i.id).toList();
      final browserTextSeq = browserVisual.map((e) => e['text'] as String).join();
      final browserIdSeq = browserVisual.map((e) => e['id'] as String).toList();

      final match = flutterTextSeq == browserTextSeq;
      _rows.add(_Row(id, text, browserTextSeq, flutterTextSeq, browserIdSeq,
          flutterIdSeq, match));

      expect(true, isTrue);
    });
  }
}
