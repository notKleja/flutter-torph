import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/testing.dart';
import 'package:torph/torph.dart';

const String _fontFamily = 'RtlShaping';
const TextStyle _style = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 40,
  color: Color(0xFF000000),
);

Future<bool> _loadArabicFont() async {
  for (final path in const [
    '/System/Library/Fonts/SFArabic.ttf',
    '/System/Library/Fonts/GeezaPro.ttc',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader(_fontFamily)
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
    return true;
  }
  return false;
}

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.rtl,
  child: DefaultTextStyle(
    style: _style,
    child: Align(
      alignment: Alignment.topRight,
      child: RepaintBoundary(
        key: const ValueKey('shape'),
        child: Container(
          color: const Color(0xFFFFFFFF),
          padding: const EdgeInsets.all(8),
          child: child,
        ),
      ),
    ),
  ),
);

Future<List<int>> _inkColumns(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shape')),
  );
  final captured = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (
      width: image.width,
      height: image.height,
      bytes: data!.buffer.asUint8List(),
    );
  });
  final image = captured!;
  final bytes = image.bytes;
  final columns = <int>[];
  for (var x = 0; x < image.width; x++) {
    var ink = 0;
    for (var y = 0; y < image.height; y++) {
      if (bytes[(y * image.width + x) * 4] < 128) ink++;
    }
    columns.add(ink);
  }
  return columns;
}

void main() {
  testWidgets('a character-split Arabic word keeps its joined glyphs', (
    tester,
  ) async {
    if (!await _loadArabicFont()) {
      markTestSkipped('no system Arabic font');
      return;
    }

    await tester.pumpWidget(
      _host(TextMorph(value: 'رسائل', locale: Locale('ar'), style: _style)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(
      _host(TextMorph(value: 'رسالة', locale: Locale('ar'), style: _style)),
    );
    await tester.pump(const Duration(seconds: 2));

    final snapshot =
        (tester.renderObject(find.byType(TextMorph)) as RenderTextMorph)
            .debugSnapshot();
    final live = snapshot.liveItems.where((i) => !i.isBreak).toList();
    expect(
      live.length,
      greaterThan(1),
      reason: 'the word must be character-split for this test to mean anything',
    );

    final morphed = await _inkColumns(tester);

    await tester.pumpWidget(_host(const Text('رسالة', style: _style)));
    await tester.pump();
    final plain = await _inkColumns(tester);

    expect(morphed.length, plain.length, reason: 'same box width');
    var diff = 0;
    var total = 0;
    for (var i = 0; i < plain.length; i++) {
      diff += (morphed[i] - plain[i]).abs();
      total += plain[i];
    }
    expect(
      diff / total,
      lessThan(0.08),
      reason:
          'ink profile of the split word must match the same word drawn as one run',
    );
  });
}
