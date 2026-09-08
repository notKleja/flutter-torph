import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

void main() {
  testWidgets('the demo app builds every card', (WidgetTester tester) async {
    await tester.pumpWidget(const TorphExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Counter'), findsOneWidget);
    expect(find.text('Sentence'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    expect(find.byType(TextMorph), findsWidgets);
  });

  testWidgets('the counter morphs on tap', (WidgetTester tester) async {
    await tester.pumpWidget(const TorphExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('counter-inc')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
