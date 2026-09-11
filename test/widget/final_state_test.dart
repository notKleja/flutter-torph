import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/testing.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

/// Same box and per-character rects as a fresh render; survivors stay split
/// where a fresh render has one word item, so items aren't compared 1:1.
void _expectMatchesFreshRender(
  TextMorphSnapshot settled,
  TextMorphSnapshot fresh,
) {
  expect(settled.value, fresh.value, reason: 'value');
  expect(settled.size, fresh.size, reason: 'size');
  expect(settled.naturalSize, fresh.naturalSize, reason: 'naturalSize');

  final a = _charRects(settled);
  final b = _charRects(fresh);
  expect(a.length, b.length, reason: 'character count');
  for (var i = 0; i < a.length; i++) {
    expect(a[i].char, b[i].char, reason: 'char $i');
    expect(a[i].x, closeTo(b[i].x, 0.01), reason: 'char $i x');
    expect(a[i].y, closeTo(b[i].y, 0.01), reason: 'char $i y');
    expect(a[i].height, closeTo(b[i].height, 0.01), reason: 'char $i height');
  }
}

typedef _CharRect = ({String char, double x, double y, double height});

List<_CharRect> _charRects(TextMorphSnapshot snapshot) {
  final rects = <_CharRect>[];
  for (final item in snapshot.liveItems) {
    if (item.isBreak) continue;
    final chars = item.text.characters.toList();
    final charWidth = chars.isEmpty ? 0.0 : item.width / chars.length;
    for (var i = 0; i < chars.length; i++) {
      rects.add((
        char: chars[i],
        x: item.x + i * charWidth,
        y: item.y,
        height: item.height,
      ));
    }
  }
  return rects;
}

