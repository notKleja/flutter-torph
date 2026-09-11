import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/motion/morph_engine.dart';

import 'engine_harness.dart';
import 'fake_measurer.dart';

/// After chaotic input the settled scene must equal a fresh render.
void main() {
  group('rapid interruption settles cleanly', () {
    test('3+ updates within one duration settle to a fresh initial render', () {
      final chaotic = Morph(measurer: FakeMeasurer());
      chaotic.update('a');
      chaotic.at(50);
      chaotic.update('ab');
      chaotic.at(120);
      chaotic.update('abc');
      chaotic.at(200);
      chaotic.update('abcd');
      chaotic.at(10000);

      final fresh = Morph(measurer: FakeMeasurer());
      fresh.update('abcd');
      fresh.at(0);

      expect(chaotic.frame.animating, false);
      expect(chaotic.rendered, 'abcd');

      final chaoticItems = chaotic.frame.items
          .where((i) => !i.isBreak)
          .toList();
      final freshItems = fresh.frame.items.where((i) => !i.isBreak).toList();
      expect(chaoticItems.length, freshItems.length);
      for (var i = 0; i < freshItems.length; i++) {
        expect(chaoticItems[i].text, freshItems[i].text);
        expect(
          chaoticItems[i].x,
          freshItems[i].x,
          reason: 'x of ${freshItems[i].text}',
        );
        expect(
          chaoticItems[i].y,
          freshItems[i].y,
          reason: 'y of ${freshItems[i].text}',
        );
        expect(chaoticItems[i].opacity, 1);
        expect(chaoticItems[i].transform.tx, 0);
        expect(chaoticItems[i].transform.ty, 0);
        expect(chaoticItems[i].transform.sx, 1);
      }
    });

    test('text -> "" -> text settles on the restored value', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello');
      morph.at(50);
      morph.update('');
      morph.at(120);
      morph.update('hello');
      morph.at(10000);

      expect(morph.frame.animating, false);
      expect(morph.rendered, 'hello');
      expect(morph.frame.items.where((i) => i.exiting), isEmpty);
    });

    test('an update mid-hold (empty value in flight) carries on correctly', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello');
      morph.update('');
      morph.at(200);
      expect(
        morph.engine.containerTransition?.held,
        isNotNull,
        reason: 'still holding at t=200 of a 400ms duration',
      );

      morph.update('hi');
      morph.at(10000);

      expect(morph.frame.animating, false);
      expect(morph.rendered, 'hi');
      expect(morph.frame.items.where((i) => i.exiting), isEmpty);
    });

    test('multi-line -> single-line -> multi-line settles correctly', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('a\nb');
      morph.at(500);
      expect(morph.rendered, 'ab');

      morph.update('ab');
      morph.at(1000);
      expect(morph.frame.animating, false);
      expect(morph.rendered, 'ab');
      expect(morph.frame.items.any((i) => i.isBreak), false);

      morph.update('c\nd');
      morph.at(1500);
      expect(morph.frame.animating, false);
      expect(morph.rendered, 'cd');
      expect(morph.frame.items.where((i) => i.isBreak).length, 1);
      expect(morph.frame.items.where((i) => i.exiting), isEmpty);
    });
  });

  group('Duration.zero', () {
    test('settles in one frame with complete fired', () {
      final log = <String>[];
      final morph = Morph(
        measurer: FakeMeasurer(),
        config: MorphConfig(
          duration: 0,
          onAnimationStart: () => log.add('start'),
          onAnimationComplete: () => log.add('complete'),
          onAnimationCancel: () => log.add('cancel'),
        ),
      );
      morph.update('a');
      morph.update('ab');
      morph.at(0);

      expect(log, ['start', 'complete']);
      expect(morph.frame.animating, false);
      expect(morph.rendered, 'ab');
      expect(morph.frame.items.where((i) => i.exiting), isEmpty);
    });
  });

  group('resting invariant after any completed morph', () {
    test('no exiting items remain and every live item is at rest', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello');
      morph.update('hello world');
      morph.at(10000);

      final frame = morph.frame;
      expect(frame.animating, false);
      expect(frame.items.any((i) => i.exiting), false);
      for (final item in frame.items) {
        if (item.isBreak) continue;
        expect(item.opacity, 1, reason: '${item.text} opacity');
        expect(item.transform.tx, 0, reason: '${item.text} tx');
        expect(item.transform.ty, 0, reason: '${item.text} ty');
        expect(item.transform.sx, 1, reason: '${item.text} sx');
        expect(item.transform.sy, 1, reason: '${item.text} sy');
      }
    });

    test('holds true after a group replacement (runs with no survivors)', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('cat');
      morph.update('dog');
      morph.at(10000);

      final frame = morph.frame;
      expect(frame.items.any((i) => i.exiting), false);
      for (final item in frame.items) {
        expect(item.opacity, 1);
        expect(item.transform.tx, 0);
        expect(item.transform.sx, 1);
      }
    });
  });
}
