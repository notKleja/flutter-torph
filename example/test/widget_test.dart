import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torph/testing.dart';
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

  testWidgets(
    'switching to Arabic flips direction and shows the Arabic corpus',
    (WidgetTester tester) async {
      await tester.pumpWidget(const TorphExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية (RTL)').last);
      await tester.pumpAndSettle();

      final Directionality dir = tester.widget<Directionality>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(dir.textDirection, TextDirection.rtl);
      expect(
        find.byKey(const Key('sentence-demo-ar'), skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the Hello card cycles phrases on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TorphExampleApp());
    await tester.pumpAndSettle();

    final render = tester.renderObject<RenderTextMorph>(
      find.descendant(
        of: find.byKey(const Key('hello-tap')),
        matching: find.byType(TextMorph),
      ),
    );
    expect(render.debugSnapshot().value, 'Hello');

    await tester.tap(find.byKey(const Key('hello-tap')));
    await tester.pumpAndSettle();

    expect(render.debugSnapshot().value, 'Hello world');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the counter morphs on tap', (WidgetTester tester) async {
    await tester.pumpWidget(const TorphExampleApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('counter-inc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('counter-inc')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
