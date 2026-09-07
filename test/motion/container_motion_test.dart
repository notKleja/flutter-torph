import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/motion/carry.dart';
import 'package:torph/src/motion/container_motion.dart';
import 'package:torph/src/motion/easing.dart';
import 'package:torph/src/motion/spring.dart';

/// Port of `lib/utils/__tests__/container-size.test.ts` plus the
/// "a container size interrupted every frame" section of `easing.test.ts`,

final SpringResult ease = spring(const SpringParams(stiffness: 150, damping: 19, mass: 1.2));
const double frameMs = 1000 / 60;
const String defaultEase = 'cubic-bezier(0.19, 1, 0.22, 1)';

/// `stage(width)`: the size the element would report, and a clock the
/// transition reads its own progress from.
class Stage {
  Stage(this.reportedWidth);

  double reportedWidth;
  double reportedHeight = 20;
  double clock = 0;

  ContainerTransition? current;
  final List<ContainerTransition> transitions = [];

  void at(double ms) => clock = ms;

  /// `transitionContainerSize(element, from, 20, EASE.duration, EASE.easing)`.
  void morph(double from) {
    // Read before the abort, off the curves the box is still riding.
    final previous = current?.snapshot(clock);
    current?.stop();
    current = ContainerTransition.transition(
      oldWidth: from,
      oldHeight: 20,
      newWidth: reportedWidth,
      newHeight: reportedHeight,
      previous: previous,
      duration: ease.duration.toDouble(),
      ease: ease.easing,
      now: clock,
    );
    transitions.add(current!);
  }

  /// What the teardown in `clearContainerTransition` does to the animations
  /// without removing the entry the next morph reads.
  void cancelRunning() {
    current?.width?.cancelled = true;
    current?.height?.cancelled = true;
  }

  /// The width animation of the most recent transition.
  Axis get lastWidth => transitions.last.width!;
  Axis get lastHeight => transitions.last.height!;

  /// `Math.round(anim.currentTime)` — the phase the curve was started at.
  double get seek => jsRound(clock - lastWidth.startedAt);
}

