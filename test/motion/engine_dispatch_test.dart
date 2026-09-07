import 'package:flutter_test/flutter_test.dart';
import 'package:torph/src/core/replacement.dart';
import 'package:torph/src/core/segment.dart';
import 'package:torph/src/motion/morph_engine.dart';

import 'engine_harness.dart';
import 'fake_measurer.dart';

/// Port of `upstream/.../text-morph/__tests__/engine.test.ts` and
/// `options.test.ts` to [MorphEngine].
void main() {
  group('kinds reach the DOM', () {
    test('marks digits and the symbols around them, and nothing else', () {
      final morph = Morph();
      morph.update('\$1,234');

      expect(morph.shape, [
        '\$:symbol',
        '1:digit',
        ',:symbol',
        '2:digit',
        '3:digit',
        '4:digit',
      ]);
    });

    test('leaves a sentence\'s words alone', () {
      final morph = Morph();
      morph.update('3 unread messages');

      expect(morph.shape, [
        '3:digit',
        '$nbsp:text',
        'unread:text',
        '$nbsp:text',
        'messages:text',
      ]);
    });
  });

  group('animation dispatch', () {
    test('slides a new digit down and a new symbol up', () {
      final morph = Morph();
      morph.update('999');

      morph.update('1,000');

      // Digits arrive from above and symbols from below, so a separator
      // appearing between them reads as a different event from the digit that
      expect(slideOf(morph.live.first), slideFrom(-slide));
      expect(slideOf(morph.byText(',')), slideFrom(slide));
    });

    test('leaves a digit that held its place untouched', () {
      final morph = Morph();
      morph.update('1234');
      final held = morph.liveIds.skip(1).toList();

      morph.update('1,234');

      // Place matching keeps 2, 3 and 4 in their columns. With no delta to
      // correct and nothing to slide, animating them at all — on either the slot
      for (final id in held) {
        expect(motion(morph.byId(id)), isNull, reason: 'slot $id');
        expect(slideOf(morph.byId(id)), isNull, reason: 'mover $id');
      }
    });

    test('sends words through the text morph, not the slide', () {
      final morph = Morph();
      morph.update('hello world');

      morph.update('hello there');

      expect(motion(morph.byText('hello')), textPersist);
      expect(motion(morph.byText('there')), textEnter);
      expect(slideOf(morph.byText('there')), isNull);
    });

    test('dispatches exits on the kind the element left with', () {
      final morph = Morph();
      morph.update('\$5 hello');
      final digit = morph.idOf('5');
      final word = morph.idOf('hello');

      morph.update('\$5');

      expect(morph.leaving.map((c) => c.string), contains('hello'));
      expect(motion(morph.byId(word)), textExit);
      expect(motion(morph.byId(digit)), isNull); // held its place, never left
    });

    test('slides a departing digit out', () {
      final morph = Morph();
      morph.update('42');
      final digits = morph.liveIds;

      morph.update('hello');

      for (final id in digits) {
        expect(slideOf(morph.byId(id)), slideOut, reason: 'mover $id');
      }
    });
  });

  group('the clip a slide happens behind', () {
    test('gives every numeric character its own box, and nothing else one', () {
      final morph = Morph();
      morph.update('3 apples');

      // Exactly the digit, and the character itself moved into a nested box so
      // the slot around it has something to clip against.
      final slots = morph.live.where((c) => c.mover != null).toList();
      expect(slots.map((c) => c.string), ['3']);
      for (final child in morph.children) {
        expect(child.mover != null, child.kind != null, reason: child.id);
      }
    });

    test('leaves the root unclipped, which is the whole reason slots exist', () {
      final morph = Morph();
      morph.update('a\n1,234\nb');

      // The root spans every line of the value, so clipping there would bound
      // only the first line's top and the last line's bottom. The clip lives on
      expect(morph.live.where((c) => c.mover != null).map((c) => c.string).join(), '1,234');
      for (final child in morph.live) {
        expect(child.mover != null, child.kind != null, reason: child.id);
      }
    });

    test('clips and fades the slot from the stylesheet, not per element', () {
      final morph = Morph();
      morph.update('\$5');

      // Upstream asserts the slot carries no inline `style` and the clip/fade
      // come from `style[data-torph]`. The engine equivalent: a slot is nothing
      for (final child in morph.live) {
        expect(child.mover != null, child.kind != null, reason: child.id);
        expect(child.transformOrigin, isNull);
      }
    });
  });

  group('opting out', () {
    test('numbers: false leaves digits as text, with no slots to slide in', () {
      final morph = Morph(config: MorphConfig(numbers: false));
      morph.update('hello');
      morph.update('\$1,234');

      expect(morph.shape.every((entry) => entry.endsWith(':text')), true);
      expect(morph.children.every((c) => c.mover == null), true);
    });
  });

  group('numbers across line changes', () {
    // Each of these moves a value between one line and several with a figure in
    // it. A digit's clip box is its own slot rather than the root, so none of it
    const steps = [
      '1,234',
      '1,234\ntotal', // gains a line below
      'Total\n5,678', // gains a line above and changes at once
      'a\n1,234\nb', // figure on a middle line
      'a\n5,678\nb', // middle line updates
      'text\n1,234',
      '1,234\ntext', // swaps lines with its label
      '5,678', // back onto one line
    ];

    test('keeps the figure a number on every line', () {
      final morph = Morph();

      for (final value in steps) {
        morph.update(value);

        final digits = morph.live.where((c) => c.kind != null);
        expect(digits.length, 5, reason: '"$value" lost its number');
        expect(morph.duplicateId, isNull, reason: '"$value" repeats an ID');
        expect(morph.rendered, value.replaceAll('\n', ''));
      }
    });

    test('slides one line box, not the height of the whole block', () {
      // The block height is stated rather than measured. Three lines of it is
      // what a digit must not travel.
      final tall = Morph(measurer: happyDom(lineHeight: 60));
      tall.update('1,234');
      tall.update('5,678');
      expect(slideOf(tall.byText('5')), slideFrom(-60));

      // Same 60px block, now three lines tall: the digit travels one of them.
      final lines = Morph(measurer: happyDom());
      lines.update('a\n1,234\nb');
      lines.update('a\n5,678\nb');
      expect(slideOf(lines.byText('5')), slideFrom(-20));
    });

    test('never hands the lines around the figure a slide', () {
      final morph = Morph();
      morph.update('a\n1,234\nb');
      final above = morph.idOf('a');
      final below = morph.idOf('b');

      morph.update('a\n5,678\nb');

      // Whether they *moved* is a layout question a zero-rect measurer cannot
      // answer. What it can answer is whether they were treated as part of the
      for (final id in [above, below]) {
        expect(slideOf(morph.byId(id)), isNull, reason: 'mover $id');
      }
      expect(
        morph.live.where((c) => c.string == 'a' || c.string == 'b').map((c) => c.kind),
        [null, null],
      );
    });
  });

  group('invariants across a chained morph', () {
    test('never gives two live children the same ID, and always renders the value', () {
      final morph = Morph();
      const sequence = [
        '\$4',
        '\$',
        '\$420',
        '\$4,020',
        'hello world',
        '3 unread messages',
        '13 unread items',
        'Total\n1,234',
        '0',
        '1,000,000',
        'it cost \$1,234.',
        '',
        '99%',
      ];

      for (final value in sequence) {
        morph.update(value);

        expect(morph.duplicateId, isNull, reason: '"$value" repeats an ID');

        // An empty value keeps a zero-width space so the line box survives the
        // exits, so it is the one step that does not render its own text.
        if (value != '') {
          expect(morph.rendered.replaceAll('\n', ''), value.replaceAll('\n', ''));
        } else {
          expect(morph.live.map((c) => c.id), [emptyId]);
        }
      }
    });
  });

  group('wholesale replacement', () {
    test('collapses a long replaced run instead of moving it character by character', () {
      final morph = Morph();
      morph.update('abcdefghijklmnop');
      final survivors = ['a', 'b', 'c', 'm', 'n', 'o', 'p'].map(morph.idOf).toList();

      morph.update('abcmnopqrstuvwx');

      // "defghijkl" leaves together and "qrstuvwx" arrives together — nine and
      // eight characters with nothing surviving between them.
      final grouped = morph.children.where(isGrouped).map((c) => c.id).toSet();
      expect(grouped.length, 17);

      // The letters that survived are not part of either gesture; they still
      // move relative to their neighbours as themselves.
      for (final id in survivors) {
        expect(grouped.contains(id), false, reason: id);
      }
    });

    test('scales about a shared origin rather than each character\'s own', () {
      final morph = Morph();
      morph.update('abcdefghijklmnop');

      morph.update('abcmnopqrstuvwx');

      // Every member of a run states the same point in its own coordinates,
      // which is what makes one scale out of what would otherwise be sixteen.
      final origins = morph.live
          .where((c) => 'qrstuvwx'.contains(c.string))
          .map((c) => c.transformOrigin)
          .toList();

      expect(origins.length, 8);
      for (final origin in origins) {
        expect(origin, isNotNull);
      }
      // One point, restated per box — every member's own box is at the same
      // place under a zero-rect measurer, so the stated offsets agree.
      expect(origins.map((o) => '${o!.x},${o.y}').toSet().length, 1);

      for (final survivor in morph.live.where((c) => 'abcmnop'.contains(c.string))) {
        expect(survivor.transformOrigin, isNull, reason: survivor.id);
      }
    });

    test('leaves a short replacement to move on its own', () {
      final morph = Morph();
      morph.update('999,999');

      morph.update('1,000,000');

      // The comma survives and splits the value into runs of five and three, so
      // nothing here is long enough to be worth replacing wholesale — and this
      expect(morph.children.where(isGrouped), isEmpty);
    });

    test('replaces a figure that jumped orders of magnitude', () {
      final morph = Morph();
      morph.update('\$999.50');
      final dollar = morph.idOf('\$');

      morph.update('\$1,000,000.00');

      final grouped = morph.children.where(isGrouped).map((c) => c.id).toSet();
      expect(grouped.length, greaterThan(groupMin));
      expect(grouped.contains(dollar), false);
    });
  });

  group('timing', () {
    test('keeps every fade a share of the duration at any speed', () {
      for (final duration in [150.0, 400.0, 3000.0]) {
        final morph = Morph(config: MorphConfig(duration: duration));
        morph.update('hello 1');

        morph.update('world 2');

        final fades = fadesOf(morph);
        expect(fades, isNotEmpty, reason: '${duration}ms produced no fades');

        // A fixed ceiling here would decouple the fade from the transform: at
        // 3000ms a capped fade finishes a tenth of the way in and the character
        for (final fade in fades) {
          expect(fade.duration, lessThanOrEqualTo(duration), reason: '${duration}ms fade');
          expect(fade.duration / duration, greaterThan(0.1), reason: '${duration}ms fade share');
          expect(fade.delay / duration, lessThan(0.5), reason: '${duration}ms delay share');
        }

        morph.dispose();
      }
    });
  });

  group('author sizing', () {
    test('leaves no inline width or height behind for CSS to fight', () {
      // A pinned size outranks the author's own rules, so anything left behind
      // is permanent: a root the page puts at `width: 100%` has to still be
      final morph = Morph(measurer: FakeMeasurer());

      morph.update('hello');
      morph.update('hello world');
      morph.update('\$1,234');
      morph.advance(1000);

      expect(morph.engine.containerTransition, isNull);
      expect(morph.frame.width, morph.frame.naturalWidth);
      expect(morph.frame.height, morph.frame.naturalHeight);
    });

    test('sizes from the layout box, not an ancestor transform\'s visual one', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello');
      morph.update('hello world');

      // Mid-flight: the layout box is the animated size, which is neither the
      // old size it left nor the natural size it is heading for.
      morph.at(200);
      final animated = morph.frame.width;
      expect(animated, greaterThan(50));
      expect(animated, lessThan(110));

      morph.update('hi');

      // Starting from an inflated visual box is what balloons the root, morph
      // on morph.
      expect(morph.engine.containerTransition!.width!.from, animated);
      expect(morph.engine.containerTransition!.width!.to, 20);
    });
  });

  group('disabled', () {
    test('writes the value straight to the element', () {
      final morph = Morph();
      morph.updateDisabled('\$1,234');

      expect(morph.frame.plainText, '\$1,234');
      expect(morph.frame.items, isEmpty);
    });
  });

  /// What the root draws and what it reads as come apart during a morph, and
  /// only one of them is the value. The segments are a word cut to the character
  group('what a screen reader gets', () {
    test('carries the value as text, once, whatever the segments are doing', () {
      final morph = Morph();

      morph.update('hello world');
      expect(morph.frame.value, 'hello world');

      // Mid-morph: the previous value has characters still on their way out, and
      // the new one is split across boxes. Neither is readable; this is.
      morph.update('hello there');
      expect(morph.leaving.length, greaterThan(0));
      expect(morph.frame.value, 'hello there');
    });

    test('hides every fragment it draws, including the ones exiting', () {
      final morph = Morph();
      morph.update('npm install');
      morph.update('npm i');

      // Upstream asserts `aria-hidden="true"` on every item. The engine models
      // one label and fragments that carry none: the value is the frame's, never
      expect(morph.frame.items, isNotEmpty);
      expect(morph.frame.items.any((i) => i.exiting), true);
      expect(morph.frame.value, 'npm i');
      expect(morph.frame.items.map((i) => i.text), isNot(contains('npm i')));
    });

    test('does not read as a segment, so nothing tries to animate it', () {
      final morph = Morph();
      morph.update('hello');
      morph.update('world');

      // The accessible copy has no ID and never matches a segment, so the exit
      // path would otherwise claim it as an old child with no counterpart and
      expect(morph.frame.value, 'world');
      expect(morph.children.map((c) => c.string), isNot(contains('world')));
      expect(morph.children.map((c) => c.string), isNot(contains('hello')));
      // Every child is a fragment of one value or the other, never a copy of it.
      expect(morph.children.every((c) => c.string.length == 1), true);
    });

    test('comes back when reduced motion goes off again', () {
      // The one runtime route out of animating: the query is live, and while it
      // matches a value is written as plain text, which replaces the root's
      final calls = <String>[];
      final morph = Morph(
        config: MorphConfig(
          onAnimationStart: () => calls.add('start'),
          onAnimationComplete: () => calls.add('complete'),
          onAnimationCancel: () => calls.add('cancel'),
        ),
      );

      morph.updateDisabled('world');
      expect(morph.frame.plainText, 'world');
      expect(morph.frame.items, isEmpty);

      morph.update('hello again');

      expect(morph.frame.plainText, isNull);
      expect(morph.frame.value, 'hello again');
      expect(morph.rendered, 'hello again');
      // Re-enabling starts from an initial render: no motion, no callbacks.
      expect(transformsOf(morph), isEmpty);
      expect(fadesOf(morph), isEmpty);
      expect(morph.engine.containerTransition, isNull);
      expect(calls, isEmpty);
    });

    test('leaves nothing behind to render as a second copy', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello');
      morph.update('hello world');
      expect(morph.engine.containerTransition, isNotNull);

      morph.dispose();

      expect(morph.engine.containerTransition, isNull);
      expect(transformsOf(morph), isEmpty);
      expect(fadesOf(morph), isEmpty);
    });
  });

  /// Port of `options.test.ts`. A prop left off in JSX arrives as an explicit
  /// `undefined`; spread over the defaults it used to win, and the fades derive
  group('options given as undefined', () {
    /// Across a digit-count change, which is what puts characters on the slide
    /// path. Returns every timing handed to a track.
    ({List<double> durations, Set<Object> easings}) spin(MorphConfig config) {
      final morph = Morph(config: config);
      final durations = <double>[];
      final easings = <Object>{};
      for (final value in [0, 9, 10, 99, 100, 101, 9, 0]) {
        morph.update('\$$value');
        for (final track in transformsOf(morph)) {
          durations.add(track.duration);
          easings.add(track.easing);
        }
        for (final fade in fadesOf(morph)) {
          durations.add(fade.duration);
        }
      }
      final container = morph.engine.containerTransition;
      if (container?.width != null) easings.add(container!.width!.easing);
      morph.dispose();
      return (durations: durations, easings: easings);
    }

    test('falls back to the defaults rather than overwriting them', () {
      final defaults = MorphConfig();
      expect(defaults.duration, 400);
      expect(defaults.ease, 'cubic-bezier(0.19, 1, 0.22, 1)');
      expect(defaults.locale, 'en');
      expect(defaults.scale, true);
      expect(defaults.numbers, true);
      expect(defaults.decimals, isNull);

      final config = MorphConfig();
      final spun = spin(config);
      expect(spun.durations, isNotEmpty);
      for (final duration in spun.durations) {
        expect(duration.isFinite, true, reason: 'duration $duration');
        expect(duration, greaterThanOrEqualTo(0));
      }
      expect(spun.durations, contains(defaults.duration));
      expect(spun.easings, contains(config.easeFn));
    });

    test('still takes the values that were given', () {
      final config = MorphConfig(duration: 600, ease: 'ease-in-out');
      final spun = spin(config);
      expect(spun.durations, contains(600.0));
      expect(spun.easings, contains(config.easeFn));
    });
  });

  group('pending starts', () {
    test('a track created by update() waits for the first frame', () {
      final morph = Morph(measurer: FakeMeasurer());
      morph.update('hello');
      morph.updateOnly('hello world');

      final tracks = transformsOf(morph);
      expect(tracks, isNotEmpty);
      for (final track in tracks) {
        expect(track.startedAt, isNull);
        expect(track.progress(morph.clock), 0);
      }

      morph.at(0);
      for (final track in transformsOf(morph)) {
        expect(track.startedAt, 0);
        expect(track.progress(0), 0);
      }
    });
  });
}
