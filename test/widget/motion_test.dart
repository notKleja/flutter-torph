import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

void main() {
  testWidgets('hello → hello world matches the engine at 0 ms and 400 ms',
      (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello')));
    expect(renderOf(tester).size.width, closeTo(5 * fontSize, 0.01));

    await tester.pumpWidget(host(TextMorph(value: 'hello world')));

    // The update's own frame: play-pending tracks show progress 0.
    final at0 = snapshotOf(tester);
    expect(at0.animating, isTrue);
    // The container starts at the old width and heads for the new.
    expect(at0.size.width, closeTo(5 * fontSize, 0.01));
    expect(at0.naturalSize.width, closeTo(11 * fontSize, 0.01));
    final world = at0.item('world');
    expect(world.opacity, 0);
    expect(world.transform.sx, 0.95);
    expect(at0.item('h').transform.tx, 0);
    // Five reused graphemes, the NBSP, and "world".
    expect(at0.items.length, 7);
    expect(renderOf(tester).size.width, closeTo(5 * fontSize, 0.01));

    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 400));

    final at400 = snapshotOf(tester);
    expect(at400.animating, isFalse);
    expect(at400.size.width, closeTo(11 * fontSize, 0.01));
    expect(at400.item('world').opacity, 1);
    expect(at400.item('world').transform.sx, 1);
    expect(renderOf(tester).size.width, closeTo(11 * fontSize, 0.01));
  });

  testWidgets('the box follows the animated width mid-morph', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello')));
    await tester.pumpWidget(host(TextMorph(value: 'hello world')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 100));

    final snapshot = snapshotOf(tester);
    expect(snapshot.now, 100);
    expect(snapshot.size.width, greaterThan(5 * fontSize));
    expect(snapshot.size.width, lessThan(11 * fontSize));
    // The RenderBox is laid out at exactly the frame's animated width.
    expect(renderOf(tester).size.width, closeTo(snapshot.size.width, 0.0001));
    expect(renderOf(tester).size.height, closeTo(snapshot.size.height, 0.0001));
  });

  testWidgets('a frame of the same size only needs paint', (tester) async {
    // Equal natural sizes, so the container width never changes: every tick of
    // this morph is paint-only.
    await tester.pumpWidget(host(TextMorph(value: 'ab')));
    await tester.pumpWidget(host(TextMorph(value: 'ba')));
    await startClock(tester);

    final render = renderOf(tester);
    final sizeBefore = render.size;
    expect(render.debugNeedsLayout, isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    expect(render.size, sizeBefore);
    expect(render.debugNeedsLayout, isFalse);

    // Hand the render object a frame of the same size directly: paint only.
    render.frame = snapshotOf(tester).frame;
    expect(render.debugNeedsLayout, isFalse);
  });

  testWidgets('pumping in 16 ms steps never throws', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: '999')));
    await tester.pumpWidget(host(TextMorph(value: '1,000')));
    await startClock(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(snapshotOf(tester).animating, isFalse);
    expect(snapshotOf(tester).liveItems.map((i) => i.text).join(), '1,000');
  });

  testWidgets('digits slide in their slots, separators the other way',
      (tester) async {
    await tester.pumpWidget(host(TextMorph(value: '999')));
    await tester.pumpWidget(host(TextMorph(value: '1,000')));

    final snapshot = snapshotOf(tester);
    final one = snapshot.liveItems.firstWhere((i) => i.text == '1');
    expect(one.kind, SegmentKind.digit);
    expect(one.moverTransform!.ty, -lineHeight);
    final comma = snapshot.items.firstWhere((i) => i.text == ',');
    expect(comma.moverTransform!.ty, lineHeight);
  });

  testWidgets('an exiting word is pinned where it was and then removed',
      (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello world')));
    await tester.pumpWidget(host(TextMorph(value: 'hello')));

    final at0 = snapshotOf(tester);
    final exiting = at0.item('world', exiting: true);
    expect(exiting.x, closeTo(6 * fontSize, 0.01));
    expect(exiting.opacity, 1);

    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(snapshotOf(tester).item('world', exiting: true).opacity,
        closeTo(0.5, 1e-9));

    await tester.pump(const Duration(milliseconds: 50));
    expect(snapshotOf(tester).exitingItems, isEmpty);
    expect(snapshotOf(tester).animating, isTrue); // the container still shrinks
  });

  testWidgets('TickerMode(enabled: false) freezes the morph', (tester) async {
    await tester.pumpWidget(host(
      const TickerMode(enabled: true, child: _Morph('hello')),
    ));
    await tester.pumpWidget(host(
      const TickerMode(enabled: false, child: _Morph('hello world')),
    ));

    final frozen = snapshotOf(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final later = snapshotOf(tester);
    expect(later.now, frozen.now);
    expect(later.size, frozen.size);
    expect(later.item('world').opacity, frozen.item('world').opacity);
    expect(later.animating, isTrue);
  });

  testWidgets('an interrupted morph carries on from the screen', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello')));
    await tester.pumpWidget(host(TextMorph(value: 'hello world')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final mid = snapshotOf(tester).size.width;

    await tester.pumpWidget(host(TextMorph(value: 'goodbye')));
    // The new transition starts from the width on screen, not from a natural one.
    expect(snapshotOf(tester).size.width, closeTo(mid, 0.5));

    await tester.pump(const Duration(milliseconds: 400));
    expect(snapshotOf(tester).animating, isFalse);
    expect(snapshotOf(tester).size.width, closeTo(7 * fontSize, 0.01));
  });
}

/// A const-constructible wrapper, so `TickerMode` can hold an identical child
/// across pumps except for the value.
class _Morph extends StatelessWidget {
  const _Morph(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => TextMorph(value: value);
}
