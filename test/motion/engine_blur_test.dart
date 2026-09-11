import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/motion/morph_engine.dart';

import 'engine_harness.dart';

const double blur = 2;
const double duration = 400;

Morph blurred() => Morph(
  config: MorphConfig(blur: blur, duration: duration),
);

ItemFrame frameOf(Morph morph, String text, {bool exiting = false}) =>
    morph.frame.items.firstWhere((i) => i.text == text && i.exiting == exiting);

void main() {
  group('text', () {
    test('an entering word starts at the configured blur and settles to 0', () {
      final morph = blurred();
      morph.update('hello');
      morph.update('hello world');
      morph.at(0);
      expect(frameOf(morph, 'world').blur, blur);
      morph.at(duration * 0.25 + duration * 0.5);
      expect(frameOf(morph, 'world').blur, 0);
    });

    test('an exiting word blurs from 0 up to the configured blur', () {
      final morph = blurred();
      morph.update('hello world');
      morph.update('hello');
      morph.at(0);
      expect(frameOf(morph, 'world', exiting: true).blur, 0);
      morph.at(duration * 0.25 - 1);
      expect(frameOf(morph, 'world', exiting: true).blur, closeTo(blur, 0.05));
    });

    test('an interrupted enter exits from its live blur', () {
      final morph = blurred();
      morph.update('hello');
      morph.update('hello world');
      morph.at(duration * 0.25 + duration * 0.25);
      final live = frameOf(morph, 'world').blur;
      expect(live, closeTo(blur / 2, 0.01));
      morph.update('hello');
      expect(frameOf(morph, 'world', exiting: true).blur, closeTo(live, 0.001));
    });
  });

  group('numbers', () {
    test('an entering digit blurs on its mover, not its slot', () {
      final morph = blurred();
      morph.update('9');
      morph.update('10');
      morph.at(0);
      final entering = morph.frame.items.where(
        (i) => !i.exiting && i.lifecycle == Lifecycle.entering,
      );
      expect(entering, isNotEmpty);
      for (final item in entering) {
        expect(item.moverBlur, blur);
        expect(item.blur, 0);
      }
      morph.at(duration * 0.25);
      for (final item in morph.frame.items.where((i) => !i.exiting)) {
        expect(item.moverBlur, 0);
      }
    });

    test('an exiting digit blurs its mover out', () {
      final morph = blurred();
      morph.update('10');
      morph.update('9');
      morph.at(duration * 0.45 - 1);
      final exiting = morph.frame.items.where((i) => i.exiting);
      expect(exiting, isNotEmpty);
      for (final item in exiting) {
        expect(item.moverBlur, closeTo(blur, 0.05));
      }
    });
  });

  group('groups', () {
    test('a replaced run blurs out and its replacement blurs in', () {
      final morph = blurred();
      morph.update('abcdefghijklmnop');
      morph.update('abcmnopqrstuvwx');
      morph.at(0);
      final entering = morph.children.where(
        (c) => c.lifecycle == Lifecycle.groupEntering,
      );
      final exiting = morph.children.where(
        (c) => c.lifecycle == Lifecycle.groupExiting,
      );
      expect(entering, isNotEmpty);
      expect(exiting, isNotEmpty);
      for (final c in entering) {
        expect(c.box.blurAt(0), blur);
      }
      for (final c in exiting) {
        expect(c.box.blurAt(0), 0);
      }
      morph.at(duration * 0.45 - 1);
      for (final c in entering) {
        expect(c.box.blurAt(morph.clock), 0);
      }
      for (final c in exiting) {
        expect(c.box.blurAt(morph.clock), closeTo(blur, 0.05));
      }
    });
  });

  group('off', () {
    test('blur 0 adds no tracks and every frame reads 0', () {
      final morph = Morph(config: MorphConfig(blur: 0));
      morph.update('hello 9');
      morph.update('bye 10');
      morph.at(0);
      for (final item in morph.children) {
        expect(item.box.blurTracks, isEmpty);
        expect(item.mover?.blurTracks ?? const [], isEmpty);
      }
      for (final item in morph.frame.items) {
        expect(item.blur, 0);
        expect(item.moverBlur ?? 0, 0);
      }
    });

    test('a negative or non-finite blur is rejected', () {
      expect(() => MorphConfig(blur: -1), throwsArgumentError);
      expect(() => MorphConfig(blur: double.nan), throwsArgumentError);
    });
  });
}