void main() {
  group('initial render', () {
    testWidgets('size matches a plain Text of the same string and style', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Text('hello world')));
      final textSize = tester.getSize(find.byType(Text));

      await tester.pumpWidget(host(TextMorph(value: 'hello world')));
      expect(renderOf(tester).size, textSize);
    });

    testWidgets('has no exiting items, is not animating, ticker inactive', (
      tester,
    ) async {
      await tester.pumpWidget(host(TextMorph(value: 'hello')));
      final snapshot = snapshotOf(tester);
      expect(snapshot.exitingItems, isEmpty);
      expect(snapshot.animating, isFalse);
      expect(stateOf(tester).debugTickerActive, isFalse);
    });

    testWidgets("an initial render of '' does not throw", (tester) async {
      await tester.pumpWidget(host(TextMorph(value: '')));
      expect(tester.takeException(), isNull);
      expect(snapshotOf(tester).animating, isFalse);
    });
  });

  group('settled geometry', () {
    testWidgets('a completed morph matches a fresh render of the final value', (
      tester,
    ) async {
      await tester.pumpWidget(host(TextMorph(value: 'hello')));
      await tester.pumpWidget(host(TextMorph(value: 'hello world')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 500));

      final settled = snapshotOf(tester);
      expect(settled.animating, isFalse);
      expect(settled.exitingItems, isEmpty);
      for (final item in settled.liveItems) {
        expect(item.opacity, 1, reason: 'item "${item.text}" opacity');
        expect(item.transform.tx, 0, reason: 'item "${item.text}" tx');
        expect(item.transform.ty, 0, reason: 'item "${item.text}" ty');
        expect(item.transform.sx, 1, reason: 'item "${item.text}" sx');
        expect(item.transform.sy, 1, reason: 'item "${item.text}" sy');
        expect(item.blur, 0, reason: 'item "${item.text}" blur');
      }

      await tester.pumpWidget(
        host(TextMorph(value: 'hello world', key: const Key('fresh'))),
      );
      _expectMatchesFreshRender(settled, snapshotOf(tester));
    });

    testWidgets(
      'rapid successive updates settle to a fresh render of the final '
      'value, with start x3, cancel x2, complete x1',
      (tester) async {
        final log = <String>[];
        Widget app(String value) => host(
          TextMorph(
            value: value,
            onAnimationStart: () => log.add('start'),
            onAnimationComplete: () => log.add('complete'),
            onAnimationCancel: () => log.add('cancel'),
          ),
        );

        await tester.pumpWidget(app('a'));
        await tester.pumpWidget(app('ab'));
        await startClock(tester);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(app('abc'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(app('abcd'));
        await tester.pump(const Duration(milliseconds: 500));

        expect(log, [
          'start',
          'start',
          'cancel',
          'start',
          'cancel',
          'complete',
        ]);

        final settled = snapshotOf(tester);
        expect(settled.animating, isFalse);

        await tester.pumpWidget(
          host(TextMorph(value: 'abcd', key: const Key('fresh'))),
        );
        _expectMatchesFreshRender(settled, snapshotOf(tester));
      },
    );

    testWidgets('repeated characters never leave duplicate live ids and settle '
        'correctly', (tester) async {
      await tester.pumpWidget(host(TextMorph(value: 'aaaa')));

      await tester.pumpWidget(host(TextMorph(value: 'aa')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 500));
      var snapshot = snapshotOf(tester);
      var ids = snapshot.liveItems.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);

      await tester.pumpWidget(host(TextMorph(value: 'aaaaaa')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 500));
      snapshot = snapshotOf(tester);
      ids = snapshot.liveItems.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(snapshot.animating, isFalse);

      await tester.pumpWidget(
        host(TextMorph(value: 'aaaaaa', key: const Key('fresh'))),
      );
      _expectMatchesFreshRender(snapshot, snapshotOf(tester));
    });
  });

  group('empty value', () {
    testWidgets('text to empty holds the size during the exit', (tester) async {
      await tester.pumpWidget(host(TextMorph(value: 'hello')));
      final before = renderOf(tester).size;

      await tester.pumpWidget(host(TextMorph(value: '')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(snapshotOf(tester).animating, isTrue);
      expect(renderOf(tester).size, before);

      await tester.pump(const Duration(milliseconds: 500));
      expect(snapshotOf(tester).animating, isFalse);
    });

    testWidgets('empty to text morphs in naturally', (tester) async {
      await tester.pumpWidget(host(TextMorph(value: '')));
      await tester.pumpWidget(host(TextMorph(value: 'hello')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 500));

      final settled = snapshotOf(tester);
      expect(settled.animating, isFalse);
      await tester.pumpWidget(
        host(TextMorph(value: 'hello', key: const Key('fresh'))),
      );
      _expectMatchesFreshRender(settled, snapshotOf(tester));
    });
  });

  testWidgets(
    'a style change mid-morph settles to a fresh render at the new style',
    (tester) async {
      await tester.pumpWidget(host(TextMorph(value: 'hello')));
      await tester.pumpWidget(host(TextMorph(value: 'hello world')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        host(
          TextMorph(value: 'hello world', style: const TextStyle(fontSize: 40)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final settled = snapshotOf(tester);
      expect(settled.animating, isFalse);

      await tester.pumpWidget(
        host(
          TextMorph(
            value: 'hello world',
            style: const TextStyle(fontSize: 40),
            key: const Key('fresh'),
          ),
        ),
      );
      _expectMatchesFreshRender(settled, snapshotOf(tester));
    },
  );

  testWidgets('Duration.zero settles immediately and fires complete', (
    tester,
  ) async {
    final log = <String>[];
    Widget app(String value) => host(
      TextMorph(
        value: value,
        duration: Duration.zero,
        onAnimationStart: () => log.add('start'),
        onAnimationComplete: () => log.add('complete'),
      ),
    );

    await tester.pumpWidget(app('a'));
    expect(log, isEmpty);

    await tester.pumpWidget(app('ab'));
    expect(log, ['start', 'complete']);
    expect(snapshotOf(tester).animating, isFalse);
  });

  testWidgets('text scaling doubles the settled size, same as Text', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const Text('hello world'), textScaler: const TextScaler.linear(2)),
    );
    final textSize = tester.getSize(find.byType(Text));

    await tester.pumpWidget(
      host(
        TextMorph(value: 'hello world'),
        textScaler: const TextScaler.linear(2),
      ),
    );
    expect(renderOf(tester).size, textSize);
  });
}
