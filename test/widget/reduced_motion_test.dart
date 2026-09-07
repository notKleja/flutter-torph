import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

void main() {
  testWidgets('disableAnimations renders plain text and never starts a ticker',
      (tester) async {
    await tester.pumpWidget(host(
      TextMorph(value: 'hello'),
      disableAnimations: true,
    ));

    final snapshot = snapshotOf(tester);
    expect(snapshot.plainText, 'hello');
    expect(snapshot.items, isEmpty);
    expect(snapshot.animating, isFalse);
    expect(stateOf(tester).debugTickerActive, isFalse);

    // The plain text still sizes the box.
    expect(renderOf(tester).size.width, closeTo(5 * fontSize, 0.01));

    await tester.pumpWidget(host(
      TextMorph(value: 'hello world'),
      disableAnimations: true,
    ));
    expect(snapshotOf(tester).plainText, 'hello world');
    expect(stateOf(tester).debugTickerActive, isFalse);
    expect(renderOf(tester).size.width, closeTo(11 * fontSize, 0.01));
  });

  testWidgets('the disabled option does the same', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello', disabled: true)));
    expect(snapshotOf(tester).plainText, 'hello');
    expect(stateOf(tester).debugTickerActive, isFalse);
  });

  testWidgets('respectReducedMotion: false ignores the media query',
      (tester) async {
    await tester.pumpWidget(host(
      TextMorph(value: 'hello', respectReducedMotion: false),
      disableAnimations: true,
    ));
    expect(snapshotOf(tester).plainText, isNull);
    await tester.pumpWidget(host(
      TextMorph(value: 'hello world', respectReducedMotion: false),
      disableAnimations: true,
    ));
    expect(snapshotOf(tester).animating, isTrue);
  });

  testWidgets('re-enabling starts from an initial render, with no motion',
      (tester) async {
    await tester.pumpWidget(host(
      TextMorph(value: 'hello'),
      disableAnimations: true,
    ));
    expect(snapshotOf(tester).plainText, 'hello');

    // The media query alone changes nothing — upstream only reads it on update.
    await tester.pumpWidget(host(TextMorph(value: 'hello')));
    expect(snapshotOf(tester).plainText, 'hello');

    // The next update renders as an initial render: no motion, no callbacks.
    final log = <String>[];
    await tester.pumpWidget(host(TextMorph(
      value: 'hello world',
      onAnimationStart: () => log.add('start'),
    )));
    final snapshot = snapshotOf(tester);
    expect(log, isEmpty);
    expect(snapshot.plainText, isNull);
    expect(snapshot.animating, isFalse);
    expect(snapshot.size.width, closeTo(11 * fontSize, 0.01));
    expect(snapshot.liveItems.every((i) => i.opacity == 1), isTrue);

    // And the one after that morphs again.
    await tester.pumpWidget(host(TextMorph(
      value: 'hello there',
      onAnimationStart: () => log.add('start'),
    )));
    expect(log, ['start']);
    expect(snapshotOf(tester).animating, isTrue);
  });

  testWidgets('a multi-line value stays multi-line when disabled',
      (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'a\nb', disabled: true)));
    final size = renderOf(tester).size;
    expect(size.height, closeTo(2 * lineHeight, 0.01));
    expect(size.width, closeTo(fontSize, 0.01));
  });
}