void main() {
  group('a container size transition', () {
    test('uses the author\'s easing when there is nothing in flight', () {
      final stage = Stage(86);
      stage.morph(67);

      // Width and height, in that order.
      expect([stage.lastWidth.easing, stage.lastHeight.easing], [ease.easing, ease.easing]);
      expect([stage.lastWidth.from, stage.lastWidth.to], [67, 86]);
    });

    test('starts a moved target over, from where the box actually is', () {
      final stage = Stage(86);
      stage.morph(67);

      stage.reportedWidth = 140;
      stage.at(frameMs);
      stage.morph(70);

      expect([stage.lastWidth.from, stage.lastWidth.to], [70, 140]);
    });
  });

  group('a transition replaced once a frame', () {
    test('resumes the curve in flight rather than restarting it', () {
      final stage = Stage(86);
      stage.morph(67);

      stage.at(frameMs);
      stage.morph(67.3);

      expect(stage.lastWidth.easing, ease.easing);
      // The original start and target, not the box's current width.
      expect([stage.lastWidth.from, stage.lastWidth.to], [67, 86]);
      expect(stage.seek, 17);
    });

    test('accumulates elapsed across every replacement', () {
      final stage = Stage(86);
      stage.morph(67);

      final seeks = <double>[];
      for (var frame = 1; frame <= 6; frame += 1) {
        stage.at(frame * frameMs);
        stage.morph(67);
        seeks.add(stage.seek);
      }

      expect(seeks, [17, 33, 50, 67, 83, 100]);
    });

    test('stops resuming once the curve has run its length', () {
      final stage = Stage(86);
      stage.morph(67);

      stage.at(ease.duration + 1);
      stage.morph(80);

      expect([stage.lastWidth.from, stage.lastWidth.to], [80, 86]);
    });

    test('stops resuming across a teardown that cancelled the animation', () {
      final stage = Stage(86);
      stage.morph(67);
      stage.cancelRunning();

      stage.at(frameMs);
      stage.morph(80);

      expect([stage.lastWidth.from, stage.lastWidth.to], [80, 86]);
      expect(stage.lastWidth.easing, ease.easing);
    });
  });

  group('momentum through a target that moves mid-flight', () {
    test('leaves at the speed it was already travelling', () {
      final stage = Stage(100);
      stage.morph(60);

      // Interrupted a frame in, with only a little left to cover — moving fast
      // relative to what remains, which is the case a fresh curve would depart
      stage.at(frameMs);
      stage.reportedWidth = 105;
      stage.morph(100);

      final carried = stage.lastWidth.easing;
      expect(carried, isNot(ease.easing));
      expect(carried.startsWith('linear('), true);

      final carriedFn = parseEasing(carried)!;
      final baseFn = parseEasing(ease.easing)!;
      expect(carriedFn(0), closeTo(0, 1e-4));
      expect(carriedFn(1), closeTo(1, 1e-4));
      expect(slopeAt(carriedFn, 0), greaterThan(slopeAt(baseFn, 0) * 2));
    });
  });

  /// The bug this exists for: a value updated faster than the morph settles
  /// restarts the size curve every frame, so only its opening sliver ever plays
  group('a container size interrupted every frame', () {
    double width(int value) => 10 + '\$$value'.length * 19;

    double spin(String easeString, double duration, bool carryOn) {
      final base = parseEasing(easeString)!;
      var position = width(90);
      var curve = base;
      var from = position;
      var to = position;
      var elapsed = 0.0;

      for (var frame = 0; frame <= 60; frame += 1) {
        final target = width(90 + frame);
        final velocity = carryOn ? ((to - from) * slopeAt(curve, elapsed / duration)) / duration : 0.0;

        from = position;
        to = target;
        final delta = to - from;
        curve = carryOn && delta.abs() > 0.5 ? carry(base, (velocity * duration) / delta).curve : base;

        elapsed = frameMs;
        position = from + delta * curve(elapsed / duration);
      }
      return to - position;
    }

    test('closes the gap a spring leaves open', () {
      final springy = spring(const SpringParams(stiffness: 150, damping: 19, mass: 1.2));
      expect(spin(springy.easing, springy.duration.toDouble(), false), greaterThan(2));
      expect(spin(springy.easing, springy.duration.toDouble(), true), lessThan(0.5));
    });

    test('does not make the front-loaded default any worse', () {
      final before = spin(defaultEase, 400, false);
      final after = spin(defaultEase, 400, true);
      expect(after, lessThanOrEqualTo(before + 0.01));
    });
  });

  group('axis state', () {
    test('a held axis hands nothing on', () {
      final held = ContainerTransition.hold(width: 50, height: 20, duration: 400, now: 0);
      final snap = held.snapshot(100);
      expect(snap.width.elapsed, isNull);
      expect(snap.width.velocity, 0);
      expect(snap.width.from, 50);
      expect(held.widthAt(300), 50);
      expect(held.finished(399), false);
      expect(held.finished(400), true);
    });

    test('velocity is px per ms off the curve actually in flight', () {
      final t = ContainerTransition.transition(
        oldWidth: 0,
        oldHeight: 20,
        newWidth: 100,
        newHeight: 20,
        previous: null,
        duration: 400,
        ease: defaultEase,
        now: 0,
      );
      final snap = t.snapshot(100);
      final expected = 100 * slopeAt(parseEasing(defaultEase)!, 100 / 400) / 400;
      expect(snap.width.velocity, closeTo(expected, 1e-12));
      expect(snap.width.elapsed, 100);
    });
  });

  group('animateAxis directly', () {
    test('carries only when the target moved by more than half a pixel', () {
      final base = parseEasing(defaultEase)!;
      final fast = AxisState(
        from: 0,
        to: 100,
        easing: defaultEase,
        curve: base,
        elapsed: 10,
        // Fast enough that the carry has something to add.
        velocity: 1,
      );
      final tiny = animateAxis(
        from: 0,
        to: 0.4,
        previous: fast,
        duration: 400,
        ease: defaultEase,
        base: base,
        now: 0,
      );
      expect(tiny.easing, defaultEase);

      final moved = animateAxis(
        from: 0,
        to: 40,
        previous: fast,
        duration: 400,
        ease: defaultEase,
        base: base,
        now: 0,
      );
      expect(moved.easing.startsWith('linear('), true);
      expect(slopeAt(moved.curve!, 0), greaterThan(slopeAt(base, 0)));
      // Sampled fine enough to be sub-frame, and pinned at both ends.
      final values = moved.easing.substring(7, moved.easing.length - 1).split(',').map((v) => double.parse(v.trim())).toList();
      expect(values.length, greaterThanOrEqualTo(32));
      expect(values.length, lessThanOrEqualTo(120));
      expect(values.first, closeTo(0, 1e-4));
      expect(values.last, 1);
      expect(values.every((v) => v.isFinite), true);
    });

    test('an axis with no previous state leaves the author\'s easing alone', () {
      final base = parseEasing(defaultEase)!;
      final axis = animateAxis(
        from: 0,
        to: 100,
        previous: null,
        duration: 400,
        ease: defaultEase,
        base: base,
        now: 0,
      );
      expect(axis.easing, defaultEase);
      expect(axis.valueAt(0), 0);
      expect(axis.valueAt(400), 100);
      expect(axis.valueAt(200), closeTo(100 * base(0.5), 1e-9));
      expect(math.min(axis.valueAt(-10), 0), 0);
    });
  });
}
