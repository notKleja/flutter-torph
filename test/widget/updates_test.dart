import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

void main() {
  testWidgets(
    'disabled: true renders plain text with the size of a plain Text, '
    'no ticker',
    (tester) async {
      await tester.pumpWidget(host(const Text('hello')));
      final textSize = tester.getSize(find.byType(Text));

      await tester.pumpWidget(host(TextMorph(value: 'hello', disabled: true)));
      expect(snapshotOf(tester).plainText, 'hello');
      expect(renderOf(tester).size, textSize);
      expect(stateOf(tester).debugTickerActive, isFalse);
    },
  );

  testWidgets('toggling disabled to false then changing the value morphs', (
    tester,
  ) async {
    final log = <String>[];
    Widget app(String value, {required bool disabled}) => host(
      TextMorph(
        value: value,
        disabled: disabled,
        onAnimationStart: () => log.add('start'),
      ),
    );

    await tester.pumpWidget(app('hello', disabled: true));
    expect(snapshotOf(tester).plainText, 'hello');

    // Re-enabling alone replays the same value as an initial render.
    await tester.pumpWidget(app('hello', disabled: false));
    expect(log, isEmpty);
    expect(snapshotOf(tester).plainText, isNull);
    expect(snapshotOf(tester).animating, isFalse);

    // The next value change morphs.
    await tester.pumpWidget(app('hello world', disabled: false));
    expect(log, ['start']);
    expect(snapshotOf(tester).animating, isTrue);

    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(snapshotOf(tester).animating, isFalse);
    expect(snapshotOf(tester).value, 'hello world');
  });
}
