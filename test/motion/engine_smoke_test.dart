import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/core/segment.dart';
import 'package:torph/src/motion/morph_engine.dart';

import 'fake_measurer.dart';

MorphEngine engine({FakeMeasurer? measurer, MorphConfig? config}) =>
    MorphEngine(
      measurer: measurer ?? FakeMeasurer(),
      config: config ?? MorphConfig(),
    );

ItemFrame item(FrameState f, String text, {bool exiting = false}) =>
    f.items.firstWhere((i) => i.text == text && i.exiting == exiting);

void main() {
  test('initial render lays out at rest with no animation', () {
    final e = engine();
    e.update('hello world', disabled: false);
    final f = e.frame(0);
    expect(f.items.map((i) => i.text), ['hello', nbsp, 'world']);
    expect(f.width, 110);
    expect(f.height, 20);
    expect(f.animating, false);
    expect(item(f, 'world').x, 60);
  });

  test('hello → hello world: hello persists in place, world enters', () {
    final e = engine();
    e.update('hello', disabled: false);
    e.frame(0);
    e.update('hello world', disabled: false);
    final f0 = e.frame(0);
    expect(f0.animating, true);
    // Container starts at the old width and heads to the new.
    expect(f0.width, 50);
    final w = item(f0, 'world');
    expect(w.opacity, 0);
    expect(w.transform.sx, 0.95);
    expect(item(f0, 'h').transform.tx, 0);
    expect(f0.items.length, 7); // five graphemes reused, NBSP, world
    final f400 = e.frame(400);
    expect(f400.width, 110);
    expect(item(f400, 'world').opacity, 1);
    expect(item(f400, 'world').transform.sx, 1);
    expect(f400.animating, false);
  });

  test(
    'hello world → hello: world exits pinned where it was and fades over 25%',
    () {
      final e = engine();
      e.update('hello world', disabled: false);
      e.frame(0);
      e.update('hello', disabled: false);
      final f0 = e.frame(0);
      final w = item(f0, 'world', exiting: true);
      expect(w.x, 60);
      expect(w.opacity, 1);
      final f50 = e.frame(50);
      expect(item(f50, 'world', exiting: true).opacity, closeTo(0.5, 1e-9));
      final f100 = e.frame(100);
      expect(f100.items.where((i) => i.exiting), isEmpty);
      expect(f100.animating, true); // container still shrinking
    },
  );

  test('empty value holds the container and shows the zero-width stand-in', () {
    final e = engine();
    e.update('hello', disabled: false);
    e.frame(0);
    e.update('', disabled: false);
    final f = e.frame(100);
    expect(f.width, 50);
    expect(f.height, 20);
    expect(f.items.any((i) => i.id == emptyId), true);
    e.frame(400);
    expect(e.frame(400).animating, false);
  });

  test('numbers: 999 → 1,000 slides digits in a slot', () {
    final e = engine();
    e.update('999', disabled: false);
    e.frame(0);
    e.update('1,000', disabled: false);
    final f = e.frame(0);
    final one = f.items.firstWhere((i) => i.text == '1' && !i.exiting);
    expect(one.kind, SegmentKind.digit);
    expect(one.moverTransform!.ty, -20);
    final comma = f.items.firstWhere((i) => i.text == ',');
    expect(comma.moverTransform!.ty, 20);
  });

  test(
    'callbacks: start before each morph, exactly one of complete/cancel',
    () {
      final log = <String>[];
      final e = engine(
        config: MorphConfig(
          onAnimationStart: () => log.add('start'),
          onAnimationComplete: () => log.add('complete'),
          onAnimationCancel: () => log.add('cancel'),
        ),
      );
      e.update('a', disabled: false);
      e.frame(0);
      expect(log, isEmpty);
      e.update('ab', disabled: false);
      e.frame(0);
      e.frame(100);
      e.update('abc', disabled: false);
      expect(log, ['start', 'start', 'cancel']);
      e.frame(100);
      e.frame(500);
      expect(log, ['start', 'start', 'cancel', 'complete']);
      e.update('abc', disabled: false);
      expect(log.length, 4);
    },
  );
}
