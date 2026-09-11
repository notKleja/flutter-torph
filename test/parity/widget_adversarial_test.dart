import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import '../widget/harness.dart';

/// The ten behaviours of `spec/A2_CHALLENGE_REPORT.md`, re-asserted through the
/// **widget** rather than the bare engine, plus the environment changes only a

/// browser px → test-font px, vertically (a line box is 24 px there, 20 here).
double _v(double browserPx) => browserPx * 20 / 24;

void main() {
  // ─── 1. a single-keyframe exit composites over the LIVE enter ───

  group('1. a mover mid-enter that starts exiting', () {
    // `999` → `1,000` at t=0, interrupted by `42` at t=40 (10 %), while the
    // 100 ms mover enter fade is still running.
    Future<void> setUp(WidgetTester tester) async {
      await tester.pumpWidget(host(TextMorph(value: '999')));
      await tester.pumpWidget(host(TextMorph(value: '1,000')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(host(TextMorph(value: '42')));
    }

    testWidgets('its mover opacity rises before it falls', (tester) async {
      await setUp(tester);
      // enterFade(t) · (1 − exitProgress(t)), not a snapshot fading to 0.
      const expected = <int, double>{
        40: 0.4,
        44: 0.4302,
        56: 0.5102,
        72: 0.592,
        90: 0.65,
        130: 0.5,
      };
      var at = 40;
      for (final entry in expected.entries) {
        if (entry.key > at) {
          await tester.pump(Duration(milliseconds: entry.key - at));
          at = entry.key;
        }
        final one = snapshotOf(tester).items.firstWhere(
          (i) => i.text == '1' && i.exiting,
          orElse: () => throw StateError('the exiting "1" is gone at t=$at'),
        );
        expect(
          one.moverOpacity,
          closeTo(entry.value, 1e-3),
          reason: 'mover opacity at t=$at',
        );
      }
    });

    testWidgets('the symbol mover dips before it rises', (tester) async {
      await setUp(tester);
      const digit = <int, double>{
        40: -12.4859,
        44: -9.6907,
        56: -2.2688,
        72: 5.5242,
        90: 11.7773,
        130: 19.0221,
      };
      const symbol = <int, double>{
        40: 12.4859,
        44: 12.2088,
        56: 12.1749,
        72: 13.4713,
        90: 15.6929,
        130: 19.8231,
      };
      var at = 40;
      for (final t in digit.keys) {
        if (t > at) {
          await tester.pump(Duration(milliseconds: t - at));
          at = t;
        }
        final items = snapshotOf(tester).items;
        final one = items.firstWhere((i) => i.text == '1' && i.exiting);
        final comma = items.firstWhere((i) => i.text == ',' && i.exiting);
        expect(
          one.moverTransform!.ty,
          closeTo(_v(digit[t]!), 0.02),
          reason: 'digit mover ty at t=$t',
        );
        expect(
          comma.moverTransform!.ty,
          closeTo(_v(symbol[t]!), 0.02),
          reason: 'symbol mover ty at t=$t',
        );
      }
      // Non-monotonic: 12.4859 → 12.2088 → 12.1749 → 13.4713.
      expect(_v(symbol[44]!), lessThan(_v(symbol[40]!)));
      expect(_v(symbol[56]!), lessThan(_v(symbol[44]!)));
      expect(_v(symbol[72]!), greaterThan(_v(symbol[56]!)));
    });
  });

  // ─── 2. text-align shifts an under-full line, never an overflowing one ───

  group('2. the pinned first-frame measurement', () {
    // A fresh key per case: reusing one `State` would make the previous case's
    // in-flight width the next case's `oldWidth`.
    var cases = 0;
    Future<double> deltaOf(
      WidgetTester tester,
      String from,
      String to,
      TextAlign align,
      String survivor,
    ) async {
      final key = ValueKey<int>(cases++);
      await tester.pumpWidget(
        host(
          TextMorph(key: key, value: from),
          textAlign: align,
        ),
      );
      await tester.pumpWidget(
        host(
          TextMorph(key: key, value: to),
          textAlign: align,
        ),
      );
      return snapshotOf(tester).item(survivor).transform.tx;
    }

    testWidgets('a grow produces zero deltas under every alignment', (
      tester,
    ) async {
      for (final align in [TextAlign.left, TextAlign.center, TextAlign.right]) {
        // `"hello"` has no space, so it is segmented by grapheme: the survivors
        // are `h e l l o`, not one word.
        expect(
          await deltaOf(tester, 'hello', 'hello world', align, 'h'),
          0,
          reason: 'grow under $align',
        );
      }
    });

    testWidgets('a shrink shifts by half the lost width when centred', (
      tester,
    ) async {
      // oldW = 11 glyphs = 220, new line = 5 glyphs = 100.
      expect(
        await deltaOf(
          tester,
          'hello world',
          'hello',
          TextAlign.center,
          'hello',
        ),
        closeTo(-(220 - 100) / 2, 1e-9),
      );
      expect(
        await deltaOf(tester, 'hello world', 'hello', TextAlign.right, 'hello'),
        closeTo(-(220 - 100), 1e-9),
      );
      expect(
        await deltaOf(tester, 'hello world', 'hello', TextAlign.left, 'hello'),
        0,
      );
    });
  });

  // ─── 3. alignment is per line box, so items move while the root does not ───

  testWidgets('3. a fixed-width root still shifts the shrinking line', (
    tester,
  ) async {
    const long = 'aaaaaaaaaaaaaaaaaaaa'; // 20 glyphs = 400, wider than line 2.
    await tester.pumpWidget(
      host(TextMorph(value: '$long\nhello world'), textAlign: TextAlign.center),
    );
    final before = renderOf(tester).size;
    await tester.pumpWidget(
      host(TextMorph(value: '$long\nhello'), textAlign: TextAlign.center),
    );

    final snapshot = snapshotOf(tester);
    // The container animation is a no-op: line 1 fixes the width and height.
    expect(snapshot.size, before);
    expect(snapshot.naturalSize, before);
    expect(snapshot.item(long).transform.tx, 0);
    // Line 2: the survivor starts half the lost width to the left.
    expect(snapshot.item('hello').transform.tx, closeTo(-60, 1e-9));
    // The departures head the other way. `detachFromFlow` folded their current
    // translate into the pinned `left`, so their transform *restarts* at 0 and
    expect(snapshot.item('world', exiting: true).transform.tx, 0);
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 50));
    final moving = snapshotOf(tester).item('world', exiting: true).transform.tx;
    expect(moving, greaterThan(30));
    expect(moving, lessThanOrEqualTo(60.001));
  });

  // ─── 4. `scale: false` only disables the plain text exit scale ───

  group('4. scale: false', () {
    testWidgets('still scales an entering text item', (tester) async {
      await tester.pumpWidget(host(TextMorph(value: 'hello', scale: false)));
      await tester.pumpWidget(
        host(TextMorph(value: 'hello world', scale: false)),
      );
      expect(snapshotOf(tester).item('world').transform.sx, 0.95);
      expect(snapshotOf(tester).item('h').transform.sx, 1);
    });

    testWidgets('drops the scale of an exiting text item', (tester) async {
      await tester.pumpWidget(
        host(TextMorph(value: 'Hello\nWorld', scale: false)),
      );
      await tester.pumpWidget(host(TextMorph(value: 'Hello', scale: false)));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        snapshotOf(tester).item('World', exiting: true).transform.sx,
        1,
        reason: 'the exit keyframe omits scale entirely',
      );
    });

    testWidgets('still scales a replacement group to 0.8', (tester) async {
      await tester.pumpWidget(
        host(TextMorph(value: 'abcdefghijklmnop', scale: false)),
      );
      await tester.pumpWidget(
        host(TextMorph(value: 'abcmnopqrstuvwx', scale: false)),
      );
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 400));
      final exited = snapshotOf(tester);
      // The group enter has landed at 1; mid-flight it came from 0.8.
      expect(exited.item('q').transform.sx, closeTo(1, 1e-9));

      await tester.pumpWidget(
        host(TextMorph(value: 'abcdefghijklmnop', scale: false)),
      );
      expect(
        snapshotOf(tester).item('d').transform.sx,
        closeTo(0.8, 1e-9),
        reason: 'the group enter keyframe is scale(0.8) whatever `scale` says',
      );
    });
  });

  // ─── 5. storms: a same target does not postpone `complete` ───

  group('5. a 16 ms storm', () {
    /// Storms `values` 16 ms apart and returns the elapsed time at which
    /// `onAnimationComplete` fired.
    Future<double> completeAt(WidgetTester tester, List<String> values) async {
      var clock = 0.0;
      var at = -1.0;
      Widget build(String v) =>
          host(TextMorph(value: v, onAnimationComplete: () => at = clock));

      await tester.pumpWidget(build(values.first));
      await tester.pumpWidget(build(values[1]));
      await startClock(tester);
      for (final v in values.skip(2)) {
        clock += 16;
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpWidget(build(v));
      }
      for (var i = 0; i < 60 && at < 0; i++) {
        clock += 16;
        await tester.pump(const Duration(milliseconds: 16));
      }
      return at;
    }

    testWidgets('completes 400 ms after the FIRST update when the width holds', (
      tester,
    ) async {
      // Every digit is one glyph wide, so the width target never moves and the
      // resumed axis still finishes at 400, not 448.
      expect(
        await completeAt(tester, ['1', '2', '3', '4', '5']),
        inInclusiveRange(400, 415),
        reason: 'the resumed axis keeps the first update\'s start',
      );
    });

    testWidgets('completes 400 ms after the LAST update when the width moves', (
      tester,
    ) async {
      expect(
        await completeAt(tester, [
          'hi',
          'hello',
          'hello world',
          'hello world foo',
        ]),
        inInclusiveRange(432, 447),
        reason: 'a moved target restarts the curve at 32 ms',
      );
    });
  });

  // ─── 6. `oldWidth` is the in-flight width; zero cancels the container ───

  testWidgets('6. an interrupt inherits the animated width', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hi')));
    await tester.pumpWidget(host(TextMorph(value: 'hello world')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 200));
    final midFlight = snapshotOf(tester).size.width;
    expect(midFlight, greaterThan(2 * fontSize));
    expect(midFlight, lessThan(11 * fontSize));

    await tester.pumpWidget(host(TextMorph(value: 'hi')));
    expect(
      snapshotOf(tester).size.width,
      closeTo(midFlight, 1e-9),
      reason: 'the next axis starts from the width on screen',
    );
  });

  testWidgets('6b. a zero old width cancels the container outright', (
    tester,
  ) async {
    final log = <String>[];
    Widget build(String v) => host(
      TextMorph(
        value: v,
        onAnimationStart: () => log.add('start'),
        onAnimationComplete: () => log.add('complete'),
        onAnimationCancel: () => log.add('cancel'),
      ),
    );

    await tester.pumpWidget(build('hello'));
    await tester.pumpWidget(build(''));
    await startClock(tester);
    // The hold keeps the old width for the whole duration, then restores.
    expect(snapshotOf(tester).size.width, closeTo(5 * fontSize, 1e-9));
    await tester.pump(const Duration(milliseconds: 400));
    expect(log, ['start', 'complete']);
    expect(snapshotOf(tester).size.width, 0);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(build('hello'));
    // oldWidth == 0: start then cancel in the same instant, no container motion.
    expect(log, ['start', 'complete', 'start', 'cancel']);
    expect(
      snapshotOf(tester).size.width,
      closeTo(5 * fontSize, 1e-9),
      reason: 'the root jumps to its natural width in one frame',
    );
    // The items still animate.
    expect(snapshotOf(tester).item('h').transform.sx, 0.95);
    expect(snapshotOf(tester).item('h').opacity, 0);
  });

  // ─── 7. interrupting a mid-enter item snaps scale and flashes opacity ───

  testWidgets('7. an interrupted mid-enter item snaps to sx 1 and opacity 1', (
    tester,
  ) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello world')));
    await tester.pumpWidget(host(TextMorph(value: 'hello there')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 96));
    final before = snapshotOf(tester).item('there');
    expect(before.transform.sx, closeTo(0.9915, 5e-4));
    expect(before.opacity, 0, reason: 'the enter fade is delayed by 25 %');

    await tester.pump(const Duration(milliseconds: 4));
    await tester.pumpWidget(host(TextMorph(value: 'hello friend')));
    final after = snapshotOf(tester).item('there', exiting: true);
    expect(after.transform.sx, 1, reason: 'the cancelled scale snaps to none');
    expect(
      after.opacity,
      1,
      reason: '`Number(getComputedStyle(el).opacity) || 1` coerces 0 to 1',
    );

    // A zero-delta persist still gets a full-duration animation that cancels
    // whatever was running.
    expect(snapshotOf(tester).item('hello').transform.tx, 0);
    expect(snapshotOf(tester).item('hello').transform.sx, 1);
  });

  // ─── 8. digits pair by column only when the digit counts match ───

  group('8. numeric pairing', () {
    Future<({Set<String> kept, Set<String> exiting, Set<String> fresh})> reuse(
      WidgetTester tester,
      String from,
      String to,
    ) async {
      await tester.pumpWidget(host(TextMorph(value: from)));
      final before = snapshotOf(tester).liveItems.map((i) => i.id).toSet();
      await tester.pumpWidget(host(TextMorph(value: to)));
      final now = snapshotOf(tester);
      return (
        kept: now.liveItems.map((i) => i.id).where(before.contains).toSet(),
        exiting: now.exitingItems.map((i) => i.id).toSet(),
        fresh: now.liveItems
            .map((i) => i.id)
            .where((id) => !before.contains(id))
            .toSet(),
      );
    }

    testWidgets('"1234" → "1,234" keeps all four digits', (tester) async {
      final r = await reuse(tester, '1234', '1,234');
      expect(r.kept.length, 4);
      expect(r.exiting, isEmpty);
      expect(r.fresh.length, 1, reason: 'only the group separator is new');
    });

    testWidgets('"999" → "1,000" replaces every digit', (tester) async {
      final r = await reuse(tester, '999', '1,000');
      expect(r.kept, isEmpty);
      expect(r.exiting.length, 3);
      expect(r.fresh.length, 5);
    });

    testWidgets('"\$999.50" → "\$1,000.00" keeps only the affix and a column', (
      tester,
    ) async {
      final r = await reuse(tester, '-999.50', '-1,000.00');
      // Report table: kept `- . 0`, exiting `9 9 9 5`, 6 fresh.
      expect(r.kept.length, 3);
      expect(r.exiting.length, 4);
      expect(r.fresh.length, 6);
    });
  });

  // ─── 9. separator IDs are UTF-16 keyed ───

  group('9. separator identity', () {
    testWidgets('"😀 hi" → "hi 😀" reuses everything, space included', (
      tester,
    ) async {
      await tester.pumpWidget(host(TextMorph(value: '😀 hi')));
      final before = snapshotOf(tester).liveItems.map((i) => i.id).toSet();
      await tester.pumpWidget(host(TextMorph(value: 'hi 😀')));
      final now = snapshotOf(tester);
      expect(now.exitingItems, isEmpty);
      expect(
        now.liveItems.map((i) => i.id).toSet(),
        before,
        reason: 'the space sits at UTF-16 offset 2 in both values',
      );
    });

    testWidgets('"one two three" → "three two one" replaces both separators', (
      tester,
    ) async {
      await tester.pumpWidget(host(TextMorph(value: 'one two three')));
      final before = snapshotOf(tester).liveItems.map((i) => i.id).toSet();
      await tester.pumpWidget(host(TextMorph(value: 'three two one')));
      final now = snapshotOf(tester);
      expect(now.exitingItems.length, 2, reason: 'both spaces leave');
      expect(now.exitingItems.every((i) => i.text == '\u00a0'), isTrue);
      final kept = now.liveItems.where((i) => before.contains(i.id)).length;
      expect(kept, 3, reason: 'all three words survive');
    });
  });

  // ─── 10. two elements can carry the same id at once ───

  testWidgets(
    '10. a re-entering value duplicates ids beside their exiting copies',
    (tester) async {
      await tester.pumpWidget(host(TextMorph(value: 'hello')));
      await tester.pumpWidget(host(TextMorph(value: '')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 4));
      await tester.pumpWidget(host(TextMorph(value: 'hello')));

      final snapshot = snapshotOf(tester);
      expect(snapshot.items.length, 10, reason: '5 exiting + 5 live');
      final exitingIds = snapshot.exitingItems.map((i) => i.id).toSet();
      final liveIds = snapshot.liveItems.map((i) => i.id).toSet();
      expect(
        exitingIds.intersection(liveIds).length,
        5,
        reason: 'the fresh allocator mints the same ids again',
      );
      expect(snapshot.exitingItems.first.opacity, closeTo(0.96, 1e-9));
      expect(snapshot.liveItems.first.opacity, 0);
      // The `empty` stand-in went synchronously, never animated out.
      expect(snapshot.items.any((i) => i.text == '\u200b'), isFalse);

      await tester.pump(const Duration(milliseconds: 100));
      expect(snapshotOf(tester).items.length, 5);
    },
  );

  // ─── the environment changing under a running morph ───

  group('mid-morph environment changes', () {
    testWidgets('a text scaler of 2.0 rescales the scene and keeps the morph', (
      tester,
    ) async {
      await tester.pumpWidget(host(TextMorph(value: 'hello')));
      await tester.pumpWidget(host(TextMorph(value: 'hello world')));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 200));
      final before = snapshotOf(tester);

      await tester.pumpWidget(
        host(
          TextMorph(value: 'hello world'),
          textScaler: const TextScaler.linear(2),
        ),
      );
      final after = snapshotOf(tester);
      expect(
        after.naturalSize.width,
        closeTo(2 * before.naturalSize.width, 1e-9),
        reason: 'the natural size doubles',
      );
      expect(after.item('world').width, closeTo(2 * 5 * fontSize, 1e-9));
      // The morph history survives: `world` is still mid-enter, not restarted.
      expect(after.item('world').opacity, before.item('world').opacity);
      expect(
        after.item('world').transform.sx,
        before.item('world').transform.sx,
      );
      // The container animation keeps its old target, as its keyframes are set.
      expect(after.size.width, closeTo(before.size.width, 1e-9));

      await tester.pump(const Duration(milliseconds: 400));
      final settled = snapshotOf(tester);
      expect(settled.animating, isFalse);
      expect(
        settled.size,
        settled.naturalSize,
        reason: 'the root ends at the rescaled natural size',
      );
      expect(renderOf(tester).size, settled.naturalSize);
    });

    testWidgets('a DefaultTextStyle change mid-morph re-measures in place', (
      tester,
    ) async {
      Widget build(double size) => MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: TextStyle(fontSize: size, color: const Color(0xFF000000)),
            child: Align(
              alignment: Alignment.topLeft,
              child: TextMorph(value: 'hello world'),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(20));
      await tester.pumpWidget(build(20));
      await startClock(tester);
      await tester.pumpWidget(build(40));
      final after = snapshotOf(tester);
      expect(after.naturalSize.width, closeTo(11 * 40, 1e-9));
      expect(after.naturalSize.height, closeTo(40, 1e-9));
      expect(after.animating, isFalse, reason: 'a re-measure is not a morph');
      expect(renderOf(tester).size, after.naturalSize);
    });

    testWidgets(
      'a Directionality flip mid-morph re-lays out from the other edge',
      (tester) async {
        await tester.pumpWidget(host(TextMorph(value: 'hello', bidi: false)));
        await tester.pumpWidget(
          host(TextMorph(value: 'hello world', bidi: false)),
        );
        await startClock(tester);
        await tester.pump(const Duration(milliseconds: 200));
        final ltr = snapshotOf(tester).item('world').x;

        await tester.pumpWidget(
          host(
            TextMorph(value: 'hello world', bidi: false),
            direction: TextDirection.rtl,
          ),
        );
        final rtl = snapshotOf(tester);
        // Logical order is kept (upstream rule, `bidi: false`), the flow starts at the right edge.
        expect(rtl.item('world').x, lessThan(ltr));
        expect(rtl.item('h').x, greaterThan(rtl.item('world').x));
        expect(rtl.animating, isTrue, reason: 'the morph is not torn down');
        await tester.pump(const Duration(milliseconds: 400));
        expect(snapshotOf(tester).animating, isFalse);
      },
    );

    testWidgets('`disabled` mid-morph stops the ticker and draws plain text', (
      tester,
    ) async {
      final log = <String>[];
      Widget build(String value, {required bool disabled}) => host(
        TextMorph(
          value: value,
          disabled: disabled,
          onAnimationStart: () => log.add('start'),
          onAnimationComplete: () => log.add('complete'),
          onAnimationCancel: () => log.add('cancel'),
        ),
      );

      await tester.pumpWidget(build('hello', disabled: false));
      await tester.pumpWidget(build('hello world', disabled: false));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(log, ['start']);

      await tester.pumpWidget(build('hello world', disabled: true));
      expect(snapshotOf(tester).plainText, 'hello world');
      expect(stateOf(tester).debugTickerActive, isFalse);
      expect(snapshotOf(tester).items, isEmpty);
      expect(log, ['start'], reason: 'the teardown fires no callback');
      expect(renderOf(tester).size.width, closeTo(11 * fontSize, 0.01));

      // A later update while disabled is still plain text, still no callbacks.
      await tester.pumpWidget(build('goodbye', disabled: true));
      expect(snapshotOf(tester).plainText, 'goodbye');
      expect(log, ['start']);

      // Re-enabling renders the next value as an initial render.
      await tester.pumpWidget(build('goodbye', disabled: false));
      expect(snapshotOf(tester).plainText, isNull);
      expect(snapshotOf(tester).animating, isFalse);
      expect(log, ['start']);
      await tester.pumpWidget(build('hello again', disabled: false));
      expect(log, ['start', 'start'], reason: 'the next change morphs again');
    });

    testWidgets('TickerMode off freezes the clock and on catches it up', (
      tester,
    ) async {
      Widget build(String value, {required bool ticking}) =>
          host(TickerMode(enabled: ticking, child: _Morph(value)));

      await tester.pumpWidget(build('hello', ticking: true));
      await tester.pumpWidget(build('hello world', ticking: true));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 100));
      final frozen = snapshotOf(tester);

      await tester.pumpWidget(build('hello world', ticking: false));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        snapshotOf(tester).now,
        frozen.now,
        reason: 'a muted ticker cannot tick',
      );
      expect(snapshotOf(tester).animating, isTrue);

      await tester.pumpWidget(build('hello world', ticking: true));
      await tester.pump(const Duration(milliseconds: 16));
      // The `Ticker`'s start time never moved, so time kept passing — which is
      // what WAAPI does to an off-screen animation.
      expect(snapshotOf(tester).now, greaterThan(frozen.now + 200));
      await tester.pump(const Duration(milliseconds: 400));
      expect(snapshotOf(tester).animating, isFalse);
      expect(snapshotOf(tester).size.width, closeTo(11 * fontSize, 0.01));
    });

    testWidgets('dispose mid-morph fires nothing and frees every painter', (
      tester,
    ) async {
      final log = <String>[];
      Widget build(String value) => host(
        TextMorph(
          value: value,
          onAnimationStart: () => log.add('start'),
          onAnimationComplete: () => log.add('complete'),
          onAnimationCancel: () => log.add('cancel'),
        ),
      );

      await tester.pumpWidget(build('hello'));
      await tester.pumpWidget(build('hello world foo bar'));
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 100));
      final measurer = renderOf(tester).measurer;
      expect(measurer.cachedPainterCount, greaterThan(0));
      expect(log, ['start']);

      await tester.pumpWidget(host(const SizedBox()));
      expect(log, ['start'], reason: 'destroy runs no callback');
      expect(
        measurer.cachedPainterCount,
        0,
        reason: 'every TextPainter was disposed',
      );

      // Whatever the disposed engine had scheduled must not resurface.
      await tester.pump(const Duration(milliseconds: 500));
      expect(log, ['start']);
      expect(tester.takeException(), isNull);
    });
  });

  // ─── F-1: the frame that completes a container transition ───

  group('F-1 (open finding): the completing frame never re-measures', () {
    testWidgets('a natural width that moved mid-flight leaves the line outside '
        'the root', (tester) async {
      // `"hello world"` → `"hello"` animates the width 220 → 100. Halfway
      // through, the text scaler halves every metric: the natural width becomes
      // 50 while the container transition keeps its 100 target (its keyframes
      // are fixed, as WAAPI's are). On the frame it finishes, the engine clears
      // `_container` and then re-measures only `if (pinned != null)`, so the
      // line keeps the alignment offset of the width it no longer has.
      await tester.pumpWidget(
        host(TextMorph(value: 'hello world'), textAlign: TextAlign.center),
      );
      await tester.pumpWidget(
        host(TextMorph(value: 'hello'), textAlign: TextAlign.center),
      );
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        host(
          TextMorph(value: 'hello'),
          textAlign: TextAlign.center,
          textScaler: const TextScaler.linear(0.5),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final settled = snapshotOf(tester);
      expect(settled.animating, isFalse);
      expect(settled.size, const Size(50, 10));
      expect(renderOf(tester).size, const Size(50, 10));
      final hello = settled.item('hello');
      expect(hello.width, 50);
      expect(hello.transform.tx, 0);
      // The browser's flow re-lays the span out the moment the inline width is
      // removed, so the only correct resting x for a 50 px line in a 50 px root
      // is 0. The port reports 25: half of the stale 100 px container.
      expect(
        hello.x,
        0,
        reason:
            'the line is centred in a container width the root no longer '
            'has, so it hangs 25 px outside its own box',
      );
    });

    testWidgets('a completed hold leaves the empty stand-in offset', (
      tester,
    ) async {
      // The `""` transition holds the old width for the duration and then
      // restores; the stand-in keeps the held width's alignment offset. Zero
      // wide, so nothing is painted — but it is the same defect.
      await tester.pumpWidget(
        host(TextMorph(value: 'hello'), textAlign: TextAlign.center),
      );
      await tester.pumpWidget(
        host(TextMorph(value: ''), textAlign: TextAlign.center),
      );
      await startClock(tester);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final settled = snapshotOf(tester);
      expect(settled.animating, isFalse);
      expect(settled.size.width, 0);
      expect(
        settled.liveItems.single.x,
        0,
        reason: 'the stand-in is still centred in the released 100 px hold',
      );
    });
  });

  // ─── cost ───

  testWidgets('a 500-character, 100-word value morphs in a sane frame budget', (
    tester,
  ) async {
    final from = List.generate(
      100,
      (i) => 'word${i.toString().padLeft(2, '0')}',
    ).join(' ');
    final to = List.generate(
      100,
      (i) => 'word${(i * 7 % 100).toString().padLeft(2, '0')}',
    ).join(' ');
    expect(from.length, greaterThan(500));

    await tester.pumpWidget(host(TextMorph(value: from)));
    final update = Stopwatch()..start();
    await tester.pumpWidget(host(TextMorph(value: to)));
    update.stop();
    await startClock(tester);

    final frames = <int>[];
    for (var i = 0; i < 25; i++) {
      final frame = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      frame.stop();
      frames.add(frame.elapsedMicroseconds);
    }
    frames.sort();
    printOnFailure(
      'update ${update.elapsedMicroseconds} µs, '
      'frame median ${frames[frames.length ~/ 2]} µs, worst ${frames.last} µs',
    );
    // Not a tight budget: a widget test carries the whole pipeline and the
    // machine is shared. This only catches a quadratic blow-up.
    expect(frames[frames.length ~/ 2], lessThan(100000));
    expect(snapshotOf(tester).liveItems.length, greaterThan(100));
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
