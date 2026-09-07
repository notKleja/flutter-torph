import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/motion/morph_engine.dart';

import 'engine_harness.dart';
import 'fake_measurer.dart';

/// CALLBACK-001..003 and LIFECYCLE-002/003 from `spec/PARITY.md`.
///

/// A morph with the three callbacks appended to one log, in order.
({Morph morph, List<String> log}) logged({
  FakeMeasurer? measurer,
  double duration = 400,
  int? decimals,
  String locale = 'en',
}) {
  final log = <String>[];
  final morph = Morph(
    measurer: measurer ?? FakeMeasurer(),
    config: MorphConfig(
      duration: duration,
      locale: locale,
      decimals: decimals,
      onAnimationStart: () => log.add('start'),
      onAnimationComplete: () => log.add('complete'),
      onAnimationCancel: () => log.add('cancel'),
    ),
  );
  return (morph: morph, log: log);
}

void main() {
  group('CALLBACK-001 start', () {
    test('fires before every non-initial update and never for the first', () {
      final (morph: morph, log: log) = logged();

      morph.update('a');
      expect(log, isEmpty, reason: 'the initial render is not an animation');

      morph.update('ab');
      expect(log, ['start']);

      morph.advance(400);
      expect(log, ['start', 'complete']);

      morph.update('abc');
      expect(log, ['start', 'complete', 'start']);
    });

    test('does not fire while disabled', () {
      final (morph: morph, log: log) = logged();
      morph.update('a');
      morph.updateDisabled('b');
      expect(log, isEmpty);
    });
  });

  group('CALLBACK-002 exactly one of complete or cancel', () {
    test('a morph left alone completes at the frame the width axis runs out', () {
      final (morph: morph, log: log) = logged();
      morph.update('hello');
      morph.update('hello world');

      final width = morph.engine.containerTransition!.width!;
      expect(width.startedAt, 0);

      morph.at(399);
      expect(log, ['start'], reason: 'still one millisecond of curve left');

      morph.at(400);
      expect(log, ['start', 'complete']);
      expect(morph.engine.containerTransition, isNull);

      // The size is released back to the content, not pinned at the target.
      expect(morph.frame.width, morph.frame.naturalWidth);

      morph.at(800);
      expect(log, ['start', 'complete'], reason: 'completion is not repeated');
    });

    test('an interruption cancels synchronously, inside update()', () {
      final (morph: morph, log: log) = logged();
      morph.update('hello');
      morph.update('hello world');
      morph.at(100);
      expect(log, ['start']);

      // `onAnimationStart` fires before reconciliation (index.ts:167) and the
      // abort of the transition already in flight comes at the end of it — both
      morph.engine.update('hello there', disabled: false);
      expect(log, ['start', 'start', 'cancel'],
          reason: 'the new morph starts, then what was in flight is aborted');

      morph.at(500);
      expect(log, ['start', 'start', 'cancel', 'complete']);
    });

    test('one morph never produces both', () {
      final (morph: morph, log: log) = logged();
      morph.update('hello');
      for (var i = 1; i <= 5; i++) {
        morph.at(i * 100);
        morph.update('hello ${'x' * i}');
      }
      morph.at(2000);

      // Four interruptions, one settled morph: five starts, four cancels, one
      // complete, and nothing doubled.
      expect(log.where((e) => e == 'start').length, 5);
      expect(log.where((e) => e == 'cancel').length, 4);
      expect(log.where((e) => e == 'complete').length, 1);
    });

    test('an emptied value holds the old size and completes after the duration', () {
      final (morph: morph, log: log) = logged();
      morph.update('hello');
      morph.update('');

      final held = morph.engine.containerTransition!;
      expect(held.held, isNotNull);
      expect(held.widthAt(200), 50);
      expect(held.heightAt(200), 20);

      morph.at(399);
      expect(log, ['start']);
      morph.at(400);
      expect(log, ['start', 'complete']);
      expect(morph.engine.containerTransition, isNull);
    });

    test('a first morph from a value that laid out empty cancels immediately', () {
      // A zero-rect measurer is the state the root is in after the disabled path
      // wrote plain text: nothing in flow, so the old width is 0.
      final (morph: morph, log: log) = logged(measurer: happyDom());
      morph.update('a');
      morph.update('ab');

      expect(log, ['start', 'cancel']);
      expect(morph.engine.containerTransition, isNull,
          reason: 'nothing animates the container when an axis started at 0');

      // The items still animate — only the container bows out.
      expect(transformsOf(morph), isNotEmpty);

      morph.at(1000);
      expect(log, ['start', 'cancel'], reason: 'no completion follows a cancel');
    });
  });

  group('CALLBACK-003 same value', () {
    test('nothing happens at all', () {
      final (morph: morph, log: log) = logged();
      morph.update('hello');
      morph.at(10);
      final calls = morph.measurer.calls;
      final ids = morph.liveIds;

      morph.update('hello');

      expect(log, isEmpty);
      expect(morph.measurer.calls, calls, reason: 'no re-measure');
      expect(morph.liveIds, ids);
      expect(transformsOf(morph), isEmpty);
      expect(morph.engine.containerTransition, isNull);
    });

    test('a number that formats to the same string is the same value', () {
      final (morph: morph, log: log) = logged(decimals: 2);
      morph.update(1234.5);
      expect(morph.engine.data, '1,234.50');

      morph.update('1,234.50');
      expect(log, isEmpty, reason: 'the formatted value did not change');
    });
  });

  group('number values', () {
    test('format through the locale and the decimals option', () {
      final morph = Morph(measurer: FakeMeasurer(), config: MorphConfig(decimals: 2));
      morph.update(1234.5);
      expect(morph.engine.data, '1,234.50');
      expect(morph.frame.value, '1,234.50');
      expect(morph.rendered, '1,234.50');

      final plain = Morph(measurer: FakeMeasurer(), config: MorphConfig());
      plain.update(1234.5);
      expect(plain.engine.data, '1,234.5');

      final german =
          Morph(measurer: FakeMeasurer(), config: MorphConfig(locale: 'de', decimals: 2));
      german.update(1234.5);
      expect(german.engine.data, '1.234,50');
    });

    test('a string value is used verbatim', () {
      final morph = Morph(measurer: FakeMeasurer(), config: MorphConfig(decimals: 2));
      morph.update('1234.5');
      expect(morph.engine.data, '1234.5');
    });
  });

  group('LIFECYCLE-002 disabled and reduced motion', () {
    test('writes plain text, resets the history and animates nothing', () {
      final (morph: morph, log: log) = logged();
      morph.update('hello');
      morph.update('hello world');
      expect(morph.engine.containerTransition, isNotNull);

      morph.updateDisabled('plain');

      expect(morph.frame.plainText, 'plain');
      expect(morph.frame.value, 'plain');
      expect(morph.frame.items, isEmpty);
      expect(morph.engine.previousSegments, isEmpty);
      expect(morph.engine.isInitialRender, true);

      // Upstream's disabled path writes `textContent` and returns: it never
      // touches the container transition, so what was in flight keeps running
      expect(log, ['start']);
      expect(morph.engine.containerTransition, isNotNull);
      morph.at(400);
      expect(log, ['start', 'complete']);
    });

    test('re-enabling renders the next value as an initial render', () {
      final (morph: morph, log: log) = logged();
      morph.update('hello');
      morph.updateDisabled('plain');
      log.clear();

      morph.update('back again');

      expect(morph.frame.plainText, isNull);
      expect(morph.frame.value, 'back again');
      expect(morph.rendered, 'back again');
      expect(transformsOf(morph), isEmpty);
      expect(fadesOf(morph), isEmpty);
      expect(morph.engine.containerTransition, isNull);
      expect(log, isEmpty);

      // The morph after that animates again.
      morph.update('back once more');
      expect(log, ['start']);
    });

    test('a disabled update to the same value is still a no-op', () {
      final (morph: morph, log: log) = logged();
      morph.updateDisabled('same');
      morph.updateDisabled('same');
      expect(log, isEmpty);
      expect(morph.frame.plainText, 'same');
    });
  });

  group('LIFECYCLE-003 dispose', () {
    test('fires no callbacks and leaves no active container', () {
      final (morph: morph, log: log) = logged();
      morph.update('hello');
      morph.update('hello world');
      morph.at(100);
      log.clear();

      morph.dispose();

      expect(log, isEmpty, reason: 'teardown is not an animation event');
      expect(morph.engine.containerTransition, isNull);
      expect(transformsOf(morph), isEmpty);
      expect(fadesOf(morph), isEmpty);
    });

    test('a hold torn down mid-flight fires nothing either', () {
      final (morph: morph, log: log) = logged();
      morph.update('hello');
      morph.update('');
      log.clear();

      morph.dispose();
      morph.at(1000);

      expect(log, isEmpty);
      expect(morph.engine.containerTransition, isNull);
    });
  });
}
