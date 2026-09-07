import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

import 'harness.dart';

const Key _boundary = ValueKey('golden');

/// The goldens are Flutter-to-Flutter, drawn with the default `flutter_test`
/// font so nothing outside the repository can move them.
Widget golden(Widget child) => host(
      RepaintBoundary(
        key: _boundary,
        child: Container(
          color: const Color(0xFFFFFFFF),
          padding: const EdgeInsets.all(8),
          child: child,
        ),
      ),
    );

Future<void> expectGolden(WidgetTester tester, String name) => expectLater(
      find.byKey(_boundary),
      matchesGoldenFile('../goldens/$name.png'),
    );

void main() {
  testWidgets('a number at rest', (tester) async {
    await tester.pumpWidget(golden(TextMorph(value: r'$1,234.56')));
    await expectGolden(tester, 'number_rest');
  });

  testWidgets('a number mid-slide', (tester) async {
    await tester.pumpWidget(golden(TextMorph(value: '999')));
    await tester.pumpWidget(golden(TextMorph(value: '1,000')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 60));
    await expectGolden(tester, 'number_mid_slide');
  });

  testWidgets('a word mid-enter', (tester) async {
    await tester.pumpWidget(golden(TextMorph(value: 'hello')));
    await tester.pumpWidget(golden(TextMorph(value: 'hello world')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await expectGolden(tester, 'hello_world_mid_enter');
  });

  testWidgets('a group replacement mid-flight', (tester) async {
    await tester.pumpWidget(golden(TextMorph(value: 'keep this here')));
    await tester.pumpWidget(golden(TextMorph(value: 'keep that here')));
    await startClock(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await expectGolden(tester, 'group_replacement_mid_flight');
  });

  testWidgets('a multi-line value with a number at rest', (tester) async {
    await tester.pumpWidget(golden(TextMorph(value: 'a\n1,234\nb')));
    await expectGolden(tester, 'multiline_number_rest');
  });

  testWidgets('debug outlines', (tester) async {
    await tester.pumpWidget(golden(TextMorph(value: 'ab 12', debug: true)));
    expect(renderOf(tester).debug, isTrue);
    await expectGolden(tester, 'debug_outlines');
  });
}
