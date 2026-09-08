import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/motion/morph_engine.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

/// A stand-in item list for the measurer, which never inspects anything but
/// `id`, `string` and `isBreak`.
List<MorphItem> items(List<String> strings) =>
    [for (var i = 0; i < strings.length; i++) MorphItem('i$i', strings[i])];

void main() {
  group('alignment inside the root', () {
    testWidgets('centre shifts the short line', (tester) async {
      await tester.pumpWidget(host(
        TextMorph(value: 'aaa\nb', textAlign: TextAlign.center),
      ));
      final snapshot = snapshotOf(tester);
      expect(snapshot.item('aaa').x, closeTo(0, 0.01));
      // (60 − 20) / 2
      expect(snapshot.item('b').x, closeTo(20, 0.01));
    });

    testWidgets('right pushes the short line to the far edge', (tester) async {
      await tester.pumpWidget(host(
        TextMorph(value: 'aaa\nb', textAlign: TextAlign.right),
      ));
      expect(snapshotOf(tester).item('b').x, closeTo(40, 0.01));
    });

    testWidgets('left (the default) leaves both lines at 0', (tester) async {
      await tester.pumpWidget(host(TextMorph(value: 'aaa\nb')));
      expect(snapshotOf(tester).item('b').x, closeTo(0, 0.01));
    });

    testWidgets('textAlign inherits from DefaultTextStyle', (tester) async {
      await tester.pumpWidget(host(
        TextMorph(value: 'aaa\nb'),
        textAlign: TextAlign.right,
      ));
      expect(snapshotOf(tester).item('b').x, closeTo(40, 0.01));
    });

    testWidgets('RTL flows the items from the right, in logical order',
        (tester) async {
      await tester.pumpWidget(host(
        TextMorph(value: 'aaa\nb', bidi: false),
        direction: TextDirection.rtl,
      ));
      final snapshot = snapshotOf(tester);
      // Line 0 fills the root; line 1 is start-aligned, upstream rule (`bidi: false`) puts that on the right.
      expect(snapshot.item('aaa').x, closeTo(0, 0.01));
      expect(snapshot.item('b').x, closeTo(40, 0.01));
    });

    testWidgets('RTL keeps logical order within a line', (tester) async {
      await tester.pumpWidget(host(
        TextMorph(value: 'ab cd', bidi: false),
        direction: TextDirection.rtl,
      ));
      final snapshot = snapshotOf(tester);
      // "ab" is the first logical item, so under the upstream rule (`bidi: false`) it sits at the right-hand end.
      expect(snapshot.item('ab').x, closeTo(60, 0.01));
      expect(snapshot.item('cd').x, closeTo(0, 0.01));
    });
  });

  group('TextMeasurer', () {
    late TextMeasurer measurer;

    tearDown(() => measurer.dispose());

    TextMeasurer build({
      TextAlign align = TextAlign.start,
      TextDirection direction = TextDirection.ltr,
    }) =>
        measurer = TextMeasurer(
          style: testStyle,
          textScaler: TextScaler.noScaling,
          textDirection: direction,
          textAlign: align,
          locale: const Locale('en'),
        );

    test('an overflowing line stays start-aligned (LTR)', () {
      final m = build(align: TextAlign.center);
      final result = m.measure(items(['abcd']), width: 40);
      expect(result.offsets['i0']!.x, 0);
    });

    test('an overflowing line stays start-aligned (RTL)', () {
      final m = build(align: TextAlign.center, direction: TextDirection.rtl);
      final result = m.measure(items(['abcd']), width: 40);
      // The line hangs off the left: its right edge is the container's.
      expect(result.offsets['i0']!.x, 40 - 80);
    });

    test('a wider container centres and right-aligns', () {
      final centre = build(align: TextAlign.center);
      expect(centre.measure(items(['ab']), width: 100).offsets['i0']!.x, 30);
      centre.dispose();
      final right = build(align: TextAlign.right);
      expect(right.measure(items(['ab']), width: 100).offsets['i0']!.x, 60);
    });

    test('a trailing break makes an empty last line one line tall', () {
      final m = build();
      final result = m.measure(items(['a', '\n']));
      expect(result.naturalHeight, closeTo(2 * lineHeight, 0.01));
      expect(result.naturalWidth, closeTo(fontSize, 0.01));
    });

    test('no items has no line box at all', () {
      final m = build();
      final result = m.measure(items([]));
      expect(result.naturalHeight, 0);
      expect(result.naturalWidth, 0);
      expect(result.offsets, isEmpty);
    });

    test('items are baseline-aligned across differing sizes', () {
      final m = build();
      final small = TextMeasurer(
        style: testStyle,
        textScaler: TextScaler.noScaling,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.start,
      );
      // A taller item raises the line's ascent, so the shorter one moves down.
      final mixed = [MorphItem('a', 'a'), MorphItem('B', 'B')];
      final result = m.measure(mixed);
      expect(result.offsets['a']!.y, result.offsets['B']!.y);
      expect(result.naturalHeight, closeTo(lineHeight, 0.01));
      small.dispose();
    });

    test('painters are cached, so a positions-only re-measure is cheap', () {
      final m = build();
      m.measure(items(['ab', 'cd']));
      final afterFirst = m.cachedPainterCount;
      m.measure(items(['ab', 'cd']), width: 500);
      expect(m.cachedPainterCount, afterFirst);
    });

    test('a zero-width space is 0 wide at full height', () {
      final m = build();
      final result = m.measure(items(['​']));
      expect(result.naturalWidth, 0);
      expect(result.naturalHeight, closeTo(lineHeight, 0.01));
    });
  });
}
