import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

void main() {
  group('ease: Curve', () {
    testWidgets('a Curve is accepted and morphs', (tester) async {
      await tester.pumpWidget(
        host(TextMorph(value: 'a', ease: Curves.easeOutCubic)),
      );
      await tester.pumpWidget(
        host(TextMorph(value: 'ab', ease: Curves.easeOutCubic)),
      );
      await startClock(tester);
      expect(snapshotOf(tester).animating, isTrue);

      await tester.pump(const Duration(milliseconds: 400));
      expect(snapshotOf(tester).animating, isFalse);
      expect(snapshotOf(tester).plainText, isNull);
    });

    testWidgets('a fresh non-const Cubic every rebuild keeps the same engine', (
      tester,
    ) async {
      Widget app(String value) =>
          host(TextMorph(value: value, ease: Cubic(0.2, 0, 0, 1)));

      await tester.pumpWidget(app('a'));
      final engine = stateOf(tester).debugEngine;
      expect(engine, isNotNull);

      // A fresh Cubic each build: Curve has no `==`.
      await tester.pumpWidget(app('a'));
      expect(stateOf(tester).debugEngine, same(engine));

      await tester.pumpWidget(app('a'));
      expect(stateOf(tester).debugEngine, same(engine));
    });

    testWidgets(
      'an in-flight morph survives a rebuild with an equivalent new Curve',
      (tester) async {
        Widget app(String value) =>
            host(TextMorph(value: value, ease: Cubic(0.2, 0, 0, 1)));

        await tester.pumpWidget(app('a'));
        await tester.pumpWidget(app('ab'));
        await startClock(tester);
        await tester.pump(const Duration(milliseconds: 100));
        expect(snapshotOf(tester).animating, isTrue);

        await tester.pumpWidget(app('ab'));
        expect(snapshotOf(tester).animating, isTrue);

        await tester.pump(const Duration(milliseconds: 400));
        expect(snapshotOf(tester).animating, isFalse);
      },
    );
  });

  group('ease validation', () {
    testWidgets('an invalid CSS easing string throws at construction', (
      tester,
    ) async {
      expect(
        () => TextMorph(value: 'a', ease: 'not-a-real-easing'),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'ease')),
      );
    });

    testWidgets('an ease of the wrong type throws at construction', (
      tester,
    ) async {
      expect(
        () => TextMorph(value: 'a', ease: 42),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'ease')),
      );
    });

    testWidgets('SpringParams still ignores duration', (tester) async {
      await tester.pumpWidget(
        host(
          TextMorph(
            value: 'a',
            ease: const SpringParams(),
            duration: const Duration(milliseconds: 1),
          ),
        ),
      );
      await tester.pumpWidget(
        host(
          TextMorph(
            value: 'ab',
            ease: const SpringParams(),
            duration: const Duration(milliseconds: 1),
          ),
        ),
      );
      await startClock(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(snapshotOf(tester).animating, isTrue);
    });
  });

  testWidgets(
    'renders with only Directionality ambient (no MediaQuery, no DefaultTextStyle)',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextMorph(value: 'hello'),
        ),
      );

      expect(find.byType(TextMorph), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a dependency change and a value change landing in one frame fire '
    'callbacks only once',
    (tester) async {
      final log = <String>[];
      Widget app(String value, TextScaler scaler) => host(
        TextMorph(value: value, onAnimationStart: () => log.add('start')),
        textScaler: scaler,
      );

      await tester.pumpWidget(app('a', TextScaler.noScaling));
      // didChangeDependencies and didUpdateWidget both run this frame.
      await tester.pumpWidget(app('ab', const TextScaler.linear(2)));
      expect(log, ['start']);
    },
  );
}
