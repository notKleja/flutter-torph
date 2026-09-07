import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

void main() {
  testWidgets('resting size equals the same Text', (tester) async {
    await tester.pumpWidget(host(const Text('hello world', style: testStyle)));
    final textSize = tester.getSize(find.byType(Text));

    await tester.pumpWidget(host(TextMorph(value: 'hello world')));
    final morphSize = renderOf(tester).size;

    expect(morphSize.width, closeTo(textSize.width, 0.01));
    expect(morphSize.height, closeTo(textSize.height, 0.01));
  });

  testWidgets('a two-line value is two line heights tall', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'a\nb')));
    final size = renderOf(tester).size;
    expect(size.height, closeTo(2 * lineHeight, 0.01));
    expect(size.width, closeTo(fontSize, 0.01));
    expect(snapshotOf(tester).lineCount, 2);
  });

  testWidgets('an initial render of "" is an empty root', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: '')));
    expect(renderOf(tester).size, Size.zero);
    final snapshot = snapshotOf(tester);
    expect(snapshot.items, isEmpty);
    expect(snapshot.lineCount, 0);
    expect(snapshot.naturalSize, Size.zero);
  });

  testWidgets('"x" → "" holds one line of height for the stand-in', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'x')));
    expect(renderOf(tester).size, const Size(fontSize, lineHeight));

    await tester.pumpWidget(host(TextMorph(value: '')));
    final snapshot = snapshotOf(tester);
    expect(snapshot.size.height, closeTo(lineHeight, 0.01));
    expect(snapshot.size.width, closeTo(fontSize, 0.01));
    expect(snapshot.items.any((i) => i.text == '​'), isTrue);
  });

  testWidgets('a numeric value lays digits out in slots', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 1234.56, decimals: 2)));
    final snapshot = snapshotOf(tester);
    expect(snapshot.value, '1,234.56');
    expect(snapshot.liveItems.map((i) => i.text).join(), '1,234.56');
    expect(snapshot.liveItems.every((i) => i.kind != null), isTrue);
    expect(snapshot.size.width, closeTo(8 * fontSize, 0.01));
  });

  testWidgets('the text scaler scales the geometry', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello')));
    expect(renderOf(tester).size.width, closeTo(5 * fontSize, 0.01));

    await tester.pumpWidget(host(
      TextMorph(value: 'hello'),
      textScaler: const TextScaler.linear(2),
    ));
    // Same engine, re-measured: no motion, twice the box.
    expect(snapshotOf(tester).animating, isFalse);
    expect(renderOf(tester).size.width, closeTo(10 * fontSize, 0.01));
    expect(renderOf(tester).size.height, closeTo(2 * lineHeight, 0.01));
  });

  testWidgets('intrinsics report the natural size', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello')));
    final render = renderOf(tester);
    expect(render.getMaxIntrinsicWidth(double.infinity), closeTo(5 * fontSize, 0.01));
    expect(render.getMinIntrinsicHeight(double.infinity), closeTo(lineHeight, 0.01));
    expect(
      render.getDryLayout(const BoxConstraints()),
      render.size,
    );
  });
}
