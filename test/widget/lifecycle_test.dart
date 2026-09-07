import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

void main() {
  testWidgets('a value change fires start once, then exactly one of complete/cancel',
      (tester) async {
    final log = <String>[];
    Widget app(String value) => host(TextMorph(
          value: value,
          onAnimationStart: () => log.add('start'),
          onAnimationComplete: () => log.add('complete'),
          onAnimationCancel: () => log.add('cancel'),
        ));

    await tester.pumpWidget(app('a'));
    expect(log, isEmpty, reason: 'an initial render is not a morph');

    await tester.pumpWidget(app('ab'));
    // Raised during the build phase, flushed in the same frame's post-frame
    // callbacks (DEV-003).
    expect(log, ['start']);

    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(log, ['start', 'complete']);
  });

  testWidgets('an interrupted morph cancels exactly once', (tester) async {
    final log = <String>[];
    Widget app(String value) => host(TextMorph(
          value: value,
          onAnimationStart: () => log.add('start'),
          onAnimationComplete: () => log.add('complete'),
          onAnimationCancel: () => log.add('cancel'),
        ));

    await tester.pumpWidget(app('a'));
    await tester.pumpWidget(app('ab'));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(app('abc'));
    expect(log, ['start', 'start', 'cancel']);

    await tester.pump(const Duration(milliseconds: 400));
    expect(log, ['start', 'start', 'cancel', 'complete']);
  });

  testWidgets('callbacks are read through the latest widget', (tester) async {
    final first = <String>[];
    final second = <String>[];
    await tester.pumpWidget(host(TextMorph(
      value: 'a',
      onAnimationStart: () => first.add('start'),
    )));
    await tester.pumpWidget(host(TextMorph(
      value: 'ab',
      onAnimationStart: () => second.add('start'),
    )));
    expect(first, isEmpty);
    expect(second, ['start']);
  });

  testWidgets('dispose mid-morph fires nothing', (tester) async {
    final log = <String>[];
    Widget app(String value) => host(TextMorph(
          value: value,
          onAnimationStart: () => log.add('start'),
          onAnimationComplete: () => log.add('complete'),
          onAnimationCancel: () => log.add('cancel'),
        ));

    await tester.pumpWidget(app('a'));
    await tester.pumpWidget(app('ab'));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 100));
    log.clear();

    await tester.pumpWidget(host(const SizedBox()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(log, isEmpty);
  });

  testWidgets('a config change replays the value without motion', (tester) async {
    final log = <String>[];
    Widget app(String value, Duration duration) => host(TextMorph(
          value: value,
          duration: duration,
          onAnimationStart: () => log.add('start'),
          onAnimationComplete: () => log.add('complete'),
          onAnimationCancel: () => log.add('cancel'),
        ));

    await tester.pumpWidget(app('hello', const Duration(milliseconds: 400)));
    final before = renderOf(tester).size;

    await tester.pumpWidget(app('hello', const Duration(milliseconds: 900)));
    final snapshot = snapshotOf(tester);
    expect(log, isEmpty);
    expect(snapshot.animating, isFalse);
    expect(snapshot.size, before);
    expect(snapshot.liveItems.every((i) => i.opacity == 1), isTrue);
    expect(stateOf(tester).debugTickerActive, isFalse);
    expect(stateOf(tester).debugEngine!.config.duration, 900);
  });

  testWidgets('a config change during a morph restarts from rest', (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello')));
    await tester.pumpWidget(host(TextMorph(value: 'hello world')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(host(TextMorph(value: 'hello world', debug: true)));
    final snapshot = snapshotOf(tester);
    expect(snapshot.animating, isFalse);
    expect(snapshot.size.width, closeTo(11 * fontSize, 0.01));
    expect(snapshot.exitingItems, isEmpty);
  });

  testWidgets('a changed callback alone does not recreate the engine',
      (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'a', onAnimationStart: () {})));
    final engine = stateOf(tester).debugEngine;
    await tester.pumpWidget(host(TextMorph(value: 'a', onAnimationStart: () {})));
    expect(stateOf(tester).debugEngine, same(engine));
  });

  testWidgets('a style change re-measures without resetting the morph',
      (tester) async {
    await tester.pumpWidget(host(TextMorph(value: 'hello')));
    await tester.pumpWidget(host(TextMorph(value: 'hello world')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final engine = stateOf(tester).debugEngine;

    await tester.pumpWidget(host(TextMorph(
      value: 'hello world',
      style: const TextStyle(fontSize: 40),
    )));

    // Same engine, same morph — new geometry.
    expect(stateOf(tester).debugEngine, same(engine));
    final snapshot = snapshotOf(tester);
    expect(snapshot.animating, isTrue);
    expect(snapshot.naturalSize.width, closeTo(11 * 40, 0.01));
  });

  testWidgets('the same value again is a no-op', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(host(TextMorph(value: 'a')));
    await tester.pumpWidget(host(TextMorph(
      value: 'a',
      onAnimationStart: () => log.add('start'),
    )));
    expect(log, isEmpty);
    expect(snapshotOf(tester).animating, isFalse);
  });

  group('options', () {
    test('the defaults are upstream\'s', () {
      expect(defaultTextMorphOptions.locale, 'en');
      expect(defaultTextMorphOptions.duration, const Duration(milliseconds: 400));
      expect(defaultTextMorphOptions.ease, 'cubic-bezier(0.19, 1, 0.22, 1)');
      expect(defaultTextMorphOptions.scale, isTrue);
      expect(defaultTextMorphOptions.numbers, isTrue);
      expect(defaultTextMorphOptions.disabled, isFalse);
      expect(defaultTextMorphOptions.respectReducedMotion, isTrue);
      expect(defaultTextMorphOptions.debug, isFalse);
      expect(defaultTextMorphOptions.decimals, isNull);
    });

    test('the widget defaults match', () {
      final widget = TextMorph(value: 'a');
      expect(widget.duration, defaultTextMorphOptions.duration);
      expect(widget.ease, defaultTextMorphOptions.ease);
      expect(widget.scale, isTrue);
      expect(widget.numbers, isTrue);
      expect(widget.disabled, isFalse);
      expect(widget.respectReducedMotion, isTrue);
      expect(widget.debug, isFalse);
      expect(widget.locale, isNull);
    });

    test('an invalid ease throws at construction', () {
      expect(() => TextMorph(value: 'a', ease: 'wobble'), throwsArgumentError);
      expect(() => TextMorph(value: 'a', ease: 42), throwsArgumentError);
      expect(() => TextMorph(value: const <int>[]), throwsArgumentError);
    });

    test('a valid CSS easing is accepted', () {
      expect(TextMorph(value: 'a', ease: 'ease-in-out').ease, 'ease-in-out');
      expect(TextMorph(value: 'a', ease: 'linear(0, 1)').ease, 'linear(0, 1)');
    });

    testWidgets('a spring replaces the duration', (tester) async {
      const params = SpringParams(stiffness: 120, damping: 14);
      await tester.pumpWidget(host(TextMorph(
        value: 'a',
        ease: params,
        duration: const Duration(milliseconds: 400),
      )));
      final resolved = spring(params);
      final config = stateOf(tester).debugEngine!.config;
      expect(config.duration, resolved.duration.toDouble());
      expect(config.ease, resolved.easing);
      expect(config.duration, isNot(400));
    });

    testWidgets('a num value is formatted with locale and decimals',
        (tester) async {
      await tester.pumpWidget(host(TextMorph(
        value: 1234.5,
        decimals: 2,
        locale: const Locale('de'),
      )));
      expect(snapshotOf(tester).value, '1.234,50');
    });
  });
}
