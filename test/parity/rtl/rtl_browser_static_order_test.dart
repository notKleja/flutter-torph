import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/testing.dart';
import 'package:torph/torph.dart';

import '../../widget/harness.dart';

/// Asserting static parity: for every RTL corpus case the port's items must
/// have the browser's logical order and upstream (non-bidi) visual order per line — built `bidi: false`.
const Set<String> _zeroWidthSpace = {
  'RTLC-048',
  'RTLC-049',
  'RTLC-050',
  'RTLC-051',
  'RTLC-052',
  'RTLC-054',
};

String _norm(String s) => s.replaceAll(' ', ' ').replaceAll(' ', ' ');

void main() {
  setUpAll(() => debugSplitJoiningWords = true);
  tearDownAll(() => debugSplitJoiningWords = false);

  final dir = Directory('oracle/fixtures/rtl/browser');
  if (!dir.existsSync()) return;
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'RTLC-\d+\.json$').hasMatch(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final b = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final id = b['id'] as String;
    final text = b['text'] as String;
    final direction = b['direction'] == 'rtl'
        ? TextDirection.rtl
        : TextDirection.ltr;
    final rest = b['torphAtRest'] as Map<String, dynamic>;

    testWidgets('$id ${jsonEncode(text)}', (tester) async {
      await tester.pumpWidget(
        host(
          TextMorph(
            value: text,
            locale: Locale(b['locale'] as String),
            bidi: false,
          ),
          direction: direction,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final snap = snapshotOf(tester);

      final browserItems = (rest['items'] as List)
          .cast<Map<String, dynamic>>()
          .where((i) => i['tag'] != 'br')
          .toList();
      final live = snap.liveItems.where((i) => !i.isBreak).toList();

      expect(
        live.map((i) => _norm(i.text)).toList(),
        browserItems.map((i) => _norm(i['text'] as String)).toList(),
        reason: 'segmentation / logical order',
      );

      final skip = _zeroWidthSpace.contains(id);
      bool keep(String t) =>
          !skip ||
          t
              .replaceAll(RegExp(r'[\u200e\u200f\u2066-\u2069]'), '')
              .trim()
              .isNotEmpty;

      final browserLines = <int, List<Map<String, dynamic>>>{};
      for (final i in browserItems) {
        browserLines
            .putIfAbsent(((i['rect'] as Map)['y'] as num).round(), () => [])
            .add(i);
      }
      final flutterLines = <int, List<ItemFrame>>{};
      for (final i in live) {
        flutterLines.putIfAbsent(i.y.round(), () => []).add(i);
      }
      expect(flutterLines.length, browserLines.length, reason: 'line count');

      final browserOrder = [
        for (final key in browserLines.keys.toList()..sort())
          (browserLines[key]!..sort(
                (a, c) => ((a['rect'] as Map)['x'] as num).compareTo(
                  (c['rect'] as Map)['x'] as num,
                ),
              ))
              .map((i) => _norm(i['text'] as String))
              .where(keep)
              .toList(),
      ];
      final flutterOrder = [
        for (final key in flutterLines.keys.toList()..sort())
          (flutterLines[key]!..sort(
                (a, c) => a.visualRect.left.compareTo(c.visualRect.left),
              ))
              .map((i) => _norm(i.text))
              .where(keep)
              .toList(),
      ];
      expect(
        flutterOrder,
        browserOrder,
        reason: 'visual left-to-right order per line',
      );
    });
  }
}
