import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/core/segment.dart';
import 'package:torph/src/motion/morph_engine.dart';

import 'engine_harness.dart';
import 'fake_measurer.dart';

/// INTERRUPT-001..005 from `spec/PARITY.md`, and the two questions the ledger
/// settles about them: Q-005 (what an exiting element's underlying opacity is)

/// 37% of the default 400ms morph — far enough in that every carried value is
/// distinct from both ends of its curve.
const double interruptAt = 148;

void main() {
  test('the interrupt lands at 37% of the morph', () {
    expect(interruptAt / MorphConfig().duration, 0.37);
  });

  group('INTERRUPT-001 a persisting item carries its translate', () {
    test('the new start offset is delta + the translate on screen', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('world');

      // "world" is pushed 30px right by "hi ", so it FLIPs from -30.
      morph.update('hi world');
      final w = morph.byText('w');
      expect(motion(w), [-30, 0, 1, 0, 0, 1]);

      morph.at(interruptAt);
      final carriedTx = w.box.transformAt(interruptAt).tx;
      expect(carriedTx, greaterThan(-30));
      expect(carriedTx, lessThan(0));

      // "big " pushes it 40px further right, so the correction is -40 — from
      // where the box actually is, not from rest.
      morph.update('hi big world');
      expect(motion(w), [carriedTx - 40, 0, 1, 0, 0, 1]);
    });

    test('a mid-enter item that persists loses its scale but keeps its fade', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('world');
      morph.update('hi world');

      // "hi" arrived: scale 0.95, fading in behind a 25% delay, and FLIPped by
      // its nearest persisting neighbour's delta (FLIP-003).
      final hi = morph.byText('hi');
      expect(motion(hi), [-30, 0, 0.95, 0, 0, 1]);

      morph.at(interruptAt);
      final opacity = hi.box.opacityAt(interruptAt);
      final tx = hi.box.transformAt(interruptAt).tx;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));

      morph.update('hi big world');

      // Q-006: only the translate is read back, so the scale snaps to the
      // persist value of 1 — reproduced, not improved.
      expect(motion(hi), [tx, 0, 1, 0, 0, 1]);
      // The fade continues from where it had got to, over the persist share.
      final fade = hi.box.opacityTracks.single;
      expect(fade.from, opacity);
      expect(fade.to, 1);
      expect(fade.duration, 100);
      expect(fade.delay, 0);
    });
  });

  group('INTERRUPT-002 / INTERRUPT-003 an arriving item that starts leaving', () {
    test('is pinned where it is, and fades on from the opacity it had', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello world');
      morph.update('hello there');

      final there = morph.byText('there');
      expect(motion(there), textEnter);

      morph.at(interruptAt);
      final opacity = there.box.opacityAt(interruptAt);
      final x = there.x;
      final tx = there.box.transformAt(interruptAt).tx;

      morph.update('hello friend');

      expect(there.exiting, true);
      expect(morph.leaving, contains(there));

      // Q-005: `detachFromFlow` writes the snapshot opacity as the element's
      // own, and the exit fade's neutral start reads it back.
      expect(there.box.underlyingOpacity, opacity);
      final fade = there.box.opacityTracks.single;
      expect(fade.from, isNull, reason: 'a single keyframe at offset 1');
      expect(fade.to, 0);
      expect(fade.duration, 100);
      expect(there.box.opacityAt(interruptAt), opacity);
      expect(there.box.opacityAt(interruptAt + 100), 0);

      // Frozen at its visual position: the layout offset plus the translate it
      // was carrying, with the animation cancelled out from under it.
      expect(there.x, x + tx);
      expect(motion(there), textExit, reason: 'scale is not carried into the exit');
    });

    test('an item detached at exactly zero opacity reads back as opaque', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello world');
      morph.update('hello there');

      // No time has passed, so the arrival is at opacity 0 exactly.
      expect(morph.byText('there').box.opacityAt(0), 0);

      morph.update('hello friend');

      // `Number(getComputedStyle(el).opacity) || 1` — a fully faded box reads as
      // opaque, so the exit starts from 1 rather than continuing from 0.
      final there = morph.leaving.firstWhere((c) => c.string == 'there');
      expect(there.box.underlyingOpacity, 1);
      expect(there.box.opacityAt(0), 1);
    });
  });

  group('INTERRUPT-004 already-exiting items', () {
    test('are untouched by the next morph', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello world');
      morph.update('hello');

      final world = morph.leaving.firstWhere((c) => c.string == 'world');
      final transform = world.box.transformTracks.single;
      final fade = world.box.opacityTracks.single;
      final pinnedX = world.x;

      morph.at(50);
      morph.update('hello there');

      expect(world.box.transformTracks, hasLength(1));
      expect(world.box.opacityTracks, hasLength(1));
      expect(identical(world.box.transformTracks.single, transform), true);
      expect(identical(world.box.opacityTracks.single, fade), true);
      expect(world.x, pinnedX);
      expect(world.exiting, true);
    });

    test('are removed only by their own fade finishing', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello world');
      morph.update('hello');
      expect(morph.leaving.map((c) => c.string), contains('world'));

      morph.at(99);
      expect(morph.leaving.map((c) => c.string), contains('world'));
      morph.at(100);
      expect(morph.leaving, isEmpty);
    });
  });

  group('INTERRUPT-005 a re-entering ID mid-exit', () {
    test('is a fresh arrival alongside the one still leaving', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello world');
      morph.update('hello');

      morph.at(50);
      morph.update('hello world');

      // Previous measures come from the live children only, so the returning ID
      // has no previous position and is treated as an arrival.
      final copies = morph.children.where((c) => c.string == 'world').toList();
      expect(copies, hasLength(2));
      expect(copies.where((c) => c.exiting), hasLength(1));

      final arriving = copies.firstWhere((c) => !c.exiting);
      expect(motion(arriving), textEnter);
      expect(arriving.box.opacityTracks.single.from, 0);

      final leaving = copies.firstWhere((c) => c.exiting);
      expect(motion(leaving), textExit);
      expect(identical(arriving, leaving), false);
    });
  });

  group('an emptied value that comes back', () {
    test('drops the stand-in instantly and grows from the held size', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello');
      morph.update('');

      final held = morph.engine.containerTransition!;
      expect(held.held, (width: 50.0, height: 20.0));
      expect(morph.live.map((c) => c.id), [emptyId]);

      // Halfway through the hold.
      morph.at(200);
      expect(morph.frame.width, 50);
      morph.update('hello');

      // EMPTY-002: the stand-in is removed outright, never animated out.
      expect(morph.children.any((c) => c.id == emptyId), false);
      expect(morph.leaving, isEmpty);

      // The transition leaves from the size the hold was pinning, so the box
      // never jumps to the collapsed width in between.
      final transition = morph.engine.containerTransition!;
      expect(transition.held, isNull);
      expect(transition.width!.from, 50);
      expect(transition.width!.to, 50);
      expect(transition.height!.from, 20);
    });
  });

  group('pending starts', () {
    test('a track is pending until the first frame, and reads 0 there', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello');
      morph.at(interruptAt);

      morph.engine.update('hello world', disabled: false);

      final tracks = transformsOf(morph);
      expect(tracks, isNotEmpty);
      for (final track in tracks) {
        expect(track.startedAt, isNull, reason: 'play-pending until a frame lands');
        expect(track.progress(interruptAt), 0);
      }

      morph.at(interruptAt);
      for (final track in transformsOf(morph)) {
        expect(track.startedAt, interruptAt);
        expect(track.progress(interruptAt), 0);
      }

      // And the container axis is back-dated to the same instant.
      expect(morph.engine.containerTransition!.width!.startedAt, interruptAt);
    });
  });
}
