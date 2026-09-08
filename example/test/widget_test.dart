import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/torph.dart';

void main() {
  testWidgets('the demo app builds every card', (WidgetTester tester) async {
    await tester.pumpWidget(const TorphExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Counter'), findsOneWidget);
    expect(find.text('Sentence', skipOffstage: false), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    expect(find.byType(TextMorph), findsWidgets);
  });

  testWidgets('switching to Arabic flips direction and shows the Arabic corpus', (WidgetTester tester) async {
    await tester.pumpWidget(const TorphExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية (RTL)').last);
    await tester.pumpAndSettle();

    final Directionality dir = tester.widget<Directionality>(
      find.descendant(of: find.byType(Scaffold), matching: find.byType(Directionality)).first,
    );
    expect(dir.textDirection, TextDirection.rtl);
    expect(find.byKey(const Key('sentence-demo-ar'), skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
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
